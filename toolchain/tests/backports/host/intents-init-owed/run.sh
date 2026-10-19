#!/bin/sh
# run.sh - the host's answer for -[<class> init] on the five Intents classes whose -init row is owed, and the port's
# answer for the same five, from one probe source (owed.m).
#
# owed.m is built twice. The host build links the system's Intents and nothing of the port. The port build (-DPORT)
# links the port's objects: CharonIntents100.m, which defines all five classes, with the coding and store it needs.
# Its classes are compiled under renamed symbols (CharonHostINInteraction and so on), because two Intents classes
# of one name in one process answer for each other (as tests/backports/host/inimage-bridge found).
#
# The diff is the verdict: the port's answer for each class must be the host's, line for line. Then the plant: a
# copy of the port in which INSpeakableString answers nil for -init, whose diff must be non-empty. A comparison
# that cannot fail is not guarding anything, so the script stops if the planted build agrees with the host.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
P=${PORT_DIR:-$here/../../../../packages/a/apple-backports}
CODING=$P/../../c/charon-coding/files
build=${OWED_INIT_BUILD:-$(runs_fresh charon-intents-init-owed)}
# Catalyst, as the INImage bridge is: CharonIntents100.m imports UIKit, so the port cannot be built for macOS here,
# and both builds must share one target to be linked into one probe. The host is the Catalyst Intents of iOSSupport.
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
flags="$target -fobjc-arc -fvisibility=hidden -w -DCHARON_HOST_BUILD"
# The probe is built without ARC, so it owns what it allocates: an ARC probe holding [cls alloc] in a strong local
# releases a second time when a planted -init returns nil, because an init consumes its receiver.
probe_flags="$target -fno-objc-arc -fvisibility=hidden -w"
frameworks="-framework Foundation -framework UIKit -framework CoreGraphics -framework EventKit -framework Intents"
includes="-I$P/Intents -I$CODING"
sources="$CODING/CharonCoding.m $P/Intents/CharonIntentsStore.m $P/Intents/CharonIntents100.m $P/Intents/IN11_0.m"

# The host: the system's Intents, nothing of the port.
xcrun clang $probe_flags "$here/owed.m" -framework Foundation -framework Intents -o "$build/host"

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
xcrun clang $probe_flags -DPORT "$here/owed.m" "$build"/port/*.o $frameworks -o "$build/port-probe"

"$build/host" > "$build/host-all.txt" || { cat "$build/host-all.txt"; echo "FAIL: the host probe stopped with status $?"; exit 1; }
"$build/port-probe" > "$build/port.txt" || { cat "$build/port.txt"; echo "FAIL: the port probe stopped with status $?"; exit 1; }
# The controls are the host's only: they show the reader finds an inherited -init and a declared one. They are
# checked on their own, and the diff is over the five owed classes, which both builds measure.
awk '/^control/' "$build/host-all.txt" > "$build/controls.txt"
awk '!/^control/' "$build/host-all.txt" > "$build/host.txt"
if ! grep -q '^control.INPaymentAmount.inherit.NSObject.object' "$build/controls.txt" \
    || ! grep -q '^control.INListCarsIntent.own.INListCarsIntent.object' "$build/controls.txt"; then
    cat "$build/controls.txt"
    echo "FAIL: a control reads differently from its known answer, so the reader cannot be trusted"
    exit 1
fi
echo "host   $(wc -l < "$build/host.txt") owed lines, $(wc -l < "$build/controls.txt") controls"
echo "port   $(wc -l < "$build/port.txt") owed lines"
if ! diff -u "$build/host.txt" "$build/port.txt"; then
    echo "FAIL: the port answers differently from the host (lines above)"
    exit 1
fi
echo "PASS: $(wc -l < "$build/host.txt") owed lines, port and host alike"
cat "$build/host.txt"

# The plant: the port with INSpeakableString's -init answering nil, inserted after its one @synthesize that
# anchors the class body. Its diff must be non-empty.
cp "$build"/port/*.o "$build/plant/"
rm -f "$build/plant/CharonIntents100.o"
sed '/^@synthesize spokenPhrase = _spokenPhrase;/a\
- (instancetype)init { return nil; }
' "$P/Intents/CharonIntents100.m" > "$build/plant/CharonIntents100.src.m"
xcrun clang $flags $renames $includes -c "$build/plant/CharonIntents100.src.m" -o "$build/plant/CharonIntents100.o"
xcrun clang $probe_flags -DPORT "$here/owed.m" "$build"/plant/*.o $frameworks -o "$build/plant-probe"
"$build/plant-probe" > "$build/plant.txt"
if diff -q "$build/host.txt" "$build/plant.txt" >/dev/null; then
    echo "FAIL: the planted port agrees with the host, so the comparison cannot fail"
    exit 1
fi
echo "PLANT: the planted port differs from the host, as it must"
