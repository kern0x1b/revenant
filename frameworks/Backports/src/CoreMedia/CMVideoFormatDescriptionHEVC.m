#include "../revenant_impl.h"
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#include <stdlib.h>
#include <string.h>

static const OSStatus invalidParameter = -12710;
static const OSStatus malformedRecord = -12712;
static const OSStatus unreadableParameterSet = -12714;

typedef struct {
    uint8_t *bytes;
    size_t length;
    size_t bit;
    BOOL failed;
} RevenantHEVCBitReader;

static RevenantHEVCBitReader revenant_hevc_rbsp(const uint8_t *nal, size_t size)
{
    RevenantHEVCBitReader reader = {malloc(size ? size : 1), 0, 0, NO};
    int zeros = 0;
    for (size_t i = 1; i < size; i++) {
        if (zeros >= 2 && nal[i] == 3) {
            zeros = 0;
            continue;
        }
        reader.bytes[reader.length++] = nal[i];
        zeros = nal[i] ? 0 : zeros + 1;
    }
    return reader;
}

static uint32_t revenant_hevc_bits(RevenantHEVCBitReader *reader, int count)
{
    uint32_t value = 0;
    for (int i = 0; i < count; i++) {
        if (reader->bit >= reader->length * 8) {
            reader->failed = YES;
            return 0;
        }
        value = (value << 1) | ((reader->bytes[reader->bit / 8] >> (7 - reader->bit % 8)) & 1);
        reader->bit++;
    }
    return value;
}

static uint32_t revenant_hevc_ue(RevenantHEVCBitReader *reader)
{
    int zeros = 0;
    while (!reader->failed && revenant_hevc_bits(reader, 1) == 0)
        zeros++;
    if (reader->failed || zeros > 31) {
        reader->failed = YES;
        return 0;
    }
    return (uint32_t)(((uint64_t)1 << zeros) - 1 + revenant_hevc_bits(reader, zeros));
}

static int32_t revenant_hevc_se(RevenantHEVCBitReader *reader)
{
    uint32_t code = revenant_hevc_ue(reader);
    return code & 1 ? (int32_t)((code + 1) / 2) : -(int32_t)(code / 2);
}

static void revenant_hevc_skip_scaling_list(RevenantHEVCBitReader *reader, int size)
{
    int last = 8, next = 8;
    for (int j = 0; j < size && !reader->failed; j++) {
        if (next != 0) {
            int32_t delta = revenant_hevc_se(reader);
            next = ((last + delta) % 256 + 256) % 256;
        }
        last = next == 0 ? last : next;
    }
}

static void revenant_hevc_skip_short_term_ref_pic_set(RevenantHEVCBitReader *reader, int interRefPicSetPredictionFlag, int idx, int numShortTermRefPicSets)
{
    if (interRefPicSetPredictionFlag) {
        uint32_t deltaIdx = revenant_hevc_ue(reader);
        if (deltaIdx > idx) {
            reader->failed = YES;
            return;
        }
    }
    if (!interRefPicSetPredictionFlag || idx > 0) {
        uint32_t numNegativePics = revenant_hevc_ue(reader);
        uint32_t numPositivePics = revenant_hevc_ue(reader);
        if (numNegativePics + numPositivePics > 16) {
            reader->failed = YES;
            return;
        }
        for (uint32_t i = 0; i < numNegativePics && !reader->failed; i++) {
            revenant_hevc_ue(reader);
            revenant_hevc_bits(reader, 1);
        }
        for (uint32_t i = 0; i < numPositivePics && !reader->failed; i++) {
            revenant_hevc_ue(reader);
            revenant_hevc_bits(reader, 1);
        }
    }
}

static void revenant_hevc_parse_vps(const uint8_t *nal, size_t size, int *width, int *height)
{
    RevenantHEVCBitReader reader = revenant_hevc_rbsp(nal, size);
    RevenantHEVCBitReader *r = &reader;

    revenant_hevc_bits(r, 4);
    int vpsMaxLayers = (int)revenant_hevc_bits(r, 6);
    int vpsMaxSubLayers = (int)revenant_hevc_bits(r, 3);
    revenant_hevc_bits(r, 1);
    revenant_hevc_ue(r);
    revenant_hevc_ue(r);
    revenant_hevc_bits(r, 1);
    revenant_hevc_bits(r, 1);

    for (int i = 0; i < vpsMaxSubLayers && !r->failed; i++) {
        revenant_hevc_bits(r, 1);
        revenant_hevc_bits(r, 1);
        revenant_hevc_ue(r);
        revenant_hevc_ue(r);
        revenant_hevc_bits(r, 1);
        revenant_hevc_bits(r, 1);
    }

    for (int i = 0; i < vpsMaxLayers && !r->failed; i++) {
        revenant_hevc_bits(r, 1);
        revenant_hevc_bits(r, 1);
        revenant_hevc_ue(r);
    }

    uint32_t vpsNumHrdParameters = revenant_hevc_ue(r);
    if (vpsNumHrdParameters > 32) {
        r->failed = YES;
    }
    for (uint32_t i = 0; i < vpsNumHrdParameters && !r->failed; i++) {
        revenant_hevc_ue(r);
        revenant_hevc_ue(r);
        revenant_hevc_bits(r, 1);
        for (int j = 0; j < 16 && !r->failed; j++) {
            revenant_hevc_bits(r, 1);
            revenant_hevc_bits(r, 1);
        }
    }

    revenant_hevc_bits(r, 1);
    revenant_hevc_bits(r, 1);
    revenant_hevc_bits(r, 1);

    free(reader.bytes);
}

static void revenant_hevc_parse_sps(const uint8_t *nal, size_t size, int *width, int *height)
{
    RevenantHEVCBitReader reader = revenant_hevc_rbsp(nal, size);
    RevenantHEVCBitReader *r = &reader;

    revenant_hevc_bits(r, 4);
    int spsMaxSubLayers = (int)revenant_hevc_bits(r, 3);
    revenant_hevc_bits(r, 1);
    revenant_hevc_ue(r);

    uint32_t chromaFormatIdc = revenant_hevc_ue(r);
    if (chromaFormatIdc == 3)
        revenant_hevc_bits(r, 1);
    uint32_t picWidthInLumaSamples = revenant_hevc_ue(r);
    uint32_t picHeightInLumaSamples = revenant_hevc_ue(r);

    if (width)
        *width = (int)picWidthInLumaSamples;
    if (height)
        *height = (int)picHeightInLumaSamples;

    if (revenant_hevc_bits(r, 1)) {
        revenant_hevc_ue(r);
        revenant_hevc_ue(r);
        revenant_hevc_ue(r);
        revenant_hevc_ue(r);
    }

    uint32_t bitDepthLumaMinus8 = revenant_hevc_ue(r);
    uint32_t bitDepthChromaMinus8 = revenant_hevc_ue(r);
    uint32_t log2MaxPicOrderCntLsb = revenant_hevc_ue(r);

    uint32_t spsSubLayerOrderingInfoPresentFlag = revenant_hevc_bits(r, 1);
    for (int i = spsSubLayerOrderingInfoPresentFlag ? 0 : spsMaxSubLayers - 1; i <= spsMaxSubLayers - 1 && !r->failed; i++) {
        revenant_hevc_ue(r);
        revenant_hevc_ue(r);
        revenant_hevc_ue(r);
    }

    uint32_t log2MinLumaCodingBlockSizeMinus3 = revenant_hevc_ue(r);
    uint32_t log2DiffMaxMinLumaCodingBlockSize = revenant_hevc_ue(r);
    uint32_t log2MinTransformBlockSizeMinus2 = revenant_hevc_ue(r);
    uint32_t log2DiffMaxMinTransformBlockSize = revenant_hevc_ue(r);
    uint32_t maxTransformHierarchyDepthInter = revenant_hevc_ue(r);
    uint32_t maxTransformHierarchyDepthIntra = revenant_hevc_ue(r);

    if (revenant_hevc_bits(r, 1)) {
        revenant_hevc_skip_scaling_list(r, 6);
    }
    revenant_hevc_bits(r, 1);
    if (revenant_hevc_bits(r, 1)) {
        revenant_hevc_ue(r);
        revenant_hevc_ue(r);
        revenant_hevc_ue(r);
    }
    if (revenant_hevc_bits(r, 1)) {
        revenant_hevc_bits(r, 1);
        revenant_hevc_bits(r, 1);
        revenant_hevc_bits(r, 1);
        revenant_hevc_bits(r, 1);
        revenant_hevc_bits(r, 1);
        revenant_hevc_bits(r, 1);
        revenant_hevc_bits(r, 1);
    }

    uint32_t vuiParametersPresentFlag = revenant_hevc_bits(r, 1);
    if (vuiParametersPresentFlag) {
        uint32_t aspectRatioInfoPresentFlag = revenant_hevc_bits(r, 1);
        if (aspectRatioInfoPresentFlag) {
            uint32_t aspectRatioIdc = revenant_hevc_bits(r, 8);
            if (aspectRatioIdc == 255) {
                revenant_hevc_bits(r, 16);
                revenant_hevc_bits(r, 16);
            }
        }
        uint32_t overscanInfoPresentFlag = revenant_hevc_bits(r, 1);
        if (overscanInfoPresentFlag)
            revenant_hevc_bits(r, 1);
        uint32_t videoSignalTypePresentFlag = revenant_hevc_bits(r, 1);
        if (videoSignalTypePresentFlag) {
            revenant_hevc_bits(r, 3);
            revenant_hevc_bits(r, 1);
            uint32_t colourDescriptionPresentFlag = revenant_hevc_bits(r, 1);
            if (colourDescriptionPresentFlag) {
                revenant_hevc_bits(r, 8);
                revenant_hevc_bits(r, 8);
                revenant_hevc_bits(r, 8);
            }
        }
        uint32_t chromaLocInfoPresentFlag = revenant_hevc_bits(r, 1);
        if (chromaLocInfoPresentFlag) {
            revenant_hevc_ue(r);
            revenant_hevc_ue(r);
        }
        uint32_t neutralChromaIndicationFlag = revenant_hevc_bits(r, 1);
        uint32_t fieldSeqFlag = revenant_hevc_bits(r, 1);
        uint32_t frameFieldInfoPresentFlag = revenant_hevc_bits(r, 1);
        uint32_t defaultDisplayWindowFlag = revenant_hevc_bits(r, 1);
        if (defaultDisplayWindowFlag) {
            revenant_hevc_ue(r);
            revenant_hevc_ue(r);
            revenant_hevc_ue(r);
            revenant_hevc_ue(r);
        }
        uint32_t vuiTimingInfoPresentFlag = revenant_hevc_bits(r, 1);
        if (vuiTimingInfoPresentFlag) {
            revenant_hevc_bits(r, 32);
            revenant_hevc_bits(r, 32);
            revenant_hevc_bits(r, 1);
        }
        uint32_t vuiPocProportionalToTimingFlag = revenant_hevc_bits(r, 1);
        if (vuiPocProportionalToTimingFlag) {
            revenant_hevc_ue(r);
            revenant_hevc_ue(r);
        }
        uint32_t vuiHrdParametersPresentFlag = revenant_hevc_bits(r, 1);
        if (vuiHrdParametersPresentFlag) {
        }
    }

    free(reader.bytes);
}

static BOOL revenant_hevc_read_nal_type(const uint8_t *nal, size_t size, int *typeOut)
{
    if (!nal || size < 2)
        return NO;
    int forbidden = (nal[0] >> 7) & 1;
    if (forbidden)
        return NO;
    *typeOut = (nal[0] >> 1) & 0x3F;
    return YES;
}

static CFStringRef revenant_chroma_location(int code)
{
    switch (code) {
    case 0: return kCVImageBufferChromaLocation_Left;
    case 1: return kCVImageBufferChromaLocation_Center;
    case 2: return kCVImageBufferChromaLocation_TopLeft;
    case 3: return kCVImageBufferChromaLocation_Top;
    case 4: return kCVImageBufferChromaLocation_BottomLeft;
    case 5: return kCVImageBufferChromaLocation_Bottom;
    default: return NULL;
    }
}

static void revenant_set_code(CFMutableDictionaryRef extensions, CFStringRef key, CFStringRef value)
{
    if (value)
        CFDictionarySetValue(extensions, key, value);
}

static void revenant_hevc_append_sets(CFMutableDataRef record, const uint8_t *const *pointers, const size_t *sizes, const int *indices, size_t count)
{
    for (size_t i = 0; i < count; i++) {
        size_t size = sizes[indices[i]];
        uint8_t length[2] = {(uint8_t)(size >> 8), (uint8_t)size};
        CFDataAppendBytes(record, length, 2);
        CFDataAppendBytes(record, pointers[indices[i]], (CFIndex)size);
    }
}

OSStatus BACKPORT_IMPL(CMVideoFormatDescriptionCreateFromHEVCParameterSets)(CFAllocatorRef allocator, size_t parameterSetCount, const uint8_t *const *parameterSetPointers,
                                                              const size_t *parameterSetSizes, int NALUnitHeaderLength, CFDictionaryRef extensions, CMFormatDescriptionRef *formatDescriptionOut)
{
    if (!formatDescriptionOut)
        return invalidParameter;
    if (parameterSetCount < 3 || !parameterSetPointers || !parameterSetSizes || (NALUnitHeaderLength != 1 && NALUnitHeaderLength != 2 && NALUnitHeaderLength != 4))
        return malformedRecord;

    int vpsIndex = -1, spsIndex = -1, ppsIndex = -1;
    int width = 0, height = 0;

    for (size_t i = 0; i < parameterSetCount; i++) {
        const uint8_t *nal = parameterSetPointers[i];
        size_t size = parameterSetSizes[i];
        if (!nal || !size || (nal[0] & 0x80) || !(nal[0] & 0x60))
            return malformedRecord;

        int nalType = 0;
        if (!revenant_hevc_read_nal_type(nal, size, &nalType))
            return malformedRecord;

        if (nalType == 32 && vpsIndex == -1)
            vpsIndex = (int)i;
        else if (nalType == 33 && spsIndex == -1)
            spsIndex = (int)i;
        else if (nalType == 34 && ppsIndex == -1)
            ppsIndex = (int)i;
    }

    if (vpsIndex == -1 || spsIndex == -1 || ppsIndex == -1)
        return malformedRecord;

    revenant_hevc_parse_vps(parameterSetPointers[vpsIndex], parameterSetSizes[vpsIndex], &width, &height);
    revenant_hevc_parse_sps(parameterSetPointers[spsIndex], parameterSetSizes[spsIndex], &width, &height);

    if (width <= 0 || height <= 0)
        return invalidParameter;

    CFMutableDataRef record = CFDataCreateMutable(allocator, 0);
    uint8_t header[23] = {1};
    header[1] = 0;
    header[2] = 0;
    header[3] = 0;
    CFDataAppendBytes(record, header, 23);

    int indices[3] = {vpsIndex, spsIndex, ppsIndex};
    revenant_hevc_append_sets(record, parameterSetPointers, parameterSetSizes, indices, 3);

    CFMutableDictionaryRef hevcExtensions = CFDictionaryCreateMutable(allocator, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFMutableDictionaryRef atoms = CFDictionaryCreateMutable(allocator, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(atoms, CFSTR("hvcC"), record);
    CFDictionarySetValue(hevcExtensions, kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms, atoms);
    CFRelease(atoms);
    CFRelease(record);

    if (extensions) {
        CFDictionaryApplyFunction(extensions, (void (*)(const void *, const void *, void *))CFDictionarySetValue, hevcExtensions);
    }

    OSStatus status = CMVideoFormatDescriptionCreate(allocator, kCMVideoCodecType_HEVC, width, height, hevcExtensions, formatDescriptionOut);
    CFRelease(hevcExtensions);
    return status;
}