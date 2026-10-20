#!/bin/sh
# run.sh - the 11.0 sample-buffer render pair, Apple's own answers against the port's, joined row by row,
# with the mutations that must be noticed.
#
#     sh tests/backports/host/avf-samplerender11/run.sh                       the differential
#     AVFSRMUTANT=<name> ... run.sh                                          a mutant, which must be noticed
#     AVFSRMUTANT=<name> CONTROL=1 ... run.sh                                its control, which must be green
#
# ONE source, samplerender.m, compiled twice: once with the real <AVFoundation/AVFoundation.h> and this
# machine's own AVFoundation - the ORACLE, from which every expectation in the join is read - and once with
# -I standin and the port's own AVFoundation/AVSampleBufferRenderSynchronizer11.m,
# AVSampleBufferAudioRenderer11.m, AVSampleBufferRenderSynchronizer12.m, AVSampleBufferRenderSynchronizer14.m,
# AVFoundationConstants70.m and AVFoundationConstants110.m linked in UNMODIFIED, against a stand-in release
# shaped like the one the port runs on.
#
# The join is not "nothing differs". Every row falls into one of three classes:
#
#   must match   both halves answer it and they must agree. A difference is a failure unless ALLOWANCES
#                names it, and ALLOWANCES is a short list of differences in the PORT's build, each with the
#                measurement that explains it.
#   answers less the host answers it and the port does not. Always a failure.
#   row missing  one half printed a row the other did not. Always a failure: the sequence is one source, so
#                a row that is there on one side only is a difference in the run and not in the code.
#
# **Directionality.** The check is not "nothing differs" but "a mutation must turn a RIGHT answer wrong".
# A mutant run is judged against the port's own unmutated table and must show all three of: a row that
# CHANGED, a change on a row that was RIGHT (it matched the host before the mutation and does not after),
# and a red verdict overall. "RIGHT" is measured against the host table, so a mutation whose only effect is
# on a row that was already allowed to differ cannot be accepted by it. A control runs each mutant's
# UNMUTATED source through the identical build-and-run path and must stay green, so a red mutant is the
# mutation and not the path.
#
# The host table is built once and cached beside the build directory, which is removed on every run; a
# baseline that a run deletes is a baseline no mutant can be judged against.
#
# Twelve mutations, and one thing in the port's own code that deliberately has none. -addRenderer: sets the
# master relationship between the two clocks, and every rate or time change after that propagates the rate
# and the time to every attached renderer (which is what makes a renderer's clock read the synchronizer's),
# so removing the two lines in -addRenderer: changes nothing this check can see: the first rate change after
# the attach does the same work. The one row that reads the master relationship is the row the two halves
# deliberately differ on - this Mac's own renderer answers nil from CMTimebaseGetMasterTimebase for both
# clocks and keeps them in step by propagating instead - so no mutation of those two lines can turn a RIGHT
# answer wrong, and the `raterenderers` mutation covers what they do.
#
# **What this machine cannot answer, and what the run does about it.** CoreAudio reports the hardware not
# running here ('who?' for kAudioHardwarePropertyDevices) and AudioQueueNewOutput fails, so no audio
# reaches an output on this machine - and this machine's own renderer stalls on the first buffer it is
# given and then ABORTS on a flush, a rate change or a release. The run therefore asks the flush rows and
# the rate-change rows of renderers that hold no media at all, which is askable, and the rows that a
# stalled renderer would answer are the ALLOWANCES below. Every measurement behind that is in
# packages/frameworks/apple-backports/facts/AVFoundation/SampleBufferRender11.md.
#
# Not run through heavy.sh: it compiles six small files, links two binaries and runs them, and the fleet's
# heavy lane is for the gate.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
root=$(cd "$here/../../../.." && pwd)
port=$root/packages/frameworks/apple-backports/AVFoundation
build=${AVFSR_BUILD:-$(runs_folder avf-samplerender11)}
# BESIDE the build directory, not inside it.
oracle_dir=${AVFSR_ORACLE:-$(runs_folder avf-samplerender11-oracle)}
rm -rf "$build"
mkdir -p "$build"

FLAGS="-fobjc-arc -w"

# ---- the mutations. Each changes a line the join READS, and each names the rows it must break, so "the
#      mutant went red" and "the mutant broke the thing it aimed at" are one claim.
mutate() {
    runs_xmake l "$here/mutations.lua" "$1" "$2"
}

want=${AVFSRMUTANT:-}
control=${CONTROL:-0}

# ---- 1. the sources, copied and mutated. The PORT's files are never edited in place.
mkdir -p "$build/src"
cp "$port/AVSampleBufferRenderSynchronizer11.m" "$build/src/synchronizer.m"
cp "$port/AVSampleBufferAudioRenderer11.m" "$build/src/renderer.m"
cp "$port/AVSampleBufferRenderSynchronizer12.m" "$build/src/currenttime.m"
cp "$port/AVSampleBufferRenderSynchronizer14.m" "$build/src/anchor.m"
if [ "$control" = 0 ] && [ -n "$want" ]; then
    case "$want" in
        rate|detachclock|raterenderers) mutate "$build/src/synchronizer.m" "$want" ;;
        boundarypast|emptytimes|removeobserver) mutate "$build/src/synchronizer.m" "$want" ;;
        flushstatus|readiness|volume|nodynamic) mutate "$build/src/renderer.m" "$want" ;;
        periodicinterval) mutate "$build/src/synchronizer.m" "$want" ;;
        addtwice) mutate "$build/src/synchronizer.m" "$want" ;;
        *)          echo "FAIL: no such mutant: $want"; exit 1 ;;
    esac
fi

# ---- 2. the PORT half: the stand-in release and the port's own objects, both compiled against the
#         stand-in's header, then linked. A port object that referenced a member the release does not have
#         fails at THIS link and not before, which is the point of linking rather than copying.
for object in standin synchronizer renderer currenttime anchor; do
    case "$object" in
        standin) source="$here/standin/standin.m" ;;
        *) source="$build/src/$object.m" ;;
    esac
    # The port's own private header travels with them: -I the port's own AVFoundation folder is what a
    # client of the port compiles against.
    # shellcheck disable=SC2086
    xcrun clang $FLAGS -I "$here/standin" -I "$port" -c "$source" -o "$build/$object.o" \
        > "$build/$object.log" 2>&1 || { echo "RUN FAILED: $object did not build against the stand-in"; head -8 "$build/$object.log"; exit 1; }
done
# The port's own constant objects, for the two values the harness reads back through the class under test
# and the notification the rate change posts. They are the port's, at 7.0 and 11.0, and they are linked
# unmodified against the same stand-in.
for source in AVFoundationConstants70 AVFoundationConstants110; do
    # shellcheck disable=SC2086
    xcrun clang $FLAGS -I "$here/standin" -I "$port" -c "$port/$source.m" -o "$build/$source.o" \
        > "$build/$source.log" 2>&1 || { echo "RUN FAILED: $source did not build against the stand-in"; head -8 "$build/$source.log"; exit 1; }
done
# shellcheck disable=SC2086
xcrun clang $FLAGS -I "$here/standin" -c "$here/samplerender.m" -o "$build/samplerender.o" \
    > "$build/samplerender.log" 2>&1 || { echo "RUN FAILED: samplerender.m did not build against the stand-in"; head -8 "$build/samplerender.log"; exit 1; }
# shellcheck disable=SC2086
xcrun clang $FLAGS "$build/samplerender.o" "$build/standin.o" "$build/synchronizer.o" "$build/renderer.o" \
    "$build/currenttime.o" "$build/anchor.o" "$build/AVFoundationConstants70.o" "$build/AVFoundationConstants110.o" \
    -framework Foundation -framework CoreMedia -framework AudioToolbox -o "$build/port" > "$build/link.log" 2>&1 || {
        echo "RUN FAILED: the port half did not link - the port reached a member the release does not have"
        head -8 "$build/link.log"; exit 1; }
set +e; "$build/port" > "$build/port.table" 2> "$build/port.stderr"; port_status=$?; set -e

# ---- 3. the HOST half, once. Built without -I standin, so <AVFoundation/AVFoundation.h> is the real one,
#         and linked against this machine's own AVFoundation.
if [ ! -x "$oracle_dir/host" ]; then
    mkdir -p "$oracle_dir"
    # shellcheck disable=SC2086
    xcrun clang $FLAGS "$here/samplerender.m" -framework Foundation -framework AVFoundation -framework CoreMedia -framework AudioToolbox \
        -o "$oracle_dir/host" > "$oracle_dir/build.log" 2>&1 || {
            echo "RUN FAILED: the host half did not build"; head -8 "$oracle_dir/build.log"; exit 1; }
    set +e; "$oracle_dir/host" > "$oracle_dir/host.table" 2> "$oracle_dir/host.stderr"; host_status=$?; set -e
    if [ "$host_status" != 0 ]; then
        echo "RUN FAILED: the host half exited $host_status, which is a control failing and not a result"
        exit 1
    fi
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
        echo "      AVFSRMUTANT first: a mutant is judged against what the port answered unmutated."
        exit 1
    }
fi

# ---- 5. the join, and the value every row must answer
set +e
runs_xmake l "$here/join.lua" join "$build" "$oracle_dir" > "$build/join.log" 2>&1


join_status=$?
cat "$build/join.log"
set -e

# ---- 6. the directionality assertion, and the control
if [ -n "$want" ] && [ "$control" = 0 ]; then
    set +e
    changed=$(runs_xmake l "$here/join.lua" direction "$build" "$oracle_dir")
    dir_status=$?
    set -e
    if [ "$dir_status" != 0 ]; then
        echo "FAIL: the $want mutation was NOT noticed in the required direction: it did not turn a"
        echo "      required answer wrong. A mutation that only moves the port AWAY from a row that already"
        echo "      differed is not a check; it needs a row the join says the port must answer."
        echo "$changed"
        exit 1
    fi
    if [ "$join_status" = 0 ]; then
        echo "FAIL: the $want mutation changed a row the join requires and the join stayed GREEN, so"
        echo "      nothing the check reads was wrong. A mutation must be noticed by the join too."
        exit 1
    fi
    echo "ok  the $want mutation was noticed, turned a required answer wrong, and the join went red:"
    echo "$changed" | grep -E '^(CHANGED|BROKE|MOVED)' | head -14
    echo "$(echo "$changed" | tail -1)"
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
allowed=$(grep -c '^ALLOWED' "$build"/join.log 2>/dev/null || echo "")
echo "ok  every row both halves answer is answered the same, apart from the $(grep -oE 'allowed-differences=[0-9]+' "$build/join.log" | head -1 | cut -d= -f2) this check names, and each of them carries"
echo "    the value the port is required to answer and the measurement behind it"
echo "log=$build"
