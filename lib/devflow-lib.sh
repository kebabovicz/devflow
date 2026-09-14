#!/bin/bash
# Shared resolution logic for devflow hooks and the CLI.
#
# Sourced, never executed. Every function here is read-only: nothing writes to
# disk. The hooks and `bin/devflow` must agree on where the map lives and what a
# status means — two copies of this logic drift the day someone runs the CLI
# from a worktree and the hook from the main checkout.

# Read a scalar from a manifest: strips inline comments, surrounding quotes and
# trailing whitespace. Same rules as hooks/guard.sh and hooks/stop-gate.sh.
# $1=file $2=key
df_yml_value() {
  [ -f "$1" ] || return 1
  grep -E "^[[:space:]]*$2:" "$1" | head -1 \
    | sed -e "s/^[[:space:]]*$2:[[:space:]]*//" \
          -e 's/[[:space:]]*#.*$//' \
          -e 's/^"\(.*\)"$/\1/' \
          -e "s/^'\(.*\)'\$/\1/" \
          -e 's/[[:space:]]*$//'
}

# Root the maps live under. A git worktree checks out tracked files only and the
# map is deliberately excluded from git, so it exists solely in the main working
# tree. Resolving from the common git dir gives every worktree of a repo the
# same map — the rule hooks/stop-gate.sh already follows.
# $1=dir  ->  prints the root, or the dir itself when it is not a git repo.
df_maps_root() {
  local dir="$1" common parent
  common=$(git -C "$dir" rev-parse --git-common-dir 2>/dev/null) || common=""
  if [ -z "$common" ]; then printf '%s' "$dir"; return; fi
  case "$common" in /*) ;; *) common="$dir/$common" ;; esac
  parent=$(cd "$(dirname "$common")" 2>/dev/null && pwd) || parent=""
  if [ -z "$parent" ]; then printf '%s' "$dir"; else printf '%s' "$parent"; fi
}

# Map directory relative to the maps root: manifest `maps.dir`, else the default
# the template ships.
# $1=manifest path
df_maps_dir() {
  local d
  d=$(df_yml_value "$1" dir 2>/dev/null) || d=""
  if [ -z "$d" ]; then d=".devflow/maps"; fi
  printf '%s' "$d"
}

# Branch checked out in a directory. Empty when the directory is not a git repo
# or the head is detached — both are states to report, not errors.
# $1=dir
df_branch() {
  local b
  b=$(git -C "$1" symbolic-ref --quiet --short HEAD 2>/dev/null) || b=""
  if [ -z "$b" ]; then
    b=$(git -C "$1" rev-parse --abbrev-ref HEAD 2>/dev/null) || b=""
  fi
  if [ "$b" = "HEAD" ]; then b=""; fi
  printf '%s' "$b"
}

# Is this directory inside a git repository at all?
# $1=dir
df_is_git() {
  git -C "$1" rev-parse --git-dir >/dev/null 2>&1
}

# The status values written into ticket files have drifted from the documented
# set: skills/map/SLICING.md defines open | in progress | awaiting review |
# done, while live files also carry `todo`, `awaiting` and `cancelled`.
# Consumers need the raw value (it is what the file actually says) AND a
# normalized bucket (counts across several repos have to add up). This table is
# the single place that mapping lives.
# $1=raw status  ->  normalized bucket, or the raw value unchanged when it is
#                    not a known alias.
df_status_norm() {
  case "$1" in
    todo|open)                   printf 'open' ;;
    "in progress"|in-progress)   printf 'in progress' ;;
    awaiting|"awaiting review")  printf 'awaiting review' ;;
    done)                        printf 'done' ;;
    blocked)                     printf 'blocked' ;;
    cancelled|canceled)          printf 'cancelled' ;;
    *)                           printf '%s' "$1" ;;
  esac
}

# Value of a header line in a ticket or issue file — `Status: done`,
# `Blocked by: 02, 03`. Header lines are plain text, not YAML front matter.
# $1=file $2=key
df_header() {
  [ -f "$1" ] || return 1
  grep -m1 -E "^$2:" "$1" 2>/dev/null \
    | sed -e "s/^$2:[[:space:]]*//" -e 's/[[:space:]]*$//'
}

# Title of a ticket or issue: the first level-1 heading, minus the marker.
# $1=file
df_title() {
  [ -f "$1" ] || return 1
  grep -m1 -E '^# ' "$1" 2>/dev/null | sed -e 's/^#[[:space:]]*//' -e 's/[[:space:]]*$//'
}

# ── ticket lookup and locking ───────────────────────────────────────────────

# Every ticket file under a maps directory, one path per line.
# $1=maps path
df_ticket_files() {
  local maps="$1" d f
  [ -d "$maps" ] || return 0
  for d in "$maps"/*/; do
    d="${d%/}"
    [ -d "$d/tickets" ] || continue
    for f in "$d/tickets"/*.md; do
      [ -f "$f" ] && printf '%s\n' "$f"
    done
  done
  return 0
}

# Resolve a ticket reference to a file path. Accepts a path to the file, the
# basename without .md (`01-a`), or just the leading number (`01`). Prints every
# candidate when several match: an ambiguous reference is for the caller to
# refuse, never for this to pick from.
# $1=maps path $2=reference
df_find_ticket() {
  local maps="$1" ref="$2" f base
  if [ -f "$ref" ]; then printf '%s\n' "$ref"; return 0; fi
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    base=$(basename "$f" .md)
    if [ "$base" = "$ref" ] || [ "${base%%-*}" = "$ref" ]; then
      printf '%s\n' "$f"
    fi
  done < <(df_ticket_files "$maps")
  return 0
}

# Lock directory for a ticket. Sits under the map root, beside the tickets —
# that tree is already excluded from version control, and a lock is machine
# state that must never be committed.
# $1=ticket file
df_lock_dir() {
  local tdir; tdir=$(dirname "$1")          # .../<map>/tickets
  printf '%s/.locks/%s' "$(dirname "$tdir")" "$(basename "$1" .md)"
}

# Is a recorded pid still running here? A hint, not proof. The process that
# calls this CLI is a short-lived shell, not the session that owns the work, so
# a dead pid does not prove the holder is gone and a live one does not prove it
# is the same holder. The authoritative identity is the owner string the caller
# passed with --owner.
# $1=pid
df_pid_alive() {
  [ -n "${1:-}" ] || return 1
  case "$1" in ''|*[!0-9]*) return 1 ;; esac
  kill -0 "$1" 2>/dev/null
}

# ── sections ────────────────────────────────────────────────────────────────

# Body of a `## <name>` section, without the heading itself and without the
# heading that ends it. Empty when the section is absent.
# $1=file $2=section name
df_section_body() {
  [ -f "$1" ] || return 1
  awk -v want="## $2" '
    $0 == want { inside = 1; next }
    inside && /^## / { inside = 0 }
    inside { print }
  ' "$1"
}

# Replace a section's body with the contents of a file, leaving every other byte
# of the ticket alone. Creates the section at the end when it is absent — a
# ticket cut before this format existed has no such heading, and refusing would
# make the command useless on exactly the tickets that need it.
# $1=file $2=section name $3=file holding the new body
df_section_replace() {
  local f="$1" name="$2" body="$3" tmp
  [ -f "$f" ] || return 1
  [ -f "$body" ] || return 1
  tmp=$(mktemp "$(dirname "$f")/.df-XXXXXX") || return 1

  if grep -qE "^## $name\$" "$f"; then
    awk -v want="## $name" -v bodyfile="$body" '
      $0 == want {
        print; print "";
        while ((getline line < bodyfile) > 0) { print line; last = line }
        close(bodyfile);
        inside = 1; next
      }
      # A blank line before the next heading — the format the ticket was written
      # in, and the one a reader expects back.
      inside && /^## / { if (last != "") print ""; inside = 0 }
      inside { next }
      { print }
    ' "$f" > "$tmp" || { rm -f "$tmp"; return 1; }
  else
    cat "$f" > "$tmp" || { rm -f "$tmp"; return 1; }
    printf '\n## %s\n\n' "$name" >> "$tmp"
    cat "$body" >> "$tmp" || { rm -f "$tmp"; return 1; }
  fi

  mv "$tmp" "$f" || { rm -f "$tmp"; return 1; }
  return 0
}

# How many questions on this ticket still wait on a person.
#
# Two forms count. `### Q<n> · open` is what `devflow question add` writes.
# A plain bullet is the older form the format documented before questions had
# commands — a line someone typed by hand. Both mean the same thing to a reader,
# so both mean the same thing here; only the first form is ever written.
# $1=ticket file
df_questions_open() {
  local body n_new n_old
  body=$(df_section_body "$1" "Open questions" 2>/dev/null) || body=""
  n_new=$(printf '%s\n' "$body" | grep -cE '^### Q[0-9]+ · open' || true)
  # A bullet inside an answered block is part of that answer, not a question of
  # its own: only count bullets when the new form is absent entirely.
  n_old=0
  if ! printf '%s\n' "$body" | grep -qE '^### Q[0-9]+'; then
    n_old=$(printf '%s\n' "$body" | grep -cE '^[[:space:]]*[-*] ' || true)
  fi
  printf '%s' "$(( ${n_new:-0} + ${n_old:-0} ))"
}

# Next question number for a ticket: one past the highest already there, so
# numbering survives dropped and answered entries.
# $1=ticket file
df_next_question_n() {
  local body max
  body=$(df_section_body "$1" "Open questions" 2>/dev/null) || body=""
  max=$(printf '%s\n' "$body" | sed -nE 's/^### Q([0-9]+) .*/\1/p' | sort -n | tail -1)
  printf '%s' "$(( ${max:-0} + 1 ))"
}

# Replace one header line in place, preserving the rest of the file byte for
# byte. A ticket is a document a person reads and edits; rewriting it from
# parsed fields would drop everything the parser does not know about. Writes a
# sibling temp file and renames it — rename is atomic, so no reader ever sees a
# half-written ticket.
#
# A key the file does not carry yet is inserted after `Status:`, which is where
# the format puts the header block. Without that, setting a header the ticket
# never had would silently do nothing — and every ticket cut before a header
# existed is exactly the ticket that needs it set.
# $1=file $2=key $3=new value
df_set_header() {
  local f="$1" key="$2" val="$3" tmp
  [ -f "$f" ] || return 1
  tmp=$(mktemp "$(dirname "$f")/.df-XXXXXX") || return 1
  if grep -qE "^$key:" "$f" 2>/dev/null; then
    awk -v k="$key" -v v="$val" '
      !placed && index($0, k ":") == 1 { print k ": " v; placed = 1; next }
      { print }
    ' "$f" > "$tmp" || { rm -f "$tmp"; return 1; }
  else
    awk -v k="$key" -v v="$val" '
      { print }
      !placed && index($0, "Status:") == 1 { print k ": " v; placed = 1 }
      END { if (!placed) print k ": " v }
    ' "$f" > "$tmp" || { rm -f "$tmp"; return 1; }
  fi
  mv "$tmp" "$f" || { rm -f "$tmp"; return 1; }
  return 0
}

# ── contracts ───────────────────────────────────────────────────────────────

# Does this ticket say what it delivers and how anyone would know it is done?
# That pair is the contract — the ticket format already carries both sections,
# so a contract is a state of the ticket rather than a document beside it.
# $1=ticket file
df_contract_complete() {
  local delivers items
  delivers=$(df_section_body "$1" "What it delivers" 2>/dev/null | tr -d '[:space:]')
  [ -n "$delivers" ] || return 1
  items=$(df_section_body "$1" "Acceptance" 2>/dev/null \
          | grep -cE '^[[:space:]]*- \[.\]') || items=0
  [ "${items:-0}" -gt 0 ]
}

# Contract state of a ticket: approved | draft | legacy | none.
#
# `legacy` is a ticket with no `Contract:` header whose two sections are both
# filled — every ticket cut before this header existed. It is reported as its
# own value rather than folded into `approved`: those tickets were reviewed when
# they were sliced, so they stay takeable, but a reader can still tell the
# difference between "a person approved this" and "this predates the question".
# $1=ticket file
df_contract_state() {
  local v first
  if ! grep -qE '^Contract:' "$1" 2>/dev/null; then
    if df_contract_complete "$1"; then printf 'legacy'; else printf 'none'; fi
    return
  fi
  v=$(df_header "$1" "Contract") || v=""
  first="${v%% *}"
  if [ -z "$first" ]; then printf 'none'; else printf '%s' "$first"; fi
}

# When a contract was approved and by whom. The whole record lives on the one
# header line — `Contract: approved <iso> by <who>` — so a grep for the state
# and a read for the provenance never disagree.
# $1=ticket file $2=at|by  ->  the field, or empty when absent
df_contract_meta() {
  local v
  v=$(df_header "$1" "Contract" 2>/dev/null) || v=""
  case "$2" in
    at) printf '%s' "$(printf '%s' "$v" | awk '{print $2}')" ;;
    by) printf '%s' "$(printf '%s' "$v" | sed -nE 's/.* by (.+)$/\1/p')" ;;
  esac
}
