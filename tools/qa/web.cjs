'use strict';
// QA browser runner: drives the web export in the installed Chrome (real GPU, puppeteer-core) with
// real key and pointer events, reads the game's console (QA: lines from gameplay, QAPROBE: lines
// from the QA probe in tests/qa/), and checks one definition-of-done item per mode.
//
//   tools/qa/qa.sh web <mode> [options] [key=value ...]      (sets the environment this needs)
//
// Modes:
//   smoke    load a scene (scene=... or the main scene), click, hold, fail on any console error,
//            shader error, page error or failed request
//   input    WASD moves the player, a click captures the mouse and mouse motion orbits the camera,
//            Space jumps, J and the left button attack, Escape releases the mouse and pauses
//   brush    holding Shift freezes the world and shows the sepia view; a circle, a horizontal line
//            and a loop drawn with the mouse are recognised; ink drains; the world resumes
//   full     autoplay=1 reaches valley_restored and the end card; screenshots of each rendering
//            stack item are taken as the events happen
//   manual   no autoplay: title, start, walk to the thorn gate with WASD, cut it with a drawn slash
//   perf     frame rate in the valley at 1280x720 and 1920x1080, capped by vsync and uncapped
//   paper    the same valley view at Light, Normal and Heavy paper (cycled with the in-game key)
// Options:
//   --target RES     scene under test for the probe modes (default res://scenes/game/main.tscn)
//   --name NAME      evidence name suffix (default the mode)
//   --headed         visible browser window
//   --timeout S      overall limit for the mode (full default 600, others 150)
//   --size WxH       viewport (default 1280x720)
// Every mode prints QA_RESULT <PASS|FAIL|NOT_YET> <evidence> <detail> and exits 0 / 1 / 3.

const fs = require('fs');
const path = require('path');
const { spawn, spawnSync } = require('child_process');

const projectRoot = process.env.ORIMI_PROJECT_ROOT || path.resolve(__dirname, '..', '..');
const toolsDir = process.env.ORIMI_TOOLS_DIR;
if (!toolsDir) { console.error('run through tools/qa/qa.sh web ...'); process.exit(2); }
const puppeteer = require(path.join(toolsDir, 'node', 'node_modules', 'puppeteer-core'));
const PYTHON = process.env.ORIMI_PYTHON || 'python';
// Full-size captures and whole console logs stay under .userdata/qa/ (not committed); docs/ gets small
// JPEGs and short log extracts (the docs/qa budget is about 5 MB).
const FULL = path.join(projectRoot, '.userdata', 'qa', 'full');
const LOGS = path.join(projectRoot, '.userdata', 'qa', 'logs');
const fullOf = (file) => path.join(FULL, path.relative(projectRoot, file));
const EVIDENCE = path.join(projectRoot, 'docs', 'qa', 'evidence');
const HOST = 'res://tests/qa/qa_host.tscn';
const MAIN = 'res://scenes/game/main.tscn';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const rel = (p) => path.relative(projectRoot, p).split(path.sep).join('/');

function parseArgs(argv) {
  const o = { mode: argv[0], target: MAIN, headed: false, timeout: 0, size: [1280, 720], query: [], name: '' };
  for (let i = 1; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--target') o.target = argv[++i];
    else if (a === '--name') o.name = argv[++i];
    else if (a === '--headed') o.headed = true;
    else if (a === '--timeout') o.timeout = Number(argv[++i]);
    else if (a === '--size') o.size = argv[++i].split('x').map(Number);
    else if (a.includes('=')) o.query.push([a.slice(0, a.indexOf('=')), a.slice(a.indexOf('=') + 1)]);
    else { console.error('unknown argument ' + a); process.exit(2); }
  }
  o.name = o.name || o.mode;
  o.timeout = o.timeout || ({ full: 2000, level: 900, resume: 900 }[o.mode] || 150);
  return o;
}

function pathVariants(p) {
  const mixed = p.replace(/\\/g, '/').replace(/\/$/, '');
  const back = mixed.replace(/\//g, '\\');
  const out = [back.replace(/\\/g, '\\\\'), back, mixed];
  if (/^[A-Za-z]:/.test(mixed)) out.push('/' + mixed[0].toLowerCase() + mixed.slice(2));
  return out;
}
const pathRules = [...pathVariants(projectRoot).map((v) => [v, '<project>']), ...pathVariants(path.dirname(toolsDir)).map((v) => [v, '<tools-root>'])]
  .map(([v, tag]) => [new RegExp(v.replace(/[.*+?^$\{\}()|[\]\\]/g, '\\$&'), 'gi'), tag]);
const sanitize = (s) => pathRules.reduce((acc, [re, tag]) => acc.replace(re, tag), s);

function findChrome() {
  const c = [process.env.CHROME_PATH, 'C:/Program Files/Google/Chrome/Application/chrome.exe', 'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe',
    process.env.LOCALAPPDATA && path.join(process.env.LOCALAPPDATA, 'Google/Chrome/Application/chrome.exe')].filter(Boolean);
  const f = c.find((p) => fs.existsSync(p));
  if (!f) throw new Error('Chrome not found; set CHROME_PATH');
  return f;
}

function startServer(dir) {
  const proc = spawn(PYTHON, ['-I', path.join(projectRoot, 'tools', 'serve_web.py'), '--dir', dir, '--port', '0'], { stdio: ['ignore', 'pipe', 'pipe'] });
  return new Promise((resolve, reject) => {
    let buf = '';
    const timer = setTimeout(() => reject(new Error('server did not start')), 15000);
    proc.stdout.on('data', (d) => { buf += d; const m = buf.match(/SERVING (\S+)/); if (m) { clearTimeout(timer); resolve({ proc, url: m[1] }); } });
    proc.stderr.on('data', () => {});
    proc.on('exit', (code) => reject(new Error('server exited ' + code)));
  });
}

const ERROR_TEXT = /SHADER ERROR|SCRIPT ERROR|USER ERROR|Parse Error|(^|\s)ERROR:|Uncaught|Failed to compile|WebGL: INVALID|GL_INVALID/i;

class Session {
  constructor(opts) { this.opts = opts; this.lines = []; this.problems = []; this.probe = []; this.qa = []; this.t0 = Date.now(); this.firstFrame = null; }

  async open(query, { size = this.opts.size, extraArgs = [] } = {}) {
    const dir = path.join(projectRoot, 'build', 'web');
    if (!fs.existsSync(path.join(dir, 'index.html'))) throw new Error('no build/web/index.html (run tools/export_web.sh)');
    this.server = await startServer(dir);
    const profileRoot = path.join(projectRoot, '.userdata', 'chrome');
    fs.mkdirSync(profileRoot, { recursive: true });
    this.profile = fs.mkdtempSync(path.join(profileRoot, 'qa-'));
    this.browser = await puppeteer.launch({
      executablePath: findChrome(), headless: !this.opts.headed, userDataDir: this.profile,
      defaultViewport: { width: size[0], height: size[1] },
      args: ['--use-angle=d3d11', '--enable-gpu', '--ignore-gpu-blocklist', '--no-first-run', '--no-default-browser-check',
        '--window-size=' + (size[0] + 16) + ',' + (size[1] + 140), ...extraArgs],
    });
    this.chrome = await this.browser.version();
    const page = (this.page = await this.browser.newPage());
    page.on('console', (msg) => this.onLine(msg.type(), msg.text()));
    page.on('pageerror', (e) => { this.log('[pageerror] ' + e.message); this.problems.push('page error: ' + e.message); });
    page.on('requestfailed', (r) => {
      const why = (r.failure() && r.failure().errorText) || '';
      this.log('[requestfailed] ' + r.url() + ' ' + why);
      // A request the page itself cancelled (closing the tab, navigating away) is not a load failure.
      if (!/ERR_ABORTED/.test(why)) this.problems.push('request failed: ' + r.url() + ' ' + why);
    });
    page.on('response', (r) => { if (r.status() >= 400) this.problems.push('HTTP ' + r.status() + ' ' + r.url()); });
    const qs = new URLSearchParams(query).toString();
    this.url = this.server.url + 'index.html' + (qs ? '?' + qs : '');
    this.log('# url ' + this.url);
    this.log('# chrome ' + this.chrome + ' viewport ' + size.join('x') + ' ' + extraArgs.join(' '));
    try {
      await page.goto(this.url, { waitUntil: 'load' });
    } catch (e) {
      // The static server never answered (seen under heavy load on this machine): a harness fault,
      // not a game one. Retry once on a fresh server, and say so in the console log.
      this.log('# retry: first navigation failed (' + e.message + '); restarting the static server');
      this.problems = this.problems.filter((p) => !p.startsWith('request failed: ' + this.server.url));
      this.server.proc.kill();
      this.server = await startServer(dir);
      this.url = this.server.url + 'index.html' + (qs ? '?' + qs : '');
      this.log('# url ' + this.url);
      await page.goto(this.url, { waitUntil: 'load', timeout: 60000 });
    }
    await this.until(() => this.firstFrame, 90000, 'ORIMI_FIRST_FRAME');
    this.firstFrameMs = Date.now() - this.t0;
    this.webgl = await page.evaluate(() => {
      const gl = document.createElement('canvas').getContext('webgl2');
      if (!gl) return { webgl2: false };
      const d = gl.getExtension('WEBGL_debug_renderer_info');
      return { webgl2: true, renderer: d ? gl.getParameter(d.UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER) };
    });
    this.log('# webgl ' + JSON.stringify(this.webgl));
    if (!this.webgl.webgl2) this.problems.push('WebGL 2 unavailable');
    else if (/swiftshader|llvmpipe|software|basic render/i.test(this.webgl.renderer)) this.problems.push('software WebGL: ' + this.webgl.renderer);
  }

  log(s) { s = sanitize(s); this.lines.push(((Date.now() - this.t0) / 1000).toFixed(2).padStart(7) + ' ' + s); }

  onLine(type, text) {
    this.log('[' + type + '] ' + text);
    if (type === 'error' || ERROR_TEXT.test(text)) this.problems.push('console ' + type + ': ' + text.slice(0, 300));
    if (text.startsWith('ORIMI_FIRST_FRAME') && !this.firstFrame) this.firstFrame = text;
    if (text.startsWith('QAPROBE:')) { try { this.probe.push(JSON.parse(text.slice(8))); } catch (e) { this.problems.push('bad QAPROBE line'); } }
    if (text.startsWith('QA:')) { try { this.qa.push(JSON.parse(text.slice(3))); } catch (e) { this.problems.push('bad QA: line from the game: ' + text.slice(0, 120)); } }
  }

  async until(fn, ms, what) {
    const end = Date.now() + ms;
    while (Date.now() < end) { const v = fn(); if (v) return v; await sleep(50); }
    if (what) throw new Error('timed out waiting for ' + what);
    return null;
  }

  events(name) { return this.probe.filter((p) => p.tag === 'evt' && p.name === name); }
  lastSnap() { return [...this.probe].reverse().find((p) => p.tag === 'snap'); }

  async cmd(command, tag) {
    const n = this.probe.length;
    await this.page.evaluate((c) => window.orimiQA && window.orimiQA(c), command);
    return this.until(() => this.probe.slice(n).find((p) => p.tag === tag), 3000, 'probe ' + tag);
  }
  snap() { return this.cmd('snap', 'snap'); }

  async canvasScale(snap) {
    const w = await this.page.evaluate(() => { const c = document.querySelector('canvas'); return c ? c.clientWidth : window.innerWidth; });
    return w / snap.window[0];
  }
  async toCss(snap, p) {
    const [xx, xy, yx, yy, ox, oy] = snap.screen_xform;
    const s = await this.canvasScale(snap);
    return [(xx * p[0] + yx * p[1] + ox) * s, (xy * p[0] + yy * p[1] + oy) * s];
  }

  async shot(file, publish = true) {
    const full = fullOf(file);
    fs.mkdirSync(path.dirname(full), { recursive: true });
    await this.page.screenshot({ path: full });
    const r = rel(file);
    if (!publish) return rel(full);
    if (r.startsWith('docs/screenshots/')) { fs.mkdirSync(path.dirname(file), { recursive: true }); fs.copyFileSync(full, file); return r; }
    if (this.opts.name.startsWith('selftest')) return rel(full);
    const jpg = file.replace(/\.png$/, '.jpg');
    const stack = r.startsWith('docs/qa/stack/');
    spawnSync(PYTHON, ['-I', path.join(projectRoot, 'tools', 'qa', 'shrink.py'), full, jpg, stack ? '1280' : '960', stack ? '80' : '70']);
    return rel(jpg);
  }

  async rafFps(ms = 3000) {
    return this.page.evaluate((dur) => new Promise((resolve) => {
      const times = []; const start = performance.now();
      const tick = (t) => { times.push(t); if (t - start < dur) requestAnimationFrame(tick); else {
        const d = times.slice(1).map((v, i) => v - times[i]).sort((a, b) => a - b);
        resolve({ fps: Math.round((d.length * 1000) / (t - times[0])), p50_ms: +d[d.length >> 1].toFixed(2), p95_ms: +d[Math.floor(d.length * 0.95)].toFixed(2), frames: d.length });
      } };
      requestAnimationFrame(tick);
    }), ms);
  }

  async close() {
    if (this.browser) await this.browser.close().catch(() => {});
    if (this.server) this.server.proc.kill();
    this.browser = null; this.server = null;
    await sleep(300);
    if (this.profile) fs.rmSync(this.profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 });
  }
}

// ---------------------------------------------------------------- helpers shared by the probe modes

function bookLevels() {
  const reg = JSON.parse(fs.readFileSync(path.join(projectRoot, 'scenes', 'levels', 'levels.json'), 'utf8'));
  return (reg.levels || []).filter((l) => fs.existsSync(path.join(projectRoot, String(l.scene).replace(/^res:\/\//, '')))).map((l) => l.id);
}

async function openProbe(s, opts, extra = [], openOpts = {}) {
  await s.open([['scene', HOST], ['target', opts.target], ...extra, ...opts.query], openOpts);
  const ready = await s.until(() => s.probe.find((p) => p.tag === 'target' || p.tag === 'target_missing'), 20000);
  if (!ready) throw new Error('QA probe never reported (is tests/ in the export?)');
  if (ready.tag === 'target_missing') return { notYet: 'target scene ' + opts.target + ' does not exist yet' };
  await sleep(2500);
  return {};
}

async function startGame(s, crit) {
  let snap = await s.snap();
  const before = snap.game_state;
  // Title, then any intro card: press Enter (then Space, then click) until the state is playing.
  const tries = [['key', 'Enter'], ['key', 'Enter'], ['key', 'Space'], ['click'], ['key', 'Enter'], ['key', 'Space'], ['click'], ['key', 'Enter']];
  const seen = [before];
  for (const [kind, key] of tries) {
    if (snap.game_state === 'playing' && snap.player) break;
    if (kind === 'key') await s.page.keyboard.press(key); else await s.page.mouse.click(640, 400);
    await sleep(1500);
    snap = await s.snap();
    if (seen[seen.length - 1] !== snap.game_state) seen.push(snap.game_state);
  }
  await s.until(() => { const l = s.lastSnap(); return l && l.player && l.game_state === 'playing'; }, 15000);
  snap = await s.snap();
  crit('title -> playing with real input', snap.game_state === 'playing' && !!snap.player, 'states ' + seen.join(' > ') + (seen[seen.length - 1] !== snap.game_state ? ' > ' + snap.game_state : '') + ', player ' + JSON.stringify(snap.player));
  return snap;
}

async function capture(s, crit) {
  const vp = await s.page.viewport();
  await s.page.mouse.click(vp.width / 2, vp.height / 2);
  await sleep(500);
  const locked = await s.page.evaluate(() => document.pointerLockElement !== null);
  const snap = await s.snap();
  if (crit) crit('click captures the mouse', locked && snap.mouse_mode === 2, 'pointerLockElement ' + locked + ', Input.mouse_mode ' + snap.mouse_mode);
  return locked;
}

function gamePos(snap) {
  const g = snap.game || {};
  for (const k of Object.keys(g)) if (/pos/i.test(k) && Array.isArray(g[k]) && g[k].length === 3) return g[k];
  if (g.player && Array.isArray(g.player.position)) return g.player.position;
  return null;
}
const sub = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
const len2 = (v) => Math.hypot(v[0], v[2]);
function camAxes(yawDeg) {
  const y = (yawDeg * Math.PI) / 180;
  return { fwd: [-Math.sin(y), 0, -Math.cos(y)], right: [Math.cos(y), 0, -Math.sin(y)] };
}
const dot2 = (a, b) => a[0] * b[0] + a[2] * b[2];

async function holdKeys(s, keys, ms) {
  for (const k of keys) await s.page.keyboard.down(k);
  await sleep(ms);
  for (const k of keys) await s.page.keyboard.up(k);
}

function shapePoints(kind, cx, cy, r) {
  const pts = [];
  if (kind === 'circle') for (let i = 0; i <= 52; i++) { const a = -Math.PI / 2 + (i / 48) * Math.PI * 2; pts.push([cx + r * Math.cos(a), cy + r * Math.sin(a)]); }
  else if (kind === 'line') for (let i = 0; i <= 30; i++) pts.push([cx - r * 1.4 + (i / 30) * r * 2.8, cy + Math.sin(i * 0.7) * 2]);
  else if (kind === 'loop') {
    // One-loop prolate cycloid over a 2*pi span, the shape docs/BRUSH.md generates its gust templates from.
    const a = r * 0.4; const b = r * 0.8;
    for (let i = 0; i <= 64; i++) { const u = -Math.PI + (i / 64) * 2 * Math.PI; pts.push([cx + a * u - b * Math.sin(u), cy - b * Math.cos(u)]); }
  }
  return pts;
}

async function drawStroke(s, pts, stepMs = 12) {
  await s.page.mouse.move(pts[0][0], pts[0][1]);
  await s.page.mouse.down({ button: 'left' });
  for (const p of pts.slice(1)) { await s.page.mouse.move(p[0], p[1]); await sleep(stepMs); }
  await s.page.mouse.up({ button: 'left' });
}

function pyStats(args) {
  const r = spawnSync(PYTHON, ['-I', path.join(projectRoot, 'tools', 'qa', 'imgstats.py'), ...args], { encoding: 'utf-8' });
  try { return JSON.parse(r.stdout); } catch (e) { return { error: (r.stdout || '') + (r.stderr || '') }; }
}

// ---------------------------------------------------------------- modes

async function modeSmoke(s, o, crit, ev) {
  await s.open(o.query);
  crit('first frame', true, s.firstFrame + ' after ' + s.firstFrameMs + ' ms');
  await sleep(2500);
  await s.page.mouse.click(640, 400);
  await sleep(6000);
  ev.shots.push(await s.shot(path.join(EVIDENCE, 'web_' + o.name + '.png')));
  const fps = await s.rafFps(2000);
  crit('requestAnimationFrame rate', fps.fps >= 30, JSON.stringify(fps));
  const requested = (o.query.find(([k]) => k === 'scene') || [])[1];
  const loaded = (s.firstFrame.match(/scene=(\S+)/) || [])[1];
  if (!requested && loaded !== MAIN) ev.notYet = 'boot loaded ' + loaded + ', not ' + MAIN + ' (gameplay main scene not delivered)';
}

async function modeInput(s, o, crit, ev) {
  const r = await openProbe(s, o, [['god', '1']]);
  if (r.notYet) { ev.notYet = r.notYet; return; }
  await startGame(s, crit);
  await capture(s, crit);
  const dirs = { KeyW: ['fwd', 1], KeyS: ['fwd', -1], KeyA: ['right', -1], KeyD: ['right', 1] };
  let gameMoved = 0; let gameHasPos = false;
  for (const [key, [axis, sign]] of Object.entries(dirs)) {
    const a = await s.snap();
    await holdKeys(s, [key], 900);
    await sleep(300);
    const b = await s.snap();
    const d = sub(b.player, a.player);
    const along = dot2(d, camAxes(a.cam.yaw)[axis]) * sign;
    crit(key + ' moves the player ' + (sign > 0 ? '+' : '-') + axis, along > 0.5 && along > 0.7 * len2(d), 'moved ' + len2(d).toFixed(2) + ' m, ' + along.toFixed(2) + ' m along the camera ' + axis + ' axis');
    const ga = gamePos(a); const gb = gamePos(b);
    if (ga && gb) { gameHasPos = true; if (len2(sub(gb, ga)) > 0.5) gameMoved++; }
  }
  crit('Game.debug_snapshot() reports the player position and it changes', gameHasPos && gameMoved === 4,
    gameHasPos ? 'position changed in ' + gameMoved + ' of 4 moves' : 'no player position key in debug_snapshot: ' + JSON.stringify(s.lastSnap().game));
  const y0 = (await s.snap()).cam.yaw;
  for (let i = 1; i <= 20; i++) { await s.page.mouse.move(640 + i * 15, 400); await sleep(16); }
  await sleep(500);
  const y1 = (await s.snap()).cam.yaw;
  const dyaw = ((y1 - y0 + 540) % 360) - 180;
  crit('mouse motion orbits the camera', Math.abs(dyaw) > 5, 'yaw ' + y0.toFixed(1) + ' -> ' + y1.toFixed(1));
  const j0 = (await s.snap()).player[1];
  await s.page.keyboard.press('Space');
  let top = j0;
  for (let i = 0; i < 10; i++) { await sleep(70); top = Math.max(top, (await s.snap()).player[1]); }
  crit('Space jumps', top - j0 > 0.3, 'height ' + j0.toFixed(2) + ' -> peak ' + top.toFixed(2));
  await sleep(800);
  let n = s.events('player_attacked').length;
  await s.page.keyboard.press('KeyJ');
  const byKey = await s.until(() => s.events('player_attacked').length > n, 2000);
  n = s.events('player_attacked').length;
  await sleep(600);
  await s.page.mouse.down({ button: 'left' }); await sleep(60); await s.page.mouse.up({ button: 'left' });
  const byMouse = await s.until(() => s.events('player_attacked').length > n, 2000);
  crit('J and the left mouse button attack (Events.player_attacked)', !!byKey && !!byMouse, 'J ' + !!byKey + ', left button ' + !!byMouse);
  await s.page.keyboard.press('Escape');
  await sleep(800);
  const e = await s.snap();
  const lockedAfter = await s.page.evaluate(() => document.pointerLockElement !== null);
  crit('Escape (pause action) pauses and frees the mouse', !lockedAfter && e.mouse_mode !== 2 && (e.paused || e.game_state === 'paused'),
    'pointer lock ' + lockedAfter + ', mouse_mode ' + e.mouse_mode + ', tree paused ' + e.paused + ', state ' + e.game_state);
  // How a player gets back: each path must leave the game playing and captured 1.5 s later.
  const resumed = async () => { await sleep(1500); const x = await s.snap(); return { ok: x.game_state === 'playing' && !x.paused && x.mouse_mode === 2, x }; };
  const states = () => s.events('game_state_changed').map((v) => v.args[0]);
  for (const [label, act] of [['Escape again', () => s.page.keyboard.press('Escape')], ['P', () => s.page.keyboard.press('KeyP')], ['a click on Resume', () => clickButton(s, /resume/i)]]) {
    const n = states().length;
    let pre = await s.snap();
    if (!(pre.game_state === 'paused')) { await s.page.keyboard.press('KeyP'); await sleep(800); pre = await s.snap(); }
    if (pre.game_state !== 'paused') { crit('resume with ' + label, false, 'could not get into the paused state first (state ' + pre.game_state + ')'); continue; }
    await act();
    const r2 = await resumed();
    crit('resume with ' + label + ' (playing and captured 1.5 s later)', r2.ok, 'state changes ' + (states().slice(n).join(' > ') || 'none') + '; now state ' + r2.x.game_state + ', tree paused ' + r2.x.paused + ', mouse_mode ' + r2.x.mouse_mode);
    if (!r2.ok) await sleep(400);
  }
  // Chrome's own Escape handling cannot be synthesised, so a capture lost to the browser is simulated
  // with document.exitPointerLock(); the contract says a lost capture is treated as a pause.
  let pre = await s.snap();
  for (let i = 0; i < 3 && !(pre.game_state === 'playing' && pre.mouse_mode === 2 && !pre.paused); i++) {
    if (pre.game_state === 'paused') await clickButton(s, /resume/i); else await capture(s, null);
    await sleep(1500);
    pre = await s.snap();
  }
  if (!(pre.game_state === 'playing' && pre.mouse_mode === 2 && !pre.paused)) {
    crit('a capture lost to the browser is treated as a pause', false, 'could not reach playing + captured first: state ' + pre.game_state + ', mouse_mode ' + pre.mouse_mode);
    return;
  }
  await s.page.evaluate(() => document.exitPointerLock());
  await sleep(800);
  const lost = await s.snap();
  crit('a capture lost to the browser is treated as a pause', lost.paused || lost.game_state === 'paused',
    'after exitPointerLock: mouse_mode ' + lost.mouse_mode + ', tree paused ' + lost.paused + ', state ' + lost.game_state);
}

async function clickButton(s, re) {
  const items = (await s.cmd('controls', 'controls')).items;
  const b = items.find((i) => re.test(i.text));
  const snap = await s.snap();
  if (!b) { await s.page.mouse.click(640, 400); return; }
  const c = await s.toCss(snap, [b.rect[0] + b.rect[2] / 2, b.rect[1] + b.rect[3] / 2]);
  await s.page.mouse.click(c[0], c[1]);
}

async function modeBrush(s, o, crit, ev) {
  const r = await openProbe(s, o, [['god', '1']]);
  if (r.notYet) { ev.notYet = r.notYet; return; }
  await startGame(s, crit);
  await capture(s, null);
  await sleep(800);
  const vp = await s.page.viewport();
  const files = { before: path.join(EVIDENCE, 'web_brush_before.png'), during: path.join(EVIDENCE, 'web_brush_during.png'), after: path.join(EVIDENCE, 'web_brush_after.png') };
  ev.shots.push(await s.shot(files.before));
  const ink0 = (await s.snap()).ink;
  const fixture = o.target.includes('tests/fixtures/');
  const expect = { circle: 'bloom', line: 'slash', loop: 'gust' };
  let openOk = 0; let resumeOk = 0; let apiOk = 0; let mouseBack = 0;
  for (const [shape, glyph] of Object.entries(expect)) {
    const nOpen = s.events('brush_opened').length; const nCast = s.events('glyph_cast').length; const nFail = s.events('glyph_failed').length;
    await s.page.keyboard.down('ShiftLeft');
    await sleep(700);
    const during = await s.snap();
    const opened = s.events('brush_opened').length > nOpen && during.paused;
    if (opened) openOk++;
    if (during.brush_open) apiOk++;
    if (shape === 'circle') ev.shots.push(await s.shot(files.during));
    await drawStroke(s, shapePoints(shape, vp.width / 2, vp.height * 0.55, Math.min(vp.width, vp.height) * 0.16));
    await sleep(150);
    await s.page.keyboard.up('ShiftLeft');
    await s.until(() => s.events('glyph_cast').length > nCast || s.events('glyph_failed').length > nFail, 3000);
    await sleep(700);
    const cast = s.events('glyph_cast').slice(nCast);
    const failed = s.events('glyph_failed').slice(nFail);
    const got = cast.map((c) => c.args[0]);
    if (!got.includes(glyph)) { const br = await s.cmd('brush_result', 'brush_result').catch(() => null); ev.brushResults = ev.brushResults || {}; ev.brushResults[shape] = br && br.result; }
    crit('a ' + shape + ' is recognised as ' + glyph, got.includes(glyph), cast.length ? 'glyph_cast ' + got.join(',') + ' score ' + ((cast[0].args[1] || {}).score) : failed.length ? 'glyph_failed ' + JSON.stringify(failed[0].args[0].reason) : 'no glyph event');
    const after = await s.snap();
    if (!after.paused && s.events('brush_closed').length >= nOpen + 1) resumeOk++;
    if (after.mouse_mode === 2) mouseBack++;
    await sleep(400);
  }
  crit('holding Shift opens the brush and freezes the world', openOk === 3, openOk + ' of 3 holds emitted brush_opened with the tree paused');
  if (!fixture) crit('Brush.is_open() is true while held', apiOk === 3, apiOk + ' of 3');
  crit('releasing resumes the world (brush_closed, tree unpaused)', resumeOk === 3, resumeOk + ' of 3');
  crit('the captured mouse comes back after the brush closes', mouseBack === 3, mouseBack + ' of 3');
  await sleep(800);
  ev.shots.push(await s.shot(files.after));
  const inkEvents = s.events('ink_changed').map((e) => e.args[0]);
  const ink1 = (await s.snap()).ink;
  crit('ink drains when casting', ink1 < ink0 || inkEvents.some((v) => v < ink0), 'Brush.ink ' + ink0 + ' -> ' + ink1 + '; ink_changed ' + inkEvents.slice(0, 8).join(', '));
  const st = pyStats(['sepia', fullOf(files.before), fullOf(files.during), fullOf(files.after)]);
  ev.stats = st;
  crit('sepia view while open (before / during / after screenshots)', st.pass === true, st.error || st.summary);
}

async function modeFull(s, o, crit, ev) {
  const shots = {};
  const real = o.target === MAIN;
  const stackDir = real ? path.join(projectRoot, 'docs', 'qa', 'stack') : EVIDENCE;
  const prefix = real ? 'web_' : 'web_' + o.name + '_';
  const old = new RegExp('^' + prefix + '[0-9]{2}_.*\\.(png|jpg)$');
  if (fs.existsSync(stackDir)) for (const f of fs.readdirSync(stackDir)) if (old.test(f)) fs.rmSync(path.join(stackDir, f));
  if (real) { fs.mkdirSync(LOGS, { recursive: true }); fs.writeFileSync(path.join(LOGS, 'web_full_started'), new Date().toISOString() + '\n'); }
  const r = await openProbe(s, o, [['autoplay', '1']]);
  if (r.notYet) { ev.notYet = r.notYet; return; }
  const t0 = Date.now();
  const want = [
    ['zone_entered', 1000, 'cursed_zone_before'], ['enemy_died', 150, 'enemy_ink_death'], ['glyph_cast', 60, 'glyph_first_cast'],
    ['thorns_cut', 100, 'slash_on_thorns'], ['zone_restore_started', 700, 'zone_restoring'], ['zone_restored', 600, 'zone_restored'],
    ['soot_cleared', 300, 'gust_on_soot'], ['finale_started', 2500, 'finale'], ['valley_restored', 1500, 'valley_restored']];
  const done = new Set();
  let shotN = 0;
  const deadline = t0 + o.timeout * 1000;
  let ended = null;
  const shoot = async (label) => { shots[label] = await s.shot(path.join(stackDir, prefix + String(++shotN).padStart(2, '0') + '_' + label + '.png')); };
  while (Date.now() < deadline) {
    for (const [evt, delay, label] of want) {
      if (!done.has(label) && s.events(evt).length) { done.add(label); await sleep(delay); await shoot(label); }
    }
    if (!done.has('slash') && s.events('glyph_cast').some((e) => e.args[0] === 'slash')) { done.add('slash'); await sleep(80); await shoot('slash_trail'); }
    ended = s.events('game_state_changed').find((e) => e.args[0] === 'ended');
    if (ended && s.events('valley_restored').length) { await sleep(1500); await shoot('end_card'); break; }
    if (!done.has('periodic') && Date.now() - t0 > 20000) { done.add('periodic'); await shoot('playing_20s'); }
    await sleep(100);
  }
  const secs = (Date.now() - t0) / 1000;
  ev.shots.push(...Object.values(shots));
  const kinds = new Set(s.events('enemy_died').map((e) => e.args[1]));
  const zones = new Set(s.events('zone_restored').map((e) => e.args[0]));
  const glyphs = new Set(s.events('glyph_cast').map((e) => e.args[0]));
  crit('valley_restored reached', s.events('valley_restored').length > 0, s.events('valley_restored').length ? 'after ' + secs.toFixed(0) + ' s' : 'not within ' + o.timeout + ' s');
  crit('end card (game state ended)', !!ended, ended ? 'ended' : 'states seen: ' + s.events('game_state_changed').map((e) => e.args[0]).join(' > '));
  crit('both enemy types killed', kinds.has('splotchet') && kinds.has('reedwraith'), 'enemy_died kinds: ' + [...kinds].join(', ') + ' (' + s.events('enemy_died').length + ' deaths)');
  crit('both zones restored', zones.has('zone_a') && zones.has('zone_b'), 'zone_restored: ' + [...zones].join(', '));
  crit('finale started', s.events('finale_started').length > 0, s.events('finale_started').length + ' finale_started');
  crit('each glyph cast at least once', ['bloom', 'slash', 'gust'].every((g) => glyphs.has(g)), 'glyph_cast: ' + s.events('glyph_cast').map((e) => e.args[0]).join(','));
  await s.until(() => s.qa.find((q) => q.tag === 'autoplay_end'), 10000);
  const book = bookLevels();
  const completed = new Set(s.qa.filter((q) => q.tag === 'level_complete').map((q) => q.data && q.data.level));
  crit('every book level completes (' + book.join(', ') + ')', book.length > 0 && book.every((id) => completed.has(id)), 'level_complete: ' + ([...completed].join(', ') || 'none'));
  const beadsFor = s.qa.filter((q) => q.tag === 'bead').map((q) => q.data && q.data.level);
  crit('a bead for every book level', book.every((id) => beadsFor.includes(id)), 'bead: ' + (beadsFor.join(', ') || 'none'));
  const apEnd = s.qa.find((q) => q.tag === 'autoplay_end');
  crit('book autoplay passed (no failed step)', !!(apEnd && apEnd.data && apEnd.data.passed === true), apEnd ? 'failures: ' + JSON.stringify(apEnd.data.failures || []).slice(0, 300) + ', ' + (apEnd.data.stages || []).length + ' stages' : 'no autoplay_end');
  crit('inside the time limit', secs < o.timeout, secs.toFixed(0) + ' s of ' + o.timeout);
  const tags = [...new Set(s.qa.map((q) => q.tag))];
  crit('gameplay prints QA: lines', s.qa.length > 0, s.qa.length + ' lines, tags: ' + tags.join(', '));
}

async function modeLevel(s, o, crit, ev) {
  const id = (o.query.find(([k]) => k === 'level') || [])[1];
  if (!id) throw new Error('level mode needs level=<id>');
  const r = await openProbe(s, o, [['autoplay', '1']]);
  if (r.notYet) { ev.notYet = r.notYet; return; }
  const t0 = Date.now();
  const qa = (tag) => s.qa.filter((q) => q.tag === tag);
  const shotFor = new Set();
  let end = null;
  while (Date.now() < t0 + o.timeout * 1000 && !(end = qa('autoplay_end')[0])) {
    for (const st of qa('stage')) {
      const name = String((st.data && (st.data.name || st.data.stage)) || '').replace(/[^a-z0-9_]+/gi, '_');
      if (name && !shotFor.has(name) && shotFor.size < 12) { ev.shots.push(await s.shot(path.join(EVIDENCE, 'web_' + o.name + '_' + name + '.png'), shotFor.size % 3 === 0)); shotFor.add(name); }
    }
    await sleep(250);
  }
  const secs = ((Date.now() - t0) / 1000).toFixed(0);
  await sleep(1000);
  ev.shots.push(await s.shot(path.join(EVIDENCE, 'web_' + o.name + '_end.png')));
  const fails = qa('autoplay_fail').map((q) => q.data && q.data.what);
  crit('autoplay reaches its end', !!end, end ? 'after ' + secs + ' s' : 'no autoplay_end within ' + o.timeout + ' s');
  crit('autoplay passed (no failed step)', end && end.data && end.data.passed === true && !fails.length,
    end ? 'passed ' + (end.data && end.data.passed) + '; failures: ' + JSON.stringify((end.data && end.data.failures) || fails).slice(0, 400) : 'failures so far: ' + JSON.stringify(fails).slice(0, 400));
  crit('level ' + id + ' completes (level_complete)', qa('level_complete').some((q) => q.data && q.data.level === id),
    'level_complete: ' + (qa('level_complete').map((q) => q.data && q.data.level).join(', ') || 'none'));
  if (end && end.data) ev.stats = { levels: end.data.levels, stages: end.data.stages, duration: end.data.duration, simulated_casts: end.data.simulated_casts };
}

async function modeResume(s, o, crit, ev) {
  const book = bookLevels();
  const first = (o.query.find(([k]) => k === 'after') || [])[1] || book[0];
  const second = book[book.indexOf(first) + 1];
  if (!second) { ev.notYet = 'no book level after ' + first; return; }
  const r = await openProbe(s, o, [['autoplay', '1'], ['level', first]]);
  if (r.notYet) { ev.notYet = r.notYet; return; }
  const before = book.slice(0, book.indexOf(first));
  if (before.length) {
    const seeded = await s.cmd('completed:' + before.join(','), 'completed_set');
    s.log('# earlier book levels marked completed, as after a play from the start: ' + JSON.stringify(seeded.completed));
  }
  const saved = await s.until(() => s.qa.find((q) => q.tag === 'progress_saved' && q.data && (q.data.completed || []).includes(first)), o.timeout * 1000);
  crit(first + ' played through and progress saved', !!saved, saved ? 'progress_saved ' + JSON.stringify(saved.data).slice(0, 200) : 'no progress_saved listing ' + first + ' within ' + o.timeout + ' s');
  if (!saved) return;
  // Godot syncs user:// to IndexedDB asynchronously after a file closes; give it time, then record
  // what the browser holds so a failed reload can be told apart from a sync that never happened.
  await sleep(6000);
  const idb = await s.page.evaluate(async () => {
    const out = {};
    for (const d of (indexedDB.databases ? await indexedDB.databases() : [])) {
      out[d.name] = await new Promise((res) => {
        const rq = indexedDB.open(d.name);
        rq.onerror = () => res('open failed');
        rq.onsuccess = () => {
          const db = rq.result; const keys = [];
          const stores = [...db.objectStoreNames];
          if (!stores.length) { db.close(); res([]); return; }
          const tx = db.transaction(stores, 'readonly');
          for (const st of stores) { const c = tx.objectStore(st).getAllKeys(); c.onsuccess = () => keys.push(...c.result.map(String).filter((k) => /progress|userfs|user/.test(k))); }
          tx.oncomplete = () => { db.close(); res(keys.slice(0, 20)); };
        };
      });
    }
    return out;
  }).catch((e) => ({ error: String(e) }));
  s.log('# indexeddb before reload: ' + JSON.stringify(idb));
  ev.stats = { indexeddb_before_reload: idb };
  const nQa = s.qa.length;
  s.firstFrame = null;
  s.url = s.server.url + 'index.html?' + new URLSearchParams([['scene', HOST], ['target', o.target]]).toString();
  s.log('# reload without autoplay or level: ' + s.url);
  await s.page.goto(s.url, { waitUntil: 'load' });
  await s.until(() => s.firstFrame, 90000, 'ORIMI_FIRST_FRAME after the reload');
  const loaded = await s.until(() => s.qa.slice(nQa).find((q) => q.tag === 'progress_loaded'), 30000);
  crit('saved progress loads after a page reload', !!(loaded && (loaded.data.completed || []).includes(first)), loaded ? 'progress_loaded ' + JSON.stringify(loaded.data).slice(0, 200) : 'no progress_loaded');
  const title = await s.until(() => s.qa.slice(nQa).find((q) => q.tag === 'title_ready'), 90000);
  crit('the title shows ' + second + ' behind it', !!(title && title.data.level === second), title ? 'title_ready level ' + title.data.level : 'no title_ready');
  await sleep(1500);
  const items = (await s.cmd('controls', 'controls')).items;
  const cont = items.find((i) => /^continue$/i.test(i.text.trim()));
  crit('the title offers Continue', !!cont, 'buttons: ' + items.map((i) => i.text).join(', '));
  ev.shots.push(await s.shot(path.join(EVIDENCE, 'web_' + o.name + '_title.png')));
  if (!cont) return;
  const snap0 = await s.snap();
  const c = await s.toCss(snap0, [cont.rect[0] + cont.rect[2] / 2, cont.rect[1] + cont.rect[3] / 2]);
  await s.page.mouse.click(c[0], c[1]);
  await sleep(1500);
  const snap = await startGame(s, () => {});
  const g = snap.game || {};
  crit('Continue starts ' + second, g.level === second, 'level ' + g.level + ', state ' + snap.game_state);
  crit('Continue keeps the ' + (before.length + 1) + ' beads earned up to ' + first, g.beads === before.length + 1, 'beads ' + g.beads + ', ink_max ' + g.ink_max);
  ev.shots.push(await s.shot(path.join(EVIDENCE, 'web_' + o.name + '_continued.png')));
}

async function modeManual(s, o, crit, ev) {
  const r = await openProbe(s, o, [['god', '1']]);
  if (r.notYet) { ev.notYet = r.notYet; return; }
  await startGame(s, crit);
  await capture(s, crit);
  const targets = (await s.cmd('targets', 'targets')).items;
  const gateT = targets.find((t) => /thorn|gate/i.test(t.name) && t.groups.includes('brush_target'));
  const gate = gateT ? gateT.pos : [-4, 0, 36];
  ev.gate = gateT ? gateT.name : 'contract coordinate (no thorn/gate brush_target found)';
  const stand = [gate[0], 0, gate[2] + 6];
  let snap = await s.snap();
  const t0 = Date.now();
  let best = len2(sub(snap.player, stand)); let lastBest = Date.now();
  while (Date.now() - t0 < 60000) {
    snap = await s.snap();
    const to = sub(stand, snap.player);
    const dist = len2(to);
    if (dist < 1.5) break;
    if (dist < best - 0.3) { best = dist; lastBest = Date.now(); }
    const ax = camAxes(snap.cam.yaw);
    const f = dot2(to, ax.fwd) / dist; const rr = dot2(to, ax.right) / dist;
    const keys = [];
    if (f > 0.35) keys.push('KeyW'); else if (f < -0.35) keys.push('KeyS');
    if (rr > 0.35) keys.push('KeyD'); else if (rr < -0.35) keys.push('KeyA');
    if (Date.now() - lastBest > 4000) { await s.page.keyboard.press('Space'); lastBest = Date.now(); }
    await holdKeys(s, keys, Math.min(400, 80 + dist * 40));
  }
  snap = await s.snap();
  const dist = len2(sub(snap.player, stand));
  crit('walked to the thorn gate with WASD', dist < 2.5, 'ended ' + dist.toFixed(1) + ' m from the stand point south of ' + ev.gate + ' after ' + ((Date.now() - t0) / 1000).toFixed(0) + ' s');
  const vp = await s.page.viewport();
  for (let i = 0; i < 30; i++) {
    snap = await s.snap();
    const want = sub(gate, snap.player);
    const yawWant = (Math.atan2(-want[0], -want[2]) * 180) / Math.PI;
    const d = ((yawWant - snap.cam.yaw + 540) % 360) - 180;
    if (Math.abs(d) < 8) break;
    await s.page.mouse.move(vp.width / 2 + (d > 0 ? -12 : 12), vp.height / 2, { steps: 2 });
    await sleep(40);
  }
  await sleep(600);
  const items = (await s.cmd('targets', 'targets')).items;
  const g = items.find((t) => (gateT ? t.name === gateT.name : /thorn|gate/i.test(t.name)));
  snap = await s.snap();
  if (!g || !g.in_front) { crit('thorn gate on screen', false, g ? 'behind the camera' : 'no thorn gate among brush targets'); return; }
  const c = await s.toCss(snap, g.screen);
  const onScreen = c[0] > 0 && c[1] > 0 && c[0] < vp.width && c[1] < vp.height;
  crit('thorn gate on screen', onScreen, 'gate anchor at css ' + c.map((v) => v.toFixed(0)).join(',') + ', ' + (g.distance || 0).toFixed(1) + ' m away');
  ev.shots.push(await s.shot(path.join(EVIDENCE, 'web_manual_at_gate.png')));
  const nCast = s.events('glyph_cast').length; const nCut = s.events('thorns_cut').length; const nClosed = s.events('brush_closed').length;
  await s.page.keyboard.down('ShiftLeft');
  await sleep(700);
  await drawStroke(s, shapePoints('line', c[0], c[1], 120));
  await sleep(150);
  await s.page.keyboard.up('ShiftLeft');
  // Targets hear on_glyph (thorns_cut) before glyph_cast is emitted; brush_closed comes last.
  await s.until(() => s.events('brush_closed').length > nClosed, 5000);
  await sleep(300);
  const cast = s.events('glyph_cast').slice(nCast).map((e) => e.args[0]);
  crit('a drawn horizontal line is recognised as slash', cast.includes('slash'), 'glyph_cast: ' + (cast.join(',') || 'none') + '; glyph_failed: ' + s.events('glyph_failed').length);
  crit('the slash cuts the thorn gate (Events.thorns_cut)', s.events('thorns_cut').length > nCut, s.events('thorns_cut').length - nCut + ' thorns_cut');
  await sleep(800);
  ev.shots.push(await s.shot(path.join(EVIDENCE, 'web_manual_after_cut.png')));
}

async function measure(s, label, size) {
  await s.page.setViewport({ width: size[0], height: size[1] });
  await sleep(2500);
  await s.page.evaluate(() => window.orimiQA && window.orimiQA('perf_reset'));
  await s.page.keyboard.down('ArrowLeft');
  const raf = await s.rafFps(6000);
  await s.page.keyboard.up('ArrowLeft');
  const perf = await s.cmd('perf', 'perf');
  const r2 = (v) => +Number(v).toFixed(2);
  return { label, size: size.join('x'), raf, godot: { fps: perf.fps, mean_ms: r2(perf.mean_ms), p95_ms: r2(perf.p95_ms), p99_ms: r2(perf.p99_ms), max_ms: r2(perf.max_ms), process_ms: r2(perf.process_ms), render_cpu_ms: r2(perf.render_cpu_ms), render_gpu_ms: r2(perf.render_gpu_ms), draw_calls: perf.draw_calls, primitives: perf.primitives, viewport: perf.viewport, window: perf.window } };
}

async function modePerf(s, o, crit, ev) {
  const warp = o.query.some(([k]) => k === 'warp') ? [] : [['warp', 'M_ZoneA']];
  const r = await openProbe(s, o, [['god', '1'], ...warp]);
  if (r.notYet) { ev.notYet = r.notYet; return; }
  await startGame(s, () => {});
  const kindle = o.query.some(([k, v]) => k === 'kindle' && v === '1');
  const walk = Number((o.query.find(([k]) => k === 'walk') || [])[1] || 0);
  const expectQa = (o.query.find(([k]) => k === 'expect_qa') || [])[1];
  const walkIn = async (ss) => { if (walk > 0) { await ss.page.keyboard.down('KeyW'); await sleep(walk * 1000); await ss.page.keyboard.up('KeyW'); await sleep(1500); } };
  await walkIn(s);
  if (expectQa) {
    const seen = await s.until(() => s.qa.find((q) => q.tag === expectQa), 15000);
    crit('measured during ' + expectQa + ' (the fight is running)', !!seen, seen ? expectQa + ' ' + JSON.stringify(seen.data).slice(0, 120) : 'no ' + expectQa + ' within 15 s of walking in');
    ev.shots.push(await s.shot(path.join(EVIDENCE, 'web_' + o.name + '_fight.png')));
  }
  if (kindle) {
    const k = await s.cmd('kindle_all', 'kindled_all');
    crit('every lamp lit before measuring (kindle_all)', k.total > 0 && k.lit === k.total, k.lit + ' of ' + k.total + ' kindle targets lit');
    await sleep(1500);
    ev.shots.push(await s.shot(path.join(EVIDENCE, 'web_' + o.name + '_lit.png')));
  }
  ev.perf = [];
  for (const size of [[1280, 720], [1920, 1080]]) ev.perf.push(await measure(s, 'vsync', size));
  await s.close();
  const s2 = new Session(o);
  s2.t0 = s.t0;
  try {
    await openProbe(s2, o, [['god', '1'], ...warp], { extraArgs: ['--disable-frame-rate-limit', '--disable-gpu-vsync'] });
    await startGame(s2, () => {});
    if (kindle) { await s2.cmd('kindle_all', 'kindled_all'); await sleep(1500); }
    await walkIn(s2);
    for (const size of [[1280, 720], [1920, 1080]]) ev.perf.push(await measure(s2, 'uncapped', size));
  } finally {
    s.lines.push(...s2.lines); s.problems.push(...s2.problems);
    await s2.close();
  }
  const p720 = ev.perf.find((p) => p.label === 'vsync' && p.size === '1280x720');
  crit('playable at 1280x720 (rAF >= 30 fps, p95 frame <= 50 ms)', p720.raf.fps >= 30 && p720.raf.p95_ms <= 50, JSON.stringify(p720.raf));
  for (const p of ev.perf) crit('measured ' + p.label + ' ' + p.size + ' (info)', true, 'rAF ' + JSON.stringify(p.raf) + ' godot ' + JSON.stringify(p.godot));
}

async function modePaper(s, o, crit, ev) {
  const r = await openProbe(s, o, [['god', '1'], ['paper', 'light'], ...(o.query.some(([k]) => k === 'warp') ? [] : [['warp', 'M_Spawn']])]);
  if (r.notYet) { ev.notYet = r.notYet; return; }
  await startGame(s, () => {});
  await sleep(3000);
  const boot = (await s.snap()).paper;
  crit('boot option paper=light honoured (info; finding F-001)', true, 'Settings.paper_intensity ' + boot + ' at start' + (boot === 0 ? '' : ' (ignored: Settings reads Boot.opt before Boot parses options)'));
  for (let i = 0; i < 3 && (await s.snap()).paper !== 0; i++) { await s.page.keyboard.press('KeyO'); await sleep(500); }
  const real = o.target === MAIN;
  const dir = real ? path.join(projectRoot, 'docs', 'screenshots') : EVIDENCE;
  const files = [];
  const names = ['light', 'normal', 'heavy'];
  for (let i = 0; i < 3; i++) {
    if (i > 0) await s.page.keyboard.press('KeyO');
    await sleep(1200);
    const snap = await s.snap();
    crit('paper ' + names[i] + ' selected in game (O key)', snap.paper === i, 'Settings.paper_intensity ' + snap.paper);
    const f = path.join(dir, (real ? 'valley_' : 'web_' + o.name + '_') + names[i] + (real ? '_web' : '') + '.png');
    ev.shots.push(await s.shot(f));
    files.push(f);
  }
  const st = pyStats(['paper', ...files.map(fullOf)]);
  ev.stats = st;
  crit('Light, Normal, Heavy differ in the expected direction', st.pass === true, st.error || st.summary);
}

const MODES = { smoke: modeSmoke, input: modeInput, brush: modeBrush, full: modeFull, level: modeLevel, resume: modeResume, manual: modeManual, perf: modePerf, paper: modePaper };

async function main() {
  const o = parseArgs(process.argv.slice(2));
  const fn = MODES[o.mode];
  if (!fn) { console.error('mode must be one of ' + Object.keys(MODES).join(', ')); process.exit(2); }
  const s = new Session(o);
  const criteria = [];
  const crit = (name, ok, detail) => { criteria.push({ name, ok: !!ok, detail }); console.log((ok ? 'ok    ' : 'FAIL  ') + name + ': ' + detail); };
  const ev = { shots: [] };
  let fatal = null;
  let finished = false;
  const overall = setTimeout(() => { fatal = 'mode exceeded ' + (o.timeout + 120) + ' s'; s.close().finally(() => finish()); }, (o.timeout + 120) * 1000);
  try { await fn(s, o, crit, ev); } catch (e) { fatal = String(e && e.message ? e.message : e); }
  clearTimeout(overall);
  await s.close();
  finish();

  function finish() {
    if (finished) return;
    finished = true;
    for (const p of [...new Set(s.problems)]) criteria.push({ name: 'no console/page errors', ok: false, detail: p });
    if (!s.problems.length && s.firstFrame) criteria.push({ name: 'no console/page errors', ok: true, detail: s.lines.length + ' console lines' });
    let status = 'PASS';
    if (fatal) criteria.push({ name: 'run completed', ok: false, detail: fatal });
    if (criteria.some((c) => !c.ok)) status = 'FAIL';
    if (ev.notYet && !s.problems.length && !fatal) status = 'NOT_YET';
    const name = 'web_' + o.name;
    const consoleFile = path.join(EVIDENCE, name + '_console.txt');
    const fullLog = path.join(LOGS, name + '_console.txt');
    fs.mkdirSync(EVIDENCE, { recursive: true });
    fs.mkdirSync(LOGS, { recursive: true });
    fs.writeFileSync(fullLog, s.lines.join('\n') + '\n');
    const marker = /\[requestfailed\]|\[pageerror\]|# retry|# url|# reload|autoplay_fail|autoplay_end|progress_|indexeddb/i;
    const keyLines = s.lines.filter((l) => marker.test(l) || ERROR_TEXT.test(l)).slice(0, 40);
    const short = ['# ' + s.lines.length + ' console lines. Marker and problem lines first, then the last 40 lines.',
      '# Full log (not committed): ' + rel(fullLog), ...keyLines, '# ...', ...s.lines.slice(-40)];
    fs.writeFileSync(consoleFile, sanitize(short.map((l) => (l.length > 300 ? l.slice(0, 300) + ' [cut]' : l)).join('\n')) + '\n');
    const report = [
      '# Browser check: ' + o.mode + ' (' + status + ')', '', 'url query: ' + (s.url ? s.url.replace(/^[^?]*\??/, '') : '-'),
      'chrome: ' + (s.chrome || '-') + '; webgl: ' + JSON.stringify(s.webgl || {}), 'first frame: ' + (s.firstFrame || '-') + (s.firstFrameMs ? ' (' + s.firstFrameMs + ' ms)' : ''),
      ev.notYet ? 'NOT YET: ' + ev.notYet : '', '', '| result | criterion | detail |', '| - | - | - |',
      ...criteria.map((c) => '| ' + (c.ok ? 'ok' : 'FAIL') + ' | ' + c.name + ' | ' + String(c.detail).replace(/\|/g, '/').replace(/\n/g, ' ') + ' |'),
      '', 'screenshots: ' + (ev.shots.join(', ') || 'none'), 'console log: ' + rel(consoleFile)];
    if (ev.perf) report.push('', '```', JSON.stringify(ev.perf, null, 1), '```');
    if (ev.brushResults) report.push('', 'Brush.last_result for strokes not recognised as expected:', '```', JSON.stringify(ev.brushResults, null, 1).slice(0, 6000), '```');
    if (ev.stats) report.push('', 'image statistics:', '```', JSON.stringify(ev.stats, null, 1), '```');
    const evFile = path.join(EVIDENCE, name + '.md');
    fs.writeFileSync(evFile, sanitize(report.join('\n')) + '\n');
    const failing = criteria.filter((c) => !c.ok);
    const detail = status === 'NOT_YET' ? ev.notYet : failing.length ? failing.length + ' failing; first: ' + failing[0].name + ': ' + failing[0].detail : criteria.length + ' criteria ok';
    console.log('QA_RESULT ' + status + ' ' + rel(evFile) + ' ' + String(detail).replace(/\s+/g, ' ').slice(0, 400));
    process.exit({ PASS: 0, FAIL: 1, NOT_YET: 3 }[status]);
  }
}

main();
