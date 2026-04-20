#!/bin/bash
# sermon.sh — print the teachings log for one or all sessions.
set -euo pipefail
SESSION=""; ALL=0; STATE_DIR=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --session) SESSION="$2"; shift 2;;
    --all) ALL=1; shift;;
    --state-dir) STATE_DIR="$2"; shift 2;;
    -h|--help) echo "sermon.sh [--session NAME | --all] [--state-dir DIR]"; exit 0;;
    *) shift;;
  esac
done
[[ -z "$STATE_DIR" ]] && for d in .claude .codex .opencode; do [[ -d "$d" ]] && STATE_DIR="$d" && break; done
[[ -n "$STATE_DIR" ]] || { echo "No teachings yet. Start with /take-the-wheel."; exit 0; }

shopt -s nullglob
if [[ "$ALL" == "1" ]]; then
  files=("$STATE_DIR"/jesus-loop.*.teachings.local.md)
else
  SESSION="${SESSION:-default}"
  files=("$STATE_DIR/jesus-loop.$SESSION.teachings.local.md")
fi
n=0
for f in "${files[@]}"; do
  [[ -f "$f" ]] || continue
  echo "═══ $(basename "$f") ═══"
  cat "$f"
  echo
  n=$((n+1))
done
if [[ "$n" == "0" ]]; then echo "No teachings yet for this session. Start with /take-the-wheel."; fi
exit 0
