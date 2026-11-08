"""Rebuilds everything the repository publishes from the OpenSCAD sources, in this order:

  1. every parts/*.scad -> build/*.stl, with OpenSCAD (the same builds CAD Studio's server makes)
  2. export/*.stl, the print-ready STLs: each part laid on its printing face (tools/export_print.py)
  3. the four assembly animations, animation/assembly*.html (tools/pack_anim.py)
  4. the site's 3D visualizer: visualizer/normal, flat, onepiece and onepiece_flat.html (copies of step 3)
  5. with --renders, the site and README images in screenshots/ (tools/render_site.py, needs Blender)

OpenSCAD 2021 does not write the triangles of a part in the same order every time, so an STL or a visualizer
page is only rewritten when its geometry really changed: rebuilding unchanged sources leaves git clean.

Usage: python tools/build_all.py [--jobs N] [--skip-build] [--renders]
  --jobs N      OpenSCAD builds run in parallel (default: the number of CPUs)
  --skip-build  reuse build/*.stl (e.g. after CAD Studio has already built everything)
  --renders     also re-render screenshots/ in Blender (slow; set BLENDER if it is not the 5.2 install)

Needs OpenSCAD and Locos3D's original Igneus files placed with tools/place_originals.py: the LED mount and the
preview parts import them (see igneus/README.md).
"""
import base64
import json
import os
import shutil
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]          # cad-studio/
sys.path.insert(0, str(ROOT / "tools"))
from stlinfo import read_stl  # noqa: E402

PARTS, BUILD, EXPORT = ROOT / "parts", ROOT / "build", ROOT / "export"
TOOLS, ANIM, SITE = ROOT / "tools", ROOT / "animation", ROOT.parent / "visualizer"

# build name -> print-ready file, and the face it prints on (tools/export_print.py modes; None = as modelled)
EXPORTS = [
    ("adapter_4010_right", "Adapter_4010_right", None),                  # nozzle down
    ("adapter_4010_left", "Adapter_4010_left", None),
    ("adapter_4010_flat_right", "Adapter_4010_flat_right", "upside_down"),
    ("adapter_4010_flat_left", "Adapter_4010_flat_left", "upside_down"),
    ("led_mount_right", "LED_mount_right", "lay_on_front"),
    ("led_mount_left", "LED_mount_left", "lay_on_front"),
    ("duct_4010_right", "Duct_4010_LED_right", "lay_on_front"),          # on the flat back face
    ("duct_4010_left", "Duct_4010_LED_left", "lay_on_front"),
    ("duct_4010_flat_right", "Duct_4010_LED_flat_right", "lay_on_front"),
    ("duct_4010_flat_left", "Duct_4010_LED_flat_left", "lay_on_front"),
    ("fan_adapter_2510_30", "Fan_adapter_2510_30mm", "lay_on_min_y"),    # fan side down
]
# pack_anim.py flags -> animation page -> visualizer page
ANIMATIONS = [
    ([], "assembly", "normal"),
    (["--flat"], "assembly_flat", "flat"),
    (["--onepiece"], "assembly_onepiece", "onepiece"),
    (["--onepiece", "--flat"], "assembly_onepiece_flat", "onepiece_flat"),
]
ORIGINALS = ["igneus/asm/duct_5015.stl", "igneus/view/body_v1_v6.stl", "igneus/view/clamp_fan30.stl",
             "igneus/view/original_ducts.stl"]


def arg(name, default=None):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def run(cmd, **kw):
    proc = subprocess.run(cmd, capture_output=True, text=True, **kw)
    if proc.returncode != 0:
        sys.exit(f"Failed: {' '.join(map(str, cmd))}\n{proc.stdout}{proc.stderr}")
    return proc.stdout


# ---------- 1. OpenSCAD builds ----------
def find_openscad():
    """Same search as server.py (which can't be imported here: it reads its port from the command line)."""
    for name in ("openscad.com", "openscad"):
        if shutil.which(name):
            return shutil.which(name)
    for base in (os.environ.get("ProgramFiles", r"C:\Program Files"),
                 os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)")):
        for exe in ("openscad.com", "openscad.exe"):
            if (Path(base) / "OpenSCAD" / exe).exists():
                return str(Path(base) / "OpenSCAD" / exe)
    sys.exit("OpenSCAD not found: install it or put it on the PATH.")


def build(openscad, src):
    tmp, dst = BUILD / f"{src.stem}.tmp.stl", BUILD / f"{src.stem}.stl"
    proc = subprocess.run([openscad, "-o", str(tmp), "--export-format", "binstl", str(src)],
                          capture_output=True, timeout=1200, cwd=str(PARTS))
    log = (proc.stdout + proc.stderr).decode("utf-8", errors="replace")
    (BUILD / f"{src.stem}.log").write_text(log, encoding="utf-8")
    ok = proc.returncode == 0 and tmp.exists() and tmp.stat().st_size > 84 and "Can't open import file" not in log
    if ok:
        os.replace(tmp, dst)
    elif tmp.exists():
        tmp.unlink()
    return src.stem, ok, log


def build_all(jobs):
    missing = [p for p in ORIGINALS if not (ROOT / p).exists()]
    if missing:
        sys.exit("Missing the placed original Igneus files (%s).\nDownload the Igneus V2 pack as explained in "
                 "igneus/README.md and run tools/place_originals.py first." % ", ".join(missing))
    openscad = find_openscad()
    sources = sorted(p for p in PARTS.glob("*.scad") if p.stem != "customizer")
    BUILD.mkdir(exist_ok=True)
    print(f"1/4 Building {len(sources)} parts with {openscad} ({jobs} at a time)...", flush=True)
    failed = []
    with ThreadPoolExecutor(jobs) as pool:
        for name, ok, log in pool.map(lambda s: build(openscad, s), sources):
            print(f"    {'ok   ' if ok else 'ERROR'} {name}", flush=True)
            if not ok:
                failed.append((name, log))
    if failed:
        sys.exit("\n".join(f"--- {n}\n{log.strip()}" for n, log in failed) + f"\n{len(failed)} part(s) failed.")


# ---------- 2. print-ready STLs ----------
def fingerprint(path):
    """Triangle count, bounding box, volume and area: the same for a part whatever its triangle order."""
    t = np.array(read_stl(path), dtype=float)
    a, b, c = t[:, 0], t[:, 1], t[:, 2]
    volume = np.einsum("ij,ij->i", a, np.cross(b, c)).sum() / 6
    area = np.linalg.norm(np.cross(b - a, c - a), axis=1).sum() / 2
    pts = t.reshape(-1, 3)
    return len(t), np.concatenate([pts.min(0), pts.max(0), [volume, area]])


def vertices(path):
    return np.unique(np.array(read_stl(path), dtype=float).reshape(-1, 3), axis=0)


def covered(va, vb, tol=1e-3):
    """Every vertex of va has a vertex of vb within tol (grid lookup in cells of size tol)."""
    cells = {}
    for i, k in enumerate(map(tuple, np.floor(vb / tol).astype(np.int64))):
        cells.setdefault(k, []).append(i)
    near = [(dx, dy, dz) for dx in (-1, 0, 1) for dy in (-1, 0, 1) for dz in (-1, 0, 1)]
    for v, (x, y, z) in zip(va, np.floor(va / tol).astype(np.int64)):
        cand = [i for d in near for i in cells.get((x + d[0], y + d[1], z + d[2]), ())]
        if not cand or np.min(np.linalg.norm(vb[cand] - v, axis=1)) > tol:
            return False
    return True


def same_part(a, b):
    """Same geometry to within ~0.001 mm: same triangle count, bounding box, volume and area, and every vertex
    of each file within 0.001 mm of one of the other. OpenSCAD's vertices can move by ~0.0001 mm from one build
    to the next (shifting volume and area by a few thousandths); any real change to a part moves them far more."""
    (na, fa), (nb, fb) = fingerprint(a), fingerprint(b)
    if na != nb or not np.allclose(fa, fb, rtol=1e-5, atol=1e-3):
        return False
    va, vb = vertices(a), vertices(b)
    return len(va) == len(vb) and covered(va, vb) and covered(vb, va)


def export_all():
    print("2/4 Print-ready STLs (export/)...", flush=True)
    with tempfile.TemporaryDirectory() as tmp:
        for name, out, mode in EXPORTS:
            new, dst = Path(tmp) / f"{out}.stl", EXPORT / f"{out}.stl"
            run([sys.executable, str(TOOLS / "export_print.py"), str(BUILD / f"{name}.stl"), str(new)] + ([mode] if mode else []))
            if dst.exists() and same_part(new, dst):
                print(f"    same    {dst.name}")
            else:
                shutil.copyfile(new, dst)
                print(f"    UPDATED {dst.name}")


# ---------- 3-4. animations and the visualizer ----------
def scene(path):
    """The page split into its template text and its scene, with each mesh reduced to a sorted set of triangles."""
    html = path.read_text(encoding="utf-8")
    i = html.find('{"bed"')
    data, end = json.JSONDecoder().raw_decode(html, i)
    for unit in data["units"]:
        for p in unit["pieces"]:
            v = np.frombuffer(base64.b64decode(p.pop("v")), dtype="<i2").reshape(-1, 3)
            f = np.frombuffer(base64.b64decode(p.pop("i")), dtype="<u4" if p.pop("i32") else "<u2").reshape(-1, 3)
            # start every triangle at its smallest corner (keeps the winding), then sort the triangles
            tris = v[f].tolist()                                   # [[corner, corner, corner], ...]
            keys = [min(range(3), key=lambda k: tri[k]) for tri in tris]
            p["tris"] = sorted(tuple(map(tuple, tri[k:] + tri[:k])) for tri, k in zip(tris, keys))
    return html[:i], data, html[end:]


def same_page(a, b):
    return b.exists() and scene(a) == scene(b)


def visualizer_all():
    print("3/4 Assembly animations (animation/)...", flush=True)
    for flags, page, _ in ANIMATIONS:
        print("    " + run([sys.executable, str(TOOLS / "pack_anim.py")] + flags).strip(), flush=True)
    print("4/4 Visualizer pages (visualizer/)...", flush=True)
    for _, page, site in ANIMATIONS:
        src, dst = ANIM / f"{page}.html", SITE / f"{site}.html"
        if same_page(src, dst):
            print(f"    same    {dst.name}")
        else:
            shutil.copyfile(src, dst)
            print(f"    UPDATED {dst.name}")


def main():
    jobs = int(arg("--jobs", os.cpu_count() or 4))
    if "--skip-build" not in sys.argv:
        build_all(jobs)
    export_all()
    visualizer_all()
    if "--renders" in sys.argv:
        print("Renders (screenshots/)...", flush=True)
        subprocess.run([sys.executable, str(TOOLS / "render_site.py")], check=True)
    print("Done. Check `git status` for what changed.")


if __name__ == "__main__":
    main()
