#!/bin/sh
# run.sh — the host half of the AVPlaybackSpeed differential: what the system's own AVKit answers for
# the speeds a playback UI offers. run.sh writes those answers to avkitspeeds.json in the build
# directory and prints them, so the numbers the port ships can be read against the host's rather than
# against this file's comment. The port's own values live in
# packages/frameworks/apple-backports/AVKit/AVPlayerViewControllerSpeeds16.m and the row of AVPlaybackSpeed.
#
# A device pass would run the port's own object against this file; no such test is in the tree yet, and
# facts/AVKit/AVPlaybackSpeed.md says so rather than implying one is.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
build=${BUILD:-$(runs_folder avkitspeeds-host)}
mkdir -p "$build"
xcrun clang -fobjc-arc -w "$here/host.m" -framework AVKit -framework Foundation -o "$build/host"
"$build/host" | tee "$build/avkitspeeds.log"
runs_xmake l "$here/speeds.lua" "$build/avkitspeeds.log" "$build/avkitspeeds.json"
