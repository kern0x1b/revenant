#include "../revenant_impl.h"
#import <CoreMedia/CoreMedia.h>
#import <CoreMedia/CMFormatDescriptionBridge.h>
#import <CoreVideo/CoreVideo.h>
#include <stdint.h>
#include <string.h>

typedef struct {
    const uint8_t *nal;
    size_t size;
    size_t index;
    unsigned zeros;
    uint32_t byte;
    unsigned bits;
    BOOL overrun;
} RevenantHEVCReader;

typedef struct {
    uint32_t width;
    uint32_t height;
    uint32_t chromaFormat;
    uint32_t bitDepthLuma;
    uint32_t bitDepthChroma;
    BOOL aspectRatioPresent;
    uint32_t aspectRatioIdc;
    uint32_t sarWidth;
    uint32_t sarHeight;
    BOOL videoSignalPresent;
    BOOL fullRange;
    BOOL colourPresent;
    uint32_t primaries;
    uint32_t transfer;
    uint32_t matrix;
    uint32_t chromaTop;
    uint32_t chromaBottom;
    BOOL fieldSequence;
} RevenantHEVCSequence;

static const uint16_t revenant_hevc_aspect_ratios[17][2] = {
    {0, 0}, {1, 1}, {12, 11}, {10, 11}, {16, 11}, {40, 33}, {24, 11}, {20, 11}, {32, 11},
    {80, 33}, {18, 11}, {15, 11}, {64, 33}, {160, 99}, {4, 3}, {3, 2}, {2, 1}
};

static void revenant_hevc_reader_start(RevenantHEVCReader *reader, const uint8_t *nal, size_t size)
{
    reader->nal = nal;
    reader->size = size;
    reader->index = 0;
    reader->zeros = 0;
    reader->byte = 0;
    reader->bits = 0;
    reader->overrun = NO;
}

static uint32_t revenant_hevc_bit(RevenantHEVCReader *reader)
{
    if (reader->bits == 0) {
        while (reader->index < reader->size) {
            uint8_t next = reader->nal[reader->index++];
            if (reader->zeros >= 2 && next == 3) {
                reader->zeros = 0;
                continue;
            }
            reader->zeros = next ? 0 : reader->zeros + 1;
            reader->byte = next;
            reader->bits = 8;
            break;
        }
        if (reader->bits == 0) {
            reader->overrun = YES;
            return 0;
        }
    }
    reader->bits--;
    return (reader->byte >> reader->bits) & 1;
}

static uint32_t revenant_hevc_bits(RevenantHEVCReader *reader, unsigned count)
{
    uint32_t value = 0;
    for (unsigned i = 0; i < count; i++)
        value = (value << 1) | revenant_hevc_bit(reader);
    return value;
}

static void revenant_hevc_skip(RevenantHEVCReader *reader, unsigned count)
{
    for (unsigned i = 0; i < count && !reader->overrun; i++)
        revenant_hevc_bit(reader);
}

static uint32_t revenant_hevc_ue(RevenantHEVCReader *reader)
{
    unsigned zeros = 0;
    while (!reader->overrun && revenant_hevc_bit(reader) == 0) {
        if (++zeros > 31) {
            reader->overrun = YES;
            return 0;
        }
    }
    if (reader->overrun)
        return 0;
    return (uint32_t)(((uint64_t)1 << zeros) - 1 + revenant_hevc_bits(reader, zeros));
}

static int32_t revenant_hevc_se(RevenantHEVCReader *reader)
{
    uint32_t code = revenant_hevc_ue(reader);
    if (code & 1)
        return (int32_t)((code >> 1) + 1);
    return -(int32_t)(code >> 1);
}

static void revenant_hevc_skip_profile_tier_level(RevenantHEVCReader *reader, uint32_t maxSubLayersMinus1)
{
    revenant_hevc_skip(reader, 88);
    revenant_hevc_skip(reader, 8);
    BOOL profilePresent[8] = {NO};
    BOOL levelPresent[8] = {NO};
    for (uint32_t i = 0; i < maxSubLayersMinus1; i++) {
        profilePresent[i] = revenant_hevc_bit(reader);
        levelPresent[i] = revenant_hevc_bit(reader);
    }
    if (maxSubLayersMinus1 > 0) {
        for (uint32_t i = maxSubLayersMinus1; i < 8; i++)
            revenant_hevc_skip(reader, 2);
    }
    for (uint32_t i = 0; i < maxSubLayersMinus1; i++) {
        if (profilePresent[i])
            revenant_hevc_skip(reader, 88);
        if (levelPresent[i])
            revenant_hevc_skip(reader, 8);
    }
}

static void revenant_hevc_skip_scaling_list(RevenantHEVCReader *reader)
{
    for (unsigned sizeId = 0; sizeId < 4; sizeId++) {
        unsigned step = sizeId == 3 ? 3 : 1;
        for (unsigned matrixId = 0; matrixId < 6 && !reader->overrun; matrixId += step) {
            if (!revenant_hevc_bit(reader)) {
                revenant_hevc_ue(reader);
                continue;
            }
            unsigned count = 1u << (4 + (sizeId << 1));
            if (count > 64)
                count = 64;
            int32_t next = 8;
            if (sizeId > 1)
                next = revenant_hevc_se(reader) + 8;
            for (unsigned i = 0; i < count && !reader->overrun; i++)
                next = (next + revenant_hevc_se(reader) + 256) % 256;
        }
    }
}

static BOOL revenant_hevc_parse_st_rps(RevenantHEVCReader *reader, uint32_t index, int32_t deltas[][32], uint32_t *negatives, uint32_t *positives)
{
    BOOL inter = index != 0 && revenant_hevc_bit(reader);
    if (!inter) {
        uint32_t negative = revenant_hevc_ue(reader);
        uint32_t positive = revenant_hevc_ue(reader);
        if (negative > 16 || positive > 16)
            return NO;
        int32_t value = 0;
        for (uint32_t i = 0; i < negative; i++) {
            uint32_t step = revenant_hevc_ue(reader);
            if (step > 32767)
                return NO;
            value -= (int32_t)(step + 1);
            deltas[index][i] = value;
            revenant_hevc_skip(reader, 1);
        }
        value = 0;
        for (uint32_t i = 0; i < positive; i++) {
            uint32_t step = revenant_hevc_ue(reader);
            if (step > 32767)
                return NO;
            value += (int32_t)(step + 1);
            deltas[index][negative + i] = value;
            revenant_hevc_skip(reader, 1);
        }
        negatives[index] = negative;
        positives[index] = positive;
        return !reader->overrun;
    }

    uint32_t reference = index - 1;
    BOOL sign = revenant_hevc_bit(reader);
    uint32_t step = revenant_hevc_ue(reader);
    if (step > 32767)
        return NO;
    int32_t deltaRps = (int32_t)(step + 1);
    if (sign)
        deltaRps = -deltaRps;
    uint32_t refNegative = negatives[reference];
    uint32_t refPositive = positives[reference];
    uint32_t refCount = refNegative + refPositive;
    BOOL useDelta[33];
    for (uint32_t j = 0; j <= refCount; j++) {
        BOOL used = revenant_hevc_bit(reader);
        useDelta[j] = used ? YES : revenant_hevc_bit(reader);
    }
    const int32_t *refNegatives = deltas[reference];
    const int32_t *refPositives = deltas[reference] + refNegative;
    int32_t negativeOut[33], positiveOut[33];
    uint32_t negCount = 0, posCount = 0;
    for (int32_t j = (int32_t)refPositive - 1; j >= 0; j--) {
        int32_t d = refPositives[j] + deltaRps;
        if (d < 0 && useDelta[refNegative + j])
            negativeOut[negCount++] = d;
    }
    if (deltaRps < 0 && useDelta[refCount])
        negativeOut[negCount++] = deltaRps;
    for (uint32_t j = 0; j < refNegative; j++) {
        int32_t d = refNegatives[j] + deltaRps;
        if (d < 0 && useDelta[j])
            negativeOut[negCount++] = d;
    }
    for (int32_t j = (int32_t)refNegative - 1; j >= 0; j--) {
        int32_t d = refNegatives[j] + deltaRps;
        if (d > 0 && useDelta[j])
            positiveOut[posCount++] = d;
    }
    if (deltaRps > 0 && useDelta[refCount])
        positiveOut[posCount++] = deltaRps;
    for (uint32_t j = 0; j < refPositive; j++) {
        int32_t d = refPositives[j] + deltaRps;
        if (d > 0 && useDelta[refNegative + j])
            positiveOut[posCount++] = d;
    }
    if (negCount > 16 || posCount > 16)
        return NO;
    for (uint32_t i = 0; i < negCount; i++)
        deltas[index][i] = negativeOut[i];
    for (uint32_t i = 0; i < posCount; i++)
        deltas[index][negCount + i] = positiveOut[i];
    negatives[index] = negCount;
    positives[index] = posCount;
    return !reader->overrun;
}

static void revenant_hevc_parse_vui(RevenantHEVCReader *reader, RevenantHEVCSequence *sequence)
{
    sequence->aspectRatioPresent = revenant_hevc_bit(reader);
    if (sequence->aspectRatioPresent) {
        sequence->aspectRatioIdc = revenant_hevc_bits(reader, 8);
        if (sequence->aspectRatioIdc == 255) {
            sequence->sarWidth = revenant_hevc_bits(reader, 16);
            sequence->sarHeight = revenant_hevc_bits(reader, 16);
        }
    }
    if (revenant_hevc_bit(reader))
        revenant_hevc_skip(reader, 1);
    sequence->videoSignalPresent = revenant_hevc_bit(reader);
    if (sequence->videoSignalPresent) {
        revenant_hevc_skip(reader, 3);
        sequence->fullRange = revenant_hevc_bit(reader);
        sequence->colourPresent = revenant_hevc_bit(reader);
        if (sequence->colourPresent) {
            sequence->primaries = revenant_hevc_bits(reader, 8);
            sequence->transfer = revenant_hevc_bits(reader, 8);
            sequence->matrix = revenant_hevc_bits(reader, 8);
        }
    }
    if (revenant_hevc_bit(reader)) {
        sequence->chromaTop = revenant_hevc_ue(reader);
        sequence->chromaBottom = revenant_hevc_ue(reader);
    }
    revenant_hevc_skip(reader, 1);
    sequence->fieldSequence = revenant_hevc_bit(reader);
    revenant_hevc_skip(reader, 1);
    if (revenant_hevc_bit(reader)) {
        for (int i = 0; i < 4; i++)
            revenant_hevc_ue(reader);
    }
}

static OSStatus revenant_hevc_parse_vps(const uint8_t *nal, size_t size, uint8_t profile[12], uint32_t *temporalLayers, uint32_t *temporalNested)
{
    RevenantHEVCReader reader;
    revenant_hevc_reader_start(&reader, nal, size);
    revenant_hevc_skip(&reader, 16);
    uint32_t header = revenant_hevc_bits(&reader, 32);
    *temporalLayers = ((header >> 17) & 7) + 1;
    *temporalNested = (header >> 16) & 1;
    for (int i = 0; i < 12; i++)
        profile[i] = (uint8_t)revenant_hevc_bits(&reader, 8);
    return reader.overrun ? kCMFormatDescriptionBridgeError_InvalidSerializedSampleDescription : noErr;
}

static OSStatus revenant_hevc_parse_sps(const uint8_t *nal, size_t size, RevenantHEVCSequence *sequence)
{
    RevenantHEVCReader reader;
    revenant_hevc_reader_start(&reader, nal, size);
    revenant_hevc_skip(&reader, 16);
    revenant_hevc_skip(&reader, 4);
    uint32_t maxSubLayersMinus1 = revenant_hevc_bits(&reader, 3);
    revenant_hevc_skip(&reader, 1);
    revenant_hevc_skip_profile_tier_level(&reader, maxSubLayersMinus1);
    uint32_t spsId = revenant_hevc_ue(&reader);
    uint32_t chroma = revenant_hevc_ue(&reader);
    if (chroma == 3)
        revenant_hevc_skip(&reader, 1);
    uint32_t width = revenant_hevc_ue(&reader);
    uint32_t height = revenant_hevc_ue(&reader);
    uint64_t cropLeft = 0, cropRight = 0, cropTop = 0, cropBottom = 0;
    if (revenant_hevc_bit(&reader)) {
        cropLeft = revenant_hevc_ue(&reader);
        cropRight = revenant_hevc_ue(&reader);
        cropTop = revenant_hevc_ue(&reader);
        cropBottom = revenant_hevc_ue(&reader);
    }
    uint32_t bitDepthLumaMinus8 = revenant_hevc_ue(&reader);
    uint32_t bitDepthChromaMinus8 = revenant_hevc_ue(&reader);
    uint32_t log2MaxPocLsbMinus4 = revenant_hevc_ue(&reader);
    BOOL subLayerOrderingInfo = revenant_hevc_bit(&reader);
    for (uint32_t i = subLayerOrderingInfo ? 0 : maxSubLayersMinus1; i <= maxSubLayersMinus1 && !reader.overrun; i++) {
        revenant_hevc_ue(&reader);
        revenant_hevc_ue(&reader);
        revenant_hevc_ue(&reader);
    }
    for (int i = 0; i < 6; i++)
        revenant_hevc_ue(&reader);
    if (revenant_hevc_bit(&reader)) {
        if (revenant_hevc_bit(&reader))
            revenant_hevc_skip_scaling_list(&reader);
    }
    revenant_hevc_skip(&reader, 2);
    if (revenant_hevc_bit(&reader)) {
        revenant_hevc_skip(&reader, 8);
        revenant_hevc_ue(&reader);
        revenant_hevc_ue(&reader);
        revenant_hevc_skip(&reader, 1);
    }
    uint32_t numShortTermRefPicSets = revenant_hevc_ue(&reader);
    if (numShortTermRefPicSets > 64)
        return kCMFormatDescriptionBridgeError_InvalidSerializedSampleDescription;
    int32_t deltas[64][32];
    uint32_t negatives[64], positives[64];
    for (uint32_t i = 0; i < numShortTermRefPicSets; i++) {
        if (!revenant_hevc_parse_st_rps(&reader, i, deltas, negatives, positives))
            return kCMFormatDescriptionBridgeError_InvalidSerializedSampleDescription;
    }
    if (revenant_hevc_bit(&reader)) {
        uint32_t numLongTermRefPicsSps = revenant_hevc_ue(&reader);
        if (numLongTermRefPicsSps > 32)
            return kCMFormatDescriptionBridgeError_InvalidSerializedSampleDescription;
        for (uint32_t i = 0; i < numLongTermRefPicsSps; i++) {
            revenant_hevc_skip(&reader, log2MaxPocLsbMinus4 + 4);
            revenant_hevc_skip(&reader, 1);
        }
    }
    revenant_hevc_skip(&reader, 2);
    if (revenant_hevc_bit(&reader))
        revenant_hevc_parse_vui(&reader, sequence);

    if (reader.overrun || spsId > 15 || chroma > 3 || bitDepthLumaMinus8 > 6 || bitDepthChromaMinus8 > 6)
        return kCMFormatDescriptionBridgeError_InvalidSerializedSampleDescription;
    uint64_t subWidth = chroma == 1 || chroma == 2 ? 2 : 1;
    uint64_t subHeight = chroma == 1 ? 2 : 1;
    uint64_t cropWidth = subWidth * (cropLeft + cropRight);
    uint64_t cropHeight = subHeight * (cropTop + cropBottom);
    if (width == 0 || height == 0 || cropWidth >= width || cropHeight >= height)
        return kCMFormatDescriptionBridgeError_InvalidSerializedSampleDescription;
    sequence->width = width - (uint32_t)cropWidth;
    sequence->height = height - (uint32_t)cropHeight;
    sequence->chromaFormat = chroma;
    sequence->bitDepthLuma = bitDepthLumaMinus8 + 8;
    sequence->bitDepthChroma = bitDepthChromaMinus8 + 8;
    return noErr;
}

static OSStatus revenant_hevc_chroma_name(uint32_t code, CFStringRef *name)
{
    *name = NULL;
    switch (code) {
    case 0: *name = (CFStringRef)CFRetain(CFSTR("Left")); return noErr;
    case 1: *name = (CFStringRef)CFRetain(CFSTR("Center")); return noErr;
    case 2: *name = (CFStringRef)CFRetain(CFSTR("TopLeft")); return noErr;
    case 3: *name = (CFStringRef)CFRetain(CFSTR("Top")); return noErr;
    case 4: *name = (CFStringRef)CFRetain(CFSTR("BottomLeft")); return noErr;
    case 5: *name = (CFStringRef)CFRetain(CFSTR("Bottom")); return noErr;
    default: return kCMFormatDescriptionBridgeError_InvalidParameter;
    }
}

static OSStatus revenant_hevc_primaries_name(CFAllocatorRef allocator, uint32_t code, CFStringRef *name)
{
    *name = NULL;
    switch (code) {
    case 1: *name = (CFStringRef)CFRetain(CFSTR("ITU_R_709_2")); return noErr;
    case 2: return noErr;
    case 4: case 7: case 8: case 10:
        *name = CFStringCreateWithFormat(allocator, NULL, CFSTR("ColorPrimaries#%u"), code);
        return noErr;
    case 5: *name = (CFStringRef)CFRetain(CFSTR("EBU_3213")); return noErr;
    case 6: *name = (CFStringRef)CFRetain(CFSTR("SMPTE_C")); return noErr;
    case 9: *name = (CFStringRef)CFRetain(CFSTR("ITU_R_2020")); return noErr;
    case 11: *name = (CFStringRef)CFRetain(CFSTR("DCI_P3")); return noErr;
    case 12: *name = (CFStringRef)CFRetain(CFSTR("P3_D65")); return noErr;
    default: return kCMFormatDescriptionBridgeError_InvalidParameter;
    }
}

static OSStatus revenant_hevc_transfer_name(CFAllocatorRef allocator, uint32_t code, CFStringRef *name)
{
    *name = NULL;
    switch (code) {
    case 1: case 6: case 14: case 15: *name = (CFStringRef)CFRetain(CFSTR("ITU_R_709_2")); return noErr;
    case 2: return noErr;
    case 4: case 5: case 9: case 10: case 11: case 12:
        *name = CFStringCreateWithFormat(allocator, NULL, CFSTR("TransferFunction#%u"), code);
        return noErr;
    case 7: *name = (CFStringRef)CFRetain(CFSTR("SMPTE_240M_1995")); return noErr;
    case 8: *name = (CFStringRef)CFRetain(CFSTR("Linear")); return noErr;
    case 13: *name = (CFStringRef)CFRetain(CFSTR("IEC_sRGB")); return noErr;
    case 16: *name = (CFStringRef)CFRetain(CFSTR("SMPTE_ST_2084_PQ")); return noErr;
    case 17: *name = (CFStringRef)CFRetain(CFSTR("SMPTE_ST_428_1")); return noErr;
    case 18: *name = (CFStringRef)CFRetain(CFSTR("ITU_R_2100_HLG")); return noErr;
    default: return kCMFormatDescriptionBridgeError_InvalidParameter;
    }
}

static OSStatus revenant_hevc_matrix_name(CFAllocatorRef allocator, uint32_t code, CFStringRef *name)
{
    *name = NULL;
    switch (code) {
    case 0: case 2: return noErr;
    case 1: *name = (CFStringRef)CFRetain(CFSTR("ITU_R_709_2")); return noErr;
    case 4: case 5: case 8: case 10: case 11: case 12: case 13:
        *name = CFStringCreateWithFormat(allocator, NULL, CFSTR("YCbCrMatrix#%u"), code);
        return noErr;
    case 6: *name = (CFStringRef)CFRetain(CFSTR("ITU_R_601_4")); return noErr;
    case 7: *name = (CFStringRef)CFRetain(CFSTR("SMPTE_240M_1995")); return noErr;
    case 9: *name = (CFStringRef)CFRetain(CFSTR("ITU_R_2020")); return noErr;
    case 14: *name = (CFStringRef)CFRetain(CFSTR("ITU_R_2100_ICtCp")); return noErr;
    default: return kCMFormatDescriptionBridgeError_InvalidParameter;
    }
}

static OSStatus revenant_hevc_set_name(CFMutableDictionaryRef extensions, CFStringRef key, CFStringRef name)
{
    if (name) {
        CFDictionarySetValue(extensions, key, name);
        CFRelease(name);
    }
    return noErr;
}

static OSStatus revenant_hevc_set_extensions(CFAllocatorRef allocator, CFMutableDictionaryRef extensions, const RevenantHEVCSequence *sequence, BOOL primariesFromUser)
{
    int32_t horizontal = 1, vertical = 1;
    if (sequence->aspectRatioPresent) {
        if (sequence->aspectRatioIdc == 255) {
            horizontal = (int32_t)sequence->sarWidth;
            vertical = (int32_t)sequence->sarHeight;
        } else if (sequence->aspectRatioIdc >= 1 && sequence->aspectRatioIdc <= 16) {
            horizontal = revenant_hevc_aspect_ratios[sequence->aspectRatioIdc][0];
            vertical = revenant_hevc_aspect_ratios[sequence->aspectRatioIdc][1];
        } else {
            return kCMFormatDescriptionBridgeError_InvalidParameter;
        }
    }
    CFMutableDictionaryRef aspect = CFDictionaryCreateMutable(allocator, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFNumberRef number = CFNumberCreate(allocator, kCFNumberSInt32Type, &horizontal);
    CFDictionarySetValue(aspect, CFSTR("HorizontalSpacing"), number);
    CFRelease(number);
    number = CFNumberCreate(allocator, kCFNumberSInt32Type, &vertical);
    CFDictionarySetValue(aspect, CFSTR("VerticalSpacing"), number);
    CFRelease(number);
    CFDictionarySetValue(extensions, CFSTR("CVPixelAspectRatio"), aspect);
    CFRelease(aspect);

    if (!sequence->fieldSequence) {
        int32_t one = 1;
        number = CFNumberCreate(allocator, kCFNumberSInt32Type, &one);
        CFDictionarySetValue(extensions, CFSTR("CVFieldCount"), number);
        CFRelease(number);
    }

    if (sequence->videoSignalPresent)
        CFDictionarySetValue(extensions, kCMFormatDescriptionExtension_FullRangeVideo, sequence->fullRange ? kCFBooleanTrue : kCFBooleanFalse);

    int32_t depth = (int32_t)sequence->bitDepthLuma;
    number = CFNumberCreate(allocator, kCFNumberSInt32Type, &depth);
    CFDictionarySetValue(extensions, kCMFormatDescriptionExtension_BitsPerComponent, number);
    CFRelease(number);

    CFStringRef top = NULL, bottom = NULL;
    OSStatus chromaStatus = revenant_hevc_chroma_name(sequence->chromaTop, &top);
    if (chromaStatus == noErr)
        chromaStatus = revenant_hevc_chroma_name(sequence->chromaBottom, &bottom);
    if (chromaStatus != noErr) {
        if (top)
            CFRelease(top);
        return chromaStatus;
    }
    revenant_hevc_set_name(extensions, CFSTR("CVImageBufferChromaLocationTopField"), top);
    revenant_hevc_set_name(extensions, CFSTR("CVImageBufferChromaLocationBottomField"), bottom);

    if (sequence->colourPresent && !primariesFromUser) {
        CFStringRef primaries = NULL, transfer = NULL, matrix = NULL;
        OSStatus status = revenant_hevc_primaries_name(allocator, sequence->primaries, &primaries);
        if (status == noErr)
            status = revenant_hevc_transfer_name(allocator, sequence->transfer, &transfer);
        if (status == noErr)
            status = revenant_hevc_matrix_name(allocator, sequence->matrix, &matrix);
        if (status != noErr) {
            if (primaries)
                CFRelease(primaries);
            if (transfer)
                CFRelease(transfer);
            return status;
        }
        revenant_hevc_set_name(extensions, CFSTR("CVImageBufferColorPrimaries"), primaries);
        revenant_hevc_set_name(extensions, CFSTR("CVImageBufferTransferFunction"), transfer);
        revenant_hevc_set_name(extensions, CFSTR("CVImageBufferYCbCrMatrix"), matrix);
    }
    return noErr;
}

static void revenant_hevc_copy_extension(const void *key, const void *value, void *context)
{
    CFDictionarySetValue((CFMutableDictionaryRef)context, key, value);
}

OSStatus BACKPORT_IMPL(CMVideoFormatDescriptionCreateFromHEVCParameterSets)(CFAllocatorRef allocator, size_t parameterSetCount, const uint8_t *const *parameterSetPointers,
                                                              const size_t *parameterSetSizes, int NALUnitHeaderLength, CFDictionaryRef extensions, CMFormatDescriptionRef *formatDescriptionOut)
{
    if (!formatDescriptionOut || parameterSetCount == 0)
        return kCMFormatDescriptionError_InvalidParameter;
    if (!parameterSetPointers || !parameterSetSizes || (NALUnitHeaderLength != 1 && NALUnitHeaderLength != 2 && NALUnitHeaderLength != 4))
        return kCMFormatDescriptionBridgeError_InvalidParameter;

    static const uint8_t types[5] = {32, 33, 34, 39, 40};
    const uint8_t *first[5] = {NULL, NULL, NULL, NULL, NULL};
    size_t firstSize[5] = {0, 0, 0, 0, 0};
    for (size_t i = 0; i < parameterSetCount; i++) {
        const uint8_t *nal = parameterSetPointers[i];
        size_t size = parameterSetSizes[i];
        if (!nal || size == 0 || size > 0xffff)
            return kCMFormatDescriptionBridgeError_InvalidParameter;
        uint8_t type = (nal[0] >> 1) & 0x3f;
        int slot = -1;
        for (int k = 0; k < 5; k++) {
            if (types[k] == type)
                slot = k;
        }
        if (slot < 0)
            return kCMFormatDescriptionBridgeError_InvalidParameter;
        if ((nal[0] & 0x80) || size < 2)
            return kCMFormatDescriptionBridgeError_InvalidSerializedSampleDescription;
        if (!first[slot]) {
            first[slot] = nal;
            firstSize[slot] = size;
        }
    }
    if (!first[1])
        return kCMFormatDescriptionError_InvalidParameter;

    uint8_t profile[12] = {0};
    uint32_t temporalLayers = 0, temporalNested = 0;
    OSStatus status = noErr;
    if (first[0] && (status = revenant_hevc_parse_vps(first[0], firstSize[0], profile, &temporalLayers, &temporalNested)) != noErr)
        return status;

    RevenantHEVCSequence sequence = {0};
    if ((status = revenant_hevc_parse_sps(first[1], firstSize[1], &sequence)) != noErr)
        return status;

    if (extensions && CFDictionaryContainsKey(extensions, kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms)) {
        CFMutableDictionaryRef userOnly = CFDictionaryCreateMutable(allocator, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        CFDictionaryApplyFunction(extensions, revenant_hevc_copy_extension, userOnly);
        status = CMVideoFormatDescriptionCreate(allocator, kCMVideoCodecType_HEVC, (int32_t)sequence.width, (int32_t)sequence.height, userOnly, formatDescriptionOut);
        CFRelease(userOnly);
        return status;
    }

    uint8_t arrays = 0;
    for (int k = 0; k < 5; k++) {
        if (first[k])
            arrays++;
    }
    uint8_t header[23] = {0};
    header[0] = 1;
    memcpy(header + 1, profile, 12);
    header[13] = 0xf0;
    header[14] = 0x00;
    header[15] = 0xfc;
    header[16] = 0xfc | (uint8_t)sequence.chromaFormat;
    header[17] = 0xf8 | (uint8_t)(sequence.bitDepthLuma - 8);
    header[18] = 0xf8 | (uint8_t)(sequence.bitDepthChroma - 8);
    header[21] = (uint8_t)(((temporalLayers & 7) << 3) | (temporalNested << 2) | (NALUnitHeaderLength - 1));
    header[22] = arrays;

    CFMutableDataRef record = CFDataCreateMutable(allocator, 0);
    CFDataAppendBytes(record, header, 23);
    for (int k = 0; k < 5; k++) {
        if (!first[k])
            continue;
        uint8_t array[5] = {(uint8_t)(0x80 | types[k]), 0, 1, (uint8_t)(firstSize[k] >> 8), (uint8_t)firstSize[k]};
        CFDataAppendBytes(record, array, 5);
        CFDataAppendBytes(record, first[k], (CFIndex)firstSize[k]);
    }

    CFMutableDictionaryRef atoms = CFDictionaryCreateMutable(allocator, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(atoms, CFSTR("hvcC"), record);
    CFRelease(record);

    CFMutableDictionaryRef merged = CFDictionaryCreateMutable(allocator, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    BOOL primariesFromUser = extensions && CFDictionaryContainsKey(extensions, CFSTR("CVImageBufferColorPrimaries"));
    status = revenant_hevc_set_extensions(allocator, merged, &sequence, primariesFromUser);
    if (status == noErr) {
        CFDictionarySetValue(merged, kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms, atoms);
        if (extensions)
            CFDictionaryApplyFunction(extensions, revenant_hevc_copy_extension, merged);
        status = CMVideoFormatDescriptionCreate(allocator, kCMVideoCodecType_HEVC, (int32_t)sequence.width, (int32_t)sequence.height, merged, formatDescriptionOut);
    }
    CFRelease(atoms);
    CFRelease(merged);
    return status;
}
