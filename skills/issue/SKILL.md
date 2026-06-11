---
description: Create a tracker issue (Jira/GitHub/Linear) from a finding or task description — drafts it per devflow conventions, shows it for approval, files it into the project configured in the manifest. Use when asked to file a task or when findings are worth tracking.
---

# File issue: $ARGUMENTS

Read `.devflow/project.yml` → `tracker`. No manifest → stop: the project isn't onboarded, point to `/devflow:init`. If `system` is empty, ask the user for the tracker details once and write them into the manifest (NEVER credentials — those go through MCP OAuth or env vars).

## Protocol

1. **Compose** the issue from "$ARGUMENTS" and/or the findings discussed in the conversation:
   - **Title**: imperative, ≤ 80 chars.
   - **Body**: What was found (with `file:line` / request-response evidence) → Why it matters → What to do (concrete steps) → How to verify when done.
   - Suggested priority with one-line justification.
   - Write in `tracker.language`; apply `tracker.labels` and `default_issue_type` unless the task clearly warrants another type (Bug for defects).
2. **Show the draft and wait for approval.** Filing an issue is outward-facing — never create silently, never bundle unrelated findings into one issue (one finding = one issue; offer a list when there are several).
3. **Create**, in order of preference:
   - Atlassian/GitHub/Linear MCP tools if available in the session;
   - REST fallback for Jira: `curl -s -u "$JIRA_EMAIL:$JIRA_API_TOKEN" -X POST "$URL/rest/api/3/issue" ...` — fail with a clear message if the env vars are missing. Never echo the token or include it in reports.
4. **Report** the issue key + URL. If the issue came from a Ralph TODO item, add the issue key next to that item in `ralph.todo`.
