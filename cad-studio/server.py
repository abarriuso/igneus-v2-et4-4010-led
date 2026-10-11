"""CAD Studio: watches parts/*.scad, rebuilds them with OpenSCAD and serves a live 3D viewer.

Usage: python server.py [port]
"""
import json
import os
import queue
import re
import shutil
import subprocess
import sys
import threading
import time
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlparse

ROOT = Path(__file__).resolve().parent
PARTS = ROOT / "parts"
LIB = PARTS / "lib"
REFS = ROOT / "refs"
BUILD = ROOT / "build"
VIEWER = ROOT / "viewer"
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8765


def find_openscad():
    for name in ("openscad.com", "openscad"):
        found = shutil.which(name)
        if found:
            return found
    for base in (os.environ.get("ProgramFiles", r"C:\Program Files"),
                 os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)")):
        for exe in ("openscad.com", "openscad.exe"):
            p = Path(base) / "OpenSCAD" / exe
            if p.exists():
                return str(p)
    sys.exit("OpenSCAD not found")


OPENSCAD = find_openscad()

state_lock = threading.Lock()
parts = {}        # name -> {status, version, log, ms, built_at}
clients = []      # list of queue.Queue for SSE
build_queue = queue.Queue()


def broadcast(event):
    data = json.dumps(event)
    with state_lock:
        for q in list(clients):
            q.put(data)


def part_hints(src):
    """Optional '// color: #rrggbb', '// material: metal|plastic' and '// variant: normal|flat' in the first lines."""
    hints = {"color": None, "material": None, "variant": None}
    try:
        for line in src.read_text(encoding="utf-8", errors="replace").splitlines()[:6]:
            m = re.match(r"\s*//\s*(color|material|variant):\s*(#[0-9a-fA-F]{6}|\w+)", line)
            if m:
                hints[m.group(1)] = m.group(2)
    except OSError:
        pass
    return hints


def build(name):
    src = PARTS / f"{name}.scad"
    if not src.exists():
        return
    with state_lock:
        info = parts.setdefault(name, {"version": 0})
        info["status"] = "building"
        info.update(part_hints(src))
    broadcast({"type": "building", "part": name})

    tmp = BUILD / f"{name}.tmp.stl"
    t0 = time.time()
    try:
        proc = subprocess.run(
            [OPENSCAD, "-o", str(tmp), "--export-format", "binstl", str(src)],
            capture_output=True, timeout=600, cwd=str(PARTS))
        log = (proc.stdout + proc.stderr).decode("utf-8", errors="replace")
        ok = proc.returncode == 0 and tmp.exists() and tmp.stat().st_size > 84
        if "Can't open import file" in log:   # a missing original part gives wrong geometry, not an empty one
            ok = False
            log += ("\n(Original Igneus files missing: download them as explained in igneus/README.md"
                    " and run tools/place_originals.py.)")
    except subprocess.TimeoutExpired:
        log, ok = "Timeout: the build took longer than 10 minutes.", False
    ms = int((time.time() - t0) * 1000)

    if ok:
        os.replace(tmp, BUILD / f"{name}.stl")
    elif tmp.exists():
        tmp.unlink()
    if not ok and "ERROR" not in log and "WARNING" not in log:
        log += "\n(No geometry: the model is empty or the export failed.)"

    with state_lock:
        info = parts[name]
        info.update(status="ok" if ok else "error", log=log.strip(), ms=ms, built_at=time.time())
        if ok:
            info["version"] += 1
        event = {"type": "build", "part": name, **info}
    (BUILD / f"{name}.log").write_text(log, encoding="utf-8")
    print(f"[{time.strftime('%H:%M:%S')}] {name}: {'OK' if ok else 'ERROR'} ({ms} ms)", flush=True)
    broadcast(event)


def builder():
    while True:
        name = build_queue.get()
        # Collapse duplicate requests queued while a build was running.
        pending = {name}
        while not build_queue.empty():
            pending.add(build_queue.get())
        for n in sorted(pending):
            build(n)


def scan(folder, pattern):
    return {p: p.stat().st_mtime for p in folder.glob(pattern)} if folder.exists() else {}


def watcher():
    seen_parts, seen_lib, seen_refs = {}, {}, {}
    while True:
        cur_parts = scan(PARTS, "*.scad")
        cur_lib = scan(LIB, "**/*.scad")
        cur_refs = scan(REFS, "*.stl")

        removed = set(seen_parts) - set(cur_parts)
        for p in removed:
            with state_lock:
                parts.pop(p.stem, None)
            broadcast({"type": "removed", "part": p.stem})

        lib_changed = seen_lib and cur_lib != seen_lib
        for p, mtime in cur_parts.items():
            if lib_changed or seen_parts.get(p) != mtime:
                build_queue.put(p.stem)
        if cur_refs != seen_refs and seen_refs is not None:
            broadcast({"type": "refs", "refs": sorted(p.name for p in cur_refs)})

        seen_parts, seen_lib, seen_refs = cur_parts, cur_lib, cur_refs
        time.sleep(0.4)


class Server(ThreadingHTTPServer):
    daemon_threads = True

    def handle_error(self, request, client_address):
        # Browsers drop SSE/keep-alive sockets all the time; don't spam the log with those.
        if isinstance(sys.exc_info()[1], (ConnectionAbortedError, ConnectionResetError, BrokenPipeError)):
            return
        super().handle_error(request, client_address)


class Handler(SimpleHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def send_json(self, obj):
        body = json.dumps(obj).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def send_file(self, path, ctype):
        if not path.is_file():
            self.send_error(404)
            return
        data = path.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        path = unquote(urlparse(self.path).path)
        if path in ("/", "/index.html"):
            return self.send_file(VIEWER / "index.html", "text/html; charset=utf-8")
        if path == "/api/state":
            with state_lock:
                snapshot = {k: dict(v) for k, v in parts.items()}
            refs = sorted(p.name for p in REFS.glob("*.stl")) if REFS.exists() else []
            return self.send_json({"parts": snapshot, "refs": refs, "openscad": OPENSCAD})
        if path == "/events":
            return self.stream_events()
        for prefix, folder, ctype in (("/build/", BUILD, "model/stl"),
                                      ("/refs/", REFS, "model/stl"),
                                      ("/src/", PARTS, "text/plain; charset=utf-8"),
                                      ("/animation/", ROOT / "animation", "text/html; charset=utf-8"),
                                      ("/media/", ROOT.parent / "media", "video/mp4")):
            if path.startswith(prefix):
                target = (folder / path[len(prefix):]).resolve()
                if folder.resolve() not in target.parents:
                    return self.send_error(403)
                return self.send_file(target, ctype)
        self.send_error(404)

    def stream_events(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Connection", "keep-alive")
        self.end_headers()
        q = queue.Queue()
        with state_lock:
            clients.append(q)
        try:
            while True:
                try:
                    data = q.get(timeout=15)
                    self.wfile.write(f"data: {data}\n\n".encode())
                except queue.Empty:
                    self.wfile.write(b": ping\n\n")
                self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError, OSError):
            pass
        finally:
            with state_lock:
                if q in clients:
                    clients.remove(q)


def main():
    for d in (PARTS, LIB, REFS, BUILD):
        d.mkdir(parents=True, exist_ok=True)
    threading.Thread(target=builder, daemon=True).start()
    threading.Thread(target=watcher, daemon=True).start()
    server = Server(("127.0.0.1", PORT), Handler)
    print(f"CAD Studio at http://localhost:{PORT}  (OpenSCAD: {OPENSCAD})", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
