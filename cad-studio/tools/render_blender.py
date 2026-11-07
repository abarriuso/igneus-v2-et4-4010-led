"""Blender side of tools/render_site.py: renders each shot of a job file to an RGBA PNG with Cycles.

Run: blender -b --factory-startup -P tools/render_blender.py -- JOB.json
The parts stand on an invisible shadow catcher on a transparent background; the lights follow the camera,
so every shot is lit the same way whatever the view.
"""
import json
import math
import sys

import bmesh
import bpy
from mathutils import Vector

job = json.load(open(sys.argv[sys.argv.index("--") + 1], encoding="utf-8"))
MM = 0.001   # the STLs are in mm, the scene in m (sensible light and camera ranges)


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def material(color, kind):
    key = f"{color}_{kind}"
    m = bpy.data.materials.get(key)
    if m:
        return m
    m = bpy.data.materials.new(key)
    try:
        m.use_nodes = True
    except Exception:
        pass
    b = m.node_tree.nodes["Principled BSDF"]
    rgb = [srgb_to_linear(int(color[i:i + 2], 16) / 255) for i in (1, 3, 5)]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    if kind == "metal":
        b.inputs["Metallic"].default_value = 1.0
        b.inputs["Roughness"].default_value = 0.3
    else:   # printed PLA / injection-moulded fan plastic
        b.inputs["Roughness"].default_value = 0.42
    return m


meshes = {}


def load(path):
    if path in meshes:
        return meshes[path]
    bpy.ops.object.select_all(action="DESELECT")
    bpy.ops.wm.stl_import(filepath=path, global_scale=MM)
    o = bpy.context.selected_objects[0]
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-7)
    bm.to_mesh(o.data)
    bm.free()
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
    meshes[path] = o
    return o


def look_at(o, target):
    o.rotation_euler = (target - o.location).to_track_quat("-Z", "Y").to_euler()


def area(name, shadow):
    d = bpy.data.lights.new(name, "AREA")
    d.shape = "DISK"
    for owner, attr in ((d, "use_shadow"), (getattr(d, "cycles", None), "cast_shadow")):
        if owner is not None and hasattr(owner, attr):
            setattr(owner, attr, shadow)
    o = bpy.data.objects.new(name, d)
    bpy.context.scene.collection.objects.link(o)
    return o


# ---------- scene ----------
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o, do_unlink=True)
sc = bpy.context.scene
sc.render.engine = "CYCLES"
try:
    prefs = bpy.context.preferences.addons["cycles"].preferences
    prefs.compute_device_type = job.get("device", "HIP")
    prefs.get_devices()
    for d in prefs.devices:
        d.use = d.type != "CPU"
    sc.cycles.device = "GPU" if any(d.use for d in prefs.devices) else "CPU"
except Exception as e:
    print("GPU unavailable, rendering on the CPU:", e)
sc.cycles.samples = job.get("samples", 160)
sc.cycles.use_denoising = True
sc.render.film_transparent = True
sc.render.resolution_x, sc.render.resolution_y = job["res"]
sc.render.resolution_percentage = 100
sc.render.image_settings.file_format = "PNG"
sc.render.image_settings.color_mode = "RGBA"
sc.view_settings.view_transform = "AgX"
sc.view_settings.look = "AgX - Medium High Contrast"

world = bpy.data.worlds.new("studio")
sc.world = world
try:
    world.use_nodes = True
except Exception:
    pass
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.82, 0.84, 0.87, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = job.get("world", 0.85)

cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
sc.collection.objects.link(cam)
sc.camera = cam
key, fill, rim = area("key", True), area("fill", False), area("rim", False)   # one shadow on the floor
ground = bpy.data.objects.new("ground", bpy.data.meshes.new("ground"))
bm = bmesh.new()
bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=1)
bm.to_mesh(ground.data)
bm.free()
sc.collection.objects.link(ground)
ground.is_shadow_catcher = True

for shot in job["shots"]:
    for o in meshes.values():
        o.hide_render = True
    used = []
    for e in shot["objects"]:
        o = load(e["stl"])
        o.hide_render = False
        o.location = Vector(e.get("offset", (0, 0, 0))) * MM
        o.data.materials.clear()
        o.data.materials.append(material(e["color"], e["material"]))
        used.append(o)
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ v.co for o in used for v in o.data.vertices]
    lo = Vector((min(p[i] for p in pts) for i in range(3)))
    hi = Vector((max(p[i] for p in pts) for i in range(3)))
    target = (lo + hi) / 2
    size = (hi - lo).length

    # camera along `dir` (from the part towards the camera), Z up, fitted to the vertices
    d = Vector(shot["dir"]).normalized()
    fwd = -d
    right = fwd.cross(Vector((0, 0, 1))).normalized()
    up = right.cross(fwd)
    cd = cam.data
    cd.lens = shot.get("lens", 70)
    cd.sensor_fit = "HORIZONTAL"
    cd.sensor_width = 36
    tx = 18 / cd.lens
    ty = tx * job["res"][1] / job["res"][0]
    m = 1 - job.get("margin", 0.06)
    rel = [(q.dot(right), q.dot(up), q.dot(d)) for q in (p - target for p in pts)]
    D = max(max(abs(x) / (tx * m) + z, abs(y) / (ty * m) + z) for x, y, z in rel)
    for _ in range(3):   # centre the projection with the lens shift, then tighten the distance
        u = [x / (D - z) for x, y, z in rel]
        v = [y / (D - z) for x, y, z in rel]
        uc, vc = (max(u) + min(u)) / 2, (max(v) + min(v)) / 2
        cd.shift_x, cd.shift_y = uc / (2 * tx), vc / (2 * tx)
        D *= max((max(u) - min(u)) / 2 / (tx * m), (max(v) - min(v)) / 2 / (ty * m))
    cam.location = target + d * D
    look_at(cam, target)
    # where the parts land in the image (pixels), so the shadow does not count when cropping
    W, H = job["res"]
    px = [(x / (D - z) / (2 * tx) - cd.shift_x + 0.5) * W for x, y, z in rel]
    py = [H / 2 - (y / (D - z) / (2 * tx) - cd.shift_y) * W for x, y, z in rel]
    json.dump([min(px), min(py), max(px), max(py)], open(shot["out"] + ".json", "w"))
    cd.clip_start, cd.clip_end = D * 0.02, D * 20

    # lights in the camera's frame: big soft key upper left, fill right, rim behind
    L = size
    for o, dirn, dist, power, s in ((key, -0.6 * right + 1.4 * up + 0.6 * d, 2.2, 14, 1.0),
                                    (fill, 1.0 * right + 0.1 * up + 0.7 * d, 2.6, 8, 1.8),
                                    (rim, 0.4 * right + 0.8 * up - 1.0 * d, 2.2, 10, 1.0)):
        o.location = target + dirn.normalized() * dist * L
        look_at(o, target)
        o.data.size = s * L
        o.data.energy = power * job.get("light", 1.0) * L * L
    ground.location = (target.x, target.y, lo.z - 1e-5)
    ground.scale = (20 * L, 20 * L, 1)

    sc.render.filepath = shot["out"]
    bpy.ops.render.render(write_still=True)
    print("RENDERED", shot["out"])
