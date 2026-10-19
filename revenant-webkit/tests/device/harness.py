"""What every device test page run shares: a local server that remembers what
the phone asked it for, the address the phone reaches it on, and the report a
page sends back."""
import http.server
import random
import re
import socket
import subprocess
import sys
import threading
import time
import urllib.parse
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
TESTS = ROOT / "tests" / "device"
SHOTS = TESTS / "sweep-shots"

_transport = None


def bind(module=None):
    global _transport
    _transport = module if module is not None else _found()
    return _transport


def transport():
    return _transport if _transport is not None else bind()


def __getattr__(name):
    if name == "device":
        return transport()
    raise AttributeError(name)


def _found():
    folder = _shared()
    if not (folder / "device.py").is_file():
        raise SystemExit(f"no device.py in {folder} - has conan config install been run on this machine?")
    if "device" not in sys.modules:
        sys.path.insert(0, str(folder))
    import device
    device.bind(ROOT)
    return device


def _shared():
    home = subprocess.run(["conan", "config", "home"], capture_output=True, text=True)
    if home.returncode:
        raise SystemExit("conan config home failed, so the phone transport cannot be found - "
                         "has conan config install been run on this machine?")
    return Path(home.stdout.strip()) / "extensions" / "charon"


def driver():
    folder = _shared()
    if "charon" not in sys.modules:
        sys.path.insert(0, str(folder))
    import charon
    return charon


def host_address():
    found = subprocess.run(["ipconfig", "getifaddr", "en0"], capture_output=True, text=True).stdout.strip()
    if found:
        return found
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
        try:
            probe.connect(("192.0.2.1", 9))
            return probe.getsockname()[0]
        except OSError:
            return "127.0.0.1"


def run_token():
    return random.randint(0, 32767)


class PageServer:
    def __init__(self, port, directory=TESTS, bind="0.0.0.0"):
        self.port = port
        self.requests = []
        self._lock = threading.Lock()
        server = self

        class Handler(http.server.SimpleHTTPRequestHandler):
            def __init__(self, *args, **kwargs):
                super().__init__(*args, directory=str(directory), **kwargs)

            def log_request(self, code="-", size="-"):
                try:
                    command = getattr(self, "command", None)
                    path = getattr(self, "path", None)
                    if command is None or not isinstance(path, str) or not path.startswith("/"):
                        return
                    with server._lock:
                        server.requests.append(f"{command} {path}")
                except Exception:
                    pass

            def log_message(self, format, *args):
                pass

        try:
            self._httpd = http.server.ThreadingHTTPServer((bind, port), Handler)
        except OSError:
            print(f"port {port} is already serving something else; set TEST_PORT", file=sys.stderr)
            sys.exit(2)
        self._thread = threading.Thread(target=self._httpd.serve_forever, daemon=True)

    def __enter__(self):
        self._thread.start()
        return self

    def __exit__(self, *exc):
        self._httpd.shutdown()
        self._httpd.server_close()

    def lines(self):
        with self._lock:
            return list(self.requests)

    def seen(self, pattern):
        expression = re.compile(pattern)
        return any(expression.search(line) for line in self.lines())

    def wait_for(self, pattern, attempts, interval):
        for _ in range(attempts):
            time.sleep(interval)
            if self.seen(pattern):
                return True
        return False

    def matching(self, prefix):
        return [line.split(" ", 1)[1] for line in self.lines() if line.split(" ", 1)[-1].startswith(prefix)]

    def last_report(self):
        reports = self.matching("/report?")
        if not reports:
            return ""
        query = reports[-1][len("/report?"):]
        return urllib.parse.unquote_plus(query.split("&r=", 1)[0])

    def reports(self):
        return [urllib.parse.unquote_plus(path[len("/report?"):].split("&r=", 1)[0])
                for path in self.matching("/report?")]


def screenshot(name):
    SHOTS.mkdir(parents=True, exist_ok=True)
    target = SHOTS / name
    device.run(25, "shot")
    device.fetch("/tmp/screenshot.png", target)
    return target


def painted(shot, colour=None):
    argv = [sys.executable, str(TESTS / "painted.py"), str(shot)]
    if colour:
        argv.append(colour)
    return subprocess.run(argv, capture_output=True, text=True).stdout.strip()
