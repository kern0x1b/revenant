#!/bin/sh
# run.sh - the INImage bridge of IntentsUI (imageWithUIImage:, imageWithCGImage:, imageSizeForIntentResponse: and
# -fetchUIImageWithCompletion:) answered by the host's own Intents and by the port, one probe source.
#
# probe.m is built twice. The host build links the system's Intents and IntentsUI and nothing of the port.
# The port build (-DPORT) links the port's objects for the four members: CharonIntents100.m with the store and
# the coding it needs, and the two IntentsUI INImage files. Its classes are compiled under renamed symbols
# (CharonHostINImage and so on), as tests/backports/host/usernotifications does: UIKit loads the system's
# Intents at run time, and two INImage classes in one process answer for each other.
#
# Two guards keep the diff honest:
#   * each build checks which image INImage was loaded from (class_getImageName) and stops with status 2 if it
#     is the wrong one: the host build must have the system's Intents, the port build must not;
#   * the plant swaps the port's INImage+IntentsUI100 object for one that answers 61 instead of 60 for
#     imageSizeForIntentResponse:, and its diff must be non-empty. A comparison that cannot fail is not guarding
#     anything, so the script stops if the planted build agrees with the host.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
P=${PORT_DIR:-$here/../../../../packages/a/apple-backports}
CODING=$P/../../c/charon-coding/files
build=${INIMAGE_BUILD:-$(runs_fresh charon-inimage)}
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
flags="-fobjc-arc -fvisibility=hidden -w -DCHARON_HOST_BUILD"
frameworks="-framework Foundation -framework UIKit -framework CoreGraphics -framework EventKit -framework Intents"
includes="-I$P/Intents -I$P/IntentsUI -I$CODING"
sources="$CODING/CharonCoding.m $P/Intents/CharonIntentsStore.m $P/Intents/CharonIntents100.m $P/Intents/IN11_0.m $P/IntentsUI/INImage+IntentsUI100.m $P/IntentsUI/INImage+IntentsUI110.m"

# The port's objects, under renamed class symbols. First compiled plain, to read which classes they define.
mkdir -p "$build/plain" "$build/port"
for source in $sources; do
    xcrun clang $target $flags $includes -c "$source" -o "$build/plain/$(basename "$source" .m).o"
done
renames=""
for name in $(xcrun nm -gU "$build"/plain/*.o | awk 'NF == 3 {print $3}' | grep -E '^_OBJC_CLASS_\$_' | sed -e 's/^_OBJC_CLASS_\$_//' | sort -u); do
    renames="$renames -D$name=CharonHost$name"
done
for source in $sources; do
    xcrun clang $target $flags $renames $includes -c "$source" -o "$build/port/$(basename "$source" .m).o"
done

# The host: the system's Intents and IntentsUI, nothing of the port.
xcrun clang $target $flags "$here/probe.m" -framework Intents -framework IntentsUI $frameworks -o "$build/host"
xcrun clang $target $flags -DPORT "$here/probe.m" "$build"/port/*.o $frameworks -o "$build/port-probe"

"$build/host" > "$build/host.txt" || { cat "$build/host.txt"; echo "FAIL: the host probe stopped with status $?"; exit 1; }
"$build/port-probe" > "$build/port.txt" || { cat "$build/port.txt"; echo "FAIL: the port probe stopped with status $?"; exit 1; }
echo "host   $(wc -l < "$build/host.txt") lines"
echo "port   $(wc -l < "$build/port.txt") lines"
if ! diff -u "$build/host.txt" "$build/port.txt"; then
    echo "FAIL: the port answers differently from the host (lines above)"
    exit 1
fi
echo "PASS: $(wc -l < "$build/host.txt") lines, port and host alike"

# The plant: the port with imageSizeForIntentResponse: answering 61, in place of the 100 object. Its diff must be non-empty.
mkdir -p "$build/plant"
cp "$build"/port/*.o "$build/plant/"
sed 's/CGSizeMake(60, 60)/CGSizeMake(61, 61)/' "$P/IntentsUI/INImage+IntentsUI100.m" > "$build/plant/INImage+IntentsUI100.src.m"
xcrun clang $target $flags $renames $includes -c "$build/plant/INImage+IntentsUI100.src.m" -o "$build/plant/INImage+IntentsUI100.o"
xcrun clang $target $flags -DPORT "$here/probe.m" "$build"/plant/*.o $frameworks -o "$build/plant-probe"
"$build/plant-probe" > "$build/plant.txt"
if diff -q "$build/host.txt" "$build/plant.txt" >/dev/null; then
    echo "FAIL: the planted port agrees with the host, so the comparison cannot fail"
    exit 1
fi
echo "PLANT: the planted port differs from the host, as it must"
