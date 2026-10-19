#!/bin/sh
# run-collection.sh — the collection factories' count table, on the port, real and mutated.
#
# The same table the host run prints (tests/backports/callgen/collection-test.sh, macOS 26's own
# Intents as the oracle), read out of a 6.1.3 emulator running libIntentsBackports. The device is
# iPhone3,1, the 3GS, which runs 6.1.3, and the invocation is the tree's own:
#
#     xmake emulate -d <device> -r <release> install
#     xmake emulate -d <device> -r <release> run /usr/libexec/<program> <argument>
#
# The mutant half swaps the generated factory's source for one that returns an element fewer,
# rebuilds - which the package's own `sources` digest notices, because that digest covers the file
# and is the reason the objects are compiled again - and runs the same program. The file is put
# back and the library is rebuilt from it, and `git status` is checked, so the tree and the store
# are both the real ones when the run ends.
#
# Each build is run twice: once with a label, which prints the whole table for a reader, and once
# with "counts", which prints the numbers alone. The two guards below compare the **.counts** files
# and not the transcripts, because the program writes the label it was given into the first line:
# the first version of this compared whole transcripts, so the mutation guard read the label instead
# of the table and could not fail, and the restore guard read the same label and always fired, so
# no run of it could finish. "counts" is the argument the host half already takes
# (tests/backports/callgen/collection-test.m), and the .counts files are what collection-test.sh
# compares, so both halves of the measurement answer in the same shape.
#
# A run has to end in two ways to be believed: it must print the table and it must exit 0. A run
# that printed a whole table and then exited non-zero says its table and disagrees with it, and the
# transcript cannot tell which is true, so the status is kept and a non-zero one stops the script
# where the run is named. (That check is the one thing series A's copy of this file had and this
# one did not; the guards below are the ones it did not have.)
#
# The port is configured ONCE, before the first build, and the second and third build reuse it:
# nothing in the configuration changes between them, only Intents/IN16_0.m, and the package's own
# `sources` digest already notices that file. `xmake f -c` is not repeated because -c clears the
# configuration and re-resolves and reinstalls the whole dependency chain, measured at 53 minutes
# holding the shared store's locks, which is three times over for one measurement.
#
# Three heavy jobs, so run it in a slot of the machine:
#     $HOME/Git/projects/ios/coordination/heavy.sh sh tests/backports/emulate/calls/run-collection.sh
# The emulator run itself is the coordinator's to gate; nothing here has been run on a device.
#
# Usage: sh tests/backports/emulate/calls/run-collection.sh [--device iPhone3,1] [--release 6.1.3]
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
device=${COLLECTION_DEVICE:-iPhone3,1}
release=${COLLECTION_RELEASE:-6.1.3}
work=${COLLECTION_WORK:-$here/.agent-work/collection}
intents=$root/packages/a/apple-backports/Intents/IN16_0.m
mkdir -p "$work"
cp "$intents" "$work/IN16_0.real.m"

restore() {
    if [ -f "$work/IN16_0.real.m" ]; then
        cp "$work/IN16_0.real.m" "$intents"
    fi
}
trap restore EXIT INT TERM

configure() {
    ( cd "$here" \
      && CHARCALLS_ROOT=$root CHARCALLS_MINIMUM=$release xmake f -c -p iphoneos -a armv7 -y \
         > "$work/configure.log" 2>&1 ) || {
        echo "the port did not configure; $work/configure.log says why" >&2
        tail -15 "$work/configure.log" 2>/dev/null >&2
        exit 1
    }
}

build() {
    label=$1
    ( cd "$here" \
      && CHARCALLS_ROOT=$root CHARCALLS_MINIMUM=$release xmake build -y charoncollection \
         > "$work/build-$label.log" 2>&1 \
      && xmake emulate -d "$device" -r "$release" install > "$work/install-$label.log" 2>&1 ) || {
        echo "$label: build or install failed; $work/*-$label.log says why" >&2
        tail -15 "$work/build-$label.log" "$work/install-$label.log" 2>/dev/null >&2
        exit 1
    }
}

run() {
    label=$1
    # From the port's own directory: xmake has to find the port's xmake.lua, and the first
    # version of this ran from the repository root, where there is none - so the run prompted for
    # a confirmation instead of running and the file it left was the prompt.
    # The status is kept of both runs, and the escapes come off a copy, so what the guards compare
    # is the program's own text.
    status=0
    ( cd "$here" \
      && xmake emulate -d "$device" -r "$release" run /usr/libexec/charoncollection \
            "the port's own body ($label)" ) > "$work/$label.raw" 2>&1 || status=$?
    counts_status=0
    ( cd "$here" \
      && xmake emulate -d "$device" -r "$release" run /usr/libexec/charoncollection counts ) \
        > "$work/$label.counts.raw" 2>&1 || counts_status=$?
    sed 's/\x1b\[[0-9;]*m//g' "$work/$label.raw" > "$work/$label.txt"
    sed 's/\x1b\[[0-9;]*m//g' "$work/$label.counts.raw" > "$work/$label.counts.all"
    if [ "$status" -ne 0 ] || [ "$counts_status" -ne 0 ]; then
        echo "$label: the run exited $status and the counts run $counts_status; $work/$label.txt says what came back" >&2
        tail -15 "$work/$label.txt" >&2
        exit 1
    fi
    # A run that printed no count line at all would leave an empty .counts file, and an empty file
    # compares equal to another empty one: the mutation guard would then pass on nothing.
    if ! grep -aE "^  [A-Z].*count=" "$work/$label.counts.all" > "$work/$label.counts"; then
        echo "FAIL: the $label run printed no count table; $work/$label.txt says why" >&2
        exit 1
    fi
    grep -aE "^  [A-Z].*count=" "$work/$label.txt" \
        || echo "$label: no count line in the transcript; $work/$label.txt is what came back" >&2
}

echo "=== the port's own body, on $device at $release"
configure
build real
run real

echo "=== the mutant: one element fewer than the host's answer"
python3 "$root/tests/backports/callgen/collection-mutant.py" "$intents" "$work/IN16_0.mutant.m" >/dev/null
cp "$work/IN16_0.mutant.m" "$intents"
build mutant
run mutant

echo "=== putting the real factory back and rebuilding the library from it"
restore
build restored
run restored

echo "--- the tree: $(cd "$root" && git status --short -- packages/a/apple-backports/Intents/IN16_0.m | wc -l) changed file(s) in the factory"
echo "--- the tables are in $work/real.txt, $work/mutant.txt and $work/restored.txt"
echo "--- the counts the two guards compare are in $work/real.counts, $work/mutant.counts and $work/restored.counts"
if cmp -s "$work/real.counts" "$work/mutant.counts"; then
    echo "FAIL: the mutation did not change the count table on the device"
    diff -u "$work/real.counts" "$work/mutant.counts" || true
    exit 1
fi
if ! cmp -s "$work/real.counts" "$work/restored.counts"; then
    echo "FAIL: the restored factory does not answer as the real one did"
    diff -u "$work/real.counts" "$work/restored.counts" || true
    exit 1
fi
echo "the mutation turns the table red on the device, and the restored factory answers as it did:"
diff -u "$work/real.counts" "$work/mutant.counts" || true
