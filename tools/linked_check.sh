#!/usr/bin/env bash
# tools/linked_check.sh: a throwaway game project that only symlinks this pack's addon into its addons/ must still find the glbs
# (they stay in this checkout's assets/, outside that project's res://). Run as `heavy -- tools/linked_check.sh`.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/addons" "$tmp/tools"
cp "$here/project.godot" "$tmp/"
for a in "$here"/addons/*; do ln -s "$(readlink -f "$a")" "$tmp/addons/$(basename "$a")"; done
cp "$here/tools/linked_check.gd" "$tmp/tools/"
godot=${GODOT:-godot}
"$godot" --headless --path "$tmp" --import >/dev/null 2>&1 || true
"$godot" --headless --path "$tmp" --script res://tools/linked_check.gd 2>&1 | grep -v '^WRN\|^Godot Engine'
exit "${PIPESTATUS[0]}"
