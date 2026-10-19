#!/usr/bin/env python3
"""Open navigator.share from a secure page on the phone, then cancel the sheet.

    tests/device/share-sheet.py
    TEST_PORT=8903 tests/device/share-sheet.py
"""
import argparse
import os
import sys
import time

import harness

device = harness.device


def main():
    argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter).parse_args()
    port = int(os.environ.get("TEST_PORT") or 8903)
    harness.SHOTS.mkdir(parents=True, exist_ok=True)

    with harness.PageServer(port, bind="127.0.0.1") as server:
        time.sleep(1)
        device.restart_safari(4)

        tunnel = device.reverse_tunnel(port)
        try:
            time.sleep(3)
            device.open_url(f"http://localhost:{port}/share-sheet.html?run={harness.run_token()}")
            time.sleep(10)
            print(f"on load:   {server.last_report()}", flush=True)

            device.run(20, "/usr/bin/revtouch tap 160 110")
            time.sleep(6)
            harness.screenshot("share-sheet.png")

            device.run(20, "/usr/bin/revtouch tap 160 438")
            time.sleep(6)
            result = server.last_report()
        finally:
            tunnel.terminate()

    print(f"after cancel: {result}")
    return 0 if result == "rejected AbortError" else 1


if __name__ == "__main__":
    sys.exit(main())
