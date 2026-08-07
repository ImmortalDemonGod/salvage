#!/bin/bash
# The gallery: one capture per key state, as PLAYED, for G6 and G10.
# Headless Godot cannot render, so every shot comes from the web export
# driven through real KeyboardEvents (verify/capture.mjs).
cd "$(dirname "$0")/.."
OUT=${1:-/tmp/salvage-gallery}
rc=0
rm -rf "$OUT"; mkdir -p "$OUT"
if ! ./tools/deploy.sh --export-only >/dev/null 2>&1; then
  echo "FINDING  THE EXPORT FAILED -- every capture below would photograph a stale build"
  exit 1
fi
shoot() {  # name, keys, expected beat id
  local d="$OUT/$1"
  local log="$OUT/$1.log"
  PLAYWRIGHT_CORE=${PLAYWRIGHT_CORE:-$HOME/node_modules/playwright-core/index.mjs} \
    node verify/capture.mjs "$d" "$2" "$3" > "$log" 2>&1
  if grep -q "^FINDING" "$log"; then
    grep "^FINDING" "$log"
    rc=1
  fi
  # keep only the last frame: that is the state we asked for
  # numeric sort: "99" sorts after "250" lexicographically, which silently
  # picked the wrong frame for every sequence longer than 99 keys
  last=$(ls "$d" | sort -V | tail -1)
  mv "$d/$last" "$OUT/$1.png"; rm -rf "$d"
  echo "  $1.png"
}
echo "gallery -> $OUT"
# The sequences used to be hand-authored, so the gallery reached the crab and
# stopped: six shots covering four of nine beats, while G10 -- a BLOCKING
# gate -- had never cold-read either lock, the vent worm or the dredge.
# tools/keypath.gd derives them by playing the run with the judge bots and
# writing down the key each action corresponds to, and it fails if any beat
# in the ladder is unreachable. The gallery can no longer fall behind the game.
paths=$(godot --headless --path "$PWD" --script tools/keypath.gd 2>/dev/null | grep -E "^[a-z0-9_]+	")
if [ -z "$paths" ]; then
  echo "FINDING  KEYPATH PRODUCED NOTHING -- the gallery would silently shrink to nothing"
  exit 1
fi
n=0
while IFS=$'\t' read -r id seq; do
  n=$((n+1))
  shoot "$(printf '%02d' $n)-$id" "$seq" "$id"
done <<< "$paths"
# and one mid-fight shot, which is the state the cold read actually reads
shoot "$(printf '%02d' $((n+1)))-fight1-midway" "Enter,Space,Space,Enter,Space,Enter,KeyW,Space,Space,Enter,Space,Space,Enter" "fight1"
# and one shot AFTER reading a limb, because every gallery so far showed
# every limb unread and a reviewer concluded, reasonably, that the whole
# mechanic was skippable and skipped
shoot "$(printf '%02d' $((n+2)))-fight1-read" "Enter,Space,Space,Enter,KeyW,KeyA,Space,Enter,KeyR,KeyA,Space" "fight1"
# the transition ITSELF, shot 1200ms into the descent overlay after the
# crab falls: the win line, the sinking squad, the destination name.
# Unverified transitions shipped invisible once (the log row lesson's
# cousin); this line keeps them photographed.
TRANSITION_MS=1200 shoot "$(printf '%02d' $((n+4)))-transition" "Enter,Space,Space,Enter,KeyW,KeyA,Space,Enter,KeyR,KeyA,Space,Space,Enter,KeyQ,Space,Space,Enter,Space,Space,Enter,Space,Space" "fight1"
# and the same mid-fight state through a WIDE window: three playtests
# reported off-centre UI that the 1280-wide capture could not see
WIDE=1 shoot "$(printf '%02d' $((n+3)))-fight1-wide" "Enter,Space,Space,Enter,Space,Enter,KeyW,Space,Space,Enter,Space,Space,Enter" "fight1"
if [ $rc -ne 0 ]; then echo "GALLERY: replay landed on the wrong beat"; exit 1; fi
echo "GALLERY: $((n+1)) shots, every replay landed where it claimed"
