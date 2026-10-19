#!/usr/bin/env python3
"""
Does a property row whose header declared `getter=` get read as missing while the release carries
the accessor it declared?

A property is read through its accessors, and the surface names the property, not the accessor.
classify_property derived both accessors from the property's name: `-supported` and
`-setSupported:`. The 26.2 SDK declares `@property (readonly, getter=isSupported, setter=...)` on
165 rows over 26 frameworks -- `AVAudioSessionCapability.supported`, `WKWebExtensionAction.enabled`,
`UIScrollView.scrollAnimating`, `MTLTextureBinding.depthTexture` -- and for those the derived getter
is not the selector any release declares, so every one of them read missing with a reason that names
a selector the header never asked for. The fix is to record what the header declared and read that,
not to guess: a prefix rule (`is` + the name) would also move rows whose accessor is unrelated.

The four parts, each of which is a defect on its own and is checked here:

  1. surface-diff-latest.Surface records the declared accessor on the property's detail. The AST
     prints it as a `getter ObjCMethod` child of the property, and that line does NOT match the
     walk's own LINE pattern (after the node name comes the type `ObjCMethod`, not an address), so
     the accessor has to be matched separately.
  2. sdk-introduced.py's objc_row carries it onto the row, and sdk-surface.py's SURFACE_HEAD has
     the column, so the TSV holds it.
  3. api-ledger.py's SURFACE_COLUMNS has it and load_surface reads it by name; classify_property
     uses it in place of the derived accessor, and the reason it reports names the real selector.
  4. main() passes it. This is a wiring check against main's source text, not a run: build() needs a
     gate, a dyld cache and an SDK to reach that line. A matcher that is right and a caller that
     forgets to hand it the getter moves nothing while every behavioural check stays green.

    python3 selftest-api-ledger-getter.py

Exit 0 when every check holds. The AST lines below are the real shapes, copied out of a
`clang -ast-dump` of the 26.2 SDK, and the inventories are written here, so nothing on this machine
can make it pass or fail.
"""
import importlib.util
import os
import re
import sys

HERE = os.path.dirname(os.path.realpath(__file__))


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, os.path.join(HERE, filename))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


sd = load("sd", "surface-diff-latest.py")
ledger = load("api_ledger", "api-ledger.py")

CHECKS = []
failures = []


def check(what, got, want):
    CHECKS.append(what)
    if got == want:
        print("ok   %s" % what)
    else:
        print("FAIL %s\n       got  %r\n       want %r" % (what, got, want))
        failures.append(what)


# ---------------------------------------------------------------------------
# 1. The walk. Real lines, indented as clang prints them inside an @interface:
#
#   |`-ObjCInterfaceDecl 0x1 </SDK/AVFAudio.framework/Headers/AVAudioSessionRoute.h:131:1> ... AVAudioSessionCapability
#   | |-ObjCPropertyDecl 0x2 </SDK/.../AVAudioSessionRoute.h:134:1, col:58> col:58 supported 'BOOL':'bool' readonly nonatomic
#   | | `-getter ObjCMethod 0x3 'isSupported'
#   | `-ObjCMethodDecl 0x4 <line:134:58> col:58 implicit - isSupported 'BOOL':'bool'
#   | |-ObjCPropertyDecl 0x5 <line:137:1, col:76> col:76 highQualityRecording 'X':'Y' readonly nonatomic strong
#   | `-ObjCMethodDecl 0x6 <line:137:76> col:77 implicit - highQualityRecording 'X':'Y'
#
# The two properties are the whole pair: one declares a getter under another name, one declares
# nothing and is read through its own name.
INTERFACE = "/SDK/AVFAudio.framework/Headers/AVAudioSessionRoute.h"
DUMP = [
    "TranslationUnitDecl 0x0 <<invalid sloc>>",
    "`-ObjCInterfaceDecl 0x1 <%s:131:1, line:138:2> line:131:12 AVAudioSessionCapability" % INTERFACE,
    "| |-ObjCPropertyDecl 0x2 <%s:134:1, col:58> col:58 supported 'BOOL':'bool' readonly nonatomic" % INTERFACE,
    "| | `-getter ObjCMethod 0x3 'isSupported'",
    "| |-ObjCPropertyDecl 0x5 <line:137:1, col:76> col:76 highQualityRecording 'X':'Y' readonly nonatomic strong",
    "| `-ObjCMethodDecl 0x6 <line:137:76> col:77 implicit - highQualityRecording 'X':'Y'",
]

surface = sd.Surface("AVFAudio", full=True, owns=lambda path: path.startswith("/SDK/"))
surface.feed(DUMP)

check("the declared getter lands on the property's detail",
      surface.details["AVAudioSessionCapability.supported"].get("getter"), "isSupported")
check("a property the header declared nothing for carries no getter",
      surface.details["AVAudioSessionCapability.highQualityRecording"].get("getter"), None)
check("and no setter either", "setter" in surface.details["AVAudioSessionCapability.supported"], False)

# The getter child belongs to the property, not to whatever the walk is looking at next: a `getter`
# line at the property's own depth, or under a method, is not the property's accessor. This is what
# keeps `self.accessors` from leaking into the next row (finish_target clears it either way).
METHOD_FIRST = [
    DUMP[0],
    DUMP[1],
    "| |-ObjCMethodDecl 0x4 <line:140:1, col:20> col:20 -probe 'BOOL':'bool'",
    "| | `-getter ObjCMethod 0x7 'isProbe'",
    "| `-ObjCMethodDecl 0x6 <line:137:76> col:77 implicit - highQualityRecording 'X':'Y'",
]
other = sd.Surface("AVFAudio", full=True, owns=lambda path: path.startswith("/SDK/"))
other.feed(METHOD_FIRST)
check("a getter child under a method is not recorded as a property's accessor",
      [api for api, detail in other.details.items() if detail and "getter" in detail], [])

# A property row of the whole surface walk: the rows, not the details, must still be the same
# count -- the accessors ride along on the detail and add no row.
check("the accessors add no row of their own",
      sorted(api for api in surface.rows if api >= "AVAudioSessionCapability"),
      ["AVAudioSessionCapability", "AVAudioSessionCapability.highQualityRecording",
       "AVAudioSessionCapability.supported"])

# ---------------------------------------------------------------------------
# 2. The row carries it, and the TSV has the column.
introduced_source = open(os.path.join(HERE, "sdk-introduced.py"), encoding="utf-8").read()
objc_row = introduced_source[introduced_source.index("def objc_row("):introduced_source.index("def inherit_class_floor(")]
check("sdk-introduced.py's objc_row copies the declared accessor onto the row",
      ('for role in ("getter", "setter")' in objc_row and "row[role] = detail[role]" in objc_row), True)

surface_source = open(os.path.join(HERE, "sdk-surface.py"), encoding="utf-8").read()
statement = re.search(r"^SURFACE_HEAD = .*$", surface_source, re.M).group(0)
check("SURFACE_HEAD has the getter column, after via and before the enrichment ENRICHED appends",
      statement.index('"via"') < statement.index('"getter"') < statement.index("ENRICHED"), True)
check("and the built row takes it from the walk's row", 'row.get("getter", "")' in surface_source, True)

# ---------------------------------------------------------------------------
# 3. The ledger reads it, and uses it in place of the derived accessor.
check("SURFACE_COLUMNS has the column", "getter" in ledger.SURFACE_COLUMNS, True)
check("and it is beside via, not at the end",
      ledger.SURFACE_COLUMNS.index("via") < ledger.SURFACE_COLUMNS.index("getter")
      < ledger.SURFACE_COLUMNS.index("registry"), True)


def entry(instance=(), klass=(), library="Backports"):
    return {"instance": set(instance), "class": set(klass), "protocols": set(),
            "superclass": "", "image": "", "library": library}


BUILT = {"AVAudioSessionCapability": entry(instance=["-isSupported"], library="AVFAudioBackports")}
RELEASE = {}

status, reason = ledger.classify_property(
    "AVAudioSessionCapability.supported", BUILT, RELEASE, {}, {}, getter="isSupported")
check("the declared getter answers the row", status, "implemented")

# What a row still missing says about itself is the other half: the selector it names must be the
# one the header declared. Before the fix this reason asked about `-supported`, which no release
# declares, so a reader could not act on it.
status, reason = ledger.classify_property(
    "AVAudioSessionCapability.supported", {"AVAudioSessionCapability": entry()}, RELEASE, {}, {},
    getter="isSupported")
check("and a row still missing names the accessor the header declared",
      reason, "AVAudioSessionCapability is there, neither -isSupported nor -setSupported: is an "
              "instance or a class selector")

# The mutation this fixes: the same row, with no getter recorded, is the old behaviour. Drop the
# column and the row reads missing again with a reason that names a selector Apple never declared.
status, reason = ledger.classify_property("AVAudioSessionCapability.supported", BUILT, RELEASE)
check("without the declared getter the row reads missing again", status, "missing")
check("with the old, false reason",
      reason, "AVAudioSessionCapability is there, neither -supported nor -setSupported: is an "
              "instance or a class selector")

# A property the header declared nothing for is unchanged, and a wrong declared getter is not
# credited: the row only moves when the selector the header names is the one the release carries.
check("a property with no declared accessor is read through its own name, as before",
      ledger.classify_property("AVAudioSessionCapability.supported",
                               {"AVAudioSessionCapability": entry(instance=["-supported"])},
                               RELEASE)[0], "implemented")
check("a declared getter the release does not carry leaves the row missing",
      ledger.classify_property("AVAudioSessionCapability.supported",
                               {"AVAudioSessionCapability": entry(instance=["-supported"])},
                               RELEASE, {}, {}, getter="isSomethingElse")[0], "missing")

# ---------------------------------------------------------------------------
# 4. The wiring. Checked against main's source text, not by running it: build() needs a gate, a
# dyld cache and an SDK to reach that line. Dropping `getter=row["getter"]` from the call leaves
# every behavioural check above green while nothing moves -- which is the defect this half exists
# to catch, the same shape as the protocol-argument wiring check in selftest-api-ledger-property.py.
source = open(os.path.join(HERE, "api-ledger.py"), encoding="utf-8").read()
call = re.search(r"classify_property\(([^)]*)\)", source[source.index("def main("):])
check("main() hands classify_property the getter the row carries",
      'getter=row["getter"]' in call.group(1), True)
# and load_surface reads the TSV by column name, so the column has to be in SURFACE_COLUMNS and the
# TSV has to carry it -- an assertion, not a silent default, so a stale surface fails loudly.
check("load_surface asserts the header shape rather than defaulting the new column",
      "assert head == SURFACE_COLUMNS" in source, True)

print("\n%d checks, %d failures" % (len(CHECKS), len(failures)))
sys.exit(1 if failures else 0)