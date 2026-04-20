#!/bin/bash

# Jesus Loop Stop Hook — 7 Genesis-day steps.
# Each iteration: pick the step's structural verse + a rotating tactical
# parallel (offset so step 1 does not collide with its Genesis companion),
# inject both with quotes, require element-by-element mapping, and do the
# concrete work. If the step is stuck, the assistant may invoke
# scripts/break-harness.sh to scope a full fib-harness child cycle.

set -euo pipefail

HOOK_INPUT=$(cat)

STATE_FILE=".claude/jesus-loop.local.md"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
CREATION_FILE="$PLUGIN_ROOT/data/creation-teachings.json"
TACTICAL_FILE="$PLUGIN_ROOT/data/teachings.json"
RECORD_SCRIPT="$PLUGIN_ROOT/scripts/record-pair.sh"
BREAK_SCRIPT="$PLUGIN_ROOT/scripts/break-harness.sh"

if [[ ! -f "$STATE_FILE" ]]; then
  exit 0
fi

FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE")
STEP=$(echo "$FRONTMATTER"      | grep '^step:'               | sed 's/step: *//')
HARNESS_WS=$(echo "$FRONTMATTER" | grep '^harness_ws:'         | sed 's/harness_ws: *//')
COMPLETION_PROMISE=$(echo "$FRONTMATTER" | grep '^completion_promise:' | sed 's/completion_promise: *//' | sed 's/^"\(.*\)"$/\1/')

if [[ ! "$STEP" =~ ^[0-9]+$ ]]; then
  echo "Jesus loop: state file corrupted. Stopping." >&2
  rm "$STATE_FILE"
  exit 0
fi

TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path')
LAST_OUTPUT=""
if [[ -f "$TRANSCRIPT_PATH" ]] && grep -q '"role":"assistant"' "$TRANSCRIPT_PATH"; then
  LAST_LINE=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -1)
  LAST_OUTPUT=$(echo "$LAST_LINE" | jq -r '.message.content | map(select(.type == "text")) | map(.text) | join("\n")' 2>/dev/null || echo "")
fi

# Completion check: promise only valid at/after Step 7.
if [[ -n "$COMPLETION_PROMISE" ]] && [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$LAST_OUTPUT" ]]; then
  PROMISE_TEXT=$(echo "$LAST_OUTPUT" | perl -0777 -pe 's/.*?<promise>(.*?)<\/promise>.*/$1/s; s/^\s+|\s+$//g; s/\s+/ /g' 2>/dev/null || echo "")
  if [[ -n "$PROMISE_TEXT" ]] && [[ "$PROMISE_TEXT" = "$COMPLETION_PROMISE" ]]; then
    echo "Jesus loop: promise fulfilled. The seven days are complete. Parking."
    rm "$STATE_FILE"
    exit 0
  fi
fi

# If a harness break is in progress, stay on the current step until verdict
# hits and the assistant clears harness_ws.
if [[ -n "$HARNESS_WS" ]] && [[ "$HARNESS_WS" != "null" ]]; then
  NEXT_STEP="$STEP"
  PHASE="harness"
else
  NEXT_STEP=$((STEP + 1))
  if [[ $NEXT_STEP -gt 7 ]]; then
    NEXT_STEP=7
    PHASE="sabbath-hold"
  else
    PHASE="step"
  fi
fi

TASK_TEXT=$(awk '/^---$/{i++; next} i>=2' "$STATE_FILE")
if [[ -z "$TASK_TEXT" ]]; then
  echo "Jesus loop: no task in state file. Stopping." >&2
  rm "$STATE_FILE"
  exit 0
fi

# Load teachings.
if [[ "$PHASE" == "harness" ]]; then
  STRUCT_REF="Isaiah 28:13"
  STRUCT_QUOTE="But the word of the LORD was unto them precept upon precept, precept upon precept; line upon line, line upon line; here a little, and there a little."
  COMPANION_REF="Galatians 6:9"
  COMPANION_QUOTE="And let us not be weary in well doing: for in due season we shall reap, if we faint not."
  GENESIS_DAY="repair"
  LABEL="precept upon precept / not weary in well doing"
  PATTERN="Repair is fractal. Each stuck step earns its own full cycle — line upon line, precept upon precept — scoped to that single thing."
  PROBLEM_MAP="Your step $STEP is stuck and a fib-harness is running in $HARNESS_WS. Keep working there until verdict = promote, then clear harness_ws in $STATE_FILE."
  APPLY="Work the harness. Run fib-harness judge / verdict. When verdict=promote, edit $STATE_FILE to blank harness_ws (set \`harness_ws:\`), then the main loop advances."
else
  IDX=$((NEXT_STEP - 1))
  STRUCT_REF=$(jq -r --argjson i "$IDX" '.[$i].primary_ref' "$CREATION_FILE")
  STRUCT_QUOTE=$(jq -r --argjson i "$IDX" '.[$i].primary_quote' "$CREATION_FILE")
  COMPANION_REF=$(jq -r --argjson i "$IDX" '.[$i].companion_ref' "$CREATION_FILE")
  COMPANION_QUOTE=$(jq -r --argjson i "$IDX" '.[$i].companion_quote' "$CREATION_FILE")
  GENESIS_DAY=$(jq -r --argjson i "$IDX" '.[$i].genesis_day' "$CREATION_FILE")
  LABEL=$(jq -r --argjson i "$IDX" '.[$i].label' "$CREATION_FILE")
  PATTERN=$(jq -r --argjson i "$IDX" '.[$i].pattern' "$CREATION_FILE")
  PROBLEM_MAP=$(jq -r --argjson i "$IDX" '.[$i].problem_map_template' "$CREATION_FILE")
  APPLY=$(jq -r --argjson i "$IDX" '.[$i].apply' "$CREATION_FILE")
fi

# Rotating tactical parallel. Offset: step N → slot (N mod count), so step 1
# lands on slot 1, avoiding collision with Genesis companion at slot 0.
TACTICAL_COUNT=0
if [[ -f "$TACTICAL_FILE" ]]; then
  TACTICAL_COUNT=$(jq 'length' "$TACTICAL_FILE" 2>/dev/null || echo 0)
fi
TACT_REF=""
TACT_QUOTE=""
TACT_LABEL=""
TACT_PATTERN=""
TACT_APPLY=""
if [[ "$TACTICAL_COUNT" =~ ^[0-9]+$ ]] && [[ $TACTICAL_COUNT -gt 0 ]]; then
  T_IDX=$(( NEXT_STEP % TACTICAL_COUNT ))
  TACT_REF=$(jq -r --argjson i "$T_IDX" '.[$i].ref'     "$TACTICAL_FILE")
  TACT_QUOTE=$(jq -r --argjson i "$T_IDX" '.[$i].quote' "$TACTICAL_FILE")
  TACT_LABEL=$(jq -r --argjson i "$T_IDX" '.[$i].label' "$TACTICAL_FILE")
  TACT_PATTERN=$(jq -r --argjson i "$T_IDX" '.[$i].pattern' "$TACTICAL_FILE")
  TACT_APPLY=$(jq -r --argjson i "$T_IDX" '.[$i].apply'     "$TACTICAL_FILE")
fi

TMP_PROMPT=$(mktemp -t jesus-loop-prompt.XXXXXX)
trap 'rm -f "$TMP_PROMPT"' EXIT

EFFECTIVE_PROMISE="${COMPLETION_PROMISE:-SHIPPED}"
[[ "$EFFECTIVE_PROMISE" == "null" ]] && EFFECTIVE_PROMISE="SHIPPED"

{
  printf 'Jesus Loop — Step %s of 7 (Genesis Day: %s — %s)\n\n' "$NEXT_STEP" "$GENESIS_DAY" "$LABEL"

  printf 'STRUCTURAL VERSE (cite verbatim in your reply):\n'
  printf '  %s — "%s"\n' "$STRUCT_REF"    "$STRUCT_QUOTE"
  printf '  %s — "%s"\n\n' "$COMPANION_REF" "$COMPANION_QUOTE"
  printf 'Structural pattern: %s\n\n' "$PATTERN"

  if [[ -n "$TACT_REF" ]]; then
    printf 'TACTICAL PARALLEL (cite verbatim in your reply):\n'
    printf '  %s — "%s"\n' "$TACT_REF" "$TACT_QUOTE"
    printf '  Pattern: %s\n'     "$TACT_PATTERN"
    printf '  Apply:   %s\n\n'   "$TACT_APPLY"
  fi

  printf 'PARALLEL TO YOUR PROBLEM:\n'
  printf '  %s\n\n' "$PROBLEM_MAP"

  printf 'REQUIRED STRUCTURE OF YOUR REPLY:\n'
  printf '  1. Quote both verses (structural + tactical) verbatim, each with its reference.\n'
  printf '  2. Element-by-element mapping: one short paragraph showing how your current\n'
  printf '     work state aligns structurally to the verses. Name the concrete match, not\n'
  printf '     a thematic one.\n'
  printf '  3. Append one line to .claude/jesus-loop.teachings.local.md:\n'
  printf '     - [step %s / %s] %s — %s — <one-line applied lesson>\n' "$NEXT_STEP" "$GENESIS_DAY" "$STRUCT_REF" "$LABEL"
  printf '  4. Record the pair to the server:\n'
  printf '     %s --iteration %s --step %s --genesis-day %s --verse "%s" --label "%s" --lesson "<your one-liner>"\n' \
    "$RECORD_SCRIPT" "$NEXT_STEP" "$NEXT_STEP" "$GENESIS_DAY" "$STRUCT_REF" "$LABEL"
  printf '  5. Do the step work: %s\n' "$APPLY"

  if [[ "$PHASE" != "harness" ]]; then
    printf '\n'
    printf 'IF STEP CANNOT CLOSE IN ONE PASS:\n'
    printf '  Invoke the harness break for this step instead of faking progress:\n'
    printf '    %s --step %s --scope "<what specifically is stuck>"\n' "$BREAK_SCRIPT" "$NEXT_STEP"
    printf '  This spawns a full fib-harness child (1-1-2-3-5-8 agents across 6 days)\n'
    printf '  scoped to the stuck sub-problem. When that verdict lands, clear harness_ws\n'
    printf '  in the state file and the loop advances.\n'
  fi

  if [[ "$NEXT_STEP" -eq 7 ]] && [[ "$PHASE" != "harness" ]]; then
    printf '\n'
    printf 'COMPLETION PROMISE:\n'
    printf '  If the seven days are genuinely complete and the verdict is PROMOTE,\n'
    printf '  output the EXACT phrase: <promise>%s</promise>\n' "$EFFECTIVE_PROMISE"
    printf '  Do not output a false promise. If HOLD, name what is missing and loop\n'
    printf '  back to the step that produced it by editing step: in %s.\n' "$STATE_FILE"
  fi

  printf '\n'
  printf 'TASK (unchanged since Step 1):\n%s\n' "$TASK_TEXT"
} > "$TMP_PROMPT"

FULL_PROMPT=$(cat "$TMP_PROMPT")

if [[ "$PHASE" != "harness" ]]; then
  TEMP_STATE="${STATE_FILE}.tmp.$$"
  sed "s/^step: .*/step: $NEXT_STEP/" "$STATE_FILE" > "$TEMP_STATE"
  mv "$TEMP_STATE" "$STATE_FILE"
fi

if [[ "$PHASE" == "harness" ]]; then
  SYSTEM_MSG="🕊 Jesus loop · Step $STEP · harness active ($HARNESS_WS)"
elif [[ "$NEXT_STEP" -eq 7 ]]; then
  SYSTEM_MSG="🕊 Jesus loop · Step 7/7 Sabbath · exit with <promise>$EFFECTIVE_PROMISE</promise> when PROMOTE is TRUE"
else
  SYSTEM_MSG="🕊 Jesus loop · Step $NEXT_STEP/7 · $GENESIS_DAY ($LABEL)"
fi

jq -n \
  --arg prompt "$FULL_PROMPT" \
  --arg msg "$SYSTEM_MSG" \
  '{decision: "block", reason: $prompt, systemMessage: $msg}'

exit 0
