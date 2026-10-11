"""Indexed meshes from STL: weld vertices and split into connected components."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from stlinfo import read_stl  # noqa: E402


def weld(tris, q=1e-4):
    idx, verts, faces = {}, [], []
    for t in tris:
        f = []
        for v in t:
            k = (round(v[0] / q), round(v[1] / q), round(v[2] / q))
            if k not in idx:
                idx[k] = len(verts)
                verts.append(tuple(v))
            f.append(idx[k])
        if len(set(f)) == 3:
            faces.append(tuple(f))
    return verts, faces


def components(verts, faces):
    parent = list(range(len(verts)))

    def root(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a
    for a, b, c in faces:
        ra, rb, rc = root(a), root(b), root(c)
        parent[rb] = ra
        parent[root(rc)] = ra
    groups = {}
    for f in faces:
        groups.setdefault(root(f[0]), []).append(f)
    out = []
    for fs in groups.values():
        used = sorted({i for f in fs for i in f})
        remap = {o: n for n, o in enumerate(used)}
        out.append(([verts[i] for i in used], [tuple(remap[i] for i in f) for f in fs]))
    return out


def bbox(verts):
    mn = [min(v[i] for v in verts) for i in range(3)]
    mx = [max(v[i] for v in verts) for i in range(3)]
    return mn, mx


def load(path):
    return weld(read_stl(path))
