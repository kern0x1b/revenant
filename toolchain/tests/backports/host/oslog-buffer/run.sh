#!/bin/sh
# run.sh - the os_log macros' packed buffer, decoded by the port, held to the host's own developer output.
#
#   1. differential.m is built twice from one source: against the host's own os_log, which writes the
#      developer output the comparator reads, and against the port's decoder (RevenantOSLogFormat.m, the core and
#      OSLog11.m), with a harness _os_log_impl in the binary so that the decoded text comes out where the
#      comparator reads it. The battery is host/oslog's, so the two runs share its cases and its verdicts.
#   2. disabled.m is built both ways: what OS_LOG_DISABLED answers on the host, and what the port's object
#      answers for the same five types. The two outputs have to be the same, byte for byte.
#
# The port's _os_log_impl itself (OSLog10.m) writes to the system log, so it is not run here: the harness takes
# its place and calls the same decoder. The write is the port's own revenant_os_log_send path, which the
# host/oslog run covers through its varargs twin.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
FOUNDATION=${FOUNDATION:-$here/../../../../packages/a/apple-backports/Foundation}
BUILD=${BUILD:-$(runs_fresh revenant-oslog-buffer)}
# Measured: the header's os_log macro takes the packed-buffer path only from a 10.12 target
# (OS_LOG_TARGET_HAS_10_12_FEATURES). At 10.11 it calls _os_log_internal, so _os_log_impl never runs.
flags="-fobjc-arc -mmacosx-version-min=10.12 -w -I$FOUNDATION -I$here/../oslog"
xcrun clang $flags "$here/differential.m" -framework Foundation -o "$BUILD/system"
xcrun clang $flags -DREVENANT_PORT -I"$here" "$here/differential.m" "$FOUNDATION/RevenantOSLogFormat.m" \
    "$FOUNDATION/RevenantOSLogCore.m" "$FOUNDATION/OSLog11.m" -framework Foundation -o "$BUILD/port"
TZ=UTC OS_ACTIVITY_DT_MODE=YES "$BUILD/system" > "$BUILD/system.stdout" 2> "$BUILD/system.txt"
TZ=UTC "$BUILD/port" "$BUILD/ours.bin" > "$BUILD/port.stdout"
xmake l "$here/../oslog/compare.lua" "$BUILD/system.txt" "$BUILD/ours.bin" > "$BUILD/compare.txt" || {
    cat "$BUILD/compare.txt"; echo "FAIL the buffer decoder differs from the host"; exit 1; }
grep -v '^ok ' "$BUILD/compare.txt" || true

xcrun clang -fobjc-arc -mmacosx-version-min=10.11 -w "$here/disabled.m" -framework Foundation -o "$BUILD/disabled-system"
xcrun clang -fobjc-arc -mmacosx-version-min=10.11 -w -DREVENANT_PORT -I"$FOUNDATION" "$here/disabled.m" \
    "$FOUNDATION/RevenantOSLogFormat.m" "$FOUNDATION/RevenantOSLogCore.m" "$FOUNDATION/OSLog11.m" \
    -framework Foundation -o "$BUILD/disabled-port"
"$BUILD/disabled-system" > "$BUILD/disabled-system.txt"
"$BUILD/disabled-port" > "$BUILD/disabled-port.txt"
diff "$BUILD/disabled-system.txt" "$BUILD/disabled-port.txt" || { echo "FAIL OS_LOG_DISABLED differs"; exit 1; }
echo "disabled: the port's OS_LOG_DISABLED answers as the host's do:"
cat "$BUILD/disabled-port.txt"
echo "log=$BUILD"
