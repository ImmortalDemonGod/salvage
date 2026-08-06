#!/bin/bash
rm -f "$HOME/salvage/verify/.run-armed" "$HOME/salvage/verify/.stop-blocks"
pkill -f "caffeinate -dims" 2>/dev/null || true
echo "run DISARMED: the Stop hook is inert and sessions can end normally"
