#!/usr/bin/env python3
"""List files whose port adaptations thinned out against a reference branch.

    scripts/carry-audit.py [ref] [path ...]
    scripts/carry-audit.py --stale [base] [path ...]

The count of port markers per file is compared with the same file on the
reference branch; --stale instead lists the files that still carry the content
of the graft base, which are the ones an update left behind entirely.

A file that carries fewer markers than the reference is either an upstream
refactor or a carry that was dropped when the file was taken from trunk, and
every one of them is worth reading before a release.
"""
import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT / "webkit-254"
MARKERS = re.compile(r"WEBKIT_IOS6|USE\(JSVALUE64\)|JSVALUE32_64|CPU\(ARM_THUMB2\)|payloadGPR|tagGPR")
SOURCE_SUFFIXES = (".cpp", ".h", ".mm", ".m", ".asm")
OBJECT_ID = re.compile(r"[0-9a-f]+")
MARKER_PATHS = ["Source/WebCore", "Source/WebKitLegacy", "Source/JavaScriptCore", "Source/WTF"]
STALE_PATHS = ["Source/JavaScriptCore", "Source/WTF", "Source/WebCore", "Source/WebKitLegacy"]
UPSTREAM = "upstream/main"


def warn(message):
    print("carry-audit: " + message, file=sys.stderr)


def git(*args, check=True, stdin=None):
    result = subprocess.run(["git", "-C", str(ENGINE), *args], input=stdin,
                            check=check, capture_output=True, text=True, errors="replace")
    return result.stdout


def require_revision(revision):
    try:
        git("rev-parse", "--verify", "-q", revision + "^{commit}")
    except subprocess.CalledProcessError:
        warn("{} is not a revision in {}, so nothing can be compared with it".format(revision, ENGINE))


def count_markers(text):
    return sum(1 for line in text.split("\n") if MARKERS.search(line))


class BlobReader:
    def __init__(self):
        self.process = subprocess.Popen(["git", "-C", str(ENGINE), "cat-file", "--batch"],
                                        stdin=subprocess.PIPE, stdout=subprocess.PIPE)

    def __enter__(self):
        return self

    def __exit__(self, *exc_info):
        self.process.stdin.close()
        self.process.wait()

    def read(self, name):
        self.process.stdin.write(name.encode() + b"\n")
        self.process.stdin.flush()
        header = self.process.stdout.readline().split()
        if len(header) != 3 or not header[2].isdigit():
            return ""
        blob = self.process.stdout.read(int(header[2]) + 1)
        return blob[:-1].decode(errors="replace")


def object_ids(revision, paths):
    request = "".join("{}:{}\n".format(revision, path) for path in paths)
    answers = git("cat-file", "--batch-check=%(objectname)", stdin=request, check=False).splitlines()
    return [answer if OBJECT_ID.fullmatch(answer) else None for answer in answers]


def list_stale(base, paths):
    require_revision(base)
    require_revision(UPSTREAM)
    files = [path for path in git("ls-files", "--", *paths, check=False).splitlines()
             if (ENGINE / path).is_file()]
    stale = [path for path, ours, theirs, upstream
             in zip(files, object_ids("HEAD", files), object_ids(base, files), object_ids(UPSTREAM, files))
             if ours and theirs and upstream and ours == theirs != upstream]
    for path in stale:
        print(path)
    print("{} files the port never touched and the merge never moved".format(len(stale)))


def list_thinned(ref, paths):
    require_revision(ref)
    sources = [path for path in git("ls-tree", "-r", "--name-only", ref, "--", *paths, check=False).splitlines()
               if path.endswith(SOURCE_SUFFIXES)]
    gaps = 0
    with BlobReader() as blobs:
        for path in sources:
            local = ENGINE / path
            if not local.is_file():
                continue
            there = count_markers(blobs.read("{}:{}".format(ref, path)))
            if there == 0:
                continue
            try:
                here = count_markers(local.read_text(errors="replace"))
            except OSError as error:
                warn("cannot read {}: {}".format(local, error.strerror))
                continue
            if here < there:
                print("{:<4} {} ({} has {}, here {})".format("-{}".format(there - here), path, ref, there, here))
                gaps += 1
    print("{} files carry fewer markers than {}".format(gaps, ref))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--stale", action="store_true",
                        help="list the files that still match the graft base")
    parser.add_argument("ref", nargs="?", help="reference branch (default main), or with --stale "
                                               "the graft base (default 1b78c03f880e)")
    parser.add_argument("paths", nargs="*", help="engine paths to look under")
    args = parser.parse_args()

    if not ENGINE.is_dir():
        warn("there is no engine tree at {}".format(ENGINE))
        return 2
    if args.stale:
        list_stale(args.ref or "1b78c03f880e", args.paths or STALE_PATHS)
    else:
        list_thinned(args.ref or "main", args.paths or MARKER_PATHS)
    return 0


if __name__ == "__main__":
    sys.exit(main())
