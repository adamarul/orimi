'use strict';
// Browser frame-rate measurement for the render demo (owner: render).
//   tools/render/perf_web.sh [--size WxH] [--hold S] [--settle S] [--uncapped] [key=value ...]
// Serves build/web, opens it in the installed Chrome (headless, real GPU through ANGLE) at the
// given viewport size, waits for ORIMI_FIRST_FRAME plus --settle seconds (default 3), then for
// --hold seconds collects the demo's
// ORIMI_RENDER_PERF / ORIMI_FPS lines and measures the requestAnimationFrame rate.
// --uncapped launches Chrome with --disable-gpu-vsync --disable-frame-rate-limit, so frames
// are not held to the 144 Hz display. Prints one JSON summary line: PERF_RESULT {...}.
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const projectRoot = process.env.ORIMI_PROJECT_ROOT;
const toolsDir = process.env.ORIMI_TOOLS_DIR;
const puppeteer = require(path.join(toolsDir, 'node', 'node_modules', 'puppeteer-core'));
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const opts = { w: 1280, h: 720, hold: 8, settle: 3, uncapped: false, query: new URLSearchParams() };
const argv = process.argv.slice(2);
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (a === '--size') { const [w, h] = argv[++i].split('x').map(Number); opts.w = w; opts.h = h; }
  else if (a === '--hold') opts.hold = Number(argv[++i]);
  else if (a === '--settle') opts.settle = Number(argv[++i]);
  else if (a === '--uncapped') opts.uncapped = true;
  else if (a.includes('=')) { const eq = a.indexOf('='); opts.query.append(a.slice(0, eq), a.slice(eq + 1)); }
  else { console.error('unknown argument ' + a); process.exit(2); }
}

function findChrome() {
  const c = [process.env.CHROME_PATH, 'C:/Program Files/Google/Chrome/Application/chrome.exe',
    'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe'].filter(Boolean);
  return c.find((p) => fs.existsSync(p));
}

function startServer(dir) {
  const proc = spawn(process.env.ORIMI_PYTHON || 'python', ['-I', path.join(projectRoot, 'tools', 'serve_web.py'), '--dir', dir, '--port', '0'], { stdio: ['ignore', 'pipe', 'pipe'] });
  return new Promise((resolve, reject) => {
    let buf = '';
    proc.stdout.on('data', (d) => { buf += d; const m = buf.match(/SERVING (\S+)/); if (m) resolve({ proc, url: m[1] }); });
    proc.on('exit', (code) => reject(new Error('server exited ' + code)));
  });
}

(async () => {
  const profileRoot = path.join(projectRoot, '.userdata', 'chrome');
  fs.mkdirSync(profileRoot, { recursive: true });
  const profile = fs.mkdtempSync(path.join(profileRoot, 'perf-'));
  const server = await startServer(path.join(projectRoot, 'build', 'web'));
  const args = ['--use-angle=d3d11', '--enable-gpu', '--ignore-gpu-blocklist', '--no-first-run',
    '--no-default-browser-check', '--window-size=' + (opts.w + 16) + ',' + (opts.h + 140)];
  if (opts.uncapped) args.push('--disable-gpu-vsync', '--disable-frame-rate-limit');
  const browser = await puppeteer.launch({ executablePath: findChrome(), headless: true, userDataDir: profile,
    defaultViewport: { width: opts.w, height: opts.h }, args });
  const result = { size: opts.w + 'x' + opts.h, uncapped: opts.uncapped, query: opts.query.toString(), errors: [] };
  try {
    const page = await browser.newPage();
    const lines = [];
    let first;
    const firstFrame = new Promise((r) => { first = r; });
    page.on('console', (m) => {
      const t = m.text();
      lines.push(t);
      if (m.type() === 'error') result.errors.push(t);
      if (t.startsWith('ORIMI_FIRST_FRAME')) first();
    });
    page.on('pageerror', (e) => result.errors.push(e.message));
    await page.goto(server.url + 'index.html?' + opts.query.toString(), { waitUntil: 'load' });
    await Promise.race([firstFrame, sleep(90000)]);
    await sleep(opts.settle * 1000);
    const start = lines.length;
    result.raf_fps = await page.evaluate((ms) => new Promise((resolve) => {
      let n = 0; const t0 = performance.now(); const dts = []; let last = t0;
      const tick = (t) => { n++; dts.push(t - last); last = t; if (t - t0 < ms) requestAnimationFrame(tick); else {
        dts.sort((a, b) => a - b);
        resolve({ fps: +(n * 1000 / (t - t0)).toFixed(1), median_ms: +dts[dts.length >> 1].toFixed(2), p95_ms: +dts[Math.floor(dts.length * 0.95)].toFixed(2) });
      } };
      requestAnimationFrame(tick);
    }), opts.hold * 1000);
    const perf = lines.slice(start).filter((l) => l.startsWith('ORIMI_RENDER_PERF'));
    result.game = perf;
    const gpu = perf.map((l) => Number((l.match(/gpu_render_ms=([\d.]+)/) || [])[1])).filter((x) => !isNaN(x));
    if (gpu.length) result.gpu_render_ms_mean = +(gpu.reduce((a, b) => a + b, 0) / gpu.length).toFixed(3);
  } finally {
    await browser.close().catch(() => {});
    server.proc.kill();
    await sleep(300);
    fs.rmSync(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 });
  }
  console.log('PERF_RESULT ' + JSON.stringify(result));
})().catch((e) => { console.error(e); process.exit(1); });
