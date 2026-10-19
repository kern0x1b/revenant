#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
AV=${AV:-$here/../../../../packages/a/apple-backports/AVFoundation}
BUILD=${BUILD:-$(runs_fresh revenant-coremedia7)}
mkdir -p "$BUILD"
sdk=$(xcrun --show-sdk-path)
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-availability"

# SAN=1 builds every object and the probe with AddressSanitizer, through the same flags as everything
# else here, and is how a walk off the end of a port's own array gets named instead of guessed at.
san=""
[ "${SAN:-0}" = "1" ] && san="-fsanitize=address -g -fno-omit-frame-pointer"
renames="-DCMTimeMultiplyByRatio=RevenantHostCMTimeMultiplyByRatio"
renames="$renames -DCMSampleBufferCopyPCMDataIntoAudioBufferList=RevenantHostCMSampleBufferCopyPCMDataIntoAudioBufferList"
renames="$renames -DCMSampleBufferCreateReady=RevenantHostCMSampleBufferCreateReady"
renames="$renames -DCMSampleBufferCreateReadyWithImageBuffer=RevenantHostCMSampleBufferCreateReadyWithImageBuffer"
renames="$renames -DCMAudioSampleBufferCreateReadyWithPacketDescriptions=RevenantHostCMAudioSampleBufferCreateReadyWithPacketDescriptions"
renames="$renames -DCMSampleBufferCallBlockForEachSample=RevenantHostCMSampleBufferCallBlockForEachSample"
renames="$renames -DCMSampleBufferCreateWithMakeDataReadyHandler=RevenantHostCMSampleBufferCreateWithMakeDataReadyHandler"
renames="$renames -DCMSampleBufferCreateForImageBufferWithMakeDataReadyHandler=RevenantHostCMSampleBufferCreateForImageBufferWithMakeDataReadyHandler"
renames="$renames -DCMAudioSampleBufferCreateWithPacketDescriptionsAndMakeDataReadyHandler=RevenantHostCMAudioSampleBufferCreateWithPacketDescriptionsAndMakeDataReadyHandler"
renames="$renames -DCMVideoFormatDescriptionGetHEVCParameterSetAtIndex=RevenantHostCMVideoFormatDescriptionGetHEVCParameterSetAtIndex"
renames="$renames $(cat "$here/formatdescription-renames.txt")"
for object in "$AV"/*.m; do
    case "$(basename "$object")" in CMFormatDescription*|CMTime71*|CMSampleBuffer*) ;; *) continue ;; esac
    xcrun clang -fobjc-arc $quiet $renames -c $san "$object" -o "$BUILD/$(basename "$object" .m).o"
done
for test in timeratio pcmdata createready constants; do
    if [ ! -f "$here/$test.m" ]; then
        echo "note: $here/$test.m is missing, so its checks are not run"
        exit 1
    fi
    xcrun clang -fobjc-arc $quiet $san "$here/$test.m" "$BUILD"/*.o -framework CoreMedia -framework CoreVideo -framework AudioToolbox -framework Foundation -o "$BUILD/$test"
    "$BUILD/$test"
done
# The CMTagCollection family: the port's file as its own image, so its names are reached through
# dlopen(RTLD_LOCAL | RTLD_FIRST) while the probe's own calls reach the host's CoreMedia. No renaming,
# no -D, and no system header is touched.
xcrun clang -c -fobjc-arc $quiet $san -I"$AV" -o "$BUILD/RevenantCMTagSupport.o" "$AV/RevenantCMTagSupport.m"
xcrun clang -c -fobjc-arc $quiet $san -I"$AV" -o "$BUILD/CMTaggedBufferGroup17.o" "$AV/CMTaggedBufferGroup17.m"
xcrun clang -dynamiclib -fobjc-arc $quiet $san -I"$AV" -DkCMTagInvalid=port_kCMTagInvalid \
    -DkCMTagCategoryKey=port_kCMTagCategoryKey -DkCMTagValueKey=port_kCMTagValueKey -DkCMTagDataTypeKey=port_kCMTagDataTypeKey \
    -framework Foundation -framework CoreMedia -framework CoreVideo \
    -o "$BUILD/libRevenantCMTag.dylib" "$AV/CMTagCollection17.m" "$AV/CMTag17.m" "$AV/CMTaggedBufferGroupDescription17.m" "$BUILD/RevenantCMTagSupport.o" "$BUILD/CMTaggedBufferGroup17.o"
xcrun clang -fobjc-arc $quiet $san -I"$AV" "$here/tagcollectionimage.m" -framework CoreMedia -framework CoreVideo -framework Foundation \
    -o "$BUILD/tagcollectionimage"
"$BUILD/tagcollectionimage" "$BUILD/libRevenantCMTag.dylib"
xcrun clang -fobjc-arc $quiet $san "$here/cmtag.m" -framework CoreMedia -framework Foundation \
    -o "$BUILD/cmtag"
"$BUILD/cmtag" "$BUILD/libRevenantCMTag.dylib"
# The group's format description and the two sample-buffer functions. Same shape as cmtag.m: the port's
# file is its own image reached through dlopen(RTLD_LOCAL | RTLD_FIRST), so nothing is renamed and no
# system header is touched. The chain is built twice - once from the host's collections, once from the
# port's - because Matches reads a representation only its own side wrote.
xcrun clang -fobjc-arc $quiet $san -I"$AV" "$here/taggedgroupdescription.m" \
    -framework CoreMedia -framework CoreVideo -framework Foundation -o "$BUILD/taggedgroupdescription"
"$BUILD/taggedgroupdescription" "$BUILD/libRevenantCMTag.dylib"
# The HEVC reader is held against a real hvcC - the record of an ffmpeg/libx265 stream, committed here
# beside the test that reads it - every truncation of it, and single-byte flips of it. Under
# AddressSanitizer, because a reader that walks off the end of a record is exactly the bug this is for.
hvc="$here/hvcC-x265.bin"
if [ ! -f "$hvc" ]; then
    echo "note: the HEVC oracle $hvc is missing, so CMVideoFormatDescriptionGetHEVCParameterSetAtIndex is unchecked"
    exit 1
fi
xcrun clang -fobjc-arc -w -fsanitize=address -g $quiet "$here/hevcreader.m" "$BUILD/CMFormatDescription11.o" \
    -framework CoreMedia -framework CoreVideo -framework Foundation -o "$BUILD/hevcreader"
"$BUILD/hevcreader" "$hvc"
