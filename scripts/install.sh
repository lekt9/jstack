#!/bin/bash
# install.sh — one entry point for installing jesus-loop into any harness.
#
# Usage:
#   install.sh claude-code [--project DIR]   # writes/merges .claude/settings.json
#   install.sh codex [--home DIR]            # default DIR=~/.codex
#   install.sh opencode [--project DIR | --global]
#   install.sh all
#   install.sh uninstall <harness>
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CMD="${1:-}"; shift || true

usage() {
  cat <<EOF
jesus-loop installer

  install.sh claude-code [--project DIR]      Add permission allowlist for state files
  install.sh codex       [--home DIR]         Drop adapter into ~/.codex (default)
  install.sh opencode    [--project DIR]      Drop plugin + commands into .opencode
  install.sh opencode    --global             Install to ~/.config/opencode
  install.sh all                              Install everything detectable
  install.sh uninstall <harness>              Remove the named install
  install.sh -h | --help                      This help

Source root: $SOURCE_ROOT
EOF
}

# ---------- helpers ----------
copy_tree() {
  # copy_tree SRC DST — copy contents of SRC into DST (idempotent).
  local src="$1" dst="$2"
  mkdir -p "$dst"
  ( cd "$src" && tar cf - . ) | ( cd "$dst" && tar xf - )
}

merge_settings_json() {
  # merge_settings_json EXISTING NEW → write merged jq result to EXISTING.
  local existing="$1" new="$2"
  if [[ ! -f "$existing" ]]; then
    cp "$new" "$existing"
    return
  fi
  command -v jq >/dev/null || { echo "install: jq required to merge $existing" >&2; exit 1; }
  local tmp="$existing.tmp.$$"
  jq -s '
    def deepmerge(a; b):
      if (a|type) == "object" and (b|type) == "object" then
        reduce ([a,b][]|to_entries[]) as $kv ({}; .[$kv.key] = (
          if .[$kv.key] == null then $kv.value
          else deepmerge(.[$kv.key]; $kv.value) end
        ))
      elif (a|type) == "array" and (b|type) == "array" then (a + b | unique)
      else b end;
    deepmerge(.[0]; .[1])
  ' "$existing" "$new" > "$tmp"
  mv "$tmp" "$existing"
}

# ---------- claude-code ----------
install_cc() {
  local proj="${1:-$PWD}"
  echo "→ claude-code: writing permission allowlist to $proj/.claude/settings.json"
  mkdir -p "$proj/.claude"
  merge_settings_json "$proj/.claude/settings.json" "$SOURCE_ROOT/adapters/claude-code/settings.json"
  echo "  ✓ permissions for .claude/jesus-loop.*.local.md added"
  echo "  Note: plugin itself is installed via the Claude Code plugin marketplace."
  echo "        Source root in use: $SOURCE_ROOT"
}

# ---------- codex ----------
install_codex() {
  local home="${1:-$HOME/.codex}"
  echo "→ codex: installing to $home"
  mkdir -p "$home/jesus-loop" "$home/prompts"
  for d in core data scripts adapters; do
    [[ -d "$SOURCE_ROOT/$d" ]] && copy_tree "$SOURCE_ROOT/$d" "$home/jesus-loop/$d"
  done
  for f in "$SOURCE_ROOT"/adapters/codex/prompts/*.md; do
    cp "$f" "$home/prompts/$(basename "$f")"
  done

  # Generate a hooks.json with absolute path to the installed stop-hook.
  cat > "$home/jesus-loop/hooks.json" <<EOF
{
  "Stop": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "JL_PLUGIN_ROOT=\"$home/jesus-loop\" bash \"$home/jesus-loop/adapters/codex/stop-hook.sh\"",
          "timeout": 60
        }
      ]
    }
  ]
}
EOF

  if [[ -f "$home/hooks.json" ]] && ! grep -q jesus-loop "$home/hooks.json"; then
    echo "  ⚠ $home/hooks.json exists and isn't ours — merge manually:"
    echo "    cat $home/jesus-loop/hooks.json"
  else
    cp "$home/jesus-loop/hooks.json" "$home/hooks.json"
    echo "  ✓ $home/hooks.json wired to Stop hook"
  fi

  echo "  ✓ prompts installed: take-the-wheel, steer ($(ls "$home/prompts" | wc -l | tr -d ' ') total)"
  echo "  Restart codex to pick up new prompts. Then: /prompts:take-the-wheel <task>"
}

# ---------- opencode ----------
install_opencode() {
  local mode="${1:-project}" proj="${2:-$PWD}"
  local target
  case "$mode" in
    project) target="$proj/.opencode";;
    global)  target="${XDG_CONFIG_HOME:-$HOME/.config}/opencode";;
    *) echo "opencode: --project DIR or --global" >&2; exit 1;;
  esac
  echo "→ opencode: installing to $target"
  mkdir -p "$target/jesus-loop" "$target/plugins" "$target/commands"
  for d in core data scripts adapters; do
    [[ -d "$SOURCE_ROOT/$d" ]] && copy_tree "$SOURCE_ROOT/$d" "$target/jesus-loop/$d"
  done
  cp "$SOURCE_ROOT/adapters/opencode/plugin.ts"    "$target/plugins/jesus-loop.ts"
  merge_settings_json "$target/package.json" "$SOURCE_ROOT/adapters/opencode/package.json"
  for f in "$SOURCE_ROOT"/adapters/opencode/commands/*.md; do
    [[ -f "$f" ]] || continue
    cp "$f" "$target/commands/$(basename "$f")"
  done
  echo "  ✓ plugin.ts + commands installed"
  echo "  Run 'cd $target && bun install' once for bun-types (optional)."
  echo "  Then in opencode: /take-the-wheel <task>"
}

# ---------- uninstall ----------
uninstall_harness() {
  local h="${1:-}"
  case "$h" in
    codex)
      echo "→ codex: removing $HOME/.codex/jesus-loop and prompts"
      rm -rf "$HOME/.codex/jesus-loop"
      rm -f "$HOME/.codex/prompts/take-the-wheel.md" "$HOME/.codex/prompts/steer.md"
      [[ -f "$HOME/.codex/hooks.json" ]] && grep -q jesus-loop "$HOME/.codex/hooks.json" && rm -f "$HOME/.codex/hooks.json"
      ;;
    opencode)
      echo "→ opencode: removing $PWD/.opencode/jesus-loop"
      rm -rf "$PWD/.opencode/jesus-loop" "$PWD/.opencode/plugins/jesus-loop.ts"
      rm -f "$PWD/.opencode/commands/take-the-wheel.md" "$PWD/.opencode/commands/steer.md"
      ;;
    claude-code) echo "→ claude-code: edit .claude/settings.json by hand to revert permissions";;
    *) echo "uninstall: claude-code | codex | opencode" >&2; exit 1;;
  esac
}

# ---------- dispatch ----------
case "$CMD" in
  ""|-h|--help) usage;;
  claude-code)
    PROJ="$PWD"
    while [[ $# -gt 0 ]]; do case $1 in --project) PROJ="$2"; shift 2;; *) shift;; esac; done
    install_cc "$PROJ";;
  codex)
    HOMEDIR="$HOME/.codex"
    while [[ $# -gt 0 ]]; do case $1 in --home) HOMEDIR="$2"; shift 2;; *) shift;; esac; done
    install_codex "$HOMEDIR";;
  opencode)
    MODE="project"; PROJ="$PWD"
    while [[ $# -gt 0 ]]; do
      case $1 in --project) MODE="project"; PROJ="$2"; shift 2;; --global) MODE="global"; shift;; *) shift;; esac
    done
    install_opencode "$MODE" "$PROJ";;
  all)
    install_cc "$PWD"
    install_codex "$HOME/.codex"
    install_opencode "project" "$PWD"
    ;;
  uninstall) uninstall_harness "${1:-}";;
  *) echo "unknown: $CMD" >&2; usage; exit 1;;
esac
