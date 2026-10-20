#!/bin/sh
# run.sh - the readers of the resolution results the host's runtime answers for INIntentResolutionResult's factories
# (+unsupportedWithReason:, +confirmationRequiredWithItemToConfirm:forReason:, and the three factories the header
# declares), asked of the host's own Intents and of the port's objects, from one probe source (probe.m).
#
# The host build links the system's Intents and nothing of the port, is compared with expected.txt (the golden answer),
# and must answer the same on macOS as on Catalyst. The port build (-DPORT) links the port's objects:
# RevenantIntents100.m, which defines the factories and the readers, and IN10_0_1.m, which defines the subclasses the
# probe reads through (INIntegerResolutionResult, INSpeakableStringResolutionResult). Its classes are compiled under
# renamed symbols (RevenantHostINIntentResolutionResult and so on), because two Intents classes of one name in one process
# answer for each other. The diff of the port and the host is the verdict.
#
# The plant: a port whose +unsupportedWithReason: drops the reason. Its diff against the host must be non-empty, or the
# comparison cannot fail.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
P=${PORT_DIR:-$here/../../../../packages/frameworks/apple-backports}
CODING=$P/../../runtimes/revenant-coding/files
build=${RESOLUTION_REASON_BUILD:-$(runs_fresh revenant-intents-resolution-reason)}
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
flags="$target -fobjc-arc -fvisibility=hidden -w -DREVENANT_HOST_BUILD"
probe_flags="$target -fno-objc-arc -fvisibility=hidden -w"
frameworks="-framework Foundation -framework UIKit -framework CoreGraphics -framework EventKit -framework Intents"
includes="-I$P/Intents -I$CODING"
sources="$CODING/RevenantCoding.m $P/Intents/RevenantIntentsStore.m $P/Intents/RevenantIntents100.m $P/Intents/IN10_0_1.m $P/Intents/IN11_0.m"

# The host: the system's Intents, nothing of the port, against the golden answer.
mkdir -p "$build/plain" "$build/port" "$build/plant"
xcrun clang $probe_flags "$here/probe.m" -framework Foundation -framework Intents -o "$build/host"
"$build/host" > "$build/host.txt"
if ! diff -u "$here/expected.txt" "$build/host.txt"; then
    echo "FAIL: the host answers differently from expected.txt (lines above)"
    exit 1
fi
echo "PASS: $(wc -l < "$build/host.txt") host lines, the golden answer"

# The same probe on macOS, which must answer as Catalyst does: the two hosts are one answer, not two.
xcrun clang -fno-objc-arc -w -framework Foundation -framework Intents "$here/probe.m" -o "$build/host-macos"
"$build/host-macos" > "$build/host-macos.txt"
if ! diff -u "$build/host.txt" "$build/host-macos.txt"; then
    echo "FAIL: macOS and Catalyst answer differently (lines above)"
    exit 1
fi
echo "PASS: macOS and Catalyst answer alike"

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
"$build/port-probe" > "$build/port.txt" || { cat "$build/port.txt"; echo "FAIL: the port probe stopped with status $?"; exit 1; }
if ! diff -u "$build/host.txt" "$build/port.txt"; then
    echo "FAIL: the port answers differently from the host (lines above)"
    exit 1
fi
echo "PASS: $(wc -l < "$build/port.txt") port lines, port and host alike"

# The plant: the port with +unsupportedWithReason: answering without its reason (the reason written as 0).
cp "$build"/port/*.o "$build/plant/"
rm -f "$build/plant/RevenantIntents100.o"
sed 's/unsupportedReason:reason\];/unsupportedReason:0];/' "$P/Intents/RevenantIntents100.m" > "$build/plant/RevenantIntents100.src.m"
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
