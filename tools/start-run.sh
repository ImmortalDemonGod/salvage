#!/bin/bash
# Start the SALVAGE overnight run. One action, and one to abort.
#   start:  tools/start-run.sh
#   abort:  rm ~/salvage/verify/.run-armed
set -e
cd "$(dirname "$0")/.."
date
command -v caffeinate >/dev/null && (caffeinate -dims &) && echo "caffeinate: started"
rm -f verify/.stop-blocks
touch verify/.run-armed
echo "run ARMED: the Stop hook will now block until three consecutive dry deep passes"
echo
echo "--- fast set ---"
godot --headless --path "$PWD" --script verify/checks.gd 2>&1 | grep -vE "^Godot Engine|^$" || true
echo
echo "--- deep set ---"
godot --headless --path "$PWD" --script verify/deep.gd -- 600 2>&1 | grep -vE "^Godot Engine|^$" || true
echo
echo "Bootstrap order is binding. Next: scene-tree layout invariants, BEFORE content."
