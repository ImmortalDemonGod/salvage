// Prove the DEPLOYED build boots, in a real browser, from the real URL.
//
// tools/deploy.sh used to print "deployed: <url>" without ever asking the
// url a question, and the first human to open the link got a 404: the repo
// was private AND Pages had never been enabled. Every file returning 200 is
// still not proof, because a Godot web export can serve every asset and
// then fail to start on a MIME type or a missing header.
//
// So this loads the live page, waits for the engine, reads the beat out of
// the window title, presses ENTER, and checks the title CHANGED. A build
// that advances a beat is a build that is running.
//
//   node verify/live.mjs        (needs playwright-core, same as capture.mjs)
import { readdirSync, existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
const spec = process.env.PLAYWRIGHT_CORE ?? "playwright-core";
const { chromium } = await import(spec);
function findShell() {
  const roots = [join(homedir(), "Library/Caches/ms-playwright")].filter(existsSync);
  for (const root of roots) {
    const dirs = readdirSync(root).filter(d => d.startsWith("chromium_headless_shell-"))
      .sort((a,b) => Number(b.split("-")[1]) - Number(a.split("-")[1]));
    for (const d of dirs) for (const rel of ["chrome-headless-shell-mac-arm64/chrome-headless-shell","chrome-headless-shell-mac-x64/chrome-headless-shell"]) {
      const p = join(root, d, rel); if (existsSync(p)) return p;
    }
  }
}
const browser = await chromium.launch({ executablePath: findShell(), args: ["--use-gl=swiftshader","--enable-unsafe-swiftshader"] });
const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
const errors = [], failed = [];
page.on("pageerror", e => errors.push(String(e).slice(0,200)));
page.on("requestfailed", r => failed.push(r.url().split("/").pop() + " :: " + (r.failure()?.errorText ?? "?")));
page.on("response", r => { if (r.status() >= 400) failed.push(r.url().split("/").pop() + " :: HTTP " + r.status()); });
await page.goto("https://salvage-chi.vercel.app/", { waitUntil: "load", timeout: 90000 });
await page.waitForTimeout(20000);
const title = await page.title();
// press ENTER twice and see whether the build advances, which only works if it is really running
// CLICK FIRST, on the opening screen, where a click advances the beat and
// the effect is therefore observable. The first version of this check
// clicked during a FIGHT, where a click attacks instead of changing the
// beat, so it reported the mouse broken while the mouse was fine: a test
// that cannot see the thing it is testing.
await page.mouse.click(640, 520);
await page.waitForTimeout(1500);
const clicked = await page.title();
// keys, where they have an observable effect: three SPACEs kill the
// descent's single 6hp limb and the run advances. ENTER during a fight
// only ends a turn, which is why the first version of this check reported
// the keyboard broken while the keyboard was fine.
for (let i = 0; i < 4; i++) { await page.keyboard.press("Space"); await page.waitForTimeout(700); }
await page.waitForTimeout(2200);
const after = await page.title();
await page.screenshot({ path: "/tmp/live-boot.png" });
console.log("TITLE AT BOOT : " + title);
console.log("PAGE ERRORS   : " + (errors.length ? errors.join(" | ") : "none"));
console.log("FAILED REQS   : " + (failed.length ? failed.join(" | ") : "none"));
const mouseWorks = clicked !== title;
console.log("TITLE AFTER CLICK: " + clicked + (mouseWorks ? "  (the mouse reaches the game)" : "  <-- FINDING: the click did nothing"));
const keyWorks = after !== clicked;
console.log("TITLE AFTER ENTER: " + after + (keyWorks ? "" : "  <-- FINDING: the key did nothing"));
const ok = mouseWorks && keyWorks && clicked.includes("beat=") && errors.length === 0 && failed.length === 0;
console.log(ok ? "LIVE: the deployed build boots and responds to input" : "LIVE: FINDING -- the deployed build is not playable from its own URL");
await browser.close();
process.exit(ok ? 0 : 1);
