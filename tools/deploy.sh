#!/bin/bash
# Build the web export and publish it to the URL the team actually holds.
# Every piece of real feedback this project has ever received came from a
# link, so this runs on day one with a placeholder in it, not at the end.
set -e
set -o pipefail
cd "$(dirname "$0")/.."

# The export dir is cleaned first: it used to accumulate, and files no
# current build produces (day-old .import metadata) were shipping to
# production with every deploy.
rm -rf export/web && mkdir -p export/web
godot --headless --path "$PWD" --export-release "Web" export/web/index.html >/dev/null 2>&1
[ -f export/web/index.html ] || { echo "EXPORT FAILED: no index.html produced"; exit 1; }
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
if ! git diff --cached --quiet; then
  git -c commit.gpgsign=false commit -q -m "web export"
fi
git push -q origin HEAD

# The deploy publishes the commit it came from at /build.txt, so which
# build a browser is running is observable from the outside. Without
# this, a stale build is indistinguishable from a fresh one, which is
# exactly how three hours of deploys went missing unnoticed. The file is
# gitignored: stamping the committed HTML with HEAD would dirty the tree
# and mint a fresh commit on every deploy forever.
SHA=$(git rev-parse --short HEAD)
echo "$SHA" > site/build.txt

# The deploy may not fail silently, may not run unlinked, and afterwards
# the advertised URL must serve the exact bytes of this build. Behavior
# is not identity: live.mjs stayed green against the stale build all
# afternoon because a stale build also boots, clicks and reaches fight1.
URL="https://salvage-chi.vercel.app"
if [ ! -f site/.vercel/project.json ]; then
  echo "DEPLOY REFUSED: site/ is not linked (cd site && vercel link --project salvage)"
  exit 1
fi
grep -q '"projectName":"salvage"' site/.vercel/project.json || {
  echo "DEPLOY REFUSED: site/ is linked to the wrong project"
  exit 1
}
out=$( (cd site && vercel deploy --prod --yes 2>&1) ) || {
  echo "$out"
  echo "DEPLOY FAILED"
  exit 1
}
echo "$out" | grep -Ei "^(Production|Aliased):" || true

# Every file the site ships is witnessed, not the two that feel
# important: a deploy that changes only the HTML passes a pck-only
# check. Vercel's static etag is the content md5 (verified against
# byte-identical downloads); any deviation fails loud here, never quiet.
fail=0
while IFS= read -r f; do
  rel=${f#site/}
  want=$(openssl md5 -r "$f" | cut -d' ' -f1)
  case "$want" in
    ????????????????????????????????) ;;
    *) echo "DEPLOY CHECK BROKEN: no hash for $rel"; exit 1 ;;
  esac
  got=$(curl -sf --max-time 30 -I "$URL/$rel" | tr -d '"\r' | awk 'tolower($1)=="etag:"{print $2}') || got=""
  if [ "$want" != "$got" ]; then
    echo "DEPLOY LIED: $rel serves ${got:-nothing}, this build is $want"
    fail=1
  fi
done < <(find site -type f ! -path "site/.vercel/*" ! -name ".nojekyll")
[ "$fail" -eq 0 ] || exit 1

# and the game content is verified by its actual bytes, plus the build
# stamp read back off the served page, so the etag assumption is never
# the only witness
want=$(openssl md5 -r site/index.pck | cut -d' ' -f1)
got=$(curl -sf --max-time 60 "$URL/index.pck" | openssl md5 -r | cut -d' ' -f1)
if [ -z "$got" ] || [ "$want" != "$got" ]; then
  echo "DEPLOY LIED: $URL serves pck ${got:-nothing}, this build is $want"
  exit 1
fi
[ "$(curl -sf --max-time 30 "$URL/build.txt")" = "$SHA" ] || {
  echo "DEPLOY LIED: $URL/build.txt is not $SHA"
  exit 1
}

# and then ASK it, rather than announcing it. With pipefail set, a red
# here stops the script; the success line prints after the gate, not
# before it.
if command -v node >/dev/null 2>&1; then
  live=$(PLAYWRIGHT_CORE=${PLAYWRIGHT_CORE:-$HOME/node_modules/playwright-core/index.mjs} \
    node "$(dirname "$0")/../verify/live.mjs" 2>&1) || {
    echo "$live"
    echo "LIVE GATE RED"
    exit 1
  }
  echo "$live" | tail -3
fi
echo "deployed and verified: $URL serves build $SHA in these exact bytes (pck $want)"
