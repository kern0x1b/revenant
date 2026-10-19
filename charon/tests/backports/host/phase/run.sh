#!/bin/sh
# values.sh — the host oracle for PHASE's spatial-audio value types, with the port's own classes in
# the same binary.
#
# Two halves, and the second is the one that can fail:
#
#   the host half asks the host's own PHASE.framework for the documented defaults of a *fresh* object
#   of each class - not a value set and read back, which was never a measurement of a default;
#
#   the port half compiles the port's own PHASEValueTypes15.m with its class names renamed, so
#   charon_host_PHASECardioidDirectivityModelSubbandParameters sits beside Apple's in one binary, and
#   holds a fresh port object to the same eight numbers the host's fresh object answers. A default the
#   port gets wrong is then a difference, not a comment.
#
# A class the host does not carry is reported and skipped; the run fails outright if the host has no
# PHASE at all, so nothing passes vacuously.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
root=${PHASE_ROOT:-$(cd "$here/../../../.." && pwd)}
AVFAUDIO="$root/packages/a/apple-backports/AVFAudio"
build=${PHASE_VALUES_BUILD:-$(runs_folder charon-phase-values)}
rm -rf "$build"
mkdir -p "$build"

# Every class the port's PHASE source defines, renamed. The list is written out rather than derived: a
# derived one spans the whole folder and renames classes this binary does not compile.
renames=""
for name in PHASENumericPair PHASEDistanceModelParameters PHASEDistanceModelFadeOutParameters \
             PHASEGeometricSpreadingDistanceModelParameters PHASEDirectivityModelParameters \
             PHASECardioidDirectivityModelSubbandParameters PHASEConeDirectivityModelSubbandParameters \
             PHASECardioidDirectivityModelParameters PHASEConeDirectivityModelParameters PHASEEngine PHASEObject \
             PHASEEnvelope PHASEEnvelopeSegment PHASEEnvelopeDistanceModelParameters
do
    renames="$renames -D$name=charon_host_$name"
done

# One -c and one -o per source: a single -c with two inputs and one -o is rejected, which is what
# this did the first time.
port_objects=""
for source in "$AVFAUDIO/PHASEValueTypes15.m" "$AVFAUDIO/PHASEEngine15.m" "$AVFAUDIO/PHASEObject15.m" \
    "$AVFAUDIO/PHASEEnvelope15.m" "$AVFAUDIO/PHASEEnvelopeSegment15.m" \
    "$AVFAUDIO/PHASEEnvelopeDistanceModelParameters15.m"; do
    name=$(basename "$source")
    # shellcheck disable=SC2086
    xcrun clang -fobjc-arc -w $renames -I"$AVFAUDIO" -I"$root/modules" \
        -c "$source" -o "$build/$name.o" 2> "$build/$name.err" || {
            echo "FAIL compiling $name"; head -6 "$build/$name.err"; exit 1; }
    port_objects="$port_objects $build/$name.o"
done

# shellcheck disable=SC2086
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations "$here/values.m" $port_objects \
    -framework Foundation -framework AVFoundation -framework PHASE -o "$build/values" 2> "$build/link.err" || {
        echo "FAIL linking"; head -8 "$build/link.err"; exit 1; }

"$build/values" > "$build/log" 2>&1 && result=0 || result=$?
grep -v '^ok ' "$build/log" || true
echo "log=$build/log"

# The clock: PHASEEngine's lastRenderTime, the host's engine and the port's render loop, run through the same script.
# It takes about six seconds and the values are timing, so each reading has a tolerance (clock.m).
# shellcheck disable=SC2086
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations "$here/clock.m" $port_objects \
    -framework Foundation -framework AVFoundation -framework PHASE -o "$build/clock" 2> "$build/clock-link.err" || {
        echo "FAIL linking clock"; head -8 "$build/clock-link.err"; exit 1; }
"$build/clock" > "$build/clock.log" 2>&1 && clock_result=0 || clock_result=$?
cat "$build/clock.log"
echo "clock log=$build/clock.log"
[ "$result" -eq 0 ] && [ "$clock_result" -eq 0 ]
