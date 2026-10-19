#!/usr/bin/env python3
"""Load pages you name in Safari on the phone and report what happened to it.

    tests/device/sweep.py https://example.org/ [more...]
    tests/device/sweep.py                       reads tests/device/sweep-sites.txt

It ships with no list of its own on purpose: which sites this repository may
drive a browser at is the operator's call, not the repository's, and loading
somebody's site from an automated run is between the operator and that site's
terms. tests/device/sweep-sites.txt is gitignored for the same reason.
"""
import argparse
import re
import sys
import time

import harness

device = harness.device

SITES_FILE = harness.TESTS / "sweep-sites.txt"
ROW = "{:<46} {:<6} {:<6} {:<10} {}"
DIRTY = (r'P=$(revpid MobileSafari | sed -n "1s/ .*//p"); '
         r'[ -n "$P" ] && revmem $P | sed -n "s/.*dirty=\([0-9.]*\) MB.*/\1 MB/p"')


def listed_sites(path=SITES_FILE):
    if not path.is_file():
        return []
    return [line for line in path.read_text().splitlines() if line and not line.startswith("#")]


def shot_name(url):
    return re.sub(r"[/?=&+]", "_", re.sub(r"^https?://", "", url))[:46]


def ask(timeout, command):
    return device.output(timeout, command).strip()


def sweep(url):
    device.run(20, "killall MobileSafari 2>/dev/null; rm -f /tmp/rev-safari-stderr.log")
    time.sleep(6)
    device.open_url(url)
    time.sleep(26)

    alive = ask(20, "killall -0 MobileSafari 2>/dev/null && echo 1 || echo 0")
    crashes = ask(20, "grep -c REVCRASH /tmp/rev-safari-stderr.log 2>/dev/null") or "?"
    painted = dirty = "-"
    if alive == "1":
        dirty = ask(30, DIRTY) or "?"
        painted = harness.painted(harness.screenshot(f"{shot_name(url)}.png")) or "?"
    return alive, crashes, painted, dirty


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("sites", nargs="*", help="pages to load; defaults to tests/device/sweep-sites.txt")
    sites = parser.parse_args().sites or listed_sites()
    if not sites:
        parser.print_help(sys.stderr)
        return 2

    harness.SHOTS.mkdir(parents=True, exist_ok=True)
    print(ROW.format("SITE", "ALIVE", "CRASH", "PAINTED", "DIRTY"), flush=True)
    for url in sites:
        print(ROW.format(url, *sweep(url)), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
