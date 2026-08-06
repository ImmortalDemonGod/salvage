#!/bin/bash
# Stop-hook gate for the SALVAGE overnight run.
#
# The last project's hook required a wall-clock time plus a completed
# report, and both are satisfiable by waiting: gates went green at 06:21
# and the run spent 97 more minutes producing zero new content. This gate
# is satisfiable only by the deep set going quiet, which requires building.
#
# Exit 0  -> allow stop.  Exit 2 -> block, stderr goes back to the model.
LEDGER="$HOME/salvage/verify/deep-ledger.json"
GUARD="$HOME/salvage/verify/.stop-blocks"
ARMED="$HOME/salvage/verify/.run-armed"
NEED=3
MAX_BLOCKS=400   # safety valve so a broken ledger cannot loop forever

# A blocking Stop hook is a loaded gun. It does nothing unless the run has
# been explicitly armed, so ordinary sessions in this repo (setup, review,
# a quick fix) are never trapped. Arming and aborting are both one file op:
#   arm:   touch verify/.run-armed
#   abort: rm    verify/.run-armed
if [ ! -f "$ARMED" ]; then
  exit 0
fi

n=$(cat "$GUARD" 2>/dev/null || echo 0)
if [ "$n" -ge "$MAX_BLOCKS" ]; then
  echo "stop-gate: block limit $MAX_BLOCKS reached; allowing stop. Investigate the ledger." >&2
  exit 0
fi

if [ ! -f "$LEDGER" ]; then
  echo $((n+1)) > "$GUARD"
  cat >&2 <<'MSG'
STOP BLOCKED: no deep-set ledger exists, so the run has never been measured.
Run the nightly deep set and keep building:
  godot --headless --path ~/salvage --script verify/deep.gd -- 600
The run is DONE only after THREE CONSECUTIVE DRY PASSES. Re-running a green
fast suite is not work.
MSG
  exit 2
fi

streak=$(python3 -c "import json,sys;print(json.load(open('$LEDGER')).get('dry_streak',0))" 2>/dev/null || echo 0)
passes=$(python3 -c "import json,sys;print(json.load(open('$LEDGER')).get('passes',0))" 2>/dev/null || echo 0)

if [ "$streak" -ge "$NEED" ]; then
  echo "stop-gate: $streak consecutive dry deep passes over $passes total. Run may stop." >&2
  rm -f "$GUARD"
  exit 0
fi

echo $((n+1)) > "$GUARD"
cat >&2 <<MSG
STOP BLOCKED: dry streak is $streak of $NEED (deep passes so far: $passes).

The run is not finished. A pass counts as dry only when it introduces no new
finding AND no check is UNVERIFIED, so coverage cannot be faked by a thin
deep set. Do the next piece of work, then run:
  godot --headless --path ~/salvage --script verify/deep.gd -- 600

Bootstrap order is binding: scene-tree layout invariants, then the
differential harness check, then a clickable web export, then content
starting with tuning G3 into band. Re-running a green fast suite is not work.
MSG
exit 2
