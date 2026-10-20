#!/bin/sh
# run.sh - which of SRSensorReaderDelegate's ten methods the port's reader actually sends, with the
# mutation layer that makes the answer falsifiable.
#
#   1. check_delegate.lua reads the port's own SRSensorReader.m and names all ten, SENT or NEVER
#   2. it must find exactly four SENT, exactly the failure callbacks the reader's own bodies send, each
#      carrying SensorKit's own inaccessible-data error, and the authorization answering denied
#   3. the same four read back out of the COMPILED armv7 object, which is what the linker binds
#      @selector() against and therefore what a device would exercise
#   4. four plants, each of which must turn the source check red: a send removed, a send swapped for one
#      of the six nothing should send, the authorization no longer denied, and a reader that sends
#      nothing at all - the last being the check's own control, red for a different reason than the
#      first three. The second of those is also carried through the object, so the object check has a
#      plant of its own rather than agreeing with the source check by construction
#
# WHY THIS IS NOT A DIFFERENTIAL, stated here rather than left for a reader to discover. There is no
# behavioural oracle for SRSensorReader on this machine and that is measured, not assumed: the host's own
# SensorKit.framework declares the class and implements nothing (respondsToSelector: is 0 for
# +authorizationStatus and +sharedReader), and the port's RevenantSensorKit.h cannot be compiled against
# the host's newer SDK at all - clang answers "typedef redefinition with different types ('NSInteger'
# vs 'enum SRAcousticSettingsSampleLifetime')" for the fifteen enumerations it redeclares, because the
# host's SensorKit spells them NS_ENUM. The armv7 object is the port's own answer, built the way the
# 6.1.3 band builds it.
#
# What this does NOT claim: that a device reaches a subscriber. The call test on the emulator has not
# been run and facts/SensorKit/SensorKit.md says so.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
. "$here/../../common/generated.sh"
ensure_generated "$here" SensorKit
appledir=${APPLEDIR:-$here/../../../../packages/frameworks/apple-backports}
reader=${READER:-$appledir/SensorKit/SRSensorReader.m}
build=${BUILD:-$(runs_fresh revenant-sensorkit-reader)}
mkdir -p "$build"

# The toolchain the armv7 band is built with, out of the shared store the whole build depends on. A
# missing one FAILS the run rather than skipping the object half: a check that did not run is not a
# check that passed, and a page whose number comes from a step that was quietly skipped is the defect
# this family already has one of.
armv7() {
    cc=$(ls -d "$HOME"/.xmake/packages/l/llvm/*/*/bin/clang 2>/dev/null | head -1)
    sdk=$(ls -d "$HOME"/.xmake/packages/i/iphoneos-sdk/16.4/cccc080d0cbe42c2a85b1369aba6e290/Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS16.4.sdk 2>/dev/null | head -1)
    if [ -z "$cc" ] || [ -z "$sdk" ]; then
        echo "FAIL no pinned toolchain: expected clang under \$HOME/.xmake/packages/l/llvm/*/*/bin and an"
        echo "     iPhoneOS 16.4 SDK under \$HOME/.xmake/packages/i/iphoneos-sdk/16.4/cccc080d0cbe42c2a85b1369aba6e290/ (tools/gen/project.lua names it). The object half of"
        echo "     this check did not run, and it is half of what the facts pages take from here."
        exit 1
    fi
    "$cc" -target armv7-apple-ios6.1.3 -isysroot "$sdk" \
        -I "$appledir" -I "$appledir/SensorKit" -fobjc-arc \
        -c "$1" -o "$2" > "$build/cc.log" 2>&1 \
        || { echo "COMPILE FAILED for $1:"; cat "$build/cc.log"; return 1; }
}

echo "--- the clean run: every one of the ten, named from the source"
xmake l "$here/check_delegate.lua" "$reader"

echo "--- the clean run: the same four read back out of the compiled armv7 object"
armv7 "$reader" "$build/SRSensorReader.o"
xmake l "$here/objc_selectors.lua" "$build/SRSensorReader.o"

# A plant is a copy of the reader with one change, and every one of them must make the check red.
# The change is anchored to a line the clean run printed, so a plant that stops applying is refused
# rather than silently passing - the "MUTATION DID NOT APPLY" line below is that refusal.
survived=0

# The protocol's OWN metadata, from the same generated translation unit the build compiles from an
# implemented protocol row. This is a separate question from the reader's sends: the sends say what the
# reader does, this says what an application finds when it asks the runtime about the protocol itself.
# The generated file is reproduced here rather than guessed, so the header this step compiles is the
# header the build compiles.
echo "--- the metadata the port emits for the protocol, counted"
# The plant's header: the protocol forwarded rather than declared, which is what this header did before
# and what made it emit a protocol with no methods in it at all. The @optional marker goes with the ten
# members, or the forward declaration would not parse.
mkdir -p "$build/mutant-protocols"
sed -e 's/^@protocol SRSensorReaderDelegate <NSObject>$/@protocol SRSensorReaderDelegate;/' \
    -e '/^@optional$/,/^@end$/d' \
    "$appledir/.gen/SensorKit/RevenantSensorKitProtocols.h" > "$build/mutant-protocols/RevenantSensorKitProtocols.h"
if grep -q '^@optional$' "$build/mutant-protocols/RevenantSensorKitProtocols.h"; then
    echo "MUTATION DID NOT APPLY: the mutant header still declares the ten members"
    survived=$((survived + 1))
fi
generated() {
    mkdir -p "$1"
    cp "$2" "$1/RevenantSensorKitProtocols.h"
    {
        echo '// SensorKitBackportsProtocols14.0.m - written by modules/apple/backports.lua, not by hand.'
        echo '#import "RevenantSensorKitProtocols.h"'
        echo
        echo 'void revenant_SensorKitBackports_protocols(void) __attribute__((used));'
        echo 'void revenant_SensorKitBackports_protocols(void)'
        echo '{'
        echo '    (void)@protocol(SRSensorReaderDelegate);'
        echo '}'
    } > "$1/SensorKitBackportsProtocols14.0.m"
    xcrun clang -fobjc-arc -w -I"$1" -c "$1/SensorKitBackportsProtocols14.0.m" -o "$1/protocols.o"
    xcrun clang -fobjc-arc -w -I"$appledir/SensorKit" "$here/protocol-count.m" "$1/protocols.o" \
        -framework Foundation -o "$1/protocol-count"
}
generated "$build/protocols" "$appledir/.gen/SensorKit/RevenantSensorKitProtocols.h"
"$build/protocols/protocol-count" > "$build/protocol.out"
cat "$build/protocol.out"
xmake l "$here/check_protocol.lua" "$build/protocol.out"

echo "--- and its plant: the protocol forwarded instead of declared, which is what the header used to do"
generated "$build/protocols-mutant" "$build/mutant-protocols/RevenantSensorKitProtocols.h"
"$build/protocols-mutant/protocol-count" > "$build/protocol-mutant.out"
if xmake l "$here/check_protocol.lua" "$build/protocol-mutant.out" > "$build/protocol-mutant-cmp.out" 2>&1; then
    echo "MUTANT SURVIVED: the protocol counted the same with its ten members deleted"
    survived=$((survived + 1))
else
    echo "  caught: $(grep -m 1 '^FAIL' "$build/protocol-mutant-cmp.out" | cut -c1-110)"
    echo "  caught: $(grep -m 1 '^sensorkit-protocol:' "$build/protocol-mutant-cmp.out")"
fi
plant() {
    label=$1; from=$2; to=$3
    rm -rf "$build/mutant"; mkdir -p "$build/mutant"
    if ! xmake l "$here/../../common/replace.lua" "$reader" "$build/mutant/SRSensorReader.m" "$from" "$to"; then
        echo "MUTATION DID NOT APPLY: $label"
        survived=$((survived + 1))
        return
    fi
    if xmake l "$here/check_delegate.lua" "$build/mutant/SRSensorReader.m" > "$build/mutant.out" 2>&1; then
        echo "MUTANT SURVIVED: $label"
        survived=$((survived + 1))
    else
        echo "  caught: $(grep -m 1 '^FAIL' "$build/mutant.out" | cut -c1-110)"
        echo "  caught: $(grep -m 1 '^sensorkit-reader:' "$build/mutant.out")"
    fi
}

echo "--- the plants"

plant "a send removed: -startRecording tells nobody" \
    "        [delegate sensorReader:self startRecordingFailedWithError:[SRSensorReader storeUnavailableError]];" \
    "        (void)delegate;"

# This one goes through swap_stop.lua rather than the inline rewrite the other two use, because the
# object half below needs the same mutation and one definition of a mutation is worth more than two
# spellings of it.
rm -rf "$build/swap"; mkdir -p "$build/swap"
if ! xmake l "$here/swap_stop.lua" "$reader" "$build/swap/SRSensorReader.m"; then
    echo "MUTATION DID NOT APPLY: -stopRecording claims it stopped"
    survived=$((survived + 1))
elif xmake l "$here/check_delegate.lua" "$build/swap/SRSensorReader.m" > "$build/swap.out" 2>&1; then
    echo "MUTANT SURVIVED: a send swapped for one of the six nothing should send"
    survived=$((survived + 1))
else
    echo "  caught: $(grep -m 1 '^FAIL' "$build/swap.out" | cut -c1-110)"
    echo "  caught: $(grep -m 1 '^sensorkit-reader:' "$build/swap.out")"
fi

plant "the authorization is no longer denied" \
    "    return SRAuthorizationStatusDenied;" \
    "    return SRAuthorizationStatusNotDetermined;"

echo "--- the check's own control: a reader that sends nothing at all must not look green"
printf '@implementation SRSensorReader\n@end\n' > "$build/empty.m"
if xmake l "$here/check_delegate.lua" "$build/empty.m" > "$build/empty.out" 2>&1; then
    echo "FAIL a reader with no delegate sends at all was accepted"
    survived=$((survived + 1))
else
    echo "  caught: $(grep -m 1 '^sensorkit-reader:' "$build/empty.out")"
fi

echo "--- the object half's own plant: the same swap, compiled"
# The second plant changed which selector the reader sends. Carried through the compiler, the object's
# own __objc_methname must show it: without this the object check would only ever be agreeing with the
# source check, which is not evidence that it can fail.
rm -rf "$build/objmutant"; mkdir -p "$build/objmutant"
xmake l "$here/swap_stop.lua" "$reader" "$build/objmutant/SRSensorReader.m"
armv7 "$build/objmutant/SRSensorReader.m" "$build/objmutant/SRSensorReader.o"
if xmake l "$here/objc_selectors.lua" "$build/objmutant/SRSensorReader.o" > "$build/objmutant.out" 2>&1; then
    echo "MUTANT SURVIVED: the object still reads as clean after the send was swapped"
    survived=$((survived + 1))
else
    echo "  caught: $(grep -m 1 '^FAIL' "$build/objmutant.out" | cut -c1-110)"
    echo "  caught: $(grep -m 1 '^sensorkit-reader-object:' "$build/objmutant.out")"
fi

if [ "$survived" -ne 0 ]; then echo "$survived plants survived; this check proves nothing"; exit 1; fi
echo "sensorkit-reader: OK - 10 protocol methods declared and 4 sent, 6 plants noticed"