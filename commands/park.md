---
description: "Park the car — cancel the active Jesus Loop"
allowed-tools: ["Bash(test -f .claude/jesus-loop.local.md:*)", "Bash(rm .claude/jesus-loop.local.md)", "Read(.claude/jesus-loop.local.md)"]
---

# Park

Cancel the 7-step Jesus Loop.

1. Check if `.claude/jesus-loop.local.md` exists:
   `test -f .claude/jesus-loop.local.md && echo "EXISTS" || echo "NOT_FOUND"`

2. **If NOT_FOUND**: "No active Jesus Loop. The wheel is yours."

3. **If EXISTS**:
   - Read `.claude/jesus-loop.local.md` and note the current `step:` value.
   - Remove: `rm .claude/jesus-loop.local.md`
   - Report: `🕊 Parked on Step N of 7. Teachings kept at .claude/jesus-loop.teachings.local.md.`
