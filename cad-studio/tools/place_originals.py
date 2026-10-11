"""Places Locos3D's original Igneus V2 parts where the OpenSCAD sources expect them.

The original files are not part of this repository. Download the Igneus V2 pack from
https://www.thingiverse.com/thing:4178590 (Locos3D, CC BY-NC-SA 4.0), put these files in cad-studio/igneus/:

    Tobera_5015_V2.stl  Adapter_4010_to_5015_V2.stl  Igneus_Version1_Rev.3.stl  Abrazadera_Adapter_Fan_30mm.stl

and run:  python3 tools/place_originals.py

It writes, in the assembly ("view") frame used by every part in parts/:
    igneus/asm/duct_5015.stl          5015 duct, right side (used to build the adapter and the LED mount)
    igneus/asm/adapter_4010_v2.stl    original 4010 adapter V2, right side (base of the improved adapter)
    igneus/view/body_v1_v6.stl        Igneus body for the E3D V6 (preview only)
    igneus/view/clamp_fan30.stl       front clamp with the 30 mm fan mount (preview only)
    igneus/view/original_ducts.stl    both 5015 ducts, right and mirrored left (preview only)
"""
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from stlinfo import read_stl  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SRC = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "igneus"

# p' = M p + t, found by matching the original files to the positions the parts were designed in
DUCT = ("Tobera_5015_V2.stl", [[1, 0, 0], [0, 0, -1], [0, 1, 0]], [-344.0, 0.0, 168.375])
PLACES = {
    "asm/duct_5015.stl": DUCT,
    "asm/adapter_4010_v2.stl": ("Adapter_4010_to_5015_V2.stl", [[1, 0, 0], [0, 1, 0], [0, 0, 1]], [-230.66402, 64.729, -58.243]),
    "view/body_v1_v6.stl": ("Igneus_Version1_Rev.3.stl", [[1, 0, 0], [0, 1, 0], [0, 0, 1]], [-130.232, 30.8005, -58.849]),
    "view/clamp_fan30.stl": ("Abrazadera_Adapter_Fan_30mm.stl", [[-1, 0, 0], [0, 0, 1], [0, 1, 0]], [137.198, -27.06, 58.311]),
}
DUCT_X = 36.05   # the right duct sits 36.05 mm off the nozzle axis; the left one is its mirror


def place(tris, m, t):
    return [tuple(tuple(sum(m[i][k] * v[k] for k in range(3)) + t[i] for i in range(3)) for v in tri) for tri in tris]


def write(path, tris):
    path.parent.mkdir(parents=True, exist_ok=True)
    out = bytearray(b"\0" * 80 + struct.pack("<I", len(tris)))
    for tri in tris:
        out += struct.pack("<3f", 0, 0, 0)
        for v in tri:
            out += struct.pack("<3f", *v)
        out += b"\0\0"
    path.write_bytes(out)
    print(f"{path.relative_to(ROOT)}: {len(tris)} triangles")


missing = [name for name, _, _ in PLACES.values() if not (SRC / name).exists()]
if missing:
    sys.exit("Missing original files in %s: %s\nDownload them from https://www.thingiverse.com/thing:4178590"
             % (SRC, ", ".join(sorted(set(missing)))))
(ROOT / "build").mkdir(exist_ok=True)   # where the OpenSCAD parts are built next
for dst, (name, m, t) in PLACES.items():
    write(ROOT / "igneus" / dst, place(read_stl(SRC / name), m, t))

right = place(read_stl(SRC / DUCT[0]), DUCT[1], [DUCT[2][0] + DUCT_X, DUCT[2][1], DUCT[2][2]])
left = [tuple((-v[0], v[1], v[2]) for v in reversed(tri)) for tri in right]   # mirror keeps the normals outward
write(ROOT / "igneus" / "view" / "original_ducts.stl", right + left)
