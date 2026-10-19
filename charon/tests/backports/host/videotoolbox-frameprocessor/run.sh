#!/bin/sh
# run.sh - the VideoToolbox frame processor, held to what the host's own VideoToolbox answers and to
# what the port's compiled armv7 objects carry.
#
#   1. host-answers.m asks the HOST: the error domain's string, the fourteen error codes, what
#      +new and -init do on the sixteen classes SDK 26.2 marks NS_UNAVAILABLE (through objc_msgSend,
#      because a bracketed call will not compile against the annotation), and what +isSupported says.
#   2. check_port.py holds the PORT to all of it, and to the registry: the domain string in the
#      compiled object rather than in the source, the fourteen code values in the port's own header,
#      the six VTFrameProcessor methods in VTFrameProcessor.o, the two methods the other two classes
#      gained, and the NS_UNAVAILABLE classes carrying neither -init nor +new.
#   3. three plants, each of which must turn step 2 red: an error code mistyped in the header, the
#      error domain's string written from the constant's name instead of measured, and an NS_UNAVAILABLE
#      class given an -init.
#   4. the check's own control: an object carrying none of the six must not look green. Six and not seven
#      because -[VTFrameProcessor init] is not one of the six: Apple's class implements no -init of its
#      own, so the port's must not either, and its -init row is implemented by inheritance from NSObject.
#      The empty object trips six assertions rather than seven.
#
# WHAT IT DELIBERATELY DOES NOT ASSERT: that +isSupported answers what the host answers. This host is an
# M4 Pro with the Neural Engine these processors need and answers 1; the port answers NO because no
# armv7 release has one. That is the documented behaviour for hardware a device lacks, and a check that
# demanded the two agree would be demanding a lie.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
appledir=${APPLEDIR:-$here/../../../../packages/a/apple-backports}
build=${BUILD:-$(runs_fresh charon-videotoolbox-frameprocessor)}
mkdir -p "$build"

cc=$(ls -d "$HOME"/.xmake/packages/l/llvm/*/*/bin/clang 2>/dev/null | head -1)
# The SDK is found by walking the store's own layout rather than by a fixed version: the package keeps
# one directory per recipe version and one hashed directory per install under it, so the glob a fixed
# version needs has to name both. mediaplayeritem/run.sh walks it the same way.
sdk=$(ls -d "$HOME"/.xmake/packages/i/iphoneos-sdk/*/*/Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS*.sdk 2>/dev/null | head -1)
if [ -z "$cc" ] || [ -z "$sdk" ]; then
    echo "FAIL no pinned toolchain: expected clang under \$HOME/.xmake/packages/l/llvm/*/*/bin and an"
    echo "     iPhoneOS SDK under \$HOME/.xmake/packages/i/iphoneos-sdk/*/*/Developer.app/.../iPhoneOS*.sdk."
    echo "     The object half of this check did not run, and it is half of what the facts pages take"
    echo "     from here."
    exit 1
fi
# The compiler's own diagnostics go to a file rather than to /dev/null: a compile that fails has to say
# why, and "did not build" is not a diagnosis.
armv7() {
    "$cc" -target armv7-apple-ios6.1.3 -isysroot "$sdk" \
        -I "$appledir" -I "$appledir/VideoToolbox" -fobjc-arc -c "$1" -o "$2" \
        > "$build/cc.log" 2>&1 || { echo "COMPILE FAILED for $1:"; cat "$build/cc.log"; return 1; }
}

# Every source this series touches, named as it is on disk. VTMotionBlurConfiguration is NOT here and
# there is no VTMotionBlurConfiguration.m: VideoToolboxValue26.m is the object that carries that class,
# so check_port.py reads $build/VideoToolboxValue26.o for it. Naming a file the port never wrote would
# make this check fail on its own harness.
# The unit whose object a header plant replaces. A header plant mutates nothing on disk under its own
# name, so it needs a unit to rebuild; this is the one that carries the header's codes.
ONE=VTFrameProcessorErrors26_0
UNITS="VTFrameProcessor VTFrameProcessorErrors26_0 VTHDRPerFrameMetadataGenerationSession18_0 VTFrameProcessorFrame VTFrameProcessorOpticalFlow \
VTFrameRateConversionConfiguration VTFrameRateConversionParameters \
VTLowLatencyFrameInterpolationConfiguration VTLowLatencyFrameInterpolationParameters \
VTLowLatencySuperResolutionScalerConfiguration VTLowLatencySuperResolutionScalerParameters \
VTMotionBlurParameters VTOpticalFlowConfiguration VTOpticalFlowParameters \
VTSuperResolutionScalerConfiguration VTSuperResolutionScalerParameters \
VTTemporalNoiseFilterConfiguration VTTemporalNoiseFilterParameters VideoToolboxValue26"
for unit in $UNITS; do
    armv7 "$appledir/VideoToolbox/$unit.m" "$build/$unit.o"
done

echo "--- what the host's own VideoToolbox answers"
xcrun clang -fobjc-arc -w "$here/host-answers.m" -framework Foundation -framework VideoToolbox \
    -o "$build/host-answers"
"$build/host-answers" > "$build/host.out"
grep '^CONTROL' "$build/host.out" || { echo "FAIL the host reader printed no control line"; exit 1; }

echo "--- what the port answers: the source, the compiled armv7 objects and the registry"
xmake l "$here/check_port.lua" "$build/host.out" "$appledir" "$build"

survived=0
plant() {
    label=$1; which=$2; from=$3; to=$4
    # The plant may be in a .m or in the header, so which one it names decides what is mutated and the
    # whole tree is copied either way - a mutated header that every unit then reads is the only way a
    # header plant can turn the check red.
    case $which in
        *.m) unit=${which%.m}; header= ;;
        *)   unit=; header=$which ;;
    esac
    rm -rf "$build/mutant"; mkdir -p "$build/mutant/VideoToolbox" "$build/mutant/registry/VideoToolbox"
    cp "$appledir/CharonValueStore.h" "$build/mutant/CharonValueStore.h"
    cp "$appledir/VideoToolbox/CharonVideoToolbox.h" "$build/mutant/VideoToolbox/CharonVideoToolbox.h"
    cp "$appledir/VideoToolbox/VideoToolboxValueStore.h" "$build/mutant/VideoToolbox/VideoToolboxValueStore.h"
    cp "$appledir/registry/VideoToolbox/ios26.json" "$build/mutant/registry/VideoToolbox/ios26.json"
    for name in $UNITS; do
        cp "$appledir/VideoToolbox/$name.m" "$build/mutant/VideoToolbox/"
    done
    target=$build/mutant/VideoToolbox/$which
    if ! xmake l "$here/plant.lua" "$target" "$from" "$to"; then
        echo "MUTATION DID NOT APPLY: $label"
        survived=$((survived + 1))
        return
    fi
    # A header plant changes what every unit compiles, so the object that has to be rebuilt is the one
    # the check reads; a .m plant changes only its own.
    rebuilt=${unit:-$ONE}
    if armv7 "$build/mutant/VideoToolbox/$rebuilt.m" "$build/mutant/$rebuilt.o"; then
        :
    else
        echo "MUTANT DID NOT BUILD, which is not the same as being noticed: $label"
        survived=$((survived + 1))
        return
    fi
    # The mutated object replaces only its own, so the rest in the build directory are the port's own and
    # the mutant is the only thing that changed.
    cp "$build/$rebuilt.o" "$build/$rebuilt.o.saved"
    cp "$build/mutant/$rebuilt.o" "$build/$rebuilt.o"
    if xmake l "$here/check_port.lua" "$build/host.out" "$build/mutant" "$build" \
        > "$build/mutant.out" 2>&1; then
        echo "MUTANT SURVIVED: $label"
        survived=$((survived + 1))
    else
        echo "  caught: $(grep -m 1 '^FAIL' "$build/mutant.out" | cut -c1-110)"
    fi
    cp "$build/$rebuilt.o.saved" "$build/$rebuilt.o"
    rm -f "$build/$rebuilt.o.saved"
}

echo "--- the plants"

plant "an error code mistyped by one digit" CharonVideoToolbox.h \
    "VTFrameProcessorRevisionNotSupported = -19739," \
    "VTFrameProcessorRevisionNotSupported = -19738,"

plant "the error domain written from the constant's own name instead of measured" \
    VTFrameProcessorErrors26_0.m \
    'NSErrorDomain const VTFrameProcessorErrorDomain = @"VTFrameProcessorErrorDomain";' \
    'NSErrorDomain const VTFrameProcessorErrorDomain = @"VTVideoToolboxFrameProcessor";'

plant "an NS_UNAVAILABLE class given an -init" VTFrameProcessorFrame.m \
    "- (CVPixelBufferRef)buffer" \
    "- (instancetype)init { return [super init]; }

- (CVPixelBufferRef)buffer"

echo "--- the check's own control: an object carrying none of the six must not look green"
cp "$build/VTFrameProcessor.o" "$build/VTFrameProcessor.o.saved"
: > "$build/VTFrameProcessor.o"
if xmake l "$here/check_port.lua" "$build/host.out" "$appledir" "$build" > "$build/empty.out" 2>&1; then
    echo "FAIL an object carrying none of the six selectors was accepted"
    survived=$((survived + 1))
else
    echo "  caught: $(grep -c '^FAIL' "$build/empty.out") failures reported against the empty object"
fi
cp "$build/VTFrameProcessor.o.saved" "$build/VTFrameProcessor.o"

if [ "$survived" -ne 0 ]; then echo "$survived plants survived; this check proves nothing"; exit 1; fi
echo "videotoolbox-frameprocessor: OK - 14 codes, the measured domain string, 6 VTFrameProcessor methods"
echo "  and no -init, 2 more on the other two classes, the two protocols' accessors on 14 conforming classes,"
echo "  the HDR session's 3 functions and its measured constant, 16 NS_UNAVAILABLE classes, 3 plants caught"