# Harness Pattern — Fibonacci Subagent Scaling (Domain-General)

## Invariant: Structure. Variant: Primitives.

```
Level  Agents  Genesis Day      Universal Question          Primitive Type Hint
─────  ──────  ──────────────   ─────────────────────────   ────────────────────
  1      1     Light            What exists?                usually code OR inventory skill
  2      1     Firmament        What separates / layers?    often skill (conceptual)
  3      2     Land/Vegetation  What does it produce?       code or skill (artifact-dependent)
  4      3     Luminaries       What are the signals?       hybrid (code collects, skill judges)
  5      5     Creatures        What moves / behaves?       hybrid (real-world probe + judgement)
  6      8     Dominion         What integrates?            hybrid (cross-surface e2e)
  7      —     Sabbath          BREAK → judge
  8      —     —                VERDICT → consequence
```

## Two-Phase Setup

### Phase 0a: Classify the domain

Before mapping dimensions, name the domain. Domains known to this harness:

- `code` — shell / typecheck / runtime assertions dominate
- `content` — copy, drafts, engagement metrics
- `sales` — pipeline, outreach, replies, close
- `fundraising` — investor list, deck, SAFE, commits
- `research` — sources, synthesis, hypothesis tests
- `operations` — metrics, rituals, orgs, loops
- `product` — PRD, roadmap, user research
- `ml` — data, checkpoints, eval, deploy
- `growth` — funnel, activation, retention
- `pastoral` — facts, scripture, body, next-step (daylight only)

New domain? Declare it. The fib structure does not care.

### Phase 0b: Map 6 days × select primitive per day

For each Genesis day, write a row with these fields:

| Field | Meaning |
|-------|---------|
| `name` | short dimension name for this domain |
| `genesis_day` | light / firmament / land / luminaries / creatures / dominion |
| `question` | one-line domain-specific question to answer |
| `primitive_type` | `code` / `skill` / `hybrid` |
| `primitive_name` | script path OR skill name OR both (for hybrid) |
| `commands` | shell commands to run (code/hybrid only) |
| `skill_invocation` | skill name + sub-task string (skill/hybrid only) |
| `success_criteria` | pass condition (regex, assertion, or semantic) |
| `failure_indicators` | known failure patterns |

A dimension with any missing required field is **not ready to spawn agents for**. Go back and concretize.

## Primitive Selection Heuristic

Ask per-dimension: *can a deterministic script decide pass/fail on its own?*

- **Yes, and re-running gives the same answer** → `code`
- **No, it needs semantic judgement or domain expertise** → `skill`
- **Script produces structured evidence that a skill can judge** → `hybrid` (preferred at L4-L6)

Default biases:
- L1 Light: code (inventory is mechanical)
- L2 Firmament: skill (conceptual separation often requires domain judgement)
- L3 Land: whichever produces the artifact
- L4 Luminaries: hybrid (code runs the check, skill grades the output)
- L5 Creatures: hybrid (real runtime + semantic result check)
- L6 Dominion: hybrid (end-to-end flow + product-feel judgement)

## Hypothesis Structure (unchanged across domains)

```json
{
  "id": "L3-b-H2",
  "claim": "<falsifiable statement about the domain>",
  "evidence": "<what the primitive produced — shell output, skill artifact, or both>",
  "primitive_type": "code | skill | hybrid",
  "primitive_used": "<script path / skill name / both>",
  "commands_run": ["<if code or hybrid>"],
  "skill_invoked": "<if skill or hybrid>",
  "status": "pass | fail | unknown",
  "blocking": true,
  "repair_hint": "<how to fix>"
}
```

## Judgement Protocol (Level 7, unchanged)

Collect all hypotheses from L1-L6. Verdict:

- All pass → `promote`
- Any blocking fail → spawn child per failure domain (fractal, same domain)
- Unknowns only → `needs_investigation`

## Fractal Rule

Children inherit the parent's domain. If a sales L5 fails, the child is a sales harness scoped to that L5 behavior, not a generic "figure it out" harness. Depth cap: 3.

## Anti-Patterns (updated)

- **Generic dimensions.** "It works" is not a dimension. "The copy-editing skill rates this draft ≥ B+ on clarity" is.
- **Wrong primitive type.** Using grep to verify a content draft's tone. Using a skill to check whether a file exists. Match primitive to the thing being verified.
- **Skipping Phase 0.** Jumping to Phase 1 before classifying domain and selecting primitives produces confused agents.
- **Prose-only agents.** Every agent — code, skill, or hybrid — outputs hypothesis JSON.
- **Domain drift across fractal.** Child harness suddenly checking code in a content run, or vice versa.
- **Wrong fib counts.** L3 is exactly 2, L6 is exactly 8. The sequence is the law.
- **Decorative Genesis mapping.** If your L1 agent is not answering "what exists" for this specific domain, the mapping is wrong.

## Convergence Guarantee

- 20 agents per cycle
- Max 2 repair cycles per workspace
- Max depth 3 for fractal children
- Hard ceiling: 60 agents × depth-3 fanout — still finite
- Level 7 forces a verdict; no open-ended loops
