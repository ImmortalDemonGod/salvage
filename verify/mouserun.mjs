// The mouse-only full-completion gate: prove the whole run -- opening,
// descent, fight1, boat1, puzzle1, fight2, puzzle2, boat2, deep1, ending --
// can be finished START TO END with nothing but left clicks. No keyboard.
//
// Same instrument as capture.mjs (real web export, real browser, the build
// reports its beat in the window title), but the input is the one this gate
// exists to interrogate: the mouse. Every coordinate below is read straight
// from game/main.gd and content/encounters.gd, cited inline, because a
// click test that guesses its own geometry tests the guess.
//
//   PLAYWRIGHT_CORE=~/node_modules/playwright-core/index.mjs node verify/mouserun.mjs
//
// Output contract:
//   MOUSERUN beat=<id> [turn=N]    progress
//   FINDING  <text>                a state the mouse cannot reach or leave
//   BYPASS   <text>                a keyboard press used ONLY to keep the
//                                  audit moving after a FINDING has already
//                                  failed the mouse-only claim (exit stays 1)
//   MOUSERUN: the run completes by mouse alone        exit 0
//   MOUSERUN: stuck at <beat> (<reason>)              exit 1
//
// MOUSE_STRICT=1 stops dead at the first mouse-unreachable state instead of
// bypassing with ENTER to audit the rest of the ladder.
import { readdirSync, existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawn } from "node:child_process";

const REPO = fileURLToPath(new URL("..", import.meta.url));
const STRICT = process.env.MOUSE_STRICT === "1";
const T0 = Date.now();

// ---- the click map, from source ----------------------------------------
// Scene beats: any click advances (main.gd _click: combat == null branch).
// Fights: the action bar is btn_rect(i) = (24, 330 + i*48, 238x42)
//   (main.gd BAR_X/BAR_TOP/BAR_H/BAR_GAP, btn_rect). bar_buttons() is
//   ability0 [, ability1], analyze, rewind, end -- so the count is
//   min(2, kit) + 3, and kit = abilities granted by the ladder: 1 until
//   boat1 grants 2 (content/beats.gd grants_ability). End turn is LAST.
// Diver cards: (24 + i*334, 584, 320x92) (main.gd _build_ui / CARD_TOP).
// Stations: content/encounters.gd "places" per encounter.
// Creature body: enc.art.pos + (0,150), radius 130 (main.gd _body_at).
// Puzzle valves: main.gd _valve_pos with LOCK_TOP=340, LOCK_TALL=168,
//   LOCK_DROP=84. Stage 1 (x=430, wide=420): v1 (500,592), v2 (580,592),
//   seized v3 (876,482). Stage 2 (ax=300, bx=700, wide=240): crossover
//   v4 (620,482), v1 (360,568), v2 (470,568), v3 (810,568).
// Solve orders from tools/bots.gd solve_step: stage 1 opens the seized
//   low valve FIRST (3, then 1, 2); stage 2 opens the crossover FIRST
//   (4, then 1, 2, 3) -- sim/puzzle.gd level_a needs valve3 AND the
//   crossover open, and B drains through, ending dry.
const ORDER = ["opening", "descent", "fight1", "boat1", "puzzle1",
  "fight2", "puzzle2", "boat2", "deep1", "ending"];
const FIGHTS = {
  descent: { body: [900, 480], party: 1, buttons: 4,
    places: [[600, 400]] },
  fight1:  { body: [872, 480], party: 2, buttons: 4,
    places: [[590, 392], [788, 288], [896, 520], [1108, 300]] },
  fight2:  { body: [910, 462], party: 2, buttons: 5,
    places: [[584, 386], [860, 270], [952, 516], [286, 386]] },
  deep1:   { body: [884, 470], party: 3, buttons: 5,
    places: [[614, 400], [782, 296], [1108, 348], [286, 400]] },
};
const PUZZLES = {
  puzzle1: [[876, 482], [500, 592], [580, 592]],
  puzzle2: [[620, 482], [360, 568], [470, 568], [810, 568]],
};
const CARD = (i) => [24 + i * 334 + 160, 584 + 46];
const BTN = (i) => [24 + 119, 330 + i * 48 + 21];
// places a player would plausibly click to leave a solved lock: the open
// door, the "way out" caption, the step line telling them the way is open,
// the middle of the screen, the scene panel. All are >30px from every
// valve, so per main.gd _click they land in the puzzle branch's dead space.
const EXIT_TRIES = [[640, 320], [640, 250], [640, 232], [640, 470], [640, 640], [200, 400]];

// ---- browser plumbing, same shape as capture.mjs -----------------------
async function loadChromium() {
  for (const spec of [process.env.PLAYWRIGHT_CORE, "playwright-core"].filter(Boolean)) {
    try { return (await import(spec)).chromium; } catch {}
  }
  throw new Error("playwright-core not resolvable; set PLAYWRIGHT_CORE");
}
function findShell() {
  if (process.env.CHROME_SHELL) return process.env.CHROME_SHELL;
  const roots = [process.env.PLAYWRIGHT_BROWSERS_PATH,
    join(homedir(), "Library/Caches/ms-playwright"), join(homedir(), ".cache/ms-playwright")]
    .filter(Boolean).filter(existsSync);
  for (const root of roots) {
    const dirs = readdirSync(root).filter((d) => d.startsWith("chromium_headless_shell-"))
      .sort((a, b) => Number(b.split("-")[1]) - Number(a.split("-")[1]));
    for (const d of dirs) for (const rel of [
      "chrome-headless-shell-mac-arm64/chrome-headless-shell",
      "chrome-headless-shell-mac-x64/chrome-headless-shell",
      "chrome-headless-shell-linux/chrome-headless-shell",
      "chrome-linux/headless_shell"]) {
      const p = join(root, d, rel); if (existsSync(p)) return p;
    }
  }
}
const PORT = 8737; // capture.mjs owns 8731; two gates must be co-runnable
const server = spawn("python3", ["-m", "http.server", String(PORT), "--bind", "127.0.0.1"],
  { cwd: join(REPO, "export/web"), stdio: "ignore" });
const stop = () => { try { server.kill(); } catch {} };
process.on("exit", stop);

const chromium = await loadChromium();
const exe = findShell();
const GL_ARGS = ["--use-gl=angle", "--use-angle=swiftshader",
  "--enable-unsafe-swiftshader", "--enable-webgl", "--ignore-gpu-blocklist"];
const browser = await chromium.launch({ headless: true, args: GL_ARGS, ...(exe ? { executablePath: exe } : {}) });
// EXACTLY the design size. project.godot stretches canvas_items/keep from
// 1280x720; at any other viewport the canvas letterboxes and every design
// coordinate above lands somewhere else on the page.
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const errors = [];
page.on("pageerror", (e) => errors.push(String(e).slice(0, 160)));

let firstStuck = null; // { beat, reason }
const findings = [];
function finding(text) { findings.push(text); console.log("FINDING  " + text); }
async function die(beat, reason) {
  console.log(`MOUSERUN: stuck at ${beat} (${reason})`);
  try { await page.screenshot({ path: "/tmp/mouserun-stuck.png" }); } catch {}
  await browser.close(); stop(); process.exit(1);
}
// the whole gate gets 5 minutes; a run that cannot finish inside that is
// stuck no matter what it is doing
let lastBeat = "boot";
const killer = setTimeout(async () => {
  await die(lastBeat, "overall 300s timeout");
}, 300000);
killer.unref?.();

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const beatNow = async () => ((await page.title()).match(/beat=([\w-]+)/)?.[1] ?? "");
async function click(x, y) { await page.mouse.click(x, y); }

// ---- boot ---------------------------------------------------------------
await page.goto(`http://127.0.0.1:${PORT}/index.html`, { waitUntil: "load" });
let booted = false;
for (let i = 0; i < 120 && !booted; i++) {
  await sleep(500);
  booted = await page.evaluate(() => {
    const c = document.querySelector("canvas");
    if (!c || !c.width) return false;
    return !!(c.getContext("webgl2") || c.getContext("webgl"));
  });
}
if (!booted) { console.log("MOUSERUN: stuck at boot (engine never painted)"); await browser.close(); stop(); process.exit(1); }
await sleep(2500);

// ---- per-beat drivers ---------------------------------------------------
async function driveScene(b) {
  // any click advances a scene (main.gd _click, combat == null)
  for (let i = 0; i < 6; i++) {
    await click(640, 300);
    await sleep(1000);
    if (await beatNow() !== b) return true;
  }
  return false;
}

async function driveFight(b) {
  const f = FIGHTS[b];
  for (let turn = 1; turn <= 40; turn++) {
    console.log(`MOUSERUN beat=${b} turn=${turn}`);
    // Each diver: select its card, take the one FREE move of the turn to a
    // ROTATING station (a fixed walk order left both divers parked on
    // limbless stations while the last limb sat elsewhere -- the first run
    // of this gate stalled fight1 at CLAW 1/12 exactly that way), then
    // hammer the creature body. A body click is player_ability(0) with the
    // selected diver; refusals (no air, nothing to hit) are silent no-ops
    // from out here. Clicking the station you already stand on attacks too.
    for (let d = 0; d < f.party; d++) {
      // select FIRST, reposition, then select AGAIN: a station click that
      // lands on another diver's body selects them instead (that is the
      // game's real click grammar), so the re-select restores the diver
      // this loop is driving before it reads and swings
      await click(...CARD(d)); await sleep(90);
      if (await beatNow() !== b) return true;
      const p = f.places[(turn + d * 2) % f.places.length];
      // the plate is the movement handle. It sits +52 under its ring,
      // except belly rings (at or below the body line), whose plates sit
      // BESIDE the ring, outward from the body
      const belly = p[1] >= f.body[1] - 20;
      const side = p[0] >= f.body[0] ? 1 : -1;
      if (belly) { await click(p[0] + side * 166, p[1] + 22); }
      else { await click(p[0], p[1] + 52); }
      await sleep(110);
      await click(...CARD(d)); await sleep(90);
      if (await beatNow() !== b) return true;
      // read the limb in front of you when the tank allows: the analyze
      // button is always third from the bar's end ([..., analyze,
      // rewind, end]). Since the brittle bonus became AIMED (a read
      // gates the x2), a never-reading policy cannot break 15 HP limbs
      // inside the turn cap -- which is the design working.
      await click(...BTN(f.buttons - 3)); await sleep(90);
      for (let k = 0; k < 3; k++) {
        await click(...f.body); await sleep(120);
        // the winning click flips the title IMMEDIATELY (main.gd _after
        // advances the run before the dive transition plays). Checking
        // after every click keeps a stray follow-up click from advancing
        // the next scene beat unseen.
        if (await beatNow() !== b) return true;
      }
    }
    // end turn: ALWAYS the last button. 4 buttons while the ladder has
    // granted one ability (descent, fight1), 5 after boat1 grants the
    // second (fight2, deep1). A click on the empty rect below a 4-button
    // bar would hit nothing, but the count here is derived from the same
    // ladder the game reads, so it is not a guess.
    await click(...BTN(f.buttons - 1));
    await sleep(800);
    if (await beatNow() !== b) return true;
  }
  return false;
}

async function drivePuzzle(b) {
  // turn the valves in the solver's order (tools/bots.gd solve_step)
  for (const v of PUZZLES[b]) {
    await click(...v);
    await sleep(300);
  }
  await sleep(500);
  // the lock should now be open. Try to LEAVE by mouse: the step line says
  // "press ENTER to go through", but a player without a keyboard will click.
  for (const p of EXIT_TRIES) {
    await click(...p);
    await sleep(400);
    if (await beatNow() !== b) return true; // a mouse exit exists after all
  }
  // No click left the lock. Reading main.gd _click: the puzzle branch
  // toggles valves inside 30px and RETURNS for everything else, so the
  // "combat == null -> run.advance()" door is unreachable while a puzzle
  // is up. Prove the lock is actually solved (and the door is the only
  // problem) with the one ENTER the game asks for -- unless strict.
  if (STRICT) {
    finding(`${b}: a solved lock cannot be exited by mouse -- main.gd _click's puzzle branch only toggles valves and returns; only ENTER calls run.advance()`);
    firstStuck ??= { beat: b, reason: "a solved lock has no mouse exit; ENTER is the only way through (main.gd _click puzzle branch)" };
    return false;
  }
  console.log(`BYPASS   beat=${b} pressing ENTER once to probe/continue; the mouse-only claim is already being judged`);
  await page.keyboard.press("Enter");
  await sleep(1000);
  if (await beatNow() !== b) {
    // ENTER advanced, so the lock WAS solved by mouse clicks alone and
    // only the exit is keyboard-locked: that is the finding.
    finding(`${b}: the lock SOLVES by mouse (valves are clickable) but a solved lock cannot be EXITED by mouse -- main.gd _click's puzzle branch toggles valves inside 30px and returns for every other click, so run.advance() is only reachable via ENTER`);
    firstStuck ??= { beat: b, reason: "a solved lock has no mouse exit; ENTER is the only way through (main.gd _click puzzle branch)" };
    return true;
  }
  // ENTER did nothing either: the valves never solved it -- a driver or
  // geometry problem, not the door problem. Say which.
  firstStuck ??= { beat: b, reason: "valve clicks did not solve the lock (ENTER probe also refused), so the click geometry or order is wrong" };
  return false;
}

// ---- the ladder ---------------------------------------------------------
let beat = await beatNow();
if (beat !== "opening") await die(beat || "boot", `expected beat=opening at boot, title reports "${await page.title()}"`);

while (beat !== "ending") {
  lastBeat = beat;
  console.log(`MOUSERUN beat=${beat}`);
  let ok;
  if (FIGHTS[beat]) ok = await driveFight(beat);
  else if (PUZZLES[beat]) ok = await drivePuzzle(beat);
  else ok = await driveScene(beat);
  if (!ok) {
    const why = firstStuck && firstStuck.beat === beat ? firstStuck.reason
      : (FIGHTS[beat] ? "fight not won inside 40 mouse-driven turns"
        : "clicks did not advance the beat");
    await die(beat, why);
  }
  const next = await beatNow();
  if (ORDER.indexOf(next) < ORDER.indexOf(beat)) {
    // the ladder only moves forward; going backwards means the driver
    // misread where it is
    await die(next, `beat went backwards from ${beat}`);
  }
  // a won fight plays a 3.2s descent before the next board is live
  await sleep(FIGHTS[beat] ? 4000 : 1200);
  beat = next;
}

console.log("MOUSERUN beat=ending");
const secs = ((Date.now() - T0) / 1000).toFixed(0);
for (const e of errors.slice(0, 5)) console.log("PAGE ERROR  " + e);
if (firstStuck) {
  console.log(`MOUSERUN: reached the ending in ${secs}s, but NOT by mouse alone (${findings.length} finding(s), keyboard bypass used)`);
  console.log(`MOUSERUN: stuck at ${firstStuck.beat} (${firstStuck.reason})`);
  await browser.close(); stop(); process.exit(1);
}
console.log(`MOUSERUN: the run completes by mouse alone (${secs}s)`);
await browser.close(); stop(); process.exit(0);
