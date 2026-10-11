"""Write a translated copy of an STL: --center puts bbox center XY at origin and min Z at 0, then applies offset.

Usage: stlplace.py IN OUT [dx dy dz] [--keep]   (--keep: don't normalize, only offset)
"""
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from stlinfo import read_stl  # noqa: E402

args = [a for a in sys.argv[1:] if not a.startswith("--")]
keep = "--keep" in sys.argv
src, dst = args[0], args[1]
off = [float(x) for x in args[2:5]] if len(args) >= 5 else [0.0, 0.0, 0.0]
tris = read_stl(src)
pts = [v for t in tris for v in t]
mn = [min(c[i] for c in pts) for i in range(3)]
mx = [max(c[i] for c in pts) for i in range(3)]
base = [0.0, 0.0, 0.0] if keep else [-(mn[0] + mx[0]) / 2, -(mn[1] + mx[1]) / 2, -mn[2]]
shift = [base[i] + off[i] for i in range(3)]
out = bytearray(b"\0" * 80 + struct.pack("<I", len(tris)))
for t in tris:
    out += struct.pack("<3f", 0, 0, 0)
    for v in t:
        out += struct.pack("<3f", *(v[i] + shift[i] for i in range(3)))
    out += b"\0\0"
Path(dst).write_bytes(out)
print(f"{Path(dst).name}: shift=({shift[0]:.2f},{shift[1]:.2f},{shift[2]:.2f})")
