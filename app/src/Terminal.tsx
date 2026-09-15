// A terminal pane: xterm.js over a pseudo-terminal running `claude attach`.
//
// The session outlives the pane. Closing this component ends the attachment,
// not the work — measured before the pane was written, and it is what makes
// closing a pane an ordinary gesture rather than a destructive one.
//
// Two things here are easy to get wrong and both are visible immediately.
//
// Sizing: a full-screen terminal interface draws to whatever size the
// pseudo-terminal claims to be, so a pane opened before layout settles fixes
// the session at the wrong number of rows and leaves the bottom off-screen.
//
// Resizing: fitting the terminal changes the canvas, which can add or remove a
// scrollbar, which changes the element, which asks us to fit again. Left alone
// that loop sends a size change to the session several times a second, and the
// program on the other end redraws its input box on every one of them — which
// is what a "the input keeps gaining blank lines" bug actually is. The fit is
// therefore never allowed to trigger its own observer.

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
    let fitting = false;
    let pending: number | undefined;
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

    // Fit, and tell the session only when the answer actually changed. The
    // `fitting` flag is what breaks the loop: everything the fit does to the
    // DOM lands while the observer is ignoring itself.
    const sync = (): boolean => {
      if (fitting || disposed) return false;
      if (element.clientWidth < 8 || element.clientHeight < 8) return false;
      fitting = true;
      try {
        fit.fit();
      } catch {
        fitting = false;
        return false;
      }
      const rows = term.rows;
      const cols = term.cols;
      requestAnimationFrame(() => {
        fitting = false;
      });
      if (rows === sent.rows && cols === sent.cols) return true;
      sent = { rows, cols };
      if (pane !== null) void paneResize(pane, rows, cols);
      return true;
    };

    // A window drag produces a size change per frame; the session only needs
    // the one at the end of it.
    const scheduleSync = () => {
      window.clearTimeout(pending);
      pending = window.setTimeout(sync, 80);
    };

    (async () => {
      // Wait for layout. Opening against an element with no height would fix
      // the session at the default 24 rows for good.
      for (let attempt = 0; attempt < 90 && !sync(); attempt++) {
        await new Promise((r) => requestAnimationFrame(r));
        if (disposed) return;
      }
      if (disposed) return;

      try {
        pane = await paneOpen(session, term.rows, term.cols);
        sent = { rows: term.rows, cols: term.cols };
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

        // Typing has to reach the session without a click first: the pane was
        // opened deliberately, so it is what the keyboard belongs to.
        term.focus();
      } catch (err) {
        onError(String(err));
      }
    })();

    const observer = new ResizeObserver(scheduleSync);
    observer.observe(element);
    window.addEventListener("resize", scheduleSync);

    return () => {
      disposed = true;
      window.clearTimeout(pending);
      window.removeEventListener("resize", scheduleSync);
      observer.disconnect();
      unlisten.forEach((u) => u());
      if (pane !== null) void paneClose(pane);
      onPane(null);
      term.dispose();
    };
  }, [session]);

  // Clicking anywhere in the pane puts the keyboard back in the terminal.
  return <div className="terminal-host" ref={host} onMouseDown={() => host.current?.querySelector<HTMLTextAreaElement>(".xterm-helper-textarea")?.focus()} />;
}
