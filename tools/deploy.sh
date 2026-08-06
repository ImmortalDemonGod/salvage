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
tmp=$(mktemp -d)
cp -r export/web/* "$tmp"/
touch "$tmp/.nojekyll"
# Update gh-pages IN PLACE rather than force-pushing a fresh orphan every
# time. Two of the last three Pages builds errored, the site sat three
# deploys behind, and a rebuilt-from-nothing branch on every push is the
# most likely reason: Pages is being asked to reconcile a tree with no
# shared history each time.
git worktree remove --force /tmp/ghp 2>/dev/null || true
git fetch -q origin gh-pages 2>/dev/null || true
if git rev-parse --verify -q origin/gh-pages >/dev/null; then
  git worktree add -q /tmp/ghp -B gh-pages origin/gh-pages
else
  git worktree add -q --detach /tmp/ghp
  cd /tmp/ghp && git checkout -q --orphan gh-pages && cd - >/dev/null
fi
cd /tmp/ghp
find . -maxdepth 1 ! -name . ! -name .git -exec rm -rf {} + 2>/dev/null || true
cp -r "$tmp"/* .
cp "$tmp/.nojekyll" .
git add -A
git -c commit.gpgsign=false commit -q -m "web export" || true
git push -q origin gh-pages
cd - >/dev/null
git worktree remove --force /tmp/ghp
rm -rf "$tmp"
echo "deployed: https://immortaldemongod.github.io/salvage/"
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
