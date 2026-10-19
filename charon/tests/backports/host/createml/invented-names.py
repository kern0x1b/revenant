#!/usr/bin/env python3
"""The public types in this package that the SDK does not declare, at ANY nesting.

    $ python3 tests/backports/host/createml/invented-names.py

The earlier version of this walk matched only `^public (struct|class|enum|protocol)` over the port's
own sources, and compared against the four `.swiftinterface` files. Both were wrong in the same
direction, and they compounded:

  * a **leading `^`** sees only top-level declarations, so a public type nested in another type was
    invisible - and `JoinType` and `PackType`, which Apple *does* declare, are nested in
    `MLDataTable`;
  * comparing against the `.swiftinterface` files alone ignored the **headers** and the modulemaps,
    where the Objective-C and C declarations live.

So the count was inflated by exactly the types that were both nested and SDK-declared. This version:

  * matches the port's declarations **at any indentation**;
  * collects the SDK's names from every `*.swiftinterface`, every `*.h` and every `module.modulemap`
    under the four frameworks, with a scan for the declaration rather than a pattern anchored at the
    start of a line.

The count the facts state is this tool's output, and re-running it re-derives it.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[4]
SDK = pathlib.Path("/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/System/Library/Frameworks")
FRAMEWORKS = ("TabularData", "CreateMLComponents", "CreateML", "CoreML")

# The port: a public declaration, at any indentation, with a kind.
PORT = re.compile(r'^\s*public\s+(?:final\s+)?(struct|class|enum|protocol)\s+([A-Za-z_]\w*)', re.M)

# The SDK: a declaration in an interface, in a header, or a modulemap line. Not anchored, and the
# header form covers `typedef NS_ENUM(...) Name` and `@interface Name`.
SDK_IFACE = re.compile(r'^\s*(?:@[\w()., ]+\s*)*(?:public\s+|package\s+)?'
                       r'(?:final\s+class|class|struct|enum|protocol)\s+([A-Za-z_]\w*)', re.M)
SDK_ENUM = re.compile(r'^\s*public\s+enum\s+([A-Za-z_]\w*)', re.M)
SDK_OBJC = re.compile(r'^\s*(?:@interface|typedef\s+NS_\w+\s*\([^)]*\)|typedef\s+struct\s+\w+)\s*'
                      r'([A-Za-z_]\w*)', re.M)
SDK_MODULEMAP = re.compile(r'^\s*(?:header|module|\w+)\s+\"?([A-Za-z_]\w*)\"?\s*$', re.M)


def port_types():
    found = {}
    for f in sorted((ROOT / "packages/c/createml/files").glob("**/*.swift")):
        for m in PORT.finditer(f.read_text()):
            found.setdefault(m.group(2), f.relative_to(ROOT).as_posix())
    return found


def sdk_types():
    """Every name the SDK declares, from interfaces, headers and modulemaps, at any nesting."""
    found, scanned = {}, 0
    for fw in FRAMEWORKS:
        base = SDK / ("%s.framework" % fw)
        if not base.is_dir():
            print("no framework for %s - its names are NOT in the comparison" % fw, file=sys.stderr)
            continue
        files = list(base.rglob("*.swiftinterface")) + list(base.rglob("*.h")) \
            + list(base.rglob("module.modulemap"))
        for path in files:
            scanned += 1
            text = path.read_text(errors="replace")
            for rx in (SDK_IFACE, SDK_ENUM, SDK_OBJC, SDK_MODULEMAP):
                for m in rx.finditer(text):
                    found.setdefault(m.group(1), fw)
    print("# scanned %d SDK files under %s" % (scanned, ", ".join(FRAMEWORKS)), file=sys.stderr)
    return found


if __name__ == "__main__":
    mine, theirs = port_types(), sdk_types()
    extra = sorted(t for t in mine if t not in theirs)
    print("port public types (any nesting): %d   SDK names (headers + interfaces + modulemaps): %d"
          % (len(mine), len(theirs)))
    print("public types the SDK does not declare, at any nesting: %d" % len(extra))
    for t in extra:
        print("  %-40s %s" % (t, mine[t]))
