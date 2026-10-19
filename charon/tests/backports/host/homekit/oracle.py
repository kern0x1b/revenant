#!/usr/bin/env python3
"""The structural oracle for the HomeKit rows: selector presence per class, in the 12.0 and 16.0 arm64
caches under ~/.charon/dyld.

This dates a NAME's first appearance at a release. It is **not** a behaviour oracle and nothing is
concluded about behaviour from it: a selector being in the release's cache says the release spells it
that way, and nothing about what it answers. The contract in probe.m is what answers are checked against;
this is what the spelling is checked against.

Counted with a boundary after the name, because the caches pack names into runs and a substring match
without one matches a longer name that merely starts the same way. A positive and a negative control are
counted in the same pass, and the run is a failure if either control is wrong - a control that fails is
not evidence about anything else in the file.
"""
import os
import re
import sys

CACHES = os.path.expanduser("~/.charon/dyld")
RELEASES = ("12.0", "16.0")

# The selectors whose spelling this series carries, and the class each belongs to. A name that is present
# in a release confirms the header's spelling at that release; absent, the release does not spell it.
SELECTORS = {
    "HMAccessoryProfile": ["uniqueIdentifier", "services", "accessory"],
    "HMCameraProfile": ["streamControl", "snapshotControl", "settingsControl", "speakerControl"],
    "HMAccessory": ["home", "cameraProfiles"],
}

# The controls. POSITIVE: the class name, which the held arm64 caches are measured to carry, so a count of
# 0 means the reading is wrong and not that HomeKit is absent from the cache. NEGATIVE: a name this port
# invents, which no release carries, so anything above 0 means the counting is matching too much.
POSITIVE = "HMAccessory"
NEGATIVE = "charon_homeKitProbeControl"


def read(release):
    """Every file that makes up the release's arm64 cache, concatenated. The 10.x caches are split, so
    reading one file only would miss names - the same mistake the HealthKit read made before it."""
    directory = os.path.join(CACHES, release)
    out = b""
    for name in sorted(os.listdir(directory)):
        if name.startswith("dyld_shared_cache_arm64") and not name.endswith(".source"):
            with open(os.path.join(directory, name), "rb") as handle:
                out += handle.read()
    return out


def count(blob, name):
    return len(re.findall(re.escape(name.encode()) + rb"[^A-Za-z0-9_]", blob))


def main():
    failures = 0
    blobs = {}
    for release in RELEASES:
        path = os.path.join(CACHES, release)
        if not os.path.isdir(path):
            print("skipped: no arm64 cache held for %s" % release)
            return 0
        blobs[release] = read(release)
        print("%s: %d bytes of cache read" % (release, len(blobs[release])))

    print("\ncontrols, in the same pass and counted the same way:")
    for release, blob in blobs.items():
        positive = count(blob, POSITIVE)
        negative = count(blob, NEGATIVE)
        ok = positive > 0 and negative == 0
        failures += 0 if ok else 1
        print("  %-6s positive %s=%d  negative %s=%d  %s"
              % (release, POSITIVE, positive, NEGATIVE, negative, "ok" if ok else "CONTROL FAILED"))

    # These are GLOBAL counts of a name, not per class: a cache holds one copy of a selector name, shared
    # by every class that uses it, so a count says the release spells the name that many times and NOT that
    # the class the row names has it. The grouping is by owning class because that is what the registry
    # row says the member is, and a short name like "home" is also a token in many other identifiers -
    # which is why its count is large. A per-class answer needs the release's own method list, not a
    # string count, and that is the runtime half this machine cannot run.
    print("\nname presence in the cache, per release (GLOBAL, not per class - see the note below):")
    for owning_class, selectors in sorted(SELECTORS.items()):
        print("  %s" % owning_class)
        for selector in selectors:
            row = []
            for release in RELEASES:
                row.append("%s=%d" % (release, count(blobs[release], selector)))
            print("    %-20s %s" % (selector, "  ".join(row)))

    print("\nThese are global counts of a NAME. A cache holds one copy of a selector name shared by every "
          "class that uses it, so this cannot say the class a row names has the member, and a short name "
          "like 'home' is also a token inside many other identifiers. What it can say is that the release "
          "spells the name at all. It dates a name and says nothing about behaviour, and none of it is "
          "compared with a host: there is no HomeKit framework in any macOS SDK here.")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
