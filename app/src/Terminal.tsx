// A terminal pane: xterm.js over a pseudo-terminal running `claude attach`.
//
// The session outlives the pane. Closing this component ends the attachment,
// not the work — measured before the pane was written, and it is what makes
// closing a pane an ordinary gesture rather than a destructive one.
//
// Sizing is the part that has to be exactly right. A full-screen terminal
// interface draws to the size the pseudo-terminal claims to be, so a pane
// opened with a stale row count paints rows that fall off the bottom of the
// window and never come back. The pane is therefore not opened until the
// element has a real size, and every later size change is sent through.

import { useEffect, useRef } from "react";
import { Terminal } from "@xterm/xterm";
import { FitAddon } from "@xterm/addon-fit";
import { listen } from "@tauri-apps/api/event";
import "@xterm/xterm/css/xterm.css";
import { paneClose, paneOpen, paneResize, paneWrite } from "./engine";

const encode = (s: string) => btoa(String.fromCharCode(...new TextEncoder().encode(s)));
const decode = (s: string) => Uint8Array.from(atob(s), (c) => c.charCodeAt(0));

export function TerminalPane({
  session,
  onPane,
  onError,
}: {
  session: string;
  onPane: (pane: number | null) => void;
  onError: (message: string) => void;
}) {
  const host = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const element = host.current;
    if (!element) return;
    let pane: number | null = null;
    let disposed = false;
    let sent = { rows: 0, cols: 0 };
    const unlisten: Array<() => void> = [];

    const term = new Terminal({
      fontFamily: 'ui-monospace, SFMono-Regular, "SF Mono", Menlo, monospace',
      fontSize: 12,
      lineHeight: 1.2,
      allowProposedApi: true,
      theme: { background: "#00000000", foreground: "#e6e6e6" },
      cursorBlink: true,
      scrollback: 20000,
    });
    const fit = new FitAddon();
    term.loadAddon(fit);
    term.open(element);

    // Tell the pseudo-terminal what the pane actually is, and only when it
    // changed — a resize storm during a window drag would otherwise send one
    // call per frame.
    const sync = () => {
      if (element.clientWidth === 0 || element.clientHeight === 0) return false;
      try {
        fit.fit();
      } catch {
        return false;
      }
      if (term.rows === sent.rows && term.cols === sent.cols) return true;
      sent = { rows: term.rows, cols: term.cols };
      if (pane !== null) void paneResize(pane, term.rows, term.cols);
      return true;
    };

    (async () => {
      // Wait for layout. Opening against a zero-height element would fix the
      // session at 24 rows and leave the bottom of its interface off-screen.
      for (let attempt = 0; attempt < 60 && !sync(); attempt++) {
        await new Promise((r) => requestAnimationFrame(r));
      }
      if (disposed) return;

      try {
        pane = await paneOpen(session, term.rows, term.cols);
        if (disposed) {
          await paneClose(pane);
          return;
        }
        onPane(pane);

        unlisten.push(
          await listen<{ pane: number; data: string }>("pane:data", (e) => {
            if (e.payload.pane === pane) term.write(decode(e.payload.data));
          }),
        );
        unlisten.push(
          await listen<{ pane: number }>("pane:closed", (e) => {
            if (e.payload.pane === pane) {
              term.writeln("\r\n\x1b[2m— the attachment ended; the session keeps running —\x1b[0m");
            }
          }),
        );

        term.onData((data) => {
          if (pane !== null) void paneWrite(pane, encode(data));
        });

        // One more pass once the session is attached: the first paint can
        // change the scrollbar, and with it the width.
        sync();
      } catch (err) {
        onError(String(err));
      }
    })();

    const observer = new ResizeObserver(() => sync());
    observer.observe(element);
    window.addEventListener("resize", sync);

    return () => {
      disposed = true;
      window.removeEventListener("resize", sync);
      observer.disconnect();
      unlisten.forEach((u) => u());
      if (pane !== null) void paneClose(pane);
      onPane(null);
      term.dispose();
    };
  }, [session]);

  return <div className="terminal-host" ref={host} />;
}
