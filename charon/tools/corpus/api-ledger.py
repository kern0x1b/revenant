#!/usr/bin/env python3
"""
The API ledger: a MEASURED status for every row of coordination/corpus/sdk-26.2-surface.tsv at
iOS 6.1.3, read from built artifacts. The surface's own `registry` column is carried through
untouched, and apple-backports' registry -- the one this ledger exists to check -- places no row of
any kind. A Swift row may be placed `declared` from
a *Swift package's own* registry when no built armv7 module for it is on this machine to check it
against; that is a record of intent, not a measurement, which is why it is its own status and its
own column.

status, one per row:

  implemented  the row's run-time symbol is there: a built apple-backports dylib of the port's
               own 6.1.3 gate carries the class/method/property, or the symbol is exported by the
               release's own 6.1.3 dyld shared cache (so the release already ships it).
  header-ok    the row is header-only -- a type, an enum case, a static or inline function -- and
               its declaration is present in the LIFTED 26.2 headers with no iOS availability that
               gates it past 6.1.3. The port needs no code for it: once the lift has lowered the
               availability, it exists.
  missing      measured as not there: no class, no selector, no symbol, or a declaration the lift
               still marks as introduced after 6.1.3 (an availability that was not lowered), or
               NS_UNAVAILABLE in the lifted headers.
  undecided    this tool cannot place the row, and says why. It is never a guess.
  unmeasured   the row is Swift-only and the Swift pass is not written yet (see below).

The three things a row is measured against:

  1. the built 6.1.3 libraries   a gate run's lib*Backports.dylib: ObjC metadata through
     tools/corpus/objc-inventory.lua (the driver's own apple.objc reader), exported symbols
     through `nm -gU`.
  2. the release's own cache     ~/.charon/dyld/<release>/dyld_shared_cache_armv7: the same ObjC
     reader over the whole cache, plus tools/corpus/dump-cache.lua for its exports. A row the
     release already ships counts as implemented -- it works on the release.
  3. the lifted headers          one clang -ast-dump per framework, target armv7-apple-ios6.1.3,
     -isysroot the real 26.2 SDK and -ivfsoverlay the lift's vfs.yaml, walked by the same
     surface-diff-latest.py that built the surface: umbrella first, then every other header of
     the framework (an umbrella leaves public headers out), one translation unit, and one per
     header when the lot does not parse. This is where the header-only rows are placed.

Swift rows (lang=swift, 65145) are measured by api-ledger-swift.py, which reads the armv7 Swift
modules the port builds with the toolchain's own swift-api-digester and indexes every declaration by
its qualified name (`--swift-modules swift-modules.json`). A row is `implemented` when that name is
in a built module, `missing` when its own framework's module is built and the name is not in it, and
`undecided` when no module this port builds stands for the framework at all -- a vendored reference
interface is recorded as what it measurably is and contributes nothing. Without `--swift-modules`
those rows are `unmeasured`, which is what they were before that pass existed.

Usage:
  python3 api-ledger.py build --surface <tsv> --gate <gate dir with lib*Backports.dylib> \\
      --release 6.1.3 --release-cache <path to dyld_shared_cache_armv7> \\
      --sdk <iPhoneOS 26.2 SDK> --vfs <lift vfs.yaml> --out <output dir> \\
      [--cache-dir <dir>] [--jobs N] [--frameworks F1,F2,...]
"""
import argparse
import collections
import concurrent.futures
import csv
import hashlib
import importlib.util
import json
import os
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.realpath(__file__))
CHARON_ROOT = os.path.realpath(os.path.join(HERE, "..", ".."))
TARGET = "armv7-apple-ios6.1.3"

SURFACE_COLUMNS = ["framework", "kind", "lang", "api", "introduced", "deprecated", "obsoleted",
                   "unavailable", "via", "getter", "registry", "owner-registry", "demand-rank",
                   "demand-severity", "demand-apps", "demand-telegram", "impl-lead", "impl-file-lead"]

# The run-time kinds resolve against the built libraries and the release cache; the header-only and
# ambiguous kinds go to the header pass. Every objc kind in the surface is in one of these.
RUNTIME_KINDS = {("class", "objc"), ("method", "objc"), ("property", "objc")}
SYMBOL_KINDS = {("constant", "objc"), ("function", "objc")}
HEADER_KINDS = {("enum", "objc"), ("protocol", "objc"), ("struct", "objc")}

# The header walk records an enum case and an extern variable both as "constant" (that is
# surface-diff-latest.Surface's own naming), and a static/inline function and a real one both as
# "function". index["flags"] tells the two apart: only a top-level VarDecl/FunctionDecl is in it.


def load_surface(path):
    rows = []
    with open(path, newline="", encoding="utf-8") as f:
        r = csv.reader(f, delimiter="\t")
        head = next(r)
        assert head == SURFACE_COLUMNS, "surface tsv header changed shape: %r" % (head,)
        for line in r:
            if line:
                rows.append(dict(zip(SURFACE_COLUMNS, line)))
    return rows


def load_neighbour(name, filename):
    path = os.path.join(HERE, filename)
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


# The one package whose registry is not a Swift registry: apple-backports' is the registry this
# ledger exists to check, so it places no row of any kind. A Swift registry is a Swift package's
# own -- createml's, RealityKit's.
SWIFT_ONLY_PACKAGE = "packages/a/apple-backports"
DECIDED_STATUSES = ("absent", "inert", "ignored")
DIAGNOSTIC_LIMIT = 5


def decide(row, registries, diagnostics):
    """(status, reason, introduced, needs) when a registry has decided this row, else None.

    A registry that records the row `absent`, `inert` or `ignored` has decided it, with a reason,
    so it is not a row anybody is going to build and it should not sit in a to-do list. Objective-C
    only: a Swift package's `absent` is that package's record of its own work, and
    apple-backports' registry is the one this ledger checks.

    A pass that places nothing is a key mismatch until it is proved otherwise, so the first few rows
    whose api is in no registry print the key the corpus row has and the nearest keys the registry
    holds -- which is how a normalisation gap shows itself instead of being guessed at.
    """
    if row["lang"] != "objc":
        return None
    api = row["api"]
    for key in registry_keys_for(api):
        found = registries.get(key)
        if found and found[0] in DECIDED_STATUSES:
            status, reason, package = found
            return ("decided", "%s in %s's registry: %s"
                    % (status, package, reason or "no reason recorded"), None, "none")
    if len(diagnostics) < DIAGNOSTIC_LIMIT:
        diagnostics.append((api, nearest_registry_keys(api, registries)))
    return None


def registry_keys_for(api):
    """The keys a registry may hold a row under. The corpus writes a method as `-[C sel]` and a
    property as `C.prop`; a registry writes the same shapes, but also the accessor forms for a
    property, so both are asked for rather than one assumed."""
    keys = [api, api.replace("()", "")]
    found = re.match(r"^([\w]+)\.([\w]+)$", api)
    if found:
        owner, prop = found.groups()
        keys += ["-[%s %s]" % (owner, prop), "-[%s set%s%s:]" % (owner, prop[0].upper(), prop[1:]),
                 "+[%s %s]" % (owner, prop)]
    return list(dict.fromkeys(keys))


def nearest_registry_keys(api, registries):
    """What the registry does hold that looks like this row, so a mismatch can be read rather than
    guessed: the same base name, or the same owner."""
    base = api.split("(")[0]
    owner = api.split(".")[0]
    near = [k for k in registries if k.split("(")[0] == base or k.split(".")[0] == owner]
    return sorted(near)[:3]


def default_checkout(surface):
    """The charon checkout the surface sits beside, when --registries is not given.

    Walked up to, not counted: the surface is at <workspace>/coordination/corpus/, three levels
    below the workspace, so taking a fixed number of levels returns the workspace root -- which has no
    `packages/`, so the decide pass read nothing and `decided` came out 0 in the fleet view.
    """
    directory = os.path.dirname(os.path.realpath(surface))
    for _ in range(6):
        candidate = os.path.join(directory, "charon")
        if os.path.isdir(os.path.join(candidate, "packages")):
            return candidate
        parent = os.path.dirname(directory)
        if parent == directory:
            break
        directory = parent
    return directory


def read_package_registries(checkout):
    """{api: (status, reason, package)} over every package's own registry under a checkout: any
    directory named `registry` under packages/, at any depth, so a package nested three deep is
    found without a list to keep. One reader for both the Swift placement and the decide pass."""
    entries = {}
    packages = os.path.join(checkout, "packages")
    if not os.path.isdir(packages):
        return entries
    for base, dirs, _ in os.walk(packages):
        if os.path.basename(base) != "registry":
            continue
        dirs[:] = []
        package = os.path.relpath(os.path.dirname(base), checkout)
        for path, _, files in os.walk(base):
            for name in sorted(files):
                if not name.endswith(".json"):
                    continue
                try:
                    with open(os.path.join(path, name), encoding="utf-8") as f:
                        data = json.load(f)
                except (ValueError, OSError):
                    continue
                for entry in (data.get("entries") if isinstance(data, dict) else data) or []:
                    if entry.get("api"):
                        entries[entry["api"]] = (entry.get("status", ""), entry.get("reason", ""),
                                                 package)
    return entries


def built_tree(gate_dir):
    """What tree a run directory was built from, read from the `tree` file build-gate.lua writes
    there. A directory without one names its own age instead: a worktree's HEAD says nothing about
    what was checked out when a build in it ran, and a report must not name a revision it has not
    read."""
    if not gate_dir:
        # A sentence, not None: this value is printed in a report, and a report that says nothing
        # about its own evidence is the thing this whole band exists to stop.
        return "no --gate given, so nothing here is measured against a build"
    record = os.path.join(gate_dir, "tree")
    if os.path.exists(record):
        fields = {}
        with open(record, encoding="utf-8", errors="replace") as f:
            for line in f:
                parts = line.rstrip("\n").split("\t", 1)
                if len(parts) == 2:
                    fields[parts[0]] = parts[1]
        if fields.get("revision") and fields["revision"] != "unknown":
            return "%s%s" % (fields["revision"][:12],
                             " (dirty)" if fields.get("dirty") == "yes" else "")
    try:
        when = time.strftime("%Y-%m-%d %H:%M", time.localtime(os.path.getmtime(gate_dir)))
    except OSError:
        when = "unknown"
    return "built %s, tree not recorded" % when


def note(message):
    print(message, file=sys.stderr, flush=True)


# ---------------------------------------------------------------------------
# Runtime inventories: ObjC classes/protocols and exported symbols, from a
# built dylib or the release's own dyld shared cache.
# ---------------------------------------------------------------------------

def run_objc_inventory(source, architecture=None):
    """Returns (classes, protocols). Each entry: {"instance": set, "class": set, "protocols": set,
    "superclass": str, "image": str}. A selector name carries a leading "-" for an instance method
    AND for a class method (apple.objc's method_names keys both that way), so a surface row's + or -
    cannot be checked against this view -- the selector name is matched, the sign is not verified."""
    env = dict(os.environ, CHARON_ROOT=CHARON_ROOT)
    args = ["xmake", "l", os.path.join(HERE, "objc-inventory.lua"), source]
    if architecture:
        args.append(architecture)
    out = subprocess.run(args, cwd=CHARON_ROOT, env=env, capture_output=True, text=True, timeout=900)
    if out.returncode != 0:
        raise RuntimeError("objc-inventory.lua failed on %s: %s" % (source, out.stderr[-4000:]))
    classes, protocols = {}, {}
    for line in out.stdout.splitlines():
        parts = line.split("\t")
        if len(parts) != 7:
            continue
        rowkind, name, superclass, image, instance, klass, protos = parts
        entry = {"instance": set(instance.split(",")) if instance else set(),
                 "class": set(klass.split(",")) if klass else set(),
                 "protocols": set(protos.split(",")) if protos else set(),
                 "superclass": superclass, "image": image}
        if rowkind == "class":
            classes[name] = entry
        else:
            protocols[name] = entry
    return classes, protocols


def run_dump_cache(cachefile):
    """The release cache's exported symbol names, leading underscore as the cache names them."""
    env = dict(os.environ, CHARON_ROOT=CHARON_ROOT)
    args = ["xmake", "l", os.path.join(HERE, "dump-cache.lua"), cachefile]
    out = subprocess.run(args, cwd=CHARON_ROOT, env=env, capture_output=True, text=True, timeout=900)
    if out.returncode != 0:
        raise RuntimeError("dump-cache.lua failed on %s: %s" % (cachefile, out.stderr[-4000:]))
    names = set()
    for line in out.stdout.splitlines():
        name = line.split("\t", 1)[0]
        if name:
            names.add(name)
    return names


def run_nm_exports(dylib):
    """Defined external symbols of one Mach-O dylib, keyed with the leading underscore nm prints."""
    out = subprocess.run(["nm", "-gU", dylib], capture_output=True, text=True, timeout=300)
    names = set()
    for line in out.stdout.splitlines():
        fields = line.split()
        if not fields:
            continue
        # "<addr> <type> <name>" for defined, "<type> <name>" for indirect/reexported.
        if len(fields) >= 3 and re.match(r"^[0-9a-fA-F]+$", fields[0]):
            name = fields[2]
        elif len(fields) >= 2:
            name = fields[1]
        else:
            continue
        if name.startswith("_"):
            names.add(name)
    return names


# `@interface NAME` and `@interface NAME : SUPER`, which is how a class's superclass is declared in a
# header. The space before the colon may be a newline (GameKit's GKGameCenterViewController is declared
# that way), and a category -- `@interface NAME (Category)` -- has no colon and so declares no
# superclass, which is what the walk below has to hear about.
INTERFACE_RE = re.compile(r"^@interface\s+(\w+)\s*(?::\s*(\w+))?", re.M)

# What the 26.2 headers declare, for one row's framework: which frameworks the reader found headers
# for, and which class each of them names as a superclass. A name may be declared more than once (a
# class and a category of it, two headers of the same framework), so a name carries the SET of
# superclasses declared for it and the walk below asks whether the release's is among them.
Headers = collections.namedtuple("Headers", "framework supers")


def header_superclasses(sdk):
    """Every class the 26.2 SDK's own framework headers declare a superclass for, by framework.

    `{framework: {class: {superclasses}}}`, read from
    `<sdk>/System/Library/Frameworks/<F>.framework/Headers/*.h` with the reader's own regex, 4196
    headers in 1.0 s. These are the real SDK's headers, not the lift's overlay: the overlay lowers
    availability attributes and changes no declaration, and the surface these rows come from was built
    from this SDK. What the surface builder reads through a clang AST walk
    (`surface-diff-latest.py`'s own `superclass`) is the same declaration read a heavier way.

    This is here because a class NAME is not a class: the 6.1.3 cache's `SKOverlay` is the iOS 6
    overlay, superclass SKLayer -> CALayer, while StoreKit's 26.2 header declares
    `@interface SKOverlay : NSObject` with `id<SKOverlayDelegate> delegate`. A walk that trusts the
    release chain by name alone credits CALayer's `-delegate` for a StoreKit property.
    """
    out = {}
    root = os.path.join(sdk, "System", "Library", "Frameworks")
    for entry in sorted(os.listdir(root)):
        headers = os.path.join(root, entry, "Headers")
        if not entry.endswith(".framework") or not os.path.isdir(headers):
            continue
        declared = {}
        for name in sorted(os.listdir(headers)):
            if not name.endswith(".h"):
                continue
            with open(os.path.join(headers, name), encoding="utf-8", errors="ignore") as f:
                for cls, superclass in INTERFACE_RE.findall(f.read()):
                    if superclass:
                        declared.setdefault(cls, set()).add(superclass)
        if declared:
            out[entry[:-len(".framework")]] = declared
    return out


def load_built_inventories(gate_dir):
    """Every lib*Backports.dylib in gate_dir merged into one view, keeping which framework's
    library carried each name (for the reason column, not for the decision).

    The per-library entries are MERGED, not replaced, because a class NAME is carried by more than
    one library as soon as two of them add a category to it, and a Foundation class is extended by
    half the tree: measured on the 6.1.3 gate of 463407400, NSString is named by three libraries at
    once - libFoundationBackports with fifteen of its own selectors, libSensorKitBackports with
    -sr_sensorForDeletionRecordsFromSensor and libUIKitBackports with six - and only the last of
    the three read here said which selectors the port has, because it came last in the sort. So
    SensorKit's one category on NSString, which is built and answered, read `missing`. Each entry's
    selector sets are the union over the libraries, the way apple.objc's own collect() unions the
    categories of one image (modules/apple/objc.lua:218, :222), and each selector keeps the library
    that carried it so the reason column names the one that answers rather than the first."""
    classes, protocols, exports = {}, {}, {}
    dylibs = sorted(f for f in os.listdir(gate_dir) if f.endswith(".dylib") and f.startswith("lib"))
    assert dylibs, "%s holds no lib*.dylib -- not a gate output directory" % gate_dir

    def merge(into, found, framework):
        for name, entry in found.items():
            held = into.get(name)
            if held is None:
                entry["library"] = framework
                entry["where"] = {}
                into[name] = entry
                continue
            if not held["superclass"] and entry["superclass"]:
                # A library that only extends the class names no superclass; the one that defines
                # it does, and a class has one.
                held["superclass"] = entry["superclass"]
            for kind in ("instance", "class"):
                for selector in entry[kind]:
                    if selector not in held[kind]:
                        held[kind].add(selector)
                        held["where"][selector] = framework
            held["protocols"] |= entry["protocols"]
            if held.get("image") is None:
                held["image"] = entry.get("image")

    for name in dylibs:
        framework = name[len("lib"):-len(".dylib")]
        if framework.endswith("Backports"):
            framework = framework[:-len("Backports")]
        path_ = os.path.join(gate_dir, name)
        found_classes, found_protocols = run_objc_inventory(path_, "armv7")
        merge(classes, found_classes, framework)
        merge(protocols, found_protocols, framework)
        for symbol in run_nm_exports(path_):
            exports[symbol] = framework
    return classes, protocols, exports


def built_why(entry, selector=None):
    """`built: <library>` for a row, naming the library that carries the selector when the row names
    one. A class two libraries both extend is named by both, and the library that carries the class is
    not always the one that carries the member the row is about."""
    where = entry.get("where") or {}
    return "built: " + where.get(selector, entry["library"])


# ---------------------------------------------------------------------------
# Run-time classification
# ---------------------------------------------------------------------------

METHOD_RE = re.compile(r"^([-+])\[([\w]+)(?:\([\w]+\))? (.+)\]$")
PROPERTY_RE = re.compile(r"^([\w]+)\.([\w]+)$")


def classify_class(api, built_classes, built_protocols, release_classes, release_protocols):
    if api in built_classes:
        return "implemented", "built: " + built_classes[api]["library"]
    if api in release_classes:
        return "implemented", "release-native: 6.1.3 dyld cache"
    # A few surface "class" rows are protocols under Swift-derived naming; present is present.
    if api in built_protocols:
        return "implemented", "built protocol: " + built_protocols[api]["library"]
    if api in release_protocols:
        return "implemented", "release-native: a protocol in the 6.1.3 dyld cache"
    return "missing", "no class or protocol %s in the built libraries or the 6.1.3 cache" % api


def _selector_present(entry, selector):
    """apple.objc keys a selector with a leading '-' for both instance and class methods, so a row's
    own sign is not checked here; the name is."""
    return selector in entry["instance"] or selector in entry["class"]


def _ancestors(owner, built_classes, release_classes, header=None):
    """The chain above `owner`, one measured ancestor at a time, and where the walk stopped.

    Returns `(chain, held)`. `chain` holds `(name, entries)` for every ancestor above `owner` the two
    inventories carry, nearest first, and `entries` is the list of `(entry, is_built)` pairs that name
    carries -- one, or both where the name is in both inventories, which is the ordinary case for a
    class the port only extends with categories (NSObject: the port's own categories plus the
    device's own, both measured, and the caller names whichever of the two has the selector). `held` is
    the clause a missing row's reason carries, or "": the recorded superclass the walk could not
    measure, or the release edge the 26.2 header disagrees with.

    A member is answered from up the chain only where the ancestor that answers it is measured at the
    release the row is measured for, and the caller's reason names the inventory that has the
    selector. That is the whole of the rule -- the port's classes are linked beside the device's, so a
    port class whose declared superclass is a release class inherits what the release declares, and a
    release class inherits up the release's own chain -- and it is why an ancestor in neither inventory
    stops the walk instead of being assumed to answer nothing.

    A name in the built inventory is not the port's own class: `load_built_inventories` merges every
    library that extends a class into one entry, so NSObject is "built" as soon as one library adds a
    category to it, and the entry then holds the port's selectors and no other. The pair is kept apart
    for that reason, and a `-init` found on the device's NSObject is reported as the release's.

    `header` is what the 26.2 headers declare for the row's own framework (`header_superclasses`), and
    it is asked about one thing only: **a step taken in the RELEASE inventory's chain is taken only
    while the header agrees with it.** A class NAME is not a class -- the 6.1.3 cache's `SKOverlay` is
    the iOS 6 overlay, superclass SKLayer -> CALayer, where StoreKit's 26.2 header declares
    `@interface SKOverlay : NSObject` -- and a member of the release's namesake is not the row's member.
    So where the release records a superclass for the class the step leaves and the header declares a
    superclass that is not it, the walk stops and says so, and the row keeps its own reading. A step
    taken in the BUILT image is the port's own compiled hierarchy and is never questioned: the port
    declares its own superclass and the release cache's chain above it is not what the port ran
    against. Where the header declares no superclass for the class -- a category-only declaration, or a
    class this SDK's headers do not name -- there is nothing to disagree with and the walk goes on.

    The owner itself is not in `chain`: the caller has already looked in its own selector sets. The
    walk follows the `superclass` edge `load_built_inventories` records per class, and `seen` is what
    makes it terminate on a chain that loops back on itself, which no measured inventory has and which
    is not this reader's to assume away.

    A class-scoped row reader walks a chain as well, for its own question: one release at a time, out of
    its own inventory line format, with no built/release split to name. This one is asked which of two
    inventories proves the row, so it carries both.
    """
    chain, seen, current = [], {owner}, owner
    while True:
        built = built_classes.get(current)
        entry = built if built is not None else release_classes.get(current)
        if entry is None:
            return chain, (", and %s is in neither the built libraries nor the 6.1.3 cache, so the "
                           "walk could not start" % current)
        superclass = entry["superclass"]
        if not superclass or superclass in seen:
            return chain, ""
        if built is None and header is not None:
            declared = header.supers.get(current)
            if declared and superclass not in declared:
                return chain, (", and the 6.1.3 cache's %s has superclass %s where %s's 26.2 header "
                               "declares %s, so the class above it was not asked"
                               % (current, superclass, header.framework,
                                  " or ".join(sorted(declared))))
        seen.add(superclass)
        entries = []
        found = built_classes.get(superclass)
        if found is not None:
            entries.append((found, True))
        found = release_classes.get(superclass)
        if found is not None:
            entries.append((found, False))
        if not entries:
            return chain, (", and the superclass %s above %s is in neither the built libraries nor "
                           "the 6.1.3 cache, so nothing above it could answer" % (superclass, current))
        chain.append((superclass, entries))
        current = superclass


def _held_note(unavailable, api, decided):
    """The clause a held-back row's reason carries, or "" when nothing holds it back.

    A row the walk was not allowed to ask is a row whose reason must not read as an absence: the
    selector may well be in the class above it, and the only reason it is not credited is a fact about
    the row. `+[UIKeyCommand commandWithTitle:image:action:propertyList:]` is the case to read -- its
    reason used to say the selector is not there, while UICommand declares it and UIKeyCommand.h:108
    marks the row NS_UNAVAILABLE.
    """
    if unavailable:
        return (", and Apple's own header marks this row NS_UNAVAILABLE, so nothing answers it at run "
                "time and the class above it was not asked")
    if api in (decided or ()):
        return ", and a registry has decided this row, so the class above it was not asked"
    return ""


def classify_method(api, built_classes, release_classes, built_protocols=None, release_protocols=None,
                    decided=None, unavailable=False, header=None):
    """A method row's owner is named without saying whether it is a class or a protocol, and the
    surface has both, so both are searched: a protocol that declares the selector is the release
    carrying that API. Looking only at classes read `-[CLLocationManagerDelegate
    locationManager:didDetermineLocation:error:]` missing while the 6.1.3 cache declares it.

    One selector is answered without the owner declaring it: `+new`. It is NSObject's, and every
    class inherits it -- measured in the release's own 6.1.3 cache, 2 of 11378 classes declare
    `+new` in their own metaclass list (NSObject and _PFCachedNumber) and 11376 inherit it, so a row
    whose owner is a class that does not declare it reads "selector new is not" for a selector the
    release carries. The port's own libraries do not declare it either, and do not need to: they are
    loaded beside the device's libSystem, whose NSObject has it. `decided` holds the rows a registry
    has decided, and this never applies to one of them -- `+[VNFaceLandmarkRegion new]` is answered
    by NSObject's `+new` only to call the class's own NS_UNAVAILABLE `-init`, which is a measurement
    somebody took, and an inference from the release's metadata does not overrule it. Protocols are
    not reached this way: a protocol has no metaclass chain to inherit from.

    A member a superclass implements is answered from up the chain, which no own table can see: the ten
    UIKeyCommand rows are the measurement. The built 6.1.3 image holds `UIKeyCommand` with superclass
    `UICommand`, and `UICommand` declares `-action`, `-title` and
    `+commandWithTitle:image:action:propertyList:` while `UIKeyCommand` declares none of them, so all
    ten read "selector X is not" for members the port carries.

    The walk is LAST -- after the owner's own sets, the protocols and `+new` -- so nothing that reads
    implemented today can read anything else: only a row that read missing moves, and only to
    implemented.

    It is also held back by two facts about the row, for the reason `+new` gives: a row a registry has
    decided, and a row Apple's own header marks NS_UNAVAILABLE, are not answered by an inference from
    the release's metadata. Measured on the whole surface, the first is 13 rows -- ten
    `-[VN*Request init]`/`initWithCompletionHandler:` whose registry row says Apple's own header marks
    the initialiser unavailable, two `UITextInputTraits` properties the port answers on NSObject under
    a row of its own, and `+[NSURLSessionStreamTask new]`. The second is 59, and it holds the two
    UIKeyCommand factories this walk was written for: UIKeyCommand.h:108 and :113 mark
    `+commandWithTitle:image:action:propertyList:` and its `alternates:` form NS_UNAVAILABLE, so a
    program that names them does not compile and no release answers them. The eight UIKeyCommand
    properties are not marked, and they move."""
    m = METHOD_RE.match(api)
    if not m:
        return "undecided", "method api does not parse as +/-[Class sel]: %r" % api
    sign, owner, selector = m.groups()
    key = "-" + selector
    built = built_classes.get(owner)
    if built and _selector_present(built, key):
        return "implemented", built_why(built, key)
    released = release_classes.get(owner)
    if released and _selector_present(released, key):
        return "implemented", "release-native: 6.1.3 dyld cache"
    for protocols, why in ((built_protocols or {}, "built: "), (release_protocols or {},
                                                                   "release-native: 6.1.3 dyld cache")):
        entry = protocols.get(owner)
        if entry and _selector_present(entry, key):
            label = why + (entry.get("library", "") if why == "built: " else "")
            return "implemented", label + " (the protocol %s declares it)" % owner
    if sign == "+" and selector == "new" and api not in (decided or ()) \
            and (owner in built_classes or owner in release_classes):
        # The owner is a class -- a protocol is answered or excluded above, and a name in neither
        # inventory falls to the line below -- and the release's own NSObject carries `+new`, which
        # every class inherits. The reason names the measurement rather than the port, because the
        # port is not what answers it: the device's libSystem NSObject is.
        return "implemented", ("+new is NSObject's and every class inherits it: the 6.1.3 cache's "
                               "own NSObject declares it and 2 of its 11378 classes declare one of "
                               "their own")
    # `built or released` keeps a protocol owner out: a protocol has no superclass to walk, and the
    # reason below already says the owner is a protocol and not a class. The two guards are `+new`'s,
    # for the reason in this function's own account: a row a registry has decided, and a row Apple's
    # own header marks NS_UNAVAILABLE, are both facts about the row that an inference from the
    # release's metadata must not overrule -- and a held-back row is not walked at all, so it carries
    # its guard's clause and not the walk's.
    held, stopped = _held_note(unavailable, api, decided), ""
    if (built or released) and not held:
        chain, stopped = _ancestors(owner, built_classes, release_classes, header)
        for name, entries in chain:
            for entry, is_built in entries:
                if _selector_present(entry, key):
                    why = built_why(entry, key) if is_built else "release-native: 6.1.3 dyld cache"
                    return "implemented", "%s (inherited from %s)" % (why, name)
    if not built and not released and not (built_protocols or {}).get(owner) \
            and not (release_protocols or {}).get(owner):
        return "missing", "owner %s is neither a class nor a protocol in the built libraries or the 6.1.3 cache" % owner
    return "missing", "%s is there, selector %s is not%s%s" % (owner, selector, held, stopped)


def classify_property(api, built_classes, release_classes, built_protocols=None,
                      release_protocols=None, getter=None, setter=None, decided=None,
                      unavailable=False, header=None):
    """A property row's owner is named without saying whether it is a class or a protocol, and the
    surface has both, so both are searched -- the same question classify_method answers, and for the
    same reason. A property is read through its accessors, so it is the accessors that are looked
    for, in the instance set and in the class set: a `@property (class, readonly)` is read through a
    class method, and its getter is a class selector and never an instance one.

    `getter` and `setter` are what the header declared (`@property (readonly, getter=isSupported)`),
    which the surface records and which is the only way to know the accessor is not the property's own
    name: `AVAudioSessionCapability.supported` is read through `-isSupported`, and a selector derived
    from the name alone asks for `-supported`, which no release declares. They arrive as clang prints
    them (`isSupported`, `setSupported:`) and are turned into selectors here, the same leading dash
    the inventories carry. Where the header declared nothing the accessor is derived as it was before.

    The chain is walked last, for the same reason and with the same rule as classify_method: the eight
    UIKeyCommand properties the built image answers from `UICommand` are the measurement, and the two
    accessors are looked for in every measured ancestor's own sets, the class set included. The
    `decided` and `unavailable` rows are held back from the walk here for the reason
    classify_method gives: an inference from the release's metadata does not overrule a fact about the
    row itself."""
    m = PROPERTY_RE.match(api)
    if not m:
        return "undecided", "property api does not parse as Class.prop: %r" % api
    owner, prop = m.groups()
    getter = "-" + getter if getter else "-" + prop
    setter = "-" + setter if setter else "-set" + prop[0].upper() + prop[1:] + ":"

    def carried_by(entry):
        """The accessor `entry` holds, or None.

        The instance set, or the class set: a `@property (class, readonly)` is read through a class
        method, so its getter is a class selector and never an instance one -- NSUnitLength has 23
        class selectors and no instance selector at all, and every one of its properties read missing
        while the built library carries it."""
        return next((sel for sel in (getter, setter)
                     if sel in entry["instance"] or sel in entry["class"]), None)

    for classes, why in ((built_classes, None), (release_classes, "release-native: 6.1.3 dyld cache")):
        entry = classes.get(owner)
        if not entry:
            continue
        carried = carried_by(entry)
        if carried:
            return "implemented", (why or built_why(entry, carried)) + (
                " (a class property: read through %s)" % getter
                if getter in entry["class"] and getter not in entry["instance"] else "")
    for protocols, why in ((built_protocols or {}, "built: "), (release_protocols or {},
                                                              "release-native: 6.1.3 dyld cache")):
        entry = protocols.get(owner)
        if entry and carried_by(entry):
            label = why + (entry.get("library", "") if why == "built: " else "")
            return "implemented", label + " (the protocol %s declares it)" % owner
    held = _held_note(unavailable, api, decided)
    stopped = ""
    if (owner in built_classes or owner in release_classes) and not held:
        # A protocol owner is not in either, so it never reaches the walk: a protocol has no
        # superclass, and the reason below already says the owner is neither.
        chain, stopped = _ancestors(owner, built_classes, release_classes, header)
        for name, entries in chain:
            for entry, is_built in entries:
                carried = carried_by(entry)
                if carried:
                    why = built_why(entry, carried) if is_built else "release-native: 6.1.3 dyld cache"
                    return "implemented", "%s (inherited from %s)%s" % (
                        why, name,
                        " (a class property: read through %s)" % getter
                        if getter in entry["class"] and getter not in entry["instance"] else "")
    if owner not in built_classes and owner not in release_classes \
            and not (built_protocols or {}).get(owner) and not (release_protocols or {}).get(owner):
        return "missing", "owner class %s not in the built libraries or the 6.1.3 cache" % owner
    return "missing", "%s is there, neither %s nor %s is an instance or a class selector%s%s" % (
        owner, getter, setter, held, stopped)


def classify_symbol(api, built_exports, release_exports):
    """implemented when the linker symbol is somewhere; (None, None) when the row is ambiguous and
    the header pass has to say whether it needs a symbol at all."""
    name = api[:-2] if api.endswith("()") else api
    symbol = "_" + name
    if symbol in built_exports:
        return "implemented", "built: " + built_exports[symbol]
    if symbol in release_exports:
        return "implemented", "release-native: 6.1.3 dyld cache"
    return None, None


# ---------------------------------------------------------------------------
# Header pass: one clang -ast-dump per framework, against the LIFTED 26.2
# headers at the port's own target, walked by surface-diff-latest.py -- the
# same walk that built the surface -- and cached per framework.
# ---------------------------------------------------------------------------

# Every top-level VarDecl and FunctionDecl in the dump, with the qualifiers that decide whether the
# declaration needs a linker symbol or is only a header. A line of the dump at depth 0 is exactly
# one starting with "|-", so the scan skips the rest without touching a regex.
STORAGE_KINDS = ("VarDecl", "FunctionDecl")
TYPEDEF_KIND = "TypedefDecl"
QUOTED_RE = re.compile(r"'([^']*)'")
# What decides internal linkage, and where the answer is read from. clang prints the entity's linkage
# on EVERY line it prints for it, whether or not that line repeated the source's keyword, and that is
# the compiler's own answer rather than a keyword this tool happens to spell. Measured 2026-10-03 with
# clang 23.1.1 (`charon@llvm`, the one the ledger's own clang_command resolves) over link.c, one
# declaration per storage form:
#   int extern_fn(void);                          -> "extern external-linkage"
#   static int static_fn(void);                  -> "static internal-linkage"
#   static inline int inline_fn(void) {...}       -> "static inline internal-linkage"
#   inline int plain_inline_fn(void) {...}        -> "inline external-linkage"
# The CLT's /usr/bin/clang prints NO linkage token at all -- the same four declarations come out as
# "extern", "static", "static inline", "inline" and nothing more -- so the keyword stays as the
# fallback and the answer is the same under either compiler.
#
# Neither answer alone was enough, because the defect was not the spelling but WHICH LINE was read.
# A function declared `static inline` through a macro and DEFINED later without repeating it is
# printed `implicit-inline internal-linkage` on its definition and `static inline internal-linkage`
# on its declaration: no `static` token anywhere on the definition line, and `implicit-inline` has a
# hyphen where `" inline"` looks for a space. That is every one of Spatial's 640 C functions -
# Spatial/Base.h:34 `#define SPATIAL_INLINE static inline`, and the definition at
# SPAffineTransform3D.h:879 is preceded by SPATIAL_REFINED_FOR_SWIFT and SPATIAL_OVERLOADABLE only.
# The scan kept the LAST line per name, so all 640 read (extern, static) as (false, false) and the
# classification's `if is_extern or not is_static` placed every one of them `missing`, "the port has
# to export it", for an API no Apple binary exports and every caller inlines.
INTERNAL_LINKAGE = "internal-linkage"
EXTERNAL_LINKAGE = "external-linkage"


def scan_storage(lines, flags, typedefs=None):
    """{top-level name: (extern, static, inline, declared type)} for every VarDecl and FunctionDecl
    in a dump. A line at depth 0 is exactly one starting with "|-", so the rest of the dump is
    skipped on a prefix test instead of a regex. An enum case is a depth-1 EnumConstantDecl and so
    is absent here -- which is how the classification tells a case (header-only) from an extern
    variable. The declared type is the first quoted token after the name, and it is what says how
    wide the constant's value is when const-values.py reads it out of a dyld cache.

    The flags MERGE across every line that names the same entity rather than the last one winning: a
    declaration and its definition are one function, so a later line that omits what an earlier one
    carried must not uncarry it."""
    for line in lines:
        if not line.startswith("|-"):
            continue
        kind, _, rest = line.partition(" ")          # "|-FunctionDecl"
        kind = kind[2:]
        if kind == TYPEDEF_KIND and typedefs is not None:
            _, _, rest = rest.partition(" ")         # the 0x... address
            quoted = QUOTED_RE.findall(rest)
            if quoted:
                # "referenced CFNotificationName 'CFStringRef':'const struct __CFString *'": the
                # name is the last token before the first quote, the underlying type the last one.
                typedefs[rest.split("'")[0].split()[-1]] = quoted[-1]
            continue
        if kind not in STORAGE_KINDS:
            continue
        _, _, rest = rest.partition(" ")             # the 0x... address
        # The same expression surface-diff-latest.Surface uses for a VarDecl/FunctionDecl name.
        name = rest.split("'")[0].split()[-1]
        # Both ends of the sugar chain, because both say something: a sugar chain prints as
        # 'sugared':'canonical' (AVAudioSessionLocationLower 'const AVAudioSessionLocation
        # _Nonnull':'NSString *const'). The canonical one is the type; the sugared one is the name
        # the source wrote, which is the only place CGFloat appears -- on armv7, the target this
        # walk reads, CGFloat's canonical type is a 4-byte float, and a value read out of a 64-bit
        # cache is 8 bytes wide.
        quoted = QUOTED_RE.findall(rest)
        found = (EXTERNAL_LINKAGE in rest or " extern" in rest,
                 INTERNAL_LINKAGE in rest or " static" in rest,
                 " inline" in rest or " implicit-inline" in rest,
                 quoted[0] if quoted else "", quoted[-1] if quoted else "")
        seen = flags.get(name)
        if seen is None:
            flags[name] = found
        else:
            # the wider answer stands: a name one entity carries keeps what any of its lines said,
            # and the types are the first line's, which is the declaration rather than the definition
            flags[name] = (seen[0] or found[0], seen[1] or found[1], seen[2] or found[2],
                           seen[3] or found[3], seen[4] or found[4])


class _HeaderSurface:
    """surface-diff-latest.Surface with the storage-class scan folded into the same pass over the
    same dump: walk_imports feeds it every line of every translation unit it reads, so a framework
    that falls back to one translation unit per header is still scanned exactly once per line."""

    def __init__(self, sd, framework, owns=None):
        self.surface = sd.Surface(framework, full=True, owns=owns)
        self.flags = {}
        self.typedefs = {}

    def feed(self, lines):
        scan_storage(lines, self.flags, self.typedefs)
        self.surface.feed(lines)


def _walk(sd, framework, sdk, vfs, failed):
    """The header set and the clang command of declared_surface_full / library_surface, with the
    vfs overlay added and the Surface wrapped so the storage scan rides along. The two setup lines
    (umbrella first, then every other header; the library's owns() predicate) are theirs, not a
    second copy of the walk: walk_imports and Surface are used as they are. The import list and the
    command come back too, so the generated unit below can name the same headers."""
    command = sd.clang_command(sdk, TARGET, full=True, vfs=vfs)
    if framework == sd.INCLUDE_TOP or framework.startswith(sd.INCLUDE_TOP + "/"):
        libraries = sd.include_libraries(sdk)
        headers = libraries.get(framework)
        if headers is None:
            return None, None, None
        if framework == sd.INCLUDE_TOP:
            owns = lambda path: re.search(r"/usr/include/[^/]+$", path) is not None
        else:
            owns = lambda path: "/usr/include/%s/" % framework.split("/", 1)[1] in path
        surface = _HeaderSurface(sd, framework, owns=owns)
        sd.walk_imports(surface, command, headers, failed)
        return surface, list(headers), command
    headers_dir = sd.framework_headers_dir(sdk, framework, TARGET, full=True)
    found = sorted(f for f in os.listdir(headers_dir) if f.endswith(".h")) if headers_dir else []
    imports = [h for h in found if h != framework + ".h"]
    if framework + ".h" in found:
        imports.insert(0, framework + ".h")
    imports = ["%s/%s" % (framework, h) for h in imports]
    surface = _HeaderSurface(sd, framework)
    sd.walk_imports(surface, command, imports, failed)
    return surface, imports, command


def naming_line(kind, api, slot):
    """The one line that names a row, per kind. An enum case is not an lvalue, so a constant is
    read rather than addressed; a type is instantiated through __typeof__ (a plain `enum Foo` tag
    resolves in C); a protocol is named as a protocol qualifier; a function is addressed."""
    if kind == "protocol":
        return "id <%s> *charonLedger%d = 0;" % (api, slot)
    if kind == "function":
        return "__typeof__(%s) *charonLedger%d = &%s;" % (api, slot, api)
    if kind == "constant":
        return "__typeof__(%s) charonLedger%d = %s;" % (api, slot, api)
    return "__typeof__(%s) charonLedger%d;" % (api, slot)


DIAGNOSTIC_RE = re.compile(r"^[^:\n]+:(\d+):(\d+): (error|warning): (.*)$")
MACRO_RE = re.compile(r"^#define\s+([A-Za-z_][A-Za-z0-9_]*)\s+(.*)$")


def dump_framework_macros(imports, command, workdir, tag):
    """{name: replacement} for every macro the framework's own headers define, from
    `clang -E -dM`. A macro is a header row by construction -- the value is in the header and no
    symbol is needed -- and one macro is the name of another framework's exported constant, which is
    a case the AST does not show at all: `kCMFormatDescriptionChromaLocation_Bottom` is declared as
    a CFStringRef variable at iOS 9 and then `#define`d to `kCVImageBufferChromaLocation_Bottom`, so
    the name resolves to something the release exports and nothing is missing."""
    if not imports:
        return {}
    source = os.path.join(workdir, "macros-" + re.sub(r"[^A-Za-z0-9_]", "_", tag) + ".m")
    with open(source, "w", encoding="utf-8") as f:
        for header in imports:
            f.write("#import <%s>\n" % header)
    # -E -dM is preprocessing only: the -fsyntax-only and -ast-dump of the syntax command would
    # stop it producing anything at all (measured: 0 macros, no error).
    preprocessing = [c for c in command if c not in ("-Xclang", "-ast-dump", "-fsyntax-only")]
    out = subprocess.run(preprocessing + ["-E", "-dM", source],
                         capture_output=True, text=True, errors="replace", timeout=900)
    macros = {}
    for line in out.stdout.splitlines():
        found = MACRO_RE.match(line)
        if found:
            macros[found.group(1)] = found.group(2).strip()
    return macros


def compile_named_rows(imports, command, rows, workdir, tag):
    """The plan's header-ok test, run literally: a generated translation unit naming every
    header-only row of this framework, compiled for the port's own target against the lifted
    headers. Returns {name: "" when it compiled, else the first error attributed to its line}."""
    if not imports or not rows:
        return {}
    source = os.path.join(workdir, "named-" + re.sub(r"[^A-Za-z0-9_]", "_", tag) + ".m")
    line_of = {}
    with open(source, "w", encoding="utf-8") as f:
        number = 0
        for header in imports:
            f.write("#import <%s>\n" % header)
            number += 1
        f.write("\n")
        number += 1
        for slot, (kind, api) in enumerate(rows):
            f.write(naming_line(kind, api, slot) + "\n")
            number += 1
            # keyed by the STRING a diagnostic carries, because DIAGNOSTIC_RE hands the line over as
            # one. This was keyed by the int, so `line not in line_of` was true for every line of
            # every unit this tool has ever compiled: `verdict` stayed "" for every row, `named_ok`
            # was `name in compiled and True`, and a header-only row of any framework read
            # `header-ok` whether or not its line compiled. Measured on Spatial, where 19 names are
            # SPATIAL_OVERLOADABLE and `&NAME` does not resolve: 19 lines of the generated unit carry
            # "reference to overloaded function could not be resolved", and this function returned 0
            # of 647 rows as failing.
            line_of[str(number)] = slot
    out = subprocess.run(command + ["-fsyntax-only", "-ferror-limit=0", source],
                         capture_output=True, text=True, errors="replace", timeout=900)
    verdict = {api: "" for _, api in rows}
    for text in (out.stderr or "").splitlines():
        found = DIAGNOSTIC_RE.match(text.strip())
        if not found or found.group(3) != "error":
            continue
        line = found.group(1)
        if line not in line_of:
            continue
        api = rows[line_of[line]][1]
        if verdict[api] == "":
            verdict[api] = found.group(4)[:200]
    return verdict


def framework_index(sd, framework, sdk, vfs, cache_dir, workdir, force=False):
    """Everything measured about one framework's lifted headers at TARGET, cached under cache_dir:
    {api: [kind, introduced, unavailable]}, {top-level name: (extern, static, inline)}, and
    {name: diagnostic} from the generated unit naming this framework's header-only rows. A framework
    the walk cannot read returns an index carrying an "error" instead of raising."""
    cache_file = os.path.join(cache_dir, framework.replace("/", "_") + ".json")
    # Keyed over everything the content depends on, this file included (the same rule dyld.lua
    # keeps its own measurements by), so a change to how a declaration is read is a different file
    # rather than a stale one nobody invalidates by hand.
    stamp = {"sdk": os.path.realpath(sdk), "vfs": os.path.realpath(vfs),
             "vfs_mtime": int(os.path.getmtime(vfs)), "target": TARGET,
             "tool": hashlib.sha256(open(os.path.realpath(__file__), "rb").read()).hexdigest()[:12]}
    if not force and os.path.exists(cache_file):
        try:
            with open(cache_file, encoding="utf-8") as f:
                cached = json.load(f)
            if cached.get("stamp") == stamp:
                return cached, True
        except ValueError:
            pass
    failed = []
    surface, imports, command = _walk(sd, framework, sdk, vfs, failed)
    if imports is None:
        imports = []
    if surface is None:
        index = {"stamp": stamp, "error": "no header directory or usr/include library for %s in this SDK"
                 % framework, "rows": {}, "flags": {}, "compiled": {}, "failed": failed, "headers": 0}
    elif not surface.surface.rows:
        index = {"stamp": stamp, "error": "the walk read no declaration of %s at %s" % (framework, TARGET),
                 "rows": {}, "flags": {}, "compiled": {}, "failed": failed, "headers": len(imports)}
    else:
        rows = {}
        for api, (kind, introduced) in surface.surface.rows.items():
            detail = surface.surface.details.get(api) or {}
            rows[api] = [kind, list(introduced) if introduced else None,
                         bool(detail.get("unavailable")), bool(detail.get("unavailable_ios"))]
        # The walk names a function "name()"; the unit has to name the identifier itself.
        named = sorted((kind, api[:-2] if kind == "function" and api.endswith("()") else api)
                       for api, (kind, _) in surface.surface.rows.items()
                       if kind in ("constant", "function", "enum", "protocol", "struct"))
        index = {"stamp": stamp, "rows": rows, "flags": surface.flags,
                 "typedefs": surface.typedefs,
                 "compiled": compile_named_rows(imports, command, named, workdir, framework),
                 "macros": dump_framework_macros(imports, command, workdir, framework),
                 "failed": failed, "headers": len(imports)}
    with open(cache_file, "w", encoding="utf-8") as f:
        json.dump(index, f)
    return index, False


# What a swift-api-digester declaration kind can stand for in a Swift surface row's own kind. The
# digester does not say whether a nominal type is a class, a struct, an enum or a protocol and calls
# two different nodes a type depending on how the declaration was written; the surface row is the
# authority on which it is, and the digester's job is only to prove the name is declared.
def split_qualified(api):
    """The owner and the member, cut at the last "." that is outside parentheses. A generic
    initialiser's argument list carries its own dots -- `Foo.Bar.init?<Value.UnwrappedType>(_ value:
    Value)` -- so a blind rpartition cuts in the wrong place, and a blind split on every dot
    re-attaches an owner that was never there."""
    depth = 0
    for index in range(len(api) - 1, -1, -1):
        char = api[index]
        if char in ")]>":
            depth += 1
        elif char in "([":
            depth -= 1
        elif char == "<":
            depth -= 1
        elif char == "." and depth == 0:
            return api[:index], api[index + 1:]
    return "", api


# The rules the digester needs so its spelling reaches the corpus row's. They are written against a
# *member*, which is why the owner is split off first and re-attached after: run against a
# qualified name they anchor on the wrong end, and `^~=.*` never fires on `Foo.~=(a:)`.
#
#   init?             the digester has no `?` on an initialiser
#   ==                it prints the operator with its parameters, not the canonical `(_:_:)`
#   ~=                it prints a prefix of it
#   subscript         it prints the labels where the surface row carries none
#   generic list      a generic initialiser's row carries the type's own generic parameter list
#                     inside the argument list and the digester prints none of it
#   payload case      it prints `X.() -> Swift.Bool` for a case with an associated value
#   argument labels   it prints the parameters a member takes and no labels at all, which is what
#                     `CGAffineTransform.==(_:_:)` against `CGAffineTransform.==(lhs:rhs:)` is
def _arguments(text):
    """`lhs:rhs:` as the digester prints it, `(_:_:)`. The colons come from the number of
    arguments, not from the string's last character: a single unlabelled parameter prints `(_:)`."""
    count = len(text.split(":")[:-1])
    return "(" + ":".join(["_"] * count) + (":" if count else "") + ")"


SWIFT_MEMBER_RULES = (
    lambda s: re.sub(r"init\?\((.*)\)", r"init(\1)", s),
    lambda s: re.sub(r"subscript\?\(", "subscript(", s),
    lambda s: re.sub(r"^==\(.*\)$", "==(_:_:)", s),
    lambda s: re.sub(r"^~=.*", "~=", s),
    lambda s: re.sub(r"^subscript\((.*)\)$",
                     lambda m: "subscript(_:)" if ":" in m.group(1) else m.group(0), s),
    lambda s: re.sub(r":?<[^()]*>", "", s),
    # A payload case: the digester prints `X.() -> Swift.Bool`, so splitting at the last dot outside
    # parentheses leaves the member as `() -> Swift.Bool` and the case's own name is the owner
    # alone. The index rule for the same shape is in api-ledger-swift.py; this is the row side.
    lambda s: s if s else s,
    # The colons come from the number of arguments, not from the string's last character: a single
    # unlabelled parameter prints `(_:)`.
    lambda s: re.sub(r"\(([^()]*)\)", lambda m: _arguments(m.group(1)), s),
)


# A payload case, which is a whole-name shape and not a member one: the digester prints
# `X.() -> Swift.Bool` for a case with an associated value, so the case's own name is nowhere in the
# index. The index rule for the same shape is in api-ledger-swift.py; this is the row side, and it
# runs before the split because `Swift.Bool` puts a dot outside every bracket.
SWIFT_PAYLOAD_CASE = re.compile(r"\.\(\s*\)?[^ ]* -> .*$")


def swift_forms(api):
    """Every spelling of this declaration a built module might carry it under: the name as written,
    and each member rule's result re-attached to the owner."""
    api = SWIFT_PAYLOAD_CASE.sub("", api)
    owner, member = split_qualified(api)
    forms = [api]
    # The rules compose: the generic-list rule turns `init?<Value.UnwrappedType>(_ value: Value)`
    # into `init?(_ value: Value)`, and only the `init?` rule applied to *that* removes the `?`, and
    # only the label rule after that gives `init(_)`. So each rule is swept over every form held so
    # far, and the sweep repeats while it still finds something, bounded so a rule that widens rather
    # than narrows cannot run away.
    for _ in range(4):
        before = len(forms)
        for normal in SWIFT_MEMBER_RULES:
            for text in list(forms):
                # The same depth-aware cut on every form: a derived one still carries its generic
                # list, and a blind rpartition cuts inside it.
                part_owner, tail = split_qualified(text)
                changed = normal(tail)
                if changed != tail:
                    forms.append(("%s.%s" % (part_owner, changed)) if part_owner and changed
                                 else (part_owner or changed))
        forms = list(dict.fromkeys(forms))
        if len(forms) == before:
            break
    return forms


SWIFT_COMPATIBLE = {
    # A type kind takes a typealias too: a typealias is a name that resolves to a type, so code that
    # uses the name compiles against it, and the port declaring `Timer.TimerPublisher` as a typealias
    # where the 26.2 SDK declares a class is a difference worth naming, not a row to call undecided.
    "class": {"TypeNominal", "TypeDecl", "TypeAlias", "TypeNameAlias"},
    "struct": {"TypeNominal", "TypeDecl", "TypeAlias", "TypeNameAlias"},
    "enum": {"TypeNominal", "TypeDecl", "TypeAlias", "TypeNameAlias"},
    "protocol": {"TypeNominal", "TypeDecl", "TypeAlias", "TypeNameAlias"},
    # A subscript is a method the digester names by its own node kind; `MutableSpan.subscript(unchecked:)`
    # is the same declaration the surface records as a method.
    "method": {"Function", "Constructor", "TypeFunc", "AccessorFunction", "Subscript",
               "OperatorDecl"},
    "property": {"Var", "AccessorSubscript"},
    "constant": {"Var", "TypeFunc", "AccessorFunction", "Macro"},
    "function": {"Function", "AccessorFunction", "OperatorDecl", "Macro"},
    # An AssociatedType is a type the declaration requires: `Publisher.Output` is one, and the
    # digester's only name for it is that node kind.
    "typealias": {"TypeAlias", "TypeNameAlias", "TypeNominal", "TypeDecl", "AssociatedType",
                  "Macro"},
}



def load_swift_modules(path):
    """What api-ledger-swift.py measured: {name: {(module, kind)}} over every module the port builds
    for armv7, plus the module names those are, and the vendored reference interfaces it recorded."""
    with open(path, encoding="utf-8") as f:
        index = json.load(f)
    names = {}
    counts = {}
    for module, declared in (index.get("modules") or {}).items():
        # Both shapes are read, and a third that is neither is refused with what it is: the cache
        # holds a versioned record and the index a flat map of names to kinds, and a reader that
        # assumes one shape while handed the other raises "unhashable type: dict" somewhere far from
        # the file that is wrong. A half-written index is exactly what a crashed run leaves behind.
        if isinstance(declared, dict) and "names" in declared and \
                isinstance(declared.get("names"), dict):
            declared = declared["names"]
        if not isinstance(declared, dict) or not all(
                isinstance(k, str) and isinstance(v, str) for k, v in declared.items()):
            raise ValueError(
                "%s: the module %r is not a map of names to kinds, and not a versioned record "
                "either -- it is %s. The index was probably written by a run that died part way "
                "through; rebuild it with api-ledger-swift.py."
                % (path, module, type(declared).__name__))
        counts[module] = len(declared)
        for name, kind in declared.items():
            names.setdefault(name, set()).add((module, kind))
    return {"names": names, "modules": set(index["modules"]), "registries": {},
            "conformances": index.get("conformances", {}),
            "references": index.get("references", {}), "digester": index.get("digester", ""),
            "target": index.get("target", ""), "sources": index.get("sources", {}),
            "search-dirs": index.get("search-dirs", []),
            "extra-module-maps": index.get("extra-module-maps", []),
            # What each module declares, and how many of a framework's rows its own module placed.
            # Both are read by classify_swift's coverage branch and by nothing else; neither was
            # filled in, so the branch compared against two empty maps and took its first answer
            # for every row -- which is the subject of the self-test beside it.
            "declaration-count": counts, "matched-by-framework": {}}


# The operators Swift synthesises from a protocol conformance, and the conformance that makes it.
# The digester prints none of these members -- there is no member, the conformance is the whole
# declaration -- so a row naming one can only be placed from the conformance, and only for the
# operator its own protocol synthesises.
SYNTHESISED_OPERATORS = {
    "==": "Equatable", "!=": "Equatable", "<": "Comparable", "<=": "Comparable",
    ">": "Comparable", ">=": "Comparable",
}


def synthesised_operator(api, swift):
    """A reason string when this row is an operator the type's own conformances synthesise, else None.

    `ActivityStyle.==(lhs:rhs:)` is the shape: the digester's dump has no `ActivityStyle.==` member
    and never will, so a matcher that only looks for members cannot place it however the name is
    spelled. The digester's dump does carry the type's conformances, and Equatable is the whole of
    the declaration, so the row is placed from that -- and from nothing weaker.
    """
    owner, member = split_qualified(api)
    if not owner or not member:
        return None
    name = member.split("(")[0]
    protocol = SYNTHESISED_OPERATORS.get(name)
    if not protocol:
        return None
    listed = swift["conformances"].get(owner, [])
    if protocol not in listed:
        return None
    return ("%s conforms to %s, so %s is synthesised for it: the digester prints no such member, "
            "and the conformance is the whole of the declaration" % (owner, protocol, member))


def classify_swift(api, row, swift, matched=None):
    """(status, reason, introduced, needs) for a Swift row, from the port's own built modules, and
    from a Swift package's own registry where there is no built module to read.

    Two evidence classes, kept apart because they are not the same claim: a name a *built armv7
    module* declares is `implemented`, and a name only a package's *registry* declares is `declared`
    -- a record of intent with no built module on this machine to check it against. It still counts
    as not missing, and `needs=build` says what is left. Objective-C rows take no registry input at
    all, which is the property the 2026-09-27 review verified and it is kept that way.

    `matched`, when given, is where a row placed `implemented` BY THE FRAMEWORK'S OWN MODULE is
    counted. Only the pass itself can say that, and the coverage branch below cannot decide without
    it, so build() classifies the Swift rows once to fill the count and once more to use it.
    """
    found = None
    for form in swift_forms(api):
        found = swift["names"].get(form)
        if found:
            break
    wanted = SWIFT_COMPATIBLE.get(row["kind"], set())
    # The registry is a Swift-only source, enforced here and not only at the call site: "no
    # Objective-C status decision reads a registry" is the property the 2026-09-27 review verified,
    # and a function that will place an Objective-C row from one the moment anything routes it
    # that way is not a property, it is a hope.
    if not found and row.get("lang") == "swift":
        synthesised = synthesised_operator(api, swift)
        if synthesised:
            return ("implemented", synthesised, None, None)
        for form in swift_forms(api):
            declared = swift["registries"].get(form)
            if declared and declared[0] == "implemented":
                return ("declared",
                        "declared implemented in %s's own registry (%s), and no built armv7 module "
                        "for it was found on this machine to check" % (declared[1], declared[2] or
                        "no reason recorded"), None, "build")
    if found:
        agreeing = sorted((module, kind) for module, kind in found if kind in wanted)
        if agreeing:
            where = sorted("%s (%s)" % (module, swift["sources"].get(module, {}).get("owner", "?"))
                           for module, kind in agreeing)
            named = sorted(set(kind for _, kind in found) - wanted)
            reason = "declared by the port's built %s module %s" % (swift["target"], ", ".join(where))
            if named:
                # The name is there and resolves; the build spells it differently from the SDK, and a
                # porter needs to know that rather than have it read as a plain match.
                reason += " (as %s, where the %s row's %s declares %s)" % (
                    named[0], row["framework"], row["kind"], "the same kind"
                    if named[0] in wanted else "another kind")
            if matched is not None and row["framework"] in swift["modules"] and \
                    any(module == row["framework"] for module, _ in agreeing):
                matched[row["framework"]] = matched.get(row["framework"], 0) + 1
            return "implemented", reason, None, None
        return ("undecided", "a module declares %s as %s and the surface row says %s: two descriptions "
                "of one name that this tool will not choose between"
                % (api, sorted(k for _, k in found)[0], row["kind"]), None, "decide")
    reference = swift["references"].get(row["framework"])
    if reference:
        return ("undecided",
                "the only %s on this machine is a vendored reference interface (%s, %s), not a module "
                "this port builds for %s: nothing here can place this row"
                % (row["framework"], reference["targets"][0] if reference["targets"] else "unknown",
                   reference["compilers"][0] if reference["compilers"] else "unknown compiler",
                   swift["target"]), None, "swift-module")
    if row["framework"] in swift["modules"]:
        # A readable module that places none of a framework's rows is evidence about coverage, not
        # about this row. CreateMLComponents is the case: the band built 614 declarations of the
        # tabular half -- BoostedTreeFitter, ColumnarTable, Impurity -- and the corpus's 2134 rows are
        # the audio and vision half, with 0 of 189 root types in the module at all. Reading those rows
        # `missing` would say the port will never have them, which nothing supports. A framework with
        # no matched row stays undecided and says which of the two it is; one with some rows matched
        # has a real gap in the rest.
        if not swift.get("matched-by-framework", {}).get(row["framework"], 0):
            declared = swift.get("declaration-count", {}).get(row["framework"], 0)
            return ("undecided",
                    "module read (%d declarations) and 0 of this framework's rows match it: "
                    "coverage, not the matcher" % declared, None, "swift-module")
        return ("missing", "not declared by the port's built %s module %s, which declares %d names "
                           "and %d of this framework's rows"
                % (swift["target"], row["framework"],
                   swift.get("declaration-count", {}).get(row["framework"], 0),
                   swift.get("matched-by-framework", {}).get(row["framework"], 0)), None, "code")
    return ("undecided", "no module this port builds for %s stands for %s, so nothing here can place "
                         "this row" % (swift["target"], row["framework"]), None, "swift-module")


def resolve_swift_coverage(results, swift, matched):
    """Re-classify the Swift rows that took the coverage branch, now that the count is filled.

    The branch asks whether the framework's own module placed ANY row of that framework, and only
    the pass itself can answer it -- so the rows are classified once to fill `matched` and once
    more to use it. Without the second pass the branch took its first answer for every row:
    `matched-by-framework` was read and never written, so the guard saw an empty map, the `missing`
    answer under it was unreachable, and 9801 rows read `undecided` with the reason "0 of this
    framework's rows match it" -- false for every framework whose module had placed thousands,
    Foundation among them. Only the rows of a framework that placed at least one are re-classified,
    and only those can reach the `missing` answer; a framework no module placed is still a coverage
    question, and 0 matched is not evidence of a gap.

    `results` is the list build() fills, and the entries are replaced in place. Returns the count.
    """
    swift["matched-by-framework"] = dict(matched)
    again = 0
    for index, (row, status, reason, introduced, needs) in enumerate(results):
        if (status != "undecided" or needs != "swift-module" or row["lang"] != "swift"
                or row["framework"] not in swift["modules"]
                or not matched.get(row["framework"])):
            continue
        results[index] = (row,) + classify_swift(row["api"], row, swift)
        again += 1
    return again


def parse_version(text):
    return tuple(int(part) for part in str(text).replace("_", ".").split("."))


def macro_target(expansion, macros, built_exports, release_exports, depth=6):
    """What a macro's replacement names, if it names one of the exported symbols: the C identifier
    it is, or the one a second macro it is written in terms of. Returns (symbol, "") or (None, why)."""
    text = expansion.strip()
    while depth > 0:
        words = re.findall(r"[A-Za-z_][A-Za-z0-9_]*", text)
        identifier = words[0] if words else ""
        if not identifier:
            return None, "its replacement is not a name"
        symbol = "_" + identifier
        if symbol in built_exports:
            return symbol, "which the built library %s exports" % built_exports[symbol]
        if symbol in release_exports:
            return symbol, "which the release's own cache exports"
        if identifier in macros:
            text = macros[identifier]
            depth -= 1
            continue
        return None, "its replacement is %r, which no built library or cache exports" % identifier
    return None, "its replacement is a chain of macros more than six deep"


def classify_macro(api, index, built_exports, release_exports):
    """A row whose name the framework's own headers `#define`."""
    expansion = index["macros"].get(api)
    if expansion is None:
        return None
    symbol, why = macro_target(expansion, index["macros"], built_exports, release_exports)
    if symbol:
        return ("implemented",
                "a macro for %s, %s: the name resolves to a value the release already has, and the "
                "availability above the declaration in the header does not gate it" % (expansion, why),
                None, None)
    return ("header-ok",
            "a macro: its value is in the header (%s), so no symbol is needed" % expansion, None, None)


def classify_from_headers(api, row, index, release="6.1.3", built_exports=None, release_exports=None):
    """api's declaration in the lifted headers. Returns (status, reason, introduced), where
    introduced is the version the lifted header still carries (None when it carries none) -- the
    lift's own work, reported next to the status rather than folded into it: an API_AVAILABLE above
    the release is a warning when the row is named, not a wall, and the plan counts these rows as
    header-only, i.e. needing no code. `index["compiled"]` is the generated unit's own verdict.
    The fourth value overrides the `needs` word when this case knows better."""
    if "error" in index:
        return "undecided", index["error"], None, None
    compiled = index.get("compiled", {})

    def named_ok(name):
        """The generated unit named it and clang reported no error on its line. The success value is
        the empty diagnostic, so membership is the test, not truth."""
        return name in compiled and not compiled[name]

    def why_not(name):
        return compiled.get(name) or "no error attributed to its line"

    bare = api[:-2] if api.endswith("()") else api
    found = index["rows"].get(api)
    if found is None:
        return ("undecided",
                "no declaration of %s at %s, though the 26.2 headers have it (the surface row is the "
                "evidence): a version-gated #if in the header hides it at this target, so lowering an "
                "availability is not enough -- the port needs its own declaration (%d headers of this "
                "framework clang rejected)"
                % (api, TARGET, len(index.get("failed", []))), None, "declare")
    kind, introduced, unavailable = found[0], found[1], found[2]
    # `API_UNAVAILABLE(ios)`: the declaration is tvOS's or visionOS's and there is no iOS API to
    # implement, so the row is not part of the denominator at all. NS_UNAVAILABLE is a different
    # fact -- the API exists and Apple marks it unavailable -- and stays a row to decide on.
    if len(found) > 3 and found[3]:
        return "not-ios", ("API_UNAVAILABLE(ios): the declaration is not an iOS API at all, so this "
                           "row leaves the denominator"), None, "none"
    # A name the headers `#define` is a header row whatever the declaration above it says: the macro
    # is what the name resolves to at compile time, and when it names an exported symbol the value is
    # already there. Decided before the availability gate, which is exactly what must not decide it.
    if built_exports is not None and row["kind"] == "constant":
        macro = classify_macro(api, index, built_exports, release_exports)
        if macro:
            return macro
    if unavailable:
        return "missing", "NS_UNAVAILABLE in the lifted headers", introduced, None
    if row["kind"] not in ("constant", "function"):
        return ("header-ok" if named_ok(bare) else "undecided",
                "%s declared in the lifted headers and the generated unit naming it compiles for %s"
                % (kind, release) if named_ok(bare) else
                "declared in the lifted headers, but the generated unit naming it does not compile: %s"
                % why_not(bare), introduced, None)
    # A constant and a function both need to know whether the declaration is a linker symbol or only
    # a header. The walk records an enum case and an extern variable both as "constant"; only a
    # top-level VarDecl/FunctionDecl is in index["flags"], and a case is not.
    flags = index["flags"].get(bare)
    if flags is None:
        if row["kind"] == "constant":
            return ("header-ok" if named_ok(bare) else "undecided",
                    "enum case in the lifted headers, no run-time symbol by construction"
                    if named_ok(bare) else
                    "enum case, but the generated unit naming it does not compile: %s"
                    % why_not(bare), introduced, None)
        return "undecided", ("%s is declared in the lifted headers but not at the top level, so its "
                             "static/inline qualifiers are unknown" % bare), introduced, None
    is_extern, is_static = flags[0], flags[1]
    if is_extern or not is_static:
        how = "extern " if is_extern else ""
        return "missing", ("declared %sin the lifted headers and there is no such symbol in the "
                           "built libraries or the %s cache -- the port has to export it"
                           % (how, release)), introduced, None
    return ("header-ok" if named_ok(bare) else "undecided",
            "static, in the header, no run-time symbol"
            if named_ok(bare) else
            "static in the header, but the generated unit naming it does not compile: %s"
            % why_not(bare), introduced, None)


# ---------------------------------------------------------------------------
# Driver
# ---------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    sub = ap.add_subparsers(dest="command", required=True)
    b = sub.add_parser("build")
    b.add_argument("--surface", required=True)
    b.add_argument("--gate", required=True,
                   help="a gate run's directory of built 6.1.3 libraries. The revision it was "
                        "built from is read from the run's own `tree` file (build-gate.lua writes "
                        "it); a directory without one is reported as `built <mtime>, tree not "
                        "recorded` rather than being attributed to this worktree's HEAD")
    b.add_argument("--release", default="6.1.3")
    b.add_argument("--release-cache", required=True)
    b.add_argument("--sdk", required=True)
    b.add_argument("--vfs", required=True)
    b.add_argument("--cache-dir", required=True)
    b.add_argument("--out", required=True)
    b.add_argument("--jobs", type=int, default=4)
    b.add_argument("--refresh", action="store_true", help="ignore the per-framework header cache")
    b.add_argument("--frameworks", default=None, help="comma-separated subset, for a fast smoke run")
    b.add_argument("--registries", default=None,
                   help="a charon checkout whose Swift packages' own registries are read, so a "
                        "Swift-module row counts from its package; defaults to the checkout beside "
                        "the surface. apple-backports' registry is skipped: it is the one this "
                        "ledger checks")
    b.add_argument("--swift-modules", default=None,
                   help="swift-modules.json from api-ledger-swift.py; without it Swift rows are "
                        "unmeasured, as they were before that pass existed")
    args = ap.parse_args()

    started = time.time()
    os.makedirs(args.cache_dir, exist_ok=True)
    os.makedirs(args.out, exist_ok=True)
    sd = load_neighbour("sd", "surface-diff-latest.py")

    rows = load_surface(args.surface)
    if args.frameworks:
        wanted = set(args.frameworks.split(","))
        rows = [r for r in rows if r["framework"] in wanted]
    note("%d rows, %d frameworks" % (len(rows), len(set(r["framework"] for r in rows))))
    swift = load_swift_modules(args.swift_modules) if args.swift_modules else None
    if swift is not None:
        read = read_package_registries(args.registries or default_checkout(args.surface))
        # A Swift registry is a Swift package's own -- createml's, RealityKit's. apple-backports' is
        # the registry this ledger exists to check, so it places no row of any kind.
        swift["registries"] = {api: (status, package, reason)
                               for api, (status, reason, package) in read.items()
                               if package != SWIFT_ONLY_PACKAGE}
        note("Swift package registries: %d entries over %s"
             % (len(swift["registries"]),
                ", ".join(sorted({package for _, _, package in swift["registries"].values()}))
                or "none"))
    if swift:
        note("Swift: %d modules, %d names, from %s" % (len(swift["modules"]), len(swift["names"]),
                                                       swift["digester"]))

    note("reading the built %s libraries from %s" % (args.release, args.gate))
    built_classes, built_protocols, built_exports = load_built_inventories(args.gate)
    note("  %d classes, %d protocols, %d exported symbols"
         % (len(built_classes), len(built_protocols), len(built_exports)))

    note("reading the release's own %s dyld cache %s" % (args.release, args.release_cache))
    release_classes, release_protocols = run_objc_inventory(args.release_cache)
    release_exports = run_dump_cache(args.release_cache)
    note("  %d classes, %d protocols, %d exported symbols"
         % (len(release_classes), len(release_protocols), len(release_exports)))

    # What the 26.2 headers declare a superclass for, per framework: the walk may not climb a release
    # chain past a class the header says has a different one, and a class NAME is not a class.
    note("reading the 26.2 headers' own @interface declarations from %s" % args.sdk)
    headers = header_superclasses(args.sdk)
    note("  %d frameworks, %d class declarations"
         % (len(headers), sum(len(v) for v in headers.values())))

    registries = read_package_registries(args.registries or default_checkout(args.surface))
    note("package registries: %d entries, of which %d record a decision"
         % (len(registries), sum(1 for v in registries.values() if v[0] in DECIDED_STATUSES)))
    # The rows a registry has decided, handed to classify_method and classify_property so that an answer
    # they infer from the release's own metadata -- `+new` is NSObject's and every class inherits it,
    # and so is any member a superclass in the chain declares -- cannot overrule a decision somebody
    # measured. decide() still runs after the classification and still stands; this only keeps the
    # classification from making the question moot.
    decided_apis = {api for api, entry in registries.items() if entry[0] in DECIDED_STATUSES}

    # Pass 1: everything the built artifacts and the release cache can place on their own.
    results = []
    diagnostics = []
    deferred = []
    matched = {}
    for row in rows:
        kind, lang, api = row["kind"], row["lang"], row["api"]
        if lang == "swift":
            if swift is None:
                results.append((row, "unmeasured",
                                "swift-only row and no Swift pass was given (--swift-modules)", None,
                                "swift-pass"))
            else:
                status, reason, introduced, needs = classify_swift(api, row, swift, matched)
                results.append((row, status, reason, introduced, needs))
        elif (kind, lang) in RUNTIME_KINDS:
            declared = headers.get(row["framework"])
            declared = Headers(row["framework"], declared) if declared else None
            if kind == "class":
                status, reason = classify_class(api, built_classes, built_protocols, release_classes, release_protocols)
            elif kind == "method":
                status, reason = classify_method(api, built_classes, release_classes,
                                                 built_protocols, release_protocols,
                                                 decided=decided_apis, unavailable=row["unavailable"],
                                                 header=declared)
            else:
                status, reason = classify_property(api, built_classes, release_classes, built_protocols,
                                            release_protocols, getter=row["getter"],
                                            decided=decided_apis, unavailable=row["unavailable"],
                                            header=declared)
            # The decide pass: a registry that records this row absent/inert/ignored has decided it,
            # with a reason, so it is not a row anybody is going to build.
            decided = decide(row, registries, diagnostics) if status == "missing" else None
            results.append((row,) + decided if decided else (row, status, reason, None, None))
        elif (kind, lang) in SYMBOL_KINDS:
            status, reason = classify_symbol(api, built_exports, release_exports)
            if status:
                results.append((row, status, reason, None, None))
            else:
                deferred.append(row)
        elif (kind, lang) in HEADER_KINDS:
            deferred.append(row)
        else:
            results.append((row, "undecided", "unhandled kind/lang %s/%s" % (kind, lang), None, None))
    for api, near in diagnostics:
        note("decide pass: %r is in no registry; the nearest keys it holds are %s"
             % (api, near or "none"))
    note("%d rows placed by the built artifacts, %d deferred to the header pass"
         % (sum(1 for r in results if r[1] != "unmeasured"), len(deferred)))

    # Pass 2: the header walk, one framework at a time, in parallel over processes.
    needed = collections.defaultdict(set)
    for row in deferred:
        needed[row["framework"]].add(row["api"].rstrip("()"))
    frameworks = sorted(needed)
    indexes = {}
    dumped = 0
    note("header pass: %d frameworks, %d names, %d jobs" % (len(frameworks), len(needed), args.jobs))

    scratch = os.path.join(args.cache_dir, "generated")
    os.makedirs(scratch, exist_ok=True)

    walked = 0

    def one(framework):
        try:
            index, cached = framework_index(sd, framework, args.sdk, args.vfs, args.cache_dir, scratch,
                                            force=args.refresh)
        except Exception as error:            # one framework must not take the run down with it
            # Recorded as that framework's own error, so every one of its rows reads `undecided` with
            # this text and the summary names it -- a failure is reported, not dropped.
            index = {"error": "the header walk failed on %s: %s: %s"
                               % (framework, type(error).__name__, error),
                     "rows": {}, "flags": {}, "compiled": {}, "failed": [], "headers": 0}
            note("  %s: %s" % (framework, error))
            return framework, index, True
        return framework, index, cached

    header_started = time.time()
    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, args.jobs)) as pool:
        for framework, index, cached in pool.map(one, frameworks):
            indexes[framework] = index
            dumped += 1
            walked += 0 if cached else 1
            if dumped % 20 == 0 or dumped == len(frameworks):
                note("  %d/%d frameworks (%d walked, %d from cache, %.0fs elapsed)"
                     % (dumped, len(frameworks), walked, dumped - walked, time.time() - started))
    header_seconds = time.time() - header_started

    for row in deferred:
        status, reason, introduced, needs = classify_from_headers(
            row["api"], row, indexes[row["framework"]], args.release, built_exports, release_exports)
        results.append((row, status, reason, introduced, needs))

    elapsed = time.time() - started

    # Pass 1b: the Swift rows the coverage branch held back, now that the pass has counted. What
    # that branch decides and why it needs two passes is resolve_swift_coverage's own account.
    if swift:
        again = resolve_swift_coverage(results, swift, matched)
        note("coverage branch: %d frameworks placed a row, %d rows re-classified as measured absent"
             % (len(matched), again))

    write_output(results, args, elapsed, indexes, walked, header_seconds, swift)


def what_this_row_needs(status, introduced, release, override=None):
    """The one word a worker needs: what has to happen for this row to work on the release. `lift`
    is the lift's own remaining work (the header still carries an availability above the release),
    which is not code and is not the port's business -- it is reported next to the status, never
    folded into it, because naming such a declaration compiles all the same."""
    if status == "unmeasured":
        return "swift-pass"
    if override == "swift-module":
        return "swift-module"
    if status == "declared":
        return override or "build"
    if override:
        return override
    if status == "undecided":
        return "decide"
    if introduced and parse_version(".".join(str(p) for p in introduced)) > parse_version(release):
        return "code+lift" if status == "missing" else "lift"
    return {"missing": "code", "header-ok": "none", "implemented": "none"}.get(status, "decide")


def write_output(results, args, elapsed, indexes, walked, header_seconds, swift=None):
    by_framework = collections.defaultdict(list)
    totals = collections.Counter()
    by_kind = collections.defaultdict(collections.Counter)
    needs_totals = collections.Counter()
    for row, status, reason, introduced, needs in results:
        by_framework[row["framework"]].append((row, status, reason, introduced, needs))
        totals[status] += 1
        by_kind[row["lang"] + "/" + row["kind"]][status] += 1
        needs_totals[what_this_row_needs(status, introduced, args.release, needs)] += 1

    order = {"missing": 0, "undecided": 1, "unmeasured": 2}
    written = 0
    for framework, entries in sorted(by_framework.items()):
        # Written even when empty, so that every framework of the surface has a checklist file and a
        # worker never has to tell "nothing left" from "no file".
        todo = [e for e in entries if e[1] != "implemented"]
        written += 1
        with open(os.path.join(args.out, framework.replace("/", "_") + ".tsv"), "w", encoding="utf-8") as f:
            f.write("kind\tlang\tapi\tintroduced\theader-introduced\tstatus\tneeds\treason\n")
            for row, status, reason, introduced, needs in sorted(
                    todo, key=lambda t: (order.get(t[1], 9), t[0]["kind"], t[0]["api"])):
                f.write("%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n"
                        % (row["kind"], row["lang"], row["api"], row["introduced"],
                           ".".join(str(p) for p in introduced) if introduced else "",
                           status,
                           what_this_row_needs(status, introduced, args.release, needs), reason))

    # A row the SDK marks API_UNAVAILABLE(ios) is tvOS's or visionOS's, not iOS's: there is no iOS
    # API in it to implement, so it leaves the denominator and is counted on its own.
    #
    # It is reported in prose here and given a column of its own in both per-row tables, which are
    # built from the *unfiltered* counters so the column carries these rows rather than a structural
    # zero. A status that is counted and shown in no column is a table whose arithmetic disagrees
    # with itself, which is the one thing a ledger may not ship, so every table below takes its
    # columns from the counters and its total from the sum of the columns it prints.
    not_ios = totals.pop("not-ios", 0)
    not_ios_by_fw = collections.Counter()
    not_ios_rows = collections.defaultdict(list)
    by_framework_all = {fw: list(entries) for fw, entries in by_framework.items()}
    for framework, entries in by_framework.items():
        by_framework[framework] = [e for e in entries if e[1] != "not-ios"]
        not_ios_by_fw[framework] = sum(1 for e in entries if e[1] == "not-ios")
        not_ios_rows[framework] = [(e[0], e[1]) for e in entries if e[1] == "not-ios"]
    measured = sum(v for k, v in totals.items() if k != "unmeasured")
    summary = os.path.join(args.out, "SUMMARY.md")
    with open(summary, "w", encoding="utf-8") as f:
        f.write("# API ledger -- measured status of the SDK 26.2 surface at iOS %s\n\n" % args.release)
        f.write("Every row of `coordination/corpus/sdk-26.2-surface.tsv` (%d rows, %d frameworks) gets a "
                "status read from built artifacts. Nothing is read from the registry: the registry is what "
                "this checks.\n\n" % (sum(totals.values()), len(by_framework)))
        f.write("Run: **%.1f minutes** end to end (%d s) over %d jobs, of which the header pass over %d "
                "frameworks took %.1f s -- %d walked from scratch, %d read from the per-framework cache. "
                "The cache is keyed by the SDK, the target and the overlay's mtime, so a run over inputs "
                "already walked costs only the two cache reads (the release's dyld cache and the built "
                "libraries, a few seconds) and a run over a new lift overlay pays the walk again.\n\n"
                % (elapsed / 60.0, round(elapsed), args.jobs, len(indexes), header_seconds, walked,
                   len(indexes) - walked))
        f.write("Three kinds of status, and they are not all measured the same way. "
                "**`implemented` and `missing` are measured from built artifacts** -- a build of main's "
                "libraries, the release's own caches, the armv7 Swift modules -- and nothing else. "
                "**`decided` is a decision somebody took and recorded**: a registry entry that says "
                "`absent`, `inert` or `ignored`, with the reason it was taken, in the row. It is kept "
                "as its own status and its own column precisely because it is not a measurement, and "
                "it is the only status in this file that rests on a registry. `header-ok` is the "
                "generated-unit test: a translation unit naming the row compiles for the release.\n\n")
        f.write("| what | where |\n| --- | --- |\n")
        f.write("| built %s libraries | `%s` |\n" % (args.release, short(args.gate)))
        tree = built_tree(args.gate)
        if tree:
            f.write("| the tree those libraries were built from | %s |\n" % tree)
        f.write("| the release's own cache | `%s` |\n" % short(args.release_cache))
        f.write("| real 26.2 SDK | `%s` |\n" % short(args.sdk.rstrip("/")).replace("$HOME/.agent-work/sdk-26.2/", ""))
        f.write("| lift overlay | `%s` (mtime %d) |\n"
                % (os.path.basename(args.vfs), int(os.path.getmtime(args.vfs))))
        f.write("| header target | `%s` |\n" % TARGET)
        f.write("| tool | `charon/tools/corpus/api-ledger.py`, header walk by "
                "`tools/corpus/surface-diff-latest.py` |\n\n")
        f.write("Reproduce (the per-framework header walk is cached under `--cache-dir`, keyed by the "
                "SDK, the target and the overlay's mtime, so the first run over new inputs is the "
                "expensive one and every run after it is cheap):\n\n```\n%s build \\\n"
                "  --surface %s \\\n  --gate %s \\\n  --release %s --release-cache %s \\\n"
                "  --sdk %s \\\n  --vfs %s \\\n  --cache-dir <dir> --out <dir> --jobs %d\n```\n\n"
                % (os.path.basename(os.path.realpath(__file__)), short(args.surface), short(args.gate),
                   args.release, short(args.release_cache), short(args.sdk), short(args.vfs), args.jobs))
        f.write("## What each status means\n\n"
                "- **implemented** -- a built apple-backports dylib of the %s gate carries it, or the "
                "release's own %s cache does: the class/method/property is in its ObjC metadata, or the "
                "linker symbol is exported. A row the release already ships counts -- it works on the release.\n"
                "- **declared** -- a Swift package's own registry records the row `implemented` and "
                "no built armv7 module for it was found on this machine to check it against. It "
                "counts as not missing, and `needs=build` is what is left: build the module and let "
                "the pass read it. Objective-C rows never read a registry, so this is the only status "
                "that rests on one.\n"
                "- **header-ok** -- header-only (a type, an enum case, a `static`/`inline` function), "
                "declared in the lifted headers with no iOS availability gating it past %s. No code is "
                "needed once the lift has lowered it.\n"
                "- **missing** -- measured as not there: no class, no selector, no symbol; or a "
                "declaration the lift still marks `API_AVAILABLE(ios(>6.1))`; or an `extern` constant or "
                "function with no symbol anywhere, which the port has to export.\n"
                "- **undecided** -- the tool cannot place the row and says why. Never a guess.\n"
                "- **unmeasured** -- Swift-only row, and no Swift pass was given.\n\n"
                % (args.release, args.release, args.release))
        f.write("## Totals\n\n| status | rows |\n| --- | --- |\n")
        for status, count in totals.most_common():
            f.write("| %s | %d |\n" % (status, count))
        f.write("| **total** | **%d** |\n\n" % sum(totals.values()))
        f.write("Every row is placed by a measurement: **%d** of %d carry a status this run decided, "
                "and the %d that do not are `undecided` with the reason in their row.\n\n"
                % (measured, sum(totals.values()), totals.get("undecided", 0)))
        f.write("**%d rows leave the denominator**: the SDK marks them `API_UNAVAILABLE(ios)`, so they "
                "are tvOS's or visionOS's declarations and there is no iOS API in them to implement. "
                "The surface keeps them (it is one file, and the %d rows of it are the whole corpus "
                "every other band works from), so they are named here rather than deleted. The "
                "denominator below is %d.\n\n"
                % (not_ios, sum(totals.values()) + not_ios, sum(totals.values())))
        if not_ios_by_fw:
            f.write("Frameworks holding them: %s.\n\n"
                    % ", ".join("%s %d" % (f, n) for f, n in sorted(not_ios_by_fw.items(),
                                                                    key=lambda kv: -kv[1])))
        f.write("## What each row needs\n\n"
                "A row is not only done or not: `needs` in the per-framework todo files says what has "
                "to happen. `lift` means the declaration is there and the generated unit that names it "
                "compiles for %s, but the lifted header still carries `API_AVAILABLE(ios(>6.1))` -- the "
                "lift band lowers it, no code is needed.\n\n| needs | rows |\n| --- | --- |\n" % args.release)
        for need, count in needs_totals.most_common():
            f.write("| %s | %d |\n" % (need, count))
        f.write("\n")
        # The per-framework counters, computed once: by_framework holds the rows, not the counts.
        # Counted from the *unfiltered* entries, so `not-ios` carries its 55 in this table as well
        # and the two tables in this file share one denominator; the header says which of the two
        # the fleet counts and why.
        per_fw = {fw: collections.Counter(st for _, st, _, _, _ in entries)
                  for fw, entries in by_framework_all.items()}
        statuses = sorted(set(totals) | {st for counters in by_kind.values() for st in counters}
                          | {st for counters in per_fw.values() for st in counters})
        f.write("## By kind\n\n| kind | %s | total |\n| --- | %s | --- |\n"
                % (" | ".join(statuses), " | ".join("---" for _ in statuses)))
        for kind in sorted(by_kind):
            t = by_kind[kind]
            f.write("| %s | %s | %d |\n"
                    % (kind, " | ".join(str(t.get(st, 0)) for st in statuses), sum(t.values())))
        f.write("\n## By framework\n\n| framework | rows | %s | todo file |\n| --- | --- | %s | --- |\n"
                % (" | ".join(statuses), " | ".join("---" for _ in statuses)))
        for framework in sorted(by_framework):
            t = per_fw[framework]
            f.write("| %s | %d | %s | `%s` |\n"
                    % (framework, sum(t.values()),
                       " | ".join(str(t.get(st, 0)) for st in statuses),
                       framework.replace("/", "_") + ".tsv"))
        empty = sorted(fw for fw, e in by_framework.items() if all(s == "implemented" for _, s, _, _, _ in e))

        unreadable = sorted(f for f, i in indexes.items() if "error" in i)
        f.write("\n## Caveats, and what this run does not measure\n\n")
        if unreadable:
            f.write("- %d frameworks the header walk could not read at all, so every row of theirs is "
                    "`undecided`: %s.\n" % (len(unreadable), ", ".join(unreadable)))
        if empty:
            f.write("- %d frameworks have no row left to do (%s); their todo file exists and is empty, "
                    "which is the whole of their status.\n" % (len(empty), ", ".join(empty)))
        partial = sorted((f, len(i["failed"])) for f, i in indexes.items() if i.get("failed"))
        if partial:
            f.write("- %d frameworks where clang rejected at least one header, so the walk fell back to one "
                    "translation unit per header; their counts are lower bounds, not complete: %s.\n"
                    % (len(partial), "; ".join("%s (%d headers)" % (f, n) for f, n in partial)))
        lifted = lifted_frameworks(args.vfs) & set(by_framework)
        f.write("- The lift's header tree holds %d of the %d frameworks walked, so for the other %d a "
                "post-%s declaration still carries its original `API_AVAILABLE`. Naming such a declaration "
                "compiles all the same, so those rows are `header-ok` with `needs=lift`, not `missing`: the "
                "lift band lowers them, no code is involved.\n"
                % (len(lifted), len(indexes), len(set(indexes) - lifted), args.release))
        f.write("- A selector name is stored by apple.objc with a leading `-` for instance *and* class "
                "methods, so a method row's `+`/`-` is not verified, only its selector name.\n")
        f.write("- The surface was built at `arm64-apple-ios26.2`; the header walk reads `%s`. A row the 26.2 "
                "headers declare but this target does not is a version-gated `#if` in the header (e.g. "
                "`OS_LOG_TARGET_HAS_10_13_FEATURES`) or a 64-bit-only declaration: lowering an availability "
                "cannot bring it back, so it is `undecided` with `needs=declare`, never counted as done.\n"
                % TARGET)
        if swift and swift["registries"]:
            by_package = collections.Counter(v[1] for v in swift["registries"].values()
                                             if v[0] == "implemented")
            f.write("- Swift rows are also placed from a Swift package's own registry, which is where a "
                    "Swift package records what it implements: %d `implemented` entries over %s. A row "
                    "no built module for is `declared` rather than `implemented`, and `needs=build`.\n"
                    % (sum(by_package.values()),
                       ", ".join("%s %d" % kv for kv in sorted(by_package.items())) or "none"))
        if swift:
            packages = {}
            for module, source in sorted(swift["sources"].items()):
                packages.setdefault((source.get("package", ""), source.get("backports", "?"),
                                     source.get("recipe", "")), []).append(module)
            for (package, backports, recipe), modules in sorted(packages.items()):
                names = ", ".join(modules[:8]) + (", ..." if len(modules) > 8 else "")
                if recipe:
                    f.write("- %d module(s) read from `%s` (`backports = %s`, recipe `%s`): %s. The "
                            "store holds more than one build of that package, so this is the one "
                            "that was measured.\n" % (len(modules), short(package), backports,
                                                       recipe, names))
                else:
                    f.write("- %d module(s) read from `%s`, a build tree with no installed-package "
                            "manifest beside it, so which build of it this is cannot be read off "
                            "the file system: %s.\n" % (len(modules), short(package), names))
            f.write("- A Swift row is `implemented` when its qualified name is declared by a module the "
                    "port builds for `%s`, read with `%s`. That is evidence the runtime *declares* the "
                    "API and that the module's own dylib stands beside it -- it is not evidence that a "
                    "body returns the right answer, which is the generated call test's job. Matching is "
                    "by exact qualified name and kind, not by signature.\n"
                    % (swift["target"], os.path.basename(swift["digester"])))
            f.write("- A Swift row of a framework no built module stands for is `undecided`, not "
                    "`missing`: nothing on this machine can place it. That is most of the Swift surface, "
                    "and it is the honest answer.\n")
        else:
            f.write("- Swift rows are `unmeasured`: no Swift pass was given (--swift-modules), so no "
                    "Swift number in this file means anything.\n")
        f.write("- The `missing` constants that are declared `extern` are the exported ones; their real "
                "values, read out of dyld shared caches of real releases, are in "
                "`coordination/corpus/ledger/exported-constants.tsv` "
                "(`tools/corpus/const-values.py` writes it and `EXPORTED-CONSTANTS.md` beside it).\n")
    # The rows that leave the denominator, written down rather than only counted: the fleet progress
    # report read this file, so both reports in this directory counted the same 145245 rows.
    if not_ios:
        with open(os.path.join(args.out, "not-ios.tsv"), "w", encoding="utf-8") as f:
            f.write("api\tframework\treason\n")
            for framework, entries in sorted(not_ios_rows.items()):
                for row, reason in entries:
                    f.write("%s\t%s\t%s\n" % (row["api"], framework, reason))
    note("wrote %s and %d per-framework todo files in %.1f minutes" % (summary, written, elapsed / 60.0))


# The overlay is JSON, and it escapes every solidus, so a path in it reads ".../headers\\/System\\/
# Library\\/Frameworks\\/ARKit.framework\\/Headers\\/ARConfiguration.h". Each separator is an
# optional backslash followed by a solidus.
LIFTED_FRAMEWORK_RE = re.compile(
    r"headers\\?/System\\?/Library\\?/(?:Private\\?/)?Frameworks\\?/([A-Za-z0-9_.]+)\.framework")


def short(path):
    """A path with the home directory written as $HOME: a tracked file carries no personal path.
    None passes through, because a report that has no --gate has to be able to say so rather than
    crash in the one function that prints its inputs."""
    if not path:
        return ""
    return path.replace(os.path.expanduser("~"), "$HOME")


def lifted_frameworks(vfs):
    """The frameworks the lift's own header tree holds, read off the overlay's external-contents
    paths: a framework the lift does not carry is read from the SDK as it ships."""
    found = set()
    with open(vfs, encoding="utf-8", errors="replace") as f:
        for match in LIFTED_FRAMEWORK_RE.finditer(f.read()):
            found.add(match.group(1))
    return found


if __name__ == "__main__":
    main()
