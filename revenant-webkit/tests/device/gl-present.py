#!/usr/bin/env python3
"""Check that a WebGL canvas the GPU drew actually reaches the screen.

    tests/device/gl-present.py [HOST]
"""
import argparse
import os
import sys
import time

import harness

device = harness.device


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("host", nargs="?", help="address the phone reaches this Mac on; default: this Mac's en0")
    host = parser.parse_args().host or harness.host_address()
    port = int(os.environ.get("TEST_PORT") or 8899)
    harness.SHOTS.mkdir(parents=True, exist_ok=True)

    with harness.PageServer(port):
        time.sleep(1)
        device.restart_safari(6)
        device.open_url(f"http://{host}:{port}/gl-present.html?run={harness.run_token()}")
        time.sleep(14)
        shot = harness.screenshot("gl-present.png")

    red = harness.painted(shot, "255,0,0")
    print(f"webgl canvas on screen: {red or '?'}")
    return 1 if red in ("absent", "", "no shot", "no PIL") else 0


if __name__ == "__main__":
    sys.exit(main())
