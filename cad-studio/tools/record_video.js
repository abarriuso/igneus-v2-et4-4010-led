// Records animation/assembly.html to an MP4, frame by frame (deterministic, any machine speed).
//
// Usage: node record_video.js OUT.mp4 --three DIR [--page assembly.html] [--fonts DIR] [--fps 30] [--tail 6] [--size 1920x1080] [--from 0] [--to END] [--clean]
//   --three  folder with three.min.js and OrbitControls.js (r128); the page normally loads them from a CDN
//   --fonts  folder with the IBM Plex woff2 files (@fontsource); without it the system fonts are used
//   --page   animation page in animation/ (assembly.html, or assembly_flat.html for the flat variant)
//   --tail   seconds of slow orbit with everything running after the sequence ends
//   --clean  only the 3D view, full frame (no side panel with the steps and schematics)
// Needs Playwright (PLAYWRIGHT=path/to/playwright if it is not resolvable) and ffmpeg with libx264.
const path = require('path');
const fs = require('fs');
const { spawn } = require('child_process');
const { chromium } = require(process.env.PLAYWRIGHT || 'playwright');

const args = process.argv.slice(2);
const opt = (name, def) => { const i = args.indexOf('--' + name); return i >= 0 ? args[i + 1] : def; };
const out = args[0];
const three = opt('three');
const fonts = opt('fonts');
const fps = +opt('fps', 30), tail = +opt('tail', 6);
const [W, H] = opt('size', '1920x1080').split('x').map(Number);
const clean = args.includes('--clean');
const html = path.join(__dirname, '..', 'animation', opt('page', 'assembly.html'));
if (!out || !three) { console.error('usage: node record_video.js OUT.mp4 --three DIR [--fonts DIR] ...'); process.exit(1); }

const FONT_FILES = {
  'IBM Plex Sans': [[400, 'ibm-plex-sans-latin-400-normal.woff2'], [500, 'ibm-plex-sans-latin-500-normal.woff2']],
  'IBM Plex Sans Condensed': [[500, 'ibm-plex-sans-condensed-latin-500-normal.woff2'], [600, 'ibm-plex-sans-condensed-latin-600-normal.woff2']],
  'IBM Plex Mono': [[400, 'ibm-plex-mono-latin-400-normal.woff2'], [500, 'ibm-plex-mono-latin-500-normal.woff2']],
};
function findFont(file) {
  for (const dir of fs.readdirSync(fonts)) {
    const p = path.join(fonts, dir, 'package', 'files', file);
    if (fs.existsSync(p)) return p;
  }
  return null;
}

// Video layout: the 3D stage fills the left, the right column shows the assembly steps,
// then switches to the two wiring schematics once the wiring starts.
const VIDEO_CSS = `
  html, body { margin: 0 !important; padding: 0 !important; overflow: hidden; }
  .wrap { max-width: none !important; gap: 0 !important; }
  header, .controls, .note, .hint { display: none !important; }
  .main { grid-template-columns: minmax(0, 1fr) 500px !important; gap: 0 !important; align-items: stretch !important; height: ${H}px; }
  section { display: block !important; }
  .stage { height: ${H}px !important; border-radius: 0 !important; }
  .status { left: 28px !important; top: 26px !important; }
  .status .n { font-size: 15px !important; padding: 5px 10px !important; }
  .status .t { font-size: 26px !important; padding: 2px 12px !important; }
  aside { padding: 40px 34px; height: ${H}px; overflow: hidden; display: flex; flex-direction: column; gap: 18px; }
  .vhead .eyebrow { font-size: 13px; }
  .vhead h1 { font-size: 34px; margin-top: 6px; }
  aside h2 { font-size: 21px !important; margin: 0 0 6px !important; }
  ol { gap: 0 !important; }
  li { padding: 3px 8px !important; line-height: 1.3; }
  li .tit { font-size: 14.5px; }
  li .det { font-size: 12px !important; }
  .circuits { display: none !important; gap: 22px !important; }
  aside.wiring .circuits { display: grid !important; }
  aside.wiring .steps-block { display: none !important; }
  .circuit { grid-template-columns: 1fr !important; border-top: 1px solid var(--line); padding-top: 14px !important; gap: 8px !important; }
  .circuit > div { order: -1; }
  .circuit p { font-size: 13.5px !important; }
  .schematic { max-width: 100% !important; }
`;

// Clean layout: just the 3D stage, full frame, with the step title in the corner
const CLEAN_CSS = `
  html, body { margin: 0 !important; padding: 0 !important; overflow: hidden; }
  .wrap { max-width: none !important; gap: 0 !important; }
  header, .controls, .note, .hint, aside, .circuits { display: none !important; }
  .main { grid-template-columns: 1fr !important; gap: 0 !important; }
  section { display: block !important; }
  .stage { height: ${H}px !important; border-radius: 0 !important; }
  .status { left: 32px !important; top: 30px !important; }
  .status .n { font-size: 16px !important; padding: 5px 10px !important; }
  .status .t { font-size: 28px !important; padding: 2px 12px !important; }
`;

(async () => {
  const launchArgs = process.env.CHROMIUM_ARGS ? process.env.CHROMIUM_ARGS.split(' ')
    : ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--disable-gpu-compositing'];   // CPU compositing: ~2x faster captures
  const browser = await chromium.launch({ args: launchArgs });
  const page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1, colorScheme: 'light' });
  page.on('pageerror', e => console.error('page error:', e.message));
  await page.route('**/three.min.js', r => r.fulfill({ path: path.join(three, 'three.min.js'), contentType: 'text/javascript' }));
  await page.route('**/OrbitControls.js', r => r.fulfill({ path: path.join(three, 'OrbitControls.js'), contentType: 'text/javascript' }));
  await page.route('https://fonts.googleapis.com/**', r => {
    if (!fonts) return r.abort();
    const faces = Object.entries(FONT_FILES).flatMap(([fam, list]) => list.map(([w, f]) =>
      `@font-face { font-family: "${fam}"; font-weight: ${w}; font-style: normal; src: url("https://fonts.gstatic.com/local/${f}") format("woff2"); }`));
    r.fulfill({ body: faces.join('\n'), contentType: 'text/css' });
  });
  await page.route('https://fonts.gstatic.com/**', r => {
    const p = fonts && findFont(path.basename(new URL(r.request().url()).pathname));
    return p ? r.fulfill({ path: p, contentType: 'font/woff2' }) : r.abort();
  });
  const body = fs.readFileSync(html, 'utf8');
  await page.setContent(`<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head><body>${body}</body></html>`, { waitUntil: 'load' });
  await page.addStyleTag({ content: clean ? CLEAN_CSS : VIDEO_CSS });
  await page.waitForFunction(() => window.toolhead);
  if (!clean) await page.evaluate(() => {
    const aside = document.querySelector('aside');
    const head = document.createElement('div'); head.className = 'vhead';
    head.innerHTML = '<div class="eyebrow">Anet ET4 · Igneus V2 (remix of Locos3D) · E3D V6</div><h1>Toolhead with 4010 blowers and LED light</h1>';
    const steps = document.createElement('div'); steps.className = 'steps-block';
    steps.append(aside.querySelector('h2'), aside.querySelector('ol'));
    aside.append(head, steps, document.querySelector('.circuits'));
  });
  await page.evaluate(() => document.fonts.ready);
  const times = await page.evaluate(() => window.toolhead.times);
  const from = +opt('from', 0), to = +opt('to', times.T_END + tail);
  const frames = Math.round((to - from) * fps);
  console.log(`timeline ${times.T_END.toFixed(2)} s + ${tail} s tail -> ${frames} frames at ${fps} fps, ${W}x${H}`);

  const ff = spawn('ffmpeg', ['-y', '-loglevel', 'error', '-f', 'image2pipe', '-framerate', String(fps), '-c:v', 'mjpeg', '-i', '-',
    '-c:v', 'libx264', '-preset', 'slow', '-crf', '20', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', out], { stdio: ['pipe', 'inherit', 'inherit'] });
  const started = Date.now();
  for (let i = 0; i < frames; i++) {
    const t = from + i / fps;
    await page.evaluate(([t, tw]) => {
      window.toolhead.set(t);
      const aside = document.querySelector('aside');
      if (aside) aside.classList.toggle('wiring', t >= tw - 0.3);
      return new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r)));
    }, [t, times.T_WIRE]);
    const jpg = await page.screenshot({ type: 'jpeg', quality: 92 });
    if (!ff.stdin.write(jpg)) await new Promise(r => ff.stdin.once('drain', r));
    if (i % 60 === 0) console.log(`frame ${i}/${frames}  t=${t.toFixed(2)}  ${((Date.now() - started) / 1000).toFixed(0)} s`);
  }
  ff.stdin.end();
  await new Promise(r => ff.on('close', r));
  await browser.close();
  console.log(`wrote ${out}`);
})();
