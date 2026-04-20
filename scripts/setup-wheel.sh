#!/bin/bash
# Jesus Take The Wheel — 9-step Genesis-days loop (1–6 build, 7 sabbath verdict, 8 judgement, 9 emergence).
# Multi-session aware: pass --session NAME to run multiple loops in one repo.
set -euo pipefail

PROMPT_PARTS=()
COMPLETION_PROMISE="SHIPPED"
SESSION="default"
NORTH_STAR=""
STATE_DIR=".claude"

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      cat <<'HELP_EOF'
Jesus Take The Wheel — 9 Genesis-day steps with multi-session + live steering.

USAGE:
  /take-the-wheel [TASK...] [OPTIONS]

OPTIONS:
  --session NAME                 Session id (default: "default"). Each session
                                 has its own state file and runs independently.
  --north-star "<text>"          Initial north star (re-injected each step).
  --completion-promise '<text>'  Phrase to output as <promise>TEXT</promise>
                                 when Step 9 (Emergence) verdict is SHIP. Default: SHIPPED.
  --state-dir DIR                Where to write state (default: .claude;
                                 use .codex or .opencode for those harnesses).
  -h, --help                     Show this help

EXAMPLES:
  /take-the-wheel Build a markdown blog generator
  /take-the-wheel --session refactor "Pull auth out of routes" --north-star "no behavior change"
HELP_EOF
      exit 0;;
    --completion-promise) COMPLETION_PROMISE="$2"; shift 2;;
    --session)            SESSION="$2"; shift 2;;
    --north-star)         NORTH_STAR="$2"; shift 2;;
    --state-dir)          STATE_DIR="$2"; shift 2;;
    *) PROMPT_PARTS+=("$1"); shift;;
  esac
done

PROMPT="${PROMPT_PARTS[*]}"
[[ -n "$PROMPT" ]] || { echo "Error: no task provided." >&2; exit 1; }

mkdir -p "$STATE_DIR"
STATE_FILE="$STATE_DIR/jesus-loop.$SESSION.local.md"
TEACHINGS_FILE="$STATE_DIR/jesus-loop.$SESSION.teachings.local.md"

{
  printf -- '---\n'
  printf 'active: true\n'
  printf 'step: 0\n'
  printf 'harness_ws:\n'
  printf 'completion_promise: "%s"\n' "$COMPLETION_PROMISE"
  [[ -n "$NORTH_STAR" ]] && printf 'north_star: "%s"\n' "$NORTH_STAR"
  printf 'started_at: "%s"\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf -- '---\n\n'
  printf '%s\n' "$PROMPT"
} > "$STATE_FILE"

if [[ ! -f "$TEACHINGS_FILE" ]]; then
  cat > "$TEACHINGS_FILE" <<EOF
# Jesus Loop — Teachings Log [$SESSION]

Task: $PROMPT
Started: $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
fi

cat <<EOF
🕊  Jesus has taken the wheel [session: $SESSION]. Nine Genesis days.

Task:              $PROMPT
Session:           $SESSION   (state: $STATE_FILE)
Step:              1/9 (Light)
Completion phrase: $COMPLETION_PROMISE (output only when PROMOTE is TRUE)
North star:        ${NORTH_STAR:-<unset — set with /steer or scripts/steer.sh>}

Steer mid-flight:
  bash <plugin-root>/scripts/steer.sh --state-dir $STATE_DIR --session $SESSION "<new north star>"

Stop early:        /park --session $SESSION
Read the sermon:   /sermon --session $SESSION

TASK:
$PROMPT
EOF
