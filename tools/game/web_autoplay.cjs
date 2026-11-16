'use strict';
// Browser run of autoplay=1: plays the whole slice in Chrome from the web export and takes a
// screenshot at every QA "stage" line. Built on the same server and Chrome setup as
// tools/smoke_web.cjs.
//
//   tools/game/web_autoplay.sh [--out DIR] [--timeout S] [--headed] [--reload-on TAG [--reload-delay MS]] [--title-only]
//     [key=value ...]
// --reload-on: once the QA line TAG appears, wait MS (default 1000), close the tab and open the game
// in a new tab without autoplay; the run ends at the title (title_ready), so qa.jsonl shows what
// the reload found, with a shot of the title (title.png) and of its chapter list (chapters.png).
// --title-only: open the game without autoplay and take those two shots.
//
// Writes DIR/console.txt (sanitised), DIR/qa.jsonl (the QA lines), DIR/NN_<stage>.png and
// DIR/summary.json. Exit 0 only if autoplay reported PASSED with no console errors.

const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const projectRoot = process.env.ORIMI_PROJECT_ROOT;
const toolsDir = process.env.ORIMI_TOOLS_DIR;
const puppeteer = require(path.join(toolsDir, 'node', 'node_modules', 'puppeteer-core'));

function parseArgs(argv) {
  const opts = { out: path.join(projectRoot, 'build', 'game', 'web_autoplay'), timeout: 600, headed: false, reloadOn: '', reloadDelay: 1000, titleOnly: false, query: new URLSearchParams() };
  opts.query.append('scene', 'res://scenes/game/main.tscn');
  opts.query.append('autoplay', '1');
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--out') opts.out = path.resolve(argv[++i]);
    else if (a === '--timeout') opts.timeout = Number(argv[++i]);
    else if (a === '--headed') opts.headed = true;
    else if (a === '--reload-on') opts.reloadOn = argv[++i];
    else if (a === '--title-only') opts.titleOnly = true;
    else if (a === '--reload-delay') opts.reloadDelay = Number(argv[++i]);
    else if (a.includes('=')) { const eq = a.indexOf('='); opts.query.set(a.slice(0, eq), a.slice(eq + 1)); }
    else { console.error('unknown argument: ' + a); process.exit(2); }
  }
  if (opts.titleOnly) opts.query.delete('autoplay');
  return opts;
}

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
    proc.stdout.on('data', (d) => { buf += d; const m = buf.match(/SERVING (\S+)/); if (m) { clearTimeout(t); resolve({ proc, url: m[1] }); } });
    proc.on('exit', (code) => reject(new Error('server exited ' + code)));
  });
}

function escapeRe(s) {
  return s.split('').map((ch) => ('.*+?^$' + '{}()|[]\\/'.indexOf(ch) >= 0 ? '\\' + ch : ch)).join('');
}

function sanitizer() {
  const variants = (p) => { const m = p.replace(/\\/g, '/').replace(/\/$/, ''); const b = m.replace(/\//g, '\\'); const o = [b, m]; if (/^[A-Za-z]:/.test(m)) o.push('/' + m[0].toLowerCase() + m.slice(2)); return o; };
  const rules = [...variants(projectRoot).map((v) => [v, '<project>']), ...variants(path.dirname(toolsDir)).map((v) => [v, '<tools-root>'])]
    .map(([v, t]) => [new RegExp(escapeRe(v), 'gi'), t]);
  return (s) => rules.reduce((a, [r, t]) => a.replace(r, t), s);
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  const webDir = path.join(projectRoot, 'build', 'web');
  fs.rmSync(opts.out, { recursive: true, force: true });
  fs.mkdirSync(opts.out, { recursive: true });
  const profileRoot = path.join(projectRoot, '.userdata', 'chrome');
  fs.mkdirSync(profileRoot, { recursive: true });
  const profileDir = fs.mkdtempSync(path.join(profileRoot, 'auto-'));
  const sanitize = sanitizer();
  const lines = [];
  const qa = [];
  const problems = [];
  const shots = [];
  let ended = null;
  let server, browser;
  const t0 = Date.now();
  try {
    server = await startServer(webDir);
    const url = server.url + 'index.html?' + opts.query.toString();
    lines.push('# url ' + url);
    browser = await puppeteer.launch({ executablePath: findChrome(), headless: !opts.headed, userDataDir: profileDir,
      defaultViewport: { width: 1280, height: 720 },
      args: ['--use-angle=d3d11', '--enable-gpu', '--ignore-gpu-blocklist', '--no-first-run', '--no-default-browser-check', '--window-size=1296,860'] });
    let page = await browser.newPage();
    let chain = Promise.resolve();
    let reloadAt = 0;
    let reloaded = false;
    let titleAt = 0;
    let shotIndex = 0;
    const watch = (page) => {
    page.on('console', (msg) => {
      const text = sanitize(msg.text());
      const stamp = ((Date.now() - t0) / 1000).toFixed(1);
      lines.push('[' + stamp + 's console.' + msg.type() + '] ' + text);
      if (msg.type() === 'error') problems.push('console error: ' + text);
      if (text.startsWith('QA:')) {
        let rec = null;
        try { rec = JSON.parse(text.slice(3)); } catch (e) { problems.push('bad QA line: ' + text); }
        if (rec) {
          rec.wall = Number(stamp);
          qa.push(rec);
          if (rec.tag === 'stage') {
            shotIndex += 1;
            const name = String(shotIndex).padStart(2, '0') + '_' + rec.data.stage + '.png';
            chain = chain.then(() => page.screenshot({ path: path.join(opts.out, name) }).then(() => shots.push(name)).catch((e) => { if (!reloaded) problems.push('screenshot ' + name + ': ' + e.message); }));
          }
          if (rec.tag === 'autoplay_end') ended = rec.data;
          if (opts.reloadOn && rec.tag === opts.reloadOn && !reloadAt) reloadAt = Date.now() + opts.reloadDelay;
          if ((reloaded || opts.titleOnly) && rec.tag === 'title_ready' && !titleAt) titleAt = Date.now();
        }
      }
    });
    page.on('pageerror', (err) => { lines.push('[pageerror] ' + err.message); problems.push('page error: ' + err.message); });
    page.on('requestfailed', (req) => problems.push('request failed: ' + req.url()));
    page.on('response', (res) => { if (res.status() >= 400) problems.push('HTTP ' + res.status() + ' ' + res.url()); });
    };
    watch(page);
    await page.goto(url, { waitUntil: 'load' });
    await sleep(4000);
    if (!opts.titleOnly) await page.mouse.click(640, 400);
    const deadline = Date.now() + opts.timeout * 1000;
    while (!ended && Date.now() < deadline) {
      if (reloadAt && !reloaded && Date.now() >= reloadAt) {
        // The tab is closed and the game opened in a new one without autoplay: whatever it finds is
        // what a player who closed the tab at that moment would find.
        reloaded = true;
        const stamp = Number(((Date.now() - t0) / 1000).toFixed(1));
        lines.push('[' + stamp + 's] # reload');
        qa.push({ tag: 'reload', data: { after: opts.reloadOn, delay_ms: opts.reloadDelay }, wall: stamp });
        await page.close();
        page = await browser.newPage();
        watch(page);
        await page.goto(server.url + 'index.html?scene=' + encodeURIComponent(opts.query.get('scene')), { waitUntil: 'load' });
      }
      if (titleAt) {
        // The title as a player finds it, then its chapter list (Down to Chapters, Enter).
        await sleep(1800);
        await page.screenshot({ path: path.join(opts.out, 'title.png') });
        shots.push('title.png');
        await page.evaluate(() => { const c = document.querySelector('canvas'); if (c) c.focus(); });
        await page.keyboard.press('ArrowDown');
        await sleep(250);
        await page.keyboard.press('Enter');
        await sleep(900);
        await page.screenshot({ path: path.join(opts.out, 'chapters.png') });
        shots.push('chapters.png');
        ended = { passed: true, reloaded, stages: [], failures: [] };
        break;
      }
      await sleep(reloadAt && !reloaded ? 50 : 500);
    }
    if (!ended) problems.push('autoplay did not finish within ' + opts.timeout + ' s');
    await sleep(500);
    await chain;
    await page.screenshot({ path: path.join(opts.out, 'zz_final.png') });
  } catch (err) {
    problems.push(String(err && err.message ? err.message : err));
  } finally {
    if (browser) await browser.close().catch(() => {});
    if (server) server.proc.kill();
    await sleep(300);
    fs.rmSync(profileDir, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 });
  }
  const summary = { passed: !!(ended && ended.passed) && problems.length === 0, autoplay: ended, problems, shots, wall_seconds: (Date.now() - t0) / 1000 };
  fs.writeFileSync(path.join(opts.out, 'console.txt'), lines.join('\n') + '\n');
  fs.writeFileSync(path.join(opts.out, 'qa.jsonl'), qa.map((q) => JSON.stringify(q)).join('\n') + '\n');
  fs.writeFileSync(path.join(opts.out, 'summary.json'), JSON.stringify(summary, null, 2));
  console.log(JSON.stringify({ passed: summary.passed, problems, stages: ended && ended.stages, failures: ended && ended.failures, duration: ended && ended.duration, shots: shots.length }, null, 1));
  console.log(summary.passed ? 'WEB AUTOPLAY PASSED' : 'WEB AUTOPLAY FAILED');
  process.exit(summary.passed ? 0 : 1);
}

main().catch((e) => { console.error(e); process.exit(1); });
