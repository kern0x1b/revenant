#!/usr/bin/env python3
"""Check that the engine tree still holds what this port depends on.

    scripts/carry-check.py [manifest]
    scripts/carry-check.py --paths [manifest]
"""
import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT / "webkit-254"
MANIFEST = ROOT / "carry-manifest.txt"
INTEGER = re.compile(r"[+-]?[0-9]+")


def warn(message):
    print("carry-check: " + message, file=sys.stderr)


def git(*args, check=True):
    result = subprocess.run(["git", "-C", str(ENGINE), *args],
                            check=check, capture_output=True, text=True, errors="replace")
    return result.stdout


def read_lines(path):
    try:
        return path.read_text(errors="replace").splitlines()
    except OSError as error:
        warn("cannot read {}: {}".format(path, error.strerror))
        return None


def contains(lines, text):
    return lines is not None and any(text in line for line in lines)


def preference_block(lines, key):
    if lines is None or key not in lines:
        return []
    block = []
    for line in lines[lines.index(key) + 1:]:
        if line == "":
            break
        block.append(line)
    return block


def check_file(path, _):
    if (ENGINE / path).is_file():
        return True, path
    return False, "missing: " + path


def check_grep(path, text):
    source = ENGINE / path
    if source.is_file() and contains(read_lines(source), text):
        return True, "{} contains {}".format(path, text)
    return False, "{} no longer contains: {}".format(path, text)


def check_pref(path, detail):
    key, _, text = detail.partition(" ")
    text = text if text else detail
    source = ENGINE / path
    if source.is_file() and contains(preference_block(read_lines(source), key + ":"), text):
        return True, "{} {} keeps {}".format(path, key, text)
    return False, "{} {} lost: {}".format(path, key, text)


def check_set(path, text):
    if contains(read_lines(ROOT / path), text):
        return True, "{} keeps {}".format(path, text)
    return False, "{} lost: {}".format(path, text)


def check_guard(area, floor):
    count = len(git("grep", "-l", "WEBKIT_IOS6", "--", area, check=False).splitlines())
    if not INTEGER.fullmatch(floor):
        warn("the guard floor for {} is not a whole number: {!r}".format(area, floor))
    elif count >= int(floor):
        return True, "{} carries the guard in {} files (floor {})".format(area, count, floor)
    return False, "{} carries the guard in only {} files, floor is {}".format(area, count, floor)


CHECKS = {
    "file": check_file,
    "grep": check_grep,
    "pref": check_pref,
    "set": check_set,
    "guard": check_guard,
}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("manifest", nargs="?", help="default: carry-manifest.txt at the repository root")
    parser.add_argument("--paths", action="store_true",
                        help="print the engine paths the manifest reads, for a sparse checkout, and check nothing")
    args = parser.parse_args()
    manifest = Path(args.manifest) if args.manifest else MANIFEST

    try:
        directives = manifest.read_text().splitlines()
    except OSError as error:
        warn("cannot read the manifest {}: {}".format(manifest, error.strerror))
        directives = None

    if args.paths:
        if directives is None:
            return 1
        paths = {fields[1] for fields in (directive.split(None, 2) for directive in directives)
                 if len(fields) > 1 and fields[0] in CHECKS and fields[0] != "set"}
        print("\n".join(sorted(paths)))
        return 0

    intact = directives is not None
    checked = 0
    for directive in directives or []:
        fields = directive.split(None, 2)
        kind, target, detail = fields + [""] * (3 - len(fields))
        if kind in ("", "#"):
            continue
        check = CHECKS.get(kind)
        if check:
            passed, message = check(target, detail)
        else:
            passed, message = False, "unknown directive: " + kind
        print("{:<6} {}".format("ok" if passed else "FAIL", message))
        checked += 1
        intact = intact and passed

    if intact and not checked:
        warn("{} names nothing to check".format(manifest))
        intact = False

    print("carry intact" if intact else "CARRY BROKEN - the tree no longer holds what this port depends on")
    return 0 if intact else 1


if __name__ == "__main__":
    sys.exit(main())
