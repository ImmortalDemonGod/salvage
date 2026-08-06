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
rm -rf site && mkdir -p site
cp -r export/web/* site/
touch site/.nojekyll
git add -A site
git -c commit.gpgsign=false commit -q -m "web export" || true
git push -q origin HEAD

if command -v vercel >/dev/null 2>&1; then
  (cd site && vercel deploy --prod --yes >/dev/null 2>&1) && echo "deployed: https://salvage-chi.vercel.app/"
fi

# and then ASK it, rather than announcing it. This script used to print the
# URL and stop; the first person to open that URL got a 404.
#
if command -v node >/dev/null 2>&1; then
  PLAYWRIGHT_CORE=${PLAYWRIGHT_CORE:-$HOME/node_modules/playwright-core/index.mjs} \
    node "$(dirname "$0")/../verify/live.mjs" 2>&1 | tail -2
fi
