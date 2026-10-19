#!/bin/sh
# run.sh - what -[INDateComponentsRange initWithEKRecurrenceRule:] and its getter -[INDateComponentsRange EKRecurrenceRule]
# do, asked by probe.m on macOS and on Catalyst (the host, the golden in expected.txt), and of the port's own objects.
#
# The host runs must agree with each other and with expected.txt. The port (CHARON_HOST_BUILD, its classes renamed
# CharonHost*) must agree with the Catalyst host, line for line. The plant keeps the last weekday of a rule where the
# host keeps the first: the port's run must then differ, or the comparison cannot fail.
#
# The host's answers are the contract (facts/Intents/Intents.md, "EventKit's recurrence rule"): the getter raises for a
# range with no weekday, and keeps one day, no end and no week number, and the port does the same.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
P=${PORT_DIR:-$here/../../../../packages/a/apple-backports}
CODING=$P/../../c/charon-coding/files
build=${EK_BUILD:-$(runs_fresh charon-intents-ek)}
sdk=$(xcrun --show-sdk-path)
catalyst="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
frameworks="-framework Foundation -framework Intents -framework EventKit"
probe_flags="-fno-objc-arc -w"
flags="$catalyst -fobjc-arc -fvisibility=hidden -w -DCHARON_HOST_BUILD"
includes="-I$P/Intents -I$CODING"
sources="$CODING/CharonCoding.m $P/Intents/CharonIntentsStore.m $P/Intents/CharonIntents100.m $P/Intents/IN10_0_1.m $P/Intents/IN11_0.m"

# The host: macOS, then Catalyst. Both must match the golden, and each other.
xcrun clang $probe_flags "$here/probe.m" $frameworks -o "$build/macos"
"$build/macos" > "$build/macos.txt"
xcrun clang $probe_flags $catalyst "$here/probe.m" $frameworks -o "$build/catalyst"
"$build/catalyst" > "$build/catalyst.txt"
if ! diff -u "$here/expected.txt" "$build/macos.txt"; then
    echo "FAIL: macOS answers differently from expected.txt (lines above)"
    exit 1
fi
if ! diff -u "$build/macos.txt" "$build/catalyst.txt"; then
    echo "FAIL: Catalyst answers differently from macOS (lines above)"
    exit 1
fi
echo "PASS: $(wc -l < "$build/macos.txt") lines, macOS and Catalyst alike, the golden answer"

# The port's objects, first compiled plain, to read which classes they define; then with the renames.
mkdir -p "$build/plain" "$build/port" "$build/plant"
for source in $sources; do
    xcrun clang $flags $includes -c "$source" -o "$build/plain/$(basename "$source" .m).o"
done
renames=""
for name in $(xcrun nm -gU "$build"/plain/*.o | awk 'NF == 3 {print $3}' | grep -E '^_OBJC_CLASS_\$_' | sed -e 's/^_OBJC_CLASS_\$_//' | sort -u); do
    renames="$renames -D$name=CharonHost$name"
done
for source in $sources; do
    xcrun clang $flags $renames $includes -c "$source" -o "$build/port/$(basename "$source" .m).o"
done
xcrun clang $probe_flags -DPORT -target arm64-apple-ios15.0-macabi -isysroot "$sdk" -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" \
    "$here/probe.m" "$build"/port/*.o -framework Foundation -framework UIKit -framework CoreGraphics -framework Intents -framework EventKit -o "$build/port-probe"
"$build/port-probe" > "$build/port.txt" || { cat "$build/port.txt"; echo "FAIL: the port probe stopped with status $?"; exit 1; }
if ! diff -u "$build/catalyst.txt" "$build/port.txt"; then
    echo "FAIL: the port answers differently from the Catalyst host (lines above)"
    exit 1
fi
echo "PASS: $(wc -l < "$build/port.txt") port lines, port and Catalyst host alike"

# The plant: the port keeps the last day of the rule's days, not the first.
cp "$build"/port/*.o "$build/plant/"
rm -f "$build/plant/CharonIntents100.o"
sed 's/start.weekday = days\[0\].dayOfTheWeek;/start.weekday = days[days.count - 1].dayOfTheWeek;/' "$P/Intents/CharonIntents100.m" > "$build/plant/CharonIntents100.src.m"
if cmp -s "$P/Intents/CharonIntents100.m" "$build/plant/CharonIntents100.src.m"; then
    echo "FAIL: the plant edit changed nothing, so the plant is not a plant"
    exit 1
fi
xcrun clang $flags $renames $includes -c "$build/plant/CharonIntents100.src.m" -o "$build/plant/CharonIntents100.o"
xcrun clang $probe_flags -DPORT -target arm64-apple-ios15.0-macabi -isysroot "$sdk" -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" \
    "$here/probe.m" "$build"/plant/*.o -framework Foundation -framework UIKit -framework CoreGraphics -framework Intents -framework EventKit -o "$build/plant-probe"
status=0
"$build/plant-probe" > "$build/plant.txt" || status=$?
if [ "$status" -ne 0 ]; then
    echo "note: the planted probe exited with status $status; its output is compared as it stands"
fi
if diff -q "$build/catalyst.txt" "$build/plant.txt" >/dev/null; then
    echo "FAIL: the planted port agrees with the host, so the comparison cannot fail"
    exit 1
fi
echo "PLANT: the planted port differs from the host, as it must"
