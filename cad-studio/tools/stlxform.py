"""Apply p' = M p + t to an STL. M given as 9 numbers row-major, t as 3 numbers.

Usage: stlxform.py IN OUT m00 m01 m02 m10 m11 m12 m20 m21 m22 tx ty tz
"""
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from stlinfo import read_stl  # noqa: E402

src, dst = sys.argv[1], sys.argv[2]
m = [float(x) for x in sys.argv[3:12]]
t = [float(x) for x in sys.argv[12:15]]
M = [m[0:3], m[3:6], m[6:9]]
tris = read_stl(src)
out = bytearray(b"\0" * 80 + struct.pack("<I", len(tris)))
for tri in tris:
    out += struct.pack("<3f", 0, 0, 0)
    for v in tri:
        out += struct.pack("<3f", *(sum(M[r][c] * v[c] for c in range(3)) + t[r] for r in range(3)))
    out += b"\0\0"
Path(dst).write_bytes(out)
