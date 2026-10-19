#!/bin/sh
# The list form of the MIDI send: midilist.m runs the port's RevenantForEachMIDIMessage, the walk the method runs, over
# UMP messages of every type the port converts, and holds each to its expected MIDI 1.0 or system-exclusive bytes.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
build=${AVFAUDIO_MIDILIST_BUILD:-$(runs_folder revenant-avfaudio-midilist)}
rm -rf "$build"
mkdir -p "$build"

xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations "$here/midilist.m" \
    -framework Foundation -framework AVFoundation -framework CoreMIDI \
    -o "$build/midilist" 2> "$build/build.err" || { echo "FAIL building midilist"; head -10 "$build/build.err"; exit 1; }
"$build/midilist" > "$build/log" 2>&1 && result=0 || result=$?
cat "$build/log"
echo "log=$build/log"
exit "$result"
