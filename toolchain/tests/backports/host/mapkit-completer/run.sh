#!/bin/sh
# The completer's delegate, compared against the HOST's own MKLocalSearchCompleter: the calls, their
# order and their values, for the same query and the same delegate.
#
# The port's completer is built here as a macOS dylib with its class renamed, because the class name is
# Apple's and only a rename lets both answer the same query in one probe. Apple's own is reached
# through the unrenamed name.
#
# THE MUTANT is a second build of the same source with -DREVENANT_DELEGATE_MUTANT, where the port's
# completer hands the delegate the wrong argument. Everything else is identical, so a mutant that does
# not go red means the comparison cannot see a wrong argument -- and the probe says so and fails,
# because a green mutant is a comparison that decides nothing.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
port=${PORT:-$here/../../../../packages/frameworks/apple-backports/MapKit}
build=${MAPKIT_COMPLETER_BUILD:-$(runs_folder revenant-mapkit-completer)}
query="a place that does not exist anywhere at all zzzzqqq"
rm -rf "$build"
mkdir -p "$build"
# CATALYST, because the port's own completer imports UIKit and macOS has no UIKit outside a Catalyst
# build. This is the shape the repository's other UIKit-touching host probes use, and MapKit on a
# Catalyst build is Apple's own MapKit, so the oracle is still Apple's framework.
MACOSX_SDK=$(xcrun --sdk macosx --show-sdk-path)
# The Catalyst build also needs the iOSSupport sub-SDK on the include path, because macOS's own
# MapKit headers include UIKit/UIImage.h. Without it the port's completer cannot be built for the
# host at all, which was the first thing this probe found.
TARGET="-target arm64-apple-ios17.0-macabi -isysroot $MACOSX_SDK -isystem $MACOSX_SDK/System/iOSSupport/usr/include -F $MACOSX_SDK/System/iOSSupport/System/Library/Frameworks"
# REVENANT_HOST_PROBE: the host's own MapKit declares the names the port also declares.
# And ONLY the completer and its protocol are renamed: those are the two classes the PORT defines.
# MKLocalSearchRequest and MKLocalSearchCompletion are real on the host, so the port's code uses the
# host's own and renaming them away only left the linker looking for classes nobody has.
build_port() {
    out=$1
    shift
    xcrun clang -fobjc-arc -Wall -fPIC -dynamiclib $TARGET -DREVENANT_HOST_PROBE=1 "$@" \
        -DMKLocalSearchCompleter=revenantHost_MKLocalSearchCompleter \
        -DMKLocalSearchCompleterDelegate=revenantHost_MKLocalSearchCompleterDelegate \
        -I"$port" -framework Foundation -framework MapKit -framework CoreLocation -framework UIKit \
        "$port/MKLocalSearchCompleter.m" "$port/MKLocalSearchRequest13.m" "$@" \
        -o "$out" 2> "$build/cc.log" || { grep -m5 ': error:' "$build/cc.log" || true; exit 1; }
}
build_port "$build/libport.dylib"
# The mutant is the SAME dylib: the runner allocates a subclass at run time whose dispatch passes the
# wrong argument, so the port's source is byte-identical in both runs and the only difference between
# them is that argument. One dylib, two behaviours.
: "$build/libmutant.dylib"
xcrun clang -fobjc-arc -Wall $TARGET -framework Foundation -framework MapKit -framework UIKit \
    -framework CoreLocation "$here/runner.m" -o "$build/runner" 2> "$build/runner.log" || {
        grep -m5 ': error:' "$build/runner.log" || true; exit 1; }

transcript() {
    "$build/runner" "$1" "$query" > "$2" 2>&1 && true
}
transcript host "$build/host.txt"
REVENANT_PORT_DYLIB="$build/libport.dylib" transcript port "$build/port.txt"
REVENANT_PORT_DYLIB="$build/libport.dylib" REVENANT_MUTANT=1 transcript port "$build/mutant.txt"

# The two transcripts, with the first line's own identity removed so the comparison is about the
# CALLS and not about which image each came from.
# The transcript's case lines, with the build's own header dropped and the per-line "# N call(s)"
# echo dropped. EVERY STEP TOLERATES AN EMPTY RESULT, with || true, and that is the fix for a silent
# death: a grep that selects nothing exits 1, the script runs under `set -e`, and the whole run ends
# there with no FAIL line and no output at all. A mutant that records nothing is a FINDING -- it
# means the mutant silenced the thing it was built to exercise -- and a finding has to be printed.
# The transcript's case lines, with the build's own header dropped and the per-call echo dropped.
# Two things here are fixes rather than cosmetics:
#   * the "revenantHost_" the -D renames put into a class NAME is a build artefact, not a behaviour,
#     so it is normalised away -- otherwise the port's own class can never equal the host's;
#   * EVERY STEP TOLERATES AN EMPTY RESULT, with || true. A grep that selects nothing exits 1, the
#     script runs under `set -e`, and the run ends there with no FAIL and no output at all. A mutant
#     that records nothing is a FINDING -- it silenced the thing it was built to exercise -- and a
#     finding has to be printed, not swallowed.
strip() {
    sed 's/revenantHost_//g; 1d' "$1" |
        { grep -E '^  (call|transcript|#)' || true; } |
        sed 's/^  //' |
        { grep -v '^# [0-9]* call' || true; }
}
strip "$build/host.txt" > "$build/host.body"
strip "$build/port.txt" > "$build/port.body"
strip "$build/mutant.txt" > "$build/mutant.body"

cat "$build/host.txt"; cat "$build/port.txt"
for who in host port mutant; do
    if [ ! -s "$build/$who.body" ]; then
        echo "FAIL the $who run recorded no case at all: an empty transcript is a RESULT, and it is"
        echo "     being reported here rather than as a silent death under set -e"
        exit 1
    fi
done
echo "--- the transcripts, compared:"
if diff -u "$build/host.body" "$build/port.body"; then
    echo "ok the port's completer calls its delegate exactly as the host's own does"
else
    echo "FAIL the port's completer and the host's own disagree"
    exit 1
fi
if [ ! -s "$build/host.body" ]; then
    echo "FAIL neither transcript has a call in it, so the comparison decided nothing"
    exit 1
fi
echo "--- the mutant (a wrong delegate argument must go red):"
if diff -q "$build/port.body" "$build/mutant.body" >/dev/null 2>&1; then
    echo "FAIL the mutant does not differ from the real build: this comparison cannot see a wrong"
    echo "     delegate argument, so a green run here would decide nothing"
    exit 1
fi
echo "ok the mutant differs, so the comparison does see the value it is checking"
diff -u "$build/port.body" "$build/mutant.body" | sed -n '1,12p'
exit 0
