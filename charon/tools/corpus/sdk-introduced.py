#!/usr/bin/env python3
"""Dump SDK-declared API -> (kind, introduced) per framework by reusing surface-diff.declared()
(clang -ast-dump over the Mac Catalyst SDK). Output: corpus/sdk-introduced.json

    sdk-introduced.py --sdk <path to an iPhoneOS SDK> [--out FILE] [--frameworks A,B] [--no-swift] [--no-include]

takes a real iPhoneOS SDK whole instead: every framework that has headers is walked with clang
(objective-c, C), every C library under usr/include (os, dispatch, xpc, mach, sys, libkern, ... one
"framework" named include/<directory> each, `include` for the loose top-level headers) is walked the
same way, every module that has a .swiftinterface is read by swiftinterface-surface.py, and
what comes out is one row per declaration with its whole availability, not the (kind, introduced)
pair above: name, framework, kind, language, introduced, deprecated, obsoleted, unavailable, via.
`via` says where `introduced` came from: own, container (class, protocol, category or enum), class-floor
(the class of a category with no annotation of its own) or none; container and class-floor are a floor,
the member arrived in that version or later. The file also carries `dropped`, the count and the names of
everything the walk sees and does not turn into a row. The
default output is corpus/sdk-<version>-declared.json; sdk-introduced.json is left as it is, its
readers (crash-demand.py and the others) expect the shape above. The run is one clang per
framework, sequential: start it through coordination/heavy.sh.

Two things this does beyond a bare re-export of declared():

- A member with no @available of its own falls back to its containing class's or protocol's own
  resolved version, inside surface-diff.declared() itself (Surface.container_version) - this was
  already there, not added here. What was broken was reaching it at all: the generator's own
  import pointed at a worktree (.claude/worktrees/priceless-kepler-a7622c) that no longer exists,
  so every run needed SURFACE_DIFF set by hand or it did not run - and when sdk-introduced.json
  goes missing, crash-demand.py loses ~700 rows to `continue` with no count, silently, because a
  KeyError deep in ver() looks nothing like "the generator never ran". Fixed by preferring a
  local, already-current copy (surface-diff-latest.py, right beside this script) over the dead
  worktree, with SURFACE_DIFF still the first choice for whoever wants to point it elsewhere.

- A member that still has no version after that fallback - neither its own nor its container's -
  is checked against a real iPhoneOS SDK's declared() for the same framework, and named in
  corpus/sdk-introduced-unverified.tsv when absent there, rather than dropped outright.
  Measured against -[UINavigationBarDelegate navigationBarNSToolbarSection:], the concrete
  example this fallback was asked to filter as Catalyst-only ("NSToolbar is not in iOS at all"):
  it IS real iOS API, since iOS 16, per the iPhoneOS 16.4 SDK's own header text - just
  unannotated in both SDKs, the same as an old pre-@available method like
  -[NSURLConnectionDelegate connection:didFailWithError:] (iOS 2.0). "Absent from the one local
  iPhoneOS SDK" does not distinguish those from a real, genuinely Catalyst-only member (an
  AppKit-shaped extra the macabi target parses because Catalyst hosts it and real iOS never
  does) - it also matches ordinary newer API the local SDK, capped at 16.4, simply predates.
  Checked directly: -[CBCentralManagerDelegate
  centralManager:didDisconnectPeripheral:timestamp:isReconnecting:error:], a real iOS 17
  CoreBluetooth addition, is unannotated in the Catalyst dump AND absent from the 16.4 SDK - the
  same shape as the Catalyst-only case, with no way to tell them apart from this AST alone. An
  automatic drop on that signal would have silently discarded real API exactly the way this whole
  effort exists to stop; the two categories are named to the file above for a human decision, not
  merged into one guess.
"""
import argparse
import collections
import glob
import importlib.util
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.realpath(__file__))
# corpus/ is DATA, in the durable location CHARON_CORPUS_ROOT addresses (default coordination/),
# independent of this script's own location. surface-diff-latest.py is a NEIGHBOR SCRIPT, found
# beside this file (HERE, already correct above). See tools/corpus/README.md.
CORPUS_ROOT = os.environ.get("CHARON_CORPUS_ROOT") or os.path.join(
    os.path.expanduser("~"), "Git", "projects", "ios", "coordination")
CORPUS = os.path.join(CORPUS_ROOT, "corpus")
if not os.path.isdir(CORPUS):
    sys.exit("sdk-introduced.py: no corpus/ data directory found at %s. Set CHARON_CORPUS_ROOT to "
              "the directory that contains corpus/." % CORPUS)


def load_surface_diff():
    candidates = [
        os.environ.get("SURFACE_DIFF"),
        os.path.join(HERE, "surface-diff-latest.py"),
        os.path.join(os.path.expanduser("~"), "Git", "projects", "ios", "charon", "tests", "backports", "tools", "surface-diff.py"),
    ]
    for path in candidates:
        if path and os.path.isfile(path):
            spec = importlib.util.spec_from_file_location("sd", path)
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            print("surface-diff: %s" % path, flush=True)
            return module
    sys.exit("no surface-diff.py found: tried %s - set SURFACE_DIFF, or refresh %s" %
              (", ".join(p for p in candidates if p), os.path.join(HERE, "surface-diff-latest.py")))


def newest_iphoneos_sdk():
    found = sorted(glob.glob(os.path.join(os.path.expanduser("~"), ".xmake", "packages", "i", "iphoneos-sdk", "*", "*", "*.sdk")))
    return found[-1] if found else None


def load_neighbor(name, filename):
    path = os.path.join(HERE, filename)
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def show(version):
    if version is None:
        return ""
    return "yes" if version == sd.DEPRECATED_NO_VERSION else sd.show_version(version)


def objc_row(name, api, kind, detail):
    row = {"api": api, "framework": name, "kind": kind, "lang": "objc",
           "introduced": show(detail["introduced"]), "deprecated": show(detail["deprecated"]),
           "obsoleted": show(detail["obsoleted"]), "unavailable": "yes" if detail["unavailable"] else "",
           "via": detail["via"]}
    # The accessors the header declared, when they are not the property's own name. A property is
    # read through its accessors, so a consumer cannot place `AVAudioSessionCapability.supported`
    # without them; every other row carries none and the two keys stay absent rather than empty,
    # which is what says "the header declared nothing different".
    for role in ("getter", "setter"):
        if role in detail:
            row[role] = detail[role]
    return row


def inherit_class_floor(rows):
    """A member of a category with no availability of its own has no version in the AST, though the
    class it extends has one: `-[HKQuery ...]` in `@interface HKQuery (HKObjectPredicates)` under
    HKQuery 8.0. It takes the class's version, as a floor (via `class-floor`): the member arrived in
    that version or later, which is enough to tell it from what was there before 6.1. Returns how many
    rows took one. The class is looked up by name across every framework, since a category may sit
    in another framework than its class."""
    floor = {}
    for row in rows:
        if row["lang"] == "objc" and row["kind"] in ("class", "protocol") and row["introduced"]:
            have = floor.get(row["api"])
            if have is None or parse_version(row["introduced"]) < parse_version(have):
                floor[row["api"]] = row["introduced"]
    taken = 0
    for row in rows:
        if row["lang"] != "objc" or row["kind"] not in ("method", "property") or row["via"] != "none":
            continue
        found = re.match(r"^[-+]\[(\w+) ", row["api"]) or re.match(r"^(\w+)\.", row["api"])
        if found and found.group(1) in floor:
            row["introduced"] = floor[found.group(1)]
            row["via"] = "class-floor"
            taken += 1
    return taken


def parse_version(text):
    return tuple(int(part) for part in text.split("."))


def walk_sdk(sd, sdk_path, only, with_swift, with_include=True):
    """Every declaration of an iPhoneOS SDK: {"sdk", "version", "target", "rows", "frameworks", "failed",
    "libraries", "dropped"}. `frameworks` maps every walked framework and usr/include library to its
    row counts; `dropped` names and counts everything the walk sees and does not turn into a row."""
    version = sd.sdk_version(sdk_path)
    target = "arm64-apple-ios" + version
    names = set()
    for base in sd.framework_bases(sdk_path, target, full=True):
        for entry in os.listdir(base):
            if entry.endswith(".framework") and sd.framework_headers_dir(sdk_path, entry[:-len(".framework")], target, full=True):
                names.add(entry[:-len(".framework")])
    if only:
        names &= set(only)
    rows = []
    failed = []
    frameworks = {}
    anonymous = collections.Counter()
    for fw in sorted(names):
        problems = []
        try:
            surface = sd.declared_surface(sdk_path, fw, target, full=True, failed=problems)
        except SystemExit as e:
            failed.append("%s: %s" % (fw, str(e)[:300]))
            print("%s: skipped (%s)" % (fw, str(e)[:120]), flush=True)
            continue
        failed += problems
        anonymous.update(surface.anonymous)
        rows += [objc_row(fw, api, kind, surface.details[api]) for api, (kind, introduced) in surface.rows.items()]
        frameworks[fw] = {"objc": len(surface.rows), "swift": 0}
        print("%s: %d rows" % (fw, len(surface.rows)), flush=True)
    # The C libraries under usr/include (libSystem and the rest), each directory as a library of its own.
    libraries = []
    if with_include:
        for name, headers in sd.include_libraries(sdk_path).items():
            if only and name not in only:
                continue
            problems = []
            surface = sd.library_surface(sdk_path, name, headers, target, failed=problems)
            failed += problems
            anonymous.update(surface.anonymous)
            rows += [objc_row(name, api, kind, surface.details[api]) for api, (kind, introduced) in surface.rows.items()]
            frameworks[name] = {"objc": len(surface.rows), "swift": 0}
            libraries.append(name)
            print("%s: %d rows" % (name, len(surface.rows)), flush=True)
    walked = sorted(frameworks)
    swift_found = []
    swift_with_rows = set()
    if with_swift:
        swift = load_neighbor("swiftinterface_surface", "swiftinterface-surface.py")
        swift_found = sorted(m for m in swift.interfaces(sdk_path) if not only or m in only)
        problems = []
        for row in swift.rows(sdk_path, set(only) if only else None, problems):
            swift_with_rows.add(row["framework"])
            rows.append({"api": row["api"], "framework": row["framework"], "kind": row["kind"], "lang": "swift",
                         "introduced": show(row["introduced"]), "deprecated": show(row["deprecated"]),
                         "obsoleted": show(row["obsoleted"]), "unavailable": "yes" if row["unavailable"] else "",
                         "via": row["via"]})
            entry = frameworks.setdefault(row["framework"], {"objc": 0, "swift": 0})
            entry["swift"] += 1
        failed += problems
        print("swiftinterface: %d modules found, %d with rows, %d rows" % (len(swift_found), len(swift_with_rows), sum(1 for r in rows if r["lang"] == "swift")), flush=True)
    # A forward declaration (`@class CIImage;`, `@protocol MTLTexture;`) in another framework's header
    # is a row with no version beside the real one; the real one is the row.
    before = collections.Counter(r["lang"] for r in rows)
    versioned = {(r["lang"], r["kind"], r["api"]) for r in rows if r["introduced"]}
    rows = [r for r in rows if r["introduced"] or (r["lang"], r["kind"], r["api"]) not in versioned]
    forward = {lang: before[lang] - sum(1 for r in rows if r["lang"] == lang) for lang in ("objc", "swift")}
    floor = inherit_class_floor(rows)
    counts = collections.Counter((r["framework"], r["lang"]) for r in rows)
    frameworks = {name: {"objc": counts[(name, "objc")], "swift": counts[(name, "swift")]} for name in sorted(frameworks)}
    slashed = [r["api"] for r in rows if r["lang"] == "objc" and "/" in r["api"]]
    if slashed:
        sys.exit("walk_sdk: %d Objective-C row(s) named after a path, an anonymous enum or struct that went through as a name: %s" % (len(slashed), slashed[:3]))
    # Every framework bundle and usr/include library, and every swiftinterface module, that gives no row at all.
    bundles = {entry[:-len(".framework")] for base in sd.framework_bases(sdk_path, target, full=True)
               for entry in os.listdir(base) if entry.endswith(".framework")}
    if only:
        bundles &= set(only)
    with_headers = set(walked)
    modules = set(swift_found)
    no_row = {}
    for name in sorted(bundles | with_headers | modules):
        if frameworks.get(name, {"objc": 0, "swift": 0}) != {"objc": 0, "swift": 0}:
            continue
        no_row[name] = ("headers, none declares an API clang shows" if name in with_headers
                        else "a .swiftinterface with no public declaration" if name in modules
                        else "no headers and no .swiftinterface (a .tbd only)")
    dropped = {"forward-declaration": forward, "anonymous": dict(anonymous), "class-floor": floor,
               "frameworks-walked": len([n for n in walked if n not in libraries]),
               "libraries-walked": len(libraries),
               "no-row": no_row,
               "no-objc-row": [n for n in walked if n not in libraries and not counts[(n, "objc")]],
               "swift-modules-found": len(swift_found),
               "swift-modules-without-rows": [m for m in swift_found if m not in swift_with_rows]}
    print("dropped: %s" % json.dumps(dropped), flush=True)
    return {"sdk": os.path.basename(sdk_path.rstrip("/")), "version": version, "target": target,
            "rows": rows, "frameworks": frameworks, "failed": failed, "libraries": libraries, "dropped": dropped}


_parser = argparse.ArgumentParser(description="SDK-declared API with its availability")
_parser.add_argument("--sdk", help="an iPhoneOS SDK to walk whole (see the docstring); without it the Mac Catalyst run below")
_parser.add_argument("--out", help="with --sdk: where to write (default corpus/sdk-<version>-declared.json)")
_parser.add_argument("--frameworks", help="with --sdk: only these, comma separated")
_parser.add_argument("--no-swift", action="store_true", help="with --sdk: skip the .swiftinterface pass")
_parser.add_argument("--no-include", action="store_true", help="with --sdk: skip the C libraries under usr/include")
options = _parser.parse_args()

sd = load_surface_diff()
if options.sdk:
    result = walk_sdk(sd, os.path.realpath(options.sdk), options.frameworks.split(",") if options.frameworks else None, not options.no_swift, not options.no_include)
    out = options.out or os.path.join(CORPUS, "sdk-%s-declared.json" % result["version"])
    with open(out, "w") as stream:
        json.dump(result, stream)
    print("wrote %d rows, %d failed header(s), to %s" % (len(result["rows"]), len(result["failed"]), out), flush=True)
    sys.exit(0)
sdk = sd.newest_sdk()
IOS_SDK = newest_iphoneos_sdk()
IOS_TARGET = "arm64-apple-ios16.4"
if IOS_SDK:
    print("real iPhoneOS SDK for the Catalyst-only check: %s" % IOS_SDK, flush=True)
else:
    print("no real iPhoneOS SDK found - the Catalyst-only check is skipped, nothing is dropped by it", flush=True)

FRAMEWORKS = ["Foundation","UIKit","Photos","PhotosUI","AVFoundation","AVKit","CoreGraphics","ImageIO",
 "CoreVideo","CoreImage","CoreMedia","Security","CoreServices","MobileCoreServices","WebKit",
 "GameController","CoreTelephony","LocalAuthentication","UserNotifications","CoreData",
 "SafariServices","QuartzCore","CoreLocation","CoreText","CloudKit","Contacts","EventKit",
 "MessageUI","StoreKit","AuthenticationServices","BackgroundTasks","CoreMotion","MapKit",
 "AudioToolbox","Accelerate","VideoToolbox","AVFAudio","Intents","CallKit","PushKit",
 "NetworkExtension","SystemConfiguration","CoreBluetooth","Vision","CoreML","NaturalLanguage",
 # FileProvider was never in this list at all -- not a parsing/macro issue, just absent, found by
 # tracing one crash-demand row (`documentStorageURL`) that could only ever collide with a UIKit
 # entry because its real second owner (NSFileProviderExtension, NSFileProviderManager) had no
 # entry to collide against. Confirmed with declared() directly: both are real, both are in the
 # local SDK header (NSFileProviderExtension.h:99, NSFileProviderManager.h:169), neither needed
 # anything beyond being named here. 69 more real classes across ~20 other frameworks show the
 # same shape (ARKit, CoreHaptics, CoreSpotlight, JavaScriptCore, MediaPlayer, PassKit, ReplayKit,
 # SceneKit, Speech, WatchConnectivity, Messages, Social, MetricKit, ModelIO, OSLog, Metal-family)
 # -- named to the coordinator, not added here without being asked.
 "FileProvider",
 # The other ~20 real frameworks that shared FileProvider's exact shape: present in the local
 # SDK's own headers, simply never named here. Added on the coordinator's explicit instruction
 # after FileProvider's fix, including Metal -- excluded from RANKING via A5_UNREACHABLE
 # (iPhone 4S/iPad 2 lack the hardware), but that is a ranking-time decision, not a reason to
 # keep it invisible to the INDEX: Metal classes remain possible second owners of a colliding
 # selector name, and the index has to be complete for collision resolution regardless of what
 # ranking later does with the result.
 "Metal","MetalKit","MetalPerformanceShaders","SceneKit","CoreHaptics","MediaPlayer","PassKit",
 "Speech","JavaScriptCore","OSLog","CoreSpotlight","Messages","ReplayKit","ARKit","MetricKit",
 "ModelIO","WatchConnectivity","Social",
 # Found by the coverage check itself, on the run right after re-ingesting 8 apps from real
 # binaries (2026-09-23): PDFView (PDFKit) and the two MetalFX descriptor classes -- real demand
 # that only became visible once the corpus held current, real binaries instead of the stale
 # store.json this session started from. Exactly the deviation-from-clean-run signal the check
 # exists to produce.
 "PDFKit","MetalFX"]
out = {}
unverified = []  # (api, kind, framework): no version even after the container fallback, and not
                 # found in the local iPhoneOS SDK either - Catalyst-only or merely newer than
                 # that SDK, indistinguishable from this AST alone; named for a human, not guessed.
for fw in FRAMEWORKS:
    try:
        rows = sd.declared(sdk, fw, "arm64-apple-ios26.0-macabi")
    except SystemExit as e:
        # Truncated to 60 chars before today only showed "clang failed to import CoreTelephony/C"
        # -- readable enough to look like a normal skip line, not enough to show the actual
        # reason. 240 keeps the log line short but leaves the return code and the fatal-error
        # text intact.
        print(f"{fw}: skipped ({str(e)[:240]})", flush=True); continue
    except Exception as e:
        print(f"{fw}: error {e}", flush=True); continue
    real_ios = None
    if IOS_SDK:
        try:
            real_ios = sd.declared(IOS_SDK, fw, IOS_TARGET)
        except Exception as e:
            print(f"{fw}: iPhoneOS cross-check skipped ({str(e)[:60]})", flush=True)
    for api, (kind, ver) in rows.items():
        if ver is None and real_ios is not None and api not in real_ios:
            unverified.append((fw, kind, api))
        v = ".".join(map(str, ver)) if ver else None
        cur = out.get(api)
        # A forward declaration (@class CNContact;) in an earlier framework's header records the class with
        # no version and would win over the real definition dumped later; prefer the row that has a version.
        if cur is None or (cur[1] is None and v is not None):
            out[api] = [kind, v, fw]
    print(f"{fw}: {len(rows)} rows", flush=True)
json.dump(out, open(os.path.join(CORPUS, "sdk-introduced.json"), "w"))

# FRAMEWORKS is a hand-maintained list and it already drifted silently once (FileProvider was
# simply never added; found only by tracing one crash-demand row by hand, half a session later).
# A hardcoded list that can go stale without anything saying so is the wrong shape by itself, per
# the coordinator: derive coverage from what the corpus actually needs, not from memory. Full
# derivation isn't done here (store.json's own framework label is unreliable for this --
# NSFileProviderExtension is attributed to "UIKit" there despite needing FileProvider's header,
# so a label-driven auto-list would have propagated the same undercount) -- this is the mandated
# minimum instead: after every run, name every real class the corpus holds that ISN'T in `out`
# and isn't a known non-SDK name, loudly, so the next gap surfaces on its own first run rather
# than through another half-session of manual tracing.
KNOWN_NON_SDK = {
    # Swift runtime internals -- synthesized by the compiler, no ObjC header exists to dump.
    "SwiftNativeNSObject", "_TtCs12_SwiftObject",
    # libdispatch/os_log C-level objects (OS_OBJECT_DECL macro) -- no @interface, nothing for
    # declared()'s ObjCInterfaceDecl/ObjCMethodDecl walk to find even if the framework is scanned.
    "OS_dispatch_group", "OS_dispatch_queue", "OS_dispatch_source", "OS_os_log",
    # This repo's OWN backport-side classes, not Apple's -- e.g. NSConstantDoubleNumber is
    # `implemented` in the registry at 13.0; there is no Apple header to have declared it.
    "NSConstantArray", "NSConstantDictionary", "NSConstantDoubleNumber", "NSConstantIntegerNumber",
    # Genuinely private Apple class: exported at the link level (present in Messages.framework's
    # own .tbd) but declared in no public header anywhere under Messages.framework -- checked
    # directly, `grep` across every .h in the framework finds nothing. declared() can only ever
    # find header-declared API by construction (it works by #import, not by reading .tbd exports),
    # so this is a structural blind spot of the method itself, not a missing framework and not a
    # broken import -- Messages itself scans fine (102 rows).
    "_MSStickerPackCollectionViewDataSource",
}
_store_candidates = [p for p in [
    os.environ.get("CHARON_TOOLS_DIR") and os.path.join(os.environ["CHARON_TOOLS_DIR"], "store.json"),
    os.path.join(CORPUS, "store.json"),
] if p]
_store_path = next((p for p in _store_candidates if os.path.isfile(p)), None)
if _store_path is None:
    print("FRAMEWORKS coverage check: no store.json found (looked in %s) -- cannot check the "
          "index against real corpus demand this run. Not fatal to sdk-introduced.json itself, "
          "but this safety net did not run." % ", ".join(_store_candidates), flush=True)
else:
    _store = json.load(open(_store_path))
    _corpus_classes = set()
    for _app, _d in _store["apps"].items():
        for _e in _d["demand"]:
            if _e.get("kind") == "class":
                _corpus_classes.add(_e["name"])
    _uncovered = sorted(c for c in _corpus_classes if c not in out and c not in KNOWN_NON_SDK)
    if _uncovered:
        print("FRAMEWORKS COVERAGE GAP: %d real corpus class(es) are absent from "
              "sdk-introduced.json and not in the known-non-SDK allowlist -- FRAMEWORKS is "
              "probably missing a real framework (the FileProvider shape) or that framework's "
              "import is silently failing (the CoreTelephony shape). Not dropped, not guessed at:"
              % len(_uncovered), flush=True)
        for c in _uncovered:
            print("  %s" % c, flush=True)
    else:
        print("FRAMEWORKS coverage check: every one of %d corpus classes is either indexed or "
              "a known non-SDK name (%d allowlisted). No gap found this run."
              % (len(_corpus_classes), len(KNOWN_NON_SDK)), flush=True)
with open(os.path.join(CORPUS, "sdk-introduced-unverified.tsv"), "w") as stream:
    stream.write("framework\tkind\tapi\treason\n")
    for fw, kind, api in sorted(unverified):
        stream.write("%s\t%s\t%s\tno version of its own or its container's, and not declared in the local iPhoneOS SDK either - Catalyst-only or newer than that SDK, not distinguished here\n" % (fw, kind, api))
print("SDK-DONE total", len(out), "unversioned-and-unverified", len(unverified), "(listed, not dropped - see corpus/sdk-introduced-unverified.tsv)", flush=True)
