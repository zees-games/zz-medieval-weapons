#!/usr/bin/env bash
# Rewrites weapons/*.tres, provides.json and the default cfg yml from the code table.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
exec timeout 120 "${GODOT:-godot}" --headless --path . --script res://tools/export_defs.gd
