//! What the running sessions cost, and what is left of the account's limits.
//!
//! Two different questions with two different answers, kept apart on purpose.
//!
//! The machine's side — how much processor and memory the live sessions take —
//! is read from the process table. The account's side — how much of the
//! five-hour and weekly allowance is spent — is not on this machine at all: it
//! is answered by Claude Code itself, over the control protocol every SDK
//! speaks, and there is no file or CLI flag that carries it.
//!
//! That protocol is JSON over the stdin of a session started in streaming mode.
//! Asking for it costs one short-lived session, about two seconds, so it is
//! polled on its own slow clock rather than with the tree.

use serde::Serialize;
use std::io::Write;
use std::process::{Command, Stdio};

#[derive(Serialize)]
pub struct Limit {
    /// `session`, `weekly_all`, `weekly_scoped` — passed through rather than
    /// renamed, so a new kind appears in the window instead of vanishing.
    pub kind: String,
    pub group: String,
    pub percent: i64,
    pub severity: String,
    pub resets_at: Option<String>,
    /// The model a scoped limit applies to, when it applies to one.
    pub scope: Option<String>,
}

#[derive(Serialize)]
pub struct Load {
    pub sessions: usize,
    pub cpu_percent: f64,
    /// Summed resident memory of the live sessions, in megabytes.
    ///
    /// Summed, and therefore an over-estimate: memory shared between processes
    /// is counted once per process. The honest alternative costs a `footprint`
    /// call per process and seconds of wall time, which is the wrong trade for
    /// a number that updates every few seconds. Read it as an upper bound.
    pub memory_mb: u64,
}

/// Processor and resident memory of the given pids, from the process table.
#[tauri::command]
pub fn session_load(pids: Vec<u32>) -> Result<Load, String> {
    if pids.is_empty() {
        return Ok(Load { sessions: 0, cpu_percent: 0.0, memory_mb: 0 });
    }
    let mut cmd = Command::new("ps");
    cmd.arg("-o").arg("pid=,pcpu=,rss=");
    for pid in &pids {
        cmd.arg("-p").arg(pid.to_string());
    }
    let out = cmd.output().map_err(|e| format!("could not read the process table: {e}"))?;
    let text = String::from_utf8_lossy(&out.stdout);

    let mut cpu = 0.0f64;
    let mut rss_kb = 0u64;
    let mut seen = 0usize;
    for line in text.lines() {
        let mut f = line.split_whitespace();
        let (_pid, c, r) = (f.next(), f.next(), f.next());
        if let (Some(c), Some(r)) = (c, r) {
            cpu += c.parse::<f64>().unwrap_or(0.0);
            rss_kb += r.parse::<u64>().unwrap_or(0);
            seen += 1;
        }
    }
    Ok(Load { sessions: seen, cpu_percent: (cpu * 10.0).round() / 10.0, memory_mb: rss_kb / 1024 })
}

/// The account's rate limits, asked of Claude Code over the control protocol.
///
/// A session is started in streaming mode, one control request is written to
/// its stdin, and the first control response is read back. The limits are an
/// account-wide fact, so one call answers for every session the window shows.
///
/// Deliberately not `--bare`: that mode answers in a second but authenticates
/// differently and comes back with no limits at all.
#[tauri::command]
pub fn account_limits() -> Result<Vec<Limit>, String> {
    let mut child = Command::new("claude")
        .args([
            "-p",
            "--verbose",
            "--input-format",
            "stream-json",
            "--output-format",
            "stream-json",
        ])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .map_err(|e| format!("could not ask claude for the limits: {e}"))?;

    child
        .stdin
        .take()
        .ok_or_else(|| "no stdin on the probe".to_string())?
        .write_all(
            br#"{"request_id":"limits","type":"control_request","request":{"subtype":"get_usage"}}
"#,
        )
        .map_err(|e| format!("could not send the request: {e}"))?;

    let out = child
        .wait_with_output()
        .map_err(|e| format!("the limits probe did not finish: {e}"))?;
    let text = String::from_utf8_lossy(&out.stdout);

    let line = text
        .lines()
        .find(|l| l.contains("\"control_response\""))
        .ok_or_else(|| "claude answered without a control response".to_string())?;
    let v: serde_json::Value =
        serde_json::from_str(line).map_err(|e| format!("the answer was not JSON: {e}"))?;

    let limits = v
        .pointer("/response/response/rate_limits/limits")
        .and_then(|l| l.as_array())
        .ok_or_else(|| "this account reports no rate limits".to_string())?;

    Ok(limits
        .iter()
        .map(|l| Limit {
            kind: l["kind"].as_str().unwrap_or("").to_string(),
            group: l["group"].as_str().unwrap_or("").to_string(),
            percent: l["percent"].as_i64().unwrap_or(0),
            severity: l["severity"].as_str().unwrap_or("normal").to_string(),
            resets_at: l["resets_at"].as_str().map(str::to_string),
            scope: l
                .pointer("/scope/model/display_name")
                .and_then(|s| s.as_str())
                .map(str::to_string),
        })
        .collect())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn no_pids_is_not_an_error() {
        let load = session_load(vec![]).unwrap();
        assert_eq!(load.sessions, 0);
        assert_eq!(load.memory_mb, 0);
    }

    #[test]
    fn a_pid_that_is_gone_contributes_nothing() {
        // 999999 is above the default pid ceiling, so it cannot be running.
        let load = session_load(vec![999_999]).unwrap();
        assert_eq!(load.sessions, 0);
    }

    #[test]
    fn this_process_is_measurable() {
        let me = std::process::id();
        let load = session_load(vec![me]).unwrap();
        assert_eq!(load.sessions, 1);
        assert!(load.memory_mb > 0, "our own process reports no memory");
    }
}
