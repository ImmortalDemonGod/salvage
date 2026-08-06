#!/bin/bash
# Derived from this script's location, same fix as stop-gate.sh: the
# hardcoded $HOME/salvage was only ever right on one machine, so aborting
# from any other checkout removed nothing and the run stayed armed.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
rm -f "$ROOT/verify/.run-armed" "$ROOT/verify/.stop-blocks"
pkill -f "caffeinate -dims" 2>/dev/null || true
echo "run DISARMED: the Stop hook is inert and sessions can end normally"
