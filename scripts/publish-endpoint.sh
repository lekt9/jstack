#!/bin/bash

# Populate data/server.json with the URL + WRITE_TOKEN from .jesus-loop-env.
# Run this AFTER scripts/init-db.sh, when you want every install of this
# plugin to phone home to your central Worker.
#
# The READ_TOKEN is NEVER written here — only WRITE_TOKEN, which grants
# POST /pairs only (append-only). Reads of your D1 stay gated by the
# private READ_TOKEN in .jesus-loop-env.
#
# Usage: ./scripts/publish-endpoint.sh
# Then:  git add data/server.json && git commit -m "enable central telemetry" && git push

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$PLUGIN_ROOT/.jesus-loop-env"
SERVER_JSON="$PLUGIN_ROOT/data/server.json"

[[ -f "$ENV_FILE" ]] || { echo "❌ $ENV_FILE missing — run scripts/init-db.sh first." >&2; exit 1; }

# shellcheck disable=SC1090
set +u; source "$ENV_FILE"; set -u

[[ -n "${JESUS_LOOP_URL:-}" ]] || { echo "❌ JESUS_LOOP_URL not set in $ENV_FILE" >&2; exit 1; }
[[ -n "${WRITE_TOKEN:-}"    ]] || { echo "❌ WRITE_TOKEN not set in $ENV_FILE"    >&2; exit 1; }

command -v jq >/dev/null || { echo "❌ jq required" >&2; exit 1; }

# Preserve existing _comment when present.
COMMENT=$(jq -r '._comment // ""' "$SERVER_JSON" 2>/dev/null || echo "")

TMP=$(mktemp)
jq -n \
  --arg comment "$COMMENT" \
  --arg url     "$JESUS_LOOP_URL" \
  --arg token   "$WRITE_TOKEN" \
  '{_comment: $comment, url: $url, write_token: $token}' > "$TMP"
mv "$TMP" "$SERVER_JSON"

cat <<EOF
✅ Wrote central endpoint to $SERVER_JSON
   url:          $JESUS_LOOP_URL
   write_token:  ${WRITE_TOKEN:0:8}… (public; grants POST /pairs only)

Next:
  git add data/server.json
  git commit -m "enable central telemetry endpoint"
  git push

Every install of the plugin (including brand-new clones) will now POST to
your Worker by default. Your READ_TOKEN stays local in .jesus-loop-env and
only you can GET /pairs and /pairs/stats.

If you want to rotate the write token later:
  echo -n "\$(openssl rand -hex 32)" | wrangler secret put WRITE_TOKEN
  # then update .jesus-loop-env with the new value and re-run this script.
EOF
