#!/bin/sh
# The host's answers for the MIDI list's type-4 scalings, measured on the host's AVAudioUnitSampler: midi-host.m. Each
# equivalence is a bit-exact render comparison, checked here against the scaling the port's walk uses.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
build=${AVFAUDIO_MIDIHOST_BUILD:-$(runs_folder charon-avfaudio-midi-host)}
rm -rf "$build"
mkdir -p "$build"

xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations "$here/midi-host.m" \
    -framework Foundation -framework AVFoundation -framework CoreMIDI -o "$build/midi-host" 2> "$build/build.err" \
    || { echo "FAIL building midi-host"; head -10 "$build/build.err"; exit 1; }
"$build/midi-host" > "$build/log" 2>&1 && result=0 || result=$?
cat "$build/log"
echo "log=$build/log"
exit "$result"
