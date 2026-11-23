#!/usr/bin/env bash
# The visual QA capture on gs-game's shot tool (gs-game docs/visual-qa.md): first person | behind-right | opponent, per
# weapon and clip. gpu.sh runs only tools/*.sh.
#   tools/visual_qa_shot.sh [--only bow,spear] [--clips swing,block,inspect,holster,draw_loose,fire_reload] [--out DIR] [--fps 30] [--clip-dir DIR]
exec bash "$(dirname "$0")/../addons/gs_game/tools/gs_game_visual_qa_shot.sh" --script tools/visual_qa.gd -- "$@"
