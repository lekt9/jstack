#!/bin/bash
# Dominion — end-to-end across a fresh repo, all three harnesses.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d -t jl-e2e.XXXXXX)
trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
ok()  { printf '  ✓ %s\n' "$1"; PASS=$((PASS+1)); }
bad() { printf '  ✗ %s\n    %s\n' "$1" "$2"; FAIL=$((FAIL+1)); }

# === E2E 1: Claude Code path — full lifecycle in a fresh repo ===
echo "== claude-code e2e =="
cd "$TMP"
mkdir cc && cd cc
# 1. User runs /take-the-wheel via setup-wheel.sh
bash "$ROOT/scripts/setup-wheel.sh" --session refactor --north-star "no behaviour change" \
  "extract auth out of routes" >/dev/null
[[ -f .claude/jesus-loop.refactor.local.md ]] && ok "setup-wheel writes session-scoped state" || bad "setup-wheel" "missing state"

# 2. User starts a SECOND concurrent session
bash "$ROOT/scripts/setup-wheel.sh" --session migrate "rename users.id to users.uuid" >/dev/null
[[ -f .claude/jesus-loop.migrate.local.md && -f .claude/jesus-loop.refactor.local.md ]] \
  && ok "two concurrent sessions coexist" || bad "concurrent sessions" "missing one"

# 3. Claude Code Stop hook fires. The thin adapter picks the most-recently-touched session.
OUT=$(echo '{}' | env CLAUDE_PLUGIN_ROOT="$ROOT" bash "$ROOT/hooks/stop-hook.sh")
DECISION=$(echo "$OUT" | jq -r .decision)
SYSMSG=$(echo "$OUT" | jq -r .systemMessage)
[[ "$DECISION" == "block" ]] && ok "claude-code adapter emits decision:block" || bad "cc adapter decision" "$OUT"
echo "$SYSMSG" | grep -q "\[migrate\]" && ok "cc adapter picked most-recent session (migrate)" || bad "cc session pick" "sysmsg=$SYSMSG"

# 4. Steer the refactor session mid-flight (older session).
bash "$ROOT/scripts/steer.sh" --session refactor "preserve all public API shapes" >/dev/null
grep -q '^north_star: "preserve all public API shapes"$' .claude/jesus-loop.refactor.local.md \
  && ok "steer rewrites refactor session live" || bad "steer cc" "$(grep north_star .claude/jesus-loop.refactor.local.md)"

# 5. Touch refactor newer than migrate, fire hook again, confirm refactor now drives.
sleep 1; touch .claude/jesus-loop.refactor.local.md
OUT2=$(echo '{}' | env CLAUDE_PLUGIN_ROOT="$ROOT" bash "$ROOT/hooks/stop-hook.sh")
echo "$OUT2" | jq -r .systemMessage | grep -q "\[refactor\]" \
  && ok "newer mtime flips active session to refactor" || bad "cc session flip" "$(echo "$OUT2" | jq -r .systemMessage)"

# 6. Reply contains the steered north star.
echo "$OUT2" | jq -r .reason | grep -q "preserve all public API shapes" \
  && ok "steered north_star reaches injected prompt" || bad "north_star injection e2e" "missing"

# 7. Backward-compat: legacy single-state file gets migrated to .default session.
rm -rf .claude
mkdir .claude
cat > .claude/jesus-loop.local.md <<'EOF'
---
active: true
step: 1
harness_ws:
completion_promise: "SHIPPED"
---

legacy task body
EOF
echo '{}' | env CLAUDE_PLUGIN_ROOT="$ROOT" bash "$ROOT/hooks/stop-hook.sh" >/dev/null
[[ -f .claude/jesus-loop.default.local.md && ! -f .claude/jesus-loop.local.md ]] \
  && ok "legacy single-state file migrated to .default session" \
  || bad "legacy migration" "$(ls .claude/)"

# === E2E 2: Codex path ===
echo
echo "== codex e2e =="
cd "$TMP" && mkdir cx && cd cx
JL_PLUGIN_ROOT="$ROOT" bash "$ROOT/scripts/setup-wheel.sh" --state-dir .codex --session demo \
  --north-star "near 1:1 port" "ship codex adapter" >/dev/null
[[ -f .codex/jesus-loop.demo.local.md ]] && ok "setup-wheel --state-dir .codex" || bad "codex setup" "missing"

OUT3=$(echo '{}' | env JL_PLUGIN_ROOT="$ROOT" JL_SESSION=demo bash "$ROOT/adapters/codex/stop-hook.sh")
echo "$OUT3" | jq -e '.decision == "block"' >/dev/null \
  && ok "codex adapter emits decision:block" || bad "codex adapter" "$OUT3"
echo "$OUT3" | jq -r .reason | grep -q "near 1:1 port" \
  && ok "codex adapter passes north_star through core" || bad "codex north_star" "missing"

# === E2E 3: opencode plugin TS shape sanity ===
echo
echo "== opencode plugin shape =="
grep -q "JL_OUTPUT_FORMAT" "$ROOT/adapters/opencode/plugin.ts" \
  && grep -q "JL_SESSION" "$ROOT/adapters/opencode/plugin.ts" \
  && grep -q "JL_STATE_DIR" "$ROOT/adapters/opencode/plugin.ts" \
  && ok "opencode plugin spawns core with full env contract" \
  || bad "opencode plugin env" "missing one of JL_OUTPUT_FORMAT/JL_SESSION/JL_STATE_DIR"

echo
printf 'Dominion: %s passed · %s failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]] || exit 1
