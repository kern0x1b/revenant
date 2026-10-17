#!/usr/bin/env python3
"""build.py - one name index per held release, read once each, and the merged table first-rung.lua answers from.

    python3 tools/cache-index/build.py [--only RELEASE]... [--force] [--ladder armv7,armv7s]

The first held rung of a name was found by running

    strings -a ~/.charon/dyld/<release>/dyld_shared_cache_<arch> | grep -xF NAME

over every rung, once per name, per slice, per author. That reads the whole cache per name, which
measures 6 ms per MB on this machine: 0.42 s at 80 MB, 1.38 s at 233 MB, 6.04 s at 1002 MB, and so
~148 s for ONE name over the whole 24.6 GB ladder the workspace holds. With load at 19-22 several
authors were doing that at once, which is the bottleneck this tool removes.

This reads each cache ONCE, with tools/cache-index/names.lua (which reuses modules/apple/dyld.lua and
modules/apple/macho.lua for every byte of Mach-O and cache parsing), and writes

    $HOME/.charon/cache-index/<release>.names.gz     sorted, deduplicated, one name per line
    $HOME/.charon/cache-index/first-rung.tsv.gz      every name -> the first held rung that carries it

Each per-release file opens with one header line naming what it was read from and when, which is the
staleness key: a file whose header's mtime and size still match the cache is left alone, so a second
run costs 50 header reads and nothing else. A cache fetched again has a new mtime, and only a copy
that keeps both the size and the time of the file it replaces goes unseen - the same rule
modules/apple/dyld.lua's ladder_signature() uses for its own kept measurements, and the reason the
header carries both and not either.

THE LADDER IS THE PORT'S OWN. The rungs and their order come from dyld.held_ladder({"armv7","armv7s"})
in modules/apple/dyld.lua: for each release, the first of armv7, armv7s, arm64, arm64e that is held,
oldest first. Only the directory walk and that preference order are restated here, because this is a
python3 script and the ladder is Lua; the reading of a cache is not restated, it is called.

READ-ONLY TOWARDS THE CACHES. Nothing here writes under ~/.charon/dyld. The output is a separate
directory, so a sweep of that is a sweep of these and not of the firmware.

COST, so nobody runs this by accident: one process at a time, one release at a time, and niced. A full
cold build over the 50 held rungs reads 24.6 GB once and takes minutes; it is NOT a build, so it does
not go through coordination/heavy.sh, but it is not free either. Do not start it while the machine is
busy without nice (build.py renices itself and its child, which is why it can be run from a busy
session). Afterwards every lookup is a read of one small gz file.
"""
import argparse
import gzip
import os
import re
import subprocess
import sys
import time
from functools import cmp_to_key

# The architectures dyld.held_ladder prefers, in its order. See the docstring.
PREFERRED = ("armv7", "armv7s", "arm64", "arm64e")

# `format` is the file's PROMISE, and the order is part of it: format 1 sorted by code point, format 2
# sorts by BYTE. A file that says 1 is not stale, it is in the old order, and is re-sorted in place
# (below) rather than re-read from 24.6 GB of cache. That is why the field is in the header and not
# only in this file: the reader can see it without reading a name.
HEADER = ("# charon-cache-index 2 format=2 order=byte release={release} arch={arch} source={source} "
          "mtime={mtime} size={size} names={names}\n")


def index_dir():
    return os.path.join(os.getenv("CHARON_HOME") or os.path.join(os.getenv("HOME"), ".charon"),
                        "cache-index")


def versions(text):
    return [int(part) for part in re.findall(r"\d+", text)]


def compare(a, b):
    left, right = versions(a), versions(b)
    width = max(len(left), len(right))
    left += [0] * (width - len(left))
    right += [0] * (width - len(right))
    return (left > right) - (left < right)


def held_source(folder, arch):
    """What dyld.held_source() names for a release and architecture: the cache file, or a libraries
    folder beside it. A release can ship a public framework as a file beside the cache rather than in
    it (PushKit on iPad2,4 8.0 and 8.1.3), and what it exports is both."""
    cache = os.path.join(folder, "dyld_shared_cache_" + arch)
    libraries = os.path.join(folder, "libraries_" + arch)
    if os.path.isfile(cache):
        return cache
    if os.path.isdir(libraries):
        return libraries
    return None


def ladder(root, preferred=PREFERRED):
    """(release, arch, source) oldest first, the way dyld.held_ladder() walks it."""
    rungs = []
    if not os.path.isdir(root):
        return rungs
    for release in sorted(os.listdir(root)):
        if not re.fullmatch(r"\d+[\d.]*", release):
            continue
        folder = os.path.join(root, release)
        for arch in preferred:
            source = held_source(folder, arch)
            if source:
                rungs.append((release, arch, source))
                break
    rungs.sort(key=cmp_to_key(lambda a, b: compare(a[0], b[0])))
    return rungs


def key_of(source):
    """What the index depends on: the cache's own mtime and size. Both, because a copy that keeps
    only one of them goes unseen."""
    stat = os.stat(source)
    if os.path.isfile(source):
        return stat.st_mtime_ns, stat.st_size
    # A libraries folder has many files; the newest mtime and the total size change when any of them
    # does, and a file replaced with one of identical size and time is the one case this cannot see.
    newest, total = 0, 0
    for base, _, files in os.walk(source):
        for name in files:
            info = os.stat(os.path.join(base, name))
            newest = max(newest, info.st_mtime_ns)
            total += info.st_size
    return newest, total


def index_file(release):
    return os.path.join(index_dir(), release + ".names.gz")


def read_header(path):
    try:
        with gzip.open(path, "rt", encoding="utf-8", errors="surrogateescape") as handle:
            first = handle.readline()
    except OSError as error:
        print("build.py: %s does not read, so it will be rebuilt: %s" % (path, error))
        return None
    return dict(part.split("=", 1) for part in first.split() if "=" in part)


def is_current(release, arch, source):
    """Whether the index on disk was read from this source at this mtime and size AND is in the order
    the current format promises. A file of the right set in the old order is not current, and
    resorted() fixes it without reading a cache."""
    path = index_file(release)
    if not os.path.isfile(path):
        return False
    fields = read_header(path)
    if not fields or fields.get("format") != "2":
        return False
    if fields.get("arch") != arch:
        return False
    mtime, size = key_of(source)
    return (fields.get("mtime") == str(mtime) and fields.get("size") == str(size)
            and fields.get("source", "").endswith(os.path.basename(source)))


def resorted(release, arch, source):
    """Put an index that holds the right names in the current order, without reading a cache.

    The names are already measured -- that is what the mtime and size in the header say -- so only the
    ORDER is wrong, and re-reading 24.6 GB to fix a sort would be absurd. This rewrites the file
    byte-sorted and stamps the current format on it. It is not a rebuild and it does not claim to be
    one: the same names, in the order the format promises."""
    path = index_file(release)
    fields = read_header(path) or {}
    with gzip.open(path, "rb") as handle:
        handle.readline()
        names = {line.rstrip(b"\n") for line in handle if line.strip()}
    mtime, size = key_of(source)
    partial = path + ".partial"
    with gzip.open(partial, "wb", compresslevel=6) as out:
        out.write(HEADER.format(release=release, arch=arch, source=fields.get("source", source),
                                mtime=mtime, size=size, names=len(names)).encode("utf-8"))
        for name in sorted(names):
            out.write(name + b"\n")
    os.replace(partial, path)
    return len(names)


def build_one(release, arch, source, force=False):
    """Read one rung once and write its index. Returns (names, seconds) or None when it was current."""
    if not force and is_current(release, arch, source):
        return None
    if not force and os.path.isfile(index_file(release)):
        fields = read_header(index_file(release)) or {}
        if fields.get("mtime") == str(key_of(source)[0]) and fields.get("size") == str(key_of(source)[1]):
            # The cache has not moved, so the names are measured; only the order is out of date.
            count = resorted(release, arch, source)
            return count, 0.0
    # The key of this rung's cache: its mtime and size, the two things an index written from it
    # depends on. Taken here, once, for the header below.
    mtime, size = key_of(source)
    started = time.time()
    names = subprocess.run(
        ["xmake", "l", "tools/cache-index/names.lua", source, arch],
        stdout=subprocess.PIPE, check=True).stdout
    elapsed = time.time() - started
    text = names.decode("utf-8", "surrogateescape")
    # Split on the newline and NOTHING else. str.splitlines() also breaks on \v \f \x1c-\x1e
    # \x85 U+2028 and U+2029, and U+2028 is a legal character inside a C string that UTF-8 encodes,
    # so splitlines() tears one name into two entries and both are wrong. Measured on the armv7 cache
    # of 6.1.3: names.lua counts 568968 names and splitlines() wrote 568966.
    #
    # Sorted BY BYTES, which is the point of the line. sorted() on str sorts by code point, and for a
    # name that is not valid UTF-8 that is not the order of its bytes: b" \xc2\xa7" (valid UTF-8, one
    # character) sorted AFTER b" \xa0" (a lone raw byte, a surrogate once decoded), which is the
    # reverse of the order those bytes are in. The file then claimed to be "sorted" in an order only
    # this reader agreed with: 26573 of its names carry a non-ASCII character and 5311 a byte that is
    # not valid UTF-8 at all, and LC_ALL=C sort -c, a C bsearch or a grep pipeline would have read the
    # whole file as unsorted. Bytes have one order and the index is bytes.
    #
    # names.lua already sorted and deduplicated them (by byte, in Lua); sorting again is cheap next
    # to the read and makes the index correct even if that ever changes.
    lines = sorted({line for line in text.split("\n") if line},
                   key=lambda line: line.encode("utf-8", "surrogateescape"))
    os.makedirs(index_dir(), exist_ok=True)
    path = index_file(release)
    partial = path + ".partial"
    with gzip.open(partial, "wt", encoding="utf-8", errors="surrogateescape", compresslevel=6) as out:
        out.write(HEADER.format(release=release, arch=arch, source=source, mtime=mtime,
                                size=size, names=len(lines)))
        out.write("\n".join(lines))
        out.write("\n")
    # A reader beside a writer sees the old file or the new one, never half of one.
    os.replace(partial, path)
    return len(lines), elapsed


# How many name rows go in one gzip member. 500 answers, each decompressing one member of this many
# rows: the cost is one member's decompression, and BLOCK sets how big that is. 65536 rows is about
# half a megabyte uncompressed, so 9.2 million rows make about 140 members and an answer decompresses
# half a megabyte -- measured 0.09 s for 500 answers.
BLOCK = 65536



def merge(full_ladder):
    """Every name -> the FIRST held rung that carries it, written as blocked gzip members.

    The ladder's own order decides it, and a name a later rung has and an earlier one does not is
    answered by the earlier one: the port supports every rung, so the first is the release that must
    carry the API. A name only a later rung has is answered by that later rung, which is the case a
    release-split.lua run exists to catch.

    `full_ladder` is ALWAYS the whole held ladder, and never the `--only` subset, because a merged
    table over a subset is not a first-rung answer at all -- it is a first-rung answer over the rungs
    that happened to be on disk, with no way to tell from the file. Measured: `build.py --only 4.3`
    overwrote the table with 4.3's 317456 names, and the tool then answered _NSFileSize 3.0 (it is
    3.0's own, so that one survived) and UITextViewDidChangeSelectionNotification NONE, which no held
    release lacks. Both wrong, neither flagged, and a lookup cannot see that the file is a subset.

    So a missing rung is a refusal with the rung named, not a silent skip. The ladder's keys are the
    names, and a name keyed to the wrong rung is worse than no answer, because a caller cannot tell it
    apart from a real one."""
    first = {}
    missing = [release for release, _, _ in full_ladder
               if not os.path.isfile(index_file(release))]
    if missing:
        raise SystemExit("build.py: refusing to merge, %d of %d rung(s) have no index: %s\n"
                         "  build them first (build.py without --only), or the merged table would be a"
                         " first-rung answer over a subset and every name in it would be keyed to the"
                         " wrong rung." % (len(missing), len(full_ladder), ", ".join(missing)))
    for release, _, _ in full_ladder:
        path = index_file(release)
        with gzip.open(path, "rt", encoding="utf-8", errors="surrogateescape") as handle:
            handle.readline()
            for line in handle:
                name = line.rstrip("\n")
                if name and name not in first:
                    first[name] = release
    path = os.path.join(index_dir(), "first-rung.tsv.gz")
    partial = path + ".partial"
    index_partial = path + ".idx.partial"
    offsets, batch, first_name = [], [], None
    # One handle for the whole file, and a new GzipFile on it per member: GzipFile does not close a
    # fileobj it did not open, so each member's close() flushes that member and leaves the handle at
    # the next byte. That byte is the offset the index records.
    with open(partial, "wb") as raw:
        out = None
        # BYTES again, for the same reason as the per-release file, and it matters MORE here: this is
        # the table the lookup binary searches, so a code-point order under a byte search misplaces
        # exactly the names that are not valid UTF-8. Sorting the per-release files by byte and leaving
        # this one by code point gave 3855 of the 9256371 names unanswerable -- measured, and the
        # difference between the two orders is one comparison per name that is not valid UTF-8.
        for name in sorted(first, key=lambda n: n.encode("utf-8", "surrogateescape")):
            if not batch:
                first_name = name
                # The offset is taken BEFORE the member is written. raw.tell() after closing one is
                # the start of the NEXT member, so recording it there shifts every block by one and
                # first-rung.lua's get() then reads the wrong member for every name -- which it did,
                # answering NONE for names the self-test's own dict had just found.
                offset = raw.tell()
            batch.append("%s\t%s\n" % (name, first[name]))
            if len(batch) == BLOCK:
                out = gzip.GzipFile(fileobj=raw, mode="wb", compresslevel=6, mtime=0)
                out.write("".join(batch).encode("utf-8", "surrogateescape"))
                out.close()
                offsets.append((offset, first_name))
                batch = []
        if batch:
            out = gzip.GzipFile(fileobj=raw, mode="wb", compresslevel=6, mtime=0)
            out.write("".join(batch).encode("utf-8", "surrogateescape"))
            out.close()
            offsets.append((offset, first_name))
    with open(index_partial, "wt", encoding="utf-8", errors="surrogateescape") as out:
        for offset, name in offsets:
            out.write("%d\t%s\n" % (offset, name))
    os.replace(partial, path)
    os.replace(index_partial, path + ".idx")
    return len(first), os.path.getsize(path), len(offsets)


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--only", action="append", default=[],
                        help="one release to build, repeatable; default is every held release")
    parser.add_argument("--force", action="store_true",
                        help="rebuild even where the index is current (after changing names.lua)")
    parser.add_argument("--no-merge", action="store_true", help="do not rewrite first-rung.tsv.gz")
    args = parser.parse_args()

    root = os.path.join(os.getenv("CHARON_HOME") or os.path.join(os.getenv("HOME"), ".charon"), "dyld")
    every = ladder(root)
    rungs = every
    if args.only:
        wanted = set(args.only)
        rungs = [rung for rung in every if rung[0] in wanted]
        missing = wanted - {rung[0] for rung in rungs}
        if missing:
            sys.exit("build.py: no held release named %s" % ", ".join(sorted(missing)))
    if not every:
        sys.exit("build.py: %s holds no release this port has a cache of" % root)
    if not rungs:
        sys.exit("build.py: no held release named %s" % ", ".join(sorted(set(args.only))))

    # One process at a time, at the back of the queue, and the child with us: a build started from a
    # loaded session must not take the machine with it.
    os.nice(19)
    print("build.py: %d rung(s), index in %s" % (len(rungs), index_dir()))
    started = time.time()
    built, skipped, read, seconds = 0, 0, 0, 0.0
    for release, arch, source in rungs:
        result = build_one(release, arch, source, args.force)
        if result is None:
            skipped += 1
            print("  %-8s %-6s current" % (release, arch))
            continue
        count, took = result
        built += 1
        read += os.path.getsize(source) if os.path.isfile(source) else 0
        seconds += took
        print("  %-8s %-6s %8d names  %6.1fs  %5.0f MB"
              % (release, arch, count, took,
                 (os.path.getsize(source) / 1048576) if os.path.isfile(source) else 0))
        sys.stdout.flush()
    print("build.py: %d built, %d current, %.1fs of reading, %.1fs total"
          % (built, skipped, seconds, time.time() - started))
    if args.no_merge:
        return
    count, size, blocks = merge(every)
    print("build.py: first-rung.tsv.gz holds %d names in %d block(s), %.1f MB"
          % (count, blocks, size / 1048576))


if __name__ == "__main__":
    main()
