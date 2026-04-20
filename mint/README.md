# mint/ — separate bottle (new wine)

This directory is the seed of the **tradeable layer** described in Step 2's
firmament. It is intentionally walled off from the free Jesus Loop plugin:

- It only **reads** from the existing `/pairs` endpoint via `READ_TOKEN`.
- It writes nothing back to the Worker or to D1.
- It has no dependency the free loop pulls in.
- It is the *only* part of this repo intended to ever be extracted to its
  own repo + own deploy. Extract before any real on-chain calls land here.

Today this contains one mustard seed:

- `queue.mjs` — fetches the latest pairs and emits one **mint-intent**
  JSONL line per pair. No chain calls. No keys required beyond `READ_TOKEN`.

That is enough to prove the seed is viable: the existing append-only stream
can drive a token mint queue 1:1 without modifying any L1/L2 code.

## Run

```
source .jesus-loop-env
node mint/queue.mjs --since-id 0 --limit 50 > mint-queue.jsonl
```

Each line:

```
{"pair_id":N,"verse_ref":"Genesis 1:3","amount":1,"recipient":null,"status":"pending"}
```

`recipient: null` means no wallet binding yet — those mints accrue to a
treasury bucket per Step 2 design.

## Not yet

- No actual minting (no SPL/ERC-20 client).
- No wallet binding endpoint (`/bind` is Step 4+ territory).
- No tokenomics curve, LP funding, or legal posture. See Step 2 architecture
  note in `.claude/jesus-loop.teachings.local.md`.
