#!/bin/bash
# Build the web export and publish it to gh-pages. One link for the team.
# Every piece of real feedback this project has ever received came from a
# link, so this runs on day one with a placeholder in it, not at the end.
set -e
cd "$(dirname "$0")/.."
godot --headless --path "$PWD" --export-release "Web" export/web/index.html >/dev/null 2>&1
if [ "$1" = "--export-only" ]; then
  echo "exported: export/web (not published)"
  exit 0
fi
# Publish through docs/ on main and the Actions workflow, not by force
# pushing an orphan gh-pages every time. The legacy branch builder errored
# on two of three attempts with a null message and left the live site three
# deploys behind for an hour.
rm -rf docs && mkdir -p docs
cp -r export/web/* docs/
touch docs/.nojekyll
git add -A docs
git -c commit.gpgsign=false commit -q -m "web export" || true
git push -q origin HEAD

echo "pushed: docs/ on main -- the pages workflow publishes it"

# and then ASK it, rather than announcing it. This script used to print the
# URL and stop; the first person to open that URL got a 404.
#
# WAIT FOR PAGES FIRST. A push is not a publish: the build takes minutes on
# a 39MB wasm, and for fifteen of them this check kept testing the PREVIOUS
# build and reporting the new one broken. Poll until the served payload is
# the one that was just pushed.
want=$(stat -f%z export/web/index.pck 2>/dev/null || stat -c%s export/web/index.pck)
for _ in $(seq 1 40); do
  got=$(curl -s -I https://immortaldemongod.github.io/salvage/index.pck | grep -i content-length | tr -dc "0-9")
  [ "$got" = "$want" ] && break
  sleep 15
done
if [ "$got" != "$want" ]; then
  echo "FINDING  PAGES IS STILL SERVING THE OLD BUILD ($got bytes, expected $want)"
fi
if command -v node >/dev/null 2>&1; then
  PLAYWRIGHT_CORE=${PLAYWRIGHT_CORE:-$HOME/node_modules/playwright-core/index.mjs} \
    node "$(dirname "$0")/../verify/live.mjs" 2>&1 | tail -2
fi
