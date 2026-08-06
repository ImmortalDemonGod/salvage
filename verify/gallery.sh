#!/bin/bash
# The gallery: one capture per key state, as PLAYED, for G6 and G10.
# Headless Godot cannot render, so every shot comes from the web export
# driven through real KeyboardEvents (verify/capture.mjs).
cd "$(dirname "$0")/.."
OUT=${1:-/tmp/salvage-gallery}
rm -rf "$OUT"; mkdir -p "$OUT"
./tools/deploy.sh >/dev/null 2>&1
shoot() {  # name, keys
  local d="$OUT/$1"
  PLAYWRIGHT_CORE=${PLAYWRIGHT_CORE:-$HOME/node_modules/playwright-core/index.mjs} \
    node verify/capture.mjs "$d" "$2" >/dev/null 2>&1
  # keep only the last frame: that is the state we asked for
  last=$(ls "$d" | sort | tail -1)
  mv "$d/$last" "$OUT/$1.png"; rm -rf "$d"
  echo "  $1.png"
}
echo "gallery -> $OUT"
shoot 01-opening ""
shoot 02-descent "Enter"
shoot 03-descent-fought "Enter,Space,Space"
shoot 04-crab "Enter,Space,Space,Enter"
shoot 05-crab-moved "Enter,Space,Space,Enter,KeyR,Space"
shoot 06-crab-hurt "Enter,Space,Space,Enter,Space,Enter,Space,Enter,Space,Enter"
