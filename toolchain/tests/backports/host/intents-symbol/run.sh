#!/bin/sh
# run.sh - the port's +[INImage systemImageNamed:] against the host's, name by name, from one probe source (probe.m).
#
# The names are the 549 the UIKit band draws (tests/backports/host/uikit2/symbols-names.txt, read where it is, not
# copied) and a few names nothing draws. The host build links the system's Intents and UIKit. The port build compiles
# the port's CharonIntents100.m and the objects it needs with CHARON_HOST_BUILD and their classes renamed CharonHost*,
# and links the system's UIKit, which is where +[UIImage systemImageNamed:] lives in this process. The two runs must
# print the same lines. The plant: a port whose INImage answers nil for every name; its run must differ.
#
# What this shows: INImage answers the names UIImage answers, in the one process that has both. The table itself is
# the UIKit band's (tests/backports/host/uikit2, the symbols group); this test does not repeat it.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
P=${PORT_DIR:-$here/../../../../packages/a/apple-backports}
CODING=$P/../../c/charon-coding/files
build=${INTENTS_SYMBOL_BUILD:-$(runs_fresh charon-intents-symbol)}
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
flags="$target -fobjc-arc -fvisibility=hidden -w -DCHARON_HOST_BUILD"
probe_flags="$target -fno-objc-arc -fvisibility=hidden -w"
frameworks="-framework Foundation -framework UIKit -framework CoreGraphics -framework EventKit -framework Intents"
includes="-I$P/Intents -I$CODING"
sources="$CODING/CharonCoding.m $P/Intents/CharonIntentsStore.m $P/Intents/CharonIntents100.m $P/Intents/IN10_0_1.m $P/Intents/IN11_0.m"

names="$build/names.txt"
cat "$here/../uikit2/symbols-names.txt" > "$names"
printf 'charon.no-such-symbol\nzz.not.a.symbol\n \n' >> "$names"

# The host: the system's Intents and UIKit. Its UIImage column is the oracle: the port's INImage must answer where
# UIImage answers, and nowhere else. The host's own INImage column is not the oracle: the system's INImage answers an
# image for any non-empty name, which the port does not do (facts/Intents/Intents.md, "+[INImage systemImageNamed:]").
xcrun clang $probe_flags -framework Foundation -framework UIKit -framework Intents "$here/probe.m" -o "$build/host"
"$build/host" "$names" > "$build/host.txt"
if ! grep -q 'UIImage YES' "$build/host.txt"; then
    echo "FAIL: the host's UIImage answers nil for every name, so the comparison has nothing to compare"
    exit 1
fi
awk -F'\t' '{u = $2; sub("UIImage ", "", u); print $1 "\t" $2 "\tINImage " u}' "$build/host.txt" > "$build/expected.txt"
echo "NOTE: the host's own INImage answers an image for $(grep -c 'UIImage NO.*INImage YES' "$build/host.txt") name(s) UIImage does not draw"

# The port's objects, first compiled plain, to read which classes they define.
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
xcrun clang $probe_flags -DPORT "$here/probe.m" "$build"/port/*.o $frameworks -o "$build/port-probe"
"$build/port-probe" "$names" > "$build/port.txt" || { cat "$build/port.txt"; echo "FAIL: the port probe stopped with status $?"; exit 1; }
if ! diff -u "$build/expected.txt" "$build/port.txt"; then
    echo "FAIL: the port's INImage answers differently from the host's UIImage (lines above)"
    exit 1
fi
echo "PASS: $(wc -l < "$build/port.txt") names, the port's INImage answers where the host's UIImage does, and nowhere else"

# The plant: the port's INImage answers nil for every name.
cp "$build"/port/*.o "$build/plant/"
rm -f "$build/plant/CharonIntents100.o"
sed 's/UIImage \*image = \[UIImage systemImageNamed:name\];/UIImage *image = nil;/' "$P/Intents/CharonIntents100.m" > "$build/plant/CharonIntents100.src.m"
if cmp -s "$P/Intents/CharonIntents100.m" "$build/plant/CharonIntents100.src.m"; then
    echo "FAIL: the plant edit changed nothing, so the plant is not a plant"
    exit 1
fi
xcrun clang $flags $renames $includes -c "$build/plant/CharonIntents100.src.m" -o "$build/plant/CharonIntents100.o"
xcrun clang $probe_flags -DPORT "$here/probe.m" "$build"/plant/*.o $frameworks -o "$build/plant-probe"
"$build/plant-probe" "$names" > "$build/plant.txt"
if diff -q "$build/expected.txt" "$build/plant.txt" >/dev/null; then
    echo "FAIL: the planted port agrees with the host, so the comparison cannot fail"
    exit 1
fi
echo "PLANT: the planted port differs from the host, as it must"
