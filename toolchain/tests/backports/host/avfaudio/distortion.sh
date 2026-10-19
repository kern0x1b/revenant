#!/bin/sh
# AVAudioUnitDistortion's presets, preGain and wetDryMix against the host's unit: distortion.m, built against the port's
# RevenantDistortionPresets.h, the table the port's class sends.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
build=${AVFAUDIO_DISTORTION_BUILD:-$(runs_folder revenant-avfaudio-distortion)}
rm -rf "$build"
mkdir -p "$build"

xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations "$here/distortion.m" \
    -framework Foundation -framework AVFoundation -framework AudioToolbox \
    -o "$build/distortion" 2> "$build/build.err" || { echo "FAIL building distortion"; head -10 "$build/build.err"; exit 1; }
"$build/distortion" > "$build/log" 2>&1 && result=0 || result=$?
cat "$build/log"
echo "log=$build/log"
exit "$result"
