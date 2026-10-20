#!/bin/sh
# run.sh - every resolution-result factory the registry marks implemented (registry/Intents), called on the host's own
# Intents and on the port's objects, from one probe source (probe.m), and the two compared factory by factory.
#
# The host's list of classes is the input: the probe's list mode names them, and each class is probed in its own
# process, so a factory that crashes one process is named and does not hide the others. The host build links the
# system's Intents and nothing of the port. The port build (-DPORT) links the port's objects, the sources listed below,
# compiled with REVENANT_HOST_BUILD and their classes renamed (RevenantHostINIntentResolutionResult and so on), because two
# Intents classes of one name in one process answer for each other.
#
# The verdict is the diff: every in-scope line the port prints must be the host's line. A class whose probe exits non-zero is a
# FAIL on both sides' lines, and says so. The plant is a copy of the port in which revenant_resolutionWithStatus: answers
# an object for an empty disambiguation: its diff must be non-empty, or the comparison cannot fail.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
P=${PORT_DIR:-$here/../../../../packages/frameworks/apple-backports}
CODING=$P/../../runtimes/revenant-coding/files
build=${RESOLUTION_FACTORIES_BUILD:-$(runs_fresh revenant-resolution-factories)}
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
flags="$target -fobjc-arc -fvisibility=hidden -w -DREVENANT_HOST_BUILD"
probe_flags="$target -fno-objc-arc -fvisibility=hidden -w"
frameworks="-framework Foundation -framework UIKit -framework CoreGraphics -framework EventKit -framework Intents"
includes="-I$P/Intents -I$CODING"
sources="$CODING/RevenantCoding.m $P/Intents/RevenantIntentsStore.m $P/Intents/RevenantIntents100.m $P/Intents/RevenantIntents110.m $P/Intents/RevenantIntents180.m $P/Intents/IN10_0_1.m $P/Intents/IN10_3.m $P/Intents/IN11_0.m $P/Intents/IN12_0.m $P/Intents/IN13_4.m $P/Intents/IN16_0.m $P/Intents/IN17_0.m $P/Intents/IN18_0.m $P/Intents/INPaymentMethodResolutionResult10.3.m"

mkdir -p "$build/plain" "$build/port" "$build/host" "$build/hostout" "$build/portout" "$build/plant"

# The host: the system's Intents, nothing of the port. Its classes are listed by the probe, then each is probed.
xcrun clang $probe_flags "$here/probe.m" $frameworks -o "$build/host-probe"
"$build/host-probe" > "$build/classes.txt"
echo "classes: $(wc -l < "$build/classes.txt" | tr -d ' ') resolution-result classes on the host"

probe_each() {
    # $1 binary, $2 output directory
    while read -r cls; do
        status=0
        "$1" "$cls" > "$2/$cls.txt" || status=$?
        if [ "$status" -ne 0 ]; then
            echo "CRASH $cls exit $status (lines before the crash are kept)" >> "$2/$cls.txt"
        fi
    done < "$build/classes.txt"
    cat "$2"/*.txt
}

probe_each "$build/host-probe" "$build/hostout" > "$build/host.txt"
echo "host: $(wc -l < "$build/host.txt" | tr -d ' ') lines, $(grep '^CRASH' "$build/host.txt" | wc -l | tr -d ' ') crashes"

# The port's objects, first compiled plain, to read which classes they define.
for source in $sources; do
    xcrun clang $flags $includes -c "$source" -o "$build/plain/$(basename "$source" .m).o"
done
renames=""
for name in $(xcrun nm -gU "$build"/plain/*.o | awk 'NF == 3 {print $3}' | grep -E '^_OBJC_CLASS_\$_' | sed -e 's/^_OBJC_CLASS_\$_//' | sort -u); do
    renames="$renames -D$name=RevenantHost$name"
done
for source in $sources; do
    xcrun clang $flags $renames $includes -c "$source" -o "$build/port/$(basename "$source" .m).o"
done
xcrun clang $probe_flags -DPORT "$here/probe.m" "$build"/port/*.o $frameworks -o "$build/port-probe"

probe_port() {
    while read -r cls; do
        status=0
        "$build/port-probe" "$cls" > "$build/portout/$cls.txt" || status=$?
        if [ "$status" -ne 0 ]; then
            echo "CRASH $cls exit $status (lines before the crash are kept)" >> "$build/portout/$cls.txt"
        fi
    done < "$build/classes.txt"
    cat "$build"/portout/*.txt
}

probe_port > "$build/port.txt"
echo "port: $(wc -l < "$build/port.txt" | tr -d ' ') lines, $(grep '^CRASH' "$build/port.txt" | wc -l | tr -d ' ') crashes"

# The comparison is the registry's: the factories of the rows the registry marks implemented, and the lines of those
# alone. The host's runtime has factories the release never had and the registry does not carry (the classes of iOS 13
# and later are not in the port at all), and those are not held against the port. A class whose host probe stalls is
# named: the probe's own timeout ends that process, the lines before the stall are compared, and an in-scope factory the
# host never reached is a line the host lacks, so the diff says so.
scope="$build/scope.txt"
awk '/"api": "\+\[/ { s=$0; sub(/.*"api": "\+\[/, "", s); sub(/\]",?$/, "", s); api=s }
     /"status": / { if (api != "" && $0 ~ /"implemented"/) print api; api="" }' "$P"/registry/Intents/*.json | sort -u > "$scope"
echo "registry: $(wc -l < "$scope" | tr -d ' ') implemented factory rows in scope"
stalled=$(awk '$1 == "CRASH" && $4 == "124" { print $2 }' "$build/host.txt" | sort -u | tr '\n' ' ')
compared() {
    awk -v scope="$scope" '
        BEGIN { while ((getline line < scope) > 0) want[line] = 1 }
        /^(CRASH|TIMEOUT)/ { next }
        { key = $0; sub(/ pass=.*/, "", key); if (key in want) print }' "$1" | sort
}
compared "$build/host.txt" > "$build/host-cmp.txt"
compared "$build/port.txt" > "$build/port-cmp.txt"
echo "in scope: $(wc -l < "$build/host-cmp.txt" | tr -d ' ') host lines, $(wc -l < "$build/port-cmp.txt" | tr -d ' ') port lines; host stalled on: ${stalled:-none} (lines before each stall are compared)"
if ! diff -u "$build/host-cmp.txt" "$build/port-cmp.txt" > "$build/diff.txt"; then
    cat "$build/diff.txt"
    echo "FAIL: the port answers differently from the host on $(grep '^[-+][^-+]' "$build/diff.txt" | wc -l | tr -d ' ') line(s) (above)"
    exit 1
fi
echo "PASS: $(wc -l < "$build/port-cmp.txt" | tr -d ' ') in-scope port lines, port and host alike"

# The plant: the port's revenant_resolutionWithStatus: built without the empty-disambiguation rule, if the rule is there.
# A copy of RevenantIntents100.m is compiled in place of the port's, and its diff must be non-empty.
if grep -q 'RevenantIntentsResolutionDisambiguation && valuesToDisambiguate.count == 0' "$P/Intents/RevenantIntents100.m"; then
    sed 's/RevenantIntentsResolutionDisambiguation \&\& valuesToDisambiguate.count == 0/RevenantIntentsResolutionNeedsValue \&\& valuesToDisambiguate.count == 0/' \
        "$P/Intents/RevenantIntents100.m" > "$build/plant/RevenantIntents100.src.m"
    cp "$build"/port/*.o "$build/plant/"
    rm -f "$build/plant/RevenantIntents100.o"
    xcrun clang $flags $renames $includes -c "$build/plant/RevenantIntents100.src.m" -o "$build/plant/RevenantIntents100.o"
    xcrun clang $probe_flags -DPORT "$here/probe.m" "$build"/plant/*.o $frameworks -o "$build/plant-probe"
    status=0
    : > "$build/plant.txt"
    while read -r cls; do
        pstatus=0
        "$build/plant-probe" "$cls" >> "$build/plant.txt" || pstatus=$?
    done < "$build/classes.txt"
    compared "$build/plant.txt" > "$build/plant-cmp.txt"
    if diff -q "$build/host-cmp.txt" "$build/plant-cmp.txt" >/dev/null; then
        echo "FAIL: the planted port agrees with the host, so the comparison cannot fail"
        exit 1
    fi
    echo "PLANT: the planted port differs from the host, as it must"
else
    echo "FAIL: the empty-disambiguation rule is not in RevenantIntents100.m, so the plant has nothing to remove"
    exit 1
fi
