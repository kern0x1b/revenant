#!/bin/sh
# run.sh - the 8.0 multi-pass writer input, Apple's own answers against the port's, joined row by row,
# with the mutations that must be noticed.
#
#     sh tests/backports/host/avf-writerinput8/run.sh                       the differential
#     AVFWMUTANT=<name> ... run.sh                                          a mutant, which must be noticed
#     AVFWMUTANT=<name> CONTROL=1 ... run.sh                                its control, which must be green
#
# ONE source, writer.m, compiled twice: once with the real <AVFoundation/AVFoundation.h> and this
# machine's own AVFoundation - the ORACLE, from which every expectation is read - and once with -I standin
# and the port's own packages/frameworks/apple-backports/AVFoundation/AVAssetWriterInputMultiPass8.m linked in
# UNMODIFIED, against a stand-in release shaped like the one the port runs on.
#
# The join is not "nothing differs". Every row falls into one of three classes:
#
#   must match   both halves answer it and they must agree. A difference is a failure unless ALLOWANCES
#                names it, and ALLOWANCES is a short list of differences in the PORT's build, each with
#                the measurement that explains it.
#   answers less the host answers it and the port does not. Always a failure.
#   row missing  one half printed a row the other did not. Always a failure: the sequence is one source,
#                so a row that is there on one side only is a difference in the run and not in the code.
#
# **Directionality.** The check is not "nothing differs" but "a mutation must turn a RIGHT answer wrong".
# A mutant run is judged against the port's own unmutated table and must show all three of: a row that
# CHANGED, a change on a row that was RIGHT (it matched the host before the mutation and does not after),
# and a red verdict overall. "RIGHT" is measured against the host table, so a mutation whose only effect is
# on a row that was already allowed to differ cannot be accepted by it - which is what the MOVED TOWARD HOST
# lines report when they appear, and they do appear: the `finalcall` mutation drops the port's invocation
# count from 2 to 1 on a switch-on row where the host's own answer is 1, so it agrees MORE closely with the
# host there while breaking five rows that matched. A control runs each mutant's UNMUTATED source through
# the identical build-and-run path and must stay green, so a red mutant is the mutation and not the path.
#
# The host table is built once and cached beside the build directory, which is removed on every run; a
# baseline that a run deletes is a baseline no mutant can be judged against.
#
# Not run through heavy.sh: it compiles four small files, links two binaries and runs them, and the
# fleet's heavy lane is for the gate.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
root=$(cd "$here/../../../.." && pwd)
port=$root/packages/frameworks/apple-backports/AVFoundation/AVAssetWriterInputMultiPass8.m
build=${AVFW_BUILD:-$(runs_folder avf-writerinput8)}
# BESIDE the build directory, not inside it.
oracle_dir=${AVFW_ORACLE:-$(runs_folder avf-writerinput8-oracle)}
rm -rf "$build"
mkdir -p "$build"

FLAGS="-fobjc-arc -w"

# ---- the six mutations. Each changes a line the join READS, and each names the rows it must break, so
#      "the mutant went red" and "the mutant broke the thing it aimed at" are one claim.
mutate() {
    runs_xmake l "$here/mutations.lua" "$1" "$2"
}

want=${AVFWMUTANT:-}
control=${CONTROL:-0}
case "$want" in
    beginpass|beginpass2) : ;;
esac

# ---- 1. the source, copied and mutated. The PORT's file is never edited in place.
mkdir -p "$build/src"
cp "$port" "$build/src/port.m"
if [ "$control" = 0 ] && [ -n "$want" ]; then
    case "$want" in
        beginpass)  mutate "$build/src/port.m" beginpass ;;
        ranges)     mutate "$build/src/port.m" ranges ;;
        finalcall)  mutate "$build/src/port.m" finalcall ;;
        forward)    mutate "$build/src/port.m" forward ;;
        setafter)   mutate "$build/src/port.m" setafter ;;
        exportafter) mutate "$build/src/port.m" exportafter ;;
        *)          echo "FAIL: no such mutant: $want"; exit 1 ;;
    esac
fi

# ---- 2. the PORT half: the stand-in release and the port's own object, both compiled against the
#         stand-in's header, then linked. A port object that referenced a member the release does not have
#         fails at THIS link and not before, which is the point of linking rather than copying.
# shellcheck disable=SC2086
xcrun clang $FLAGS -I "$here/standin" -c "$here/standin/standin.m" -o "$build/standin.o" \
    > "$build/standin.log" 2>&1 || { echo "RUN FAILED: the stand-in did not build"; head -8 "$build/standin.log"; exit 1; }
# shellcheck disable=SC2086
xcrun clang $FLAGS -I "$here/standin" -c "$build/src/port.m" -o "$build/port.o" \
    > "$build/port.log" 2>&1 || { echo "RUN FAILED: the port's own file did not build against the stand-in"; head -8 "$build/port.log"; exit 1; }
# shellcheck disable=SC2086
xcrun clang $FLAGS -I "$here/standin" -c "$here/writer.m" -o "$build/writer.o" \
    > "$build/writer.log" 2>&1 || { echo "RUN FAILED: writer.m did not build against the stand-in"; head -8 "$build/writer.log"; exit 1; }
# shellcheck disable=SC2086
xcrun clang $FLAGS "$build/writer.o" "$build/standin.o" "$build/port.o" \
    -framework Foundation -framework CoreMedia -o "$build/port" > "$build/link.log" 2>&1 || {
        echo "RUN FAILED: the port half did not link - the port reached a member the release does not have"
        head -8 "$build/link.log"; exit 1; }
set +e; "$build/port" > "$build/port.table" 2> "$build/port.stderr"; port_status=$?; set -e

# ---- 3. the HOST half, once. Built without -I standin, so <AVFoundation/AVFoundation.h> is the real one,
#         and linked against this machine's own AVFoundation. The BINARY and the TABLE are cached
#         separately and each is built when it is missing: a cached binary with no table (an interrupted
#         run, or an oracle directory handed to a fresh tree) used to be copied as a table that was not
#         there, and the join then read whatever was left.
if [ ! -x "$oracle_dir/host" ]; then
    mkdir -p "$oracle_dir"
    # shellcheck disable=SC2086
    xcrun clang $FLAGS "$here/writer.m" -framework Foundation -framework AVFoundation -framework CoreMedia \
        -o "$oracle_dir/host" > "$oracle_dir/build.log" 2>&1 || {
            echo "RUN FAILED: the host half did not build"; head -8 "$oracle_dir/build.log"; exit 1; }
fi
if [ ! -f "$oracle_dir/host.table" ]; then
    set +e; "$oracle_dir/host" > "$oracle_dir/host.table" 2> "$oracle_dir/host.stderr"; host_status=$?; set -e
    if [ "$host_status" != 0 ]; then
        echo "RUN FAILED: the host half exited $host_status, which is a control failing and not a result"
        exit 1
    fi
fi
# A TABLE THAT WAITED AND GOT NOTHING IS NOT CACHED, AND IS NOT USED. writer.m prints TIMED-OUT-<bound>
# instead of a count when the invocation AVAssetWriterInput.h:492 promises in response to
# -markCurrentPassAsFinished did not arrive inside the bound, and that marker says the run did not answer
# the question - it says the oracle could not. Caching such a table would repeat exactly the failure this
# rule exists for: the coordinator's gate read "currentPassDescription after markAsFinished host=[{0/1,0/0}]"
# and "markAsFinished after the final pass invocation host=[RAISED NSInternalInconsistencyException]" out of
# a table built once under load beside fifteen other tests, and every later run in that tree reported
# unexplained=2 while a fresh tree of the same commit answered unexplained=0 every time. So the table is
# named, deleted, and the run fails - and because the check sits HERE rather than inside the build, it
# also rejects a table that was already cached, which is the case that bit.
if grep -q 'TIMED-OUT' "$oracle_dir/host.table"; then
    echo "RUN FAILED: the host half did not settle, and its table is neither used nor cached. These rows"
    echo "      waited for an invocation the header promises and did not get it inside the bound:"
    grep 'TIMED-OUT' "$oracle_dir/host.table" | sed 's/^/      /'
    rm -f "$oracle_dir/host.table"
    echo "      Deleted, so the next run builds the oracle again from scratch rather than inherit it."
    exit 1
fi
cp "$oracle_dir/host.table" "$build/host.table"
host_status=0
[ -f "$oracle_dir/host.stderr" ] && cp "$oracle_dir/host.stderr" "$build/host.stderr"

# ---- 4. the baseline: the PORT's own table, written on an unmutated run and read by a mutant run.
if [ -z "$want" ] || [ "$control" != 0 ]; then
    mkdir -p "$oracle_dir"
    cp "$build/port.table" "$oracle_dir/port.baseline"
else
    [ -f "$oracle_dir/port.baseline" ] || {
        echo "FAIL: the mutant was asked for with no baseline beside it. Run this script once with no"
        echo "      AVFWMUTANT first: a mutant is judged against what the port answered unmutated."
        exit 1
    }
fi

# ---- 5. the join and the verdict
set +e
runs_xmake l "$here/join.lua" join "$build" "$oracle_dir"


join_status=$?
set -e

# ---- 6. the directionality assertion, and the control
if [ -n "$want" ] && [ "$control" = 0 ]; then
    set +e
    changed=$(runs_xmake l "$here/join.lua" direction "$build" "$oracle_dir")

    dir_status=$?
    set -e
    if [ "$dir_status" != 0 ]; then
        echo "FAIL: the $want mutation was NOT noticed in the required direction: it did not turn a"
        echo "      right answer wrong. A mutation that only moves the port AWAY from a row that already"
        echo "      differed is not a check; it needs a row that was RIGHT."
        echo "$changed"
        exit 1
    fi
    if [ "$join_status" = 0 ]; then
        echo "FAIL: the $want mutation changed a row that matched the host and the join stayed GREEN, so"
        echo "      nothing the check reads was wrong. A mutation must be noticed by the join too."
        exit 1
    fi
    echo "ok  the $want mutation was noticed, turned a right answer wrong, and the join went red:"
    echo "$changed" | grep -E '^(CHANGED|BROKE|MOVED)' | head -14
    echo "DIRECTIONALITY $(echo "$changed" | tail -1)"
    echo "log=$build"
    exit 0
fi

if [ -n "$want" ] && [ "$control" != 0 ]; then
    if [ "$join_status" != 0 ]; then
        echo "FAIL: the $want control is not green. The control runs the UNMUTATED source through the"
        echo "      identical build-and-run path, so a red here is the path, not the mutation."
        exit 1
    fi
    echo "ok  the $want control is green: the unmutated source through the same path"
    echo "log=$build"
    exit 0
fi

if [ "$port_status" != 0 ]; then
    echo "FAIL: the port half exited $port_status. Its rows are the port's, and a run that died half way"
    echo "      through prints a table that reads like a measurement and is not one."
    head -5 "$build/port.stderr" | sed 's/^/    /'
    exit 1
fi
if [ "$join_status" != 0 ]; then
    echo "FAIL: the differential is not green"
    exit 1
fi
echo "ok  every row Apple's own single-pass input answers is answered by the port, and what differs is"
echo "    one switch-on difference the port's own file writes down with the measurement behind it"
echo "log=$build"
