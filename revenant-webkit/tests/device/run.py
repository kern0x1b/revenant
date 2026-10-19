#!/usr/bin/env python3
"""Load every device test page in Safari on the phone and print each verdict.

    tests/device/run.py [HOST]
    tests/device/run.py --port 8898
    TEST_PORT=8898 tests/device/run.py
"""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import time

import harness

PAGES = ["text-and-emoji", "gradients-and-blends", "image-draw-cost", "svg-image-filters", "web-platform", "websocket"]


def final_pattern(page):
    return "^" + re.escape(f"GET /verdicts?page={page}&results=") + "[^&]+.*final=1"


def reported_pattern(page):
    return re.escape(f"GET /verdicts?page={page}")


def warm_pattern(token):
    return re.escape(f"GET /warm-up-state?bridge=yes&token={token}")


class Bridge:
    def __init__(self, server, base):
        self.server = server
        self.base = base
        self.token = 0

    def ensure(self):
        for attempt in (1, 2, 3):
            self.token += 1
            harness.device.open_url(f"{self.base}/warmup.html?token={self.token}")
            if self.server.wait_for(warm_pattern(self.token), 8, 2):
                return True
            print(f"the tweak is not in this Safari; restarting it (attempt {attempt})", file=sys.stderr, flush=True)
            harness.device.restart_safari(12)
        print("giving up on the tweak; the bridges it installs will read as missing", file=sys.stderr, flush=True)
        return False


def problems(server, pages=PAGES):
    found = []
    for page in pages:
        if not server.seen(reported_pattern(page)):
            found.append(f"MISSING {page} reported nothing")
        elif not server.seen(final_pattern(page)):
            found.append(f"PARTIAL {page} stopped before its end - the verdicts below are what it reached")
    return found


def verdict_feed(server):
    return "".join(f"GET {path}\n" for path in server.matching("/verdicts?"))


def run_gate(host: str | None, port: int | None = None) -> int:
    host = host or harness.host_address()
    port = port or int(os.environ.get("TEST_PORT") or 8899)
    base = f"http://{host}:{port}"

    with harness.PageServer(port) as server:
        time.sleep(1)
        harness.device.restart_safari(12)

        bridge = Bridge(server, base)
        for page in PAGES:
            bridge.ensure()
            harness.device.open_url(f"{base}/{page}.html?run={harness.run_token()}")
            server.wait_for(final_pattern(page), 22, 2)

        found = problems(server)
        for line in found:
            print(line, flush=True)

        status = subprocess.run([sys.executable, str(harness.TESTS / "verdicts.py")],
                                input=verdict_feed(server), text=True).returncode
    return 1 if found else status


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("host", nargs="?", help="address the phone reaches this Mac on; default: this Mac's en0")
    parser.add_argument("--port", type=int, help="port the pages are served on; default: TEST_PORT, else 8899")
    parsed = parser.parse_args()
    return run_gate(parsed.host, parsed.port)


if __name__ == "__main__":
    sys.exit(main())
