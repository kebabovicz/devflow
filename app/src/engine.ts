// The shapes `devflow status --json` and `claude agents --json` answer with,
// and the only place this application knows either command exists.
//
// Keys are never omitted by the engine: an unknown value comes back null, so a
// missing field here means "not collected", not "not applicable".

import { invoke } from "@tauri-apps/api/core";

export type ContractState = "approved" | "draft" | "legacy" | "none" | string;
export type AcceptanceState = "accepted" | "reported" | "legacy" | "none" | string;

export interface Ticket {
  id: string;
  path: string;
  title: string | null;
  status: string | null;
  status_raw: string | null;
  blocked_by: string[];
  acceptance: { total: number; checked: number };
  contract: { state: ContractState; at: string | null; by: string | null };
  acceptance_state: AcceptanceState;
  reported: string | null;
  accepted: string | null;
  lock: null | {
    owner: string;
    since: string;
    session: string | null;
    holder_pid_alive: boolean;
    stale: boolean;
  };
  session: null | Session;
}

export interface EffortMap {
  slug: string;
  path: string;
  tickets: Ticket[];
  questions_open: number;
  counts: Record<string, number>;
}

export interface Session {
  id: string;
  session_id: string;
  name: string | null;
  kind: "background" | "interactive" | string;
  status: string | null;
  pid: number | null;
  cwd: string;
  started_at: string | null;
  live: boolean;
}

export interface Repo {
  path: string;
  name: string;
  engine: boolean;
  branch: string | null;
  maps: EffortMap[];
  counts: Record<string, number>;
  tickets_total: number;
  questions_open: number;
  sessions: Session[];
}

export interface Status {
  schema: number;
  generated_at: string;
  repos: Repo[];
}

/// A group is a name and a list of repositories. `folder`, when set, is a
/// binding rather than an identity: repositories appearing under it join the
/// group without being listed. A group with no folder holds whatever
/// directories were added to it, from anywhere.
export interface Group {
  id: string;
  name: string;
  repos: string[];
  folder: string | null;
  open: boolean;
}

export const engineStatus = (paths: string[]) =>
  invoke<Status>("engine_status", { paths });

/// Every session Claude Code knows about, whatever directory it stands in.
/// Read straight from the registry rather than out of the repositories the
/// window happens to be watching: the sessions are the first thing a person
/// opens this window for, and they must be there before anything is configured.
export const claudeAgents = () => invoke<Session[]>("claude_agents");

export const groupsLoad = () => invoke<{ groups: Group[] }>("groups_load");
export const groupsSave = (groups: Group[]) =>
  invoke<void>("groups_save", { groups: { groups } });
export const groupRepos = (group: Group) => invoke<string[]>("group_repos", { group });
export const readText = (path: string) => invoke<string>("read_text", { path });

export const paneOpen = (session: string, rows: number, cols: number) =>
  invoke<number>("pane_open", { session, rows, cols });

export const paneWrite = (pane: number, data: string) =>
  invoke<void>("pane_write", { pane, data });

export const paneSendLine = (pane: number, line: string) =>
  invoke<void>("pane_send_line", { pane, line });

export const paneResize = (pane: number, rows: number, cols: number) =>
  invoke<void>("pane_resize", { pane, rows, cols });

export const paneClose = (pane: number) => invoke<void>("pane_close", { pane });
