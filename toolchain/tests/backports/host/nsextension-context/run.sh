#!/bin/sh
# run.sh - a fresh NSExtensionContext, asked the same questions on the host (Catalyst) and on the port's class, from one
# probe source (probe.m). The port's class is the Foundation backport's, with the IntentsUI members and the NotificationCenter
# widget members as categories in their own libraries; all three sources are built here.
#
# Three kinds of line are not compared the same way as the rest:
#   * completeRequestReturningItems:completionHandler: does not call back on the host, on a context no extension host has
#     started. The host is held to its golden (callback 0); the port calls back once with expired NO, by the ruling.
#   * the widget members are absent on the host (Catalyst has no widget host, and its NSExtensionContext has none of them).
#     The host is held to "absent"; the port answers the documented compact contract, which the harness checks by value:
#     active and largest are 0 (compact), and the maximum is the screen width by 110 points for compact and expanded.
#   * everything else is the host's, line for line, the screen width included.
#
# The plant: a port whose hostedViewMinimumAllowedSize answers 1 by 1. Its diff against the host must be non-empty.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
P=${PORT_DIR:-$here/../../../../packages/a/apple-backports}
build=${NSEXTENSION_BUILD:-$(runs_fresh revenant-nsextension-context)}
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
flags="$target -fobjc-arc -fvisibility=hidden -w -DREVENANT_HOST_BUILD"
probe_flags="$target -fno-objc-arc -fvisibility=hidden -w"
frameworks="-framework Foundation -framework UIKit -framework CoreGraphics"
sources="$P/Foundation/NSExtensionContext.m $P/IntentsUI/RevenantNSExtensionContext+IntentsUI.m $P/NotificationCenter/RevenantNSExtensionContext+NotificationCenter.m"
mkdir -p "$build/plain" "$build/port" "$build/plant"

xcrun clang $probe_flags "$here/probe.m" $frameworks -o "$build/host"
"$build/host" > "$build/host.txt"
if ! diff -u "$here/expected.txt" "$build/host.txt"; then
    echo "FAIL: the host answers differently from expected.txt (lines above)"
    exit 1
fi
echo "PASS: $(wc -l < "$build/host.txt" | tr -d ' ') host lines, the golden answer"

# The port's objects, compiled plain to read which classes they define, then under renamed symbols.
renames=""
for source in $sources; do
    xcrun clang $flags -c "$source" -o "$build/plain/$(basename "$source" .m).o"
done
for name in $(xcrun nm -gU "$build"/plain/*.o | awk 'NF == 3 {print $3}' | grep -E '^_OBJC_CLASS_\$_' | sed -e 's/^_OBJC_CLASS_\$_//' | sort -u); do
    renames="$renames -D$name=RevenantHost$name"
done
for source in $sources; do
    xcrun clang $flags $renames -c "$source" -o "$build/port/$(basename "$source" .m).o"
done
xcrun clang $probe_flags -DPORT "$here/probe.m" "$build"/port/*.o $frameworks -o "$build/port-probe"
"$build/port-probe" > "$build/port.txt"

# The comparison: the host's lines against the port's, minus the three kinds above.
grep -v -e '^completeRequest callback' -e '^widget' "$build/host.txt" > "$build/host-cmp.txt"
grep -v -e '^completeRequest callback' -e '^widget' "$build/port.txt" > "$build/port-cmp.txt"
if ! diff -u "$build/host-cmp.txt" "$build/port-cmp.txt"; then
    echo "FAIL: the port answers differently from the host (lines above)"
    exit 1
fi
if ! grep -qx 'completeRequest callback 1 expired 0' "$build/port.txt"; then
    echo "FAIL: the port's completion is not called once with expired NO, as the ruling says:"
    grep '^completeRequest callback' "$build/port.txt"
    exit 1
fi
width=$(awk '/^screen width/ {print $3}' "$build/port.txt")
for want in "widgetActiveDisplayMode 0" "widgetLargestAvailableDisplayMode 0" \
    "widgetMaximumSizeForDisplayMode:0 $width 110" "widgetMaximumSizeForDisplayMode:1 $width 110"; do
    if ! grep -qxF "$want" "$build/port.txt"; then
        echo "FAIL: the port does not answer the documented compact contract: want '$want'"
        grep '^widget' "$build/port.txt"
        exit 1
    fi
done
echo "PASS: $(wc -l < "$build/port-cmp.txt" | tr -d ' ') lines alike; the completion once, expired NO; the widget members compact, maximum $width by 110"

# The plant: the port's minimum size answers 1 by 1, in the first of the two CGSizeMake(0, 0) returns (IntentsUI's category).
awk 'BEGIN { done = 0 } /return CGSizeMake\(0, 0\);/ && !done { sub(/return CGSizeMake\(0, 0\);/, "return CGSizeMake(1, 1);"); done = 1 } { print }' \
    "$P/IntentsUI/RevenantNSExtensionContext+IntentsUI.m" > "$build/plant/plant-intentsui.m"
if cmp -s "$P/IntentsUI/RevenantNSExtensionContext+IntentsUI.m" "$build/plant/plant-intentsui.m"; then
    echo "FAIL: the plant edit changed nothing, so the plant is not a plant"
    exit 1
fi
cp "$build"/port/*.o "$build/plant/"
rm -f "$build/plant/RevenantNSExtensionContext+IntentsUI.o"
xcrun clang $flags $renames -c "$build/plant/plant-intentsui.m" -o "$build/plant/RevenantNSExtensionContext+IntentsUI.o"
xcrun clang $probe_flags -DPORT "$here/probe.m" "$build"/plant/*.o $frameworks -o "$build/plant-probe"
status=0
"$build/plant-probe" > "$build/plant.txt" || status=$?
if [ "$status" -ne 0 ]; then
    echo "PLANT: the planted port stopped with status $status, which differs from the host, as it must"
    exit 0
fi
grep -v -e '^completeRequest callback' -e '^widget' "$build/plant.txt" > "$build/plant-cmp.txt"
if diff -q "$build/host-cmp.txt" "$build/plant-cmp.txt" >/dev/null; then
    echo "FAIL: the planted port agrees with the host, so the comparison cannot fail"
    exit 1
fi
echo "PLANT: the planted port differs from the host, as it must"
