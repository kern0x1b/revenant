#!/usr/bin/env python3
"""Compare a build's symbol surface with the one the device last loaded.

    tools/symbol-check.py [--build DIR]           compare against carry-symbols.txt
    tools/symbol-check.py [--build DIR] --pin     make this build the new baseline

A new undefined symbol means an upstream change reached for something iOS 6 may
not have, and dyld kills the process at load with no crash log. An Objective-C
class that stops being exported is the same death from the other side: UIKit and
Safari link those classes by name.
"""
import argparse
import importlib.util
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FRAMEWORKS = ("JavaScriptCore", "WebCore", "WebKitLegacy")
PIN = ROOT / "carry-symbols.txt"
PIN_HEADER = """\
# Symbols this port's frameworks depend on and provide, as of the last
# build known to load on the device. tools/symbol-check.py compares a
# fresh build against this.
#
# undefined <framework> <symbol>  something iOS 6 must already have.
#   A new one means an upstream change reached for API this system may
#   not have, and dyld kills the process at load with no crash log.
# class <framework> <symbol>      an Objective-C class UIKit and Safari
#   link by name. Losing one is the same death, from the other side.
"""


def nm(arguments, binary):
    return subprocess.run(["nm", *arguments, str(binary)], capture_output=True, text=True, check=True).stdout


def surface(build):
    entries = set()
    for framework in FRAMEWORKS:
        binary = build / f"{framework}.framework" / framework
        if not binary.is_file():
            raise SystemExit(f"no build: {binary}")
        entries.update(f"undefined {framework} {line.strip()}" for line in nm(["-u"], binary).splitlines() if line.strip())
        for line in nm(["-gU"], binary).splitlines():
            symbol = line.split()[-1] if line.strip() else ""
            if symbol.startswith("_OBJC_CLASS_$_"):
                entries.add(f"class {framework} {symbol}")
    return entries


def pinned():
    return {line for line in PIN.read_text().splitlines() if line and not line.startswith("#")}


def default_build():
    spec = importlib.util.spec_from_file_location("revenant_harness", ROOT / "tests" / "device" / "harness.py")
    harness = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(harness)
    try:
        return harness.driver().engine_build(ROOT)
    except LookupError as refused:
        raise SystemExit(f"{refused} - or pass --build with the build to check")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--build", type=Path,
                        help="engine build to check; default: the engine build Charon names under build/")
    parser.add_argument("--pin", action="store_true", help="write this build's surface as the baseline")
    args = parser.parse_args()

    current = surface(args.build or default_build())
    if args.pin:
        PIN.write_text(PIN_HEADER + "".join(f"{entry}\n" for entry in sorted(current)))
        print(f"pinned {len(current)} symbols")
        return 0

    baseline = pinned()
    new_imports = sorted(e for e in current - baseline if e.startswith("undefined "))
    lost_classes = sorted(e for e in baseline - current if e.startswith("class "))
    for title, entries in (("new undefined symbols - iOS 6 may not have these", new_imports),
                           ("Objective-C classes no longer exported", lost_classes)):
        if entries:
            print(f"FAIL  {title}:")
            print("\n".join(f"        {entry}" for entry in entries))
        else:
            print(f"ok    no {title.split(' - ')[0]}")
    if new_imports or lost_classes:
        print("SYMBOLS CHANGED - check each against the device, then --pin")
        return 1
    print("symbols intact")
    return 0


if __name__ == "__main__":
    sys.exit(main())
