#!/usr/bin/env bash
# tools/screenshot.sh --sheet|--world [weapon ...]  eight-frame contact sheets of the weapon in
# hands (first person, or a person seen from outside) -> screenshots/view_<id>.png, world_<id>.png.
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
scene=res://tools/rack.tscn
res=640x480
case "${1:-}" in
    --sheet) shift; scene=res://tools/sheet.tscn; res=400x300 ;;
    --world) scene=res://tools/sheet.tscn; res=400x300 ;;
esac
DISPLAY=":$disp" LIBGL_ALWAYS_SOFTWARE=1 timeout 300 "${GODOT:-godot}" --path . --resolution "$res" "$scene" -- "$@"
ls screenshots
