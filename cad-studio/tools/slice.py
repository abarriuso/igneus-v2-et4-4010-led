"""Cross-section an STL with an axis-aligned plane; print loops (bbox, area, circle fit) and save a PNG.

Usage: slice.py FILE AXIS VALUE OUT.png [px_per_mm]
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).parent))
from stlinfo import read_stl  # noqa: E402

path, axis, value, out = sys.argv[1], sys.argv[2], float(sys.argv[3]), sys.argv[4]
scale = float(sys.argv[5]) if len(sys.argv) > 5 else 10.0
ai = "xyz".index(axis)
u, v = [i for i in range(3) if i != ai]

tris = np.array(read_stl(path), dtype=float)  # (n,3,3)
d = tris[:, :, ai] - value
d[np.abs(d) < 1e-9] = 1e-9
segs = []
for t, dd in zip(tris, d):
    pts = []
    for i in range(3):
        j = (i + 1) % 3
        if (dd[i] > 0) != (dd[j] > 0):
            k = dd[i] / (dd[i] - dd[j])
            p = t[i] + k * (t[j] - t[i])
            pts.append((p[u], p[v]))
    if len(pts) == 2:
        segs.append(pts)

# chain segments into loops
def key(p):
    return (round(p[0], 3), round(p[1], 3))

adj = {}
for a, b in segs:
    adj.setdefault(key(a), []).append(key(b))
    adj.setdefault(key(b), []).append(key(a))
used = set()
loops = []
for start in list(adj):
    if start in used:
        continue
    loop = [start]
    used.add(start)
    cur = start
    while True:
        nxt = [n for n in adj[cur] if n not in used]
        if not nxt:
            break
        cur = nxt[0]
        used.add(cur)
        loop.append(cur)
    if len(loop) > 2:
        loops.append(np.array(loop))

names = "xyz"
print(f"Section {axis}={value} of {Path(path).name}: {len(segs)} segs, {len(loops)} loops  (coords {names[u]},{names[v]})")
info = []
for i, L in enumerate(loops):
    x, y = L[:, 0], L[:, 1]
    area = 0.5 * np.sum(x * np.roll(y, -1) - np.roll(x, -1) * y)
    cx, cy = x.mean(), y.mean()
    r = np.hypot(x - cx, y - cy)
    circ = r.std() < 0.05 * r.mean() and len(L) > 8
    info.append((abs(area), i))
    tag = f" CIRCLE d={2 * r.mean():.2f} c=({cx:.2f},{cy:.2f})" if circ else ""
    print(f"  loop {i:2d}: n={len(L):4d} area={area:9.2f} bbox {names[u]}[{x.min():.2f},{x.max():.2f}] "
          f"{names[v]}[{y.min():.2f},{y.max():.2f}] size {x.max() - x.min():.2f} x {y.max() - y.min():.2f}{tag}")

if loops:
    allp = np.vstack(loops)
    mn, mx = allp.min(0) - 3, allp.max(0) + 3
    W, H = int((mx[0] - mn[0]) * scale), int((mx[1] - mn[1]) * scale)
    img = Image.new("RGB", (W, H), "white")
    dr = ImageDraw.Draw(img)
    for g in range(int(math.floor(mn[0])), int(math.ceil(mx[0])) + 1):
        X = (g - mn[0]) * scale
        dr.line([(X, 0), (X, H)], fill=(225, 225, 225) if g % 5 else (170, 170, 170) if g % 10 else (110, 110, 110))
        if g % 10 == 0:
            dr.text((X + 2, 2), str(g), fill=(0, 0, 200))
    for g in range(int(math.floor(mn[1])), int(math.ceil(mx[1])) + 1):
        Y = H - (g - mn[1]) * scale
        dr.line([(0, Y), (W, Y)], fill=(225, 225, 225) if g % 5 else (170, 170, 170) if g % 10 else (110, 110, 110))
        if g % 10 == 0:
            dr.text((2, Y + 2), str(g), fill=(0, 0, 200))
    for i, L in enumerate(loops):
        P = [((p[0] - mn[0]) * scale, H - (p[1] - mn[1]) * scale) for p in L]
        dr.line(P + [P[0]], fill=(200, 0, 0), width=2)
        dr.text(P[0], str(i), fill=(0, 120, 0))
    dr.text((W - 120, H - 14), f"{names[u]} -> , {names[v]} ^", fill=(0, 0, 0))
    img.save(out)
