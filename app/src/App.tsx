// One tree over several repositories, and one pane showing whichever thing was
// picked from it — a session's terminal, or a file.
//
// The order of the left pane is the argument: what is waiting on a person comes
// before what is merely running, and both come before the repositories they
// belong to. A window that lists everything equally is the flat list this one
// exists to replace.

import { useCallback, useEffect, useMemo, useState } from "react";
import { open as openDialog } from "@tauri-apps/plugin-dialog";
import {
  claudeAgents,
  engineStatus,
  groupRepos,
  groupsLoad,
  groupsSave,
  type Group,
  type Repo,
  type Session,
  type Status,
  type Ticket,
} from "./engine";
import { TerminalPane } from "./Terminal";
import { DocumentPane } from "./Document";
import "./App.css";

const POLL_MS = 2500;

type Showing =
  | { kind: "session"; session: Session }
  | { kind: "file"; path: string; title: string }
  | null;

/// What a ticket is waiting for, if it is waiting for a person at all.
function waitingOn(t: Ticket): string | null {
  if (t.status === "blocked") return "an answer";
  if (t.contract.state === "draft") return "contract approval";
  if (t.acceptance_state === "reported" || t.status === "awaiting review") return "acceptance";
  if (t.contract.state === "none" && t.status !== "done" && t.status !== "cancelled")
    return "a contract";
  return null;
}

function ticketNote(t: Ticket): string {
  const bits: string[] = [];
  if (t.acceptance.total > 0) bits.push(`${t.acceptance.checked}/${t.acceptance.total}`);
  if (t.lock) bits.push(t.lock.owner);
  if (t.blocked_by.length > 0) bits.push(`after ${t.blocked_by.join(", ")}`);
  return bits.join(" · ");
}

const newId = () => Math.random().toString(36).slice(2, 10);

export default function App() {
  const [groups, setGroups] = useState<Group[]>([]);
  const [reposByGroup, setReposByGroup] = useState<Record<string, string[]>>({});
  const [status, setStatus] = useState<Status | null>(null);
  const [sessions, setSessions] = useState<Session[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [showing, setShowing] = useState<Showing>(null);
  const [, setPane] = useState<number | null>(null);

  // ── what is watched ───────────────────────────────────────────────────────

  useEffect(() => {
    groupsLoad()
      .then((g) => setGroups(g.groups ?? []))
      .catch((e) => setError(String(e)));
  }, []);

  const persist = useCallback((next: Group[]) => {
    setGroups(next);
    groupsSave(next).catch((e) => setError(String(e)));
  }, []);

  const addGroup = useCallback(async () => {
    // Picking a folder is the common case, so it is the same gesture as adding
    // a group. Cancelling still makes the group — an empty one you fill by hand
    // is a legitimate thing to want.
    const picked = await openDialog({
      directory: true,
      multiple: false,
      title: "Folder for the group",
    });
    const folder = typeof picked === "string" ? picked : null;
    const name = folder ? folder.split("/").filter(Boolean).pop()! : "Group";
    persist([...groups, { id: newId(), name, repos: [], folder, open: true }]);
  }, [groups, persist]);

  const addRepo = useCallback(
    async (group: Group) => {
      const picked = await openDialog({ directory: true, multiple: true, title: "Repositories" });
      const paths = Array.isArray(picked) ? picked : typeof picked === "string" ? [picked] : [];
      if (paths.length === 0) return;
      persist(
        groups.map((g) =>
          g.id === group.id ? { ...g, repos: [...new Set([...g.repos, ...paths])] } : g,
        ),
      );
    },
    [groups, persist],
  );

  // ── state ─────────────────────────────────────────────────────────────────

  const refresh = useCallback(async () => {
    // Sessions first and unconditionally: they are what the window is opened
    // for, and they exist whether or not anything has been configured.
    try {
      setSessions(await claudeAgents());
    } catch (e) {
      setError(String(e));
    }

    try {
      const byGroup: Record<string, string[]> = {};
      for (const g of groups) byGroup[g.id] = await groupRepos(g);
      setReposByGroup(byGroup);
      const all = [...new Set(Object.values(byGroup).flat())];
      setStatus(all.length === 0 ? null : await engineStatus(all));
      setError(null);
    } catch (e) {
      setError(String(e));
    }
  }, [groups]);

  useEffect(() => {
    void refresh();
    const t = setInterval(() => void refresh(), POLL_MS);
    return () => clearInterval(t);
  }, [refresh]);

  const repoByPath = useMemo(() => {
    const m = new Map<string, Repo>();
    for (const r of status?.repos ?? []) m.set(r.path, r);
    return m;
  }, [status]);

  const live = useMemo(
    () =>
      sessions
        .filter((s) => s.live)
        .sort((a, b) => (a.name ?? a.id).localeCompare(b.name ?? b.id)),
    [sessions],
  );

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

  const openFile = (path: string, title: string) => setShowing({ kind: "file", path, title });

  // ── the window ────────────────────────────────────────────────────────────

  return (
    <div className="app">
      <header className="bar">
        <span className="brand">devflow</span>
        <span className="spacer" />
        <span className="generated">
          {status ? new Date(status.generated_at).toLocaleTimeString() : ""}
        </span>
      </header>

      {error && (
        <div className="error" onClick={() => setError(null)} title="Click to dismiss">
          {error}
        </div>
      )}

      <div className="body">
        <aside className="tree">
          {attention.length > 0 && (
            <section className="group attention">
              <h2>
                Waiting on you<span className="count">{attention.length}</span>
              </h2>
              {attention.map(({ repo, ticket, why }) => (
                <div
                  className="row waiting"
                  key={`${repo.path}/${ticket.id}`}
                  onClick={() => openFile(ticket.path, ticket.id)}
                  title={ticket.title ?? ticket.id}
                >
                  <span className="id">{ticket.id}</span>
                  <span className="why">{why}</span>
                  <span className="where">{repo.name}</span>
                </div>
              ))}
            </section>
          )}

          <section className="group">
            <h2>
              Sessions<span className="count">{live.length}</span>
            </h2>
            {live.length === 0 && <div className="empty">none running</div>}
            {live.map((s) => {
              const attachable = s.kind === "background";
              const on = showing?.kind === "session" && showing.session.session_id === s.session_id;
              return (
                <div
                  key={s.session_id}
                  className={`row session ${on ? "on" : ""} ${attachable ? "" : "external"}`}
                  onClick={() => attachable && setShowing({ kind: "session", session: s })}
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

          {groups.map((g) => (
            <section className="group" key={g.id}>
              <h2>
                <button
                  className="twisty"
                  onClick={() =>
                    persist(groups.map((x) => (x.id === g.id ? { ...x, open: !x.open } : x)))
                  }
                >
                  {g.open ? "▾" : "▸"} {g.name}
                </button>
                <button
                  className="tiny"
                  title="Add repositories to this group"
                  onClick={() => void addRepo(g)}
                >
                  +
                </button>
                <button
                  className="tiny"
                  title="Remove this group — the repositories themselves are untouched"
                  onClick={() => persist(groups.filter((x) => x.id !== g.id))}
                >
                  −
                </button>
              </h2>

              {g.open &&
                (reposByGroup[g.id] ?? []).map((path) => {
                  const r = repoByPath.get(path);
                  const name = path.split("/").filter(Boolean).pop()!;
                  return (
                    <div key={path}>
                      <div className="repo">
                        <span className="id">{name}</span>
                        <span className="where">{r ? (r.branch ?? "not a repository") : "…"}</span>
                      </div>
                      {r && !r.engine && <div className="empty">engine not set up here</div>}
                      {r?.maps.map((m) => (
                        <div key={m.path}>
                          <div
                            className="effort"
                            onClick={() => openFile(`${m.path}/map.md`, m.slug)}
                            title="Open the map"
                          >
                            {m.slug}
                          </div>
                          {m.tickets
                            .filter((t) => t.status !== "done" && t.status !== "cancelled")
                            .map((t) => (
                              <div
                                className={`row ticket ${
                                  showing?.kind === "file" && showing.path === t.path ? "on" : ""
                                }`}
                                key={t.path}
                                onClick={() => openFile(t.path, t.id)}
                                title={t.title ?? t.id}
                              >
                                <span className="id">{t.id}</span>
                                <span className="why">{t.status ?? "?"}</span>
                                <span className="where">{ticketNote(t)}</span>
                              </div>
                            ))}
                        </div>
                      ))}
                    </div>
                  );
                })}

              {g.open && (reposByGroup[g.id] ?? []).length === 0 && (
                <div className="empty">
                  {g.folder ? "nothing with devflow in that folder" : "no repositories yet"}
                </div>
              )}
            </section>
          ))}

          <button className="add" onClick={() => void addGroup()}>
            + group
          </button>
        </aside>

        <main className="pane">
          {showing?.kind === "session" ? (
            <>
              <div className="pane-head">
                <span className="id">{showing.session.name ?? showing.session.id}</span>
                <span className="where">{showing.session.cwd}</span>
                <CloseButton onClick={() => setShowing(null)} />
              </div>
              <TerminalPane
                key={showing.session.session_id}
                session={showing.session.id}
                onPane={setPane}
                onError={setError}
              />
            </>
          ) : showing?.kind === "file" ? (
            <>
              <div className="pane-head">
                <span className="id">{showing.title}</span>
                <span className="where">{showing.path}</span>
                <CloseButton onClick={() => setShowing(null)} />
              </div>
              <DocumentPane key={showing.path} path={showing.path} onError={setError} />
            </>
          ) : (
            <div className="empty hint">
              Pick a session to open its terminal, or a ticket to read it. Sessions started
              outside this window are listed but cannot be attached.
            </div>
          )}
        </main>
      </div>
    </div>
  );
}

function CloseButton({ onClick }: { onClick: () => void }) {
  return (
    <button
      className="close"
      title="Close the pane — a session keeps running"
      aria-label="Close the pane"
      onClick={onClick}
    >
      <svg width="12" height="12" viewBox="0 0 12 12" aria-hidden="true">
        <path d="M1.5 1.5 L10.5 10.5 M10.5 1.5 L1.5 10.5" />
      </svg>
    </button>
  );
}
