#import <CoreMedia/CoreMedia.h>
#include <string.h>

// The HEVC parameter-set reader of iOS 11, over the hvcC record the release already stores: 23 bytes of
// fixed part with numOfArrays at byte 22, then per array a type byte and a 16-bit count of NAL units,
// then per NAL unit a 16-bit length and that many bytes. Measured against the host's own reader over
// the hvcC of a real x265 stream and over every truncation of it
// (facts/CoreMedia/HEVCParameterSets.md).

#define parameterIsInvalid kCMFormatDescriptionError_InvalidParameter
// -12712 is what the host answers for a record it cannot walk; no SDK on this machine names it, and
// CMVideoFormatDescription7.m carries the same value for the H.264 reader.
#define malformedRecord ((OSStatus)-12712)

OSStatus CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(CMFormatDescriptionRef videoDesc, size_t parameterSetIndex,
                                                            const uint8_t **parameterSetPointerOut, size_t *parameterSetSizeOut,
                                                            size_t *parameterSetCountOut, int *NALUnitHeaderLengthOut)
{
    if (!videoDesc || CMFormatDescriptionGetMediaType(videoDesc) != kCMMediaType_Video ||
        CMFormatDescriptionGetMediaSubType(videoDesc) != kCMVideoCodecType_HEVC)
        return parameterIsInvalid;
    CFDictionaryRef atoms = CMFormatDescriptionGetExtension(videoDesc, kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms);
    CFDataRef record = atoms && CFGetTypeID(atoms) == CFDictionaryGetTypeID() ? CFDictionaryGetValue(atoms, CFSTR("hvcC")) : NULL;
    if (!record || CFGetTypeID(record) != CFDataGetTypeID())
        return parameterIsInvalid;
    const uint8_t *bytes = CFDataGetBytePtr(record);
    size_t length = (size_t)CFDataGetLength(record);
    if (parameterSetCountOut)
        *parameterSetCountOut = 0;
    if (NALUnitHeaderLengthOut)
        *NALUnitHeaderLengthOut = 0;
    if (parameterSetPointerOut)
        *parameterSetPointerOut = NULL;
    if (parameterSetSizeOut)
        *parameterSetSizeOut = 0;
    if (length < 23)
        return malformedRecord;
    if (bytes[0] != 1)
        return malformedRecord;
    if (NALUnitHeaderLengthOut)
        *NALUnitHeaderLengthOut = (bytes[21] & 3) + 1;
    size_t seen = 0;
    size_t at = 23;
    int arrays = bytes[22];
    BOOL complete = YES, found = NO;
    size_t declared = 0;
    for (int array = 0; array < arrays; array++) {
        if (at + 3 > length) {
            complete = NO;
            break;
        }
        size_t units = ((size_t)bytes[at + 1] << 8) | bytes[at + 2];
        declared += units;
        at += 3;
        for (size_t unit = 0; unit < units; unit++) {
            if (at + 2 > length) {
                complete = NO;
                goto done;
            }
            size_t size = ((size_t)bytes[at] << 8) | bytes[at + 1];
            at += 2;
            if (at + size > length) {
                complete = NO;
                goto done;
            }
            if (seen == parameterSetIndex) {
                found = YES;
                if (parameterSetPointerOut)
                    *parameterSetPointerOut = bytes + at;
                if (parameterSetSizeOut)
                    *parameterSetSizeOut = size;
            }
            seen++;
            at += size;
        }
    }
    // Measured on the host: a record cut inside an array reports no count at all, and a record that
    // walks reports the number of NAL units its array headers declare.
    if (parameterSetCountOut)
        *parameterSetCountOut = complete ? declared : 0;
done:
    // A record the walk could not finish reports no count: the host answers a truncated record with
    // count 0 even though the header length, which only needs the fixed part, is still reported. A
    // record it can walk reports the count whatever index was asked for.
    // Measured, and the same rule the H.264 reader in CMVideoFormatDescription7.m carries: a call that
    // asks for neither the pointer nor the size is answered 0 whatever index it is given - the host
    // answers 0 for index 7 of the x265 record with only the count asked for, and 4 for index 0.
    if (!parameterSetPointerOut && !parameterSetSizeOut)
        return 0;
    // A record the walk could not finish is refused even when the index asked for was already reached:
    // the host answers -12712 for a record cut after the first NAL unit, with that unit's size filled in.
    if (complete && found)
        return 0;
    return malformedRecord;
}
