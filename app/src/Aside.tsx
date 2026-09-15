// The left column owns its own head and foot.
//
// That is the correction this file exists for: adding a group and the resource
// readout belong to the column that shows the projects, not to the window. Put
// in the window's title bar and along the window's bottom edge they read as
// application chrome, and the connection to what they act on is lost.
//
// Sizes, colours and spacing are the design file's, down to the 3px bars.

import type { Limit, Load } from "./engine";

const Icon = ({ d }: { d: string }) => (
  <svg viewBox="0 0 16 16" width="14" height="14" aria-hidden="true">
    <path d={d} />
  </svg>
);

const FOLDER_PLUS = "M1.5 3.5 A1 1 0 0 1 2.5 2.5 H6 L7.5 4.5 H13.5 A1 1 0 0 1 14.5 5.5 V12.5 A1 1 0 0 1 13.5 13.5 H2.5 A1 1 0 0 1 1.5 12.5 Z M8 7.5 V11 M6.25 9.25 H9.75";
const TERMINAL = "M2 3.5 A1 1 0 0 1 3 2.5 H13 A1 1 0 0 1 14 3.5 V12.5 A1 1 0 0 1 13 13.5 H3 A1 1 0 0 1 2 12.5 Z M5 6.5 L7 8 L5 9.5 M9 10 H11.5";
const COLLAPSE = "M4.5 6 L8 2.5 L11.5 6 M4.5 10 L8 13.5 L11.5 10";
const SEARCH = "M7 2.5 A4.5 4.5 0 1 1 7 11.5 A4.5 4.5 0 1 1 7 2.5 M10.5 10.5 L13.5 13.5";
const ACTIVITY = "M1.5 8 H4.5 L6 3.5 L9 12.5 L10.5 8 H14.5";

export function AsideHead({
  filter,
  onFilter,
  onAddGroup,
  onCollapseAll,
}: {
  filter: string;
  onFilter: (v: string) => void;
  onAddGroup: () => void;
  onCollapseAll: () => void;
}) {
  return (
    <div className="aside-head">
      <div className="title">
        <span className="caption">PROJECTS</span>
        <span className="actions">
          <button title="New group" onClick={onAddGroup}>
            <Icon d={FOLDER_PLUS} />
          </button>
          <button title="Collapse everything" onClick={onCollapseAll}>
            <Icon d={COLLAPSE} />
          </button>
        </span>
      </div>
      <div className="filter">
        <span className="field">
          <svg viewBox="0 0 16 16" width="12" height="12" aria-hidden="true">
            <path d={SEARCH} />
          </svg>
          <input
            value={filter}
            placeholder="filter tree"
            onChange={(e) => onFilter(e.target.value)}
          />
          <kbd>⌘F</kbd>
        </span>
      </div>
    </div>
  );
}

function label(l: Limit): string {
  if (l.kind === "session") return "5-hour";
  if (l.kind === "weekly_all") return "weekly";
  if (l.kind === "weekly_scoped") return l.scope ? `weekly · ${l.scope.toLowerCase()}` : "weekly";
  return l.kind.replace(/_/g, " ");
}

function resets(iso: string | null): string {
  if (!iso) return "";
  const d = new Date(iso);
  const ahead = d.getTime() - Date.now();
  return ahead > 20 * 3600 * 1000
    ? `resets ${d.toLocaleDateString(undefined, { month: "short", day: "numeric" })}`
    : `resets ${d.toLocaleTimeString(undefined, { hour: "2-digit", minute: "2-digit" })}`;
}

export function AsideFoot({
  load,
  limits,
  limitsError,
}: {
  load: Load | null;
  limits: Limit[] | null;
  limitsError: boolean;
}) {
  return (
    <div className="aside-foot">
      <div className="resources">
        <span className="left">
          <svg viewBox="0 0 16 16" width="12" height="12" aria-hidden="true">
            <path d={ACTIVITY} />
          </svg>
          {load?.sessions ?? 0} active
        </span>
        <span className="right">
          <span className="pair">
            <em>cpu</em>
            <b>{load ? `${load.cpu_percent}%` : "—"}</b>
          </span>
          <span
            className="pair"
            title="Summed resident memory — shared pages counted once per session, so read it as an upper bound"
          >
            <em>mem</em>
            <b>{load ? `${(load.memory_mb / 1024).toFixed(1)} GB` : "—"}</b>
          </span>
        </span>
      </div>

      {limitsError && <div className="limits"><span className="none">limits unavailable</span></div>}

      {limits && limits.length > 0 && (
        <div className="limits">
          {limits.map((l) => (
            <div className={`limit ${l.severity}`} key={l.kind + (l.scope ?? "")}>
              <div className="line">
                <span className="left">
                  <em>{label(l)}</em>
                  <b>{l.percent}%</b>
                </span>
                <span className="resets">{resets(l.resets_at)}</span>
              </div>
              <div className="bar">
                <span style={{ width: `${Math.min(100, Math.max(0, l.percent))}%` }} />
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

export const TERMINAL_ICON = TERMINAL;
