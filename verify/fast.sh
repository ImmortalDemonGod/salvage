#!/bin/bash
# The per-commit set. Every detector must be invoked by this or the nightly
# job (standing rule 11): an instrument nothing runs cannot block.
#
# THREE THINGS THIS GATES BEYOND THE DETECTORS THEMSELVES, each added after
# a defect got through:
#   1. Every .gd PARSES. GDScript fails at load, so a broken script is
#      discovered one-at-a-time when something happens to run it. Checking
#      all of them costs a second and finds them in one pass.
#   2. Engine stderr is EVIDENCE. "Invalid polygon data, triangulation
#      failed" printed on every frame while the enemy silently did not draw
#      and every test stayed green. An ERROR line is now a finding.
#   3. quit() without a following return. quit() only REQUESTS a quit, so
#      the code after it still runs; this made a fully green fast set exit 1.
cd "$(dirname "$0")/.."
rc=0
note() { echo "FINDING  $1"; rc=1; }

# --- 1. everything parses -------------------------------------------------
bad=0
while IFS= read -r f; do
  out=$(godot --headless --path "$PWD" --check-only --script "$f" 2>&1 | grep -E "Parse Error|Compile Error")
  if [ -n "$out" ]; then
    note "DOES NOT PARSE: $f :: $(echo "$out" | head -1 | sed 's/^ *//')"
    bad=$((bad+1))
  fi
done < <(find sim tools verify game content -name '*.gd' 2>/dev/null | sort)
echo "parse      $(find sim tools verify game content -name '*.gd' 2>/dev/null | wc -l | tr -d ' ') scripts checked, $bad broken"

# --- 3. quit() must return ------------------------------------------------
while IFS= read -r f; do
  if grep -n -A1 'quit(' "$f" | grep -A1 'quit(' | grep -q 'quit(' ; then :; fi
  awk -v F="$f" '/[^_a-zA-Z]quit\(/ {q=NR; line=$0; next}
       q && NR==q+1 { if ($0 !~ /return/ && line !~ /#/) print F":"q" "line; q=0 }' "$f" \
    | while read -r hit; do note "QUIT WITHOUT RETURN: $hit (quit only requests; code after it still runs)"; done
done < <(find verify tools -name '*.gd' 2>/dev/null | sort)

# --- the detectors, with 2. engine stderr gated ---------------------------
for s in verify/checks.gd verify/teach.gd verify/pillar.gd verify/audio.gd verify/layout.gd verify/fuzz.gd verify/differential.gd; do
  [ -f "$s" ] || continue
  out=$(godot --headless --path "$PWD" --script "$s" 2>&1 | grep -vE "^Godot Engine|^$")
  echo "$out" | grep -vE "^(ERROR|SCRIPT ERROR|WARNING|USER ERROR)|^ *at:|^ *GDScript backtrace|^ *\[[0-9]+\]"
  echo "$out" | grep -q "FINDING" && rc=1
  eng=$(echo "$out" | grep -cE "^(ERROR|SCRIPT ERROR|USER ERROR)")
  if [ "$eng" -gt 0 ]; then
    note "ENGINE ERRORS during $s: $eng line(s) -- $(echo "$out" | grep -E "^(ERROR|SCRIPT ERROR|USER ERROR)" | head -1)"
  fi
done
# Record the exact commit this verdict applies to. The deep set refuses to
# count a pass as DRY unless the fast set is green ON THIS CODE: otherwise
# a known-broken build could accumulate a dry streak and satisfy the stop
# gate by finding nothing new in something already red.
sha=$(git rev-parse HEAD 2>/dev/null || echo none)
dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
printf '%s %s %s\n' "$rc" "$sha" "$dirty" > verify/.fast-status
exit $rc
