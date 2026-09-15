// One tree over several repositories, and one pane showing whichever thing was
// picked from it — a session's terminal, or a file.
//
// The order of the left pane is the argument: what is waiting on a person comes
// before what is merely running, and both come before the repositories they
// belong to. A window that lists everything equally is the flat list this one
// exists to replace.

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { open as openDialog } from "@tauri-apps/plugin-dialog";
import {
  claudeAgents,
  engineStatus,
  groupRepos,
  groupsLoad,
  groupsSave,
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
  const [elsewhereOpen, setElsewhereOpen] = useState(true);
  const [filter, setFilter] = useState("");
  const [menu, setMenu] = useState<{ x: number; y: number; group: Group } | null>(null);
  const [load, setLoad] = useState<Load | null>(null);
  const [limits, setLimits] = useState<Limit[] | null>(null);
  const [limitsError, setLimitsError] = useState(false);
  const tree = useRef<HTMLDivElement>(null);

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

  const live = useMemo(
    () =>
      sessions
        .filter((s) => s.live)
        .sort((a, b) => (a.name ?? a.id).localeCompare(b.name ?? b.id)),
    [sessions],
  );




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

    // Sessions no group covers are still running, and a tree that omitted them
    // would be lying about what is going on.
    if (elsewhere.length > 0) {
      out.push({
        kind: "group",
        depth: 0,
        key: "g:elsewhere",
        name: "Elsewhere",
        open: elsewhereOpen,
        group: { id: "elsewhere", name: "Elsewhere", repos: [], folder: null, open: elsewhereOpen },
        waiting: 0,
        working: elsewhere.filter((s) => s.status === "busy").length,
      });
      if (elsewhereOpen) {
        for (const sn of elsewhere) {
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
  }, [groups, reposByGroup, repoByPath, live, elsewhere, elsewhereOpen, filter]);

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
        <aside className="aside">
          <AsideHead
            filter={filter}
            onFilter={setFilter}
            onAddGroup={() => void addGroup()}
            onCollapseAll={() => persist(groups.map((g) => ({ ...g, open: false })))}
          />

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
                if (row.kind !== "group") return;
                if (row.group.id === "elsewhere") setElsewhereOpen((v) => !v);
                else persist(groups.map((x) => (x.id === row.group.id ? { ...x, open: !x.open } : x)));
              }}
              onPick={() => {
                if (row.kind === "ticket") openFile(row.ticket.path, row.ticket.id);
                if (row.kind === "session") setShowing({ kind: "session", session: row.session });
              }}
            />
          ))}

            {groups.length === 0 && (
              <div className="empty hint">
                Nothing is being watched yet. Add a group — a folder of repositories, or
                an empty one you fill by hand.
              </div>
            )}
          </div>

          <AsideFoot load={load} limits={limits} limitsError={limitsError} />
        </aside>

        {scrolled && (
          <button
            className="to-top"
            title="Back to the top"
            onClick={() => tree.current?.scrollTo({ top: 0, behavior: "smooth" })}
          >
            ▲
          </button>
        )}

        {menu && (
          <>
            <div className="scrim" onClick={() => setMenu(null)} onContextMenu={(e) => { e.preventDefault(); setMenu(null); }} />
            <div className="menu" style={{ left: menu.x, top: menu.y }}>
              <button
                onClick={() => {
                  const g = menu.group;
                  setMenu(null);
                  void addRepo(g);
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
