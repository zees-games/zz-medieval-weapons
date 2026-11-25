#!/usr/bin/env bash
# tools/attach_shot.sh [--variant=N] : renders the fitted-weapon frames (tools/attach_shot.gd) to
# screenshots/attach/<attachment>/<weapon>/f###.png. A GPU job: heavy routes tools/*_shot.sh to staging02/staging and
# copies the pngs back; never llvmpipe. tools/attach_capture.sh is the judge's capture (this, then the mp4s).
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p screenshots; touch screenshots/.gdignore
rm -rf screenshots/attach
# A fresh checkout on the GPU box has no class cache yet; twice, as in view_shot.sh.
for _ in 1 2; do timeout 300 godot --headless --path . --import >/dev/null 2>&1 || true; done
xvfb-run -a -s "-screen 0 1280x960x24" timeout 900 godot --path . --resolution 400x400 res://tools/attach_shot.tscn -- "$@" 2>&1 \
    | grep -E '^clip |ERROR|SCRIPT ERROR|Using Device' | head -80
