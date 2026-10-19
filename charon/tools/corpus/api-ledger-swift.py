#!/usr/bin/env python3
"""
The Swift side of the API ledger: what the port's own built armv7 Swift modules actually declare.

Every Swift row of coordination/corpus/sdk-26.2-surface.tsv is left `unmeasured` by api-ledger.py
because no Swift pass existed. This is that pass, and it is one measurement: a module the port
builds for armv7 is read with `swift-api-digester -dump-sdk` (the toolchain's own API digester, run
against the built binary .swiftmodule) and every declaration it reports is indexed by its
`printedName` -- the same printed form the surface's rows were built from, so a row is placed by an
exact name comparison and nothing is matched by guessing.

What the evidence is, precisely, because it is weaker than the Objective-C side and the ledger must
not overstate it: a name in a built module proves the port's armv7 runtime *declares* it, and the
module's own dylib sitting beside it is what carries the code. It does not prove a function body
returns the right answer -- that is the generated call test's job, not this tool's. A name absent
from a module the port builds is measured `missing`; a row whose framework no built module stands
for is `undecided`, because nothing on this machine can place it.

A vendored reference interface is not a build and is not measured as one: Eidolon's
`bridge/fw/SwiftUI.framework` holds Apple's own 16.4 arm64 `.swiftinterface` (its own header says
`-target arm64-apple-ios16.4`, "Apple Swift version 5.8"), so it describes the API's shape and
nothing about what this port has. Pass it in and it is read as a reference, reported as such, and
contributes no `implemented` row.

Usage:
  python3 api-ledger-swift.py --out <dir> --sdk <iPhoneOS SDK> --vfs <lift vfs.yaml> \\
      --module-dirs "swift-runtime=/path/to/lib/swift/iphoneos,styx=/path/to/Combine's dir" \\
      [--digester <path>] [--shims-modulemap <path>] [--cache-dir <dir>]
"""
import argparse
import collections
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import time

def note(message):
    print(message, file=sys.stderr, flush=True)


def find_digester():
    """The toolchain's own swift-api-digester, newest in the shared store. Recorded in the output,
    because which compiler read the module is part of what was measured."""
    root = os.path.expanduser("~/.xmake/packages/s/swift")
    found = []
    for base, _, files in os.walk(root):
        if "swift-api-digester" in files:
            path = os.path.join(base, "swift-api-digester")
            found.append((os.path.getmtime(path), path))
    if not found:
        sys.exit("api-ledger-swift.py: no swift-api-digester under %s; pass --digester" % root)
    return max(found)[1]


def package_of(module_file):
    """The installed package a module came from, and the two facts that say which build of it this
    is: xmake writes a manifest.txt beside an install recording the configs it was built with and the
    digest of the recipe that built it. A store can hold several builds of the same package -- two of
    the swift-runtime copies on this machine carry 17 armv7 modules each and are different builds --
    so a measurement that does not name the one it read is not reproducible."""
    # Walk up to the install root: xmake writes manifest.txt there, and the module file sits four
    # directories below it (M.swiftmodule/armv7-apple-ios.swiftmodule under lib/swift/iphoneos).
    directory = os.path.dirname(module_file)
    manifest = ""
    for _ in range(6):
        candidate = os.path.join(directory, "manifest.txt")
        if os.path.exists(candidate):
            manifest = candidate
            break
        parent = os.path.dirname(directory)
        if parent == directory:
            break
        directory = parent
    found = {"package": directory, "manifest": manifest}
    if not manifest:
        return found
    with open(manifest, encoding="utf-8", errors="replace") as f:
        text = f.read()
    found["manifest"] = manifest
    for key in ("backports", "backports_uikit", "shared", "recipe"):
        match = re.search(r"\b" + key + r' = "?([^"\n,}]+)', text)
        if match:
            found[key] = match.group(1)
    return found


# A node that is a type: its printed name qualifies the names of everything inside it.
TYPE_KINDS = {"TypeNominal", "TypeDecl", "TypeAlias", "TypeNameAlias"}
# One argument group, to be reduced to its arity: `(_:_:)`.
ARGS_RE = re.compile(r"\(([^()]*)\)")
# `X.() -> Swift.Bool`: a payload case, whose own name the digester prints as the type of a
# function it synthesises. Measured on the digester's own output.
PAYLOAD_CASE = re.compile(r"\.\(\s*\)?[^ ]* -> .*$")
# The two nodes that carry no API of their own: the module's root and its imports.
IGNORED_KINDS = {"Import", "Root"}


def index_from_json(payload, conformances=None):
    """Three things out of one digester dump, because one walk can see all three:

    names         {name: kind} for everything the module declares, keyed the way the surface's rows
                  name things. A member's own printedName is unqualified -- the digester prints
                  `hash(into:)`, not `Calendar.Identifier.hash(into:)` -- so a name is qualified by
                  the types it is declared in, and a type is indexed bare as well as qualified,
                  because a surface row names a type both ways.
    conformances  {type: [protocol names]}, which is the only evidence there is for an operator the
                  digester never prints: Swift synthesises `==` from Equatable, and there is no
                  member in the dump to find, because the conformance *is* the declaration.
    Nothing       the third return is None and always was; it is here so a caller can tell an
                  unsuccessful read from an empty module without catching.
    """
    names, conformances = {}, {} if conformances is None else conformances
    stack = [(payload.get("ABIRoot", {}), ())]
    while stack:
        node, path = stack.pop()
        kind = node.get("kind")
        own = node.get("printedName") or node.get("name")
        if kind in IGNORED_KINDS or not own:
            for child in node.get("children", []):
                stack.append((child, path))
            continue
        here = path + ((kind, own),)
        qualified = ".".join(name for _, name in here)
        # A payload case: the digester prints `X.() -> Swift.Bool` for a case with an associated
        # value, so the case's own name is nowhere in the tree and the row cannot be placed.
        payload = PAYLOAD_CASE.sub("", qualified)
        if kind in TYPE_KINDS:
            names.setdefault(own, kind)
            names.setdefault(qualified, kind)
            if payload != qualified:
                names.setdefault(payload, kind)
            listed = [c.get("printedName") or c.get("name") for c in node.get("conformances") or []]
            for name in (own, qualified, payload):
                if listed:
                    conformances.setdefault(name, []).extend(listed)
        else:
            names.setdefault(qualified, kind)
            # The same member under the other convention. The digester prints a method's labels
            # (`timeInterval(since:)`) and the corpus's row carries the parameter names
            # (`Date.timeInterval(since:date:)`), so neither spelling is a subset of the other and
            # a matcher that only tries one convention misses rows whose name is otherwise exact.
            # Reducing both sides to the labels-as-written-or-underscore form is what makes the two
            # comparable, and it is why the index carries both.
            reduced = ARGS_RE.sub(lambda m: "(" + ":".join(["_"] * len(m.group(1).split(":")[:-1]))
                                                + (":" if m.group(1).endswith(":") else "") + ")",
                                  qualified)
            if reduced != qualified:
                names.setdefault(reduced, kind)
        inside = here if kind in TYPE_KINDS else path
        for child in node.get("children", []):
            stack.append((child, inside))
    return names, conformances, None


def _names_for(here):
    """The names one node answers to: a type bare and qualified, a member qualified by its types."""
    kind, own = here[-1]
    path = [name for _, name in here[:-1]]
    qualified = ".".join(path + [own])
    if kind in TYPE_KINDS:
        return (own, qualified)
    return (qualified,)


def read_module(digester, module_dir, module, sdk, vfs, shims, workdir, search=(), extra_maps=(),
                include_dirs=()):
    """One module's name index, written to workdir as the digester's own JSON, read back from there.
    Returns (names, conformances, error) -- three values on every path, error or not. It returned
    two on the two failure paths below while the caller unpacked three, so a digester that exited
    non-zero, or wrote JSON this could not parse, raised ValueError out of the run: the tool that
    exists to report a module it could not read was the thing that fell over, and wrote no index,
    so the module was absent from the output rather than named in `failures`."""
    handle, out_path = tempfile.mkstemp(suffix="-%s.json" % re.sub(r"\W", "_", module), dir=workdir)
    os.close(handle)
    try:
        args = [digester, "-dump-sdk", "-module", module, "-I", module_dir]
        # A module that is not the runtime's own -- Styx's Combine, say -- has to find the standard
        # library it was built against, so every module directory on the machine is on its path.
        for extra in search:
            args += ["-I", extra]
        args += ["-target", "armv7-apple-ios6.1.3", "-sdk", sdk, "-Xcc", "-Wno-incompatible-sysroot"]
        for module_map in ([shims] if shims else []) + list(extra_maps):
            args += ["-Xcc", "-fmodule-map-file=%s" % module_map]
        for directory in include_dirs:
            args += ["-Xcc", "-I%s" % directory]
        args += ["-Xcc", "-ivfsoverlay", "-Xcc", vfs, "-o", out_path]
        # stderr is merged into stdout, not captured separately: the importer's "missing required
        # modules" line is the only thing that says why a module did not load, and with
        # `capture_output` it reached neither stream.
        out = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                             errors="replace", timeout=1800)
        if out.returncode != 0:
            # out.stdout, not out.stderr: stderr was merged into stdout three lines above, so
            # out.stderr is None and reading it raised AttributeError out of this function -- the
            # one failure this whole reader exists to report took the run down with a traceback and
            # wrote no index at all, which is how a module that would not load became invisible
            # instead of a line in `failures`.
            return None, None, "swift-api-digester failed (%d): %s" % (
                out.returncode, (out.stdout or "").strip()[-300:])
        with open(out_path, encoding="utf-8") as f:
            payload = json.load(f)
    except (ValueError, OSError) as error:
        return None, None, ("the digester's output for %s could not be read: %s" % (module, error))
    finally:
        os.unlink(out_path)
    return read_declarations(payload, module)


# The cache holds one typed record with named fields and a version, because a bare
# `{name: kind}` and a two-element list are both valid JSON and a reader that guesses which it has
# will one day read one as the other -- which it did, and printed a conformances dict as a
# declaration count. A record without this version is refused, not guessed at.
CACHE_RECORD_VERSION = 2
# A digest of this file, so an entry written by an older reader is never read by a newer one.
TOOL_DIGEST = hashlib.sha256(open(os.path.realpath(__file__), "rb").read()).hexdigest()[:8]



def read_cache_record(data):
    """(names, conformances) from a cache record, or None when the record is not one of ours."""
    if not isinstance(data, dict) or data.get("version") != CACHE_RECORD_VERSION:
        return None
    if not isinstance(data.get("names"), dict):
        return None
    return data["names"], data.get("conformances") or {}


def write_cache_record(path, names, conformances):
    with open(path, "w", encoding="utf-8") as f:
        json.dump({"version": CACHE_RECORD_VERSION, "names": names,
                   "conformances": {k: sorted(set(v)) for k, v in conformances.items()}}, f)


def digester_complaint(*streams):
    """The digester's own line about what it could not load, or nothing.

    `swift-api-digester` exits 0 on a module it could not load, writes an empty tree, and prints the
    line naming the missing module from the clang importer -- on **stdout**, not stderr, which is
    itself worth knowing. Both streams are read. Discarding that line is what turned a four-second
    diagnosis into four probes, so it is carried into the refusal rather than thrown away.
    """
    for stream in streams:
        if not stream:
            continue
        for line in str(stream).splitlines():
            if "error:" in line or "missing required modules" in line:
                return line.strip()[:300]
    return ""


def read_declarations(payload, module, *streams):
    """(names, conformances, error) for one digester dump.

    A module that reports no declaration is a read that did not happen, and it is the most
    consequential thing this tool can get wrong: the digester exits 0 and writes an empty tree when
    it cannot load a module or one of its dependencies, so an empty tree indexed as "this module
    declares nothing" turns every row of that module into `missing` that are not missing at all. It
    has bitten three times -- Styx's Combine (1222 rows), FoundationEssentials and
    FoundationInternationalization -- and each time the only symptom was a number that looked
    plausible.
    """
    names, conformances, _ = index_from_json(payload)
    if not names:
        complaint = digester_complaint(*streams)
        return None, None, ("the digester reported no declaration of %s, which is a module it could "
                            "not load, not an empty one%s"
                            % (module, ": the digester said %s" % complaint if complaint else ""))
    return names, conformances, None


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    ap.add_argument("--out", required=True)
    ap.add_argument("--sdk", required=True)
    ap.add_argument("--vfs", required=True)
    ap.add_argument("--module-dirs", required=True,
                    help="comma-separated <owner>=<dir of *.swiftmodule directories>")
    ap.add_argument("--digester", default=None)
    ap.add_argument("--shims-modulemap", default=None)
    ap.add_argument("--cache-dir", default=None)
    ap.add_argument("--search-dirs", default="",
                    help="comma-separated module directories every digester run may also read")
    ap.add_argument("--include-dirs-for", default="",
                    help="comma-separated <owner>=<dir>[,<dir>]: directories to put on the "
                         "clang include path when that owner's module is read. A module map names "
                         "its headers, and clang resolves those on the include path, so the map "
                         "alone leaves the module unloadable: swift-foundation's _FoundationCShims "
                         "and _FoundationICU maps sit beside their headers and still need -I")
    ap.add_argument("--module-maps-for", default="",
                    help="comma-separated <owner>=<map>[,<map>]: module maps that belong to one "
                         "owner's modules and not to every run. A map given here is passed only "
                         "when that owner's module is read, because a module map is global to a "
                         "digester run and one package's C shims make every other module unloadable")
    ap.add_argument("--extra-module-maps", default="",
                    help="comma-separated module.modulemap files every digester run must also see: "
                         "a module's own C shims, which without it the digester cannot load the module")
    ap.add_argument("--reference-dirs", default="",
                    help="comma-separated <name>=<dir of .swiftmodule dirs holding text interfaces>: "
                         "recorded as what they measurably are, and measured as nothing")
    args = ap.parse_args()
    started = time.time()

    digester = args.digester or find_digester()
    os.makedirs(args.out, exist_ok=True)
    cache_dir = args.cache_dir or os.path.join(args.out, "swift-module-cache")
    os.makedirs(cache_dir, exist_ok=True)
    workdir = os.path.join(cache_dir, "digests")
    os.makedirs(workdir, exist_ok=True)
    note("digester: %s" % digester)

    search = [os.path.realpath(d) for d in args.search_dirs.split(",") if d.strip()]
    extra_maps = [os.path.realpath(p) for p in args.extra_module_maps.split(",") if p.strip()]
    owner_maps, owner_includes = {}, {}
    for pair in args.module_maps_for.split(","):
        if "=" in pair:
            owner, _, maps = pair.partition("=")
            owner_maps[owner] = [os.path.realpath(p) for p in maps.split(",") if p.strip()]
    for pair in args.include_dirs_for.split(","):
        if "=" in pair:
            owner, _, dirs = pair.partition("=")
            owner_includes[owner] = [os.path.realpath(p) for p in dirs.split(",") if p.strip()]
    for path in extra_maps:
        if not os.path.exists(path):
            note("module map %s does not exist, passed on anyway so the failure is the digester's "
                 "and says why" % path)
    modules, sources, failures, all_conformances = {}, {}, [], {}
    for pair in args.module_dirs.split(","):
        if "=" not in pair:
            sys.exit("api-ledger-swift.py: --module-dirs wants <owner>=<dir>, got %r" % pair)
        owner, _, directory = pair.partition("=")
        directory = os.path.realpath(directory)
        if not os.path.isdir(directory):
            note("%s: %s is not a directory, skipped" % (owner, directory))
            continue
        shims = args.shims_modulemap or os.path.join(os.path.dirname(directory), "shims",
                                                     "module.modulemap")
        if not os.path.exists(shims):
            shims = None
        for entry in sorted(os.listdir(directory)):
            if not entry.endswith(".swiftmodule"):
                continue
            module = entry[:-len(".swiftmodule")]
            binary = os.path.join(directory, entry, "armv7-apple-ios.swiftmodule")
            if not os.path.exists(binary):
                note("  %s/%s: no armv7-apple-ios.swiftmodule, not this port's target" % (owner, module))
                continue
            # Keyed over everything the content depends on, *this file's contents* included, not
            # its path: the reader's shapes changed twice today and a path-keyed cache kept serving
            # entries written by the older reader -- one of them a versioned record nested inside the
            # record, which is valid JSON with a valid version and so was accepted.
            # Keyed over everything the content depends on, this file's *contents* included and
            # not its path: the reader's shapes changed twice today and a path-keyed cache kept
            # serving entries written by the older reader -- one of them a versioned record nested
            # inside the record, which is valid JSON with a valid version and so was accepted.
            key = hashlib.sha256("".join([
                binary, str(int(os.path.getmtime(binary))), str(os.path.getsize(binary)),
                digester, str(int(os.path.getmtime(digester))), shims or "", args.vfs,
                " ".join(search), " ".join(extra_maps), " ".join(owner_maps.get(owner, [])),
                " ".join(owner_includes.get(owner, [])), TOOL_DIGEST,
            ]).encode()).hexdigest()[:16]
            cache_file = os.path.join(cache_dir, "%s-%s-%s.json" % (owner, module, key))
            cached = None
            if os.path.exists(cache_file):
                try:
                    with open(cache_file, encoding="utf-8") as f:
                        cached = read_cache_record(json.load(f))
                except ValueError:
                    cached = None      # a file that is not JSON is a cache entry, not an answer
                if cached is None:
                    note("  %s/%s: the cache entry is not a record this reader wrote, read again"
                         % (owner, module))
            if cached is not None:
                # read_cache_record, not json.load: what is stored is a versioned record, and
                # handing the whole record on as the name index left `modules` holding
                # {"version":.., "names":{..}} where every other reader expects {name: kind} --
                # tolerated downstream, so nothing failed, and no conformances at all. A hit
                # therefore placed every synthesised operator (X.==, X.<, from a conformance and
                # from nothing else) as absent, and the index a warm run wrote was not the index
                # the cold run before it wrote. dylib_there went missing the same way.
                names, conformances = cached
                modules[module] = names
                all_conformances.update(conformances)
                dylib = os.path.join(directory, "libswift%s.dylib" % module)
                sources[module] = dict(package_of(binary), owner=owner, module=binary, dylib=dylib,
                                       dylib_there=os.path.exists(dylib))
                note("  %s/%s: %d declarations (from cache)" % (owner, module, len(names)))
                continue
            names, conformances, error = read_module(digester, directory, module, args.sdk, args.vfs,
                                                    shims, workdir, search,
                                                    extra_maps + owner_maps.get(owner, []),
                                                    owner_includes.get(owner, []))
            if error:
                failures.append("%s/%s: %s" % (owner, module, error))
                note("  %s/%s: %s" % (owner, module, error))
                continue
            write_cache_record(cache_file, names, conformances)
            modules[module] = names
            all_conformances.update(conformances)
            dylib = os.path.join(directory, "libswift%s.dylib" % module)
            sources[module] = dict(package_of(binary), owner=owner, module=binary, dylib=dylib,
                                  dylib_there=os.path.exists(dylib))
            note("  %s/%s: %d declarations" % (owner, module, len(names)))

    # A vendored reference interface: not a build, and not measured as one. What it *is* is read off
    # its own first lines, which name the target and the compiler that wrote it.
    references = {}
    for pair in args.reference_dirs.split(","):
        if not pair.strip():
            continue
        if "=" not in pair:
            sys.exit("api-ledger-swift.py: --reference-dirs wants <name>=<dir>, got %r" % pair)
        name, _, directory = pair.partition("=")
        directory = os.path.realpath(directory)
        found = []
        if os.path.isdir(directory):
            for base, _, files in os.walk(directory):
                for entry in sorted(files):
                    if entry.endswith(".swiftinterface"):
                        found.append(os.path.join(base, entry))
        elif os.path.isfile(directory):
            found = [directory]
        targets, compilers = set(), set()
        for path in found:
            with open(path, encoding="utf-8", errors="replace") as f:
                for _ in range(12):
                    line = f.readline()
                    if not line:
                        break
                    if line.startswith("// swift-module-flags:"):
                        # "// swift-module-flags: -target arm64-apple-ios16.4 -enable-objc-interop ..."
                        flags = line.split()
                        for index, flag in enumerate(flags):
                            if flag == "-target" and index + 1 < len(flags):
                                targets.add(flags[index + 1])
                            elif flag.startswith("-target="):
                                targets.add(flag.split("=", 1)[1])
                    elif line.startswith("// swift-compiler-version:"):
                        compilers.add(line.split(":", 1)[1].strip())
        references[name] = {"path": directory, "files": sorted(found), "built": False,
                            "targets": sorted(targets), "compilers": sorted(compilers)}
        note("  reference %s: %d text interfaces, target %s, %s -- recorded, not measured"
             % (name, len(found), ", ".join(sorted(targets)) or "unknown",
                ", ".join(sorted(compilers)) or "unknown compiler"))

    index = {"digester": digester, "target": "armv7-apple-ios6.1.3", "sdk": args.sdk, "vfs": args.vfs,
             "search-dirs": search, "extra-module-maps": extra_maps,
             "module-maps-for": owner_maps, "include-dirs-for": owner_includes, "modules": modules,
             "conformances": {k: sorted(set(v)) for k, v in all_conformances.items()},
             "sources": sources, "failures": failures,
             "references": references}
    path = os.path.join(args.out, "swift-modules.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(index, f, indent=1, sort_keys=True)
    total = sum(len(v) for v in modules.values())
    note("wrote %s: %d modules, %d distinct names, %.1f minutes"
         % (path, len(modules), total, (time.time() - started) / 60.0))


if __name__ == "__main__":
    main()
