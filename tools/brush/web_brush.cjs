'use strict';
// Browser proof for the brush: drives build/web with real pointer and key events (CDP) in the
// installed Chrome. Opens the brush demo, captures the mouse with a click, then for each glyph
// holds a brush key, paints the glyph over its target (Kindle: a dab on the lamp's wick; Tie: a
// line from post A to post B), releases, and records what the game printed plus half-size JPEG
// screenshots of the sepia view and of the target reacting.
//
//   tools/brush/web_brush.sh [--pointer mouse|pen] [--headed] [--out DIR] [--rate HZ]
//
// Exit 0 only if every glyph was recognised and hit its target, the world froze and resumed,
// the tree was unpaused, and the page logged no errors.

const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const projectRoot = process.env.ORIMI_PROJECT_ROOT;
const toolsDir = process.env.ORIMI_TOOLS_DIR;
if (!projectRoot || !toolsDir) {
  console.error('run through tools/brush/web_brush.sh');
  process.exit(2);
}
const puppeteer = require(path.join(toolsDir, 'node', 'node_modules', 'puppeteer-core'));

const opts = { pointer: 'mouse', headed: false, out: path.join(projectRoot, 'docs', 'brush', 'web'), rate: 125 };
const argv = process.argv.slice(2);
for (let i = 0; i < argv.length; i++) {
  if (argv[i] === '--pointer') opts.pointer = argv[++i];
  else if (argv[i] === '--headed') opts.headed = true;
  else if (argv[i] === '--out') opts.out = path.resolve(argv[++i]);
  else if (argv[i] === '--rate') opts.rate = Number(argv[++i]);
  else { console.error('unknown argument ' + argv[i]); process.exit(2); }
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function findChrome() {
  const c = [process.env.CHROME_PATH, 'C:/Program Files/Google/Chrome/Application/chrome.exe',
    'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe'].filter(Boolean);
  const f = c.find((p) => fs.existsSync(p));
  if (!f) throw new Error('Chrome not found; set CHROME_PATH');
  return f;
}

function startServer(dir) {
  const proc = spawn(process.env.ORIMI_PYTHON || 'python', ['-I', path.join(projectRoot, 'tools', 'serve_web.py'), '--dir', dir, '--port', '0'], { stdio: ['ignore', 'pipe', 'pipe'] });
  return new Promise((resolve, reject) => {
    let buf = '';
    const t = setTimeout(() => reject(new Error('server did not start')), 15000);
    proc.stdout.on('data', (d) => {
      buf += d.toString();
      const m = buf.match(/SERVING (\S+)/);
      if (m) { clearTimeout(t); resolve({ proc, url: m[1] }); }
    });
    proc.stderr.on('data', () => {});
  });
}

function pathVariants(p) {
  const mixed = p.replace(/\\/g, '/').replace(/\/$/, '');
  const back = mixed.replace(/\//g, '\\');
  const out = [back.replace(/\\/g, '\\\\'), back, mixed];
  if (/^[A-Za-z]:/.test(mixed)) out.push('/' + mixed[0].toLowerCase() + mixed.slice(2));
  return out;
}
const rules = [...pathVariants(projectRoot).map((v) => [v, '<project>']), ...pathVariants(path.dirname(toolsDir)).map((v) => [v, '<tools-root>'])]
  .map(([v, tag]) => [new RegExp(v.replace(/[.*+?^$(){}|[\]\\]/g, '\\$&'), 'gi'), tag]);
const sanitize = (s) => rules.reduce((a, [re, tag]) => a.replace(re, tag), s);

// Glyph strokes in viewport pixels around a centre, drawn the way a hand does: a little
// wobble, and (in main) an ease-in/ease-out speed profile. Tie runs from c to c2.
function glyphPath(glyph, c, c2, pointer) {
  const pts = [];
  if (glyph === 'kindle') {
    // A mouse click barely moves; a pen tip slips a few pixels and trembles as it lands.
    if (pointer !== 'pen') return [c, [c[0] + 1, c[1] + 1]];
    for (let i = 0; i <= 12; i++) {
      const s = Math.min(1, i / 4);
      pts.push([c[0] + 3 * s + Math.sin(i * 2.1) * 0.6, c[1] + 2 * s + Math.cos(i * 1.7) * 0.6]);
    }
  } else if (glyph === 'tie') {
    for (let i = 0; i <= 40; i++) {
      const t = i / 40;
      pts.push([c[0] + (c2[0] - c[0]) * t, c[1] + (c2[1] - c[1]) * t + Math.sin(t * 7) * 3]);
    }
  } else if (glyph === 'bloom') {
    for (let i = 0; i <= 60; i++) {
      const a = -Math.PI / 2 - (i / 60) * Math.PI * 2 * 1.03;
      pts.push([c[0] + Math.cos(a) * 95 + Math.sin(i * 0.7) * 2, c[1] + Math.sin(a) * 85]);
    }
  } else if (glyph === 'slash') {
    for (let i = 0; i <= 30; i++) {
      const t = i / 30;
      pts.push([c[0] - 160 + t * 320, c[1] + 6 - 14 * t + Math.sin(t * 9) * 2]);
    }
  } else {
    const d = 2.3;
    for (let i = 0; i <= 70; i++) {
      const t = -Math.PI + (i / 70) * 2 * Math.PI;
      pts.push([c[0] + (t - d * Math.sin(t)) * 28, c[1] + (-d * Math.cos(t)) * 28 + 30]);
    }
  }
  return pts;
}

async function main() {
  fs.mkdirSync(opts.out, { recursive: true });
  const profileRoot = path.join(projectRoot, '.userdata', 'chrome');
  fs.mkdirSync(profileRoot, { recursive: true });
  const profileDir = fs.mkdtempSync(path.join(profileRoot, 'brush-'));
  const lines = [];
  const problems = [];
  const events = [];
  const log = (s) => { s = sanitize(s); lines.push(s); console.log(s); };
  let server;
  let browser;
  const summary = { pointer: opts.pointer, rate_hz: opts.rate, glyphs: {} };
  try {
    server = await startServer(path.join(projectRoot, 'build', 'web'));
    browser = await puppeteer.launch({
      executablePath: findChrome(), headless: !opts.headed, userDataDir: profileDir,
      defaultViewport: { width: 1280, height: 720 },
      args: ['--use-angle=d3d11', '--enable-gpu', '--ignore-gpu-blocklist', '--no-first-run', '--no-default-browser-check', '--window-size=1296,860'],
    });
    summary.chrome = await browser.version();
    const page = await browser.newPage();
    page.on('console', (msg) => {
      const text = msg.text();
      log('[console.' + msg.type() + '] ' + text);
      if (msg.type() === 'error') problems.push('console error: ' + text);
      const m = text.match(/^BRUSH_DEMO (\{.*\})$/);
      if (m) events.push({ t: Date.now(), ...JSON.parse(m[1]) });
    });
    page.on('pageerror', (e) => { log('[pageerror] ' + e.message); problems.push('page error: ' + e.message); });
    page.on('requestfailed', (r) => problems.push('request failed: ' + r.url()));
    const waitFor = async (pred, ms, what) => {
      const end = Date.now() + ms;
      while (Date.now() < end) {
        const e = events.find(pred);
        if (e) return e;
        await sleep(25);
      }
      throw new Error('timed out waiting for ' + what);
    };
    const url = server.url + 'index.html?scene=res://scenes/dev/brush_demo.tscn';
    log('# opening ' + url);
    await page.goto(url, { waitUntil: 'load' });
    const layout = await waitFor((e) => e.event === 'layout', 90000, 'layout');
    summary.webgl = await page.evaluate(() => {
      const gl = document.createElement('canvas').getContext('webgl2');
      const dbg = gl && gl.getExtension('WEBGL_debug_renderer_info');
      return gl ? gl.getParameter(dbg ? dbg.UNMASKED_RENDERER_WEBGL : gl.RENDERER) : 'no webgl2';
    });
    log('# webgl ' + summary.webgl);
    await sleep(1500);
    const cdp = await page.createCDPSession();
    let buttons = 0;
    const pointerType = opts.pointer;
    const send = (type, x, y, button, extra = {}) => cdp.send('Input.dispatchMouseEvent', {
      type, x, y, button: button || 'none', buttons, clickCount: type === 'mouseMoved' ? 0 : 1, pointerType, ...extra,
    });
    const lockState = () => page.evaluate(() => document.pointerLockElement !== null);

    // Capture the mouse: the demo requests capture on a left click, as the game does.
    await send('mouseMoved', 640, 150, 'none');
    buttons = 1; await send('mousePressed', 640, 150, 'left', { force: 0.5 });
    buttons = 0; await send('mouseReleased', 640, 150, 'left');
    await sleep(500);
    summary.pointer_lock_before = await lockState();
    log('# pointer lock after click: ' + summary.pointer_lock_before);

    // The last run keeps the brush key down 6 s after the stroke, past Chrome's 5 s transient
    // user activation, to see whether pointer lock can still be taken back on release.
    const runs = [['bloom', 'shift', 200], ['slash', 'q', 200], ['gust', 'rmb', 200], ['kindle', 'shift', 200], ['tie', 'q', 200], ['bloom', 'shift', 6000]];
    const shot = (file) => page.screenshot({ path: path.join(opts.out, file + '.jpg'), type: 'jpeg', quality: 70,
      clip: { x: 0, y: 0, width: 1280, height: 720, scale: 0.5 } });
    for (const [glyph, key, holdMs] of runs) {
      const name = glyph + (holdMs > 1000 ? '_long_hold' : '');
      const g = { key, hold_ms: holdMs };
      const centre = layout.targets[glyph === 'tie' ? 'tie_a' : glyph];
      const pts = glyphPath(glyph, centre, layout.targets.tie_b, pointerType);
      const since = Date.now();
      const after = (pred) => (e) => e.t >= since && pred(e);
      g.pointer_lock_before = await lockState();
      if (g.key === 'shift') await page.keyboard.down('ShiftLeft');
      else if (g.key === 'q') await page.keyboard.down('KeyQ');
      else { buttons |= 2; await send('mousePressed', pts[0][0], pts[0][1], 'right'); }
      const opened = await waitFor(after((e) => e.event === 'brush_opened'), 5000, glyph + ' brush_opened');
      g.opened = { paused: opened.paused, mouse_mode: opened.mouse_mode };
      await sleep(250);
      g.pointer_lock_while_open = await lockState();
      const dt = 1000 / opts.rate;
      const duration = { slash: 160, kindle: 150, tie: 450 }[glyph] || 900;
      const at = (u) => {
        const e = u * u * (3 - 2 * u) * 0.6 + u * 0.4;
        const f = e * (pts.length - 1);
        const i = Math.min(Math.floor(f), pts.length - 2);
        const k = f - i;
        return [pts[i][0] + (pts[i + 1][0] - pts[i][0]) * k, pts[i][1] + (pts[i + 1][1] - pts[i][1]) * k];
      };
      await send('mouseMoved', pts[0][0], pts[0][1], 'none');
      buttons |= 1;
      await send('mousePressed', pts[0][0], pts[0][1], 'left', { force: 0.35 });
      // Positions follow the wall clock, so the stroke takes `duration` ms whatever the event
      // round trip costs; events go out at most every dt ms.
      const t0 = Date.now();
      for (;;) {
        const u = Math.min(1, (Date.now() - t0) / duration);
        const p = at(u);
        const force = pointerType === 'pen' ? 0.25 + 0.7 * Math.sin(Math.PI * u) : 0;
        await send('mouseMoved', p[0], p[1], 'none', { force });
        if (u >= 1) break;
        const wait = dt - ((Date.now() - t0) % dt);
        if (wait > 1) await sleep(wait);
      }
      g.duration_ms = Date.now() - t0;
      const end = pts[pts.length - 1];
      buttons &= ~1;
      await send('mouseReleased', end[0], end[1], 'left');
      await sleep(holdMs);
      const frozen = events.filter(after((e) => e.event === 'frozen_check'));
      g.frozen_checks = frozen.length;
      g.mover_moved_while_open = Math.max(0, ...frozen.map((e) => e.mover_moved));
      await shot(pointerType + '_' + name + '_open');
      if (g.key === 'shift') await page.keyboard.up('ShiftLeft');
      else if (g.key === 'q') await page.keyboard.up('KeyQ');
      else { buttons &= ~2; await send('mouseReleased', end[0], end[1], 'right'); }
      const result = await waitFor(after((e) => e.event === 'glyph_cast' || e.event === 'glyph_failed'), 5000, glyph + ' result');
      g.result = result.event === 'glyph_cast' ? result.glyph : 'failed: ' + result.detail;
      g.score = result.score;
      g.targets = result.targets;
      g.input = result.input;
      const closed = await waitFor(after((e) => e.event === 'brush_closed'), 5000, glyph + ' brush_closed');
      g.closed = { paused: closed.paused, mouse_mode: closed.mouse_mode };
      const resumed = await waitFor(after((e) => e.event === 'resumed'), 5000, glyph + ' resumed');
      g.mover_moved_after = resumed.mover_moved_after;
      const reacted = events.filter(after((e) => e.event === 'target_reacted' && e.glyph === glyph));
      // A Tie must reach both posts, told in stroke order.
      g.reacted = glyph === 'tie'
        ? reacted.map((e) => e.target + ':' + e.order).join(',') === 'PostA:0,PostB:1'
        : reacted.length > 0;
      await sleep(500);
      g.pointer_lock_after = await lockState();
      await shot(pointerType + '_' + name + '_after');
      g.ok = g.result === glyph && g.reacted && g.opened.paused === true && g.closed.paused === false &&
        g.mover_moved_while_open === 0 && g.mover_moved_after > 0 && g.frozen_checks > 0;
      if (!g.ok) problems.push(name + ' did not pass: ' + JSON.stringify(g));
      summary.glyphs[name] = g;
      log('# ' + name + ' ' + JSON.stringify(g));
      if (!g.pointer_lock_after) {
        // The game treats a lost capture as a pause; click to capture again, like a player.
        await send('mouseMoved', 640, 150, 'none');
        buttons |= 1; await send('mousePressed', 640, 150, 'left');
        buttons &= ~1; await send('mouseReleased', 640, 150, 'left');
      }
      await sleep(3600);
    }
  } catch (err) {
    problems.push(String(err && err.message ? err.message : err));
  } finally {
    if (browser) await browser.close().catch(() => {});
    if (server) server.proc.kill();
    await sleep(300);
    fs.rmSync(profileDir, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 });
  }
  summary.problems = problems;
  summary.passed = problems.length === 0;
  log('# summary ' + JSON.stringify(summary, null, 2));
  fs.writeFileSync(path.join(opts.out, opts.pointer + '_console.txt'), lines.join('\n') + '\n');
  console.log(summary.passed ? 'WEB BRUSH PASSED' : 'WEB BRUSH FAILED');
  process.exit(summary.passed ? 0 : 1);
}

main().catch((e) => { console.error(e); process.exit(1); });
