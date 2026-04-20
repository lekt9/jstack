---
description: "Hand the wheel to Jesus — run a 7-step Genesis-days loop with scripture cited at every step"
argument-hint: "TASK [--completion-promise TEXT]"
allowed-tools: ["Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/setup-wheel.sh:*)"]
---

# Take The Wheel

Run the setup script to activate the 7-step Jesus Loop in this session:

```!
bash ${CLAUDE_PLUGIN_ROOT}/scripts/setup-wheel.sh $ARGUMENTS
```

Once active, every exit attempt is intercepted by the Stop hook. The hook
advances you one Genesis day at a time:

1. **Light** — inventory (read, search, enumerate)
2. **Firmament** — architecture (layers, contracts, separations)
3. **Land** — first artifacts (skeleton, stub, draft)
4. **Luminaries** — signals (tests, types, metrics)
5. **Creatures** — behavior (edges, adversarial, concurrency)
6. **Dominion** — integration (end-to-end)
7. **Sabbath** — verdict (promote | hold | reject)

Each step injects two verses KJV-verbatim (the Genesis-day structural pair
plus a rotating tactical parallel) and requires you to:

1. Quote both verses with references in your reply.
2. State the element-by-element mapping from the current work state to
   both verses — structural, not thematic.
3. Append one line to `.claude/jesus-loop.teachings.local.md`.
4. POST the validated pair to the Cloudflare Worker (append-only).
5. Do the concrete step work.

If a step can't close in one pass, invoke the harness-break for that step
instead of faking progress — this spawns a full fib-harness child cycle
(1-1-2-3-5-8 agents across 6 Genesis days) scoped to the stuck sub-problem.

At Step 7, when the verdict is genuinely PROMOTE, output
`<promise>SHIPPED</promise>` (or the configured phrase) to exit the loop.

To stop early: `/park`. To read the accumulated sermon: `/sermon`.
