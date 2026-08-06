#!/bin/bash
# Build the web export and publish it to gh-pages. One link for the team.
# Every piece of real feedback this project has ever received came from a
# link, so this runs on day one with a placeholder in it, not at the end.
set -e
cd "$(dirname "$0")/.."
godot --headless --path "$PWD" --export-release "Web" export/web/index.html >/dev/null 2>&1
tmp=$(mktemp -d)
cp -r export/web/* "$tmp"/
touch "$tmp/.nojekyll"
git worktree remove --force /tmp/ghp 2>/dev/null || true
git branch -D gh-pages 2>/dev/null || true
git worktree add -q --detach /tmp/ghp
cd /tmp/ghp
git checkout -q --orphan gh-pages
git rm -rq --cached . 2>/dev/null || true
rm -rf ./* 2>/dev/null || true
cp -r "$tmp"/* "$tmp"/.nojekyll .
git add -A
git -c commit.gpgsign=false commit -q -m "web export"
git push -q -f origin gh-pages
cd - >/dev/null
git worktree remove --force /tmp/ghp
rm -rf "$tmp"
echo "deployed: https://immortaldemongod.github.io/salvage/"
