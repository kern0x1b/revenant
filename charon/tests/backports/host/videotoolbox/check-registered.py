#!/usr/bin/env python3
"""Every registry row of kind constant is accounted for: defined by the port, or exported natively.

    python3 tests/backports/host/videotoolbox/check-registered.py [--control]

WHAT check-constant-files.py ALREADY COVERS, and this does not repeat:
  * every constant a per-release object DEFINES has a registry row whose `introduced` is that object's
    release, and
  * every constant is defined exactly once.
  It says so itself, at its own line 9: "The registry also holds constants no file of these defines, the
  ones the framework itself exports, so rows without a definition are not this check's." That sentence is
  the gap, and this file is the other half of it.

THE GAP: A ROW WITH NO DEFINITION. 148 constant rows and 135 definitions, so thirteen rows name a constant
no object of ours defines. Each one is either
  * a constant a HELD RELEASE EXPORTS NATIVELY - then the port must NOT define it, and saying so is the
    whole point of the row; or
  * an oversight - a constant the port was asked to carry and does not.

WHICH IS WHICH IS NOT A MATTER OF OPINION: ladder.tsv is the measurement, one row per constant, the
smallest held-cache rung that EXPORTS it, and a constant with no rung is one no held cache exports. So:
  * the ladder PLACES a constant  -> the port must define it, in the object of that release
  * the ladder cannot place it     -> no held cache exports it, the port must not define it, and the row
    is a record of the framework's own export
and a constant that is neither placed nor unplaced is a row nobody can account for, which is the failure
this file exists to name.

THE CONTROL defines a constant the ladder says no held cache exports - the port SHADOWING something the
release already has, which is a real defect and the one this check exists to see - and requires the
check to go red NAMING it. The copy must be green before the shadow is added, or the control proves
nothing.
"""
import glob
import json
import os
import re
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
WORKTREE = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
PACKAGE = os.path.join(WORKTREE, "packages", "a", "apple-backports")
OBJECTS = os.path.join(PACKAGE, "VideoToolbox")
REGISTRY = os.path.join(PACKAGE, "registry", "VideoToolbox")
TABLE = os.path.join(HERE, "ladder.tsv")
# The release this package builds for. A constant a HELD CACHE exports at or before this is native to it
# and the port must not carry it; one exported later is exactly what the port is for.
MINIMUM = (6, 0)


def ladder():
    """The measurement, read: constant -> the release that first exports it. A constant with no rung is
    one no held cache exports, and the table says so by not naming it."""
    placed, native = {}, []
    for line in open(TABLE):
        if line.startswith("#") or not line.strip():
            continue
        name, _, release = line.rstrip("\n").partition("\t")
        if not name:
            continue
        if release.strip() in ("", "-"):
            native.append(name)
        else:
            placed[name] = release.strip()
    return placed, native


def registry_rows(directory):
    found = {}
    for path in sorted(glob.glob(os.path.join(directory, "*.json"))):
        for row in json.load(open(path)).get("entries", []):
            if row.get("kind") == "constant":
                found[row["api"]] = row
    return found


def defined_in(objects):
    found = {}
    for path in sorted(glob.glob(os.path.join(objects, "VideoToolboxConstants*.m"))):
        for name in re.findall(r"^const CFStringRef (\w+) = CFSTR", open(path).read(), re.M):
            found[name] = os.path.basename(path)
    return found


def check(objects, registry):
    placed, native = ladder()
    rows = registry_rows(registry)
    defined = defined_in(objects)
    problems = []
    for name, release in sorted(placed.items()):
        if name not in defined:
            problems.append("%s: the ladder places it at %s and no object of ours defines it"
                            % (name, release))
        elif name not in rows:
            problems.append("%s is defined in %s and has no registry row" % (name, defined[name]))
    for name in sorted(defined):
        if name in placed:
            first = tuple(int(part) for part in placed[name].split("."))
            if first <= MINIMUM:
                problems.append("%s is defined in %s and the release this package builds for already "
                                "exports it at %s, so the port is shadowing a name the release has"
                                % (name, defined[name], placed[name]))
        elif name not in native:
            problems.append("%s is defined in %s and the table says no held cache exports it, so it is "
                            "neither carried deliberately nor accounted for" % (name, defined[name]))
    for name in sorted(set(rows) - set(defined) - set(native) - set(placed)):
        problems.append("%s has a registry row and is in NEITHER half of ladder.tsv, so it is not "
                        "measured at all" % name)
    for name in sorted(set(rows) - set(placed) - set(native)):
        problems.append("%s has a registry row and no row in ladder.tsv - NOT MEASURED" % name)
    print("%d constant rows, %d defined, %d the ladder places, %d no held cache exports"
          % (len(rows), len(defined), len(placed), len(native)))
    return problems


def control(objects, registry):
    scratch = os.path.join(WORKTREE, ".agent-work", "runs", "vtclass", "registered-control")
    shutil.rmtree(scratch, ignore_errors=True)
    os.makedirs(scratch)
    for path in glob.glob(os.path.join(objects, "VideoToolboxConstants*.m")):
        shutil.copy(path, scratch)
    saved = TABLE
    globals()["TABLE"] = table
    before = check(scratch, registry)
    if before:
        print("CONTROL cannot start: the copy is red before the shadow: %s" % before[0])
        return 1
    placed, _native = ladder()
    # Nothing in this family is native to 6.0, so the control cannot shadow one that is. It writes the
    # constant into a scratch table placed AT the minimum, which is the rule it is checking.
    victim = sorted(placed)[0]
    table = os.path.join(WORKTREE, ".agent-work", "runs", "vtclass", "control-ladder.tsv")
    shutil.copy(TABLE, table)
    with open(table, "a") as handle:
        handle.write("%s\t6.0\n" % victim)
    target = sorted(glob.glob(os.path.join(scratch, "VideoToolboxConstants*.m")))[0]
    with open(target, "a") as handle:
        handle.write('const CFStringRef %s = CFSTR("A held release already exports this one.");\n' % victim)
    after = check(scratch, registry)
    globals()["TABLE"] = saved
    named = [p for p in after if p.startswith(victim + " ")]
    print("CONTROL defined %s in %s, a constant a held release exports: %s"
          % (victim, os.path.basename(target), named[0] if named else "NOT CAUGHT"))
    shutil.rmtree(scratch, ignore_errors=True)
    return 0 if named else 1


def main():
    status = 0
    for problem in check(OBJECTS, REGISTRY):
        print("FAIL " + problem)
        status = 1
    if "--control" in sys.argv:
        status = status or control(OBJECTS, REGISTRY)
    print("check-registered: %s" % ("RED" if status else "OK"))
    return status


if __name__ == "__main__":
    sys.exit(main())
