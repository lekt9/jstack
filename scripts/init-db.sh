#!/bin/bash

# One-time setup for the Jesus Loop server:
#   1. Create the `jesus-loop` D1 database (if it doesn't exist).
#   2. Write its database_id into wrangler.toml.
#   3. Apply data/schema.sql (creates table + immutability triggers).
#   4. Generate WRITE_TOKEN + READ_TOKEN (random 32-byte hex).
#   5. Upload them as Worker secrets via `wrangler secret put`.
#   6. Deploy the Worker and capture its URL.
#   7. Save URL + tokens to $PLUGIN_ROOT/.jesus-loop-env (gitignored).
#
# After this runs, record-pair.sh talks to your Worker over HTTPS — the loop
# no longer needs wrangler/CF credentials on the loop machine.

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
WRANGLER_TOML="$PLUGIN_ROOT/wrangler.toml"
SCHEMA_FILE="$PLUGIN_ROOT/data/schema.sql"
ENV_FILE="$PLUGIN_ROOT/.jesus-loop-env"
DB_NAME="${1:-jesus-loop}"
MODE="${2:---remote}"   # --remote (default) or --local

command -v wrangler >/dev/null || { echo "wrangler not installed. npm i -g wrangler" >&2; exit 1; }
command -v jq       >/dev/null || { echo "jq not installed." >&2; exit 1; }

# --- 1. Create D1 DB if wrangler.toml has no database_id yet. ---
EXISTING_ID=$(awk -F'=' '/^[[:space:]]*database_id[[:space:]]*=/{gsub(/[" ]/,"",$2); print $2; exit}' "$WRANGLER_TOML" 2>/dev/null || echo "")
if [[ -n "$EXISTING_ID" ]]; then
  echo "✓ D1 database already configured (id=$EXISTING_ID)"
  DB_ID="$EXISTING_ID"
else
  echo "Creating D1 database: $DB_NAME"
  CREATE_OUT=$(wrangler d1 create "$DB_NAME" 2>&1 || true)
  echo "$CREATE_OUT"
  DB_ID=$(echo "$CREATE_OUT" | grep -Eo 'database_id *= *"[^"]+"' | head -1 | sed 's/.*"\([^"]*\)".*/\1/')
  if [[ -z "$DB_ID" ]]; then
    DB_ID=$(echo "$CREATE_OUT" | grep -Eo '"database_id" *: *"[^"]+"' | head -1 | sed 's/.*"\([^"]*\)".*/\1/')
  fi
  [[ -n "$DB_ID" ]] || { echo "Failed to parse database_id from wrangler output." >&2; exit 1; }

  TMP="${WRANGLER_TOML}.tmp.$$"
  awk -v id="$DB_ID" '/^database_id[[:space:]]*=/ { print "database_id = \"" id "\""; next } { print }' "$WRANGLER_TOML" > "$TMP"
  mv "$TMP" "$WRANGLER_TOML"
  echo "✓ Wrote database_id=$DB_ID into wrangler.toml"
fi

# --- 2. Apply schema (idempotent thanks to IF NOT EXISTS). ---
echo "Applying schema ($MODE)…"
(cd "$PLUGIN_ROOT" && wrangler d1 execute "$DB_NAME" "$MODE" --file="$SCHEMA_FILE")
echo "✓ Schema applied (table + immutability triggers)."

# --- 3. Generate tokens (reuse if .jesus-loop-env exists). ---
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  set +u; source "$ENV_FILE"; set -u
fi
WRITE_TOKEN="${WRITE_TOKEN:-$(openssl rand -hex 32)}"
READ_TOKEN="${READ_TOKEN:-$(openssl rand -hex 32)}"

# --- 4. Upload secrets to the Worker. ---
echo "Setting Worker secrets (WRITE_TOKEN, READ_TOKEN)…"
(cd "$PLUGIN_ROOT" && printf '%s' "$WRITE_TOKEN" | wrangler secret put WRITE_TOKEN >/dev/null)
(cd "$PLUGIN_ROOT" && printf '%s' "$READ_TOKEN"  | wrangler secret put READ_TOKEN  >/dev/null)
echo "✓ Secrets uploaded."

# --- 5. Deploy Worker. ---
echo "Deploying Worker…"
DEPLOY_OUT=$(cd "$PLUGIN_ROOT" && wrangler deploy 2>&1)
echo "$DEPLOY_OUT"
WORKER_URL=$(echo "$DEPLOY_OUT" | grep -Eo 'https://[a-zA-Z0-9.-]+\.workers\.dev' | head -1)
[[ -n "$WORKER_URL" ]] || { echo "Could not parse Worker URL from deploy output." >&2; exit 1; }
echo "✓ Worker deployed at $WORKER_URL"

# --- 6. Write local env file. ---
umask 077
cat > "$ENV_FILE" <<ENV_EOF
# Jesus Loop — server configuration. Do not commit.
JESUS_LOOP_URL="$WORKER_URL"
WRITE_TOKEN="$WRITE_TOKEN"
READ_TOKEN="$READ_TOKEN"
ENV_EOF
chmod 600 "$ENV_FILE"
echo "✓ Wrote $ENV_FILE (mode 600)."

cat <<DONE

🕊  Jesus Loop server is live.

  URL:         $WORKER_URL
  Write auth:  Bearer \$WRITE_TOKEN   (used by record-pair.sh)
  Read auth:   Bearer \$READ_TOKEN    (share if you want others to query)

Test write:
  source "$ENV_FILE"
  curl -s -X POST "\$JESUS_LOOP_URL/pairs" \\
    -H "Authorization: Bearer \$WRITE_TOKEN" \\
    -H 'content-type: application/json' \\
    -d '{"session_id":"test","project_dir":"/tmp","task":"ping","iteration":1,
         "verse_ref":"Matthew 7:7","pattern_label":"seek and find",
         "applied_lesson":"init-db smoke test"}'

Test read:
  curl -s "\$JESUS_LOOP_URL/pairs?limit=5" -H "Authorization: Bearer \$READ_TOKEN" | jq
  curl -s "\$JESUS_LOOP_URL/pairs/stats"   -H "Authorization: Bearer \$READ_TOKEN" | jq

Immutability:
  UPDATE and DELETE are blocked by D1 triggers. No code path in the Worker
  performs either operation. The table is append-only.
DONE
