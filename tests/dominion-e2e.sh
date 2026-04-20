#!/bin/bash
# Dominion — full lifecycle through install.sh, multi-session, steer, park, sermon.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d -t jl-dom2.XXXXXX)
trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
ok()  { printf '  ✓ %s\n' "$1"; PASS=$((PASS+1)); }
bad() { printf '  ✗ %s\n    %s\n' "$1" "$2"; FAIL=$((FAIL+1)); }

# 1. Fresh repo, install all three adapters via install.sh all.
PROJ="$TMP/proj"; mkdir -p "$PROJ"
FAKE_HOME="$TMP/home"; mkdir -p "$FAKE_HOME/.codex"
cd "$PROJ"
HOME="$FAKE_HOME" bash "$ROOT/scripts/install.sh" claude-code --project "$PROJ" >/dev/null
HOME="$FAKE_HOME" bash "$ROOT/scripts/install.sh" codex --home "$FAKE_HOME/.codex" >/dev/null
HOME="$FAKE_HOME" bash "$ROOT/scripts/install.sh" opencode --project "$PROJ" >/dev/null

[[ -f "$PROJ/.claude/settings.json" ]] && ok "cc settings dropped" || bad "cc settings" "missing"
[[ -f "$FAKE_HOME/.codex/hooks.json" ]] && ok "codex hooks.json dropped" || bad "codex" "missing"
[[ -f "$PROJ/.opencode/plugins/jesus-loop.ts" ]] && ok "opencode plugin dropped" || bad "opencode" "missing"

# 2. Simulate a real /take-the-wheel from each harness — start three concurrent sessions.
bash "$ROOT/scripts/setup-wheel.sh" --session refactor --north-star "no behaviour change" "extract auth" >/dev/null
bash "$ROOT/scripts/setup-wheel.sh" --session migrate "rename users.id" >/dev/null
[[ -f "$PROJ/.claude/jesus-loop.refactor.local.md" ]] && [[ -f "$PROJ/.claude/jesus-loop.migrate.local.md" ]] \
  && ok "two cc sessions coexist after take-the-wheel" || bad "cc sessions" "missing"

bash "$ROOT/scripts/setup-wheel.sh" --state-dir .codex --session demo --north-star "near 1:1 port" "ship codex" >/dev/null
[[ -f "$PROJ/.codex/jesus-loop.demo.local.md" ]] && ok "codex session via setup-wheel --state-dir" || bad "codex setup" "missing"

# 3. Fire each harness's installed Stop hook end-to-end.
sleep 1; touch "$PROJ/.claude/jesus-loop.refactor.local.md"
CC_OUT=$(echo '{}' | env CLAUDE_PLUGIN_ROOT="$ROOT" bash "$ROOT/hooks/stop-hook.sh")
echo "$CC_OUT" | jq -e '.decision == "block"' >/dev/null \
  && echo "$CC_OUT" | jq -r .reason | grep -q "no behaviour change" \
  && echo "$CC_OUT" | jq -r .reason | grep -q "FIB PARALLELISM" \
  && ok "cc hook fires E2E with steered north_star + fib budget" \
  || bad "cc e2e" "$(echo "$CC_OUT" | jq -r .systemMessage)"

CODEX_HOOK_CMD=$(jq -r '.Stop[0].hooks[0].command' "$FAKE_HOME/.codex/hooks.json")
CX_OUT=$(echo '{}' | env JL_SESSION=demo bash -c "$CODEX_HOOK_CMD")
echo "$CX_OUT" | jq -e '.decision == "block"' >/dev/null \
  && echo "$CX_OUT" | jq -r .reason | grep -q "near 1:1 port" \
  && ok "codex installed hook fires E2E" || bad "codex e2e" "$(echo "$CX_OUT" | head -3)"

# 4. Live steer — change refactor's north star mid-loop.
bash "$ROOT/scripts/steer.sh" --session refactor "preserve all public API shapes" >/dev/null
sleep 1; touch "$PROJ/.claude/jesus-loop.refactor.local.md"
CC2=$(echo '{}' | env CLAUDE_PLUGIN_ROOT="$ROOT" bash "$ROOT/hooks/stop-hook.sh")
echo "$CC2" | jq -r .reason | grep -q "preserve all public API shapes" \
  && ok "live steer reaches next firing's prompt" || bad "steer e2e" "missing new north_star"

# 5. Sermon prints multi-session teachings.
echo "alpha tch" > "$PROJ/.claude/jesus-loop.refactor.teachings.local.md"
echo "beta tch"  > "$PROJ/.claude/jesus-loop.migrate.teachings.local.md"
ALL=$(bash "$ROOT/scripts/sermon.sh" --all --state-dir "$PROJ/.claude")
echo "$ALL" | grep -q "alpha tch" && echo "$ALL" | grep -q "beta tch" \
  && ok "sermon --all prints every session" || bad "sermon all" "$ALL"

# 6. Park one then all.
bash "$ROOT/scripts/park.sh" --session migrate --state-dir "$PROJ/.claude" >/dev/null
[[ -f "$PROJ/.claude/jesus-loop.refactor.local.md" ]] && [[ ! -f "$PROJ/.claude/jesus-loop.migrate.local.md" ]] \
  && ok "park --session targets one session only" || bad "park single" "$(ls "$PROJ/.claude/")"

bash "$ROOT/scripts/park.sh" --all --state-dir "$PROJ/.claude" >/dev/null
[[ -z "$(ls "$PROJ"/.claude/jesus-loop.*.local.md 2>/dev/null | { grep -v teachings || true; })" ]] \
  && ok "park --all clears all sessions (teachings preserved)" || bad "park all" "$(ls "$PROJ/.claude/")"

# 7. Sabbath now allows fan-out for repair.
mkdir -p "$TMP/sab/.codex"
cat > "$TMP/sab/.codex/jesus-loop.x.local.md" <<'EOF'
---
active: true
step: 6
harness_ws:
completion_promise: "SHIPPED"
---
sabbath fanout test
EOF
S7=$(echo '{}' | env JL_PLUGIN_ROOT="$ROOT" JL_STATE_DIR="$TMP/sab/.codex" JL_SESSION=x JL_OUTPUT_FORMAT=codex bash "$ROOT/core/loop.sh")
REASON=$(echo "$S7" | jq -r .reason)
echo "$REASON" | grep -q "SABBATH BREAK" \
  && echo "$REASON" | grep -q "If HOLD or REJECT, you MAY then spawn workers" \
  && ok "sabbath permits fan-out for HOLD/REJECT repair" \
  || bad "sabbath fanout" "$(echo "$REASON" | grep -A2 'FIB PARALLELISM')"

# 8. Uninstall reverses.
HOME="$FAKE_HOME" bash "$ROOT/scripts/install.sh" uninstall codex >/dev/null
[[ ! -d "$FAKE_HOME/.codex/jesus-loop" ]] && ok "uninstall codex reverses" || bad "uninstall" "still there"

cd "$ROOT"
echo
printf 'Dominion-E2E: %s passed · %s failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]] || exit 1
