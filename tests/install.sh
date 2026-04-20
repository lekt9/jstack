#!/bin/bash
# Jesus Loop — Step-3 (install) signals.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d -t jl-install.XXXXXX)
trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
ok()  { printf '  ✓ %s\n' "$1"; PASS=$((PASS+1)); }
bad() { printf '  ✗ %s\n    %s\n' "$1" "$2"; FAIL=$((FAIL+1)); }
INSTALL="$ROOT/scripts/install.sh"

echo "== plugin manifest =="
VER=$(jq -r .version "$ROOT/.claude-plugin/plugin.json")
[[ "$VER" == "0.4.0" ]] && ok "plugin.json version is 0.4.0" || bad "version" "got $VER"
jq -e '.description | test("opencode"; "i")' "$ROOT/.claude-plugin/plugin.json" >/dev/null \
  && jq -e '.description | test("codex"; "i")' "$ROOT/.claude-plugin/plugin.json" >/dev/null \
  && ok "manifest description names opencode + codex" || bad "manifest description" "missing harness names"

echo
echo "== install.sh codex =="
CHOME="$TMP/codex-home"
bash "$INSTALL" codex --home "$CHOME" >/dev/null
[[ -f "$CHOME/hooks.json" ]] && ok "wrote ~/.codex/hooks.json" || bad "hooks.json" "missing"
jq -e '.Stop[0].hooks[0].command | test("^JL_PLUGIN_ROOT="; "")' "$CHOME/hooks.json" >/dev/null \
  && ok "hooks.json command sets absolute JL_PLUGIN_ROOT" \
  || bad "hooks.json absolute path" "$(jq -r .Stop[0].hooks[0].command "$CHOME/hooks.json")"
[[ -f "$CHOME/jesus-loop/core/loop.sh" ]] && ok "core/loop.sh installed under jesus-loop/" || bad "core copy" "missing"
[[ -f "$CHOME/prompts/take-the-wheel.md" && -f "$CHOME/prompts/steer.md" ]] \
  && ok "prompts/{take-the-wheel,steer}.md installed" || bad "prompts" "missing"

# Run installed loop end-to-end to prove the codex hook would actually fire.
mkdir -p "$TMP/cwd/.codex"
cat > "$TMP/cwd/.codex/jesus-loop.demo.local.md" <<'EOF'
---
active: true
step: 1
harness_ws:
completion_promise: "SHIPPED"
north_star: "ship the codex install"
---
test task body
EOF
cd "$TMP/cwd"
HOOK_CMD=$(jq -r '.Stop[0].hooks[0].command' "$CHOME/hooks.json")
OUT=$(echo '{}' | bash -c "$HOOK_CMD")
echo "$OUT" | jq -e '.decision == "block"' >/dev/null \
  && echo "$OUT" | jq -r .reason | grep -q "ship the codex install" \
  && ok "installed codex hook runs end-to-end (decision:block + north_star)" \
  || bad "codex e2e via installed hook" "$(echo "$OUT" | head -3)"
cd "$ROOT"

echo
echo "== install.sh opencode =="
OPROJ="$TMP/oc-proj"; mkdir -p "$OPROJ"
bash "$INSTALL" opencode --project "$OPROJ" >/dev/null
[[ -f "$OPROJ/.opencode/plugins/jesus-loop.ts" ]] && ok "plugins/jesus-loop.ts installed" || bad "opencode plugin.ts" "missing"
[[ -f "$OPROJ/.opencode/commands/take-the-wheel.md" ]] && ok "opencode commands/take-the-wheel.md" || bad "opencode commands" "missing"
[[ -f "$OPROJ/.opencode/package.json" ]] && jq -e '.devDependencies."bun-types"' "$OPROJ/.opencode/package.json" >/dev/null \
  && ok "opencode package.json has bun-types" || bad "opencode package.json" "missing or no bun-types"
[[ -f "$OPROJ/.opencode/jesus-loop/core/loop.sh" ]] && ok "opencode core/loop.sh present" || bad "opencode core" "missing"

echo
echo "== install.sh claude-code (settings merge) =="
CCPROJ="$TMP/cc-proj"; mkdir -p "$CCPROJ/.claude"
# Pre-existing user settings — must be preserved.
cat > "$CCPROJ/.claude/settings.json" <<'EOF'
{ "permissions": { "allow": ["Bash(git status:*)"] }, "model": "opus-4-7" }
EOF
bash "$INSTALL" claude-code --project "$CCPROJ" >/dev/null
jq -e '.model == "opus-4-7"' "$CCPROJ/.claude/settings.json" >/dev/null \
  && ok "merge preserved unrelated keys (model)" || bad "merge preservation" "$(cat "$CCPROJ/.claude/settings.json")"
jq -e '.permissions.allow | index("Bash(git status:*)") != null' "$CCPROJ/.claude/settings.json" >/dev/null \
  && ok "merge preserved existing permission entry" || bad "existing perm dropped" "$(jq .permissions.allow "$CCPROJ/.claude/settings.json")"
jq -e '.permissions.allow | index("Edit(.claude/jesus-loop.*.local.md)") != null' "$CCPROJ/.claude/settings.json" >/dev/null \
  && ok "merge added jesus-loop permissions" || bad "jl perms missing" "$(jq .permissions.allow "$CCPROJ/.claude/settings.json")"

# Idempotency: running again must not duplicate.
bash "$INSTALL" claude-code --project "$CCPROJ" >/dev/null
COUNT=$(jq -r '[.permissions.allow[] | select(. == "Edit(.claude/jesus-loop.*.local.md)")] | length' "$CCPROJ/.claude/settings.json")
[[ "$COUNT" == "1" ]] && ok "second install run is idempotent (no duplicate perm)" || bad "idempotent" "duplicates: $COUNT"

echo
echo "== park.sh / sermon.sh multi-session =="
PROJ="$TMP/sess"; mkdir -p "$PROJ/.claude"; cd "$PROJ"
for s in alpha beta gamma; do
  cat > ".claude/jesus-loop.$s.local.md" <<EOF
---
active: true
step: 2
harness_ws:
completion_promise: "SHIPPED"
---
$s task
EOF
done
# Sermon for one session.
echo "teachings for alpha" > .claude/jesus-loop.alpha.teachings.local.md
OUT=$(bash "$ROOT/scripts/sermon.sh" --session alpha)
echo "$OUT" | grep -q "teachings for alpha" && ok "sermon --session prints that session's teachings" || bad "sermon single" "$OUT"

# Park one session.
bash "$ROOT/scripts/park.sh" --session beta >/dev/null
[[ ! -f .claude/jesus-loop.beta.local.md && -f .claude/jesus-loop.alpha.local.md && -f .claude/jesus-loop.gamma.local.md ]] \
  && ok "park --session removes only that session" || bad "park single" "$(ls .claude/)"

# Park all.
bash "$ROOT/scripts/park.sh" --all >/dev/null
remaining=$(ls .claude/jesus-loop.*.local.md 2>/dev/null | { grep -v teachings || true; } | wc -l | tr -d ' ')
[[ "$remaining" == "0" ]] && ok "park --all removes every session state" || bad "park all" "remaining=$remaining"
cd "$ROOT"

echo
echo "== install.sh uninstall codex =="
bash "$INSTALL" uninstall codex >/dev/null 2>&1 || true
# Restore: re-install into temp home so we can test uninstall there.
HOME_BACKUP="$HOME"; export HOME="$TMP/uhome"; mkdir -p "$HOME/.codex"
bash "$INSTALL" codex --home "$HOME/.codex" >/dev/null
[[ -d "$HOME/.codex/jesus-loop" ]] || { bad "codex uninstall pre-state" "install failed"; HOME=$HOME_BACKUP; exit 1; }
# Manually invoke uninstall path that uses $HOME.
bash "$INSTALL" uninstall codex >/dev/null
[[ ! -d "$HOME/.codex/jesus-loop" ]] && ok "uninstall codex removes jesus-loop/ dir" || bad "uninstall jl dir" "still there"
[[ ! -f "$HOME/.codex/prompts/take-the-wheel.md" ]] && ok "uninstall codex removes prompts" || bad "uninstall prompts" "still there"
[[ ! -f "$HOME/.codex/hooks.json" ]] && ok "uninstall codex removes our hooks.json" || bad "uninstall hooks" "still there"
export HOME="$HOME_BACKUP"

echo
printf 'Install signals: %s passed · %s failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]] || exit 1
