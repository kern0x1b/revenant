#!/bin/sh
# run.sh - AVAudioFile, the port against the host.
#
# One program (probe.m) built twice: plain, against Apple's AVFAudio on this host, and with the rename
# list and the port's four objects, where the same names are the port's own classes in the same binary.
# Both runs write and read the same files and print the same lines; the outputs must be equal byte for
# byte. The outputs are the measurement - field values, frame counts, a checksum of the PCM frames, the
# NSError domain and code of each failure, and the exception a read past the buffer raises.
#
# What makes it a check rather than a comparison:
#
#   * a name the port does not define is a LINK ERROR, so a missing class cannot read as "both sides agree";
#   * an empty output is a FAIL, not an empty diff;
#   * AVFILE_FOUNDATION points the port half at another copy of the AVFoundation folder, so a planted
#     control (a sed on a scratch copy) can show the comparison goes red.
#
# Run DIRECTLY, not through heavy.sh: a handful of small compiles and two short runs.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
root=$(cd "$here/../../../.." && pwd)
AVFAUDIO="$root/packages/a/apple-backports/AVFAudio"
AVFOUNDATION=${AVFILE_FOUNDATION:-$root/packages/a/apple-backports/AVFoundation}
build=${AVFILE_BUILD:-$(runs_folder revenant-avfaudio-file)}
rm -rf "$build"
mkdir -p "$build/host-scratch" "$build/port-scratch"

# Every class the port's AVAudioFile and the formats and buffers it holds define, renamed.
renames="-DAVAudioFile=revenant_host_AVAudioFile
-DAVAudioFormat=revenant_host_AVAudioFormat
-DAVAudioPCMBuffer=revenant_host_AVAudioPCMBuffer
-DRevenantAudioBuffer=revenant_host_RevenantAudioBuffer"

# The host half: Apple's classes, no renames.
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations "$here/probe.m" \
    -framework Foundation -framework AVFoundation -framework AVFAudio -framework AudioToolbox \
    -o "$build/host" 2> "$build/host.err" || {
        echo "FAIL building the host half"; head -8 "$build/host.err"; exit 1; }

# The port half: the port's four objects, renamed, and the probe compiled with the same renames.
objects=""
for source in AVAudioFormat8.m AVAudioBuffer8.m AVAudioPCMBuffer8.m AVAudioFile8.m; do
    [ -f "$AVFOUNDATION/$source" ] || { echo "FAIL missing $AVFOUNDATION/$source"; exit 1; }
    # shellcheck disable=SC2086
    xcrun clang -fobjc-arc -w $renames -I"$AVFAUDIO" -I"$AVFOUNDATION" \
        -c "$AVFOUNDATION/$source" -o "$build/$source.o" 2> "$build/$source.err" || {
            echo "FAIL compiling $source"; head -6 "$build/$source.err"; exit 1; }
    objects="$objects $build/$source.o"
done
# shellcheck disable=SC2086
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations $renames -I"$AVFAUDIO" -I"$AVFOUNDATION" \
    "$here/probe.m" $objects \
    -framework Foundation -framework AVFoundation -framework AVFAudio -framework AudioToolbox \
    -o "$build/port" 2> "$build/port.err" || {
        echo "FAIL linking the port half"; head -8 "$build/port.err"; exit 1; }

"$build/host" "$build/host-scratch" > "$build/host.log" 2> "$build/host.stderr" || {
    echo "FAIL the host half exited non-zero"; head -4 "$build/host.stderr"; exit 1; }
"$build/port" "$build/port-scratch" > "$build/port.log" 2> "$build/port.stderr" || {
    echo "FAIL the port half exited non-zero"; head -4 "$build/port.stderr"; exit 1; }

lines=$(wc -l < "$build/host.log" | tr -d ' ')
if [ "$lines" -lt 30 ]; then
    echo "FAIL the host half printed $lines lines, too few to be the measurement"; exit 1
fi
if diff -u "$build/host.log" "$build/port.log" > "$build/diff" 2>&1; then
    echo "ok    AVAudioFile: the port and the host print the same $lines lines"
    echo "log=$build/host.log"
    exit 0
fi
echo "FAIL  AVAudioFile: the port and the host differ"
head -40 "$build/diff"
echo "log=$build/diff"
exit 1
