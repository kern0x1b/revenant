#!/usr/bin/env python3
"""Run named tests of the Khronos WebGL conformance suite in Safari on the phone.

    tests/device/conformance.py conformance/rendering/culling.html [more...]
    WEBGL_TESTS=/path/to/sdk/tests HOST_IP=... TEST_PORT=8905 tests/device/conformance.py ...
"""
import argparse
import os
import shutil
import sys
import time
from pathlib import Path

import harness

device = harness.device


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("tests", nargs="*", help="test pages relative to the suite, e.g. conformance/rendering/culling.html")
    names = parser.parse_args().tests

    tests_root = Path(os.environ.get("WEBGL_TESTS") or str(Path.home() / "Git/tools/webgl-conformance/sdk/tests"))
    if not (tests_root / "conformance").is_dir():
        print(f"no conformance suite at {tests_root} - see the header of this script", file=sys.stderr)
        return 2
    if not names:
        print("name at least one test, e.g. conformance/rendering/culling.html", file=sys.stderr)
        return 2

    host = os.environ.get("HOST_IP") or harness.host_address()
    port = int(os.environ.get("TEST_PORT") or 8905)
    tests = ",".join(names)

    runner = tests_root / "conformance-runner.html"
    shutil.copy(str(harness.TESTS / "conformance-runner.html"), str(runner))
    try:
        with harness.PageServer(port, directory=tests_root) as server:
            time.sleep(1)
            device.restart_safari(5)
            device.open_url(f"http://{host}:{port}/conformance-runner.html?tests={tests}&run={harness.run_token()}")
            server.wait_for("RUNNER%20DONE", 90, 5)
            for report in server.reports():
                print(report)
    finally:
        try:
            runner.unlink()
        except OSError:
            pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
