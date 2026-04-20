# Jesus Take The Wheel

A Claude Code plugin that walks your task through the **seven Genesis days**,
citing scripture verbatim at every step, and posting each validated
(verse, applied-lesson) pair to an **append-only Cloudflare Worker + D1**.

Three structural parts fused:

1. **7-step Genesis-days loop** — the main shape. Each step is one day.
2. **Scripture citations at every step** — one structural verse (the day
   itself) + one tactical parallel from the bible-parallel catalog, both
   KJV-quoted, with an element-by-element mapping required in the reply.
3. **Optional fib-harness break** — when a step can't close in one pass,
   escape to a full 1-1-2-3-5-8 agent investigation scoped to that step.

## The seven days

| Step | Genesis Day | What it means for the work |
|------|-------------|----------------------------|
| 1 | Light       | Inventory — read, search, enumerate. No building. |
| 2 | Firmament   | Architecture — layers, contracts, separations. |
| 3 | Land        | First artifacts — skeleton, stub, draft. |
| 4 | Luminaries  | Signals — tests, types, metrics. |
| 5 | Creatures   | Behavior — edges, adversarial, concurrency. |
| 6 | Dominion    | Integration — end-to-end flows. |
| 7 | Sabbath     | Verdict — promote, hold, or reject. |

## Architecture

```
  Claude Code (any machine, any project)
      │
      │ each step:
      │   1. stop-hook.sh picks the day's structural verse + rotating
      │      tactical parallel, quotes both KJV, injects mapping requirement
      │   2. assistant replies with quoted verses + element-by-element map
      │   3. assistant appends to .claude/jesus-loop.teachings.local.md
      │   4. assistant runs record-pair.sh → POST /pairs
      │   5. assistant does the step's concrete work
      │
      │ step stuck? → scripts/break-harness.sh scopes a full fib-harness
      │               child (1-1-2-3-5-8 across 6 Genesis days) to the
      │               stuck sub-problem; main loop resumes on verdict
      ▼
  record-pair.sh ── HTTPS ──► Cloudflare Worker
      Bearer WRITE_TOKEN         │
                                 │  POST /pairs       (append-only)
                                 │  GET  /pairs       (Bearer READ_TOKEN)
                                 │  GET  /pairs/stats (?group=verse|day|step)
                                 ▼
                         Cloudflare D1  (jesus_loop_pairs)
                         UPDATE/DELETE blocked by DB triggers
```

- **Write-only** from the loop's side (POST, WRITE_TOKEN).
- **Read-only** from the maintainer's side (GET, private READ_TOKEN).
- **Immutable** at DB level (triggers RAISE FAIL on UPDATE/DELETE).

## Install

```bash
# Plugin only — by default, validated pairs POST to the maintainer's
# central Worker (endpoint + write-only token baked in data/server.json).
# The baked-in token is write-only; reads require a separate token that
# is never shipped.
ln -s "$(pwd)" ~/.claude/plugins/jesus-loop
```

### Run your own server instead (optional)

If you'd rather keep your loop data private in your own Cloudflare D1:

```bash
npm i -g wrangler
wrangler login
./scripts/init-db.sh    # creates your D1, deploys your Worker,
                        # writes .jesus-loop-env (mode 600, gitignored).
```

`.jesus-loop-env` takes precedence over `data/server.json` at runtime, so
once you've run `init-db.sh`, everything stays in your own CF account.

If you also want to *publish* your endpoint so every install of your fork
phones home to you, run `./scripts/publish-endpoint.sh` after `init-db.sh`
and commit the resulting `data/server.json`.

### Telemetry opt-out

To disable the default central telemetry without running your own server,
blank out `data/server.json`:

```json
{ "url": "", "write_token": "" }
```

`record-pair.sh` will silently skip the POST and the loop still runs.

## Use

```bash
/take-the-wheel Build a markdown blog generator
# or with a custom completion phrase:
/take-the-wheel Fix the flaky login test --completion-promise FIXED
```

Each step, the hook arrives with:

- the Genesis-day verse (e.g. `Genesis 1:3` for Day 1) with full KJV text,
- a companion verse (e.g. `Luke 14:28`) with full KJV text,
- a rotating tactical parallel from the 24-entry catalog with its quote,
- the "parallel to your problem" template,
- and a citation-required reply structure.

Step 7 (Sabbath) is where you render the verdict. Output
`<promise>SHIPPED</promise>` (or the configured phrase) only when
PROMOTE is genuinely true.

Exit early: `/park`. Review the sermon: `/sermon`.

## Harness-break escape

If a step can't close in one pass:

```bash
./scripts/break-harness.sh --step 3 --scope "API routing skeleton is larger than one agent"
```

That initializes a fib-harness workspace, writes `harness_ws: /tmp/fib-...`
into the state file, and switches the loop into **repair mode** (Isaiah
28:13 / Galatians 6:9) until you resolve the child cycle and blank the
`harness_ws:` line in `.claude/jesus-loop.local.md`.

Then Step N+1 proceeds.

## Querying your own server (maintainer only)

```bash
source ~/.claude/plugins/jesus-loop/.jesus-loop-env
./scripts/read-pairs.sh ping
./scripts/read-pairs.sh stats                    # default: by verse+label
./scripts/read-pairs.sh list --verse "Genesis 1:3"
./scripts/read-pairs.sh list --genesis-day creatures --limit 20
./scripts/read-pairs.sh list --step 7
# Raw:
curl -sS "$JESUS_LOOP_URL/pairs/stats?group=day"  -H "Authorization: Bearer $READ_TOKEN" | jq
curl -sS "$JESUS_LOOP_URL/pairs/stats?group=step" -H "Authorization: Bearer $READ_TOKEN" | jq
```

The baked-in central `write_token` cannot read; only the maintainer's
private `READ_TOKEN` (kept out of the repo) can GET the data.

## API

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| GET | `/` | none | service descriptor |
| POST | `/pairs` | `WRITE_TOKEN` | append one pair |
| GET | `/pairs` | `READ_TOKEN` | list (`?verse`, `?session`, `?step`, `?genesis_day`, `?limit`) |
| GET | `/pairs/stats` | `READ_TOKEN` | rollup (`?group=verse\|day\|step`) |

Any other method returns 405. D1 triggers block UPDATE/DELETE at the
database layer too.

## Schema

| column | type | notes |
|--------|------|-------|
| id | INTEGER | auto-increment |
| session_id | TEXT | loop `started_at` timestamp |
| project_dir | TEXT | cwd where the loop ran |
| task | TEXT | original task prompt |
| iteration | INTEGER | iteration counter (matches step for a simple run) |
| step | INTEGER | 1..7 (Genesis day index) |
| genesis_day | TEXT | light, firmament, land, luminaries, creatures, dominion, sabbath, repair |
| harness_ws | TEXT | fib-harness workspace if a break is active |
| verdict | TEXT | promote, hold, reject (on Step 7 rows) |
| verse_ref | TEXT | e.g. "Genesis 1:3" |
| pattern_label | TEXT | e.g. "let there be light" |
| applied_lesson | TEXT | the one-line lesson for this step |
| outcome | TEXT | pass, fail, blocked (optional) |
| client_ip | TEXT | CF-Connecting-IP at write time |
| user_agent | TEXT | UA at write time |
| created_at | TEXT | SQLite `datetime('now')` |

## Files

```
jesus-loop/
├── .claude-plugin/plugin.json
├── commands/          # /take-the-wheel, /park, /sermon
├── hooks/             # stop-hook.sh
├── scripts/
│   ├── setup-wheel.sh         # invoked by /take-the-wheel
│   ├── init-db.sh             # one-time: your D1 + Worker + secrets
│   ├── publish-endpoint.sh    # publish your URL + write_token to data/server.json
│   ├── record-pair.sh         # per-step POST /pairs
│   ├── read-pairs.sh          # read-only CLI (needs READ_TOKEN)
│   ├── break-harness.sh       # escape to fib-harness for a stuck step
│   └── fib-harness            # 1-1-2-3-5-8 Genesis-day investigation tool
├── worker/src/index.js
├── data/
│   ├── creation-teachings.json   # 7 entries (one per step)
│   ├── teachings.json            # 24 tactical parallels with KJV quotes
│   ├── schema.sql                # table + immutability triggers
│   └── server.json               # committed: central telemetry URL + public write_token
├── wrangler.toml
└── .jesus-loop-env    # generated by init-db.sh; mode 600; gitignored
```

## Credits

- [ralph-wiggum](https://github.com/anthropics/claude-code/tree/main/plugins/ralph-wiggum)
  — Daisy Hollman — the stop-hook loop mechanism.
- `bible-parallel` skill — the scripture pattern catalog.
- `fib-harness-writer` skill — the 1-1-2-3-5-8 Genesis-day harness.
