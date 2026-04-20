---
description: "Read back the teachings log from a Jesus Loop session"
argument-hint: "[--session NAME | --all]"
allowed-tools: ["Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/sermon.sh:*)"]
---

# Sermon

Show the teachings gathered across the seven Genesis days. Pass `--session NAME`
for one session, `--all` for every session in the repo. Default is `--session default`.

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/sermon.sh $ARGUMENTS`

After printing, offer a short synthesis (≤3 sentences): which Genesis day
carried the most friction, which tactical parallel showed up more than once,
and what that says about the shape of the work.
