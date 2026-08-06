#!/bin/bash
# Build the web export and publish it to the URL the team actually holds.
# Every piece of real feedback this project has ever received came from a
# link, so this runs on day one with a placeholder in it, not at the end.
set -e
cd "$(dirname "$0")/.."
godot --headless --path "$PWD" --export-release "Web" export/web/index.html >/dev/null 2>&1
if [ "$1" = "--export-only" ]; then
  echo "exported: export/web (not published)"
  exit 0
fi

# site/ is committed on main so the artifact that went out is the artifact
# in history. The rm below used to delete site/.vercel with everything
# else, which unlinked the project; every deploy after the first then
# landed in an auto-created project while the advertised URL kept serving
# the first build all afternoon. The link survives the rebuild now.
KEEP=""
if [ -d site/.vercel ]; then KEEP=$(mktemp -d); cp -R site/.vercel "$KEEP/"; fi
rm -rf site && mkdir -p site
cp -r export/web/* site/
touch site/.nojekyll
if [ -n "$KEEP" ]; then cp -R "$KEEP/.vercel" site/; rm -rf "$KEEP"; fi
git add -A site
git -c commit.gpgsign=false commit -q -m "web export" || true
git push -q origin HEAD

# The deploy used to run with output discarded and failure swallowed, and
# live.mjs stayed green against the stale build because a stale build also
# boots, clicks and reaches fight1. Behavior is not identity. So: the
# deploy may not fail silently, it may not run unlinked, and afterwards
# the advertised URL must serve the exact bytes of this build.
URL="https://salvage-chi.vercel.app"
if [ ! -f site/.vercel/project.json ]; then
  echo "DEPLOY REFUSED: site/ is not linked (cd site && vercel link --project salvage)"
  exit 1
fi
grep -q '"projectName":"salvage"' site/.vercel/project.json || {
  echo "DEPLOY REFUSED: site/ is linked to the wrong project"
  exit 1
}
(cd site && vercel deploy --prod --yes >/dev/null) || { echo "DEPLOY FAILED"; exit 1; }
want=$(openssl md5 -r site/index.pck | cut -d' ' -f1)
got=$(curl -sf "$URL/index.pck?v=$want" | openssl md5 -r | cut -d' ' -f1)
if [ "$want" != "$got" ]; then
  echo "DEPLOY LIED: $URL serves pck $got, this build is $want"
  exit 1
fi
# the wasm is the engine; Vercel's etag for a static file is its md5
want_w=$(openssl md5 -r site/index.wasm | cut -d' ' -f1)
got_w=$(curl -sfI "$URL/index.wasm?v=$want_w" | tr -d '"\r' | awk 'tolower($1)=="etag:"{print $2}')
if [ "$want_w" != "$got_w" ]; then
  echo "DEPLOY LIED: $URL serves wasm $got_w, this build is $want_w"
  exit 1
fi
echo "deployed and verified: $URL serves this exact build (pck $want)"

# and then ASK it, rather than announcing it: the behavior pass still runs,
# it is just no longer the only witness.
if command -v node >/dev/null 2>&1; then
  PLAYWRIGHT_CORE=${PLAYWRIGHT_CORE:-$HOME/node_modules/playwright-core/index.mjs} \
    node "$(dirname "$0")/../verify/live.mjs" 2>&1 | tail -3
fi
