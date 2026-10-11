"""Packs the preview parts (build/*.stl) for the three.js assembly animation.

Usage: pack_anim.py [--flat]  ->  writes animation/assembly.html (or assembly_flat.html) from animation/template.html
  --flat: the flat variant (blowers on top of the adapters, intake to the front, no blower ear screw)
Each unit carries its meshes (int16 relative to its centre, 1/200 mm), its assembly step and the
explode vector it flies in from. Impellers and rotors are tagged so they spin at the end.
"""
import base64
import json
import math
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from meshes import bbox, components, load  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / "build"
Q = 200.0
FLAT = "--flat" in sys.argv
V = "_flat" if FLAT else ""   # suffix of the variant-specific parts
BLACK, ALU, STEEL, BRASS, SCREW, FAN, LED = "#1d1d1f", "#cfd3d8", "#9aa0a6", "#c9a24a", "#b9bec4", "#0e0e0f", "#f2f1ec"

STEPS = [
    ("Igneus V2 body", "Printed body for the E3D V6"),
    ("E3D V6 heatsink", "Slides into the body from the front"),
    ("Heater block", "Threads onto the heatbreak"),
    ("Heater cartridge", "Slides into the block from the side"),
    ("Nozzle", "Screws in from below"),
    ("Front clamp", "Locks the V6 against the body"),
    ("Original 5015 ducts", "One on each side"),
    ("Duct M3 screws and nuts", "One per side, through the height slot into the body"),
    ("LED mounts", "Rest on the inner face of each duct"),
    ("LED strips", "2 LEDs per side, 24 V in parallel"),
    ("4010 adapters", "Into the duct socket, fan cradle on top"),
] + ([
    ("4010 blowers", "Stock Ender 3 fans on top, intake to the front"),
] if FLAT else [
    ("Adapter M3 screws", "Flat head, adapter arm + duct ear, with a nut"),
    ("4010 blowers", "Stock Ender 3 part-cooling fans, push-fit in the cradles"),
]) + [
    ("25 → 30 mm fan adapter", "Held by the clamp's own M3 screws"),
    ("2510 hotend fan", "Kobra X fan, 4 × self-tapping M2.5"),
]


def meshes_of(name, keep=None):
    v, f = load(BUILD / f"{name}.stl")
    out = []
    for cv, cf in components(v, f):
        mn, mx = bbox(cv)
        c = [(a + b) / 2 for a, b in zip(mn, mx)]
        if keep is None or keep(c, [b - a for a, b in zip(mn, mx)]):
            out.append((cv, cf))
    return out


def merge(parts):
    verts, faces = [], []
    for cv, cf in parts:
        o = len(verts)
        verts += cv
        faces += [(a + o, b + o, c + o) for a, b, c in cf]
    return verts, faces


def b64(b):
    return base64.b64encode(b).decode()


def piece(parts, color, metal=False, role=None):
    verts, faces = merge(parts)
    mn, mx = bbox(verts)
    c = [(a + b) / 2 for a, b in zip(mn, mx)]
    vb = struct.pack(f"<{len(verts) * 3}h", *[round((p[i] - c[i]) * Q) for p in verts for i in range(3)])
    fmt = "H" if len(verts) < 65536 else "I"
    ib = struct.pack(f"<{len(faces) * 3}{fmt}", *[i for t in faces for i in t])
    return {"c": [round(x, 3) for x in c], "v": b64(vb), "i": b64(ib), "i32": fmt == "I",
            "color": color, "metal": metal, "role": role, "_bb": (mn, mx)}


side = lambda s: (lambda c, d: c[0] * s > 0)  # noqa: E731
units = []


def unit(step, name, pieces, dir_, dist, spin=None, delay=0.0, thread=None):
    """thread: for screws, nuts and the nozzle, the last mm they travel while turning (screwed in)."""
    n = math.sqrt(sum(x * x for x in dir_))
    units.append({"step": step, "name": name, "pieces": pieces,
                  "dir": [x / n for x in dir_], "dist": dist, "spin": spin, "delay": delay, "thread": thread})


def screws(keep):
    return meshes_of("view_screws" + V, keep)


# 1-6: body and hotend
unit(1, "body", [piece(meshes_of("view_igneus_body"), BLACK)], [0, 0.3, 1], 110)
unit(2, "heatsink", [piece(meshes_of("view_v6_heatsink"), ALU, True)], [0, -1, 0.15], 100)
unit(3, "block", [piece(meshes_of("view_v6_heater_block"), ALU, True)], [0, 0, -1], 70)
unit(4, "cartridge", [piece(meshes_of("view_v6_heater_cartridge"), STEEL, True)], [1, 0, 0], 70)
unit(5, "nozzle", [piece(meshes_of("view_v6_nozzle"), BRASS, True)], [0, 0, -1], 45, spin=[0, 0, 1, 4], thread=6)
unit(6, "clamp", [piece(meshes_of("view_clamp_30"), BLACK)], [0, -1, 0], 100)
# 7-8: ducts and through bolt
for s in (1, -1):
    unit(7, f"duct{s}", [piece(meshes_of("view_original_ducts", side(s)), BLACK)], [s, 0, 0.25], 100,
         delay=0.15 if s < 0 else 0)
for s in (1, -1):
    d = 0.15 if s < 0 else 0
    # the nut drops into the body's nut pocket, then the screw goes through the duct's height slot into it
    unit(8, f"duct_nut{s}", [piece(meshes_of("view_nuts" + V, lambda c, d, s=s: c[2] < 25 and c[0] * s > 0), SCREW, True)],
         [0, 0, 1], 30, delay=d)
    unit(8, f"duct_m3{s}", [piece(screws(lambda c, d, s=s: abs(c[2] - 19.39) < 1 and c[0] * s > 0), SCREW, True)],
         [s, 0, 0], 45, spin=[1, 0, 0, -5 * s], delay=d + 0.3, thread=14)
# 9-10: LEDs
for s in (1, -1):
    sfx = "right" if s > 0 else "left"
    unit(9, f"led_mount{s}", [piece(meshes_of(f"led_mount_{sfx}"), BLACK)], [-0.25 * s, 0, -1], 80,
         delay=0.15 if s < 0 else 0)
    unit(10, f"strip{s}", [piece(meshes_of("view_led_strips", side(s)), LED, role="led")], [-0.3 * s, 0, -1], 95,
         delay=0.15 if s < 0 else 0)
# 11-13: adapters and blowers (the flat variant has no blower screw, so the hotend fan steps move up by one)
for s in (1, -1):
    sfx = "right" if s > 0 else "left"
    d = 0.15 if s < 0 else 0
    blower = [piece(meshes_of("view_blowers_4010" + V, side(s)), FAN),
              piece(meshes_of("view_blower_4010_rotors" + V, side(s)), "#2a2a2d", role="impeller")]
    if FLAT:   # the adapter comes down onto the duct, then the blower drops into its cradle from above
        unit(11, f"adapter{s}", [piece(meshes_of(f"adapter_4010_flat_{sfx}"), BLACK)], [0.4 * s, -0.3, 1], 100, delay=d)
        unit(12, f"blower{s}", blower, [0.25 * s, -0.5, 1], 120, delay=d)
        continue
    unit(11, f"adapter{s}", [piece(meshes_of(f"adapter_4010_{sfx}"), BLACK)], [s, -0.5, -0.2], 100, delay=d)
    unit(13, f"blower{s}", blower, [s, -0.4, 0.35], 120, delay=d)   # covers the flat-head screw
    # the nut sits in its trap first, then the screw is driven into it
    unit(12, f"blower_nut{s}", [piece(meshes_of("view_nuts", lambda c, d, s=s: c[2] > 25 and c[0] * s > 0),
                                      SCREW, True)], [0, -1, 0.2], 35, delay=d)
    unit(12, f"blower_m3{s}", [piece(screws(lambda c, d, s=s: c[2] > 30 and c[0] * s > 0), SCREW, True)],
         [s, 0, 0], 45, spin=[1, 0, 0, -5 * s], delay=d + 0.3, thread=10)
# 14-15 (13-14 in the flat variant): hotend fan
F = 13 if FLAT else 14
unit(F, "fan_adapter", [piece(meshes_of("fan_adapter_2510_30"), BLACK)], [0, -1, 0.1], 90)
for x in (-11, 11):
    unit(F, f"clamp_m3{x}", [piece(screws(lambda c, d, x=x: abs(c[2] - 15.65) < 1 and c[0] * x > 0),
                                    SCREW, True)], [0, -1, 0], 45, spin=[0, 1, 0, -5], delay=0.35, thread=12)
unit(F + 1, "fan_2510", [piece(meshes_of("view_fan_2510"), FAN),
                      piece(meshes_of("view_fan_2510_rotor"), "#2a2a2d", role="rotor")], [0, -1, 0], 110)
for i, (x, z) in enumerate([(-10, -15.05), (10, -15.05), (-10, 4.95), (10, 4.95)]):
    unit(F + 1, f"m25_{i}", [piece(screws(lambda c, d, x=x, z=z: c[1] < -30 and abs(c[0] - x) < 1
                                       and abs(c[2] - z) < 1), SCREW, True)],
         [0, -1, 0], 40, spin=[0, 1, 0, -5], delay=0.35 + 0.08 * i, thread=10)

# every piece found geometry, and no screw is left unassigned
for u in units:
    for p in u["pieces"]:
        assert p["v"], u["name"]
used = sum(1 for u in units if u["name"].startswith(("duct_m3", "blower_m3", "clamp_m3", "m25_")))
assert used == (2 + 2 + 4 if FLAT else 2 + 2 + 2 + 4), used
assert len(components(*load(BUILD / f"view_screws{V}.stl"))) == (8 if FLAT else 10)

# LED wiring, both strips in parallel on one 24 V connector behind the body (view frame).
# Each wire leaves the back end of its strip (behind the duct, y > 0), climbs between the duct and the
# body and runs above the body to the connector. + and - run side by side, 0.8 mm off the centre line.
JUNCTION = [0, 11.5, 40.5]
ROUTE = [  # right-hand centre line, strip end -> connector
    ([27.0, -2.0, -20.5], "z"), ([27.0, 3.0, -20.5], "z"), ([27.5, 5.5, -14.0], "x"), ([27.5, 7.0, 5.0], "x"),
    ([27.0, 9.0, 30.0], "x"), ([22.0, 10.5, 38.5], "z"), ([8.0, 11.5, 40.5], "z"), ([4.2, 11.5, 40.5], "z"),
]
SUPPLY = [([0, 11.5, 44.5], "x"), ([0, 13.5, 50.0], "x"), ([0, 21.0, 57.0], "x"), ([0, 30.0, 61.0], "x")]


# Both 4010 blowers in parallel on the part-cooling fan output: each lead leaves the top of its blower scroll,
# runs above the duct and the body and meets the other one in a second connector above the body.
FAN_JUNCTION = [0, -4, 52]
FAN_ROUTE = [  # right-hand centre line, blower -> connector
    ([40.6, -24.0, 42.5], "x"), ([40.6, -22.0, 46.5], "x"), ([36.0, -14.0, 50.0], "y"), ([20.0, -6.0, 52.0], "y"),
    ([6.0, -4.0, 52.0], "y"), ([4.6, -4.0, 52.0], "y"),
]
if FLAT:   # the blowers sit lower and further out: their leads leave the top of the fan, then the same way in
    FAN_ROUTE = [
        ([41.0, -14.4, 32.6], "y"), ([41.0, -14.4, 36.0], "y"), ([34.0, -11.0, 44.0], "y"), ([20.0, -6.0, 52.0], "y"),
        ([6.0, -4.0, 52.0], "y"), ([4.6, -4.0, 52.0], "y"),
    ]
FAN_SUPPLY = [([0, -4, 56.5], "x"), ([-3, -2, 61], "x"), ([-12, 3, 64], "z"), ([-26, 8, 65], "z")]


def wire(route, s, pol):
    out = []
    for (x, y, z), ax in route:
        o = 0.8 * pol * (s if ax == "x" else 1)
        out.append([round(s * x + (o if ax == "x" else 0), 2), round(y + (o if ax == "y" else 0), 2),
                    round(z + (o if ax == "z" else 0), 2)])
    return out


def circuit(junction, route, supply):
    return {"junction": junction,
            "branches": [{"side": s, "plus": wire(route, s, 1), "minus": wire(route, s, -1)} for s in (1, -1)],
            "supply": {"plus": wire(supply, 1, 1), "minus": wire(supply, 1, -1)}}


wiring = circuit(JUNCTION, ROUTE, SUPPLY)
fan_wiring = circuit(FAN_JUNCTION, FAN_ROUTE, FAN_SUPPLY)

# Airflow: duct outlets (inner bottom edge of each duct), blower intakes (outer face) and the 2510 intake
airflow = {"duct": {"x": 23.8, "y": [-25.0, -3.0], "z": -36.8, "to": [2.0, -14.06, -40.5]},
           "blower": ({"y": -19.4, "c": [56.65, 12.15], "r": 12.0} if FLAT          # front face, axis (x, z)
                      else {"x": 45.62, "c": [-29.46, 24.55], "r": 12.0}),             # outer face, axis (y, z)
           "fan2510": {"y": -41.06, "c": [0.0, -5.05], "r": 11.0}}

# ---------- kit layout: every unit lies on a textured PEI bed before it flies into place ----------
Z_BED = -80.0
I3 = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
RX = [[1, 0, 0], [0, 0, -1], [0, 1, 0]]   # +90 deg about X: y -> z
RY = [[0, 0, -1], [0, 1, 0], [1, 0, 0]]   # -90 deg about Y: x -> z
RZ = [[0, -1, 0], [1, 0, 0], [0, 0, 1]]   # +90 deg about Z


def mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def apply(m, v):
    return [sum(m[i][k] * v[k] for k in range(3)) for i in range(3)]


def quat(m):
    tr = m[0][0] + m[1][1] + m[2][2]
    if tr > 0:
        w = math.sqrt(1 + tr) / 2
        return [(m[2][1] - m[1][2]) / (4 * w), (m[0][2] - m[2][0]) / (4 * w), (m[1][0] - m[0][1]) / (4 * w), w]
    i = max(range(3), key=lambda k: m[k][k])
    j, k = (i + 1) % 3, (i + 2) % 3
    r = math.sqrt(1 + m[i][i] - m[j][j] - m[k][k])
    q = [0, 0, 0, 0]
    q[i] = r / 2
    q[j] = (m[j][i] + m[i][j]) / (2 * r)
    q[k] = (m[k][i] + m[i][k]) / (2 * r)
    q[3] = (m[k][j] - m[j][k]) / (2 * r)
    return q


for u in units:
    u["pivot"] = [round(sum(p["c"][i] for p in u["pieces"]) / len(u["pieces"]), 3) for i in range(3)]
    mn = [min(p["_bb"][0][i] for p in u["pieces"]) - u["pivot"][i] for i in range(3)]
    mx = [max(p["_bb"][1][i] for p in u["pieces"]) - u["pivot"][i] for i in range(3)]
    size = [b - a for a, b in zip(mn, mx)]
    flat = min(range(3), key=lambda i: size[i])          # thinnest side goes down
    rot = [RY, RX, I3][flat]
    corners = [apply(rot, [x, y, z]) for x in (mn[0], mx[0]) for y in (mn[1], mx[1]) for z in (mn[2], mx[2])]
    rmn = [min(c[i] for c in corners) for i in range(3)]
    rmx = [max(c[i] for c in corners) for i in range(3)]
    if rmx[1] - rmn[1] > rmx[0] - rmn[0]:                 # long side across the bed
        rot = mul(RZ, rot)
        corners = [apply(RZ, c) for c in corners]
        rmn = [min(c[i] for c in corners) for i in range(3)]
        rmx = [max(c[i] for c in corners) for i in range(3)]
    u["_lay"] = (rot, rmn, rmx)
    for p in u["pieces"]:
        del p["_bb"]

GAP, ROW_W = 10.0, 250.0
rows, row, x = [], [], 0.0
big = [u for u in units if not u["thread"]]
hardware = [u for u in units if u["thread"]]
for group, gap in ((big, GAP), (hardware, 6.0)):
    for u in group:
        rot, rmn, rmx = u["_lay"]
        w = rmx[0] - rmn[0]
        if row and x + w > ROW_W:
            rows.append(row); row, x = [], 0.0
        row.append((u, x, w)); x += w + gap
    rows.append(row); row, x = [], 0.0
depths = [max(u["_lay"][2][1] - u["_lay"][1][1] for u, _, _ in r) for r in rows]
total_d = sum(depths) + GAP * (len(rows) - 1)
y = -20 + total_d / 2                                   # first rows at the back, hardware at the front
bed_x = [1e9, -1e9]
for r, dpt in zip(rows, depths):
    width = r[-1][1] + r[-1][2]
    cy = y - dpt / 2
    for u, x0, w in r:
        rot, rmn, rmx = u["_lay"]
        cx = -width / 2 + x0 + w / 2
        pos = [cx - (rmn[0] + rmx[0]) / 2, cy - (rmn[1] + rmx[1]) / 2, Z_BED - rmn[2]]
        u["bed"] = {"p": [round(v, 3) for v in pos], "q": [round(v, 6) for v in quat(rot)]}
        bed_x = [min(bed_x[0], cx - w / 2), max(bed_x[1], cx + w / 2)]
        del u["_lay"]
    y -= dpt + GAP
bed = {"z": Z_BED, "x": [round(bed_x[0] - 16, 1), round(bed_x[1] + 16, 1)],
       "y": [round(y + GAP - 16, 1), round(-20 + total_d / 2 + 16, 1)]}

scene = {"bed": bed, "steps": [{"title": t, "detail": d} for t, d in STEPS], "units": units,
         "leds": {"x": 27.25, "ys": [-9.55, -27.65], "z": -20.5, "dir": [-0.966, 0, -0.259]},
         "wiring": wiring, "fan_wiring": fan_wiring, "airflow": airflow, "impeller_axis": "y" if FLAT else "x"}
template = (ROOT / "animation" / "template.html").read_text(encoding="utf-8")
html = template.replace("/*SCENE*/null", json.dumps(scene, separators=(",", ":")))
dst = ROOT / "animation" / f"assembly{V}.html"
dst.write_text(html, encoding="utf-8")
print(f"{dst.name}: {len(units)} units, {len(html) / 1e6:.2f} MB")
