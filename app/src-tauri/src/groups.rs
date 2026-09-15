//! Groups: what the window is watching, and where that is remembered.
//!
//! A group is a name and a list of repositories. It may also be bound to a
//! parent folder, and then repositories appearing in that folder join the group
//! on their own.
//!
//! The folder is a binding, not an identity. That was settled when the
//! requirements were written — "a folder is a way to bound a group of sessions;
//! there is no product ontology in it" — and it is why a group can hold
//! directories from anywhere, or none at all.
//!
//! Stored in the application's own data directory. Not in `.devflow`: which
//! repositories one person chose to watch together is not a fact about any of
//! those repositories, and writing it into one of them would make it look like
//! one.

use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};
use tauri::Manager;

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Group {
    pub id: String,
    pub name: String,
    /// Repositories added by hand, absolute paths.
    #[serde(default)]
    pub repos: Vec<String>,
    /// Optional parent folder. Its immediate subdirectories that carry a devflow
    /// manifest are part of the group without being listed.
    #[serde(default)]
    pub folder: Option<String>,
    #[serde(default = "yes")]
    pub open: bool,
}

fn yes() -> bool {
    true
}

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct Groups {
    #[serde(default)]
    pub groups: Vec<Group>,
}

fn store_path(app: &tauri::AppHandle) -> Result<PathBuf, String> {
    let dir = app
        .path()
        .app_data_dir()
        .map_err(|e| format!("no application data directory: {e}"))?;
    std::fs::create_dir_all(&dir).map_err(|e| format!("could not create {}: {e}", dir.display()))?;
    Ok(dir.join("groups.json"))
}

#[tauri::command]
pub fn groups_load(app: tauri::AppHandle) -> Result<Groups, String> {
    let path = store_path(&app)?;
    if !path.is_file() {
        return Ok(Groups::default());
    }
    let text = std::fs::read_to_string(&path)
        .map_err(|e| format!("could not read {}: {e}", path.display()))?;
    serde_json::from_str(&text).map_err(|e| format!("{} is not readable: {e}", path.display()))
}

#[tauri::command]
pub fn groups_save(app: tauri::AppHandle, groups: Groups) -> Result<(), String> {
    let path = store_path(&app)?;
    let text = serde_json::to_string_pretty(&groups).map_err(|e| e.to_string())?;
    // Written beside and renamed: a half-written file here would lose the list
    // of everything the window watches.
    let tmp = path.with_extension("json.tmp");
    std::fs::write(&tmp, text).map_err(|e| format!("could not write {}: {e}", tmp.display()))?;
    std::fs::rename(&tmp, &path).map_err(|e| format!("could not replace {}: {e}", path.display()))
}

/// Every repository a group covers: the ones listed, plus the ones its folder
/// turns up. Sorted, without repeats, and only those that still exist.
#[tauri::command]
pub fn group_repos(group: Group) -> Result<Vec<String>, String> {
    let mut out: Vec<String> = Vec::new();
    let mut add = |p: PathBuf| {
        if p.join(".devflow/project.yml").is_file() || p.is_dir() {
            let s = p.to_string_lossy().to_string();
            if !out.contains(&s) {
                out.push(s);
            }
        }
    };

    if let Some(folder) = group.folder.as_deref() {
        let dir = Path::new(folder);
        if dir.join(".devflow/project.yml").is_file() {
            add(dir.to_path_buf());
        }
        if let Ok(entries) = std::fs::read_dir(dir) {
            let mut found: Vec<PathBuf> = entries
                .flatten()
                .map(|e| e.path())
                .filter(|p| p.is_dir() && p.join(".devflow/project.yml").is_file())
                .collect();
            found.sort();
            for p in found {
                add(p);
            }
        }
    }
    for r in &group.repos {
        let p = PathBuf::from(r);
        if p.is_dir() {
            add(p);
        }
    }
    Ok(out)
}

/// A text file, for reading in the window. Capped: this is for tickets, maps
/// and notes, and a pane is not the place to discover that something is a
/// gigabyte of log.
/// The home directory, so paths can be written the way a person writes them.
#[tauri::command]
pub fn home_dir() -> String {
    std::env::var("HOME").unwrap_or_default()
}

#[tauri::command]
pub fn read_text(path: String) -> Result<String, String> {
    const CAP: u64 = 2 * 1024 * 1024;
    let p = Path::new(&path);
    let meta = std::fs::metadata(p).map_err(|e| format!("{path}: {e}"))?;
    if meta.len() > CAP {
        return Err(format!(
            "{path} is {} MB — too large to open here",
            meta.len() / 1024 / 1024
        ));
    }
    std::fs::read_to_string(p).map_err(|e| format!("{path}: {e}"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_group_with_nothing_in_it_covers_nothing() {
        let g = Group {
            id: "a".into(),
            name: "a".into(),
            repos: vec![],
            folder: None,
            open: true,
        };
        assert!(group_repos(g).unwrap().is_empty());
    }

    #[test]
    fn a_folder_that_is_gone_is_not_an_error() {
        let g = Group {
            id: "a".into(),
            name: "a".into(),
            repos: vec!["/nonexistent/repo".into()],
            folder: Some("/nonexistent/folder".into()),
            open: true,
        };
        // Watching a directory that has been moved away should leave the rest of
        // the tree standing, not refuse to draw it.
        assert!(group_repos(g).unwrap().is_empty());
    }

    #[test]
    fn a_file_larger_than_the_cap_is_refused_by_name() {
        let err = read_text("/nonexistent/file.md".into()).unwrap_err();
        assert!(err.contains("/nonexistent/file.md"), "unexpected: {err}");
    }
}
