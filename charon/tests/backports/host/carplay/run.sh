#!/bin/sh
# Two halves, one command, and one diff between them.
#
#   1. APPLE'S side. `headunit-probe.m` asks Apple's own CarPlay what it answers with NO head unit
#      attached, built for Mac Catalyst because that is the only place on this machine where Apple's
#      CarPlay loads: the fleet devices run 6.1.3, which has no CarPlay class of any name, and
#      /System/Library/Frameworks has no CarPlay outside the SDK.
#   2. THE PORT'S side. The port's own CarPlay sources are compiled here with their class names
#      renamed onto `charonHost_…`, so the runner reaches them through the runtime and can never reach
#      Apple's CarPlay by accident, and it drives the same questions.
#   3. THE DIFF. Both sides print `label<TAB>answer`, and every label they both carry has to answer
#      the same on both, or the run is red. That is what makes the port's rows measured rather than
#      asserted: the answer in `registry/CarPlay/ios12.json` is the answer Apple's own object gave.
#
# Each half carries a mutant, and the run FAILS if a mutant does not differ, because a comparison
# that cannot fail decides nothing. Run output lands under this repository's own .agent-work, never
# the system temp: the transcript is the evidence the registry's `source` names.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
port=${PORT:-$here/../../../../packages/a/apple-backports/CarPlay}
build=${CARPLAY_BUILD:-$PWD/.agent-work/runs/carplay-host}
mkdir -p "$build"
rm -f "$build"/cc.log "$build"/probe "$build"/probe.log "$build"/mutant "$build"/mutant.log \
      "$build"/mutated.m "$build"/runner "$build"/runner.log "$build"/runner.mutant.m \
      "$build"/runner.mutant.log "$build"/host.answers "$build"/port.answers \
      "$build"/port-classes.o "$build"/*.answers

MACOSX_SDK=$(xcrun --sdk macosx --show-sdk-path)
TARGET="-target arm64-apple-ios17.0-macabi -isysroot $MACOSX_SDK"
IOSSUPPORT="$MACOSX_SDK/System/iOSSupport"
FRAMEWORKS="-F $IOSSUPPORT/System/Library/Frameworks -framework Foundation -framework UIKit -framework CoreGraphics"
# The renames move the PORT's references; the headers they were read from still declare Apple's
# names, which is why Apple's CarPlay has to be linked on the probe side and not on the port side.
RENAME="-DCPTemplate=charonHost_CPTemplate \
    -DCPNavigationSession=charonHost_CPNavigationSession \
    -DCPMapTemplate=charonHost_CPMapTemplate \
    -DCPTrip=charonHost_CPTrip \
        -DCPSessionConfiguration=charonHost_CPSessionConfiguration \
    -DCPSessionConfigurationDelegate=charonHost_CPSessionConfigurationDelegate \
    -DCPLane=charonHost_CPLane \
    -DCPLaneGuidance=charonHost_CPLaneGuidance \
    -DCPRouteInformation=charonHost_CPRouteInformation \
    -DCPVoiceControlTemplate=charonHost_CPVoiceControlTemplate \
    -DCPVoiceControlState=charonHost_CPVoiceControlState \
    -DCPManeuver=charonHost_CPManeuver \
    -DCPTravelEstimates=charonHost_CPTravelEstimates \
    -DCPInterfaceController=charonHost_CPInterfaceController"

status=0

# ---------------------------------------------------------------- 1. Apple's side
echo "== Apple's own CarPlay, no head unit =="
xcrun clang -fobjc-arc -Wall $TARGET $FRAMEWORKS -framework CarPlay \
    "$here/headunit-probe.m" -o "$build/probe" 2> "$build/cc.log" || {
        grep -m5 ': error:' "$build/cc.log" || true
        exit 1
    }
"$build/probe" "$build/host.answers" > "$build/probe.log" 2>&1 && host_status=0 || host_status=$?
sed -n '2,$p' "$build/probe.log" | sed -n '/== 3/,$p'

# The mutant: the SAME source with one expectation inverted -- the voice control template's five
# state limit read as six. A header that stopped limiting would answer six, so this is the check that
# would notice. The substitution is compared before the build, so a renamed line fails the run
# instead of producing a mutant that is quietly identical to the real one.
sed 's/\[voice.voiceControlStates count\] == 5/[voice.voiceControlStates count] == 6/' \
    "$here/headunit-probe.m" > "$build/mutated.m"
if cmp -s "$build/mutated.m" "$here/headunit-probe.m"; then
    echo "FAIL: the line the host mutant changes is not in the probe" >&2
    exit 1
fi
xcrun clang -fobjc-arc -Wall $TARGET $FRAMEWORKS -framework CarPlay \
    "$build/mutated.m" -o "$build/mutant" 2> "$build/cc.log" || {
        grep -m5 ': error:' "$build/cc.log" || true
        exit 1
    }
"$build/mutant" > "$build/mutant.log" 2>&1 && host_mutant=0 || host_mutant=$?
if [ "$host_status" -ne 0 ]; then
    echo "FAIL: Apple's side did not pass every check" >&2
    status=1
fi
if [ "$host_mutant" -eq 0 ]; then
    echo "FAIL: Apple's side cannot fail, so it proves nothing" >&2
    status=1
fi

# ---------------------------------------------------------------- 2. the port's side
echo
echo "== the port's own voice control =="
# The shim names charonHost_CPTemplate literally, so it is compiled WITHOUT the renames: the renames
# exist to move the port's references and the shim's whole job is to declare what they moved onto.
xcrun clang -fobjc-arc -Wall -fPIC $TARGET $FRAMEWORKS -I"$port" \
    -c "$here/port-classes.m" -o "$build/port-classes.o" 2> "$build/cc.log" || {
        grep -m5 ': error:' "$build/cc.log" || true
        exit 1
    }
build_runner() {
    out=$1
    source=$2
    xcrun clang -fobjc-arc -Wall $TARGET $FRAMEWORKS -I"$port" $RENAME \
        "$here/runner.m" "$build/port-classes.o" "$source" \
        "$port/CarPlayNavigationSession12.m" "$port/CarPlayNavigationSession154.m" \
        "$port/CarPlayNavigationSession174.m" "$port/CarPlayLane174.m" "$port/CarPlayLane18.m" \
        "$port/CarPlayLaneGuidance174.m" "$port/CarPlayRouteInformation174.m" \
        "$port/CarPlaySessionConfiguration12.m" "$port/CarPlaySessionConfiguration13.m" \
        -o "$out" 2> "$build/cc.log" || {
            grep -m5 ': error:' "$build/cc.log" || true
            exit 1
        }
}
build_runner "$build/runner" "$port/CarPlayVoiceControl12.m"
"$build/runner" "$build/port.answers" > "$build/runner.log" 2>&1 && port_status=0 || port_status=$?
sed -n '2,$p' "$build/runner.log"

# The port's mutant: the same source with its own five-state limit read as six, so the row's limit is
# a thing the harness can see break rather than a sentence in a facts file.
sed 's/kept = MIN((NSUInteger)5, (NSUInteger)voiceControlStates.count)/kept = MIN((NSUInteger)6, (NSUInteger)voiceControlStates.count)/' \
    "$port/CarPlayVoiceControl12.m" > "$build/runner.mutant.m"
if cmp -s "$build/runner.mutant.m" "$port/CarPlayVoiceControl12.m"; then
    echo "FAIL: the line the port mutant changes is not in CarPlayVoiceControl12.m" >&2
    exit 1
fi
build_runner "$build/runner.mutant" "$build/runner.mutant.m"
"$build/runner.mutant" > "$build/runner.mutant.log" 2>&1 && port_mutant=0 || port_mutant=$?
if [ "$port_status" -ne 0 ]; then
    echo "FAIL: the port's side did not pass every check" >&2
    status=1
fi
if [ "$port_mutant" -eq 0 ]; then
    echo "FAIL: the port's side cannot fail, so it proves nothing" >&2
    status=1
fi

# ---------------------------------------------------------------- 3. the diff
echo
echo "== the two sides, label by label =="
# Only the labels BOTH sides carry are compared; the port's own extra checks (its drawing) have no
# counterpart in Apple's framework to compare with, and the count of those is printed so a reader can
# see what was and was not compared.
cut -f1 "$build/host.answers" | sort -u > "$build/host.labels"
cut -f1 "$build/port.answers" | sort -u > "$build/port.labels"
comm -12 "$build/host.labels" "$build/port.labels" > "$build/shared.labels"
port_only=$(comm -13 "$build/host.labels" "$build/port.labels" | wc -l | tr -d ' ')
: > "$build/host.shared"
: > "$build/port.shared"
while IFS= read -r label; do
    grep -F "$label	" "$build/host.answers" >> "$build/host.shared" || true
    grep -F "$label	" "$build/port.answers" >> "$build/port.shared" || true
done < "$build/shared.labels"
compared=$(wc -l < "$build/host.shared" | tr -d ' ')
if [ "$compared" -eq 0 ]; then
    echo "FAIL: no label is answered by both sides, so the diff compares nothing" >&2
    exit 1
fi
if diff -u "$build/host.shared" "$build/port.shared" > "$build/diff.txt"; then
    echo "compared $compared answers, all identical; $port_only port-only checks not compared"
else
    echo "FAIL: the port and Apple's own object answer differently. The diff:" >&2
    cat "$build/diff.txt" >&2
    status=1
fi

echo
echo "host exit=$host_status host-mutant exit=$host_mutant port exit=$port_status port-mutant exit=$port_mutant"
if [ "$status" -ne 0 ]; then
    echo "FAIL" >&2
    exit 1
fi
echo "ok: both sides pass, both mutants are red, and every answer both sides give is the same"
