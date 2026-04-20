#!/bin/bash
# Step 5 (creatures): five hostile/edge probes against install.sh + the new
# fib-parallelism budget injection.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d -t jl-adv.XXXXXX)
trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
ok()  { printf '  ✓ %s\n' "$1"; PASS=$((PASS+1)); }
bad() { printf '  ✗ %s\n    %s\n' "$1" "$2"; FAIL=$((FAIL+1)); }

echo "== probe 1: pre-existing non-ours hooks.json must NOT be clobbered =="
H1="$TMP/p1"; mkdir -p "$H1"
cat > "$H1/hooks.json" <<'EOF'
{ "Stop": [{"hooks":[{"type":"command","command":"echo MY_OWN_HOOK"}]}] }
EOF
bash "$ROOT/scripts/install.sh" codex --home "$H1" >/dev/null 2>&1 || true
if grep -q MY_OWN_HOOK "$H1/hooks.json"; then
  ok "existing user hooks.json preserved"
else
  bad "user hooks.json overwritten" "$(cat "$H1/hooks.json")"
fi
[[ -f "$H1/jesus-loop/hooks.json" ]] && ok "ours dropped at jesus-loop/hooks.json for manual merge" || bad "no fallback file" "missing"

echo
echo "== probe 2: install into nonexistent home creates dirs =="
H2="$TMP/p2/nested/deep"
bash "$ROOT/scripts/install.sh" codex --home "$H2" >/dev/null
[[ -f "$H2/hooks.json" && -f "$H2/jesus-loop/core/loop.sh" ]] \
  && ok "deep path created with mkdir -p" || bad "deep mkdir" "missing"

echo
echo "== probe 3: opencode install.sh into target with pre-existing package.json =="
OP="$TMP/p3"; mkdir -p "$OP/.opencode"
cat > "$OP/.opencode/package.json" <<'EOF'
{ "name": "user-project", "dependencies": { "react": "^18" } }
EOF
bash "$ROOT/scripts/install.sh" opencode --project "$OP" >/dev/null
if jq -e '.dependencies.react' "$OP/.opencode/package.json" >/dev/null 2>&1 \
   && jq -e '.devDependencies."bun-types"' "$OP/.opencode/package.json" >/dev/null; then
  ok "user package.json merged with bun-types (both kept)"
else
  bad "package.json merge" "$(cat "$OP/.opencode/package.json")"
fi

echo
echo "== probe 4: settings.json merge with hostile/malformed existing file =="
CC="$TMP/p4"; mkdir -p "$CC/.claude"
echo "not json {{{" > "$CC/.claude/settings.json"
if bash "$ROOT/scripts/install.sh" claude-code --project "$CC" 2>/dev/null; then
  bad "merge silently succeeded on malformed JSON" "$(cat "$CC/.claude/settings.json")"
else
  ok "install fails loudly on malformed existing settings.json (no silent corruption)"
fi

echo
echo "== probe 5: fib-parallelism budget present in injected prompt =="
FAIL_BUDGET=0
mkdir -p "$TMP/.codex"
for step_minus1 in 0 1 2 3 4 5 6; do
  step=$((step_minus1 + 1))
  expected=("1" "1" "2" "3" "5" "8" "1")
  exp="${expected[$step_minus1]}"
  cat > "$TMP/.codex/jesus-loop.fib.local.md" <<EOF
---
active: true
step: $step_minus1
harness_ws:
completion_promise: "SHIPPED"
---
fib budget test
EOF
  OUT=$(echo '{}' | env JL_PLUGIN_ROOT="$ROOT" JL_STATE_DIR="$TMP/.codex" JL_SESSION=fib JL_OUTPUT_FORMAT=codex bash "$ROOT/core/loop.sh")
  REASON=$(echo "$OUT" | jq -r .reason)
  ACTUAL=$(echo "$REASON" | grep -oE 'Genesis Day [0-9]+ of 7 → [0-9]+ worker' | grep -oE '→ [0-9]+' | grep -oE '[0-9]+' | head -1)
  if [[ "$ACTUAL" == "$exp" ]]; then
    printf '  ✓ step %s → %s worker(s)\n' "$step" "$exp"
  else
    printf '  ✗ step %s expected %s got %s\n' "$step" "$exp" "${ACTUAL:-MISSING}"
    FAIL_BUDGET=1
  fi
done
[[ "$FAIL_BUDGET" == "0" ]] && PASS=$((PASS+7)) && ok "all 7 days emit correct fib budget" || { FAIL=$((FAIL+1)); bad "fib budget" "wrong N for at least one step"; }

# Sabbath also injects the SINGLE-THREAD verdict instruction.
cat > "$TMP/.codex/jesus-loop.fib.local.md" <<'EOF'
---
active: true
step: 6
harness_ws:
completion_promise: "SHIPPED"
---
sabbath test
EOF
OUT=$(echo '{}' | env JL_PLUGIN_ROOT="$ROOT" JL_STATE_DIR="$TMP/.codex" JL_SESSION=fib JL_OUTPUT_FORMAT=codex bash "$ROOT/core/loop.sh")
echo "$OUT" | jq -r .reason | grep -q "SABBATH BREAK" \
  && ok "step 7 injects SABBATH BREAK instruction (single-thread verdict)" \
  || bad "sabbath break" "missing in step 7 prompt"

# Per-harness fan-out hint.
mkdir -p "$TMP/.claude"
cat > "$TMP/.claude/jesus-loop.fib.local.md" <<'EOF'
---
active: true
step: 4
harness_ws:
completion_promise: "SHIPPED"
---
cc fib hint test
EOF
OUT=$(echo '{}' | env JL_PLUGIN_ROOT="$ROOT" JL_STATE_DIR="$TMP/.claude" JL_SESSION=fib JL_OUTPUT_FORMAT=claude-code bash "$ROOT/core/loop.sh")
echo "$OUT" | jq -r .reason | grep -q "Use the Agent tool to spawn 5 sub-agents" \
  && ok "claude-code hint names Agent tool with N=5 at step 5" \
  || bad "cc hint" "$(echo "$OUT" | jq -r .reason | grep -A1 'FIB PARALLELISM' || true)"

echo
printf 'Adversarial: %s passed · %s failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]] || exit 1
