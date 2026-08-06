#!/bin/bash
# The per-commit set. Every detector must be invoked by this or by the
# nightly job (standing rule 11): an instrument nothing runs cannot block.
cd "$(dirname "$0")/.."
rc=0
for s in verify/checks.gd verify/layout.gd verify/fuzz.gd verify/differential.gd; do
  [ -f "$s" ] || continue
  out=$(godot --headless --path "$PWD" --script "$s" 2>&1 | grep -vE "^Godot Engine|^$")
  echo "$out"
  echo "$out" | grep -q "FINDING" && rc=1
done
exit $rc
