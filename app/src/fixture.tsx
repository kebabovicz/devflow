// A page that renders the real components against made-up data.
//
// It exists so the window can be looked at without being run: a browser can
// open it, a screenshot can be compared against the design, and a layout that
// collapsed is seen before anyone is asked to look. Every visual bug in this
// application so far was found by a person squinting at a screenshot, which is
// the slowest possible way to find one.
//
// It imports the same components and the same stylesheet as the application.
// A fixture that reimplements the markup would pass while the window is broken.

import ReactDOM from "react-dom/client";
import { AsideFoot, AsideHead } from "./Aside";
import { TreeRow, type Row } from "./Tree";
import type { Group, Repo, Session, Ticket } from "./engine";
import "./App.css";

const group = (id: string, name: string): Group => ({ id, name, repos: [], folder: null, open: true });

const ticket = (id: string, status: string, over: Partial<Ticket> = {}): Ticket => ({
  id,
  path: `/x/${id}.md`,
  title: id,
  status,
  status_raw: status,
  blocked_by: [],
  acceptance: { total: 4, checked: 2 },
  contract: { state: "approved", at: null, by: null },
  acceptance_state: "none",
  reported: null,
  accepted: null,
  lock: null,
  session: null,
  ...over,
});

const session = (name: string, status: string | null, cwd: string): Session => ({
  id: name.slice(0, 8),
  session_id: `${name}-uuid`,
  name,
  kind: "background",
  status,
  pid: 1,
  cwd,
  started_at: null,
  live: true,
});

const repo = (name: string, branch: string | null, engine = true): Repo => ({
  path: `/p/${name}`,
  name,
  engine,
  branch,
  maps: [],
  counts: {},
  tickets_total: 0,
  questions_open: 0,
  sessions: [],
});

const rows: Row[] = [
  { kind: "group", depth: 0, key: "g1", name: "AiZhol", open: true, group: group("1", "AiZhol"), waiting: 1, working: 1 },
  { kind: "repo", depth: 1, key: "r1", name: "aizhol-infra", path: "/p/aizhol-infra", repo: repo("aizhol-infra", "main"), waiting: 0, working: 0 },
  { kind: "session", depth: 2, key: "s1", session: session("aizhol-infra-7a", "idle", "/p/aizhol-infra") },
  { kind: "repo", depth: 1, key: "r2", name: "aizhol-web", path: "/p/aizhol-web", repo: repo("aizhol-web", "develop"), waiting: 0, working: 1 },
  { kind: "session", depth: 2, key: "s2", session: session("aizhol-web-27", "busy", "/p/aizhol-web") },
  { kind: "group", depth: 0, key: "g2", name: "Iprav", open: true, group: group("2", "Iprav"), waiting: 1, working: 1 },
  { kind: "repo", depth: 1, key: "r3", name: "iprav-r2", path: "/p/iprav-r2", repo: repo("iprav-r2", "feature/ABC-431"), waiting: 1, working: 1 },
  { kind: "ticket", depth: 2, key: "t1", ticket: ticket("01-join-table-unique-indexes", "in progress"), waiting: null },
  { kind: "session", depth: 3, key: "s3", session: session("iprav-r2-b9", "busy", "/p/iprav-r2/.claude/worktrees/b9") },
  { kind: "ticket", depth: 2, key: "t2", ticket: ticket("01-offset-overflow", "blocked", { acceptance: { total: 3, checked: 0 } }), waiting: "an answer" },
  { kind: "ticket", depth: 2, key: "t3", ticket: ticket("02-account-disable-route", "open", { acceptance: { total: 2, checked: 0 }, blocked_by: ["01"] }), waiting: null },
  { kind: "repo", depth: 1, key: "r4", name: "spec-hub", path: "/p/spec-hub", repo: repo("spec-hub", null, false), waiting: 0, working: 0 },
  { kind: "dir", depth: 0, key: "d1", name: "~/meteora/spec-hub", path: "/h/meteora/spec-hub", open: true, working: 1 },
  { kind: "session", depth: 1, key: "s4", session: { ...session("onboarding documentation review", "done", "/h/meteora/spec-hub"), live: false } },
  { kind: "session", depth: 1, key: "s5", session: { ...session("loop-test", "stopped", "/h/meteora/spec-hub"), live: false } },
  { kind: "session", depth: 1, key: "s6", session: { ...session("kebabovicz-a4", "idle", "/h/meteora/spec-hub"), kind: "interactive" } },
];

function Fixture() {
  return (
    <div
      className="app"
      style={{ backgroundImage: "linear-gradient(135deg,#2f5b86,#13263a 55%,#28506e)" }}
    >
      <header className="bar">
        <span className="brand">devflow</span>
        <span className="spacer" />
        <span className="generated">12:55:04</span>
      </header>
      <div className="body">
        <aside className="aside">
          <AsideHead filter="" onFilter={() => {}} onAddGroup={() => {}} onCollapseAll={() => {}} />
          <div className="tree">
            {rows.map((row) => (
              <TreeRow key={row.key} row={row} selected={row.key === "t1"} onToggle={() => {}} onPick={() => {}} />
            ))}
          </div>
          <AsideFoot
            load={{ sessions: 3, cpu_percent: 62, memory_mb: 1229 }}
            limits={[
              { kind: "session", group: "session", percent: 78, severity: "warning", resets_at: new Date(Date.now() + 3600e3).toISOString(), scope: null },
              { kind: "weekly_all", group: "weekly", percent: 41, severity: "normal", resets_at: new Date(Date.now() + 5 * 86400e3).toISOString(), scope: null },
              { kind: "weekly_scoped", group: "weekly", percent: 12, severity: "normal", resets_at: new Date(Date.now() + 5 * 86400e3).toISOString(), scope: "Opus" },
            ]}
            limitsError={false}
          />
        </aside>
        <main className="pane">
          <div className="pane-head">
            <span className="id">01-join-table-unique-indexes</span>
            <span className="where">/p/iprav-r2</span>
          </div>
          <div className="terminal-pad">
            <pre style={{ margin: 0, font: "12px/1.2 var(--font)", color: "#e6e6e6" }}>
              {"❯ devflow ticket report 01-join-table-unique-indexes --commit 4e11b17\n{\n  \"ok\": true,\n  \"reason\": \"reported\"\n}\n"}
            </pre>
          </div>
        </main>
      </div>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById("root") as HTMLElement).render(<Fixture />);
