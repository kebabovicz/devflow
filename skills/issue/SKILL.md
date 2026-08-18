---
description: Create a tracker issue (Jira/GitHub/Linear) from a finding or task description — drafts it per devflow conventions, shows it for approval, files it into the project configured in the manifest. Use when asked to file a task or when findings are worth tracking.
---

# File issue: $ARGUMENTS

Read `.devflow/project.yml` → `tracker`. No manifest → stop: the project isn't onboarded, point to `/devflow:init`. If `system` is empty, ask the user for the tracker details once and write them into the manifest (NEVER credentials — those go through MCP OAuth or env vars).

## Protocol

1. **Compose** the issue from "$ARGUMENTS" and/or the findings discussed in the conversation:
   - **Title**: imperative, ≤ 80 chars. **No area/type prefixes or tags in the title** (`[BACKEND]`, `МОБА:`, `Bug:` …) — routing lives in `tracker.labels` and the issue type; a title prefix duplicates them and pollutes search and boards.
   - **Body**: What was found (with `file:line` / request-response evidence) → Why it matters → What to do (concrete steps) → How to verify when done.
   - Suggested priority with one-line justification.
   - Write in `tracker.language`; apply `tracker.labels` and `default_issue_type` unless the task clearly warrants another type (Bug for defects).
   - **Relations**: if the conversation or "$ARGUMENTS" ties this issue to existing ones (follow-up of, blocks, duplicates, same area), list them in the draft with the proposed link type.
2. **Show the draft and wait for approval.** Filing an issue is outward-facing — never create silently, never bundle unrelated findings into one issue (one finding = one issue; offer a list when there are several).
3. **Create**, in order of preference:
   - Atlassian/GitHub/Linear MCP tools if available in the session;
   - REST fallback for Jira: `curl -s -u "$JIRA_EMAIL:$JIRA_API_TOKEN" -X POST "$URL/rest/api/3/issue" ...` — fail with a clear message if the env vars are missing. Never echo the token or include it in reports.
4. **Link, don't mention**: every relation approved in the draft becomes a REAL tracker link right after creation — Jira: `createIssueLink` with the proper type (Relates / Blocks / Duplicate); GitHub: cross-reference (`#123`) in the body or a sub-issue; Linear: issue relation. A textual "related to ABC-12" in the description is not a link — boards, filters, and automation see links, not prose. If link creation fails (missing tool, permissions), say so explicitly so the user can link manually — never report the issue as fully filed with relations silently dropped.
5. **Report** the issue key + URL + created links. If the issue came from a blocked map ticket, add the issue key next to that ticket.
