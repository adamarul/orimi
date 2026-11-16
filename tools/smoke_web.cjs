'use strict';
// Browser smoke check for the web export, driving the installed Chrome through puppeteer-core.
//
//   tools/smoke_web.sh [options] [key=value ...]
//
// key=value pairs become the URL query string, which the boot scene reads exactly like desktop
// command-line options (scene=res://..., paper=heavy, ...).
//
// Options:
//   --headed          show the browser window (default: headless)
//   --hold S          keep the page open S seconds after the first frame (default 6), then screenshot
//   --shot PATH       screenshot path (default build/smoke/web.png)
//   --log PATH        console log path (default build/smoke/web_console.txt)
//   --timeout S       seconds to wait for the first-frame marker (default 60)
//   --no-input        do not click or send pen events
//   --allow-software  do not fail when WebGL runs on a software rasteriser
//   --reload          after the first frame, reload once and also time a warm-cache load
//   --dir PATH        directory to serve (default build/web)
//
// Exit code 0 only if: the page printed ORIMI_FIRST_FRAME, there were no console errors, page
// errors or failed requests, the screenshot was written, and WebGL 2 ran on a hardware GPU.

const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawn } = require('child_process');

const projectRoot = process.env.ORIMI_PROJECT_ROOT || path.resolve(__dirname, '..');
const toolsDir = process.env.ORIMI_TOOLS_DIR;
if (!toolsDir) {
  console.error('ORIMI_TOOLS_DIR is not set; run through tools/smoke_web.sh');
  process.exit(2);
}
const puppeteer = require(path.join(toolsDir, 'node', 'node_modules', 'puppeteer-core'));

function parseArgs(argv) {
  const opts = {
    headed: false, hold: 6, timeout: 60, input: true, allowSoftware: false,
    shot: path.join(projectRoot, 'build', 'smoke', 'web.png'),
    log: path.join(projectRoot, 'build', 'smoke', 'web_console.txt'),
    dir: path.join(projectRoot, 'build', 'web'),
    query: new URLSearchParams(),
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--headed') opts.headed = true;
    else if (a === '--no-input') opts.input = false;
    else if (a === '--allow-software') opts.allowSoftware = true;
    else if (a === '--reload') opts.reload = true;
    else if (a === '--hold') opts.hold = Number(argv[++i]);
    else if (a === '--timeout') opts.timeout = Number(argv[++i]);
    else if (a === '--shot') opts.shot = path.resolve(argv[++i]);
    else if (a === '--log') opts.log = path.resolve(argv[++i]);
    else if (a === '--dir') opts.dir = path.resolve(argv[++i]);
    else if (a.includes('=')) {
      const eq = a.indexOf('=');
      opts.query.append(a.slice(0, eq), a.slice(eq + 1));
    } else {
      console.error('unknown argument: ' + a);
      process.exit(2);
    }
  }
  return opts;
}

function findChrome() {
  const candidates = [
    process.env.CHROME_PATH,
    'C:/Program Files/Google/Chrome/Application/chrome.exe',
    'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe',
    process.env.LOCALAPPDATA && path.join(process.env.LOCALAPPDATA, 'Google/Chrome/Application/chrome.exe'),
    '/usr/bin/google-chrome',
  ].filter(Boolean);
  const found = candidates.find((p) => fs.existsSync(p));
  if (!found) throw new Error('Chrome not found; set CHROME_PATH');
  return found;
}

function startServer(dir) {
  const python = process.env.ORIMI_PYTHON || 'python';
  const proc = spawn(python, ['-I', path.join(projectRoot, 'tools', 'serve_web.py'), '--dir', dir, '--port', '0'], {
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  return new Promise((resolve, reject) => {
    let buf = '';
    const timer = setTimeout(() => reject(new Error('server did not start')), 15000);
    proc.stdout.on('data', (d) => {
      buf += d.toString();
      const m = buf.match(/SERVING (\S+)/);
      if (m) {
        clearTimeout(timer);
        resolve({ proc, url: m[1] });
      }
    });
    proc.stderr.on('data', () => {});
    proc.on('exit', (code) => reject(new Error('server exited with code ' + code)));
  });
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// Logs may be kept under docs/, so absolute checkout paths become <project> / <tools-root>.
function pathVariants(p) {
  const mixed = p.replace(/\\/g, '/').replace(/\/$/, '');
  const back = mixed.replace(/\//g, '\\');
  const out = [back.replace(/\\/g, '\\\\'), back, mixed];
  if (/^[A-Za-z]:/.test(mixed)) out.push('/' + mixed[0].toLowerCase() + mixed.slice(2));
  return out;
}
const pathRules = [
  ...pathVariants(projectRoot).map((v) => [v, '<project>']),
  ...pathVariants(path.dirname(toolsDir)).map((v) => [v, '<tools-root>']),
].map(([v, tag]) => [new RegExp(v.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'gi'), tag]);
const sanitize = (s) => pathRules.reduce((acc, [re, tag]) => acc.replace(re, tag), s);

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  if (!fs.existsSync(path.join(opts.dir, 'index.html'))) {
    console.error('no index.html in ' + opts.dir + ' (run tools/export_web.sh)');
    process.exit(2);
  }
  fs.mkdirSync(path.dirname(opts.shot), { recursive: true });
  fs.mkdirSync(path.dirname(opts.log), { recursive: true });
  const profileRoot = path.join(projectRoot, '.userdata', 'chrome');
  fs.mkdirSync(profileRoot, { recursive: true });
  const profileDir = fs.mkdtempSync(path.join(profileRoot, 'profile-'));

  const lines = [];
  const problems = [];
  const log = (s) => {
    s = sanitize(s);
    lines.push(s);
    console.log(s);
  };
  const report = { headless: !opts.headed, query: opts.query.toString() };
  let server;
  let browser;
  try {
    server = await startServer(opts.dir);
    const url = server.url + 'index.html' + (opts.query.toString() ? '?' + opts.query.toString() : '');
    report.url = url;
    log('# serving ' + opts.dir + ' at ' + server.url);
    browser = await puppeteer.launch({
      executablePath: findChrome(),
      headless: !opts.headed,
      userDataDir: profileDir,
      defaultViewport: { width: 1280, height: 720 },
      args: [
        '--use-angle=d3d11',
        '--enable-gpu',
        '--ignore-gpu-blocklist',
        '--enable-unsafe-webgpu=false',
        '--no-first-run',
        '--no-default-browser-check',
        '--window-size=1296,860',
      ],
    });
    report.chrome = await browser.version();
    const page = await browser.newPage();
    let frameResolve = null;
    const nextFirstFrame = () => new Promise((resolve) => { frameResolve = resolve; });
    const firstFrame = nextFirstFrame();
    page.on('console', (msg) => {
      const text = msg.text();
      log('[console.' + msg.type() + '] ' + text);
      if (msg.type() === 'error') problems.push('console error: ' + text);
      if (text.startsWith('ORIMI_FIRST_FRAME') && frameResolve) {
        frameResolve(text);
        frameResolve = null;
      }
    });
    page.on('pageerror', (err) => {
      log('[pageerror] ' + err.message);
      problems.push('page error: ' + err.message);
    });
    page.on('requestfailed', (req) => {
      log('[requestfailed] ' + req.url() + ' ' + (req.failure() && req.failure().errorText));
      problems.push('request failed: ' + req.url());
    });
    page.on('response', (res) => {
      if (res.status() >= 400) problems.push('HTTP ' + res.status() + ' ' + res.url());
    });

    await page.evaluateOnNewDocument(() => {
      const Original = window.AudioContext;
      window.__orimiAudioContexts = [];
      window.AudioContext = class extends Original {
        constructor(...args) {
          super(...args);
          window.__orimiAudioContexts.push(this);
        }
      };
    });
    const audioState = () => page.evaluate(() => window.__orimiAudioContexts.map((c) => ({ state: c.state, time: Number(c.currentTime.toFixed(2)) })));

    const t0 = Date.now();
    await page.goto(url, { waitUntil: 'load' });
    const marker = await Promise.race([firstFrame, sleep(opts.timeout * 1000).then(() => null)]);
    if (!marker) throw new Error('no ORIMI_FIRST_FRAME within ' + opts.timeout + 's');
    report.first_frame_ms = Date.now() - t0;
    report.first_frame = marker;
    if (opts.reload) {
      const again = nextFirstFrame();
      const t1 = Date.now();
      log('# reloading (same profile, warm caches)');
      await page.reload({ waitUntil: 'load' });
      if (!(await Promise.race([again, sleep(opts.timeout * 1000).then(() => null)]))) throw new Error('no ORIMI_FIRST_FRAME after reload');
      report.reload_first_frame_ms = Date.now() - t1;
    }

    report.webgl = await page.evaluate(() => {
      const c = document.createElement('canvas');
      const gl = c.getContext('webgl2');
      if (!gl) return { webgl2: false };
      const dbg = gl.getExtension('WEBGL_debug_renderer_info');
      return {
        webgl2: true,
        version: gl.getParameter(gl.VERSION),
        vendor: dbg ? gl.getParameter(dbg.UNMASKED_VENDOR_WEBGL) : gl.getParameter(gl.VENDOR),
        renderer: dbg ? gl.getParameter(dbg.UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER),
      };
    });
    report.software_gl = /swiftshader|llvmpipe|software|basic render/i.test(report.webgl.renderer || '');
    log('# webgl ' + JSON.stringify(report.webgl));

    const holdStart = Date.now();
    if (opts.input) {
      await sleep(3000);
      report.audio_before_click = await audioState();
      await page.mouse.click(640, 400);
      await sleep(300);
      report.pointer_lock_after_click = await page.evaluate(() => document.pointerLockElement !== null);
      log('# pointer lock after click: ' + report.pointer_lock_after_click);
      await sleep(1200);
      report.audio_after_click = await audioState();
      log('# AudioContext before click ' + JSON.stringify(report.audio_before_click) + ', 1.5 s after click ' + JSON.stringify(report.audio_after_click));
      const cdp = await page.createCDPSession();
      const pen = (type, x, y, force, buttons) => cdp.send('Input.dispatchMouseEvent', {
        type, x, y, button: 'left', buttons, clickCount: 1, pointerType: 'pen', force, tiltX: 20, tiltY: -10,
      });
      await pen('mouseMoved', 500, 450, 0, 0);
      await pen('mousePressed', 500, 450, 0.3, 1);
      for (let i = 1; i <= 20; i++) await pen('mouseMoved', 500 + i * 10, 450 - i * 3, 0.3 + i * 0.03, 1);
      await pen('mouseReleased', 700, 390, 0, 0);
      log('# sent a pen stroke (CDP pointerType=pen, force 0.3..0.9, tilt 20/-10)');
    }

    report.raf_fps = await page.evaluate(() => new Promise((resolve) => {
      let n = 0;
      const start = performance.now();
      const tick = (t) => {
        n++;
        if (t - start < 2000) requestAnimationFrame(tick);
        else resolve(Math.round((n * 1000) / (t - start)));
      };
      requestAnimationFrame(tick);
    }));
    const remaining = opts.hold * 1000 - (Date.now() - holdStart);
    if (remaining > 0) await sleep(remaining);

    await page.screenshot({ path: opts.shot });
    report.screenshot = opts.shot;
    const fps = lines.map((l) => l.match(/ORIMI_FPS fps=(\d+)/)).filter(Boolean).map((m) => Number(m[1]));
    report.game_fps = fps;
    report.probes = lines.filter((l) => l.includes('ORIMI_PROBE ')).map((l) => l.replace(/^\[console\.\w+\] /, ''));
  } catch (err) {
    problems.push(String(err && err.message ? err.message : err));
  } finally {
    if (browser) await browser.close().catch(() => {});
    if (server) server.proc.kill();
    await sleep(300);
    fs.rmSync(profileDir, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 });
  }

  if (report.software_gl && !opts.allowSoftware) problems.push('WebGL is running on a software rasteriser: ' + report.webgl.renderer);
  if (report.webgl && !report.webgl.webgl2) problems.push('WebGL 2 unavailable');
  report.problems = problems;
  report.passed = problems.length === 0;
  log('# summary ' + JSON.stringify(report, null, 2));
  fs.writeFileSync(opts.log, lines.join('\n') + '\n');
  console.log(report.passed ? 'SMOKE PASSED' : 'SMOKE FAILED');
  process.exit(report.passed ? 0 : 1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
