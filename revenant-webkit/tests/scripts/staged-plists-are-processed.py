#!/usr/bin/env python3
"""Refuse a staged framework whose Info.plist is the unprocessed one, or absent.

    tests/scripts/staged-plists-are-processed.py

CMake writes its own Info.plist for a framework target every time it regenerates,
and the engine post-build command replaces it with the processed one. A build
that reconfigures and relinks nothing loses that race and stages the default:
no MinimumOSVersion, no UIDeviceFamily, an empty CFBundleName. It loads, it runs,
and nothing says the bundle lost what identifies it - which is why this refuses
rather than warns.

Which bundles must carry one comes from charon.toml: a framework staged with its
resources is opened as a bundle, so a missing plist is the same loss arriving
quietly. Walking the plists that happen to be there cannot see that.
"""
import plistlib
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "charon.toml"
REQUIRED = ("MinimumOSVersion", "UIDeviceFamily", "CFBundleSupportedPlatforms")


def staging():
    with MANIFEST.open("rb") as handle:
        declared = tomllib.load(handle)
    stage = declared.get("stage", {})
    where = stage.get("engine-location")
    if not where:
        raise SystemExit("{} declares no stage engine-location, so where the frameworks land is unknown".format(
            MANIFEST))
    bundles = sorted(spec.get("as", name) for name, spec in stage.get("frameworks", {}).items()
                     if spec.get("resources"))
    if not bundles:
        raise SystemExit("{} declares no framework staged with its resources, so nothing here has a "
                         "bundle to identify".format(MANIFEST))
    return where, bundles


def unprocessed(plist, described):
    faults = []
    missing = [key for key in REQUIRED if not described.get(key)]
    if missing:
        faults.append("{} lacks {} - it is the plist CMake generates, not the one the engine "
                      "processes".format(plist.relative_to(ROOT), ", ".join(missing)))
    if not described.get("CFBundleName"):
        faults.append("{} carries an empty CFBundleName".format(plist.relative_to(ROOT)))
    return faults


def main():
    where, bundles = staging()
    stages = sorted((ROOT / "build").glob("*/stage"))
    if not stages:
        print("FAIL  no staged tree under {}; run charon build first".format(ROOT / "build"))
        return 1

    failures = []
    checked = 0
    for stage in stages:
        for bundle in bundles:
            plist = stage / where / "{}.framework".format(bundle) / "Info.plist"
            if not plist.is_file():
                failures.append("{} is staged with its resources and carries no Info.plist - the engine "
                                "opens it as a bundle".format(plist.parent.relative_to(ROOT)))
                continue
            with plist.open("rb") as handle:
                described = plistlib.load(handle)
            failures.extend(unprocessed(plist, described))
            checked += 1

    for line in failures:
        print("FAIL  {}".format(line))
    if failures:
        print("{} staged framework plist(s) missing or unprocessed".format(len(failures)))
        return 1
    print("ok    {} staged framework plists carry the keys the device is identified by, "
          "one for every bundle declared with resources".format(checked))
    return 0


if __name__ == "__main__":
    sys.exit(main())
