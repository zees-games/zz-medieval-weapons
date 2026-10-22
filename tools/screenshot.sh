#!/usr/bin/env bash
# tools/screenshot.sh [weapon ...]  renders each weapon's model to screenshots/<id>.png under Xvfb
# (a --headless render is black). With no weapon, all eight. Look at the PNGs.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
command -v Xvfb >/dev/null || { echo "Xvfb not installed" >&2; exit 3; }
disp=$((200 + RANDOM % 50))
Xvfb ":$disp" -screen 0 800x600x24 >/dev/null 2>&1 &
xpid=$!
trap 'kill $xpid 2>/dev/null' EXIT
sleep 1
DISPLAY=":$disp" LIBGL_ALWAYS_SOFTWARE=1 timeout 120 "${GODOT:-godot}" --path . --resolution 640x480 res://tools/rack.tscn -- "$@"
ls screenshots
