// One tree over several repositories, and a terminal on the session doing the
// work. The point of the layout is the first column of the left pane: what is
// waiting on a person, ahead of everything that is merely in flight.

import { useCallback, useEffect, useMemo, useState } from "react";
import { discoverRepos, engineStatus, type Repo, type Session, type Status, type Ticket } from "./engine";
import { TerminalPane } from "./Terminal";
import "./App.css";

const FOLDER_KEY = "devflow.productFolder";
const POLL_MS = 2500;

/// What a ticket is waiting for, if it is waiting for a person at all.
function waitingOn(t: Ticket): string | null {
  if (t.status === "blocked") return "an answer";
  if (t.contract.state === "draft") return "contract approval";
  if (t.acceptance_state === "reported" || t.status === "awaiting review") return "acceptance";
  return null;
}

function ticketBadges(t: Ticket): string[] {
  const out: string[] = [];
  if (t.acceptance.total > 0) out.push(`${t.acceptance.checked}/${t.acceptance.total}`);
  if (t.contract.state === "draft") out.push("draft contract");
  if (t.contract.state === "none") out.push("no contract");
  if (t.blocked_by.length > 0) out.push(`blocked by ${t.blocked_by.join(", ")}`);
  return out;
}

export default function App() {
  const [folder, setFolder] = useState(() => localStorage.getItem(FOLDER_KEY) ?? "");
  const [draftFolder, setDraftFolder] = useState(folder);
  const [status, setStatus] = useState<Status | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [selected, setSelected] = useState<Session | null>(null);
  const [, setPane] = useState<number | null>(null);

  const refresh = useCallback(async () => {
    if (!folder) return;
    try {
      const repos = await discoverRepos(folder);
      const next = await engineStatus(repos);
      setStatus(next);
      setError(null);
    } catch (e) {
      setError(String(e));
    }
  }, [folder]);

  useEffect(() => {
    void refresh();
    const t = setInterval(() => void refresh(), POLL_MS);
    return () => clearInterval(t);
  }, [refresh]);

  const sessions = useMemo(() => {
    const seen = new Map<string, Session>();
    for (const r of status?.repos ?? []) {
      for (const s of r.sessions) if (s.live) seen.set(s.session_id, s);
    }
    return [...seen.values()].sort((a, b) => (a.name ?? "").localeCompare(b.name ?? ""));
  }, [status]);

  const attention = useMemo(() => {
    const out: Array<{ repo: Repo; ticket: Ticket; why: string }> = [];
    for (const r of status?.repos ?? []) {
      for (const m of r.maps) {
        for (const t of m.tickets) {
          const why = waitingOn(t);
          if (why) out.push({ repo: r, ticket: t, why });
        }
      }
    }
    return out;
  }, [status]);

  return (
    <div className="app">
      <header className="bar">
        <span className="brand">devflow</span>
        <input
          className="folder"
          placeholder="path to the folder holding your repositories"
          value={draftFolder}
          onChange={(e) => setDraftFolder(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter") {
              localStorage.setItem(FOLDER_KEY, draftFolder);
              setFolder(draftFolder);
            }
          }}
        />
        <span className="generated">
          {status ? new Date(status.generated_at).toLocaleTimeString() : "—"}
        </span>
      </header>

      {error && <div className="error">{error}</div>}

      <div className="body">
        <aside className="tree">
          {attention.length > 0 && (
            <section className="group attention">
              <h2>Waiting on you</h2>
              {attention.map(({ repo, ticket, why }) => (
                <div className="row waiting" key={`${repo.path}/${ticket.id}`}>
                  <span className="id">{ticket.id}</span>
                  <span className="why">{why}</span>
                  <span className="where">{repo.name}</span>
                </div>
              ))}
            </section>
          )}

          <section className="group">
            <h2>Sessions</h2>
            {sessions.length === 0 && <div className="empty">none running</div>}
            {sessions.map((s) => {
              const attachable = s.kind === "background";
              return (
                <div
                  key={s.session_id}
                  className={`row session ${selected?.session_id === s.session_id ? "on" : ""} ${
                    attachable ? "" : "external"
                  }`}
                  onClick={() => attachable && setSelected(s)}
                  title={attachable ? s.cwd : `${s.cwd} — started outside this window, view only`}
                >
                  <span className={`dot ${s.status ?? "idle"}`} />
                  <span className="id">{s.name ?? s.id}</span>
                  <span className="why">{s.status ?? ""}</span>
                  <span className="where">{s.cwd.split("/").pop()}</span>
                </div>
              );
            })}
          </section>

          {(status?.repos ?? []).map((r) => (
            <section className="group" key={r.path}>
              <h2>
                {r.name}
                <span className="branch">{r.branch ?? "not a repository"}</span>
              </h2>
              {!r.engine && <div className="empty">engine not set up here</div>}
              {r.maps.map((m) => (
                <div key={m.path}>
                  <div className="effort">{m.slug}</div>
                  {m.tickets
                    .filter((t) => t.status !== "done" && t.status !== "cancelled")
                    .map((t) => (
                      <div className="row ticket" key={t.path} title={t.title ?? t.id}>
                        <span className="id">{t.id}</span>
                        <span className="why">{t.status ?? "?"}</span>
                        <span className="where">{ticketBadges(t).join(" · ")}</span>
                      </div>
                    ))}
                </div>
              ))}
            </section>
          ))}

          {!folder && (
            <div className="empty hint">
              Type the folder that holds your repositories above and press Enter.
            </div>
          )}
        </aside>

        <main className="pane">
          {selected ? (
            <>
              <div className="pane-head">
                <span className="id">{selected.name ?? selected.id}</span>
                <span className="where">{selected.cwd}</span>
                <button onClick={() => setSelected(null)}>close</button>
              </div>
              <TerminalPane
                key={selected.session_id}
                session={selected.id}
                onPane={setPane}
                onError={setError}
              />
            </>
          ) : (
            <div className="empty hint">
              Pick a background session on the left to open it here. Sessions started
              outside this window are listed but cannot be attached.
            </div>
          )}
        </main>
      </div>
    </div>
  );
}
