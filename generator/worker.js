// Runs OpenSCAD (WebAssembly build) off the main thread: builds one part of cad-studio/parts/customizer.scad
// with the given -D overrides and returns the STL.
import { createOpenSCAD } from 'https://cdn.jsdelivr.net/npm/openscad-wasm-prebuilt@1.2.0/dist/openscad.js';

// virtual file system path (relative to /w) -> URL relative to this worker
const FILES = {
  'parts/customizer.scad': '../cad-studio/parts/customizer.scad',
  'parts/lib/duct4010.scad': '../cad-studio/parts/lib/duct4010.scad',
  'parts/lib/flat4010.scad': '../cad-studio/parts/lib/flat4010.scad',
  'parts/lib/fan_adapter.scad': '../cad-studio/parts/lib/fan_adapter.scad',
  'igneus/asm/duct_5015.stl': 'originals/duct_5015.stl',
  'igneus/asm/adapter_4010_v2.stl': 'originals/adapter_4010_v2.stl',
};
let files;
async function loadFiles() {
  if (!files) {
    const entries = await Promise.all(Object.entries(FILES).map(async ([vfs, url]) => {
      const r = await fetch(new URL(url, self.location.href));
      if (!r.ok) throw new Error(`could not load ${url} (${r.status})`);
      return [vfs, new Uint8Array(await r.arrayBuffer())];
    }));
    files = Object.fromEntries(entries);
  }
  return files;
}

self.onmessage = async (e) => {
  const { id, defines } = e.data;
  const log = [];
  try {
    const f = await loadFiles();
    // a fresh instance per build: OpenSCAD's main() can only run once per instance
    const inst = (await createOpenSCAD({ noInitialRun: true, print: (s) => log.push(s), printErr: (s) => log.push(s) })).getInstance();
    for (const d of ['/w', '/w/parts', '/w/parts/lib', '/w/igneus', '/w/igneus/asm']) { try { inst.FS.mkdir(d); } catch { /* exists */ } }
    for (const [vfs, data] of Object.entries(f)) inst.FS.writeFile('/w/' + vfs, data);
    inst.FS.chdir('/w/parts');
    const args = ['customizer.scad', '-o', '/out.stl'];
    for (const [k, v] of Object.entries(defines)) args.push('-D', `${k}=${v}`);
    try { inst.callMain(args); } catch (err) { log.push(String(err)); }
    let stl;
    try { stl = inst.FS.readFile('/out.stl'); } catch { throw new Error('OpenSCAD did not produce an STL'); }
    self.postMessage({ id, ok: true, stl, log }, [stl.buffer]);
  } catch (err) {
    self.postMessage({ id, ok: false, error: String(err.message || err), log });
  }
};
