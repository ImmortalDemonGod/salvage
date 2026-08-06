// As-played capture against the WEB EXPORT, because headless Godot uses a
// dummy rasteriser and cannot render a frame. This is also the right
// instrument on principle: it drives the real build the team will click,
// with real KeyboardEvents through the real handlers, which is the lesson
// the last project paid for.
//
// Usage: node verify/capture.mjs <outdir> [keys]
//   keys are comma separated, "Key*N" repeats, e.g. Digit1,KeyQ,Space
import { readdirSync, existsSync, mkdirSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { spawn } from "node:child_process";

const outdir = process.argv[2] ?? "/tmp/salvage-shots";
const keySpec = process.argv[3] ?? "";
mkdirSync(outdir, { recursive: true });

async function loadChromium() {
  for (const spec of [process.env.PLAYWRIGHT_CORE, "playwright-core"].filter(Boolean)) {
    try { return (await import(spec)).chromium; } catch {}
  }
  throw new Error("playwright-core not resolvable; set PLAYWRIGHT_CORE");
}
function findShell() {
  if (process.env.CHROME_SHELL) return process.env.CHROME_SHELL;
  const roots = [join(homedir(), "Library/Caches/ms-playwright"), join(homedir(), ".cache/ms-playwright")].filter(existsSync);
  for (const root of roots) {
    const dirs = readdirSync(root).filter((d) => d.startsWith("chromium_headless_shell-"))
      .sort((a, b) => Number(b.split("-")[1]) - Number(a.split("-")[1]));
    for (const d of dirs) for (const rel of [
      "chrome-headless-shell-mac-arm64/chrome-headless-shell",
      "chrome-headless-shell-mac-x64/chrome-headless-shell",
      "chrome-headless-shell-linux/chrome-headless-shell"]) {
      const p = join(root, d, rel); if (existsSync(p)) return p;
    }
  }
}

const PORT = 8731;
const server = spawn("python3", ["-m", "http.server", String(PORT), "--bind", "127.0.0.1"],
  { cwd: join(homedir(), "salvage/export/web"), stdio: "ignore" });
const stop = () => { try { server.kill(); } catch {} };
process.on("exit", stop);

const chromium = await loadChromium();
const exe = findShell();
// chrome-headless-shell ships no WebGL2, and Godot's web export refuses to
// boot without it ("WebGL2 - Check web browser configuration and hardware
// support"). Software rasterisation via ANGLE/SwiftShader is what makes a
// headless capture possible at all. The last project was canvas2d, so this
// constraint is new to Godot.
const GL_ARGS = [
  "--use-gl=angle",
  "--use-angle=swiftshader",
  "--enable-unsafe-swiftshader",
  "--enable-webgl",
  "--ignore-gpu-blocklist",
];
const browser = await chromium.launch({ headless: true, args: GL_ARGS, ...(exe ? { executablePath: exe } : {}) });
const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
const errors = [];
page.on("pageerror", (e) => errors.push(String(e)));
page.on("console", (m) => { if (m.type() === "error") errors.push("console: " + m.text()); });

await page.goto(`http://127.0.0.1:${PORT}/index.html`, { waitUntil: "load" });
// the engine boots, compiles wasm, then paints. Wait for real pixels
// rather than a fixed sleep: MEASURE, never assert.
let booted = false;
for (let i = 0; i < 120 && !booted; i++) {
  await page.waitForTimeout(500);
  booted = await page.evaluate(() => {
    const c = document.querySelector("canvas");
    if (!c || !c.width) return false;
    const g = c.getContext("webgl2") || c.getContext("webgl");
    return !!g;
  });
}
if (!booted) { console.log("CAPTURE: engine never painted"); await browser.close(); stop(); process.exit(1); }
await page.waitForTimeout(2500);
await page.screenshot({ path: join(outdir, "00-boot.png") });

let shot = 1;
if (keySpec) {
  const keys = keySpec.split(",").flatMap((tok) => {
    const [k, n] = tok.split("*");
    return Array.from({ length: Number(n ?? 1) }, () => k);
  });
  // A 250-key replay does not need 250 screenshots; the caller wants the
  // state at the end. Shooting every frame made the gallery take minutes
  // per beat. CAPTURE_ALL=1 restores the full film when debugging a replay.
  const all = process.env.CAPTURE_ALL === "1";
  for (let i = 0; i < keys.length; i++) {
    const k = keys[i];
    await page.keyboard.down(k);
    await page.waitForTimeout(60);
    await page.keyboard.up(k);
    await page.waitForTimeout(all ? 320 : 90);
    if (all || i === keys.length - 1) {
      await page.waitForTimeout(all ? 0 : 400);
      await page.screenshot({ path: join(outdir, `${String(shot++).padStart(5, "0")}-${k}.png`) });
    }
  }
}

// where the replay ACTUALLY ended up, straight from the build
const title = await page.title();
console.log(`CAPTURE: ${shot} frame(s) to ${outdir}, ${errors.length} page error(s), title="${title}"`);
const want = process.argv[4];
if (want && !title.includes(`beat=${want}`)) {
  console.log(`FINDING  REPLAY LANDED WRONG: asked for beat=${want}, the build reports "${title}"`);
  await browser.close(); server.kill(); process.exit(3);
}
for (const e of errors.slice(0, 8)) console.log("PAGE ERROR  " + e);
await browser.close();
stop();
process.exit(errors.length ? 1 : 0);
