// The tree, built to the design rather than to taste.
//
// Everything here — row heights, the 14px indent step and its guide lines, the
// two text sizes, every colour — is read off the design file, not chosen. What
// is chosen is which of them the data can actually justify: the design shows
// five session states and the registry answers with two, so a state we cannot
// know is not drawn as though we could.

import type { Group, Repo, Session, Ticket } from "./engine";

const INDENT = 14;
const BASE = 6;

export type Row =
  | { kind: "group"; depth: number; key: string; name: string; open: boolean; group: Group; waiting: number; working: number }
  | { kind: "dir"; depth: number; key: string; name: string; path: string; open: boolean; working: number }
  | { kind: "repo"; depth: number; key: string; name: string; path: string; repo?: Repo; waiting: number; working: number }
  | { kind: "ticket"; depth: number; key: string; ticket: Ticket; waiting: string | null }
  | { kind: "session"; depth: number; key: string; session: Session };

/// The guide lines that make depth readable: one column per level, a hairline
/// down the left of each. Drawn rather than simulated with padding, because the
/// line has to run the full height of the row.
function Indent({ depth }: { depth: number }) {
  return (
    <span className="indent" style={{ width: BASE + depth * INDENT }}>
      {Array.from({ length: depth }, (_, i) => (
        <span className="guide" key={i} style={{ left: BASE + i * INDENT }} />
      ))}
    </span>
  );
}

const Chevron = ({ open }: { open: boolean }) => (
  <svg viewBox="0 0 16 16" width="11" height="11" aria-hidden="true">
    <path d={open ? "M3 6 L8 11 L13 6" : "M6 3 L11 8 L6 13"} />
  </svg>
);

const TerminalIcon = () => (
  <svg viewBox="0 0 16 16" width="13" height="13" aria-hidden="true">
    <rect x="1.5" y="2.5" width="13" height="11" rx="2" />
    <path d="M4.5 6.5 L6.5 8 L4.5 9.5 M8.5 10 L11 10" />
  </svg>
);

const BranchIcon = () => (
  <svg viewBox="0 0 16 16" width="10" height="10" aria-hidden="true">
    <circle cx="4" cy="3.5" r="1.6" />
    <circle cx="4" cy="12.5" r="1.6" />
    <circle cx="12" cy="6" r="1.6" />
    <path d="M4 5 L4 11 M12 7.6 C12 10 9 10 6.5 11" />
  </svg>
);

/// Counters read at a glance: a dot and a number, coloured by what they mean.
/// Nothing is shown when there is nothing to count — a row of zeroes is noise.
function Counts({ waiting, working }: { waiting: number; working: number }) {
  if (waiting === 0 && working === 0) return null;
  return (
    <>
      {waiting > 0 && (
        <span className="count waiting">
          <i /> {waiting}
        </span>
      )}
      {working > 0 && (
        <span className="count working">
          <i /> {working}
        </span>
      )}
    </>
  );
}

function Branch({ name, engine }: { name: string | null; engine: boolean }) {
  if (name === null) return <span className="nogit">no git</span>;
  return (
    <span className={`branch ${engine ? "" : "no-engine"}`}>
      <BranchIcon /> {name}
    </span>
  );
}

/// The session state a row can honestly show.
///
/// A running session reports busy or idle; one that has ended reports done or
/// stopped. That is four of the five states the design asks for. The fifth —
/// error — is genuinely not in the registry: a session killed by a rate limit
/// and one stopped by hand look identical from here, so it is not drawn.
function sessionTone(s: Session): string {
  switch (s.status) {
    case "busy": return "working";
    case "done": return "done";
    case "stopped": return "stopped";
    default: return s.live ? "idle" : "stopped";
  }
}

function ticketTone(t: Ticket): string {
  if (t.status === "in progress") return "working";
  if (t.status === "blocked") return "waiting";
  if (t.status === "awaiting review") return "done";
  return "idle";
}

function ticketNote(t: Ticket): string {
  const bits: string[] = [t.status ?? "?"];
  if (t.acceptance.total > 0) bits.push(`${t.acceptance.checked}/${t.acceptance.total}`);
  else if (t.blocked_by.length > 0) bits.push(`after ${t.blocked_by.join(", ")}`);
  return bits.join(" · ");
}

function sessionNote(s: Session, repo?: string): string {
  // The registry's own word for the state, whichever field it came in on.
  const bits: string[] = [s.status ?? (s.live ? "idle" : "stopped")];
  // A session working in a worktree stands somewhere else than the repository
  // it belongs to, and which worktree it is in is the useful half of that.
  if (repo && s.cwd !== repo) bits.push(s.cwd.slice(repo.length + 1));
  return bits.join(" · ");
}

export function TreeRow({
  row,
  selected,
  onToggle,
  onPick,
  onMenu,
}: {
  row: Row;
  selected: boolean;
  onToggle: () => void;
  onPick: () => void;
  onMenu?: (x: number, y: number) => void;
}) {
  if (row.kind === "group" || row.kind === "repo" || row.kind === "dir") {
    const open = row.kind === "repo" ? true : row.open;
    return (
      <div
        className={`node ${row.kind}`}
        onClick={onToggle}
        onContextMenu={(e) => {
          if (!onMenu) return;
          e.preventDefault();
          onMenu(e.clientX, e.clientY);
        }}
      >
        <Indent depth={row.depth} />
        <span className="twist">
          <Chevron open={open} />
        </span>
        <span className="label">
          <span className="name">{row.name}</span>
        </span>
        <span className="right">
          <Counts waiting={row.kind === "dir" ? 0 : row.waiting} working={row.working} />
          {row.kind === "repo" && (
            <Branch name={row.repo ? row.repo.branch : null} engine={row.repo?.engine ?? false} />
          )}
        </span>
      </div>
    );
  }

  if (row.kind === "ticket") {
    const t = row.ticket;
    return (
      <div className={`node leaf ticket ${selected ? "on" : ""}`} onClick={onPick}>
        <Indent depth={row.depth} />
        <span className="twist" />
        <span className={`mark dot ${ticketTone(t)}`} />
        <span className="label two">
          <span className="name">{t.id}</span>
          <span className="note">{ticketNote(t)}</span>
        </span>
        {row.waiting && (
          <span className="right">
            <span className="flag waiting">
              ?
            </span>
          </span>
        )}
      </div>
    );
  }

  const s = row.session;
  const tone = sessionTone(s);
  // Every background session can be opened, finished or not: `claude attach`
  // reopens a conversation that has ended. Only an interactive one is out of
  // reach, because it belongs to the terminal that started it.
  const attachable = s.kind === "background";
  return (
    <div
      className={`node leaf session ${selected ? "on" : ""} ${attachable ? "" : "external"}`}
      onClick={() => attachable && onPick()}
    >
      <Indent depth={row.depth} />
      <span className="twist" />
      <span className={`mark ${tone}`}>
        <TerminalIcon />
      </span>
      <span className="label two">
        <span className="name">{s.name ?? s.id}</span>
        <span className="note">{sessionNote(s)}</span>
      </span>
    </div>
  );
}
