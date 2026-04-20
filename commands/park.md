---
description: "Park the car — cancel an active Jesus Loop session (or all)"
argument-hint: "[--session NAME | --all]"
allowed-tools: ["Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/park.sh:*)"]
---

# Park

Cancel a 7-step Jesus Loop. Pass `--session NAME` for a specific session, or
`--all` to park every session in the repo. Default is `--session default`.

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/park.sh $ARGUMENTS`
