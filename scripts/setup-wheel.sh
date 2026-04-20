#!/bin/bash

# Jesus Take The Wheel — 7-step Genesis-days loop.
# Each iteration advances one step. If a step can't close in one pass,
# the assistant can `break-harness` into a full fib-harness for that step.

set -euo pipefail

PROMPT_PARTS=()
COMPLETION_PROMISE="SHIPPED"

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      cat <<'HELP_EOF'
Jesus Take The Wheel — 7 Genesis-day steps, with scripture cited at each step
and an optional fib-harness break when a step can't close in one pass.

USAGE:
  /take-the-wheel [TASK...] [OPTIONS]

ARGUMENTS:
  TASK...    What you want Jesus to build (free-form, no quotes needed)

OPTIONS:
  --completion-promise '<text>'  Phrase to output as <promise>TEXT</promise>
                                 when Step 7 verdict is PROMOTE. Default: SHIPPED.
  -h, --help                     Show this help

HOW IT WORKS:
  Step 1 Light        — inventory (read, search, enumerate)
  Step 2 Firmament    — architecture (layers, contracts, separations)
  Step 3 Land         — first artifacts (skeleton, stub, draft)
  Step 4 Luminaries   — signals (tests, types, metrics)
  Step 5 Creatures    — behavior (edges, adversarial, concurrency)
  Step 6 Dominion     — integration (end-to-end)
  Step 7 Sabbath      — verdict (promote | hold | reject)

  Each step, the Stop hook injects:
    · the Genesis-day structural verse (quoted)
    · a rotating tactical parallel (quoted)
    · an explicit element-by-element mapping requirement

  If a step is too big for one pass, you can invoke fib-harness for that
  step — it scopes a full 1-1-2-3-5-8 Genesis-day investigation as a
  child. When the harness verdict returns, the main 7-step loop resumes
  at the next step.

EXAMPLES:
  /take-the-wheel Build a markdown blog generator
  /take-the-wheel Fix the flaky login test --completion-promise 'FIXED'

STOPPING:
  /park                          # cancels the loop
  output <promise>SHIPPED</promise> at Step 7 when PROMOTE is genuinely true
HELP_EOF
      exit 0
      ;;
    --completion-promise)
      [[ -z "${2:-}" ]] && { echo "--completion-promise needs text" >&2; exit 1; }
      COMPLETION_PROMISE="$2"; shift 2;;
    *)
      PROMPT_PARTS+=("$1"); shift;;
  esac
done

PROMPT="${PROMPT_PARTS[*]}"
[[ -n "$PROMPT" ]] || { echo "Error: no task provided." >&2; exit 1; }

mkdir -p .claude
cat > .claude/jesus-loop.local.md <<EOF
---
active: true
step: 0
harness_ws:
completion_promise: "$COMPLETION_PROMISE"
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
---

$PROMPT
EOF

if [[ ! -f .claude/jesus-loop.teachings.local.md ]]; then
  cat > .claude/jesus-loop.teachings.local.md <<EOF
# Jesus Loop — Teachings Log

Task: $PROMPT
Started: $(date -u +%Y-%m-%dT%H:%M:%SZ)

Each step appends one line: \`- [step N / Day] Ref — label — applied lesson\`.

EOF
fi

cat <<EOF
🕊  Jesus has taken the wheel. Seven Genesis days.

Task:              $PROMPT
Step:              1/7 (Light)
Completion phrase: $COMPLETION_PROMISE (output only when PROMOTE is TRUE)

Each step will arrive with its Genesis verse and a tactical parallel —
both quoted, both mapped element-by-element to your current state. If a
step can't close in one pass, invoke:
  \${CLAUDE_PLUGIN_ROOT}/scripts/break-harness.sh --step N --scope "<what>"
to spawn a full fib-harness child for that step.

To stop early: /park. To review the sermon: /sermon.
EOF

echo ""
echo "TASK:"
echo "$PROMPT"
