#!/bin/sh
# run.sh - the port's CoreMotion classes (activity, pedometer, altimeter) against the host's own CoreMotion, case by case, in
# two processes.
#
#   1. differential.m is COMPILED against the host's CoreMotion (Catalyst, the macOS 27.0 SDK) and run once per case
#   2. the same source is COMPILED against the port's CoreMotion sources, with the test-only CMLogItem stub, and run once per
#      case
#   3. the two outputs of each case are compared; a case where the host dies on a signal is named as such and is not
#      counted as agreement
#   4. a plant on a scratch copy of the port's sources - one answer changed, each in the case that measures it - must turn
#      that case red
#
# Two processes, not one, because both sides define the same classes.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
appledir=${APPLEDIR:-$here/../../../../packages/a/apple-backports}
build=${BUILD:-$(runs_folder coremotion-activity)}
mkdir -p "$build"
sdk=$(xcrun --sdk macosx --show-sdk-path)
target=arm64-apple-ios17.0-macabi
cases="0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 20 21 22 23 24 25 26 27 28 29 30"

# The port's sources, every class of the three families in the directory given, and the test-only superclass stub.
port_build() {
    # port_build <source-dir> <output>
    xcrun clang -fobjc-arc -w -target "$target" -isysroot "$sdk" -DPORT -framework Foundation \
        "$here/differential.m" "$1/CMMotionActivity.m" "$1/CMMotionActivityManager.m" \
        "$1/CMPedometer.m" "$1/CMPedometerData.m" "$1/CMPedometerEvent.m" \
        "$1/CMAltimeter.m" "$1/CMAltitudeData.m" "$1/CMAbsoluteAltitudeData.m" \
        "$here/cmlogitem-stub.m" -o "$2"
}

xcrun clang -fobjc-arc -w -target "$target" -isysroot "$sdk" -framework Foundation -framework CoreMotion \
    "$here/differential.m" -o "$build/host"
port_build "$appledir/CoreMotion" "$build/port"

differs=0
crashed=0
compare() {
    # compare <label> <port-binary> <case...>
    label=$1; port=$2; shift 2
    for n in "$@"; do
        set +e
        "$build/host" "$n" > "$build/host.$n.out" 2>/dev/null; hs=$?
        "$port" "$n" > "$build/port.$n.out" 2>/dev/null; ps=$?
        set -e
        if [ "$hs" -ge 128 ]; then
            crashed=$((crashed + 1))
            echo "case $n: HOST CRASHED (signal $((hs - 128))), not comparable; port exit $ps: $(head -1 "$build/port.$n.out")"
            continue
        fi
        if [ "$ps" -ne 0 ] || [ "$hs" -ne 0 ]; then
            differs=$((differs + 1))
            echo "case $n: DIFFERS ($label): host exit $hs, port exit $ps"
            continue
        fi
        if cmp -s "$build/host.$n.out" "$build/port.$n.out"; then
            echo "case $n: EQUAL"
        else
            differs=$((differs + 1))
            echo "case $n: DIFFERS ($label)"
            diff "$build/host.$n.out" "$build/port.$n.out" | sed 's/^/    /' || true
        fi
    done
}

echo "--- the clean run"
compare clean "$build/port" $cases

# A plant is a copy of the port's sources with one line changed, and the case that measures that line must differ. The copy
# is a directory of its own holding every file, so a harness that copied only the changed one would fail to build rather
# than measure nothing.
plant() {
    # plant <case> <file> <sed-expression> <label>
    n=$1; file=$2; expr=$3; label=$4
    rm -rf "$build/mutant"; mkdir -p "$build/mutant"
    cp "$appledir/CoreMotion/"*.m "$build/mutant/"
    sed "$expr" "$appledir/CoreMotion/$file" > "$build/mutant/$file"
    if cmp -s "$appledir/CoreMotion/$file" "$build/mutant/$file"; then
        echo "MUTATION DID NOT APPLY: $label"
        differs=$((differs + 1000))
        return
    fi
    port_build "$build/mutant" "$build/port-mutant"
    set +e
    "$build/port-mutant" "$n" > "$build/port-mutant.$n.out" 2>/dev/null
    set -e
    if cmp -s "$build/host.$n.out" "$build/port-mutant.$n.out"; then
        echo "MUTANT SURVIVED: $label"
        differs=$((differs + 1000))
    else
        echo "  caught: $label"
    fi
}

echo "--- the plants"
plant 0 CMMotionActivityManager.m 's/    return NO;/    return YES;/' "activity availability NO flipped to YES"
plant 0 CMMotionActivityManager.m 's/CMAuthorizationStatusNotDetermined;/CMAuthorizationStatusDenied;/' "activity authorization NotDetermined flipped to Denied"
plant 8 CMPedometer.m 's/    return NO;/    return YES;/' "pedometer availability NO flipped to YES"
plant 8 CMPedometer.m 's/CMAuthorizationStatusNotDetermined;/CMAuthorizationStatusDenied;/' "pedometer authorization NotDetermined flipped to Denied"
plant 17 CMPedometerEvent.m 's/    copy->_type = _type;/    copy->_type = 1;/' "pedometer event copy loses the type"
plant 20 CMAltimeter.m 's/    return NO;/    return YES;/' "altimeter availability NO flipped to YES"
plant 20 CMAltimeter.m 's/CMAuthorizationStatusNotDetermined;/CMAuthorizationStatusDenied;/' "altimeter authorization NotDetermined flipped to Denied"

echo "--- verdict: $differs difference(s) among comparable cases, $crashed host crash(es) not comparable"
[ "$differs" -eq 0 ]
