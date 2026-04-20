#!/bin/bash

# POST one validated (scripture, applied-lesson) pair to the Jesus Loop
# Worker. Invoked by the assistant each step.
#
# Endpoint precedence:
#   1. $PLUGIN_ROOT/.jesus-loop-env   (user's own server, gitignored)
#   2. $PLUGIN_ROOT/data/server.json  (central telemetry, public in repo)
#   3. skip silently if neither provides URL + token
#
# Fails soft: never blocks the loop. A network or auth problem emits a
# warning to stderr and exits 0.

set -euo pipefail

ITERATION=""; STEP=""; GENESIS_DAY=""; HARNESS_WS=""; VERDICT=""
VERSE=""; LABEL=""; LESSON=""; OUTCOME=""
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
ENV_FILE="$PLUGIN_ROOT/.jesus-loop-env"
SERVER_JSON="$PLUGIN_ROOT/data/server.json"

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

command -v jq   >/dev/null || { echo "record-pair: jq missing. Skipping." >&2;   exit 0; }
command -v curl >/dev/null || { echo "record-pair: curl missing. Skipping." >&2; exit 0; }

# Resolve endpoint: env file wins; fall back to committed server.json.
URL=""
TOKEN=""
SOURCE=""
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  set +u; source "$ENV_FILE"; set -u
  if [[ -n "${JESUS_LOOP_URL:-}" && -n "${WRITE_TOKEN:-}" ]]; then
    URL="$JESUS_LOOP_URL"; TOKEN="$WRITE_TOKEN"; SOURCE="env"
  fi
fi
if [[ -z "$URL" ]] && [[ -f "$SERVER_JSON" ]]; then
  CENTRAL_URL=$(jq -r '.url   // ""' "$SERVER_JSON" 2>/dev/null || echo "")
  CENTRAL_TOK=$(jq -r '.write_token // ""' "$SERVER_JSON" 2>/dev/null || echo "")
  if [[ -n "$CENTRAL_URL" && -n "$CENTRAL_TOK" ]]; then
    URL="$CENTRAL_URL"; TOKEN="$CENTRAL_TOK"; SOURCE="central"
  fi
fi
if [[ -z "$URL" ]]; then
  echo "record-pair: no endpoint configured (neither $ENV_FILE nor $SERVER_JSON). Skipping." >&2
  exit 0
fi

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
  -X POST "$URL/pairs" \
  -H "Authorization: Bearer $TOKEN" \
  -H 'content-type: application/json' \
  --max-time 10 \
  --data "$PAYLOAD" 2>/dev/null || echo 000)

BODY=$(cat /tmp/jesus-loop-record.$$ 2>/dev/null || true)
rm -f /tmp/jesus-loop-record.$$

if [[ "$HTTP_CODE" == "201" ]]; then
  ID=$(echo "$BODY" | jq -r '.id // "?"' 2>/dev/null || echo "?")
  echo "✓ Recorded step ${STEP:-?}/${GENESIS_DAY:-?} → $URL ($SOURCE, $VERSE — $LABEL, id=$ID)."
else
  echo "record-pair: server responded $HTTP_CODE — $BODY. Loop continues." >&2
fi

exit 0
