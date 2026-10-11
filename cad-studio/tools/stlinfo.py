"""Print bounding box / triangle count of STL files (binary or ASCII)."""
import struct
import sys
from pathlib import Path


def read_stl(path):
    data = Path(path).read_bytes()
    if len(data) >= 84:
        n = struct.unpack_from("<I", data, 80)[0]
        if 84 + n * 50 == len(data):
            tris = []
            for i in range(n):
                v = struct.unpack_from("<12f", data, 84 + i * 50)
                tris.append((v[3:6], v[6:9], v[9:12]))
            return tris
    verts = []
    for line in data.decode("latin-1").splitlines():
        line = line.strip()
        if line.startswith("vertex"):
            verts.append(tuple(map(float, line.split()[1:4])))
    return [tuple(verts[i:i + 3]) for i in range(0, len(verts) - 2, 3)]


def main():
  for p in sys.argv[1:]:
      tris = read_stl(p)
      pts = [v for t in tris for v in t]
      mn = [min(c[i] for c in pts) for i in range(3)]
      mx = [max(c[i] for c in pts) for i in range(3)]
      size = [mx[i] - mn[i] for i in range(3)]
      print(f"{Path(p).name:48s} tris={len(tris):6d}  min=({mn[0]:8.2f},{mn[1]:8.2f},{mn[2]:8.2f})"
            f"  max=({mx[0]:8.2f},{mx[1]:8.2f},{mx[2]:8.2f})  size=({size[0]:.2f},{size[1]:.2f},{size[2]:.2f})")


if __name__ == '__main__':
    main()
