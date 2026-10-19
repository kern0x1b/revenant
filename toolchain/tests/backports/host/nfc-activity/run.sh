#!/bin/sh
# run.sh - the NDEF message NSUserActivity answers for an activity no tag launched: the host (Catalyst) against the port's category,
# from one probe source (probe.m). The port's objects are the CoreNFC library's sources, compiled here and linked without the
# host's CoreNFC, which the probe does not need to name a class.
#
# The host is held to expected.txt. The plant: a port whose record is of the well-known type-name format, not the empty one.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
P=${PORT_DIR:-$here/../../../../packages/a/apple-backports}
build=${NFC_ACTIVITY_BUILD:-$(runs_fresh revenant-nfc-activity)}
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
flags="$target -fobjc-arc -fvisibility=hidden -w"
mkdir -p "$build/port" "$build/plant"

xcrun clang $flags "$here/probe.m" -framework Foundation -framework CoreNFC -o "$build/host"
"$build/host" > "$build/host.txt"
if ! diff -u "$here/expected.txt" "$build/host.txt"; then
    echo "FAIL: the host answers differently from expected.txt (lines above)"
    exit 1
fi
echo "PASS: $(wc -l < "$build/host.txt" | tr -d ' ') host lines, the golden answer"

objects=""
for source in "$P"/CoreNFC/*.m; do
    name=$(basename "$source" .m)
    xcrun clang $flags -c "$source" -o "$build/port/$name.o"
    objects="$objects $build/port/$name.o"
done
xcrun clang $flags "$here/probe.m" $objects -framework Foundation -o "$build/port-probe"
"$build/port-probe" > "$build/port.txt"
if ! diff -u "$build/host.txt" "$build/port.txt"; then
    echo "FAIL: the port answers differently from the host (lines above)"
    exit 1
fi
echo "PASS: $(wc -l < "$build/port.txt" | tr -d ' ') lines alike, the port's default message is the host's"

sed 's/NFCTypeNameFormatEmpty/NFCTypeNameFormatNFCWellKnown/' "$P/CoreNFC/NSUserActivity+CoreNFC.m" > "$build/plant/NSUserActivity+CoreNFC.m"
if cmp -s "$P/CoreNFC/NSUserActivity+CoreNFC.m" "$build/plant/NSUserActivity+CoreNFC.m"; then
    echo "FAIL: the plant edit changed nothing, so the plant is not a plant"
    exit 1
fi
plant_objects=""
for source in "$P"/CoreNFC/*.m; do
    name=$(basename "$source" .m)
    if [ "$name" = "NSUserActivity+CoreNFC" ]; then
        xcrun clang $flags -c "$build/plant/NSUserActivity+CoreNFC.m" -o "$build/plant/$name.o"
        plant_objects="$plant_objects $build/plant/$name.o"
    else
        plant_objects="$plant_objects $build/port/$name.o"
    fi
done
xcrun clang $flags "$here/probe.m" $plant_objects -framework Foundation -o "$build/plant-probe"
status=0
"$build/plant-probe" > "$build/plant.txt" || status=$?
echo "plant probe exit $status (nonzero is what a red plant gives)"
if diff -q "$build/host.txt" "$build/plant.txt" >/dev/null; then
    echo "FAIL: the planted port agrees with the host, so the comparison cannot fail"
    exit 1
fi
echo "PLANT: the planted port differs from the host, as it must"
