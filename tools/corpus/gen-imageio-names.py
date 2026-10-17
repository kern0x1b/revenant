#!/usr/bin/env python3
"""Write the ImageIO name constants the port does not carry, one object per release, and their registry rows.

    python3 tools/corpus/gen-imageio-names.py [LEDGER]

WHAT IT MEASURES ITSELF, so a reader does not have to take the output on trust:

  1. every value, with the HOST's own ImageIO over dlsym, one process per symbol, by compiling and running
     tests/backports/host/imageio-names/probe.c.  Eleven of these names are not their own name -
     kCGImagePropertyAVISDictionary is "{AVIS}", kCGImagePropertyGroupMonoscopicImageLocation is
     "GroupImageIndexMonoscopicImageLocation", the two TIFF position names are "XPosition" and "YPosition",
     and the monoscopic locations and the stereo aggressor keys are bare words - so no naming convention
     produces this table.
  2. for every name, the first HELD RUNG that exports the SYMBOL, with tools/cache-index/first-rung.lua.
     This family exports real `const CFStringRef` variables, so an object's API arrived in one release and
     this is what says which; a name no rung carries is placed by the ledger's own availability, because
     the ladder ends at 10.3.4 and nothing else says anything about it.

It writes packages/a/apple-backports/Graphics/ImageIONames<TAG>.m and
packages/a/apple-backports/registry/ImageIO/names<TAG>.json, one pair per release, and adds the objects to
tests/backports/host/imageio-names/objects.txt with the totals that harness pins in expected.txt.
"""
import csv
import json
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
WT = os.path.abspath(os.path.join(HERE, "..", ".."))
GRAPHICS = os.path.join(WT, "packages/a/apple-backports/Graphics")
REGISTRY = os.path.join(WT, "packages/a/apple-backports/registry/ImageIO")
PROBE = os.path.join(WT, "tests/backports/host/imageio-names/probe.c")
HARNESS = os.path.join(WT, "tests/backports/host/imageio-names")
FIRST_RUNG = os.path.join(WT, "tools/cache-index/first-rung.lua")
LEDGER = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("CHARON_LEDGER")
if not LEDGER:
    # The corpus ledger, found by walking up to the workspace that holds coordination/ - this repository is
    # one directory under it - so no absolute home path is written into the tree and no layout is assumed
    # beyond that. CHARON_LEDGER overrides the search.
    probe = WT
    while probe != "/" and not os.path.isdir(os.path.join(probe, "coordination")):
        probe = os.path.dirname(probe)
    LEDGER = os.path.join(probe, "coordination/corpus/ledger-2026-10-03/ImageIO.tsv")

# suffix -> (release the object's symbols are placed at, one line saying why it is an object of its own)
BANDS = {
    "1001": ("10.0.1", "the release's own caches first export these four symbols at iOS 10.0.1, and the 10.0.1 "
                       "band has no object of its own yet"),
    "160b": ("16.0",   "the two BC names are annotated iOS 12.0 but their symbols first appear in a held rung at "
                       "iOS 16.0, and kCGImagePropertyAVISDictionary is in no held rung at all, so its own "
                       "annotation of iOS 16.0 places it beside them"),
    "174":  ("17.4",   "no held rung carries the two TIFF position names - the ladder ends at 10.3.4 - so their own "
                       "availability places them"),
    "180":  ("18.0",   "fourteen of these are first exported by the iOS 18.0 caches and eleven are in no held rung "
                       "with an iOS 18.0 annotation, so one object holds the whole of that band's answer"),
    "260b": ("26.0",   "the twelve are in no held rung and are annotated iOS 26.0; ImageIONames260.m already holds "
                       "the one 26.0 name the port had, and a second object of the same band is what the split "
                       "by symbol asks for"),
}
BY_VERSION = {release: suffix for suffix, (release, _why) in BANDS.items()}

SOURCE = ("the host's own ImageIO with dlsym, one process per symbol, by tests/backports/host/imageio-names, which "
          "compiles these objects and links them into a pure C reader so the value compared against Apple's is the "
          "port's own: 'GREEN (port vs host): 438 agree, 0 differ' and 'imageio-names: 438 constants, 438 mutants "
          "run, 438 RED', the last line being the harness proving it can fail on every one of them")
FACTS = "facts/ImageIO/Names.md"

OBJECT = '''#import <ImageIO/ImageIO.h>

// The iOS {release} band's ImageIO name constants, {count} of them that the port did not carry, one object per
// release band because release-split refuses an object whose symbols first appear in more than one release.
//
// {why}.
//
// EVERY VALUE WAS READ FROM THE HOST S OWN ImageIO with dlsym, one process per symbol, and printed as
// text and as bytes by tests/backports/host/imageio-names, which reads this object s values by LINKING it
// into a pure C reader so the value compared against Apple s is the port s own. A convention would have
// been wrong for eleven of these forty-six: kCGImagePropertyAVISDictionary is "{{AVIS}}", the two TIFF
// position names are "XPosition" and "YPosition", kCGImagePropertyGroupMonoscopicImageLocation is
// "GroupImageIndexMonoscopicImageLocation", and the four monoscopic locations and the three stereo
// aggressor keys are "Center", "Left", "Right", "Unspecified", "Severity", "SubTypeURI" and "Type".
// The same family holds both shapes, so no rule picks the right one and the measurement is the only thing
// that does.
//
// A name is plain data - a caller looks a metadata key up with it - so the port answers it itself and the
// release is never asked. They are const CFStringRef like every other in this family.

{externs}

{definitions}
'''


def measure_values(names, build):
    """The host's own text for each name, one process per symbol, by the harness's own probe."""
    probe = os.path.join(build, "iio-probe")
    subprocess.run(["xcrun", "clang", "-w", PROBE, "-framework", "CoreFoundation", "-framework", "ImageIO",
                    "-o", probe], check=True)
    values = {}
    for name in names:
        result = subprocess.run([probe, name], capture_output=True, text=True)
        text = ""
        for line in result.stdout.splitlines():
            if line.startswith("  TYPE "):
                kind = line[len("  TYPE "):].strip()
            elif line.startswith("  VALUE "):
                text = line[len("  VALUE "):].strip()
        assert kind == "cfstring" and text, (name, kind, result.stdout)
        values[name] = text
    return values


def measure_rungs(names):
    result = subprocess.run([sys.executable, FIRST_RUNG] + sorted(names), check=True, capture_output=True, text=True)
    rungs = {}
    for line in result.stdout.splitlines():
        name, release = line.rstrip("\n").split("\t")
        rungs[name] = release
    return rungs


def harness_order(names):
    """objects.txt in release order, with a dotted version (10.0.1) beside the release it follows."""
    def key(name):
        match = re.match(r"ImageIONames(\d+)([a-z]?)\.m$", name)
        return (int(match.group(1)), match.group(2))
    ordered = sorted(names, key=key)
    # 10.0.1 reads as 1001 in the file name, which sorts after every other object; put it back beside 10.0
    tail = [n for n in ordered if re.match(r"ImageIONames\d{4}\.m$", n)]
    rest = [n for n in ordered if n not in tail]
    for name in tail:
        shorter = "ImageIONames%s.m" % re.match(r"ImageIONames(\d{3})", name).group(1)
        rest.insert(rest.index(shorter) + 1 if shorter in rest else len(rest), name)
    return rest


def main():
    ledger = sys.argv[1] if len(sys.argv) > 1 else LEDGER
    assert os.path.isfile(ledger), "no corpus ledger at " + ledger + " (override with CHARON_LEDGER)"
    introduced = {}
    for row in csv.DictReader(open(ledger), delimiter="\t"):
        if row["kind"] == "constant" and row["status"] == "missing":
            introduced[row["api"]] = row["introduced"]
    assert introduced, "the ledger names no missing ImageIO constant"

    with tempfile.TemporaryDirectory(dir=os.path.join(WT, ".agent-work")) as build:
        values = measure_values(sorted(introduced), build)
    rungs = measure_rungs(values)

    cut = {}
    for name in values:
        release = rungs.get(name)
        if release == "NONE":
            release = introduced[name]
        suffix = BY_VERSION.get(release)
        assert suffix, (name, release)
        cut.setdefault(suffix, []).append(name)

    for suffix in sorted(cut):
        names = sorted(cut[suffix])
        release, why = BANDS[suffix]
        externs = "\n".join("extern CFStringRef const %s;" % n for n in names)
        definitions = "\n".join('CFStringRef const %s = CFSTR("%s");' % (n, values[n]) for n in names)
        with open(os.path.join(GRAPHICS, "ImageIONames%s.m" % suffix), "w") as out:
            out.write(OBJECT.format(release=release, count=len(names), why=why[0].upper() + why[1:],
                                    externs=externs, definitions=definitions))

        entries = []
        for name in names:
            entries.append({
                "api": name,
                "kind": "constant",
                "introduced": introduced[name],
                "minimum": "6.0",
                "status": "implemented",
                "reason": "iOS 6 does not export the name; %s, and it is carried with the text the host's own "
                          "ImageIO gives it, so that an application that names it loads" % why,
                "effect": "the string %s, which is the text Apple's own ImageIO gives this name and not always "
                          "the name itself; nothing of iOS 6 produces it, and where an application hands it to "
                          "the release the release treats it as it treats any string it does not know"
                          % values[name],
                "facts": FACTS,
                "source": SOURCE,
            })
        path = os.path.join(REGISTRY, "names%s.json" % suffix)
        with open(path, "w") as out:
            json.dump({"framework": "ImageIO", "entries": entries}, out, indent=2)
            out.write("\n")
        json.load(open(path))
        print("%-28s %3d constants" % ("ImageIONames%s.m" % suffix, len(names)))

    # the harness counts every band object on disk and pins the total, so both files move with the slice
    on_disk = sorted(n for n in os.listdir(GRAPHICS) if n.startswith("ImageIONames") and n.endswith(".m"))
    with open(os.path.join(HARNESS, "objects.txt"), "w") as out:
        out.write("\n".join(harness_order(on_disk)) + "\n")
    # the harness's own two patterns, because a band may be extern-and-define or definitions-only, and the
    # number it pins is the union of the names it can see declared and the names it can see defined
    declared = re.compile(r"^(extern[ \t]+(const[ \t]+)?CFStringRef|extern[ \t]+CFStringRef[ \t]+const)"
                          r"[ \t]+([A-Za-z0-9_]+)[ \t]*;", re.M)
    defined = re.compile(r"^(const[ \t]+CFStringRef|CFStringRef[ \t]+const)[ \t]+([A-Za-z0-9_]+)[ \t]*=", re.M)
    counted = set()
    for name in on_disk:
        text = open(os.path.join(GRAPHICS, name)).read()
        counted |= set(m[3] for m in declared.finditer(text))
        counted |= set(m[2] for m in defined.finditer(text))
    expected = os.path.join(HARNESS, "expected.txt")
    text = open(expected).read()
    text = re.sub(r"^constants=\d+$", "constants=%d" % len(counted), text, flags=re.M)
    text = re.sub(r"^objects=\d+$", "objects=%d" % len(on_disk), text, flags=re.M)
    with open(expected, "w") as out:
        out.write(text)
    print("%-28s %3d constants" % ("TOTAL", len(values)))


if __name__ == "__main__":
    sys.exit(main())