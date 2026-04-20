---
description: "Read back the teachings log from the 7-step loop"
allowed-tools: ["Bash(test -f .claude/jesus-loop.teachings.local.md:*)", "Read(.claude/jesus-loop.teachings.local.md)"]
---

# Sermon

Show the user the teachings gathered across the seven Genesis days.

1. Check if `.claude/jesus-loop.teachings.local.md` exists.
2. **If not found**: "No teachings yet. Start with `/take-the-wheel`."
3. **If found**:
   - Read the file.
   - Present the per-step list cleanly.
   - Offer one short synthesis (≤3 sentences): which Genesis day carried
     the most friction, which tactical parallel showed up more than once,
     and what that says about the shape of the work.
