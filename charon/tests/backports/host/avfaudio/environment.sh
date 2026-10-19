#!/bin/sh
# AVAudioEnvironmentNode's outputType resolution and listenerHeadTrackingEnabled: environment.m, against the header the port includes.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
build=${AVFAUDIO_ENVIRONMENT_BUILD:-$(runs_folder charon-avfaudio-environment)}
rm -rf "$build"
mkdir -p "$build"

xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations "$here/environment.m" \
    -framework Foundation -framework AVFoundation -framework AudioToolbox \
    -o "$build/environment" 2> "$build/build.err" || { echo "FAIL building environment"; head -10 "$build/build.err"; exit 1; }
"$build/environment" > "$build/log" 2>&1 && result=0 || result=$?
cat "$build/log"
echo "log=$build/log"
exit "$result"
