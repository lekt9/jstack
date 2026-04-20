#!/bin/bash
# Jesus Loop — Step-3 artifact signals.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d -t jl-signals.XXXXXX)
trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
ok()   { printf '  ✓ %s\n' "$1"; PASS=$((PASS+1)); }
bad()  { printf '  ✗ %s\n    %s\n' "$1" "$2"; FAIL=$((FAIL+1)); }
command -v jq >/dev/null || { echo "missing jq" >&2; exit 2; }

mk_state() {
  local dir="$1" session="$2" step="$3" north="${4:-}"
  mkdir -p "$dir"
  {
    printf -- '---\nactive: true\nstep: %s\nharness_ws:\ncompletion_promise: "SHIPPED"\n' "$step"
    [[ -n "$north" ]] && printf 'north_star: "%s"\n' "$north"
    printf -- '---\n\nDemo task body.\n'
  } > "$dir/jesus-loop.$session.local.md"
}
run_core() {
  local fmt="$1" dir="$2" session="$3"
  echo '{}' | env JL_PLUGIN_ROOT="$ROOT" JL_STATE_DIR="$dir" JL_SESSION="$session" \
    JL_OUTPUT_FORMAT="$fmt" bash "$ROOT/core/loop.sh"
}

echo "== core/loop.sh =="

mk_state "$TMP/.codex" alpha 2
OUT=$(run_core codex "$TMP/.codex" alpha)
echo "$OUT" | jq -e '.decision == "block" and (.reason|type) == "string" and (.systemMessage|type) == "string"' >/dev/null \
  && ok "codex JSON shape valid" || bad "codex JSON shape" "$OUT"

NEW_STEP=$(sed -n 's/^step: //p' "$TMP/.codex/jesus-loop.alpha.local.md")
[[ "$NEW_STEP" == "3" ]] && ok "step advanced 2→3" || bad "step advance" "got $NEW_STEP"

if echo "$OUT" | jq -r '.reason' | grep -q "^CURRENT NORTH STAR (set by user"; then
  bad "north_star injected when unset" "should be absent"
else
  ok "no north_star section when unset"
fi

mk_state "$TMP/.codex" beta 1 "ship the codex adapter"
OUT2=$(run_core codex "$TMP/.codex" beta)
echo "$OUT2" | jq -r '.reason' | grep -q "ship the codex adapter" \
  && ok "north_star injected when set" || bad "north_star injection" "$(echo "$OUT2" | jq -r .reason | head -5)"

mk_state "$TMP/.codex" omega 0 "auto-detect codex session"
OUT_AUTO=$(echo '{}' | env JL_PLUGIN_ROOT="$ROOT" JL_STATE_DIR="$TMP/.codex" JL_OUTPUT_FORMAT=codex bash "$ROOT/core/loop.sh")
echo "$OUT_AUTO" | jq -r '.systemMessage' | grep -q "\[omega\]" \
  && ok "core auto-detects newest codex session when JL_SESSION unset" || bad "core auto-detect" "$(echo "$OUT_AUTO" | jq -r .systemMessage)"

A=$(sed -n 's/^step: //p' "$TMP/.codex/jesus-loop.alpha.local.md")
B=$(sed -n 's/^step: //p' "$TMP/.codex/jesus-loop.beta.local.md")
[[ "$A" == "3" && "$B" == "2" ]] && ok "two sessions advance independently" || bad "session isolation" "alpha=$A beta=$B"

mk_state "$TMP/.raw" gamma 1
RAW=$(run_core raw "$TMP/.raw" gamma)
echo "$RAW" | head -1 | grep -q "Jesus Loop \[session: gamma\]" \
  && ok "raw mode prints plain prompt" || bad "raw mode" "$(echo "$RAW" | head -2)"

if echo '{}' | JL_PLUGIN_ROOT="$ROOT" JL_STATE_DIR="$TMP/.missing" JL_SESSION=zzz JL_OUTPUT_FORMAT=codex bash "$ROOT/core/loop.sh" >/dev/null 2>&1; then
  bad "empty state dir should exit nonzero" "exited 0"
else
  ok "empty state dir → exit 1"
fi

echo
echo "== scripts/steer.sh =="

bash "$ROOT/scripts/steer.sh" --session beta --state-dir "$TMP/.codex" "new direction" >/dev/null
grep -q '^north_star: "new direction"$' "$TMP/.codex/jesus-loop.beta.local.md" \
  && ok "steer rewrites existing north_star" || bad "steer rewrite" "$(grep north_star "$TMP/.codex/jesus-loop.beta.local.md")"

mk_state "$TMP/.codex" delta 1
bash "$ROOT/scripts/steer.sh" --session delta --state-dir "$TMP/.codex" "first aim" >/dev/null
grep -q '^north_star: "first aim"$' "$TMP/.codex/jesus-loop.delta.local.md" \
  && ok "steer inserts north_star when absent" || bad "steer insert" "$(grep north_star "$TMP/.codex/jesus-loop.delta.local.md")"

bash "$ROOT/scripts/steer.sh" --session delta --state-dir "$TMP/.codex" "first aim" >/dev/null
COUNT=$(grep -c '^north_star:' "$TMP/.codex/jesus-loop.delta.local.md")
[[ "$COUNT" == "1" ]] && ok "steer idempotent (single north_star line)" || bad "steer idempotent" "found $COUNT lines"

echo
echo "== adapters =="

jq -e '.Stop[0].hooks[0].command' "$ROOT/adapters/codex/hooks.json" >/dev/null \
  && ok "codex hooks.json valid + has Stop.hooks[0].command" || bad "codex hooks.json" "invalid"

mk_state "$TMP/.codex" eps 1
OUT3=$(echo '{}' | env JL_PLUGIN_ROOT="$ROOT" JL_STATE_DIR="$TMP/.codex" JL_SESSION=eps bash "$ROOT/adapters/codex/stop-hook.sh")
echo "$OUT3" | jq -e '.decision == "block"' >/dev/null \
  && ok "adapters/codex/stop-hook.sh emits codex JSON" || bad "codex adapter" "$OUT3"

echo
echo "== scripts/record-pair.sh =="

mkdir -p "$TMP/record/.codex" "$TMP/plugin/data"
cat > "$TMP/record/.codex/jesus-loop.theta.local.md" <<'EOF'
---
active: true
step: 1
started_at: "2026-04-20T00:00:00Z"
---

Theta task body.
EOF
printf '%s\n' '{ "url": "", "write_token": "" }' > "$TMP/plugin/data/server.json"
REC_OUT=$(cd "$TMP/record" && env JL_PLUGIN_ROOT="$TMP/plugin" JL_STATE_DIR=.codex JL_SESSION=theta bash "$ROOT/scripts/record-pair.sh" --iteration 1 --step 1 --genesis-day light --verse "Genesis 1:3" --label "let there be light" --lesson "x" 2>&1)
echo "$REC_OUT" | grep -q "no endpoint configured" \
  && ok "record-pair finds codex state via JL_STATE_DIR/JL_SESSION" || bad "record-pair codex state" "$REC_OUT"

REC_OUT2=$(cd "$TMP/record" && env JL_PLUGIN_ROOT="$TMP/plugin" bash "$ROOT/scripts/record-pair.sh" --iteration 1 --step 1 --genesis-day light --verse "Genesis 1:3" --label "let there be light" --lesson "x" 2>&1)
echo "$REC_OUT2" | grep -q "no endpoint configured" \
  && ok "record-pair auto-detects codex state without Claude-only path" || bad "record-pair auto-detect" "$REC_OUT2"

grep -q '"session.stopping"' "$ROOT/adapters/opencode/plugin.ts" \
  && grep -q 'event:' "$ROOT/adapters/opencode/plugin.ts" \
  && ok "opencode plugin.ts exports session.stopping + event handlers" \
  || bad "opencode plugin.ts" "missing handler keys"

echo
printf 'Signals: %s passed · %s failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]] || exit 1
