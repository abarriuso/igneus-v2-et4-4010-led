"""Export display-frame STLs as print-ready STLs: optional rotation, then centered on XY with min Z = 0.

Usage: export_print.py IN OUT [lay_on_front | lay_on_min_y | upside_down]
  lay_on_front: rotate (x, y, z) -> (x, z, -y) so the max-Y face ends up on the bed.
  lay_on_min_y: rotate (x, y, z) -> (x, -z, y) so the min-Y face ends up on the bed.
  upside_down:  rotate (x, y, z) -> (x, -y, -z) so the top face ends up on the bed.
"""
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from stlinfo import read_stl  # noqa: E402

src, dst = sys.argv[1], sys.argv[2]
mode = sys.argv[3] if len(sys.argv) > 3 else None
tris = read_stl(src)
if mode == "lay_on_front":
    tris = [tuple((v[0], v[2], -v[1]) for v in t) for t in tris]
elif mode == "lay_on_min_y":
    tris = [tuple((v[0], -v[2], v[1]) for v in t) for t in tris]
elif mode == "upside_down":
    tris = [tuple((v[0], -v[1], -v[2]) for v in t) for t in tris]
elif mode is not None:
    sys.exit(f"unknown mode {mode}")
pts = [v for t in tris for v in t]
mn = [min(p[i] for p in pts) for i in range(3)]
mx = [max(p[i] for p in pts) for i in range(3)]
off = (-(mn[0] + mx[0]) / 2, -(mn[1] + mx[1]) / 2, -mn[2])
out = bytearray(b"\0" * 80 + struct.pack("<I", len(tris)))
for t in tris:
    out += struct.pack("<3f", 0, 0, 0)
    for v in t:
        out += struct.pack("<3f", v[0] + off[0], v[1] + off[1], v[2] + off[2])
    out += b"\0\0"
Path(dst).write_bytes(out)
print(f"{Path(dst).name}: {len(tris)} tris, size {mx[0]-mn[0]:.1f} x {mx[1]-mn[1]:.1f} x {mx[2]-mn[2]:.1f} mm")
