#!/usr/bin/env python3
"""band.py RELEASE PHOTOS-DIR REGISTRY-DIR -- the Photos sources one release's band carries.

    python3 tests/backports/device/photos/band.py 6.1.3 packages/a/apple-backports/Photos \
        packages/a/apple-backports/registry

The rule is the build's own, not a list written out again here: an object is placed by the minimum
its registry rows carry, and never by the release its file name or its API was introduced in
(modules/apple/backports.lua:2014 -- minimums() reads entry.minimum and never entry.status -- and
:2508 band_ranges). So a file is in the band when every class it defines has a registry entry whose
minimum is at or below the release, and a file whose classes no entry names (the port's own store
and transaction, which carry no API of their own) is in it too. A hardcoded list of file names is
what this replaces: it went stale twice in one afternoon, once for PHChangeRequest13.m -- a 13.0
object the 6.0 band carries, because registry/Photos/ios13.json gives it minimum 6.0 -- and once for
a file added beside it, whose absence the link caught as an unrecognized selector on the device.
"""
import json
import os
import re
import sys


def versions(text):
    return tuple(int(part) for part in re.findall(r"\d+", text or "0"))


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    release_text, photos, registry = sys.argv[1:]
    release = versions(release_text)
    minimums = {}
    for folder, _, names in os.walk(registry):
        for name in sorted(names):
            if not name.endswith(".json"):
                continue
            with open(os.path.join(folder, name)) as handle:
                document = json.load(handle)
            # A registry file holds {"framework": ..., "entries": [...]} in this tree. A shape this
            # script does not know is named and skipped, never read as "no entry": that would put
            # every class of that file into every band. The one that was here is gone: the Intents
            # manifest (Intents/constants.json, a "constants" object under its own key and a
            # generator input rather than a row list) is at tools/intents/constants.json since the
            # coordinator's ruling of 2026-10-03, because a reader that walked it under registry/
            # saw none of its 83 rows. Nothing under registry/ holds that shape now, and this
            # script's skip is the backstop if one ever does.
            if isinstance(document, dict) and "entries" not in document:
                keys = [key for key in document if isinstance(document[key], list)]
                if len(keys) != 1:
                    print("band.py: %s holds no entries and no one list; skipped" % os.path.join(folder, name),
                          file=sys.stderr)
                    continue
                document = document[keys[0]]
            entries = document["entries"] if isinstance(document, dict) else document
            if True:
                for entry in entries:
                    if entry.get("kind") == "class" and entry.get("minimum"):
                        current = minimums.get(entry["api"])
                        if current is None or versions(entry["minimum"]) < versions(current):
                            minimums[entry["api"]] = entry["minimum"]
    defined = re.compile(r"^@(?:implementation|interface)\s+([A-Za-z_][A-Za-z0-9_]*)", re.M)
    for name in sorted(os.listdir(photos)):
        if not name.endswith(".m"):
            continue
        with open(os.path.join(photos, name)) as handle:
            classes = defined.findall(handle.read())
        floors = [minimums[cls] for cls in classes if cls in minimums]
        if not floors and classes:
            print("%s: no registry entry names %s, so it is in the band by default" %
                  (name, ", ".join(sorted(set(classes)))), file=sys.stderr)
        above = [floor for floor in floors if versions(floor) > release]
        if above:
            print("%s is not in the %s band: %s carries a minimum of %s" %
                  (name, release_text, ", ".join(sorted(set(classes))), ", ".join(sorted(set(above)))),
                  file=sys.stderr)
            continue
        print(name)


if __name__ == "__main__":
    main()
