#!/usr/bin/env python3
"""Everything an iPhoneOS SDK declares that arrived after iOS 6.1, in one table, and what the
SDK dropped since 16.4. Two subcommands, run from anywhere (data is under CHARON_CORPUS_ROOT):

    sdk-surface.py impl-index              fetch the file lists of the reference implementations
                                           (`gh api .../git/trees/<branch>?recursive=1`, names only,
                                           nothing cloned) into corpus/impl-source-trees/
    sdk-surface.py build [--new F] [--old F] [--registry F] [--demand F]

`build` reads the two walks sdk-introduced.py --sdk wrote (default corpus/sdk-26.2-declared.json and
sdk-16.4-declared.json, the newest and the oldest by version if not named), the newest
carried-registry-*.tsv and crash-demand-top.tsv, and writes, named after the new SDK's version:

    sdk-<v>-surface.tsv                    what arrived after 6.1: name, framework, kind, language,
                                           availability, charon registry status, demand, impl-lead
    sdk-<v>-removed-since-<old>.tsv        what the old SDK declared and the new one does not, or
                                           declares unavailable or obsoleted (the removed API); a Swift
                                           name that came back under other labels is `changed`, not removed
    sdk-<v>-surface.md                     the counts

Columns of the surface table:

    registry        the charon registry's own row for this API: carried (implemented), absent, inert,
                    ignored; none where the registry has no row (which is not the same as absent)
    owner-registry  for a member with no row of its own: the status of the class or protocol it belongs to
    demand-*        the demand corpus row (crash-demand-top.tsv): its rank and severity, how many of the
                    corpus apps call it, and whether Telegram is one of them
    via             where `introduced` came from: `own` (the declaration's own @available), `container` (the
                    class, protocol, category or enum it sits in) or `class-floor` (the class a category
                    with no annotation extends). The last two are a FLOOR: the member arrived in that
                    version or later, not necessarily in it (`MTLGPUFamilyApple8` says 13.0 through its
                    enum and came with iOS 16). Rows with no version at all are not in the table.
    getter          the accessor a property's header declared, when it is not the property's own name
                    (`@property (readonly, getter=isSupported)` -> `isSupported`); empty for every row
                    the header declared nothing different for, and for every row that is not a property.
                    A property is read through its accessors, so this is what says `supported` is read
                    through `-isSupported` and not through `-supported`.
    impl-lead       a lead to where an implementation might be read, by file name: swift-foundation,
                    swift-corelibs-foundation, apple-oss (CF, objc4, libdispatch), OpenCombine, OpenSwiftUI,
                    WinObjC; empty where none of those has a file of that name. impl-file-lead names the file.

`impl-lead` is a lead by file name, not a proof and not a fact of implementation: a repository has a file named after the type
(Calendar.swift, CFArray.c, UIView.mm) in the frameworks that repository stands for. For a member it
is the file of the type it belongs to; whether that file implements this member is for whoever reads
it. Functions and constants are matched to the longest file name their own name starts with
(CFArrayCreate -> CFArray.c).

What the surface leaves out, because neither clang nor a swiftinterface shows it: macros (#define
constants), typedefs and struct fields, conformances (`extension X: P`), SPI, private headers. The
C libraries under usr/include are in it, one library per directory (`include/os`, `include/dispatch`,
`include/xpc`, `include/mach`, ..., and `include` for the loose top-level headers), except the C++
standard library. Every row the walk drops or cannot read is counted and named at the end of the `.md`.
"""
import argparse
import collections
import csv
import glob
import json
import os
import re
import subprocess
import sys

CORPUS_ROOT = os.environ.get("CHARON_CORPUS_ROOT") or os.path.join(
    os.path.expanduser("~"), "Git", "projects", "ios", "coordination")
CORPUS = os.path.join(CORPUS_ROOT, "corpus")
TREES = os.path.join(CORPUS, "impl-source-trees")
if not os.path.isdir(CORPUS):
    sys.exit("sdk-surface.py: no corpus/ data directory found at %s. Set CHARON_CORPUS_ROOT to "
              "the directory that contains corpus/." % CORPUS)

AFTER = (6, 1)
DEPRECATED_NO_VERSION = "yes"

# name shown in impl-lead, GitHub repository, branch, frameworks it stands for (None: every
# framework it has a directory for), where its sources sit, and the aliases a name may also go by.
REPOS = [
    {"source": "swift-foundation", "repo": "swiftlang/swift-foundation", "branch": "main",
     "frameworks": {"Foundation"}, "under": "Sources/"},
    {"source": "swift-corelibs-foundation", "repo": "swiftlang/swift-corelibs-foundation", "branch": "main",
     "frameworks": {"Foundation"}, "under": "Sources/", "strip": "NS"},
    {"source": "apple-oss", "repo": "apple-oss-distributions/CF", "branch": "main",
     "frameworks": {"CoreFoundation"}, "under": "", "prefix": True},
    {"source": "apple-oss", "repo": "apple-oss-distributions/objc4", "branch": "main",
     "frameworks": {"ObjectiveC"}, "under": "runtime/"},
    {"source": "apple-oss", "repo": "apple-oss-distributions/libdispatch", "branch": "main",
     "frameworks": {"Dispatch"}, "under": "src/swift/", "strip": "Dispatch"},
    {"source": "OpenCombine", "repo": "OpenCombine/OpenCombine", "branch": "master",
     "frameworks": {"Combine"}, "under": "Sources/"},
    {"source": "OpenSwiftUI", "repo": "OpenSwiftUIProject/OpenSwiftUI", "branch": "main",
     "frameworks": {"SwiftUI", "SwiftUICore"}, "under": "Sources/"},
    {"source": "WinObjC", "repo": "microsoft/WinObjC", "branch": "develop",
     "frameworks": None, "under": "Frameworks/", "prefix": True, "directory": True},
]
SOURCE_SUFFIX = (".swift", ".c", ".m", ".mm", ".cpp", ".cc", ".h", ".hpp")
SKIPPED_DIRS = ("Tests/", "Test/", "Example", "Benchmarks/", ".github/", "docs/", "Docs/", "tests/", "samples/", "Samples/")


def parse_version(text):
    return tuple(int(part) for part in text.split("."))


def repo_file(repo):
    return os.path.join(TREES, repo.replace("/", "_") + ".json")


def fetch_index():
    os.makedirs(TREES, exist_ok=True)
    for entry in REPOS:
        out = subprocess.run(["gh", "api", "repos/%s/git/trees/%s?recursive=1" % (entry["repo"], entry["branch"])],
                             capture_output=True, text=True)
        if out.returncode != 0:
            sys.exit("gh api failed for %s: %s" % (entry["repo"], out.stderr[:300]))
        tree = json.loads(out.stdout)
        if tree["truncated"]:
            sys.exit("%s: the tree is truncated by GitHub, the file list is incomplete" % entry["repo"])
        files = [t["path"] for t in tree["tree"] if t["type"] == "blob"]
        with open(repo_file(entry["repo"]), "w") as stream:
            json.dump({"repo": entry["repo"], "branch": entry["branch"], "sha": tree["sha"], "files": files}, stream)
        print("%s@%s: %d files" % (entry["repo"], tree["sha"][:10], len(files)))


class Impl:
    """File-name index of the reference implementations."""

    def __init__(self):
        self.repos = []
        for entry in REPOS:
            path = repo_file(entry["repo"])
            if not os.path.isfile(path):
                sys.exit("no file list for %s at %s: run `sdk-surface.py impl-index` first" % (entry["repo"], path))
            tree = json.load(open(path))
            stems = {}
            directories = set()
            for name in tree["files"]:
                if not name.startswith(entry["under"]) or not name.endswith(SOURCE_SUFFIX):
                    continue
                if any("/" + skipped in "/" + name for skipped in SKIPPED_DIRS):
                    continue
                parts = name.split("/")
                # WinObjC keeps a framework's files in Frameworks/<Framework>/: a name is looked up there only
                directory = parts[1].lower() if entry.get("directory") and len(parts) > 2 else None
                if entry.get("directory") and directory is None:
                    continue
                if directory:
                    directories.add(directory)
                stem = parts[-1].rsplit(".", 1)[0]
                self.remember(stems, (directory, stem), name)
                if "+" in stem:
                    self.remember(stems, (directory, stem.split("+")[0]), name)
            self.repos.append({**entry, "stems": stems, "directories": directories, "sha": tree["sha"]})

    @staticmethod
    def remember(stems, key, name):
        # the shortest path is the one nearest the root; a plain type file beats a category file
        if key not in stems or len(name) < len(stems[key]):
            stems[key] = name

    @staticmethod
    def applies(entry, framework):
        if entry["frameworks"] is not None:
            return framework in entry["frameworks"]
        return framework.lower() in entry["directories"]

    @staticmethod
    def candidates(entry, name, loose):
        """Names to look for among one repository's file stems: the name itself, its alias without
        the prefix the repository's `strip` names, and for a function or constant (`loose`) every
        prefix of it that ends where a capital letter or an underscore begins, longest first."""
        base = name.split("(")[0]
        found = [base]
        strip = entry.get("strip")
        if strip and base.startswith(strip) and len(base) > len(strip):
            found.append(base[len(strip):])
        if entry.get("prefix") and loose:
            root = base[1:] if re.match(r"k[A-Z]", base) else base
            cuts = [i for i in range(len(root) - 1, 3, -1) if root[i].isupper() or root[i] == "_"]
            found += [root[:i].rstrip("_") for i in cuts]
        return found

    def lookup(self, framework, kind, api, owner_names):
        """[(source, "repo:path")] for one row: by its own name when it is a type, function or
        constant, by the type it belongs to when it is a member."""
        member = bool(owner_names) and kind in ("method", "property", "constant")
        names = owner_names if member else [api]
        loose = kind in ("function", "constant") and not member
        hits = []
        seen = set()
        for entry in self.repos:
            if not self.applies(entry, framework):
                continue
            directory = framework.lower() if entry.get("directory") else None
            path = next((entry["stems"][(directory, candidate)] for name in names
                         for candidate in self.candidates(entry, name, loose) if (directory, candidate) in entry["stems"]), None)
            if path is not None and (entry["source"], entry["repo"]) not in seen:
                seen.add((entry["source"], entry["repo"]))
                hits.append((entry["source"], "%s:%s" % (entry["repo"], path)))
        return hits


def owners(kind, lang, api):
    """The type names a member belongs to, nearest first: `UIView` for `-[UIView foo:]` and for
    `UIView.bar`; for a Swift `Publishers.Map.foo(x:)` `Publishers.Map`, then `Publishers`."""
    found = re.match(r"^[-+]\[(\w+) ", api)
    if found:
        return [found.group(1)]
    if kind not in ("method", "property", "constant"):
        return []
    base = api.split("(")[0]
    if "." not in base:
        return []
    parts = base.split(".")[:-1]
    if lang == "objc":
        return parts[:1]
    return [".".join(parts[:n]) for n in range(len(parts), 0, -1)]


def newest(pattern):
    found = glob.glob(os.path.join(CORPUS, pattern))
    if not found:
        sys.exit("no %s in %s" % (pattern, CORPUS))
    return max(found, key=os.path.getmtime)


def walks(new, old):
    def version(path):
        found = re.search(r"sdk-(\d+(?:\.\d+)*)-declared\.json$", path)
        return parse_version(found.group(1)) if found else (0,)
    files = glob.glob(os.path.join(CORPUS, "sdk-*-declared.json"))
    if not files:
        sys.exit("no sdk-<version>-declared.json in %s: run sdk-introduced.py --sdk <iPhoneOS SDK> first" % CORPUS)
    new = new or max(files, key=version)
    old = old or min(files, key=version)
    return new, old


def load_registry(path):
    rows = {}
    order = {"implemented": 0, "inert": 1, "ignored": 2, "absent": 3}
    with open(path) as stream:
        for row in csv.DictReader(stream, delimiter="\t", quoting=csv.QUOTE_NONE):
            status = row["status"]
            have = rows.get(row["api"])
            if have is None or order.get(status, 9) < order.get(have, 9):
                rows[row["api"]] = status
    return rows


def registry_status(registry, kind, api):
    """The registry's row for api. The registry names a member in more than one way: `-[C sel]`,
    `C.sel`, and for a property `C.name` or its accessors `-[C name]` and `-[C setName:]`."""
    status = registry.get(api)
    if status is not None:
        return status
    found = re.match(r"^[-+]\[(\w+) (.+)\]$", api)
    if found:
        return registry.get("%s.%s" % found.groups())
    if kind == "property" and "." in api:
        owner, name = api.split(".", 1)
        for candidate in ("-[%s %s]" % (owner, name), "-[%s set%s%s:]" % (owner, name[:1].upper(), name[1:])):
            if candidate in registry:
                return registry[candidate]
    return None


def show_registry(status):
    return {"implemented": "carried"}.get(status, status) if status else "none"


def load_demand(path):
    rows = {}
    with open(path) as stream:
        for row in csv.DictReader(stream, delimiter="\t", quoting=csv.QUOTE_NONE):
            rows.setdefault(row["api"], row)
    return rows


def demand_for(demand, kind, api):
    """The demand row of api. A linker symbol in the demand file carries its underscore, a
    function its `()` here."""
    row = demand.get(api)
    if row is None and kind in ("constant", "function"):
        row = demand.get("_" + api.split("(")[0])
    return row


def introduced_after(row):
    return bool(row["introduced"]) and parse_version(row["introduced"]) > AFTER


def enrich(row, registry, demand, impl):
    api, kind, lang, framework = row["api"], row["kind"], row["lang"], row["framework"]
    own = registry_status(registry, kind, api)
    owner_names = owners(kind, lang, api)
    owner_status = ""
    if own is None and owner_names:
        owner_status = show_registry(registry.get(owner_names[0]))
        owner_status = "" if owner_status == "none" else owner_status
    found = demand_for(demand, kind, api)
    hits = impl.lookup(framework, kind, api, owner_names)
    return [show_registry(own), owner_status,
            found["rank"] if found else "", found["severity"] if found else "", found["apps"] if found else "",
            "yes" if found and "telegram" in found["crash_callers"].split(",") else "",
            ",".join(dict.fromkeys(h[0] for h in hits)), ";".join(h[1] for h in hits)]


ENRICHED = ["registry", "owner-registry", "demand-rank", "demand-severity", "demand-apps", "demand-telegram", "impl-lead", "impl-file-lead"]
# `getter` sits with the declaration's own facts, next to `via`, and not with the enrichment: it is
# what the header declared (`getter=isSupported`), empty for every row the header declared nothing
# different for. It goes after `via` rather than at the end so the columns that describe the
# declaration stay together; the readers that index the row positionally (tools/intents/
# gen-registry.py:211, tests/backports/host/matter/members.m:101) only ever reach the first four.
SURFACE_HEAD = ["framework", "kind", "lang", "api", "introduced", "deprecated", "obsoleted", "unavailable", "via", "getter"] + ENRICHED
REMOVED_HEAD = ["framework", "kind", "lang", "api", "introduced", "deprecated", "old-obsoleted", "state", "new-framework", "new-introduced",
                "new-obsoleted", "new-unavailable"] + ENRICHED


def tsv(path, head, rows):
    with open(path, "w") as stream:
        stream.write("\t".join(head) + "\n")
        for row in rows:
            stream.write("\t".join(str(c).replace("\t", " ").replace("\n", " ") for c in row) + "\n")


def is_live(row, sdk_version):
    """A declaration an app of that SDK can use: not unavailable, not obsoleted at or below the SDK."""
    if row["unavailable"]:
        return False
    return not (row["obsoleted"] and parse_version(row["obsoleted"]) <= sdk_version)


def build(options):
    new_path, old_path = walks(options.new, options.old)
    new = json.load(open(new_path))
    old = json.load(open(old_path))
    registry_path = options.registry or newest("carried-registry-*.tsv")
    demand_path = options.demand or os.path.join(CORPUS, "crash-demand-top.tsv")
    registry = load_registry(registry_path)
    demand = load_demand(demand_path)
    impl = Impl()
    new_version = parse_version(new["version"])
    old_version = parse_version(old["version"])
    stem = "sdk-%s" % new["version"]
    print("new %s (%d rows), old %s (%d rows), registry %s (%d rows), demand %s (%d rows)" % (
        os.path.basename(new_path), len(new["rows"]), os.path.basename(old_path), len(old["rows"]),
        os.path.basename(registry_path), len(registry), os.path.basename(demand_path), len(demand)))

    surface = []
    unannotated = collections.Counter()
    before = collections.Counter()
    for row in new["rows"]:
        if not row["introduced"]:
            unannotated[(row["lang"], row["framework"])] += 1
            continue
        if not introduced_after(row):
            # a version taken from the container is a floor (that version or later): such a row may be newer than 6.1
            before[(row["lang"], "own" if row["via"] == "own" else "floor")] += 1
            continue
        surface.append(row)
    surface.sort(key=lambda r: (parse_version(r["introduced"]), r["framework"], r["lang"], r["kind"], r["api"]))
    enriched = []
    for row in surface:
        enriched.append([row["framework"], row["kind"], row["lang"], row["api"], row["introduced"], row["deprecated"],
                         row["obsoleted"], row["unavailable"], row["via"], row.get("getter", "")] + enrich(row, registry, demand, impl))
    tsv(os.path.join(CORPUS, stem + "-surface.tsv"), SURFACE_HEAD, enriched)

    present = {}
    for row in new["rows"]:
        key = (row["lang"], row["api"])
        # the same name can be declared in more than one framework; a usable declaration is the one that counts
        if key not in present or (not is_live(present[key], new_version) and is_live(row, new_version)):
            present[key] = row
    # A Swift name that is gone under its labels but declared again under others (`f(function:_:)` ->
    # `f(isolation:function:_:)`) has a changed signature, it is not removed.
    # Only labels the old walk does not have count: when the other overload was already there, one overload was
    # removed and the other kept, which is a removal.
    old_live = {(row["lang"], row["api"]) for row in old["rows"] if is_live(row, old_version)}
    relabelled = {}
    for row in new["rows"]:
        if (row["lang"] == "swift" and "(" in row["api"] and is_live(row, new_version)
                and (row["lang"], row["api"]) not in old_live):
            relabelled.setdefault((row["kind"], row["api"].split("(")[0]), row)
    removed = []
    for row in old["rows"]:
        if not is_live(row, old_version):
            continue
        current = present.get((row["lang"], row["api"]))
        if current is None and row["lang"] == "swift" and "(" in row["api"]:
            current = relabelled.get((row["kind"], row["api"].split("(")[0]))
            state = "changed" if current else "removed"
        elif current is None:
            state = "removed"
        elif current["unavailable"]:
            state = "unavailable"
        elif not is_live(current, new_version):
            state = "obsoleted"
        else:
            continue
        removed.append([row["framework"], row["kind"], row["lang"], row["api"], row["introduced"], row["deprecated"], row["obsoleted"],
                        state, current["framework"] if current else "", current["introduced"] if current else "",
                        current["obsoleted"] if current else "", current["unavailable"] if current else ""] + enrich(row, registry, demand, impl))
    removed.sort(key=lambda r: (r[7], r[0], r[2], r[1], r[3]))
    old_stem = "sdk-%s-removed-since-%s.tsv" % (new["version"], old["version"])
    tsv(os.path.join(CORPUS, old_stem), REMOVED_HEAD, removed)
    write_summary(os.path.join(CORPUS, stem + "-surface.md"), new, old, new_path, old_path, registry_path, demand_path,
                  enriched, removed, unannotated, before, impl)
    print("wrote %s-surface.tsv (%d rows), %s (%d rows), %s-surface.md" % (stem, len(enriched), old_stem, len(removed), stem))


def table(head, rows):
    lines = ["| " + " | ".join(head) + " |", "|" + "|".join("---" for _ in head) + "|"]
    lines += ["| " + " | ".join(str(c) for c in row) + " |" for row in rows]
    return "\n".join(lines)


def named(names):
    return ", ".join("`%s`" % n for n in names) if names else "none"


def not_in_surface(new, new_path, unannotated, before, floor_in_table):
    """The last section of the .md: everything the walk drops, cannot read or leaves out, counted and named."""
    dropped = new["dropped"]
    unversioned = {lang: sum(v for (l, _), v in unannotated.items() if l == lang) for lang in ("objc", "swift")}
    forward = dropped["forward-declaration"]
    anonymous = dropped["anonymous"]
    no_row = dropped["no-row"]
    return ["## Not in the surface", "",
            "Everything the walk of `%s` sees and does not put in the table, counted; what it cannot see at all is the last item." % os.path.basename(new_path), "",
            "- Introduced at or before iOS 6.1 (in the walk, not in the table): %d Objective-C / C and %d Swift rows with a version of their own; "
            "%d Objective-C / C and %d Swift rows more whose version at or before 6.1 is only a floor taken from their class, protocol, category "
            "or enum (`via=container` or `class-floor`), so any of them may have arrived after 6.1 and is not shown as such." % (
                before[("objc", "own")], before[("swift", "own")], before[("objc", "floor")], before[("swift", "floor")]),
            "- No iOS version at all (%d Objective-C / C and %d Swift rows): API from before the availability annotations, or Swift API "
            "whose module states no version. In the walk, not in the table. Objective-C members of a category with no annotation of its own take "
            "their class's or protocol's version as a floor (`via=class-floor`) and are not among these (a Swift extension member with no @available keeps `none`): %d rows took one, "
            "%d of them are in the table (the others took a version at or before 6.1)." % (
                unversioned["objc"], unversioned["swift"], dropped["class-floor"], floor_in_table),
            "- Forward declarations (`@class CIImage;`, `@protocol MTLTexture;`) in another framework's header, a row with no version "
            "beside the real one: %d Objective-C and %d Swift rows removed from the walk." % (forward["objc"], forward["swift"]),
            "- Enums and structs with no name of their own, which have no row (a `typedef struct {...} X` is one; the cases of an anonymous enum "
            "do have theirs): %d enums and %d structs." % (anonymous.get("enum", 0), anonymous.get("struct", 0)),
            "- Headers clang rejects, named with the first error (%d):%s" % (len(new["failed"]), "".join("\n  - " + f for f in new["failed"][:40])),
            "- %d frameworks with headers were walked and %d libraries under `usr/include` (`include/<directory>`, `include` for the loose "
            "top-level headers; the C++ standard library `c++`, the Darwin module's `_modules` shims and the `secure` wrappers are not walked, "
            "each is an `#error` or C++ when read alone). The C API of libSystem (`os_unfair_lock_*`, `dispatch_*`, `xpc_*`, `os_log_*`, `mach_*`) "
            "is in these." % (dropped["frameworks-walked"], dropped["libraries-walked"]),
            "- Frameworks, libraries and Swift modules that give no row at all (%d): %s." % (
                len(no_row), "; ".join("`%s` (%s)" % kv for kv in no_row.items())),
            "- Frameworks with headers that give no Objective-C / C row (%d; those of them named above give no row at all, the rest have Swift rows): %s." % (
                len(dropped["no-objc-row"]), named(dropped["no-objc-row"])),
            "- Swift modules: %d found, %d with rows; without rows: %s." % (
                dropped["swift-modules-found"], dropped["swift-modules-found"] - len(dropped["swift-modules-without-rows"]),
                named(dropped["swift-modules-without-rows"])),
            "- What neither clang nor a swiftinterface shows: macros (`#define` constants), typedefs and struct fields, conformances "
            "(`extension X: P`), SPI, private headers; frameworks that ship only a `.tbd` (%s)." % named([n for n, why in no_row.items() if ".tbd" in why]), ""]


def write_summary(path, new, old, new_path, old_path, registry_path, demand_path, rows, removed, unannotated, before, impl):
    at = {name: i for i, name in enumerate(SURFACE_HEAD)}
    total = len(rows)
    carried = sum(1 for r in rows if r[at["registry"]] == "carried")
    with_impl = sum(1 for r in rows if r[at["impl-lead"]])
    by_registry = collections.Counter(r[at["registry"]] for r in rows)
    by_owner = collections.Counter(r[at["owner-registry"]] for r in rows if r[at["registry"]] == "none")
    demanded = sum(1 for r in rows if r[at["demand-rank"]])
    telegram = sum(1 for r in rows if r[at["demand-telegram"]])
    majors = sorted({int(r[at["introduced"]].split(".")[0]) for r in rows})
    frameworks = collections.defaultdict(lambda: collections.Counter())
    for r in rows:
        frameworks[r[at["framework"]]][int(r[at["introduced"]].split(".")[0])] += 1
    per_source = collections.Counter()
    for r in rows:
        for source in r[at["impl-lead"]].split(","):
            if source:
                per_source[source] += 1
    by_via = collections.Counter(r[at["via"]] for r in rows)
    floor = lambda r: r[at["via"]] in ("container", "class-floor")
    dropped_total = sum(1 for r in removed if r[7] != "changed")
    lines = ["# SDK %s surface after iOS %s" % (new["version"], ".".join(str(p) for p in AFTER)), "",
             "Two things to read before using a number below:", "",
             "- **`impl-lead` is a lead by file name, not a fact of implementation.** A row has one when a reference "
             "implementation (WinObjC, swift-foundation, ...) has a *file* named after the type it belongs to (`UIView.mm` for "
             "`UIView.safeAreaInsets`). Nothing checks that the file implements that member, or that the repository's snapshot is "
             "as new as the API (WinObjC is years older than most of these rows).",
             "- **`via=container` and `via=class-floor` versions are a floor, not the arrival.** The member came in that iOS version "
             "*or later*: it took the version of the class, protocol, category or enum it sits in "
             "(`MTLGPUFamilyApple8` says 13.0 through its enum and came with iOS 16). Only `via=own` is the declaration's own "
             "`@available`.", "",
             "Generated by `tools/corpus/sdk-surface.py build`. Inputs: `%s` (%s, target %s), `%s`, registry `%s`, demand `%s`, "
             "implementation file lists `impl-source-trees/` (%s)." % (
                 os.path.basename(new_path), new["sdk"], new["target"], os.path.basename(old_path), os.path.basename(registry_path),
                 os.path.basename(demand_path), ", ".join("%s@%s" % (e["repo"], e["sha"][:8]) for e in impl.repos)), "",
             "## Totals", "",
             table(["", "rows"], [
                 ["declared after iOS 6.1 (`sdk-%s-surface.tsv`)" % new["version"], total],
                 ["of them Objective-C / C (clang)", sum(1 for r in rows if r[at["lang"]] == "objc")],
                 ["of them Swift-only (`.swiftinterface`)", sum(1 for r in rows if r[at["lang"]] == "swift")],
                 ["registry: carried", carried],
                 ["registry: absent", by_registry["absent"]],
                 ["registry: inert / ignored", "%d / %d" % (by_registry["inert"], by_registry["ignored"])],
                 ["registry: no row", by_registry["none"]],
                 ["  of those, the owning class or protocol has a row: carried / absent / other", "%d / %d / %d" % (
                     by_owner["carried"], by_owner["absent"], sum(v for k, v in by_owner.items() if k not in ("", "carried", "absent")))],
                 ["in the demand corpus", demanded],
                 ["  of those called by Telegram", telegram],
                 ["  `via` own / container / class-floor", "%d / %d / %d" % (by_via["own"], by_via["container"], by_via["class-floor"])],
                 ["with an `impl-lead` (a file name match, not an implementation, see above)", with_impl],
                 ["dropped since %s: removed / unavailable / obsoleted (`removed-since-%s.tsv`)" % (old["version"], old["version"]), dropped_total],
                 ["  and signature `changed` (same Swift name, other labels; in the same file, not counted above)", len(removed) - dropped_total]]), "",
             "`impl-lead` by repository (a row may have several): " + ", ".join("%s %d" % kv for kv in sorted(per_source.items())), "",
             "## By introduced iOS version", "",
             table(["iOS", "rows", "objc", "swift", "of them a floor", "carried", "with impl-lead"], [
                 [m, sum(1 for r in rows if int(r[at["introduced"]].split(".")[0]) == m),
                  sum(1 for r in rows if int(r[at["introduced"]].split(".")[0]) == m and r[at["lang"]] == "objc"),
                  sum(1 for r in rows if int(r[at["introduced"]].split(".")[0]) == m and r[at["lang"]] == "swift"),
                  sum(1 for r in rows if int(r[at["introduced"]].split(".")[0]) == m and floor(r)),
                  sum(1 for r in rows if int(r[at["introduced"]].split(".")[0]) == m and r[at["registry"]] == "carried"),
                  sum(1 for r in rows if int(r[at["introduced"]].split(".")[0]) == m and r[at["impl-lead"]])] for m in majors]), "",
             "## By framework and version", "",
             "Rows per framework and the major iOS version they arrived in; `carried` and `impl` (an `impl-lead`) are the two counts the task asked for.", "",
             table(["framework", "rows", "carried", "impl"] + [str(m) for m in majors], [
                 [fw, sum(counts.values()),
                  sum(1 for r in rows if r[at["framework"]] == fw and r[at["registry"]] == "carried"),
                  sum(1 for r in rows if r[at["framework"]] == fw and r[at["impl-lead"]])] + [counts[m] or "" for m in majors]
                 for fw, counts in sorted(frameworks.items(), key=lambda kv: -sum(kv[1].values()))]), "",
             "## Dropped since %s" % old["version"], "",
             "What %s declares and %s does not, or declares unavailable, or obsoleted at or below its version. A Swift name that "
             "is gone under its labels but declared again under others (`withCheckedContinuation(function:_:)` -> "
             "`withCheckedContinuation(isolation:function:_:)`) is `changed`, not removed: its signature moved, the name did not. "
             "Rows are matched by name and labels, so the `changed` and `removed` counts are a split of one comparison, and "
             "`changed` is not in the dropped total." % (old["sdk"], new["sdk"]), "",
             table(["state", "rows", "objc", "swift", "carried in the registry", "demanded"], [
                 [state, sum(1 for r in removed if r[7] == state), sum(1 for r in removed if r[7] == state and r[2] == "objc"),
                  sum(1 for r in removed if r[7] == state and r[2] == "swift"),
                  sum(1 for r in removed if r[7] == state and r[12] == "carried"),
                  sum(1 for r in removed if r[7] == state and r[14])] for state in ("removed", "unavailable", "obsoleted", "changed")]), ""]
    lines += not_in_surface(new, new_path, unannotated, before, by_via["class-floor"])
    with open(path, "w") as stream:
        stream.write("\n".join(lines))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("impl-index")
    b = sub.add_parser("build")
    b.add_argument("--new")
    b.add_argument("--old")
    b.add_argument("--registry")
    b.add_argument("--demand")
    options = parser.parse_args()
    if options.command == "impl-index":
        fetch_index()
    else:
        build(options)


if __name__ == "__main__":
    main()
