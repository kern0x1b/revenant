#!/usr/bin/env python3
"""Measure how fast a WebGL canvas keeps drawing in Safari on the phone.

    tests/device/gl-frame-rate.py [HOST]
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

    with harness.PageServer(port) as server:
        time.sleep(1)
        device.restart_safari(6)
        device.open_url(f"http://{host}:{port}/gl-frame-rate.html?run={harness.run_token()}")
        server.wait_for("320x480%3D", 40, 3)
        verdict = server.last_report()

    print(f"webgl frame rate: {verdict or 'nothing reported'}")
    return 0 if "320x480=" in verdict else 1


if __name__ == "__main__":
    sys.exit(main())
