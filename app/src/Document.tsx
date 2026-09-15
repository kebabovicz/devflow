// Reading a markdown file in the window: a ticket, a map, a design note.
//
// Two views of one file, because they answer different questions. Rendered is
// for reading what it says; raw is for seeing what is actually written —
// which header a ticket carries, whether a checkbox is ticked, where a line
// break really is. A ticket is a document a person reads and a machine parses,
// and both readings have to be available.

import { useEffect, useMemo, useState } from "react";
import { marked } from "marked";
import { readText } from "./engine";

type View = "rendered" | "raw";

export function DocumentPane({ path, onError }: { path: string; onError: (m: string) => void }) {
  const [text, setText] = useState<string | null>(null);
  const [view, setView] = useState<View>("rendered");

  useEffect(() => {
    let dropped = false;
    setText(null);
    readText(path)
      .then((t) => {
        if (!dropped) setText(t);
      })
      .catch((e) => onError(String(e)));
    return () => {
      dropped = true;
    };
  }, [path]);

  const html = useMemo(() => {
    if (text === null) return "";
    // The file comes off this machine's own disk, written by the person using
    // the window or by a session they started; it is not remote content.
    return marked.parse(text, { async: false, gfm: true, breaks: false }) as string;
  }, [text]);

  const lines = useMemo(() => (text === null ? [] : text.split("\n")), [text]);

  return (
    <>
      <div className="doc-head">
        <div className="views">
          <button className={view === "rendered" ? "on" : ""} onClick={() => setView("rendered")}>
            Rendered
          </button>
          <button className={view === "raw" ? "on" : ""} onClick={() => setView("raw")}>
            Raw
          </button>
        </div>
      </div>
      {text === null ? (
        <div className="empty hint">reading…</div>
      ) : view === "rendered" ? (
        <div className="doc rendered" dangerouslySetInnerHTML={{ __html: html }} />
      ) : (
        <div className="doc raw">
          <table>
            <tbody>
              {lines.map((line, i) => (
                <tr key={i}>
                  <td className="ln">{i + 1}</td>
                  <td className="src">{line || " "}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </>
  );
}
