#!/usr/bin/env bash
# tools/view_shot.sh [--world] [weapon ...] : the in-hands contact sheets (tools/sheet.gd) on a real GPU, plus each
# cell at full size in screenshots/frames/. A GPU job: heavy routes tools/*_shot.sh to staging02/staging, so run
#   sudo -u gamedev heavy -- tools/view_shot.sh bow
# from the checkout; never on llvmpipe (tools/screenshot.sh --sheet is the software fallback).
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p screenshots/frames; touch screenshots/.gdignore
# A fresh checkout on the GPU box has no class cache yet; build it first or every class_name fails to parse.
# Twice: the first pass extracts a glb's embedded images, the second imports them.
for _ in 1 2; do timeout 300 godot --headless --path . --import >/dev/null 2>&1 || true; done
xvfb-run -a -s "-screen 0 1280x960x24" timeout 600 godot --path . --resolution 1280x960 \
    res://tools/sheet.tscn -- --frames "$@" 2>&1 | grep -E 'res://screenshots|ERROR|SCRIPT ERROR' | head -80
ls screenshots/frames | wc -l
