#!/bin/bash
# Static lint of the plugin's own structure — catches the defect classes past
# releases hit by hand: dangling ${CLAUDE_SKILL_DIR} references (0.18.1),
# hooks shipped without exec bits (0.9.1), version/CHANGELOG drift, and
# template keys the hooks grep-parse becoming ambiguous. Requires: bash, jq.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0 FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }

echo "lint: skill frontmatter"
for f in "$ROOT"/skills/*/SKILL.md; do
  name=$(basename "$(dirname "$f")")
  if head -1 "$f" | grep -q '^---$' \
     && awk '/^---$/{n++; next} n==1 && /^description:[[:space:]]*[^[:space:]]/{found=1} n==2{exit} END{exit !found}' "$f"; then
    ok "skills/$name: frontmatter with description"
  else
    bad "skills/$name: missing frontmatter or empty description"
  fi
done

echo "lint: agent frontmatter"
for f in "$ROOT"/agents/*.md; do
  name=$(basename "$f" .md)
  missing=""
  for key in name description tools model; do
    awk '/^---$/{n++; next} n==1' "$f" | grep -qE "^$key:[[:space:]]*[^[:space:]]" || missing="$missing $key"
  done
  if [ -z "$missing" ]; then ok "agents/$name: complete frontmatter"; else bad "agents/$name: missing$missing"; fi
done

echo "lint: hooks.json commands exist and are executable"
while IFS= read -r cmd; do
  path=${cmd//\$\{CLAUDE_PLUGIN_ROOT\}/$ROOT}
  path=${path//\"/}
  if [ -x "$path" ]; then ok "hook executable: $(basename "$path")"; else bad "hook missing or not executable: $path"; fi
done < <(jq -r '.hooks | to_entries[].value[].hooks[].command' "$ROOT/hooks/hooks.json")

echo "lint: manifest template"
if python3 -c 'import yaml' 2>/dev/null; then
  if python3 -c "import yaml; yaml.safe_load(open('$ROOT/templates/project.yml'))" 2>/dev/null; then
    ok "template parses as YAML"
  else
    bad "template does not parse as YAML"
  fi
else
  printf '  skip yaml parse (python3+pyyaml not available)\n'
fi
# Keys the hooks read with grep (first match wins) must stay unique.
for key in base_branch branch_pattern commit_pattern footprint dir; do
  n=$(grep -cE "^[[:space:]]*$key:" "$ROOT/templates/project.yml")
  if [ "$n" -eq 1 ]; then ok "template key unique: $key"; else bad "template key '$key' appears $n times — hooks grep the first match"; fi
done

echo "lint: \${CLAUDE_SKILL_DIR} references resolve"
for f in "$ROOT"/skills/*/SKILL.md; do
  skdir="$ROOT/skills/$(basename "$(dirname "$f")")"
  while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    resolved=${ref//\$\{CLAUDE_SKILL_DIR\}/$skdir}
    if [ -e "$resolved" ]; then
      ok "$(basename "$skdir"): $ref"
    else
      bad "$(basename "$skdir"): dangling reference $ref"
    fi
  done < <(grep -oE '\$\{CLAUDE_SKILL_DIR\}[^ `")]*' "$f" | sort -u)
done

echo "lint: version consistency"
v=$(jq -r .version "$ROOT/.claude-plugin/plugin.json")
head_v=$(grep -m1 -E '^## ' "$ROOT/CHANGELOG.md" | sed -e 's/^## //' -e 's/ —.*$//')
if [ "$v" = "$head_v" ]; then
  ok "plugin.json ($v) matches latest CHANGELOG entry"
else
  bad "plugin.json says $v but CHANGELOG's latest entry is $head_v"
fi

echo
echo "lint.test.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
