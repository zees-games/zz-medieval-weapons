#!/usr/bin/env bash
# tools/art_sheet.sh PACK_DIR [out.png]: contact sheet of the weapon_art() hook, the bare zee stand-in beside the pack's own model.
# Needs zee-dot-weapons linked into addons/ (a dev-only link: zee is not a dependency of the pack) and a display, so it runs under Xvfb.
# Run as `heavy -- tools/art_sheet.sh zz_modern_weapons`.
set -uo pipefail
cd "$(dirname "$0")/.."
pack="${1:?pack directory name under addons/, e.g. zz_modern_weapons}"
out="${2:-$PWD/screenshots/art-sheet.png}"
mkdir -p "$(dirname "$out")"
xvfb-run -a -s "-screen 0 2400x2400x24" timeout 120 godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 \
    res://tools/art_sheet.tscn -- --pack "$pack" --shot "$out" 2>&1 | grep -v '^WRN' | tail -5
[ -s "$out" ] && echo "wrote $out" || { echo "capture failed: $out" >&2; exit 1; }
