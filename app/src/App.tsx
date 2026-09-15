// One tree over several repositories, and one pane showing whichever thing was
// picked from it — a session's terminal, or a file.
//
// The order of the left pane is the argument: what is waiting on a person comes
// before what is merely running, and both come before the repositories they
// belong to. A window that lists everything equally is the flat list this one
// exists to replace.

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  claudeAgents,
  engineStatus,
  groupRepos,
  groupsLoad,
  groupsSave,
  homeDir,
  accountLimits,
  sessionLoad,
  type Group,
  type Limit,
  type Load,
  type Repo,
  type Session,
  type Status,
  type Ticket,
} from "./engine";
import { TerminalPane } from "./Terminal";
import { DocumentPane } from "./Document";
import { TreeRow, type Row } from "./Tree";
import { AsideFoot, AsideHead } from "./Aside";
import "./App.css";

const POLL_MS = 2500;
// The limits cost a short-lived session to read, so they move on their own clock.
const LIMITS_MS = 5 * 60 * 1000;

/// A session belongs to the repository it stands in — or under it: a session
/// working in a worktree has its own directory inside the repository, not the
/// repository itself.
function sessionsUnder(all: Session[], repo: string): Session[] {
  return all.filter((s) => s.cwd === repo || s.cwd.startsWith(repo + "/"));
}


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

const newId = () => Math.random().toString(36).slice(2, 10);

export default function App() {
  const [groups, setGroups] = useState<Group[]>([]);
  const [reposByGroup, setReposByGroup] = useState<Record<string, string[]>>({});
  const [status, setStatus] = useState<Status | null>(null);
  const [sessions, setSessions] = useState<Session[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [showing, setShowing] = useState<Showing>(null);
  const [, setPane] = useState<number | null>(null);
  const [scrolled, setScrolled] = useState(false);
  const [closedDirs, setClosedDirs] = useState<Set<string>>(new Set());
  const [filter, setFilter] = useState("");
  const [home, setHome] = useState("");
  const [collapsed, setCollapsed] = useState(
    () => localStorage.getItem("devflow.treeCollapsed") === "1",
  );
  const [adding, setAdding] = useState<null | { to: Group | null }>(null);
  const [menu, setMenu] = useState<{ x: number; y: number; group: Group } | null>(null);
  const [load, setLoad] = useState<Load | null>(null);
  const [limits, setLimits] = useState<Limit[] | null>(null);
  const [limitsError, setLimitsError] = useState(false);
  const tree = useRef<HTMLDivElement>(null);

  // ── what is watched ───────────────────────────────────────────────────────

  useEffect(() => {
    homeDir()
      .then((h) => setHome(h.replace(/\/$/, "")))
      .catch(() => {});
  }, []);

  useEffect(() => {
    groupsLoad()
      .then((g) => setGroups(g.groups ?? []))
      .catch((e) => setError(String(e)));
  }, []);

  const persist = useCallback((next: Group[]) => {
    setGroups(next);
    groupsSave(next).catch((e) => setError(String(e)));
  }, []);

  const addGroup = useCallback(
    (path: string) => {
      const folder = path.trim().replace(/\/+$/, "");
      if (folder === "") return;
      const full = folder.startsWith("~") ? home + folder.slice(1) : folder;
      persist([
        ...groups,
        { id: newId(), name: full.split("/").filter(Boolean).pop() ?? "Group", repos: [], folder: full, open: true },
      ]);
    },
    [groups, home, persist],
  );

  const addRepo = useCallback(
    (group: Group, path: string) => {
      const p = path.trim().replace(/\/+$/, "");
      if (p === "") return;
      const full = p.startsWith("~") ? home + p.slice(1) : p;
      persist(
        groups.map((g) =>
          g.id === group.id ? { ...g, repos: [...new Set([...g.repos, full])] } : g,
        ),
      );
    },
    [groups, home, persist],
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

  useEffect(() => {
    const pids = sessions.filter((s) => s.pid !== null).map((s) => s.pid as number);
    sessionLoad(pids)
      .then(setLoad)
      .catch(() => setLoad(null));
  }, [sessions]);

  useEffect(() => {
    const ask = () =>
      accountLimits()
        .then((l) => {
          setLimits(l);
          setLimitsError(false);
        })
        .catch(() => setLimitsError(true));
    void ask();
    const t = setInterval(ask, LIMITS_MS);
    return () => clearInterval(t);
  }, []);

  const repoByPath = useMemo(() => {
    const m = new Map<string, Repo>();
    for (const r of status?.repos ?? []) m.set(r.path, r);
    return m;
  }, [status]);

  // Every session, running or finished. A finished background session keeps its
  // conversation and reopens on attach — measured, not assumed — so dropping it
  // here was throwing away most of what the window is for. Running ones come
  // first; the rest keep their names in order.
  const live = useMemo(() => {
    const rank = (s: Session) => (s.status === "busy" ? 0 : s.live ? 1 : 2);
    return [...sessions].sort(
      (a, b) => rank(a) - rank(b) || (a.name ?? a.id).localeCompare(b.name ?? b.id),
    );
  }, [sessions]);




  const watched = useMemo(
    () => [...new Set(Object.values(reposByGroup).flat())],
    [reposByGroup],
  );

  // A session in a directory no group watches is still running and still worth
  // reaching. Hiding it would make the window lie about what is going on.
  const elsewhere = useMemo(
    () => live.filter((s) => !watched.some((r) => s.cwd === r || s.cwd.startsWith(r + "/"))),
    [live, watched],
  );


  const rows = useMemo(() => {
    const out: Row[] = [];
    const waitingIn = (r?: Repo) =>
      r ? r.maps.flatMap((m) => m.tickets).filter((t) => waitingOn(t) !== null).length : 0;

    for (const g of groups) {
      const paths = reposByGroup[g.id] ?? [];
      const repos = paths.map((p) => repoByPath.get(p));
      out.push({
        kind: "group",
        depth: 0,
        key: `g:${g.id}`,
        name: g.name,
        open: g.open,
        group: g,
        waiting: repos.reduce((n, r) => n + waitingIn(r), 0),
        working: paths.reduce((n, p) => n + sessionsUnder(live, p).filter((s) => s.status === "busy").length, 0),
      });
      if (!g.open) continue;

      for (const path of paths) {
        const r = repoByPath.get(path);
        const mine = sessionsUnder(live, path);
        out.push({
          kind: "repo",
          depth: 1,
          key: `r:${g.id}:${path}`,
          name: path.split("/").filter(Boolean).pop()!,
          path,
          repo: r,
          waiting: waitingIn(r),
          working: mine.filter((s) => s.status === "busy").length,
        });
        for (const m of r?.maps ?? []) {
          for (const t of m.tickets) {
            if (t.status === "done" || t.status === "cancelled") continue;
            out.push({ kind: "ticket", depth: 2, key: `t:${t.path}`, ticket: t, waiting: waitingOn(t) });
          }
        }
        for (const sn of mine) {
          out.push({ kind: "session", depth: 2, key: `s:${g.id}:${sn.session_id}`, session: sn });
        }
      }
    }

    // Sessions no group covers are still work, and hiding them would make the
    // window disagree with `claude agents`. They are laid out the way that
    // command lays them out: by the directory they stand in.
    if (elsewhere.length > 0) {
      const byDir = new Map<string, Session[]>();
      for (const sn of elsewhere) {
        const list = byDir.get(sn.cwd) ?? [];
        list.push(sn);
        byDir.set(sn.cwd, list);
      }
      for (const [dir, list] of [...byDir.entries()].sort()) {
        const open = !closedDirs.has(dir);
        out.push({
          kind: "dir",
          depth: 0,
          key: `d:${dir}`,
          name: dir.replace(home, "~"),
          path: dir,
          open,
          working: list.filter((s) => s.status === "busy").length,
        });
        if (!open) continue;
        for (const sn of list) {
          out.push({ kind: "session", depth: 1, key: `s:else:${sn.session_id}`, session: sn });
        }
      }
    }
    // Filtering keeps the branch a match sits on: a hit with its parents
    // removed is a name with nowhere to stand.
    const q = filter.trim().toLowerCase();
    if (q === "") return out;
    const keep = new Set<number>();
    out.forEach((row, i) => {
      const text =
        row.kind === "ticket"
          ? `${row.ticket.id} ${row.ticket.title ?? ""}`
          : row.kind === "session"
            ? `${row.session.name ?? ""} ${row.session.cwd}`
            : row.name;
      if (!text.toLowerCase().includes(q)) return;
      keep.add(i);
      for (let j = i - 1, d = row.depth; j >= 0 && d > 0; j--) {
        if (out[j].depth < d) {
          keep.add(j);
          d = out[j].depth;
        }
      }
    });
    return out.filter((_, i) => keep.has(i));
  }, [groups, reposByGroup, repoByPath, live, elsewhere, closedDirs, home, filter]);

  const openFile = (path: string, title: string) => setShowing({ kind: "file", path, title });

  // ── the window ────────────────────────────────────────────────────────────

  return (
    <div className="app">
      <header className="bar" data-tauri-drag-region>
        <button
          className="fold"
          title={collapsed ? "Show the projects" : "Hide the projects"}
          aria-pressed={collapsed}
          onClick={() => {
            const next = !collapsed;
            setCollapsed(next);
            localStorage.setItem("devflow.treeCollapsed", next ? "1" : "0");
          }}
        >
          <svg viewBox="0 0 16 16" width="15" height="15" aria-hidden="true">
            <rect x="1.5" y="2.5" width="13" height="11" rx="2" />
            <path d="M6.5 2.5 V13.5" />
          </svg>
        </button>
        <span className="brand" data-tauri-drag-region>devflow</span>
        <span className="spacer" data-tauri-drag-region />
        <span className="generated" data-tauri-drag-region>
          {status ? new Date(status.generated_at).toLocaleTimeString() : ""}
        </span>
      </header>

      {error && (
        <div className="error" onClick={() => setError(null)} title="Click to dismiss">
          {error}
        </div>
      )}

      <div className="body">
        <aside className={`aside ${collapsed ? "folded" : ""}`}>
          <AsideHead
            filter={filter}
            onFilter={setFilter}
            onAddGroup={() => setAdding({ to: null })}
            onCollapseAll={() => persist(groups.map((g) => ({ ...g, open: false })))}
          />

          {adding && (
            <PathPrompt
              label={adding.to ? `Repository for ${adding.to.name}` : "Folder for a new group"}
              onCancel={() => setAdding(null)}
              onSubmit={(path) => {
                if (adding.to) addRepo(adding.to, path);
                else addGroup(path);
                setAdding(null);
              }}
            />
          )}

          <div
            className="tree"
            ref={tree}
            onScroll={(e) => setScrolled(e.currentTarget.scrollTop > 120)}
          >
          {rows.map((row) => (
            <TreeRow
              key={row.key}
              onMenu={(x, y) =>
                row.kind === "group" && row.group.id !== "elsewhere" && setMenu({ x, y, group: row.group })
              }
              row={row}
              selected={
                (row.kind === "ticket" &&
                  showing?.kind === "file" &&
                  showing.path === row.ticket.path) ||
                (row.kind === "session" &&
                  showing?.kind === "session" &&
                  showing.session.session_id === row.session.session_id)
              }
              onToggle={() => {
                if (row.kind === "dir") {
                  setClosedDirs((prev) => {
                    const next = new Set(prev);
                    next.has(row.path) ? next.delete(row.path) : next.add(row.path);
                    return next;
                  });
                }
                if (row.kind === "group") {
                  persist(groups.map((x) => (x.id === row.group.id ? { ...x, open: !x.open } : x)));
                }
              }}
              onPick={() => {
                if (row.kind === "ticket") openFile(row.ticket.path, row.ticket.id);
                if (row.kind === "session") setShowing({ kind: "session", session: row.session });
              }}
            />
          ))}

          </div>

          {/* Kept mounted so it can fade both ways, and out of the flow so the
              tree does not resize under the pointer when it appears. */}
          <div className="to-top-slot">
            <button
              className={`to-top ${scrolled ? "on" : ""}`}
              tabIndex={scrolled ? 0 : -1}
              aria-hidden={!scrolled}
              onClick={() => tree.current?.scrollTo({ top: 0, behavior: "smooth" })}
            >
              jump to top
            </button>
          </div>

          <AsideFoot load={load} limits={limits} limitsError={limitsError} />
        </aside>


        {menu && (
          <>
            <div className="scrim" onClick={() => setMenu(null)} onContextMenu={(e) => { e.preventDefault(); setMenu(null); }} />
            <div className="menu" style={{ left: menu.x, top: menu.y }}>
              <button
                onClick={() => {
                  const g = menu.group;
                  setMenu(null);
                  setAdding({ to: g });
                }}
              >
                Add repository…
              </button>
              <button
                className="danger"
                onClick={() => {
                  persist(groups.filter((x) => x.id !== menu.group.id));
                  setMenu(null);
                }}
              >
                Remove from pult
              </button>
            </div>
          </>
        )}

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
          ) : null}
        </main>
      </div>

    </div>
  );
}

function PathPrompt({
  label,
  onSubmit,
  onCancel,
}: {
  label: string;
  onSubmit: (path: string) => void;
  onCancel: () => void;
}) {
  const [value, setValue] = useState("");
  return (
    <div className="prompt">
      <label>{label}</label>
      <input
        autoFocus
        placeholder="~/projects"
        value={value}
        onChange={(e) => setValue(e.target.value)}
        onKeyDown={(e) => {
          if (e.key === "Enter") onSubmit(value);
          if (e.key === "Escape") onCancel();
        }}
        onBlur={() => value.trim() === "" && onCancel()}
      />
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
