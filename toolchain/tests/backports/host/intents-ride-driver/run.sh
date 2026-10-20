#!/bin/sh
# run.sh - what the two deprecated -[INRideDriver initWithHandle:...] initialisers store, asked of the host's own
# Intents and of the port's objects, from one probe source (probe.m).
#
# The host build links the system's Intents and nothing of the port, and is compared with expected.txt, the golden
# answer. The port build (-DPORT) links the port's objects: IN10_0_1.m, which defines INRideDriver and INPersonHandle,
# with the coding and store it needs, compiled with REVENANT_HOST_BUILD against the Catalyst headers (so
# RevenantIntents262.h declares nothing the SDK already declares). Its classes are renamed (RevenantHostINRideDriver and so
# on), because two Intents classes of one name in one process answer for each other. The diff of the two is the verdict.
#
# The plant: a port whose handle-only initialiser answers "" for a nil displayName, where the host answers the handle.
# Its diff against the host must be non-empty, or the comparison cannot fail.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
P=${PORT_DIR:-$here/../../../../packages/frameworks/apple-backports}
CODING=$P/../../runtimes/revenant-coding/files
build=${RIDE_DRIVER_BUILD:-$(runs_fresh revenant-intents-ride-driver)}
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
flags="$target -fobjc-arc -fvisibility=hidden -w -DREVENANT_HOST_BUILD"
probe_flags="$target -fno-objc-arc -fvisibility=hidden -w"
frameworks="-framework Foundation -framework UIKit -framework CoreGraphics -framework EventKit -framework Intents"
includes="-I$P/Intents -I$CODING"
sources="$CODING/RevenantCoding.m $P/Intents/RevenantIntentsStore.m $P/Intents/RevenantIntents100.m $P/Intents/IN10_0_1.m $P/Intents/IN11_0.m"

# The host: the system's Intents, nothing of the port, against the golden answer.
xcrun clang $probe_flags "$here/probe.m" -framework Foundation -framework Intents -o "$build/host"
"$build/host" > "$build/host.txt"
if ! diff -u "$here/expected.txt" "$build/host.txt"; then
    echo "FAIL: the host answers differently from expected.txt (lines above)"
    exit 1
fi
echo "PASS: $(wc -l < "$build/host.txt") host lines, the golden answer"

# The port's objects, first compiled plain, to read which classes they define. The two initialisers are a category in
# RevenantIntents100.m, so the plant edits that file.
mkdir -p "$build/plain" "$build/port" "$build/plant"
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
"$build/port-probe" > "$build/port.txt" || { cat "$build/port.txt"; echo "FAIL: the port probe stopped with status $?"; exit 1; }
if ! diff -u "$build/host.txt" "$build/port.txt"; then
    echo "FAIL: the port answers differently from the host (lines above)"
    exit 1
fi
echo "PASS: $(wc -l < "$build/port.txt") port lines, port and host alike"

# The plant: the port's handle-only initialiser with "" in place of the handle for a nil displayName.
cp "$build"/port/*.o "$build/plant/"
rm -f "$build/plant/RevenantIntents100.o"
sed 's/NSString \*name = displayName ?: (handle ?: @"");/NSString *name = displayName ?: @"";/' "$P/Intents/RevenantIntents100.m" > "$build/plant/RevenantIntents100.src.m"
if cmp -s "$P/Intents/RevenantIntents100.m" "$build/plant/RevenantIntents100.src.m"; then
    echo "FAIL: the plant edit changed nothing, so the plant is not a plant"
    exit 1
fi
xcrun clang $flags $renames $includes -c "$build/plant/RevenantIntents100.src.m" -o "$build/plant/RevenantIntents100.o"
xcrun clang $probe_flags -DPORT "$here/probe.m" "$build"/plant/*.o $frameworks -o "$build/plant-probe"
"$build/plant-probe" > "$build/plant.txt"
if diff -q "$build/host.txt" "$build/plant.txt" >/dev/null; then
    echo "FAIL: the planted port agrees with the host, so the comparison cannot fail"
    exit 1
fi
echo "PLANT: the planted port differs from the host, as it must"
