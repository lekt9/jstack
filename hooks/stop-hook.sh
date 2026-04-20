#!/bin/bash
# Claude Code Stop hook — thin adapter over core/loop.sh.
# Discovers active sessions in .claude/jesus-loop.*.local.md and runs the
# core for each. If multiple sessions exist, only the most-recently-modified
# one drives this turn (Claude Code's hook contract emits a single response).
set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
STATE_DIR=".claude"

# Capture stdin once; replay to core.
INPUT=$(cat || true)

shopt -s nullglob

# Backward compat: migrate legacy single-state path → .default session.
if [[ ! -f "$STATE_DIR/jesus-loop.default.local.md" && -f "$STATE_DIR/jesus-loop.local.md" ]]; then
  mv "$STATE_DIR/jesus-loop.local.md" "$STATE_DIR/jesus-loop.default.local.md"
  [[ -f "$STATE_DIR/jesus-loop.teachings.local.md" ]] && \
    mv "$STATE_DIR/jesus-loop.teachings.local.md" "$STATE_DIR/jesus-loop.default.teachings.local.md"
fi

# Pick the most-recently-modified session state file (excluding teachings.*).
# Uses `ls -t` (portable mtime ordering) so sub-second mtime collisions resolve
# by ls's tiebreak rather than glob/alphabetical order.
PICK=$(ls -t "$STATE_DIR"/jesus-loop.*.local.md 2>/dev/null | grep -v '\.teachings\.local\.md$' | head -1 || true)
[[ -n "$PICK" ]] || exit 0

# Derive session id from filename: jesus-loop.<SESSION>.local.md
base=$(basename "$PICK")
SESSION="${base#jesus-loop.}"; SESSION="${SESSION%.local.md}"

export JL_PLUGIN_ROOT="$PLUGIN_ROOT"
export JL_STATE_DIR="$STATE_DIR"
export JL_SESSION="$SESSION"
export JL_OUTPUT_FORMAT="claude-code"
echo "$INPUT" | exec bash "$PLUGIN_ROOT/core/loop.sh"
