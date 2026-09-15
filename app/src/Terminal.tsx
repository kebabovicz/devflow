// A terminal pane: xterm.js over a pseudo-terminal running `claude attach`.
//
// The session outlives the pane. Closing this component ends the attachment,
// not the work — measured before the pane was written, and it is what makes
// closing a pane an ordinary gesture rather than a destructive one.

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
    if (!host.current) return;
    let pane: number | null = null;
    let disposed = false;
    const unlisten: Array<() => void> = [];

    const term = new Terminal({
      fontFamily: 'ui-monospace, SFMono-Regular, "SF Mono", Menlo, monospace',
      fontSize: 12,
      allowProposedApi: true,
      // The window paints its own material behind the page; a transparent
      // background lets that through instead of stacking another black layer.
      theme: { background: "#00000000", foreground: "#e6e6e6" },
      cursorBlink: true,
      scrollback: 20000,
    });
    const fit = new FitAddon();
    term.loadAddon(fit);
    term.open(host.current);
    fit.fit();

    (async () => {
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
      } catch (err) {
        onError(String(err));
      }
    })();

    const onResize = () => {
      fit.fit();
      if (pane !== null) void paneResize(pane, term.rows, term.cols);
    };
    window.addEventListener("resize", onResize);
    const observer = new ResizeObserver(onResize);
    observer.observe(host.current);

    return () => {
      disposed = true;
      window.removeEventListener("resize", onResize);
      observer.disconnect();
      unlisten.forEach((u) => u());
      if (pane !== null) void paneClose(pane);
      onPane(null);
      term.dispose();
    };
  }, [session]);

  return <div className="terminal-host" ref={host} />;
}
