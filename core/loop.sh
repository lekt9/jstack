#!/bin/bash
# Jesus Loop — harness-agnostic core.
#
# Inputs (env):
#   JL_PLUGIN_ROOT      — root of the jesus-loop install (data/, scripts/)
#   JL_STATE_DIR        — dir holding state files (.claude | .codex | .opencode)
#   JL_SESSION          — session id; allows multiple concurrent loops per repo
#                         (default: "default"). State path = $JL_STATE_DIR/jesus-loop.$JL_SESSION.local.md
#   JL_OUTPUT_FORMAT    — claude-code | codex | raw     (default: raw)
#   JL_SYSMSG_FD        — fd to write the system-message line on (raw mode; default 3)
#
# Inputs (stdin): harness hook envelope JSON (must contain .transcript_path, may be {}).
#
# Outputs:
#   raw          — prompt to stdout, sysmsg to fd $JL_SYSMSG_FD if open
#   claude-code  — JSON {decision:"block", reason, systemMessage} to stdout
#   codex        — same JSON shape (codex uses the same decision/reason contract)
#
# Exit: 0 keep going · 1 no state / parked.

set -euo pipefail

JL_STATE_DIR="${JL_STATE_DIR:-.claude}"
JL_SESSION="${JL_SESSION:-default}"
JL_OUTPUT_FORMAT="${JL_OUTPUT_FORMAT:-raw}"
JL_SYSMSG_FD="${JL_SYSMSG_FD:-3}"
PLUGIN_ROOT="${JL_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

STATE_FILE="$JL_STATE_DIR/jesus-loop.$JL_SESSION.local.md"
TEACHINGS_FILE="$JL_STATE_DIR/jesus-loop.$JL_SESSION.teachings.local.md"
CREATION_FILE="$PLUGIN_ROOT/data/creation-teachings.json"
TACTICAL_FILE="$PLUGIN_ROOT/data/teachings.json"
RECORD_SCRIPT="bash $PLUGIN_ROOT/scripts/record-pair.sh"
BREAK_SCRIPT="bash $PLUGIN_ROOT/scripts/break-harness.sh"
STEER_SCRIPT="bash $PLUGIN_ROOT/scripts/steer.sh"

[[ -f "$STATE_FILE" ]] || exit 1

HOOK_INPUT=$(cat || true)

FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE")
fm_get() { echo "$FRONTMATTER" | { grep "^$1:" || true; } | head -1 | sed "s/^$1: *//" | sed 's/^"\(.*\)"$/\1/'; }
STEP=$(fm_get step)
HARNESS_WS=$(fm_get harness_ws)
COMPLETION_PROMISE=$(fm_get completion_promise)
NORTH_STAR=$(fm_get north_star)

if [[ ! "$STEP" =~ ^[0-9]+$ ]]; then
  echo "Jesus loop: state file corrupted ($STATE_FILE)." >&2
  rm -f "$STATE_FILE"
  exit 1
fi

TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || echo "")
LAST_OUTPUT=""
if [[ -n "$TRANSCRIPT_PATH" ]] && [[ -f "$TRANSCRIPT_PATH" ]] && grep -q '"role":"assistant"' "$TRANSCRIPT_PATH"; then
  LAST_LINE=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -1)
  LAST_OUTPUT=$(echo "$LAST_LINE" | jq -r '.message.content | map(select(.type == "text")) | map(.text) | join("\n")' 2>/dev/null || echo "")
fi

if [[ -n "$COMPLETION_PROMISE" ]] && [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$LAST_OUTPUT" ]]; then
  PROMISE_TEXT=$(echo "$LAST_OUTPUT" | perl -0777 -pe 's/.*?<promise>(.*?)<\/promise>.*/$1/s; s/^\s+|\s+$//g; s/\s+/ /g' 2>/dev/null || echo "")
  if [[ -n "$PROMISE_TEXT" ]] && [[ "$PROMISE_TEXT" = "$COMPLETION_PROMISE" ]]; then
    echo "Jesus loop [$JL_SESSION]: promise fulfilled. Parking." >&2
    rm -f "$STATE_FILE"
    exit 1
  fi
fi

if [[ -n "$HARNESS_WS" ]] && [[ "$HARNESS_WS" != "null" ]]; then
  NEXT_STEP="$STEP"; PHASE="harness"
else
  NEXT_STEP=$((STEP + 1))
  NEXT_STEP=$((STEP + 1))
  if [[ $NEXT_STEP -gt 9 ]]; then NEXT_STEP=9; PHASE="emergence-hold"; else PHASE="step"; fi
fi

TASK_TEXT=$(awk '/^---$/{i++; next} i>=2' "$STATE_FILE")
if [[ -z "$TASK_TEXT" ]]; then
  echo "Jesus loop: no task in state file." >&2
  rm -f "$STATE_FILE"
  exit 1
fi

if [[ "$PHASE" == "harness" ]]; then
  STRUCT_REF="Isaiah 28:13"
  STRUCT_QUOTE="But the word of the LORD was unto them precept upon precept, precept upon precept; line upon line, line upon line; here a little, and there a little."
  COMPANION_REF="Galatians 6:9"
  COMPANION_QUOTE="And let us not be weary in well doing: for in due season we shall reap, if we faint not."
  GENESIS_DAY="repair"
  LABEL="precept upon precept / not weary in well doing"
  PATTERN="Repair is fractal. Each stuck step earns its own full cycle."
  PROBLEM_MAP="Your step $STEP is stuck and a fib-harness is running in $HARNESS_WS."
  APPLY="Work the harness. When verdict=promote, blank harness_ws in $STATE_FILE."
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

TACTICAL_COUNT=0
[[ -f "$TACTICAL_FILE" ]] && TACTICAL_COUNT=$(jq 'length' "$TACTICAL_FILE" 2>/dev/null || echo 0)
TACT_REF=""; TACT_QUOTE=""; TACT_PATTERN=""; TACT_APPLY=""
if [[ "$TACTICAL_COUNT" =~ ^[0-9]+$ ]] && [[ $TACTICAL_COUNT -gt 0 ]]; then
  T_IDX=$(( NEXT_STEP % TACTICAL_COUNT ))
  TACT_REF=$(jq -r --argjson i "$T_IDX" '.[$i].ref'     "$TACTICAL_FILE")
  TACT_QUOTE=$(jq -r --argjson i "$T_IDX" '.[$i].quote' "$TACTICAL_FILE")
  TACT_PATTERN=$(jq -r --argjson i "$T_IDX" '.[$i].pattern' "$TACTICAL_FILE")
  TACT_APPLY=$(jq -r --argjson i "$T_IDX" '.[$i].apply'     "$TACTICAL_FILE")
fi

EFFECTIVE_PROMISE="${COMPLETION_PROMISE:-SHIPPED}"
[[ "$EFFECTIVE_PROMISE" == "null" ]] && EFFECTIVE_PROMISE="SHIPPED"

# Fibonacci parallelism budget per Genesis day:
#   Step 1 → 1 worker   (light: solo inventory)
#   Step 2 → 1 worker   (firmament: single architect, can't sub-divide vision)
#   Step 3 → 2 workers  (land: two parallel skeletons)
#   Step 4 → 3 workers  (luminaries: three independent signal axes)
#   Step 5 → 5 workers  (creatures: five adversarial probes in parallel)
#   Step 6 → 8 workers  (dominion: eight integration paths in parallel)
#   Step 7 → 1 worker   (sabbath: SINGLE-THREAD verdict; the breaking)
FIB_BUDGET=(1 1 2 3 5 8 1 13 21)
PARALLEL_N="${FIB_BUDGET[$((NEXT_STEP - 1))]:-1}"

# Per-harness fan-out hint (the verbs change; the budget doesn't).
case "${JL_OUTPUT_FORMAT:-raw}" in
  claude-code) FANOUT_HINT="Use the Agent tool to spawn $PARALLEL_N sub-agents in a single message (parallel tool calls). Each sub-agent owns one slice of this Genesis day's work. Synthesize results before recording the pair.";;
  codex)       FANOUT_HINT="Run $PARALLEL_N parallel workers via background jobs (\`( task1 ) & ( task2 ) & wait\`) or your harness's parallel primitive. Each worker owns one slice. Aggregate before recording.";;
  *)           FANOUT_HINT="Spawn $PARALLEL_N parallel workers via the harness's native primitive (Bun \`Promise.all\`, opencode \`client.session.prompt\` fan-out, etc.). Each worker owns one slice.";;
esac
[[ "$NEXT_STEP" -eq 7 ]] && FANOUT_HINT="SABBATH BREAK — render the verdict single-threaded first (PROMOTE / HOLD / REJECT). If PROMOTE, proceed to Step 8 (Judgement) where the books are opened. If HOLD or REJECT, you MAY spawn workers to repair, then re-render next firing."
[[ "$NEXT_STEP" -eq 8 ]] && FANOUT_HINT="JUDGEMENT — open the books. Spawn $PARALLEL_N adversarial auditors in parallel (each re-reads a slice of the artifact cold, no builder bias). Aggregate findings. Any artifact that cannot survive audit loops back before Step 9."
[[ "$NEXT_STEP" -eq 9 ]] && FANOUT_HINT="EMERGENCE — new heaven, new earth. Spawn $PARALLEL_N publishers in parallel (commit, tag, changelog, README, hand-off message, notify caller). Only then output <promise>$EFFECTIVE_PROMISE</promise> if the artifact is genuinely reachable by its intended user."


PROMPT=$( {
  printf 'Jesus Loop [session: %s] — Step %s of 9 (Genesis Day: %s — %s)\n\n' "$JL_SESSION" "$NEXT_STEP" "$GENESIS_DAY" "$LABEL"
  if [[ -n "$NORTH_STAR" ]] && [[ "$NORTH_STAR" != "null" ]]; then
    printf 'CURRENT NORTH STAR (set by user, may have changed since last step):\n  %s\n\n' "$NORTH_STAR"
  fi
  printf 'STRUCTURAL VERSE (cite verbatim):\n'
  printf '  %s — "%s"\n' "$STRUCT_REF"    "$STRUCT_QUOTE"
  printf '  %s — "%s"\n\n' "$COMPANION_REF" "$COMPANION_QUOTE"
  printf 'Structural pattern: %s\n\n' "$PATTERN"
  if [[ -n "$TACT_REF" ]]; then
    printf 'TACTICAL PARALLEL (cite verbatim):\n'
    printf '  %s — "%s"\n' "$TACT_REF" "$TACT_QUOTE"
    printf '  Pattern: %s\n  Apply:   %s\n\n' "$TACT_PATTERN" "$TACT_APPLY"
  fi
  printf 'PARALLEL TO YOUR PROBLEM:\n  %s\n\n' "$PROBLEM_MAP"
  printf 'REQUIRED REPLY STRUCTURE:\n'
  printf '  1. Quote both verses verbatim with refs.\n'
  printf '  2. Element-by-element mapping paragraph.\n'
  printf '  3. Append one line to %s:\n' "$TEACHINGS_FILE"
  printf '     - [step %s / %s] %s — %s — <one-line lesson>\n' "$NEXT_STEP" "$GENESIS_DAY" "$STRUCT_REF" "$LABEL"
  printf '  4. Record the pair:\n'
  printf '     %s --iteration %s --step %s --genesis-day %s --verse "%s" --label "%s" --lesson "<your one-liner>"\n' \
    "$RECORD_SCRIPT" "$NEXT_STEP" "$NEXT_STEP" "$GENESIS_DAY" "$STRUCT_REF" "$LABEL"
  printf '  5. Do the step work: %s\n' "$APPLY"
  printf '\nFIB PARALLELISM (Genesis Day %s of 9 → %s worker%s):\n  %s\n' \
    "$NEXT_STEP" "$PARALLEL_N" "$([[ "$PARALLEL_N" -eq 1 ]] && echo "" || echo "s")" "$FANOUT_HINT"
  printf '\nUSER STEERING:\n  Lewis can re-aim the north star at any time with:\n'
  printf '    %s --session %s "<new north star>"\n' "$STEER_SCRIPT" "$JL_SESSION"
  printf '  Re-read the CURRENT NORTH STAR section above each step before doing work.\n'
  if [[ "$PHASE" != "harness" ]]; then
    printf '\nIF STEP CANNOT CLOSE IN ONE PASS:\n'
    printf '    %s --step %s --session %s --scope "<what is stuck>"\n' "$BREAK_SCRIPT" "$NEXT_STEP" "$JL_SESSION"
  fi
  if [[ "$NEXT_STEP" -eq 9 ]] && [[ "$PHASE" != "harness" ]]; then
    printf '\nCOMPLETION PROMISE:\n  When PROMOTE is genuinely true, output exactly: <promise>%s</promise>\n' "$EFFECTIVE_PROMISE"
  fi
  printf '\nTASK (unchanged since Step 1):\n%s\n' "$TASK_TEXT"
} )

if [[ "$PHASE" != "harness" ]]; then
  TEMP_STATE="${STATE_FILE}.tmp.$$"
  sed "s/^step: .*/step: $NEXT_STEP/" "$STATE_FILE" > "$TEMP_STATE"
  mv "$TEMP_STATE" "$STATE_FILE"
fi

if [[ "$PHASE" == "harness" ]]; then
  SYSMSG="🕊 [$JL_SESSION] Step $STEP · harness ($HARNESS_WS)"
elif [[ "$NEXT_STEP" -eq 9 ]]; then
  SYSMSG="🕊 [$JL_SESSION] Step 9/9 Emergence · <promise>$EFFECTIVE_PROMISE</promise> when handed off"
elif [[ "$NEXT_STEP" -eq 8 ]]; then
  SYSMSG="🕊 [$JL_SESSION] Step 8/9 Judgement · the books are opened"
elif [[ "$NEXT_STEP" -eq 7 ]]; then
  SYSMSG="🕊 [$JL_SESSION] Step 7/9 Sabbath · verdict before judgement"
else
  SYSMSG="🕊 [$JL_SESSION] Step $NEXT_STEP/9 · $GENESIS_DAY ($LABEL)"
fi

case "$JL_OUTPUT_FORMAT" in
  claude-code|codex)
    jq -n --arg prompt "$PROMPT" --arg msg "$SYSMSG" \
      '{decision: "block", reason: $prompt, systemMessage: $msg}'
    ;;
  raw|*)
    printf '%s\n' "$PROMPT"
    if { true >&"$JL_SYSMSG_FD"; } 2>/dev/null; then
      printf '%s\n' "$SYSMSG" >&"$JL_SYSMSG_FD"
    fi
    ;;
esac

exit 0
