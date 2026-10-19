#!/usr/bin/env python3
"""Verify the trust store the standalone application carries.

    scripts/check-cacert.py [--upstream]
"""
import argparse
import hashlib
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUNDLE = ROOT / "app" / "cacert.pem"
EXPECTED = "f66dff1bdf8f96060b8177976f8b7d9254bc89bc4db933d769f7384d28480bc9"
UPSTREAM = "https://curl.se/ca/cacert.pem"


def warn(message):
    print(message, file=sys.stderr)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--upstream", action="store_true",
                        help="also compare the bundle with what {} serves today".format(UPSTREAM))
    args = parser.parse_args()

    try:
        actual = hashlib.sha256(BUNDLE.read_bytes()).hexdigest()
    except OSError as error:
        warn("check-cacert: cannot read {}: {}".format(BUNDLE, error.strerror))
        return 1
    if actual != EXPECTED:
        warn("app/cacert.pem is not the reviewed bundle")
        warn("  expected " + EXPECTED)
        warn("  found    " + actual)
        return 1
    print("app/cacert.pem matches the reviewed bundle ({})".format(EXPECTED))

    if not args.upstream:
        return 0
    try:
        with urllib.request.urlopen(UPSTREAM) as response:
            remote = hashlib.sha256(response.read()).hexdigest()
    except OSError as error:
        warn("check-cacert: could not download {}: {}".format(UPSTREAM, error))
        return 1
    if remote == actual:
        print("and it is byte-for-byte what {} serves today".format(UPSTREAM))
    else:
        print("{} now serves a different extract ({}).".format(UPSTREAM, remote))
        print("A trust store changes only after somebody reads the change:")
        print("  1. diff the two files and see which authorities moved")
        print("  2. replace app/cacert.pem")
        print("  3. put the new hash in EXPECTED above, in the same commit")
    return 0


if __name__ == "__main__":
    sys.exit(main())
