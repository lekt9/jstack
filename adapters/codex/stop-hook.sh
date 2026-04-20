#!/bin/bash
# Codex CLI Stop hook — thin adapter over core/loop.sh.
# Codex passes JSON envelope on stdin: {session_id, transcript_path, cwd, hook_event_name, model, turn_id?}.
# Codex expects on stdout: {"decision":"block","reason":"<inject>"} (systemMessage allowed).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="${JL_PLUGIN_ROOT:-$(cd "$HERE/../.." && pwd)}"
export JL_PLUGIN_ROOT="$PLUGIN_ROOT"
export JL_STATE_DIR="${JL_STATE_DIR:-.codex}"
export JL_SESSION="${JL_SESSION:-default}"
export JL_OUTPUT_FORMAT="codex"
exec bash "$PLUGIN_ROOT/core/loop.sh"
