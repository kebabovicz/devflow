mod engine;
mod groups;
mod pty;

use std::sync::Arc;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_dialog::init())
        .manage(Arc::new(pty::Panes::default()))
        .setup(|app| {
            // Translucency is a platform effect, not a CSS one: the window has
            // to be transparent and the system has to paint its material behind
            // it. Anything but macOS gets an opaque window and the same layout.
            #[cfg(target_os = "macos")]
            {
                use tauri::Manager;
                if let Some(window) = app.get_webview_window("main") {
                    let _ = window_vibrancy::apply_vibrancy(
                        &window,
                        window_vibrancy::NSVisualEffectMaterial::UnderWindowBackground,
                        None,
                        None,
                    );
                }
            }
            let _ = app;
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            engine::engine_status,
            engine::claude_agents,
            engine::discover_repos,
            groups::groups_load,
            groups::groups_save,
            groups::group_repos,
            groups::read_text,
            pty::pane_open,
            pty::pane_write,
            pty::pane_send_line,
            pty::pane_resize,
            pty::pane_close,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
