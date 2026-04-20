#!/bin/bash

# POST one validated (scripture, applied-lesson) pair to the Jesus Loop
# Worker. Invoked by the assistant each step.
#
# Usage:
#   record-pair.sh --iteration 5 --step 5 --genesis-day creatures \\
#                  --verse "Luke 15:4" --label "the one lost sheep" \\
#                  --lesson "chased the single failing concurrency test" \\
#                  [--harness-ws /tmp/fib-...] [--verdict promote] [--outcome pass]
#
# Reads session_id + task from .claude/jesus-loop.local.md. Reads endpoint
# + token from $PLUGIN_ROOT/.jesus-loop-env. Fails soft if anything missing.

set -euo pipefail

ITERATION=""; STEP=""; GENESIS_DAY=""; HARNESS_WS=""; VERDICT=""
VERSE=""; LABEL=""; LESSON=""; OUTCOME=""
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
ENV_FILE="$PLUGIN_ROOT/.jesus-loop-env"

while [[ $# -gt 0 ]]; do
  case $1 in
    --iteration)    ITERATION="$2";   shift 2;;
    --step)         STEP="$2";        shift 2;;
    --genesis-day)  GENESIS_DAY="$2"; shift 2;;
    --harness-ws)   HARNESS_WS="$2";  shift 2;;
    --verdict)      VERDICT="$2";     shift 2;;
    --verse)        VERSE="$2";       shift 2;;
    --label)        LABEL="$2";       shift 2;;
    --lesson)       LESSON="$2";      shift 2;;
    --outcome)      OUTCOME="$2";     shift 2;;
    -h|--help) sed -n '3,15p' "$0"; exit 0;;
    *) echo "unknown arg: $1" >&2; exit 1;;
  esac
done

for f in ITERATION VERSE LABEL LESSON; do
  if [[ -z "${!f}" ]]; then
    echo "record-pair: missing --${f,,}; skipping server write." >&2
    exit 0
  fi
done

STATE=".claude/jesus-loop.local.md"
if [[ ! -f "$STATE" ]]; then
  echo "record-pair: no active loop ($STATE); skipping server write." >&2
  exit 0
fi

SESSION_ID=$(sed -n 's/^started_at: *"\(.*\)"/\1/p' "$STATE" | head -1)
TASK=$(awk '/^---$/{i++; next} i>=2' "$STATE")
PROJECT_DIR=$(pwd)
[[ -n "$SESSION_ID" ]] || SESSION_ID="unknown-session"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "record-pair: $ENV_FILE missing — run $PLUGIN_ROOT/scripts/init-db.sh first. Skipping." >&2
  exit 0
fi

# shellcheck disable=SC1090
set +u; source "$ENV_FILE"; set -u

if [[ -z "${JESUS_LOOP_URL:-}" || -z "${WRITE_TOKEN:-}" ]]; then
  echo "record-pair: JESUS_LOOP_URL or WRITE_TOKEN not set in $ENV_FILE. Skipping." >&2
  exit 0
fi

command -v jq   >/dev/null || { echo "record-pair: jq missing. Skipping." >&2;   exit 0; }
command -v curl >/dev/null || { echo "record-pair: curl missing. Skipping." >&2; exit 0; }

PAYLOAD=$(jq -n \
  --arg session_id     "$SESSION_ID" \
  --arg project_dir    "$PROJECT_DIR" \
  --arg task           "$TASK" \
  --argjson iteration  "$ITERATION" \
  --arg verse_ref      "$VERSE" \
  --arg pattern_label  "$LABEL" \
  --arg applied_lesson "$LESSON" \
  --arg step           "$STEP" \
  --arg genesis_day    "$GENESIS_DAY" \
  --arg harness_ws     "$HARNESS_WS" \
  --arg verdict        "$VERDICT" \
  --arg outcome        "$OUTCOME" \
  '{session_id:$session_id, project_dir:$project_dir, task:$task,
    iteration:$iteration, verse_ref:$verse_ref, pattern_label:$pattern_label,
    applied_lesson:$applied_lesson}
   + (if $step        == "" then {} else {step:($step|tonumber)} end)
   + (if $genesis_day == "" then {} else {genesis_day:$genesis_day} end)
   + (if $harness_ws  == "" then {} else {harness_ws:$harness_ws} end)
   + (if $verdict     == "" then {} else {verdict:$verdict} end)
   + (if $outcome     == "" then {} else {outcome:$outcome} end)')

HTTP_CODE=$(curl -sS -o /tmp/jesus-loop-record.$$ -w '%{http_code}' \
  -X POST "$JESUS_LOOP_URL/pairs" \
  -H "Authorization: Bearer $WRITE_TOKEN" \
  -H 'content-type: application/json' \
  --max-time 10 \
  --data "$PAYLOAD" 2>/dev/null || echo 000)

BODY=$(cat /tmp/jesus-loop-record.$$ 2>/dev/null || true)
rm -f /tmp/jesus-loop-record.$$

if [[ "$HTTP_CODE" == "201" ]]; then
  ID=$(echo "$BODY" | jq -r '.id // "?"' 2>/dev/null || echo "?")
  echo "✓ Recorded step ${STEP:-?}/${GENESIS_DAY:-?} to $JESUS_LOOP_URL ($VERSE — $LABEL, id=$ID)."
else
  echo "record-pair: server responded $HTTP_CODE — $BODY. Loop continues." >&2
fi

exit 0
