#!/bin/sh
# run.sh - AVPlayerLooper (iOS 10.0), the host against the port.
#
# probe.m makes a one-second movie with the host's AVAssetWriter and loops it on an AVQueuePlayer, reading the
# looper's answers in three sections (the default range, a sweep of time-range lengths, and a template that fails).
# It is built twice: plain, against Apple's AVPlayerLooper; and with REVENANT_PORT_BUILD=1, against the port's
# RevenantPlayerLooper, whose .m is compiled from a scratch copy that changes only its runtime name (so the two
# classes do not clash in one process), as tests/backports/host/avf-movie4/run.sh does.
#
# Run DIRECTLY, not through heavy.sh: a few compiles and a few short runs of about 25 seconds each.
#
# What makes it a check rather than a comparison:
#   * a member the port does not define is a RUNTIME error, and the probe stops with it;
#   * the row count is the probe's own last line ("rows: N") and must equal the rows each table holds;
#   * the PLANTED control: AVPLAYERLOOPER_MUTANT=1 changes the seconds of queued material from 10 to 9 in the
#     scratch copy, the change is checked by count, and the run must go red.
#   * a build failure is "RUN FAILED" with the compiler's first lines, never a noticed mutation.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
root=$(cd "$here/../../../.." && pwd)
avf=$root/packages/frameworks/apple-backports/AVFoundation
run=${AVPLAYERLOOPER_RUN:-$(runs_folder v-avf-looper)}
mutant=${AVPLAYERLOOPER_MUTANT:-0}
build=$run/build
rm -rf "$build"
mkdir -p "$build/src"
# -Wno-deprecated-declarations: the macOS SDK deprecates some of the writer's constants, which the probe does not use.
# shellcheck disable=SC2086
flags="-fobjc-arc -Wall -Wno-deprecated-declarations -framework Foundation -framework AVFoundation -framework CoreMedia -framework CoreVideo"

# 1. the host table: the probe against Apple's own AVPlayerLooper
# shellcheck disable=SC2086
xcrun clang $flags "$here/probe.m" -o "$build/host" > "$build/host.log" 2>&1 || {
    echo "RUN FAILED: the host probe did not build"; head -8 "$build/host.log"; exit 1; }
timeout 120 "$build/host" "$run" > "$build/host.table" 2> "$build/host.err" || {
    echo "RUN FAILED: the host probe stopped (exit $?)"; head -5 "$build/host.err"; tail -2 "$build/host.table"; exit 1; }

# 2. the port's AVPlayerLooper10.m, from a scratch copy: the runtime name, and for the planted mutant one changed constant
port_src=$build/src/AVPlayerLooper10.m
sed -e 's/objc_runtime_name("AVPlayerLooper")/objc_runtime_name("revenant_host_AVPlayerLooper")/' \
    "$avf/AVPlayerLooper10.m" > "$port_src"
[ "$(grep -c 'revenant_host_AVPlayerLooper' "$port_src")" = 1 ] || {
    echo "RUN FAILED: the scratch copy lost its runtime name, so this run proves nothing"; exit 1; }
if [ "$mutant" != 0 ]; then
    before='static const double revenantLooperQueuedSeconds = 10.0;'
    after='static const double revenantLooperQueuedSeconds = 9.0;'
    [ "$(grep -cF "$before" "$port_src")" = 1 ] || { echo "RUN FAILED: the mutant target is not unique, so this run proves nothing"; exit 1; }
    sed -e "s/$before/$after/" "$port_src" > "$port_src.mutant" && mv "$port_src.mutant" "$port_src"
    [ "$(grep -cF "$before" "$port_src")" = 0 ] && [ "$(grep -cF "$after" "$port_src")" = 1 ] || {
        echo "RUN FAILED: the mutant did not take, so this run proves nothing"; exit 1; }
    echo "# the mutation applied: the looper keeps nine seconds of material, not ten"
fi
# shellcheck disable=SC2086
xcrun clang -fobjc-arc -w -c "$port_src" -o "$build/AVPlayerLooper10.o" > "$build/port-object.log" 2>&1 || {
    echo "RUN FAILED: the port's AVPlayerLooper10.m did not compile"; head -8 "$build/port-object.log"; exit 1; }

# 3. the port table: the same probe, linked with the port's object in place of the framework's class
# shellcheck disable=SC2086
xcrun clang $flags -DREVENANT_PORT_BUILD=1 "$here/probe.m" "$build/AVPlayerLooper10.o" -o "$build/port" > "$build/port.log" 2>&1 || {
    echo "RUN FAILED: the port probe did not link"; head -8 "$build/port.log"; exit 1; }
timeout 120 "$build/port" "$run" > "$build/port.table" 2> "$build/port.err" || {
    echo "RUN FAILED: the port probe stopped (exit $?)"; head -5 "$build/port.err"; tail -2 "$build/port.table"; exit 1; }

# 4. neither table may be smaller than its claim
for side in host port; do
    want=$(sed -n 's/^rows: \([0-9][0-9]*\)$/\1/p' "$build/$side.table" | tail -1)
    have=$(grep -c ' = ' "$build/$side.table" || true)
    if [ -z "$want" ] || [ "$have" -ne "$want" ]; then
        echo "FAIL: the $side table holds $have rows but the probe reported ${want:-no count}; refusing to compare"
        exit 1
    fi
done

# 5. the join: every row must be equal; the count line is not compared
grep -v '^rows: ' "$build/host.table" > "$build/host.cmp"
grep -v '^rows: ' "$build/port.table" > "$build/port.cmp"
compared=$(grep -c ' = ' "$build/host.cmp")
echo "host $(grep -c ' = ' "$build/host.table") rows, port $(grep -c ' = ' "$build/port.table") rows; compared $compared"
diff -u "$build/host.cmp" "$build/port.cmp" > "$build/diff.log" && differs=0 || differs=$(grep -c '^[-+][^-+]' "$build/diff.log" || true)

if [ "$mutant" != 0 ]; then
    if [ "$differs" = 0 ]; then
        echo "FAIL: the mutation left the tables equal, so this check cannot fail and proves nothing"
        exit 1
    fi
    echo "ok  the mutation was noticed, on $differs changed line(s):"
    sed -n '1,12p' "$build/diff.log"
    exit 0
fi
if [ "$differs" != 0 ]; then
    echo "FAIL: the port's table differs from the host's on $differs line(s):"
    sed -n '1,60p' "$build/diff.log"
    exit 1
fi
echo "ok  every compared row: the port answers what the host answers"
exit 0
