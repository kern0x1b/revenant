#!/usr/bin/env python3
"""
The exported Objective-C constants' real values, read out of real dyld shared caches.

Which of the surface's `constant` rows are exported constants is not guessed: it is read from the
header pass's own per-framework index (api-ledger.py's cache). A row is an exported constant when
the port's header declares it as a top-level variable -- an EnumConstantDecl is a depth-1 node and
is not in that index at all, so the two never mix. 6201 of the 20830 constant rows are exported
variables; the other 14622 are enum cases and carry their value in the header already.

The value is never invented and never taken from the SDK header. It is read out of a dyld shared
cache of a real release that has the symbol, oldest release first, through the project's own cache
reader (tools/corpus/cache-value.lua over modules/apple/dyld.lua): a release that already shipped
the constant is the release whose value it was. Which release each value came from is in the output,
next to the value. A constant no cache on this machine has is reported as such, with the releases
that were searched -- not guessed, and not filled in from the host framework, which is a different
platform with different values.

The width and the pointer/string reading of each value come from the declaration's own C type, with
the header's own typedefs resolved (`CFStringRef` -> `const struct __CFString *`, `CFIndex` ->
`long`), because a 4-byte read of a double and a pointer read of an integer are both wrong answers.

Usage:
  python3 const-values.py --index-dir <api-ledger cache dir> --surface <tsv> \\
      --caches <release>=<cache file>[,<release>=<file>...] --out <output dir> [--jobs N]
"""
import argparse
import collections
import csv
import os
import re
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.realpath(__file__))
CHARON_ROOT = os.path.realpath(os.path.join(HERE, "..", ".."))
CHARON_ROOT = os.environ.get("CHARON_ROOT", CHARON_ROOT)

# A type that is a pointer to a constant string: the reader is told to follow it and decode the
# CFString/NSString it names. Anything else that is a pointer is just an address.
STRING_TYPE_RE = re.compile(r"(__CFString|NSString|CFStringRef|NSConstantString)\s*\*")
# Scalar types and their width, keyed by the canonical type clang printed. `p` means "this cache's
# pointer size": on both ABIs here (armv7 and arm64e) a pointer, a long, a size_t and an NSInteger
# are all pointer-sized, which is why the same rule covers them.
SCALAR_WIDTHS = {"int": 4, "unsigned int": 4, "unsigned": 4, "long": "p", "unsigned long": "p",
                 "long long": 8, "unsigned long long": 8, "short": 2, "unsigned short": 2,
                 "char": 1, "signed char": 1, "unsigned char": 1, "float": 4, "double": 8,
                 "long double": 8, "BOOL": 1, "bool": 1, "_Bool": 1, "void *": "p",
                 "int32_t": 4, "uint32_t": 4, "int64_t": 8, "uint64_t": 8, "int16_t": 2,
                 "uint16_t": 2, "int8_t": 1, "uint8_t": 1, "size_t": "p", "ssize_t": "p",
                 "ptrdiff_t": "p", "intptr_t": "p", "uintptr_t": "p", "wchar_t": 4,
                 "NSInteger": "p", "NSUInteger": "p", "CFIndex": "p", "CFRunLoopRef": "p",
                 "CFStringRef": "p", "CFTypeID": "p", "CFHashCode": "p", "CFTypeRef": "p",
                 "Boolean": 1, "mach_port_t": 4, "id": "p", "Class": "p", "SEL": "p", "IMP": "p"}
FUNCTION_POINTER_RE = re.compile(r"^\w[\w ]*\([^)]*\)$")

# Types whose width is the ABI's, not the type's. The header walk runs at armv7-apple-ios6.1.3, where
# CGFloat is a 4-byte float and long is 4 bytes; the value is read out of whichever cache has the
# symbol, and a 64-bit cache holds 8 bytes for both. Reading the walk's width off a 64-bit slot
# returns half a double: measured, that turned UICellAccessoryStandardDimension into nan. So these
# are read at the cache's own pointer size, which is what each of them is on either ABI.
ABI_SIZED = {"CGFloat": "f", "NSInteger": "i", "NSUInteger": "i", "long": "i", "unsigned long": "i",
             "size_t": "i", "ssize_t": "i",
             "CFIndex": "i", "CFAbsoluteTime": "f", "NSTimeInterval": "f", "ptrdiff_t": "i",
             "intptr_t": "i", "uintptr_t": "i", "CFTypeID": "i", "CFHashCode": "i", "mach_vm_size_t": "i",
             "vm_size_t": "i", "vm_offset_t": "i", "kern_boottime_t": "i", "id": "i", "Class": "i",
             "SEL": "i", "IMP": "i", "Boolean": 1, "BOOL": 1, "dispatch_once_t": "i"}

# The reader is checked before any value is taken from a cache, against values that are measured
# rather than asserted: a constant string whose value is its own name ("NSURLIsDirectoryKey") has to
# read back as its own name. Which constants those are is not written down here -- they are found by
# reading the reference cache, whose values are the ones already in hand -- and a cache that cannot
# reproduce them is not used for any value at all, because a wrong slide or chain rule reads a
# neighbouring object and that is worse than no value. The reference is the cache named by
# --oracle-cache: pick the one with the least to undo, a 32-bit cache, which is never slid.
ORACLE_SAMPLE = 8


def note(message):
    print(message, file=sys.stderr, flush=True)


def load_surface(path):
    rows = []
    with open(path, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f, delimiter="\t"):
            rows.append(row)
    return rows


def strip_type(text):
    """The canonical type clang printed, without the qualifiers that do not change its width."""
    cleaned = re.sub(r"\b(const|volatile|restrict|_Nonnull|_Nullable|_Null_unspecified|"
                     r"__kindof|__unsafe_unretained|strong|weak|atomic|nonatomic|readonly|"
                     r"readwrite|_Nullable_result)\b", " ", text)
    return " ".join(cleaned.split())


def resolve_type(declared, typedefs):
    """The declared type with the header's own typedefs followed, up to a depth that cannot cycle."""
    seen, current = set(), strip_type(declared)
    for _ in range(16):
        if current in seen:
            return current, False
        seen.add(current)
        nxt = typedefs.get(current)
        if not nxt:
            return current, True
        current = strip_type(nxt)
    return current, False


def classify(sugared, canonical, typedefs):
    """(width for the read, is_pointer, is_string, the resolved type) from the declaration's own
    type. The width is "p" for a type whose size is the ABI's -- a pointer, a long, a size_t, a
    CGFloat, an NSInteger -- and the reader fills it in from the cache's own ABI, because the header
    walk runs at armv7 where CGFloat is a 4-byte float and a 64-bit cache holds 8 bytes for it. It is
    0 for a type that is neither a scalar nor a pointer, a struct or an array, and nothing is read
    off such a symbol: a fixed-width read of it would be reading past the object or stopping inside
    it. These are different cases and the file format says which is which."""
    resolved, _ = resolve_type(canonical, typedefs)
    if not resolved:
        return 0, False, False, canonical
    # The sugared name is what the source wrote and the only place an ABI-sized name appears; the
    # canonical one is what the walk's own target made of it (a 4-byte float for CGFloat on armv7).
    abi = ABI_SIZED.get(strip_type(sugared)) or ABI_SIZED.get(strip_type(canonical))
    if abi is not None:
        # Read at the cache's own pointer size, whatever the walk's target made this type.
        if abi == 1:
            return 1, False, False, resolved
        if "*" in resolved:
            return "p", True, bool(STRING_TYPE_RE.search(resolved)), resolved
        return "p", False, False, resolved
    if "*" in resolved:
        return "p", True, bool(STRING_TYPE_RE.search(resolved)), resolved
    if resolved in SCALAR_WIDTHS:
        width = SCALAR_WIDTHS[resolved]
        return (width if width == "p" else width), False, False, resolved
    if FUNCTION_POINTER_RE.match(resolved):
        return "p", True, False, resolved
    return 0, False, False, resolved


def float32(u32):
    import struct
    return struct.unpack("<f", struct.pack("<I", u32 & 0xFFFFFFFF))[0]


def sentinel_reason(ctype, declared, read_width, storage, u32, f64):
    """Why these bytes are not a value the port can export, or None when they are one.

    Two shapes, both measured rather than judged:

      - a read wider than the symbol's own storage (the distance to the next export in the same
        image) assembles the value out of the bytes past its end, which belong to the next symbol;
      - bytes that are not a finite value of the type. A release that *initialises* a constant to
        a placeholder -- UIKit's UICellAccessoryStandardDimension and
        UIListContentImageStandardDimension hold `0xFFFFFFFF` in the low four bytes on 16.0 and
        18.0, which is a float NaN and an int32 -1 -- ships something the tool is faithful to but
        that is not the constant's value. The resolved type of a CGFloat read at the ABI width is
        `float`, the 4-byte float, and its half is not finite, which is how that is caught.
    """
    import math
    if storage and read_width > storage:
        return ("read-too-wide",
                "the symbol's own storage is %d bytes (the distance to the next export in the same "
                "image) and %d were read, so the value would be built from the bytes past its end"
                % (storage, read_width))
    kind = ctype.strip()
    if kind in ("float", "double", "long double"):
        if not math.isfinite(f64):
            return ("read-sentinel",
                    "the bytes are not a finite %s (%s): a placeholder the release initialises, not "
                    "a value to export" % (kind, hex(f64)))
        narrow = "float" if kind == "float" else kind
        if "CGFloat" in declared or "NSTimeInterval" in declared or "CFAbsoluteTime" in declared:
            # Read at the cache's ABI width; the resolved type is this walk's, from armv7.
            if not math.isfinite(float32(u32)):
                return ("read-sentinel",
                        "read at the cache's pointer width, and the low four bytes (%s) are not a "
                        "finite float, so a placeholder the release initialises is being read as a "
                        "value" % ("0x%08x" % (u32 & 0xFFFFFFFF)))
        elif kind == "float" and not math.isfinite(float32(u32)):
            return ("read-sentinel",
                    "the bytes are not a finite float (%s): a placeholder the release initialises, "
                    "not a value to export" % ("0x%08x" % (u32 & 0xFFFFFFFF)))
    return None


def format_value(ctype, read_width, pointer, text, u32, u64, f64, hexed):
    """The value as C would spell it, from the declaration's type and the width the reader actually
    read -- or the raw bytes when the type says nothing this can read (an array, a typedef these
    headers do not resolve), named as such rather than guessed."""
    if not hexed or hexed == "-":
        return "", ("the declared type is neither a scalar nor a pointer (%s): the symbol is at %#s "
                    "in this release, and no fixed-width read of it would be this constant's value"
                    % (ctype, hexed))
    if pointer:
        if text and text != "-":
            return '"%s"' % text, "constant string"
        return "", ("a function pointer or a pointer to something that is not a constant string: the "
                    "release holds an address at %#s, which is not a value the port can export -- it "
                    "needs a real definition" % (text if text and text != "-" else hexed))
    kind = ctype.strip()
    if kind == "double" and read_width == 4:
        return repr(float32(u32)), "CGFloat, 4 bytes in this cache"
    if kind in ("float", "double", "long double"):
        if kind == "float" and read_width == 4:
            return repr(float32(u32)), "float"
        return repr(f64), "double" if kind != "long double" else "long double, read as double"
    if kind and kind not in SCALAR_WIDTHS:
        return hexed, "raw bytes: the declared type is not a scalar this reads (%s)" % kind
    if read_width == 8:
        return str(u64), "64-bit integer"
    if read_width in (1, 2, 4):
        return str(u32), "integer"
    return hexed, "raw bytes: no width was read (%s)" % kind


def read_cache(cachefile, symbols):
    """One cache-value.lua run: {symbol: (install, address, hex, u32, u64, f64, pointer, text)}."""
    with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False, encoding="utf-8") as f:
        for name, width, pointer, text in symbols:
            f.write("%s\t%s\t%s\t%s\n" % (name, width, "p" if pointer else "-",
                                          "s" if text else "-"))
        listing = f.name
    try:
        env = dict(os.environ, CHARON_ROOT=CHARON_ROOT)
        out = subprocess.run(["xmake", "l", os.path.join(HERE, "cache-value.lua"), cachefile, listing],
                             cwd=CHARON_ROOT, env=env, capture_output=True, text=True, timeout=5400)
    finally:
        os.unlink(listing)
    if out.returncode != 0:
        raise RuntimeError("cache-value.lua failed on %s: %s" % (cachefile, out.stderr[-3000:]))
    values, architecture = {}, ""
    for line in out.stdout.splitlines():
        parts = line.split("\t")
        if parts[0] == "#cache":
            architecture = parts[1]
            continue
        if len(parts) < 10:
            continue
        name, install, address, hexed, u32, u64, f64, pointer, text, width = parts[:10]
        storage = int(parts[10]) if len(parts) > 10 and parts[10] != "-" else 0
        if install == "-":
            continue
        # A symbol the cache has but that was not read -- a struct, an array, a read wider than its
        # storage -- comes back with dashes where the bytes would be. That is a real answer (the
        # release has the symbol; the tool declines to read a value off it) and the caller sees it as
        # an empty `hexed`, so the numbers are only parsed when there are any.
        def number(text):
            try:
                return int(text)
            except ValueError:
                return 0

        values[name] = (install, address, hexed, number(u32), number(u64), number(f64), pointer, text,
                        number(width), storage)
    return values, architecture


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    ap.add_argument("--index-dir", required=True, help="api-ledger.py's per-framework cache")
    ap.add_argument("--surface", required=True)
    ap.add_argument("--caches", required=True,
                    help="comma-separated <release>=<cache file>, oldest release first")
    ap.add_argument("--out", required=True)
    ap.add_argument("--oracle-cache", required=True,
                    help="the cache the reader is checked against before any value is taken")
    ap.add_argument("--only", default=None, help="comma-separated frameworks, for a smoke run")
    args = ap.parse_args()
    started = time.time()

    rows = load_surface(args.surface)
    wanted = collections.defaultdict(set)
    if args.only:
        rows = [r for r in rows if r["framework"] in set(args.only.split(","))]
    for row in rows:
        if row["lang"] == "objc" and row["kind"] == "constant":
            wanted[row["framework"]].add(row["api"])

    indexes = {}
    for framework in wanted:
        path = os.path.join(args.index_dir, framework.replace("/", "_") + ".json")
        if os.path.exists(path):
            import json
            with open(path, encoding="utf-8") as f:
                indexes[framework] = json.load(f)
    note("%d frameworks, %d constant rows, %d header indexes read"
         % (len(wanted), sum(len(v) for v in wanted.values()), len(indexes)))

    # The exported constants: declared as a top-level variable in the port's header, and not static
    # (a static one needs no symbol and its value is in the header).
    constants = {}
    for framework, names in wanted.items():
        index = indexes.get(framework)
        if not index or "flags" not in index:
            continue
        for name in names:
            flags = index["flags"].get(name)
            if not flags:
                continue
            is_extern, is_static = flags[0], flags[1]
            if not (is_extern or not is_static):
                continue
            width, pointer, text, resolved = classify(flags[3], flags[4], index.get("typedefs", {}))
            constants.setdefault(name, (framework, flags[3], resolved, width, pointer, text))
    note("%d exported constants: %d read at the width their own type declares, %d a type whose size "
         "is the ABI's -- read at the cache's pointer size, %d of those a pointer -- and %d a type "
         "that is neither a scalar nor a pointer (a struct or an array), from which nothing is read"
         % (len(constants),
            sum(1 for c in constants.values() if not (c[3] == "p" or (c[3] == 0 and not c[4]))),
            sum(1 for c in constants.values() if c[3] == "p"),
            sum(1 for c in constants.values() if c[3] == "p" and c[4]),
            sum(1 for c in constants.values() if c[3] == 0 and not c[4])))

    # Oldest release first: the value a release shipped is the value the constant had.
    # The oracle: constants whose value is their own name, measured on the reference cache.
    strings = sorted(n for n, c in constants.items() if c[4] and c[5])
    reference, reference_abi = read_cache(
        args.oracle_cache, [(n, constants[n][3], constants[n][4], constants[n][5]) for n in strings])
    release_of = {pair.partition("=")[2]: pair.partition("=")[0]
                  for pair in args.caches.split(",") if "=" in pair}
    reference_release = release_of.get(os.path.realpath(args.oracle_cache), args.oracle_cache)
    oracle = sorted(n for n, v in reference.items() if v[7] == n)
    if not oracle:
        note("no constant string in %s reads back as its own name, so the reader cannot be checked "
             "here; refusing to write values" % args.oracle_cache)
        sys.exit("const-values.py: no oracle on this machine. Re-run with --oracle-cache naming a "
                 "cache the reader handles (a 32-bit one).")
    # Spread over the whole set rather than the first few, so a cache that is right about one corner
    # of the corpus is not taken as right about all of it.
    step = max(1, len(oracle) // ORACLE_SAMPLE)
    sample = oracle[::step][:ORACLE_SAMPLE]
    note("oracle: %d of %d constant strings read back as their own name on %s; %d of them are "
         "checked on every cache (%s%s)" % (len(oracle), len(strings), args.oracle_cache,
                                            len(sample), ", ".join(sample[:4]),
                                            ", ..." if len(sample) > 4 else ""))
    # Every cache is checked against the oracle constants it actually holds -- an earlier release
    # holds none of the later ones, which is not a disagreement -- and the rule is:
    #
    #   reproduces none of the ones it holds   -> refused, and no value of its is used;
    #   reproduces some, disagrees on some     -> used, with the disagreeing constants flagged one by
    #                                              one and both values shown;
    #   holds none of them                     -> unchecked here, so it takes the verdict of a
    #                                              checked cache of the same architecture, and is
    #                                              refused when no same-architecture cache was
    #                                              checked. The reader's 32-bit and 64-bit paths are
    #                                              different code, so a verdict crosses an
    #                                              architecture only when it has nothing else and
    #                                              never from one architecture to the other.
    #
    # A cache with nothing of its own to check is the case that bit nothing in the first run (every
    # cache used here holds at least one of the checked constants) and would have gone in unchecked
    # and silently: the inheritance is what makes "checked" mean something for such a cache.
    resolved, searched, refused, differed = {}, [], [], {}
    # The rows read at the cache's ABI width rather than at their own resolved type's, and every
    # cache's reading of them, kept apart from the resolution so that asking each cache for them
    # cannot change which release a row is taken from.
    abi_set = {n for n, c in constants.items() if c[3] == "p" and not c[4]}
    abi_reads = {}
    # Per architecture: the release whose reading the others inherit, and how many of the checked
    # constants that release reproduced.
    verdicts, unchecked = {}, []
    for pair in args.caches.split(","):
        release, _, cachefile = pair.partition("=")
        if not cachefile or not os.path.exists(cachefile):
            note("  %s: no cache at %s, skipped" % (release, cachefile))
            searched.append(release)
            continue
        left = [n for n in constants if n not in resolved]
        if not left:
            break
        note("  %s: reading %d symbols from %s" % (release, len(left), os.path.basename(cachefile)))
        # The ABI-width rows ride along in the same walk: they are what the corroboration below is
        # made of, and asking for them here costs nothing next to walking a cache at all.
        ask = set(left) | abi_set
        batch = [(n, constants[n][3], constants[n][4], constants[n][5]) for n in sorted(ask)]
        # The same check on every cache, not only the reference: a cache whose slide or chain layout
        # this reader does not follow would otherwise contribute values that are its neighbours'.
        # "p": the checked constants are constant strings, which are pointer-sized on both ABIs.
        probe, abi = read_cache(cachefile, [(n, "p", True, True) for n in oracle])
        present = sorted(probe)
        agreed = sorted(n for n in present if probe[n][7] == reference[n][7])
        # A checked constant whose value is not the one the reference measured is one of two things,
        # and they are not the same: the reader followed a neighbouring object, or Apple shipped a
        # different value in this release. The first is caught by the reader agreeing on the rest --
        # a reader that is wrong here agrees on nothing. The second is a real difference in the API,
        # so the value is taken and flagged with both, since a porter has to decide which to ship.
        changed = {n: probe[n][7] for n in present if n not in agreed}
        if present and not agreed:
            refused.append("%s (%s: reproduces none of the %d checked constants it holds)"
                           % (release, abi, len(present)))
            note("    %s (%s): the reader reproduces none of the %d checked constants it holds, so "
                 "no value is taken from it" % (release, abi, len(present)))
            searched.append(release)
            continue
        if not present:
            # Nothing of the oracle's is here, so this cache is not checked in its own right. It is
            # left pending and resolved against its architecture once every cache has been read.
            unchecked.append((release, cachefile, batch, abi))
            note("    %s (%s): holds none of the %d checked constants -- unchecked for now, and it "
                 "takes the verdict of a checked %s cache or none" % (release, abi, len(oracle), abi))
            searched.append(release)
            continue
        note("    %s (%s): reader reproduces %d of the %d checked constants it holds%s"
             % (release, abi, len(agreed), len(present),
                ", %d differ from %s and are flagged" % (len(changed), os.path.basename(args.oracle_cache))
                if changed else ""))
        if abi not in verdicts:
            verdicts[abi] = {"release": release, "agreed": len(agreed), "present": len(present)}
        values, _ = read_cache(cachefile, batch)
        for name, value in values.items():
            if name in abi_set:
                # Every cache's reading of an ABI-width row, kept beside the resolution rather than
                # instead of it: a row is still taken from the oldest release that has it.
                abi_reads.setdefault(name, []).append((release, value))
            if name in left:
                resolved[name] = (release,) + value
        differed.update(changed)
        note("    %d of %d symbols are in this release" % (len(values), len(left)))
        searched.append(release)

    # Now the caches that were not checked in their own right. A cache with no verdict to inherit is
    # refused, and anything it read is dropped: an unchecked read is a guess, and a guess in a
    # constants file is worse than a gap.
    for release, cachefile, batch, abi in unchecked:
        verdict = verdicts.get(abi)
        if not verdict:
            refused.append("%s (%s: unchecked, and no %s cache was checked to inherit from)"
                           % (release, abi, abi))
            note("    %s (%s): no %s cache was checked, so this one is refused" % (release, abi, abi))
            continue
        values, _ = read_cache(cachefile, batch)
        for name, value in values.items():
            resolved.setdefault(name, (release,) + value)
        note("    %s (%s): takes %s's verdict (reproduced %d of %d checked constants) -- %d symbols"
             % (release, abi, verdict["release"], verdict["agreed"], verdict["present"], len(values)))

    # Corroboration for the rows read at the cache's ABI width. The self-naming oracle covers
    # constant strings only, so a `CGFloat`/`CFAbsoluteTime`/`long` read at the pointer size is
    # unverified by construction: the resolved type this walk sees is armv7's, and nothing else in
    # the run exercises the width. So each such row is read again from every other cache that has
    # the symbol, and it counts as corroborated only when a same-width reading in another cache
    # gives the same value. The rows nothing corroborates are named in the summary, not counted.
    abi_rows = {n: c for n, c in constants.items() if c[3] == "p" and not c[4]}
    agreed_with = {}
    # resolved[name] is the reader's tuple with the release in front of it, so every index below is
    # the reader's plus one: release, install, address, bytes, u32, u64, f64, pointer, text, width,
    # storage. abi_reads holds the reader's own tuples, unshifted.
    incomparable, other_width, differing, comparable = {}, {}, {}, set()
    for name, mine in resolved.items():
        row = abi_rows.get(name)
        if not row:
            continue
        # The row's own reading has to be a value before another reading can corroborate it.
        if sentinel_reason(row[2], row[1], mine[9], mine[10], mine[4], mine[6]):
            continue
        mine_value = format_value(row[2], mine[9], mine[7], mine[8], mine[4], mine[5], mine[6],
                                  mine[3])
        for release, theirs in abi_reads.get(name, []):
            if release == mine[0]:
                continue
            if not theirs[2] or theirs[2] == "-":
                continue        # nothing was read there, so there is nothing to compare
            if sentinel_reason(row[2], row[1], theirs[8], theirs[9], theirs[3], theirs[5]):
                # The other release's own slot for this symbol is narrower than the width read (or
                # holds a placeholder), so the two readings are not about the same thing. That is a
                # fact about the two releases, not a failure of the reading, and it is counted apart
                # rather than quietly dropped.
                incomparable.setdefault(name, []).append(release)
                continue
            other = format_value(row[2], theirs[8], theirs[6], theirs[7], theirs[3], theirs[4],
                                 theirs[5], theirs[2])
            if theirs[8] != mine[9]:
                # A reading of a different width is not about the same thing: a CGFloat is four
                # bytes in an armv7 release and eight in an arm64e one, and that is the width the
                # whole point of these rows is. Counted apart rather than quietly dropped.
                other_width.setdefault(name, []).append(release)
                continue
            if other[0] == "" or mine_value[0] == "":
                continue        # one side read no value, so there is nothing to compare
            comparable.add(name)
            if other[0] == mine_value[0]:
                agreed_with[name] = agreed_with.get(name, 0) + 1
            else:
                differing.setdefault(name, []).append((release, other[0], mine_value[0]))
    # A row only one of the caches read has nothing to be corroborated by, which is neither a
    # corroboration nor a failure; it is counted on its own so the two are not confused.
    single = sorted(n for n in abi_rows if n in resolved and len(abi_reads.get(n, [])) < 2)
    uncorroborated = sorted(n for n in abi_rows if n in resolved and agreed_with.get(n, 0) == 0)
    note("ABI-width reads: %d in all, %d corroborated by a same-width reading in another cache. "
         "%d of the %d had a second reading at the same width that produced a value to compare "
         "with, so %d is the most any of them could reach on this machine. Of the rest: %d are only "
         "in releases of the other ABI, where the same type is a different width, and %d have a "
         "second reading whose own slot is narrower than the width read. %d disagreed where they "
         "could be compared (%s)."
         % (len(abi_rows), len(abi_rows) - len(uncorroborated), len(comparable), len(abi_rows),
            max(len(comparable), len(abi_rows) - len(uncorroborated)), len(other_width),
            len(incomparable), len(differing),
            "; ".join("%s %s != %s" % (n, b, a) for n, v in sorted(differing.items())[:3] for _, a, b
                      in v[:1]) or "none"))

    os.makedirs(args.out, exist_ok=True)
    path = os.path.join(args.out, "exported-constants.tsv")
    kinds = collections.Counter()
    with open(path, "w", encoding="utf-8") as f:
        f.write("framework\tapi\tc-type\tvalue\tfrom-release\tstatus\tdetail\tinstall\taddress\t"
                "raw-bytes\tint32\tint64\tdouble\twidth\tstorage\tagreed-in-caches\n")
        for name in sorted(constants):
            framework, declared, ctype, width, pointer, text = constants[name]
            if name in resolved:
                (release, install, address, hexed, u32, u64, f64, pointed, body, read_width,
                 storage) = resolved[name]
                if not hexed or hexed == "-":
                    # No bytes came back, and there are two quite different reasons, which are two
                    # different things for a porter: the declared type is not something a fixed-width
                    # read can be taken of, or the read was refused because the symbol's own storage
                    # is narrower than the width. The second is a fact about the release, and it says
                    # the release stores this constant in less space than its type claims.
                    if read_width and storage and read_width > storage:
                        status = "read-too-wide"
                        detail = ("the symbol's own storage is %d bytes (the distance to the next "
                                  "export in the same image) and its type would be read at %d, so no "
                                  "value is read: this release stores it in less space than its "
                                  "type claims, and the bytes past its end belong to the next symbol"
                                  % (storage, read_width))
                    else:
                        status = "read"
                        detail = ("the declared type is neither a scalar nor a pointer (%s): the "
                                  "symbol is at %#s in this release, and no fixed-width read of it "
                                  "would be this constant's value" % (ctype, address))
                    value = ""
                else:
                    value, detail = format_value(ctype, read_width, pointer, body, u32, u64, f64,
                                                 hexed)
                    status = "read"
                    sent = sentinel_reason(ctype, declared, read_width, storage, u32, f64)
                    if sent:
                        status, why = sent
                        detail = "%s; %s, and the raw bytes are %s" % (detail, why, hexed)
                        value = hexed
                if name in differed:
                    status = "read-changed"
                    detail += ("; this release's value differs from the one %s measured for the same "
                               "symbol (%r), so it is a real difference in the API and not this "
                               "reader" % (reference_release, reference[name][7]))
            else:
                release = install = address = hexed = read_width = storage = ""
                u32 = u64 = ""
                f64 = pointed = body = ""
                value, detail, status = "", "no release on this machine has it", "no-release"
            kinds[(status, detail.split(":")[0])] += 1
            f.write("%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n"
                    % (framework, name, "%s (declared %s)" % (ctype, declared), value, release,
                       status, detail, install, address, hexed, u32, u64,
                       repr(f64) if f64 != "" else "", read_width, storage,
                       agreed_with.get(name, 0) if name in abi_rows else ""))
    note("wrote %s (%d rows, %.1f minutes)" % (path, len(constants), (time.time() - started) / 60.0))

    summary = os.path.join(args.out, "EXPORTED-CONSTANTS.md")
    with open(summary, "w", encoding="utf-8") as f:
        read = sum(v for (s, _), v in kinds.items() if s == "read")
        none = sum(v for (s, _), v in kinds.items() if s == "no-release")
        f.write("# Exported Objective-C constants, with the values real releases shipped\n\n")
        f.write("%d of the surface's `constant` rows are exported variables -- declared as a "
                "top-level variable in the lifted header, not an enum case, which is a different "
                "node in the header and carries its value in the header already. Every value below "
                "was read out of a dyld shared cache of a real release that has the symbol, oldest "
                "release first, through `tools/corpus/cache-value.lua` over the project's own cache "
                "reader. **No value here is invented, and none is taken from a header comment or "
                "from the host framework.**\n\n" % len(constants))
        f.write("Run: %.1f minutes. Caches read, oldest first: %s.\n\n"
                % ((time.time() - started) / 60.0, ", ".join(searched)))
        if refused:
            f.write("Caches **refused**: %s -- the reader did not reproduce the checked constants "
                    "there, so no value is taken from them (a wrong slide or chain rule reads a "
                    "neighbouring object, which is worse than no value). Those constants are reported "
                    "`no-release` even though the release has them.\n\n" % ", ".join(refused))
        f.write("| | rows |\n| --- | --- |\n")
        f.write("| value read from a release | %d |\n" % (read + len(differed)))
        f.write("| no release on this machine has it | %d |\n" % none)
        if differed:
            f.write("| of those, a value that differs from the reference release's for the same "
                    "symbol | %d |\n" % len(differed))
        f.write("\n## How the value was read\n\n| kind | rows |\n| --- | --- |\n")
        for (status, detail), count in kinds.most_common():
            f.write("| %s: %s | %d |\n" % (status, detail, count))
        f.write("\n## What this does not cover\n\n")
        f.write("- A constant no cache on this machine holds is reported `no-release`, not filled in. "
                "The releases searched are listed above; a constant introduced after the newest of "
                "them needs that release's IPSW fetched before its value can be read.\n")
        f.write("- Before a single value is taken from a cache, the reader has to reproduce, there, "
                "the %d measured constants whose value is their own name (%s%s). **A cache that "
                "reproduces none of the checked constants it holds is refused outright** and its "
                "values are not used; one that disagrees on some is used, with the disagreeing "
                "constants flagged one by one (`read-changed`, both values in the row) rather than "
                "the release thrown away. A cache that holds none of the checked constants cannot be "
                "checked in its own right, so it takes the verdict of a checked cache of the same "
                "architecture -- the reader's 32-bit and 64-bit paths are different code -- and is "
                "refused when no same-architecture cache was checked. Per architecture: %s. The list "
                "is measured on the reference cache (%s), not written down here.\n"
                % (len(oracle), ", ".join(sample[:4]), ", ..." if len(sample) > 4 else "",
                   ", ".join("%s <- %s (%d of %d)" % (abi, v["release"], v["agreed"], v["present"])
                             for abi, v in sorted(verdicts.items())) or "nothing was checked",
                   os.path.basename(args.oracle_cache)))
        f.write("- A `CGFloat`, `CFAbsoluteTime` or `long` is read at the **cache's** pointer width, "
                "because the header walk runs at armv7 where `CGFloat` is a 4-byte float. Nothing in "
                "the self-naming oracle exercises that width -- it covers constant strings only -- so "
                "every such row is read again from each other cache that has the symbol, and counts "
                "as corroborated only when a same-width reading there gives the same value. %d of "
                "those %d rows are corroborated; **%d are not**, and they are named in the "
                "`agreed-in-caches` column: %s.\n"
                % (len(abi_rows) - len(uncorroborated), len(abi_rows), len(uncorroborated),
                   ", ".join(uncorroborated) if uncorroborated else "none"))
        f.write("  - %d of the %d not corroborated have no same-width reading to compare with: the "
                "other release that carries the symbol is a different ABI, where the same type is a "
                "different width -- a `CGFloat` is four bytes in an armv7 release and eight in an "
                "arm64e one, which is the whole reason these rows are read at the cache's width.\n"
                % (len(other_width), len(uncorroborated)))
        if incomparable:
            f.write("  - %d could not be compared because in the other release the symbol's own "
                    "slot is narrower than the width read: %s. That is a fact about the two "
                    "releases, not a failure of the reading.\n"
                    % (len(incomparable), ", ".join(sorted(incomparable)[:12]) +
                       (", ..." if len(incomparable) > 12 else "")))
        if differing:
            f.write("  - %d had a same-width reading in another cache that **disagrees**, which is "
                    "the one case that would mean a width is being read wrongly: %s.\n"
                    % (len(differing), "; ".join("%s: %s reads %s" % (n, a, b)
                                                 for n, v in sorted(differing.items())[:6])))
        f.write("- A `float`/`double` whose bytes are not a finite value, or whose four-byte half is "
                "not a finite float while the resolved type is `float`, is reported `read-sentinel` "
                "with its raw bytes rather than as a value: a release that initialises a constant to "
                "a placeholder ships something the reader is faithful to and that is not the "
                "constant's value. A read wider than the symbol's own storage -- the distance to the "
                "next export in the same image, which is in the `storage` column -- is refused as "
                "`read-too-wide` rather than assembled from the bytes past the symbol.\n")
        f.write("- The read is by symbol name, so a constant a release re-exported under a stub is "
                "credited to the image the export trie names; the install column says which.\n")
        f.write("- A value whose declared type is neither a scalar nor a pointer (an array, a "
                "function pointer, a typedef these headers do not resolve) is written as its raw "
                "bytes with the type named, not interpreted.\n")
    note("wrote %s" % summary)


if __name__ == "__main__":
    main()
