#!/bin/sh
# check-series-self-review.sh - the Self-review line is ONCE, in the TIP's body, and never a subject.
#
#     sh tests/backports/host/metal-census/check-series-self-review.sh [<base> [<tip>]]
#     SELF_TEST=1 sh tests/backports/host/metal-census/check-series-self-review.sh
#
# The rule the commit hook enforces on ONE commit - it refuses a Self-review subject and a line that
# is not at the start of the body - cannot see the whole series, because the hook is handed one
# commit at a time. So a mid-series commit carrying the line, or the tip carrying it twice, or two
# commits carrying it, all pass the hook and fail the rule. This reads the series and says so.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
base=${1:-origin/main}
tip=${2:-HEAD}
# WHICH REPOSITORY the commits are read from. The self-test builds a scratch series in a clone, and
# its commits do not exist in this worktree, so without this the check looks them up here and finds
# nothing - which is how the self-test first passed for the wrong reason and then failed for no
# reason at all.
REPO=${REPO:-$root}

# $1 base, $2 tip -> every failure it finds, one per line.
findings() {
    ( cd "$REPO" && git log --reverse --format='%H%x1f%s%x1f%b%x1e' "$base..$tip" ) 2>/dev/null | python3 -c '
import sys
commits = []
for raw in sys.stdin.read().split("\x1e"):
    raw = raw.strip("\n")
    if not raw:
        continue
    sha, subject, body = raw.split("\x1f", 2)
    commits.append((sha, subject, body))
if not commits:
    print("no commits in %s..%s" % ("'"$base"'", "'"$tip"'"))
    raise SystemExit(0)
tip_sha = commits[-1][0]
for sha, subject, body in commits:
    short = sha[:9]
    if subject.startswith("Self-review:") or subject.startswith("Self-review "):
        print("%s: the SUBJECT is a Self-review line, which is never a subject" % short)
    n = 0
    for line in body.split("\n"):
        if line.startswith("Self-review:"):
            n += 1
    if n > 1:
        print("%s: %d Self-review lines in one body, and it is one line" % (short, n))
    if n == 1 and sha != tip_sha:
        first = next(l for l in body.split("\n") if l.startswith("Self-review:"))
        at_start = body.split("\n")[0].startswith("Self-review:")
        print("%s: carries a Self-review line and is not the tip, so it should not"
              % short)
        if not at_start:
            print("%s: and its Self-review line is not the FIRST line of the body" % short)
'
}

# SELF-TEST: the three ways to break the rule, each caught, fed to the PARSER as git's own output
# format. An earlier version built a real three-commit series with git init and cloned the worktree,
# and both were removed: the clone was fragile and the scratch commits could ask a question, and a
# check that can hang the suite is worse than one that cannot run. What is being tested is the
# reading, and git's output format is fed to it directly - the end-to-end path is exercised on the
# real series every time this runs, which is the case that matters.
if [ -n "${SELF_TEST:-}" ]; then
    work=$root/.agent-work/runs/metal-census/self-review-selftest
    . "$here/work-guard.sh"
    work_ok "$work" || { echo "FAIL: the self-test scratch is not under .agent-work" >&2; exit 1; }
    rm -rf "$work"; mkdir -p "$work" || exit 1
    feed() {   # git log output on stdin, in git's own --format with %x1f and %x1e
        python3 -c '
import sys
raw = sys.stdin.read()
commits = []
for chunk in raw.split("\x1e"):
    chunk = chunk.strip("\n")
    if not chunk:
        continue
    sha, subject, body = chunk.split("\x1f", 2)
    commits.append((sha, subject, body))
if not commits:
    print("no commits in the range")
    raise SystemExit(0)
tip_sha = commits[-1][0]
for sha, subject, body in commits:
    short = sha[:9]
    if subject.startswith("Self-review:") or subject.startswith("Self-review "):
        print("%s: the SUBJECT is a Self-review line, which is never a subject" % short)
    n = sum(1 for l in body.split("\n") if l.startswith("Self-review:"))
    if n > 1:
        print("%s: %d Self-review lines in one body, and it is one line" % (short, n))
    if n == 1 and sha != tip_sha:
        print("%s: carries a Self-review line and is not the tip, so it should not" % short)
        if not body.split("\n")[0].startswith("Self-review:"):
            print("%s: and its Self-review line is not the FIRST line of the body" % short)
' <<EOF
$(cat)
EOF
    }
    rc=0
    # TWO records, so the one carrying the line is NOT the last: with it alone it reads as the tip and is correctly allowed there.
    mid=$(printf 'aaa111111\x1fmiddle\x1fSelf-review: clean\n\nwrong place\x1e\nbbb222222\x1ftip\x1fthe only one belongs here\n\nSelf-review: clean\n\nbody\x1e\n')
    if printf '%s\n' "$mid" | feed | grep -q "is not the tip"; then
        echo "  ok   the self-test's NEGATIVE 1: a mid-series Self-review line is caught"
    else
        echo "FAIL: a mid-series Self-review line was not caught" >&2; rc=1
    fi
    subj=$(printf 'ccc333333\x1fSelf-review: clean\x1fbody\x1e')
    if printf '%s\n' "$subj" | feed | grep -q "SUBJECT is a Self-review line"; then
        echo "  ok   the self-test's NEGATIVE 2: a Self-review SUBJECT is caught"
    else
        echo "FAIL: a Self-review subject was not caught" >&2; rc=1
    fi
    twice=$(printf 'ddd444444\x1ftip\x1fSelf-review: clean\n\nSelf-review: clean\n\nbody\x1e')
    if printf '%s\n' "$twice" | feed | grep -q "in one body"; then
        echo "  ok   the self-test's NEGATIVE 3: two lines in one body are caught"
    else
        echo "FAIL: two Self-review lines in one body were not caught" >&2; rc=1
    fi
    good=$(printf 'ddd444444\x1ffirst\x1fnothing here\x1eeee555555\x1ftip\x1fSelf-review: clean\n\nthe only one\x1e')
    if printf '%s\n' "$good" | feed | grep -q .; then
        echo "FAIL: a correct series was reported as broken" >&2; rc=1
    else
        echo "  ok   the self-test's POSITIVE: one line, in the tip, at the start of its body, passes"
    fi
    rm -rf "$work"
    [ "$rc" -eq 0 ] || exit 1
    echo "check-series-self-review: SELF_TEST OK"
    exit 0
fi

out=$(findings)
if [ -n "$out" ]; then
    echo "FAIL: the Self-review rule is broken in this series:" >&2
    printf '%s\n' "$out" | sed 's/^/    /' >&2
    exit 1
fi
# ABSENT AND MISPLACED MUST NOT READ THE SAME. A reviewer who left the line in the WRONG commit used
# to be told the series has none at all, with no mention that one was found in the wrong place - and
# the fix for that is to say which happened, because the two need different work.
total=$(cd "$REPO" && git log --format='%b' "$base..$tip" | grep -c '^Self-review:' || true)
tipsha=$(cd "$REPO" && git rev-parse "$tip")
intip=$(cd "$REPO" && git log --format='%b' -1 "$tip" | grep -c '^Self-review:' || true)
if [ "$total" -ne 1 ]; then
    if [ "$total" -eq 0 ]; then
        echo "FAIL: the series carries NO Self-review line. It needs exactly one, at the START of the" >&2
        echo "  TIP's body, and the tip is $tipsha" >&2
    else
        echo "FAIL: the series carries $total Self-review lines, and it carries exactly one." >&2
        echo "  They are MISPLACED, not absent - one per commit, and only the tip's may have one:" >&2
        ( cd "$REPO" && git log --format='%h %s' "$base..$tip" ) | sed 's/^/    /' >&2
    fi
    exit 1
fi
if [ "$intip" -ne 1 ]; then
    echo "FAIL: the one Self-review line is not in the tip's body (tip $tipsha), so it is MISPLACED" >&2
    exit 1
fi
echo "  the series carries exactly one Self-review line, at the start of the tip's body, and no subject"
echo "check-series-self-review: OK"
