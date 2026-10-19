#!/bin/sh
# run.sh - the host's answer for the six initialisers the IntentsUI 12.0 rows name, and the port's answer for the same
# six, from one probe source (probe.m).
#
# The host build links the system's IntentsUI (Catalyst, from iOSSupport) and nothing of the port, and is compared with
# expected.txt, the golden answer. The port build (-DPORT) links the port's objects: RevenantIntentsUI120.m and
# RevenantIntentsUIHostedView.m, with the INImage files and the Intents objects they need. Its classes are compiled under
# renamed symbols (RevenantHostINUIAddVoiceShortcutButton and so on), because two classes of one name in one process answer
# for each other. The diff of the two is the verdict.
#
# The plant: a category on the button that answers nil for -init. Its diff against the host must be non-empty, or the
# comparison cannot fail.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
P=${PORT_DIR:-$here/../../../../packages/a/apple-backports}
CODING=$P/../../c/revenant-coding/files
build=${INTENTSUI_INIT_BUILD:-$(runs_fresh revenant-intentsui-init)}
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
flags="$target -fobjc-arc -fvisibility=hidden -w -DREVENANT_HOST_BUILD"
probe_flags="$target -fno-objc-arc -fvisibility=hidden -w"
frameworks="-framework Foundation -framework UIKit -framework CoreGraphics -framework EventKit -framework Intents -framework IntentsUI"
includes="-I$P/Intents -I$P/IntentsUI -I$CODING"
sources="$CODING/RevenantCoding.m $P/Intents/RevenantIntentsStore.m $P/Intents/RevenantIntents100.m $P/Intents/IN10_0_1.m $P/Intents/IN11_0.m $P/IntentsUI/RevenantIntentsUI120.m $P/IntentsUI/RevenantIntentsUIHostedView.m $P/IntentsUI/INImage+IntentsUI100.m $P/IntentsUI/INImage+IntentsUI110.m"

# The host: the system's IntentsUI, nothing of the port, against the golden answer.
mkdir -p "$build/plain" "$build/port" "$build/plant"
xcrun clang $probe_flags "$here/probe.m" $frameworks -o "$build/host"
"$build/host" > "$build/host.txt"
if ! diff -u "$here/expected.txt" "$build/host.txt"; then
    echo "FAIL: the host answers differently from expected.txt (lines above)"
    exit 1
fi
echo "PASS: $(wc -l < "$build/host.txt") host lines, the golden answer"

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
if ! "$build/port-probe" > "$build/port.txt"; then
    echo "FAIL: the port probe stopped with status $?"
    exit 1
fi
if ! diff -u "$build/host.txt" "$build/port.txt"; then
    echo "FAIL: the port answers differently from the host (lines above)"
    exit 1
fi
echo "PASS: $(wc -l < "$build/port.txt") port lines, port and host alike"

# The plant: a category on the port's button that answers nil for -init. Compiled with the same renames, so it extends
# the renamed class; its diff against the host must be non-empty.
cat > "$build/plant/plant.m" <<'PLANT'
#import <IntentsUI/IntentsUI.h>
@implementation INUIAddVoiceShortcutButton (RevenantPlant)
- (instancetype)init
{
    return nil;
}
@end
PLANT
cp "$build"/port/*.o "$build/plant/"
xcrun clang $flags $renames $includes -c "$build/plant/plant.m" -o "$build/plant/plant.o"
xcrun clang $probe_flags -DPORT "$here/probe.m" "$build"/plant/*.o $frameworks -o "$build/plant-probe"
# A planted probe that stops is a difference too, so its status is read, not swallowed.
status=0
"$build/plant-probe" > "$build/plant.txt" || status=$?
if [ "$status" -ne 0 ]; then
    echo "PLANT: the planted port stopped with status $status, which differs from the host, as it must"
    exit 0
fi
if diff -q "$build/host.txt" "$build/plant.txt" >/dev/null; then
    echo "FAIL: the planted port agrees with the host, so the comparison cannot fail"
    exit 1
fi
echo "PLANT: the planted port differs from the host, as it must"
