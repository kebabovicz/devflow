//! Terminal panes.
//!
//! A pane is `claude attach <id>` running in a pseudo-terminal we own. Measured
//! before this was written: attaching that way works, input reaches the session,
//! and closing the pseudo-terminal leaves the session running — which is what
//! makes a closable pane safe. Claude Code prints its own detach affordance
//! (Ctrl-D twice) into the stream, so the pane does not have to invent one.
//!
//! Output is forwarded as raw bytes. It is a terminal stream — escape sequences,
//! alternate screen, the lot — and the only honest consumer of that is a
//! terminal emulator, which is why the frontend renders it with xterm.js rather
//! than trying to read it as text.

use portable_pty::{CommandBuilder, MasterPty, PtySize, native_pty_system};
use serde::Serialize;
use std::collections::HashMap;
use std::io::{Read, Write};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use tauri::{AppHandle, Emitter};

pub struct Pane {
    master: Box<dyn MasterPty + Send>,
    child: Box<dyn portable_pty::Child + Send + Sync>,
    /// Taken once, at open, and kept for the life of the pane.
    /// `take_writer` refuses a second call — "cannot take writer more than
    /// once" — so taking it per keystroke delivers the first character typed
    /// and silently drops every one after it.
    writer: Box<dyn Write + Send>,
}

#[derive(Default)]
pub struct Panes(pub Mutex<HashMap<u64, Pane>>);

static NEXT_ID: AtomicU64 = AtomicU64::new(1);

#[derive(Clone, Serialize)]
pub struct Chunk {
    pub pane: u64,
    /// Bytes as they came off the pseudo-terminal, base64 so that a half-read
    /// multi-byte character or a stray control byte survives the trip to the
    /// frontend intact. Reassembling UTF-8 is the emulator's job.
    pub data: String,
}

#[derive(Clone, Serialize)]
pub struct Closed {
    pub pane: u64,
}

fn b64(bytes: &[u8]) -> String {
    const TABLE: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    let mut out = String::with_capacity((bytes.len() + 2) / 3 * 4);
    for chunk in bytes.chunks(3) {
        let b = [chunk[0], *chunk.get(1).unwrap_or(&0), *chunk.get(2).unwrap_or(&0)];
        let n = ((b[0] as u32) << 16) | ((b[1] as u32) << 8) | b[2] as u32;
        out.push(TABLE[(n >> 18) as usize & 63] as char);
        out.push(TABLE[(n >> 12) as usize & 63] as char);
        out.push(if chunk.len() > 1 { TABLE[(n >> 6) as usize & 63] as char } else { '=' });
        out.push(if chunk.len() > 2 { TABLE[n as usize & 63] as char } else { '=' });
    }
    out
}

fn unb64(s: &str) -> Vec<u8> {
    let mut rev = [255u8; 256];
    const TABLE: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    for (i, c) in TABLE.iter().enumerate() {
        rev[*c as usize] = i as u8;
    }
    let cleaned: Vec<u8> = s.bytes().filter(|c| rev[*c as usize] != 255).collect();
    let mut out = Vec::with_capacity(cleaned.len() / 4 * 3);
    for chunk in cleaned.chunks(4) {
        let mut n = 0u32;
        for (i, c) in chunk.iter().enumerate() {
            n |= (rev[*c as usize] as u32) << (18 - 6 * i);
        }
        out.push((n >> 16) as u8);
        if chunk.len() > 2 {
            out.push((n >> 8) as u8);
        }
        if chunk.len() > 3 {
            out.push(n as u8);
        }
    }
    out
}

/// Open a pane onto a background session.
///
/// Only background sessions can be attached — an interactive one belongs to the
/// terminal that started it. The application shows those too, but read-only,
/// and this call is where that distinction becomes visible as an error.
#[tauri::command]
pub fn pane_open(
    app: AppHandle,
    panes: tauri::State<'_, Arc<Panes>>,
    session: String,
    rows: u16,
    cols: u16,
) -> Result<u64, String> {
    let pty = native_pty_system();
    let pair = pty
        .openpty(PtySize { rows, cols, pixel_width: 0, pixel_height: 0 })
        .map_err(|e| format!("could not open a pseudo-terminal: {e}"))?;

    let mut cmd = CommandBuilder::new("claude");
    cmd.arg("attach");
    cmd.arg(&session);
    cmd.env("TERM", "xterm-256color");
    if let Ok(home) = std::env::var("HOME") {
        cmd.cwd(home);
    }

    let child = pair
        .slave
        .spawn_command(cmd)
        .map_err(|e| format!("could not attach to session {session}: {e}"))?;
    drop(pair.slave);

    let writer = pair
        .master
        .take_writer()
        .map_err(|e| format!("could not open the write side of the pane: {e}"))?;

    let id = NEXT_ID.fetch_add(1, Ordering::Relaxed);
    let mut reader = pair
        .master
        .try_clone_reader()
        .map_err(|e| format!("could not read the pseudo-terminal: {e}"))?;

    let app_for_thread = app.clone();
    std::thread::spawn(move || {
        let mut buf = [0u8; 8192];
        loop {
            match reader.read(&mut buf) {
                Ok(0) | Err(_) => break,
                Ok(n) => {
                    let chunk = Chunk { pane: id, data: b64(&buf[..n]) };
                    if app_for_thread.emit("pane:data", chunk).is_err() {
                        break;
                    }
                }
            }
        }
        let _ = app_for_thread.emit("pane:closed", Closed { pane: id });
    });

    panes
        .0
        .lock()
        .map_err(|_| "pane registry is poisoned".to_string())?
        .insert(id, Pane { master: pair.master, child, writer });
    Ok(id)
}

#[tauri::command]
pub fn pane_write(
    panes: tauri::State<'_, Arc<Panes>>,
    pane: u64,
    data: String,
) -> Result<(), String> {
    let mut guard = panes.0.lock().map_err(|_| "pane registry is poisoned".to_string())?;
    let entry = guard.get_mut(&pane).ok_or_else(|| format!("no pane {pane}"))?;
    entry
        .writer
        .write_all(&unb64(&data))
        .map_err(|e| format!("could not write to pane {pane}: {e}"))?;
    entry.writer.flush().ok();
    Ok(())
}

/// Send a line of text followed by Enter — what a drag-and-drop gesture turns
/// into. Kept apart from `pane_write` so a caller sending a command cannot
/// accidentally send a control sequence.
#[tauri::command]
pub fn pane_send_line(
    panes: tauri::State<'_, Arc<Panes>>,
    pane: u64,
    line: String,
) -> Result<(), String> {
    let mut payload = line.replace(['\r', '\n'], " ");
    payload.push('\r');
    pane_write(panes, pane, b64(payload.as_bytes()))
}

#[tauri::command]
pub fn pane_resize(
    panes: tauri::State<'_, Arc<Panes>>,
    pane: u64,
    rows: u16,
    cols: u16,
) -> Result<(), String> {
    let guard = panes.0.lock().map_err(|_| "pane registry is poisoned".to_string())?;
    let entry = guard.get(&pane).ok_or_else(|| format!("no pane {pane}"))?;
    entry
        .master
        .resize(PtySize { rows, cols, pixel_width: 0, pixel_height: 0 })
        .map_err(|e| format!("could not resize pane {pane}: {e}"))
}

/// Close the pane. The session keeps running — that was measured before any of
/// this was written, and it is the reason closing a pane is a safe gesture
/// rather than a destructive one.
#[tauri::command]
pub fn pane_close(panes: tauri::State<'_, Arc<Panes>>, pane: u64) -> Result<(), String> {
    let mut guard = panes.0.lock().map_err(|_| "pane registry is poisoned".to_string())?;
    if let Some(mut entry) = guard.remove(&pane) {
        let _ = entry.child.kill();
        let _ = entry.child.wait();
    }
    Ok(())
}
