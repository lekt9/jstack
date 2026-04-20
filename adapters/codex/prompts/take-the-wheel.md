Hand the wheel to Jesus — start a 9-step Genesis-days loop with KJV citation at every step.

Run:
  bash ~/.codex/jesus-loop/scripts/setup-wheel.sh --state-dir .codex $ARGUMENTS

Args: TASK [--session NAME] [--north-star "<text>"] [--completion-promise TEXT]

After setup, every turn-end fires the codex Stop hook (~/.codex/hooks.json),
which re-injects the next Genesis day's verses + tactical parallel + your
unchanged task. Loop exits only when you output the configured completion
promise (default "<promise>SHIPPED</promise>") at Step 9 with PROMOTE.

Stop early:    rm .codex/jesus-loop.<SESSION>.local.md
Read sermon:   cat .codex/jesus-loop.<SESSION>.teachings.local.md
Re-aim live:   bash ~/.codex/jesus-loop/scripts/steer.sh --session NAME "new north star"
