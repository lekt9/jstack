#!/bin/bash
# Jesus Loop — adversarial / edge behavior under real conditions.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d -t jl-creatures.XXXXXX)
trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
ok()  { printf '  ✓ %s\n' "$1"; PASS=$((PASS+1)); }
bad() { printf '  ✗ %s\n    %s\n' "$1" "$2"; FAIL=$((FAIL+1)); }

write_state() {
  local file="$1" step="$2" hw="${3:-}" promise="${4:-SHIPPED}" north="${5:-}"
  mkdir -p "$(dirname "$file")"
  {
    printf -- '---\nactive: true\nstep: %s\nharness_ws: %s\ncompletion_promise: "%s"\n' "$step" "$hw" "$promise"
    [[ -n "$north" ]] && printf 'north_star: "%s"\n' "$north"
    printf -- '---\n\nTask body.\n'
  } > "$file"
}
core() {
  local fmt="$1" dir="$2" session="$3" stdin="${4:-{\}}"
  echo "$stdin" | env JL_PLUGIN_ROOT="$ROOT" JL_STATE_DIR="$dir" JL_SESSION="$session" \
    JL_OUTPUT_FORMAT="$fmt" bash "$ROOT/core/loop.sh"
}

echo "== edges =="

# Edge 1: step at 7 must clamp (not 8).
write_state "$TMP/.codex/jesus-loop.s7.local.md" 7
core codex "$TMP/.codex" s7 >/dev/null
[[ "$(sed -n 's/^step: //p' "$TMP/.codex/jesus-loop.s7.local.md")" == "7" ]] \
  && ok "step clamps at 7 (sabbath-hold)" \
  || bad "step clamp" "got $(sed -n 's/^step: //p' "$TMP/.codex/jesus-loop.s7.local.md")"

# Edge 2: harness_ws set → step does NOT advance.
write_state "$TMP/.codex/jesus-loop.hw.local.md" 3 "/tmp/harness-ws"
core codex "$TMP/.codex" hw >/dev/null
[[ "$(sed -n 's/^step: //p' "$TMP/.codex/jesus-loop.hw.local.md")" == "3" ]] \
  && ok "harness_ws blocks step advance" \
  || bad "harness_ws block" "step changed"

echo
echo "== adversarial =="

# Adversarial 1: north_star with double-quotes and shell metachars via steer.sh.
write_state "$TMP/.codex/jesus-loop.adv.local.md" 1
HOSTILE='build "the thing"; rm -rf / && echo $(whoami)'
bash "$ROOT/scripts/steer.sh" --session adv --state-dir "$TMP/.codex" "$HOSTILE" >/dev/null
# State must contain the literal text and not have executed anything.
if grep -F "$HOSTILE" "$TMP/.codex/jesus-loop.adv.local.md" >/dev/null 2>&1; then
  ok "steer survives quotes + shell metachars (literal preserved)"
else
  bad "steer adversarial" "$(grep north_star "$TMP/.codex/jesus-loop.adv.local.md")"
fi

# Adversarial 2: core injects hostile north_star into prompt without breaking JSON.
OUT=$(core codex "$TMP/.codex" adv)
echo "$OUT" | jq -e '.decision == "block"' >/dev/null \
  && ok "core JSON survives hostile north_star" \
  || bad "core JSON adversarial" "$(echo "$OUT" | head -3)"

# Edge 3: completion promise present in transcript → state file removed, exit 1.
write_state "$TMP/.codex/jesus-loop.done.local.md" 7
TRANS="$TMP/transcript.jsonl"
printf '%s\n' '{"role":"assistant","message":{"content":[{"type":"text","text":"<promise>SHIPPED</promise>"}]}}' > "$TRANS"
if echo "{\"transcript_path\":\"$TRANS\"}" | env JL_PLUGIN_ROOT="$ROOT" JL_STATE_DIR="$TMP/.codex" JL_SESSION=done JL_OUTPUT_FORMAT=codex bash "$ROOT/core/loop.sh" >/dev/null 2>&1; then
  bad "promise should exit 1" "exited 0"
elif [[ -f "$TMP/.codex/jesus-loop.done.local.md" ]]; then
  bad "promise should remove state file" "still exists"
else
  ok "<promise>SHIPPED</promise> triggers parking (state removed, exit 1)"
fi

echo
echo "== concurrency =="

# Edge 4: two parallel invocations on same session — final step must be exactly 1 advance,
# not 2 (sed -i replace + atomic mv → last writer wins, never doubles).
write_state "$TMP/.codex/jesus-loop.race.local.md" 2
( core codex "$TMP/.codex" race >/dev/null ) &
( core codex "$TMP/.codex" race >/dev/null ) &
wait
FINAL=$(sed -n 's/^step: //p' "$TMP/.codex/jesus-loop.race.local.md")
if [[ "$FINAL" == "3" ]]; then
  ok "concurrent invocations advance once (last-writer-wins)"
elif [[ "$FINAL" == "4" ]]; then
  bad "concurrent invocations double-advanced" "step=$FINAL — race window in step rewrite"
else
  bad "concurrent invocations weird" "step=$FINAL"
fi

# Edge 5: two sessions racing in same dir don't corrupt each other.
write_state "$TMP/.codex/jesus-loop.r1.local.md" 1
write_state "$TMP/.codex/jesus-loop.r2.local.md" 4
( core codex "$TMP/.codex" r1 >/dev/null ) &
( core codex "$TMP/.codex" r2 >/dev/null ) &
wait
S1=$(sed -n 's/^step: //p' "$TMP/.codex/jesus-loop.r1.local.md")
S2=$(sed -n 's/^step: //p' "$TMP/.codex/jesus-loop.r2.local.md")
[[ "$S1" == "2" && "$S2" == "5" ]] \
  && ok "concurrent multi-session: r1 1→2, r2 4→5" \
  || bad "multi-session race" "r1=$S1 r2=$S2"

echo
printf 'Creatures: %s passed · %s failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]] || exit 1
