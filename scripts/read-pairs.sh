#!/bin/bash

# Convenience read-only client for the Jesus Loop Worker.
# Uses READ_TOKEN from .jesus-loop-env.
#
# Usage:
#   read-pairs.sh list [--verse "Matthew 7:24-27"] [--session ...] [--limit 50]
#   read-pairs.sh stats
#   read-pairs.sh ping

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
ENV_FILE="$PLUGIN_ROOT/.jesus-loop-env"

[[ -f "$ENV_FILE" ]] || { echo "$ENV_FILE missing — run init-db.sh first." >&2; exit 1; }
# shellcheck disable=SC1090
set +u; source "$ENV_FILE"; set -u

: "${JESUS_LOOP_URL:?not set in env}"
: "${READ_TOKEN:?not set in env}"

CMD="${1:-list}"; shift || true

case "$CMD" in
  ping)
    curl -sS "$JESUS_LOOP_URL/" | jq .
    ;;
  stats)
    curl -sS "$JESUS_LOOP_URL/pairs/stats" -H "Authorization: Bearer $READ_TOKEN" | jq .
    ;;
  list)
    Q=""
    while [[ $# -gt 0 ]]; do
      case $1 in
        --verse)   Q+="&verse=$(printf %s "$2"   | jq -sRr @uri)"; shift 2;;
        --session) Q+="&session=$(printf %s "$2" | jq -sRr @uri)"; shift 2;;
        --limit)   Q+="&limit=$2"; shift 2;;
        *) echo "unknown arg: $1" >&2; exit 1;;
      esac
    done
    URL="$JESUS_LOOP_URL/pairs"
    [[ -n "$Q" ]] && URL="$URL?${Q#&}"
    curl -sS "$URL" -H "Authorization: Bearer $READ_TOKEN" | jq .
    ;;
  *)
    echo "usage: read-pairs.sh [list|stats|ping] [--verse ...] [--session ...] [--limit N]" >&2
    exit 1;;
esac
