// Browser capture of the vfx demo (owner: vfx). Serves build/web, opens it in the installed
// Chrome (headless, real GPU through ANGLE, fresh profile), clicks the canvas once, and:
//   series mode (default): runs scenes/dev/vfx_demo.tscn with peak_pause=1 once=1 and saves a
//     screenshot each time the demo holds an effect at its peak (VFX_PEAK_HELD), until
//     VFX_DEMO_DONE;
//   --perf S: runs the demo without pauses for S seconds and reports the frame rate.
// Usage (through tools/vfx/shots_web.sh): [--out DIR] [--perf S] [--timeout S] [key=value ...]
// Writes DIR/web_console.txt (paths sanitised) and DIR/*.png. Exit 1 on any console error,
// page error, failed request, missing WebGL 2 or a software rasteriser.
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const projectRoot = process.env.ORIMI_PROJECT_ROOT;
const toolsDir = process.env.ORIMI_TOOLS_DIR;
const puppeteer = require(path.join(toolsDir, 'node', 'node_modules', 'puppeteer-core'));
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const opts = { out: path.join(projectRoot, 'build', 'vfx_web'), perf: 0, timeout: 240, query: new URLSearchParams() };
const argv = process.argv.slice(2);
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (a === '--out') opts.out = path.resolve(argv[++i]);
  else if (a === '--perf') opts.perf = Number(argv[++i]);
  else if (a === '--timeout') opts.timeout = Number(argv[++i]);
  else if (a.includes('=')) opts.query.append(a.slice(0, a.indexOf('=')), a.slice(a.indexOf('=') + 1));
  else { console.error('unknown argument: ' + a); process.exit(2); }
}
opts.query.set('scene', 'res://scenes/dev/vfx_demo.tscn');
if (!opts.perf) { opts.query.set('peak_pause', '1'); opts.query.set('once', '1'); }

function pathVariants(p) {
  const mixed = p.replace(/\\/g, '/').replace(/\/$/, '');
  const back = mixed.replace(/\//g, '\\');
  const out = [back.replace(/\\/g, '\\\\'), back, mixed];
  if (/^[A-Za-z]:/.test(mixed)) out.push('/' + mixed[0].toLowerCase() + mixed.slice(2));
  return out;
}
const rules = [...pathVariants(projectRoot).map((v) => [v, '<project>']), ...pathVariants(path.dirname(toolsDir)).map((v) => [v, '<tools-root>'])]
  .map(([v, tag]) => [new RegExp(v.replace(/[.*+?^$(){}|[\]\\]/g, '\\$&'), 'gi'), tag]);
const sanitize = (s) => rules.reduce((acc, [re, tag]) => acc.replace(re, tag), s);

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
    const timer = setTimeout(() => reject(new Error('server did not start')), 15000);
    proc.stdout.on('data', (d) => {
      buf += d.toString();
      const m = buf.match(/SERVING (\S+)/);
      if (m) { clearTimeout(timer); resolve({ proc, url: m[1] }); }
    });
    proc.on('exit', (code) => reject(new Error('server exited with code ' + code)));
  });
}

async function main() {
  fs.mkdirSync(opts.out, { recursive: true });
  const profileRoot = path.join(projectRoot, '.userdata', 'chrome');
  fs.mkdirSync(profileRoot, { recursive: true });
  const profileDir = fs.mkdtempSync(path.join(profileRoot, 'vfx-'));
  const lines = [];
  const problems = [];
  const shots = [];
  const log = (s) => { s = sanitize(s); lines.push(s); console.log(s); };
  const report = { mode: opts.perf ? 'perf' : 'series', query: opts.query.toString() };
  let server, browser;
  try {
    server = await startServer(path.join(projectRoot, 'build', 'web'));
    const url = server.url + 'index.html?' + opts.query.toString();
    browser = await puppeteer.launch({
      executablePath: findChrome(), headless: true, userDataDir: profileDir,
      defaultViewport: { width: 1280, height: 720 },
      args: ['--use-angle=d3d11', '--enable-gpu', '--ignore-gpu-blocklist', '--no-first-run', '--no-default-browser-check', '--window-size=1296,860'],
    });
    report.chrome = await browser.version();
    const page = await browser.newPage();
    let pending = Promise.resolve();
    let done = null;
    const finished = new Promise((r) => { done = r; });
    let firstFrame = null;
    const gotFirst = new Promise((r) => { firstFrame = r; });
    page.on('console', (msg) => {
      const text = msg.text();
      log('[console.' + msg.type() + '] ' + text);
      if (msg.type() === 'error') problems.push('console error: ' + text);
      if (text.startsWith('ORIMI_FIRST_FRAME')) firstFrame(text);
      const m = text.match(/^VFX_PEAK_HELD n=(\d+) id=(\S+)/);
      if (m) {
        const file = path.join(opts.out, String(m[1]).padStart(2, '0') + '_' + m[2] + '.png');
        pending = pending.then(() => page.screenshot({ path: file })).then(() => { shots.push(path.basename(file)); log('# shot ' + path.basename(file)); });
      }
      if (text.startsWith('VFX_DEMO_DONE')) done();
    });
    page.on('pageerror', (err) => { log('[pageerror] ' + err.message); problems.push('page error: ' + err.message); });
    page.on('requestfailed', (req) => { log('[requestfailed] ' + req.url()); problems.push('request failed: ' + req.url()); });
    page.on('response', (res) => { if (res.status() >= 400) problems.push('HTTP ' + res.status() + ' ' + res.url()); });
    const t0 = Date.now();
    await page.goto(url, { waitUntil: 'load' });
    const first = await Promise.race([gotFirst, sleep(90000).then(() => null)]);
    if (!first) throw new Error('no ORIMI_FIRST_FRAME');
    report.first_frame_ms = Date.now() - t0;
    report.webgl = await page.evaluate(() => {
      const gl = document.createElement('canvas').getContext('webgl2');
      if (!gl) return { webgl2: false };
      const dbg = gl.getExtension('WEBGL_debug_renderer_info');
      return { webgl2: true, renderer: dbg ? gl.getParameter(dbg.UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER) };
    });
    if (!report.webgl.webgl2) problems.push('WebGL 2 unavailable');
    if (/swiftshader|llvmpipe|software/i.test(report.webgl.renderer || '')) problems.push('software rasteriser: ' + report.webgl.renderer);
    await sleep(500);
    await page.mouse.click(640, 400);
    const rafFps = (ms) => page.evaluate((ms) => new Promise((resolve) => {
      let n = 0; const s = performance.now();
      const tick = (t) => { n++; if (t - s < ms) requestAnimationFrame(tick); else resolve(Math.round((n * 1000) / (t - s))); };
      requestAnimationFrame(tick);
    }), ms);
    if (opts.perf) {
      await sleep(3000);
      report.raf_fps = [];
      const end = Date.now() + opts.perf * 1000;
      while (Date.now() < end) report.raf_fps.push(await rafFps(2000));
      await page.screenshot({ path: path.join(opts.out, 'perf.png') });
    } else {
      const ok = await Promise.race([finished.then(() => true), sleep(opts.timeout * 1000).then(() => false)]);
      await pending;
      if (!ok) problems.push('no VFX_DEMO_DONE within ' + opts.timeout + ' s');
    }
    const fps = lines.map((l) => l.match(/ORIMI_FPS fps=(\d+)/)).filter(Boolean).map((m) => Number(m[1]));
    report.game_fps = fps;
    report.shots = shots;
  } catch (err) {
    problems.push(String(err && err.message ? err.message : err));
  } finally {
    if (browser) await browser.close().catch(() => {});
    if (server) server.proc.kill();
    await sleep(300);
    fs.rmSync(profileDir, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 });
  }
  report.problems = problems;
  report.passed = problems.length === 0;
  log('# summary ' + JSON.stringify(report, null, 2));
  fs.writeFileSync(path.join(opts.out, opts.perf ? 'web_perf_console.txt' : 'web_console.txt'), lines.join('\n') + '\n');
  console.log(report.passed ? 'VFX WEB PASSED' : 'VFX WEB FAILED');
  process.exit(report.passed ? 0 : 1);
}
main().catch((e) => { console.error(e); process.exit(1); });
