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
