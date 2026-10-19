#!/usr/bin/env python3
"""How far the engine tree has moved from its upstream base.

    scripts/port-delta.py [base]
    scripts/port-delta.py --freshness [base]
    scripts/port-delta.py --unguarded [area] [base]

LIMIT caps the --unguarded list (default 40).
"""
import argparse
import os
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT / "webkit-254"
DEFAULT_BASES = ("upstream/webkitglib/2.54", "origin/webkitglib/2.54")
SOURCE_FILE = re.compile(r"Source/.*\.(cpp|h|mm)")
COMMITS_LOOKED_AT = 200
WIDTH = 72


def warn(message):
    print("port-delta: " + message, file=sys.stderr)


def git(*args, check=True):
    result = subprocess.run(["git", "-C", str(ENGINE), *args],
                            check=check, capture_output=True, text=True, errors="replace")
    return result.stdout


def is_revision(ref):
    try:
        git("rev-parse", "--verify", "-q", ref)
    except subprocess.CalledProcessError:
        return False
    return True


def files_mentioning(pattern, area):
    try:
        return set(git("grep", "-l", pattern, "--", area).splitlines())
    except subprocess.CalledProcessError as error:
        if error.returncode == 1:
            return set()
        raise


def line_count(field):
    return int(field) if field.isdigit() else 0


def numstat(*args):
    entries = iter(git("diff", "--numstat", "-z", *args).split("\0"))
    for entry in entries:
        if not entry:
            continue
        added, deleted, path = entry.split("\t", 2)
        if not path:
            _, path = next(entries), next(entries)
        yield path, line_count(added), line_count(deleted)


def area_of(path):
    parts = path.split("/") + [""]
    return parts[0] + "/" + parts[1]


def one_line(text):
    return text.rstrip("\n")[:WIDTH]


def report_unguarded(area, base, limit):
    print("changed files under {} that carry no WEBKIT_IOS6 guard, largest first".format(area))
    print("  these are the ones a conflict here has to be read by hand")
    guarded = files_mentioning("WEBKIT_IOS6", area)
    rows = [(added + deleted, path) for path, added, deleted in numstat(base, "HEAD", "--", area)
            if path not in guarded]
    for total, path in sorted(rows, reverse=True)[:limit]:
        print("{}\t{}".format(total, path))


def first_added_line(patch):
    for line in patch.split("\n"):
        if line.startswith("+") and not line.startswith("+++") and line[1:].strip():
            return line[1:]
    return None


def find_boundary(base):
    for commit in git("log", "--format=%H", "-n", str(COMMITS_LOOKED_AT), base).split():
        names = git("show", "--name-only", "--format=", commit).splitlines()
        source = next((name for name in names if SOURCE_FILE.fullmatch(name)), None)
        if source is None or not (ENGINE / source).is_file():
            continue
        added = first_added_line(git("show", commit, "--", source))
        if added is None:
            continue
        try:
            if added in (ENGINE / source).read_text(errors="replace"):
                return commit
        except OSError:
            continue
    return None


def report_freshness(base):
    print("how fresh the snapshot is, against " + base)
    print("  branch tip: " + one_line(git("log", "-1", "--format=%ad  %s", "--date=short", base)))
    boundary = find_boundary(base)
    if boundary is None:
        print("  nothing on the branch matched - the snapshot is older than the {} commits looked at"
              .format(COMMITS_LOOKED_AT))
        return
    print("  we carry:   " + one_line(git("log", "-1", "--format=%ad  %h  %s", "--date=short", boundary)))
    print("  behind by:  {} commits".format(git("rev-list", "--count", boundary + ".." + base).strip()))


def report_size(base):
    span = base + "..HEAD"
    print("port delta against " + base)
    print(git("diff", "--shortstat", span))

    print("by area:")
    added, deleted, files = Counter(), Counter(), Counter()
    for path, plus, minus in numstat(span):
        area = area_of(path)
        added[area] += plus
        deleted[area] += minus
        files[area] += 1
    for area in sorted(files, key=lambda area: (files[area], area), reverse=True)[:12]:
        print("  {:<34} {:>5} files  +{:<7} -{}".format(area, files[area], added[area], deleted[area]))
    print()

    print("kind of change:")
    kinds = Counter(line.split("\t")[0] for line in git("diff", "--name-status", span).splitlines())
    print("  {} modified, {} added, {} deleted".format(kinds["M"], kinds["A"], kinds["D"]))

    changed = set(git("diff", "--name-only", span, "--", "Source").splitlines())
    guarded = files_mentioning("defined(WEBKIT_IOS6)", "Source")
    bare = changed - guarded
    print()
    print("how much of it announces itself:")
    print("  {:>5} files changed under Source".format(len(changed)))
    print("  {:>5} of them carry the WEBKIT_IOS6 guard".format(len(changed & guarded)))
    print("  {:>5} do not - these are the ones a re-graft has to be careful with".format(len(bare)))
    print()
    print("  the unguarded ones, by area:")
    by_area = Counter(area_of(path) for path in bare)
    for area, count in sorted(by_area.items(), key=lambda item: (item[1], item[0]), reverse=True)[:8]:
        print("    {:<32} {}".format(area, count))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--freshness", action="store_true",
                      help="find the newest base commit whose content the tree carries")
    mode.add_argument("--unguarded", nargs="?", const="Source", metavar="AREA",
                      help="list changed files under AREA (default Source) without a WEBKIT_IOS6 guard")
    parser.add_argument("base", nargs="?", help="upstream base, default {} or else {}".format(*DEFAULT_BASES))
    args = parser.parse_args()

    base = args.base or next((ref for ref in DEFAULT_BASES if is_revision(ref)), DEFAULT_BASES[-1])
    if not is_revision(base):
        warn("no such ref: {} (fetch it first)".format(base))
        return 1

    try:
        if args.unguarded is not None:
            try:
                limit = int(os.environ.get("LIMIT") or 40)
            except ValueError:
                limit = 0
            if limit <= 0:
                warn("LIMIT has to be a positive number of lines, not {!r}".format(os.environ["LIMIT"]))
                return 1
            report_unguarded(args.unguarded, base, limit)
        elif args.freshness:
            report_freshness(base)
        else:
            report_size(base)
    except subprocess.CalledProcessError as error:
        warn("{} failed: {}".format(" ".join(error.cmd[3:]), error.stderr.strip()))
        return error.returncode
    return 0


if __name__ == "__main__":
    sys.exit(main())
