"""Renders the images of the site and the README (screenshots/*.png) in Blender, from the preview builds.

Usage: python tools/render_site.py [name ...]      (names as in screenshots/, without .png; default: all)
Needs Blender 4.2+ (BLENDER=path/to/blender, default: the 5.2 install) and the preview STLs in build/, which
CAD Studio builds. The colour, material and variant of each part come from the '// color:', '// material:'
and '// variant:' hints at the top of its parts/*.scad, as in the viewer. Blender renders every shot on a
transparent background (tools/render_blender.py); this script crops it, sets it on the card colour of the
site at 4:3 and lays out the sheet of the 2510 fan adapter.
"""
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

import trimesh
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
BUILD, PARTS, OUT = ROOT / "build", ROOT / "parts", ROOT.parent / "screenshots"
BLENDER = os.environ.get("BLENDER", r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe")
BG = (213, 216, 220)        # .card img background on the site
SIZE = (1200, 900)          # final size of the cards (4:3, as the part cards are shown)
ORANGE, GREY = "#e8962e", "#5d636b"


def hints(path):
    h = {"color": "#1d1d1f", "material": "plastic", "variant": ""}
    for line in path.read_text(encoding="utf-8").splitlines()[:6]:
        m = re.match(r"\s*//\s*(color|material|variant):\s*(#[0-9a-fA-F]{6}|\w+(?:[ ,]+\w+)*)", line)
        if m:
            h[m.group(1)] = m.group(2)
    return h


PART = {p.stem: hints(p) for p in sorted(PARTS.glob("*.scad")) if p.stem != "customizer"}


def obj(name, color=None, offset=(0, 0, 0), stl=None, material=None):
    h = PART.get(name, {"color": "#1d1d1f", "material": "plastic"})
    return {"stl": str(stl or BUILD / f"{name}.stl"), "color": color or h["color"],
            "material": material or h["material"], "offset": list(offset)}


def screw(stl, offset=(0, 0, 0)):
    return obj("view_screws", offset=offset, stl=stl)


def variant(v):
    return [obj(n) for n, h in PART.items() if not h["variant"] or v in re.split(r"[\s,]+", h["variant"])]


def screws(tmp):
    """The two M3 that hold the 2510 adapter to the clamp, and the four M2.5 of the fan (from view_screws)."""
    parts = trimesh.load(BUILD / "view_screws.stl", force="mesh").split(only_watertight=False)
    clamp = [p for p in parts if -32 < p.bounds[0][1] and p.bounds[1][1] < -3 and p.bounds[0][2] > 12
             and abs(p.bounds.mean(axis=0)[0]) < 15]
    fan = [p for p in parts if p.bounds[0][1] < -40]
    assert len(clamp) == 2 and len(fan) == 4, (len(clamp), len(fan))
    out = {}
    for name, ps in (("clamp", clamp), ("fan", fan)):
        out[name] = Path(tmp) / f"screws_{name}.stl"
        trimesh.util.concatenate(ps).export(out[name])
    return out


ASM, ASM_FLAT = [-0.55, -1, 0.6], [-0.55, -1, 0.75]
SHOTS = {
    "assembly_normal": ("normal", ASM), "assembly_flat": ("flat", ASM_FLAT),
    "assembly_onepiece": ("onepiece", ASM), "assembly_onepiece_flat": ("onepiece_flat", ASM_FLAT),
    "part_adapter_4010": (["adapter_4010_right"], [-1, -1.1, 0.8]),
    "part_adapter_4010_flat": (["adapter_4010_flat_right"], [-0.8, -1.2, 0.9]),
    "part_duct_4010_led": (["duct_4010_right"], [-1, -1.1, 0.7]),
    "part_duct_4010_led_flat": (["duct_4010_flat_right"], [-0.8, -1.2, 0.8]),
    "part_led_mount": (["led_mount_right"], [-1, -0.7, 0.5]),
    "part_fan_adapter_2510_30": (["fan_adapter_2510_30"], [0.55, -1, 0.5]),
}
SHEET = [   # 2510 adapter: caption, objects, view
    ("1  Fan side (prints face down)", lambda s: [obj("fan_adapter_2510_30")], [0.45, -1, 0.35]),
    ("2  Clamp side: bosses + pins", lambda s: [obj("fan_adapter_2510_30")], [-0.45, 1, 0.35]),
    ("3  Onto the clamp", lambda s: [obj("view_clamp_30", GREY), obj("fan_adapter_2510_30", ORANGE, (0, -16, 0)),
                                     screw(s["clamp"], (0, -50, 0))], [1, -0.75, 0.4]),
    ("4  Mounted with the 2510", lambda s: [obj("view_clamp_30", GREY), obj("fan_adapter_2510_30", ORANGE),
                                            obj("view_fan_2510"), obj("view_fan_2510_rotor"),
                                            screw(s["clamp"]), screw(s["fan"])], [0.6, -1, 0.4]),
]
def finish(src, size, bg=BG, margin=0.08):
    """Frame the parts (not their shadow) in the given size, on the background colour."""
    im = Image.open(src).convert("RGBA")
    x0, y0, x1, y1 = json.loads(Path(src + ".json").read_text())
    w, h = size
    k = min(w * (1 - 2 * margin) / (x1 - x0), h * (1 - 2 * margin) / (y1 - y0))
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    im = im.crop((round(cx - w / 2 / k), round(cy - h / 2 / k), round(cx + w / 2 / k), round(cy + h / 2 / k)))
    im = im.resize(size, Image.LANCZOS)
    # keep the shadow only round the parts: it fades out with the distance from their silhouette
    a = im.getchannel("A")
    near = a.point(lambda v: 255 if v > 240 else 0).filter(ImageFilter.GaussianBlur(0.07 * min(w, h)))
    im.putalpha(ImageChops.multiply(a, near.point(lambda v: min(255, 3 * v))))
    out = Image.new("RGBA", size, bg + (255,))
    out.alpha_composite(im)
    return out.convert("RGB")


def save(im, path):
    """256 colours with dithering: looks the same and weighs about half."""
    im.quantize(colors=256, dither=Image.Dither.FLOYDSTEINBERG).save(path, optimize=True)
    print(Path(path).relative_to(OUT.parent))


def main():
    want = sys.argv[1:]
    tmp = tempfile.mkdtemp(prefix="render_site_")
    s = screws(tmp)
    shots = []
    for name, (what, d) in SHOTS.items():
        if not want or name in want:
            objs = variant(what) if isinstance(what, str) else [obj(n) for n in what]
            shots.append({"name": name, "dir": d, "objects": objs})
    if not want or "fan_adapter_2510_30" in want:
        for i, (cap, objs, d) in enumerate(SHEET):
            shots.append({"name": f"sheet_{i}", "dir": d, "objects": objs(s), "caption": cap})
    for sh in shots:
        sh["out"] = str(Path(tmp) / f"{sh['name']}.png")
    job = Path(tmp) / "job.json"
    job.write_text(json.dumps({"res": [2000, 1500], "samples": 160, "margin": 0.16, "shots": shots}), encoding="utf-8")
    subprocess.run([BLENDER, "-b", "--factory-startup", "-P", str(ROOT / "tools" / "render_blender.py"), "--", str(job)],
                   check=True)
    for sh in shots:
        if not sh["name"].startswith("sheet_"):
            save(finish(sh["out"], SIZE), OUT / f"{sh['name']}.png")
    sheet = [sh for sh in shots if sh["name"].startswith("sheet_")]
    if sheet:
        pw, ph, cap = 700, 525, 46
        out = Image.new("RGB", (2 * pw, 2 * (ph + cap)), BG)
        draw = ImageDraw.Draw(out)
        font = ImageFont.truetype(r"C:\Windows\Fonts\segoeui.ttf", 22)
        for i, sh in enumerate(sheet):
            x, y = (i % 2) * pw, (i // 2) * (ph + cap)
            draw.text((x + 18, y + 12), sh["caption"], fill=(30, 32, 36), font=font)
            out.paste(finish(sh["out"], (pw, ph), margin=0.08), (x, y + cap))
        save(out, OUT / "fan_adapter_2510_30.png")


if __name__ == "__main__":
    main()
