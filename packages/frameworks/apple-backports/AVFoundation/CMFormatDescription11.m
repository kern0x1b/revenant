#import <CoreMedia/CoreMedia.h>
#include <string.h>

#define parameterIsInvalid kCMFormatDescriptionError_InvalidParameter
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
    if (parameterSetCountOut)
        *parameterSetCountOut = complete ? declared : 0;
done:
    if (!parameterSetPointerOut && !parameterSetSizeOut)
        return 0;
    if (complete && found)
        return 0;
    return malformedRecord;
}
