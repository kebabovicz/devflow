//! Talking to the two command lines this application stands on.
//!
//! Neither one is ever assembled in the frontend. The frontend asks for state;
//! how that state is obtained — which binary, which flags — lives here, so a
//! change to the engine's interface is one file rather than a hunt through
//! components.

use std::path::{Path, PathBuf};
use std::process::Command;

/// Where `bin/devflow` lives.
///
/// The plugin is installed by version into the Claude Code plugin cache, so the
/// path moves on every update; resolving it at runtime is the difference
/// between an application that survives an engine release and one that does
/// not. `DEVFLOW_BIN` overrides, which is how you run against a worktree.
pub fn devflow_bin() -> Result<PathBuf, String> {
    if let Ok(p) = std::env::var("DEVFLOW_BIN") {
        let p = PathBuf::from(p);
        if p.is_file() {
            return Ok(p);
        }
        return Err(format!("DEVFLOW_BIN points at {}, which is not a file", p.display()));
    }

    let home = std::env::var("HOME").map_err(|_| "HOME is not set".to_string())?;
    let versions_dir = Path::new(&home)
        .join(".claude/plugins/cache/devflow/devflow");
    let mut found: Vec<(Vec<u64>, PathBuf)> = Vec::new();
    let entries = std::fs::read_dir(&versions_dir)
        .map_err(|e| format!("no devflow plugin installed at {}: {e}", versions_dir.display()))?;
    for entry in entries.flatten() {
        let bin = entry.path().join("bin/devflow");
        if !bin.is_file() {
            continue;
        }
        let name = entry.file_name().to_string_lossy().to_string();
        let parts: Vec<u64> = name.split('.').map(|p| p.parse().unwrap_or(0)).collect();
        found.push((parts, bin));
    }
    found.sort();
    found
        .pop()
        .map(|(_, bin)| bin)
        .ok_or_else(|| format!("no bin/devflow under {}", versions_dir.display()))
}

fn run_json(program: &Path, args: &[&str]) -> Result<serde_json::Value, String> {
    let out = Command::new(program)
        .args(args)
        .output()
        .map_err(|e| format!("could not run {}: {e}", program.display()))?;
    if out.stdout.is_empty() {
        let err = String::from_utf8_lossy(&out.stderr);
        return Err(format!(
            "{} {} said nothing on stdout: {}",
            program.display(),
            args.join(" "),
            err.trim()
        ));
    }
    serde_json::from_slice(&out.stdout)
        .map_err(|e| format!("{} did not return JSON: {e}", program.display()))
}

/// State of every repository the application is watching.
///
/// One call for all of them: `status` takes several paths and answers with one
/// document, so the tree is built from a single consistent read rather than
/// from several taken a moment apart.
#[tauri::command]
pub fn engine_status(paths: Vec<String>) -> Result<serde_json::Value, String> {
    if paths.is_empty() {
        return Ok(serde_json::json!({ "schema": 1, "repos": [] }));
    }
    let bin = devflow_bin()?;
    let mut args: Vec<&str> = vec!["status", "--json"];
    for p in &paths {
        args.push(p);
    }
    run_json(&bin, &args)
}

/// Every session Claude Code knows about, background and interactive alike.
///
/// The application keeps no registry of its own: a second one would only give
/// the two a chance to disagree about which sessions exist.
#[tauri::command]
pub fn claude_agents() -> Result<serde_json::Value, String> {
    run_json(Path::new("claude"), &["agents", "--json"])
}

/// Repositories directly under a folder — the product folder, in one level.
///
/// A repository is a directory carrying `.devflow/project.yml`. Anything else
/// in the folder is not this application's business, and going deeper than one
/// level would start walking node_modules.
#[tauri::command]
pub fn discover_repos(folder: String) -> Result<Vec<String>, String> {
    let dir = Path::new(&folder);
    if !dir.is_dir() {
        return Err(format!("{folder} is not a directory"));
    }
    let mut out: Vec<String> = Vec::new();
    if dir.join(".devflow/project.yml").is_file() {
        out.push(folder.clone());
    }
    for entry in std::fs::read_dir(dir).map_err(|e| e.to_string())?.flatten() {
        let p = entry.path();
        if p.is_dir() && p.join(".devflow/project.yml").is_file() {
            out.push(p.to_string_lossy().to_string());
        }
    }
    out.sort();
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The plugin is installed by version and the path moves on every release,
    /// so this resolution is the one thing here that breaks quietly. The test
    /// asserts what can be asserted on any machine: if a plugin is installed at
    /// all, we find a real executable, and it is the newest one present.
    #[test]
    fn finds_the_newest_installed_engine() {
        let home = match std::env::var("HOME") {
            Ok(h) => h,
            Err(_) => return,
        };
        let dir = Path::new(&home).join(".claude/plugins/cache/devflow/devflow");
        if !dir.is_dir() {
            return; // nothing installed on this machine; nothing to assert
        }
        let installed: Vec<String> = std::fs::read_dir(&dir)
            .unwrap()
            .flatten()
            .filter(|e| e.path().join("bin/devflow").is_file())
            .map(|e| e.file_name().to_string_lossy().to_string())
            .collect();
        if installed.is_empty() {
            return; // versions present but none ships the CLI yet
        }
        let found = devflow_bin().expect("a bin/devflow exists, so one must be found");
        assert!(found.is_file(), "{} is not a file", found.display());

        // Newest wins, compared as numbers rather than as text: 0.9.0 must not
        // beat 0.42.1, which is exactly what a string sort would do.
        let mut keys: Vec<Vec<u64>> = installed
            .iter()
            .map(|v| v.split('.').map(|p| p.parse().unwrap_or(0)).collect())
            .collect();
        keys.sort();
        let newest = keys.pop().unwrap();
        let picked: Vec<u64> = found
            .parent()
            .unwrap()
            .parent()
            .unwrap()
            .file_name()
            .unwrap()
            .to_string_lossy()
            .split('.')
            .map(|p| p.parse().unwrap_or(0))
            .collect();
        assert_eq!(picked, newest, "picked {picked:?}, newest installed is {newest:?}");
    }

    #[test]
    fn a_folder_that_is_not_a_directory_is_refused() {
        let err = discover_repos("/nonexistent/folder".into()).unwrap_err();
        assert!(err.contains("not a directory"), "unexpected message: {err}");
    }
}
