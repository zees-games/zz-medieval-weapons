#!/usr/bin/env bash
# tools/attach_capture.sh <clips dir> [variant] : the visual judge's capture for the attachment meshes. Renders the
# frames on a GPU box (tools/attach_shot.sh through heavy, so the log names the box) and encodes
# <clips dir>/<attachment>/<weapon>.mp4, three cameras side by side. Run as gamedev from the ~/wt worktree:
#   bash addons/gs_game/tools/gs_game_visual_judge.sh --capture 'tools/attach_capture.sh <clips dir>' \
#        --clips <clips dir> --only <attachments> --out <dir>
set -uo pipefail
cd "$(dirname "$0")/.."
clips=${1:?usage: attach_capture.sh <clips dir> [variant]}
variant=${2:-${SHOT_VQA_VARIANT:-0}}
heavy -- tools/attach_shot.sh "--variant=$variant" || exit $?
n=0
for d in screenshots/attach/*/*/; do
  [[ -f $d/f000.png ]] || continue
  att=$(basename "$(dirname "$d")"); w=$(basename "$d")
  mkdir -p "$clips/$att"
  ffmpeg -v error -y -framerate 12 -i "$d/f%03d.png" -c:v libx264 -pix_fmt yuv420p "$clips/$att/$w.mp4" && n=$((n + 1))
done
echo "attach_capture: $n clips in $clips"
((n > 0))
