#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#include <stdlib.h>
#include <string.h>

static const OSStatus invalidParameter = -12710;
static const OSStatus malformedRecord = -12712;
static const OSStatus unreadableParameterSet = -12714;

CFStringRef CVColorPrimariesGetStringForIntegerCodePoint(int codePoint);
CFStringRef CVTransferFunctionGetStringForIntegerCodePoint(int codePoint);
CFStringRef CVYCbCrMatrixGetStringForIntegerCodePoint(int codePoint);

OSStatus CMVideoFormatDescriptionGetH264ParameterSetAtIndex(CMFormatDescriptionRef videoDesc, size_t parameterSetIndex, const uint8_t **parameterSetPointerOut,
                                                            size_t *parameterSetSizeOut, size_t *parameterSetCountOut, int *NALUnitHeaderLengthOut)
{
    if (!videoDesc || CMFormatDescriptionGetMediaType(videoDesc) != kCMMediaType_Video || CMFormatDescriptionGetMediaSubType(videoDesc) != kCMVideoCodecType_H264)
        return invalidParameter;
    CFDictionaryRef atoms = CMFormatDescriptionGetExtension(videoDesc, kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms);
    CFDataRef record = atoms && CFGetTypeID(atoms) == CFDictionaryGetTypeID() ? CFDictionaryGetValue(atoms, CFSTR("avcC")) : NULL;
    if (!record || CFGetTypeID(record) != CFDataGetTypeID())
        return invalidParameter;
    if (parameterSetPointerOut)
        *parameterSetPointerOut = NULL;
    if (parameterSetSizeOut)
        *parameterSetSizeOut = 0;
    if (parameterSetCountOut)
        *parameterSetCountOut = 0;
    if (NALUnitHeaderLengthOut)
        *NALUnitHeaderLengthOut = 0;
    const uint8_t *bytes = CFDataGetBytePtr(record);
    size_t length = (size_t)CFDataGetLength(record);
    if (length < 6 || bytes[0] != 1)
        return malformedRecord;
    if (NALUnitHeaderLengthOut)
        *NALUnitHeaderLengthOut = (bytes[4] & 3) + 1;
    if (NALUnitHeaderLengthOut && !parameterSetPointerOut && !parameterSetSizeOut && !parameterSetCountOut)
        return 0;
    size_t at = 5;
    size_t seen = 0;
    BOOL extended = bytes[1] == 100 || bytes[1] == 110 || bytes[1] == 122 || bytes[1] == 144;
    for (int group = 0; group < (extended ? 3 : 2); group++) {
        if (group == 2) {
            if (at == length)
                break;
            if (at + 4 > length)
                return malformedRecord;
            at += 3;
        }
        if (at >= length)
            return malformedRecord;
        size_t n = group == 0 ? (bytes[at] & 0x1F) : bytes[at];
        at++;
        for (size_t i = 0; i < n; i++) {
            if (at + 2 > length)
                return malformedRecord;
            size_t size = ((size_t)bytes[at] << 8) | bytes[at + 1];
            at += 2;
            if (at + size > length)
                return malformedRecord;
            if (seen == parameterSetIndex) {
                if (parameterSetPointerOut)
                    *parameterSetPointerOut = bytes + at;
                if (parameterSetSizeOut)
                    *parameterSetSizeOut = size;
                if (!parameterSetCountOut)
                    return 0;
            }
            seen++;
            at += size;
        }
    }
    if (parameterSetCountOut)
        *parameterSetCountOut = seen;
    if (!parameterSetPointerOut && !parameterSetSizeOut)
        return 0;
    return parameterSetIndex < seen ? 0 : malformedRecord;
}

typedef struct {
    uint8_t *bytes;
    size_t length;
    size_t bit;
    BOOL failed;
} CharonBitReader;

static CharonBitReader charon_rbsp(const uint8_t *nal, size_t size)
{
    CharonBitReader reader = {malloc(size ? size : 1), 0, 0, NO};
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

static uint32_t charon_bits(CharonBitReader *reader, int count)
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

static uint32_t charon_ue_within(CharonBitReader *reader, int longest)
{
    int zeros = 0;
    while (!reader->failed && charon_bits(reader, 1) == 0)
        zeros++;
    if (reader->failed || zeros > longest) {
        reader->failed = YES;
        return 0;
    }
    return (uint32_t)(((uint64_t)1 << zeros) - 1 + charon_bits(reader, zeros));
}

static uint32_t charon_ue(CharonBitReader *reader)
{
    return charon_ue_within(reader, 12);
}

static int32_t charon_se(CharonBitReader *reader)
{
    uint32_t code = charon_ue(reader);
    return code & 1 ? (int32_t)((code + 1) / 2) : -(int32_t)(code / 2);
}

typedef struct {
    int profile, constraints, level;
    BOOL hasFormat;
    int chroma, lumaDepth, chromaDepth;
    BOOL hasFrames;
    int frameOnly;
    BOOL hasSize;
    int width, height;
    BOOL hasVUI, hasAspect, hasSignal, hasColour, hasChromaLocation;
    int aspect, sarWidth, sarHeight, fullRange, primaries, transfer, matrix, chromaTop, chromaBottom;
    BOOL complete;
} CharonSequence;

static BOOL charon_has_format_syntax(int profile)
{
    switch (profile) {
    case 100: case 110: case 122: case 244: case 44: case 83: case 86: case 118: case 128: case 138: case 139: case 134: case 135:
        return YES;
    default:
        return NO;
    }
}

static BOOL charon_writes_format(int profile)
{
    return profile == 100 || profile == 110 || profile == 122 || profile == 144;
}

static void charon_skip_scaling_list(CharonBitReader *reader, int size)
{
    int last = 8, next = 8;
    for (int j = 0; j < size && !reader->failed; j++) {
        if (next != 0) {
            int32_t delta = charon_se(reader);
            next = ((last + delta) % 256 + 256) % 256;
        }
        last = next == 0 ? last : next;
    }
}

static void charon_skip_hrd(CharonBitReader *reader)
{
    uint32_t count = charon_ue(reader) + 1;
    if (count > 32) {
        reader->failed = YES;
        return;
    }
    charon_bits(reader, 8);
    for (uint32_t i = 0; i < count && !reader->failed; i++) {
        charon_ue_within(reader, 31);
        charon_ue_within(reader, 31);
        charon_bits(reader, 1);
    }
    charon_bits(reader, 20);
}

static void charon_parse_sequence(const uint8_t *nal, size_t size, CharonSequence *out)
{
    memset(out, 0, sizeof *out);
    CharonBitReader reader = charon_rbsp(nal, size);
    CharonBitReader *r = &reader;
    out->profile = (int)charon_bits(r, 8);
    out->constraints = (int)charon_bits(r, 8);
    out->level = (int)charon_bits(r, 8);
    uint32_t identifier = charon_ue(r);
    if (r->failed || identifier > 31)
        goto done;
    out->chroma = 1;
    if (charon_has_format_syntax(out->profile)) {
        uint32_t chroma = charon_ue(r);
        if (r->failed || chroma > 3)
            goto done;
        if (chroma == 3)
            charon_bits(r, 1);
        uint32_t luma = charon_ue(r), chromaDepth = charon_ue(r);
        if (r->failed || luma > 6 || chromaDepth > 6)
            goto done;
        out->chroma = (int)chroma;
        out->lumaDepth = (int)luma;
        out->chromaDepth = (int)chromaDepth;
        out->hasFormat = YES;
        charon_bits(r, 1);
        if (charon_bits(r, 1))
            for (int i = 0; i < (chroma != 3 ? 8 : 12) && !r->failed; i++)
                if (charon_bits(r, 1))
                    charon_skip_scaling_list(r, i < 6 ? 16 : 64);
        if (r->failed)
            goto done;
    }
    charon_ue(r);
    uint32_t order = charon_ue(r);
    if (order == 0) {
        if (charon_ue(r) > 12)
            goto done;
    } else if (order == 1) {
        // H.264 7.4.2.1.1 lets these three offsets range over -2^31+1 to 2^31-1, but the host's CoreMedia refuses
        // an SPS with any of them past -4095 to 4095 (-12710), the most 12 leading zeros can say, and the port
        // answers as it does (facts/CoreMedia/H264ParameterSets.md).
        charon_bits(r, 1);
        charon_se(r);
        charon_se(r);
        uint32_t cycle = charon_ue(r);
        if (cycle > 255)
            goto done;
        for (uint32_t i = 0; i < cycle && !r->failed; i++)
            charon_se(r);
    }
    charon_ue(r);
    charon_bits(r, 1);
    uint32_t widthMbs = charon_ue(r) + 1, heightUnits = charon_ue(r) + 1;
    int frameOnly = (int)charon_bits(r, 1);
    if (r->failed)
        goto done;
    out->frameOnly = frameOnly;
    out->hasFrames = YES;
    if (!frameOnly)
        charon_bits(r, 1);
    charon_bits(r, 1);
    uint32_t left = 0, right = 0, top = 0, bottom = 0;
    if (charon_bits(r, 1)) {
        left = charon_ue(r);
        right = charon_ue(r);
        top = charon_ue(r);
        bottom = charon_ue(r);
    }
    if (r->failed)
        goto done;
    int unitX = out->chroma == 0 ? 0 : out->chroma == 3 ? 1 : 2;
    int unitY = (out->chroma == 0 ? 0 : out->chroma == 1 ? 2 : 1) * (2 - frameOnly);
    int64_t width = (int64_t)widthMbs * 16 - (int64_t)unitX * ((int64_t)left + right);
    int64_t height = (int64_t)heightUnits * 16 * (2 - frameOnly) - (int64_t)unitY * ((int64_t)top + bottom);
    out->width = (int32_t)width;
    out->height = (int32_t)height;
    if (!out->width || !out->height)
        goto done;
    out->hasSize = YES;
    if (charon_bits(r, 1)) {
        out->hasVUI = YES;
        if (charon_bits(r, 1)) {
            out->aspect = (int)charon_bits(r, 8);
            if (out->aspect == 255) {
                out->sarWidth = (int)charon_bits(r, 16);
                out->sarHeight = (int)charon_bits(r, 16);
            }
            out->hasAspect = !r->failed;
        }
        if (charon_bits(r, 1))
            charon_bits(r, 1);
        if (charon_bits(r, 1)) {
            charon_bits(r, 3);
            out->fullRange = (int)charon_bits(r, 1);
            if (charon_bits(r, 1)) {
                out->primaries = (int)charon_bits(r, 8);
                out->transfer = (int)charon_bits(r, 8);
                out->matrix = (int)charon_bits(r, 8);
                out->hasColour = !r->failed;
            }
            out->hasSignal = !r->failed;
        }
        if (charon_bits(r, 1)) {
            out->chromaTop = (int)charon_ue(r);
            out->chromaBottom = (int)charon_ue(r);
            out->hasChromaLocation = !r->failed;
        }
        if (charon_bits(r, 1)) {
            charon_bits(r, 32);
            charon_bits(r, 32);
            charon_bits(r, 1);
        }
        int nalHRD = (int)charon_bits(r, 1);
        if (nalHRD)
            charon_skip_hrd(r);
        int vclHRD = (int)charon_bits(r, 1);
        if (vclHRD)
            charon_skip_hrd(r);
        if (nalHRD || vclHRD)
            charon_bits(r, 1);
        charon_bits(r, 1);
        if (charon_bits(r, 1)) {
            charon_bits(r, 1);
            for (int i = 0; i < 6; i++)
                charon_ue(r);
        }
    }
    if (r->failed)
        goto done;
    out->complete = YES;
done:
    free(reader.bytes);
}

typedef struct {
    size_t index;
    uint32_t identifier;
    int type, profile, constraints, level;
    BOOL hasFormat;
    uint32_t chroma, lumaDepth, chromaDepth;
} CharonParameterSet;

static BOOL charon_read_parameter_set(const uint8_t *nal, size_t size, CharonParameterSet *out)
{
    CharonBitReader reader = charon_rbsp(nal, size);
    if (out->type == 7) {
        out->profile = (int)charon_bits(&reader, 8);
        out->constraints = (int)charon_bits(&reader, 8);
        out->level = (int)charon_bits(&reader, 8);
    }
    out->identifier = charon_ue(&reader);
    if (out->type == 7 && charon_writes_format(out->profile)) {
        out->chroma = charon_ue(&reader);
        if (out->chroma == 3)
            charon_bits(&reader, 1);
        out->lumaDepth = charon_ue(&reader);
        out->chromaDepth = charon_ue(&reader);
        out->hasFormat = YES;
    }
    BOOL readable = !reader.failed;
    free(reader.bytes);
    return readable;
}

static void charon_sort_by_identifier(CharonParameterSet *sets, size_t count)
{
    for (size_t i = 1; i < count; i++) {
        CharonParameterSet moving = sets[i];
        size_t j = i;
        for (; j > 0 && sets[j - 1].identifier > moving.identifier; j--)
            sets[j] = sets[j - 1];
        sets[j] = moving;
    }
}

static CFStringRef charon_chroma_location(int code)
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

static void charon_set_code(CFMutableDictionaryRef extensions, CFStringRef key, CFStringRef value)
{
    if (value)
        CFDictionarySetValue(extensions, key, value);
}

static void charon_append_sets(CFMutableDataRef record, const uint8_t *const *pointers, const size_t *sizes, const CharonParameterSet *sets, size_t count)
{
    for (size_t i = 0; i < count; i++) {
        size_t size = sizes[sets[i].index];
        uint8_t length[2] = {(uint8_t)(size >> 8), (uint8_t)size};
        CFDataAppendBytes(record, length, 2);
        CFDataAppendBytes(record, pointers[sets[i].index], (CFIndex)size);
    }
}

OSStatus CMVideoFormatDescriptionCreateFromH264ParameterSets(CFAllocatorRef allocator, size_t parameterSetCount, const uint8_t *const *parameterSetPointers,
                                                             const size_t *parameterSetSizes, int NALUnitHeaderLength, CMFormatDescriptionRef *formatDescriptionOut)
{
    if (!formatDescriptionOut)
        return invalidParameter;
    if (parameterSetCount < 2 || !parameterSetPointers || !parameterSetSizes || (NALUnitHeaderLength != 1 && NALUnitHeaderLength != 2 && NALUnitHeaderLength != 4))
        return malformedRecord;
    CharonParameterSet *sets = calloc(3 * parameterSetCount, sizeof *sets);
    CharonParameterSet *sequences = sets, *pictures = sets + parameterSetCount, *extensionSets = sets + 2 * parameterSetCount;
    size_t sequenceCount = 0, pictureCount = 0, extensionCount = 0, lastSequence = 0;
    CharonParameterSet format = {0};
    BOOL hasFormat = NO;
    OSStatus status = noErr;
    for (size_t i = 0; i < parameterSetCount && status == noErr; i++) {
        const uint8_t *nal = parameterSetPointers[i];
        size_t size = parameterSetSizes[i];
        if (!nal || !size || (nal[0] & 0x80) || !(nal[0] & 0x60)) {
            status = malformedRecord;
            break;
        }
        CharonParameterSet set = {i, 0, nal[0] & 0x1F};
        if (set.type != 7 && set.type != 8 && set.type != 13) {
            status = malformedRecord;
            break;
        }
        if (!charon_read_parameter_set(nal, size, &set)) {
            status = unreadableParameterSet;
            break;
        }
        if (set.hasFormat && hasFormat && (set.chroma != format.chroma || set.lumaDepth != format.lumaDepth || set.chromaDepth != format.chromaDepth)) {
            status = malformedRecord;
            break;
        }
        if (set.hasFormat && !hasFormat) {
            format = set;
            hasFormat = YES;
        }
        if (set.type == 7) {
            lastSequence = i;
            sequences[sequenceCount++] = set;
        } else if (set.type == 8) {
            pictures[pictureCount++] = set;
        } else {
            extensionSets[extensionCount++] = set;
        }
    }
    if (status == noErr && (!sequenceCount || !pictureCount))
        status = malformedRecord;
    int profile = 0, constraints = 0xFF, level = 0;
    for (size_t i = 0; i < sequenceCount && status == noErr; i++) {
        profile = sequences[i].profile > profile ? sequences[i].profile : profile;
        level = sequences[i].level > level ? sequences[i].level : level;
        constraints &= sequences[i].constraints;
    }
    CharonSequence *parsed = status == noErr ? calloc(sequenceCount, sizeof *parsed) : NULL;
    const CharonSequence *sized = NULL;
    for (size_t i = 0; i < sequenceCount && status == noErr; i++) {
        CharonSequence *sequence = &parsed[i];
        charon_parse_sequence(parameterSetPointers[sequences[i].index], parameterSetSizes[sequences[i].index], sequence);
        if (!sequence->complete && sequences[i].index == lastSequence)
            status = invalidParameter;
        if (sequence->complete) {
            if (sized && (sized->width != sequence->width || sized->height != sequence->height))
                status = invalidParameter;
            sized = sized ? sized : sequence;
        }
    }
    if (status == noErr && !sized)
        status = invalidParameter;
    if (status != noErr) {
        free(parsed);
        free(sets);
        return status;
    }
    BOOL tail = charon_writes_format(profile);
    if (!tail) {
        memcpy(sequences + sequenceCount, extensionSets, extensionCount * sizeof *sets);
        sequenceCount += extensionCount;
        extensionCount = 0;
    }
    charon_sort_by_identifier(sequences, sequenceCount);
    charon_sort_by_identifier(pictures, pictureCount);
    charon_sort_by_identifier(extensionSets, extensionCount);
    CFMutableDataRef record = CFDataCreateMutable(allocator, 0);
    uint8_t header[6] = {1, (uint8_t)profile, (uint8_t)constraints, (uint8_t)level, (uint8_t)(0xFC | (NALUnitHeaderLength - 1)), (uint8_t)(0xE0 | sequenceCount)};
    CFDataAppendBytes(record, header, 6);
    charon_append_sets(record, parameterSetPointers, parameterSetSizes, sequences, sequenceCount);
    uint8_t pictureTotal = (uint8_t)pictureCount;
    CFDataAppendBytes(record, &pictureTotal, 1);
    charon_append_sets(record, parameterSetPointers, parameterSetSizes, pictures, pictureCount);
    if (tail) {
        uint8_t bytes[4] = {(uint8_t)(0xFC | format.chroma), (uint8_t)(0xF8 | format.lumaDepth), (uint8_t)(0xF8 | format.chromaDepth), (uint8_t)extensionCount};
        CFDataAppendBytes(record, bytes, 4);
        charon_append_sets(record, parameterSetPointers, parameterSetSizes, extensionSets, extensionCount);
    }
    CharonSequence described;
    charon_parse_sequence(parameterSetPointers[sequences[0].index], parameterSetSizes[sequences[0].index], &described);
    if (!described.complete)
        memset(&described, 0, sizeof described);
    const CharonSequence *first = &described;
    CFMutableDictionaryRef extensions = CFDictionaryCreateMutable(allocator, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFMutableDictionaryRef atoms = CFDictionaryCreateMutable(allocator, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(atoms, CFSTR("avcC"), record);
    CFDictionarySetValue(extensions, kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms, atoms);
    CFRelease(atoms);
    CFRelease(record);
    if (first->hasFrames && first->frameOnly) {
        int one = 1;
        CFNumberRef count = CFNumberCreate(allocator, kCFNumberIntType, &one);
        CFDictionarySetValue(extensions, kCVImageBufferFieldCountKey, count);
        CFRelease(count);
    }
    int top = first->hasChromaLocation ? first->chromaTop : 0, bottom = first->hasChromaLocation ? first->chromaBottom : 0;
    if (top == 2 && bottom == 2)
        top = bottom = 1;
    charon_set_code(extensions, kCVImageBufferChromaLocationTopFieldKey, charon_chroma_location(top));
    charon_set_code(extensions, kCVImageBufferChromaLocationBottomFieldKey, charon_chroma_location(bottom));
    if (first->hasVUI) {
        CFDictionarySetValue(extensions, kCMFormatDescriptionExtension_FullRangeVideo, first->hasSignal && first->fullRange ? kCFBooleanTrue : kCFBooleanFalse);
        static const int ratios[17][2] = {{0, 0}, {1, 1}, {12, 11}, {10, 11}, {16, 11}, {40, 33}, {24, 11}, {20, 11}, {32, 11}, {80, 33}, {18, 11}, {15, 11}, {64, 33}, {160, 99}, {4, 3}, {3, 2}, {2, 1}};
        int horizontal = 0, vertical = 0;
        if (first->hasAspect && first->aspect >= 1 && first->aspect <= 16) {
            horizontal = ratios[first->aspect][0];
            vertical = ratios[first->aspect][1];
        } else if (first->hasAspect && first->aspect == 255) {
            horizontal = first->sarWidth;
            vertical = first->sarHeight;
        }
        if (horizontal && vertical) {
            CFNumberRef h = CFNumberCreate(allocator, kCFNumberIntType, &horizontal), v = CFNumberCreate(allocator, kCFNumberIntType, &vertical);
            const void *keys[2] = {kCVImageBufferPixelAspectRatioHorizontalSpacingKey, kCVImageBufferPixelAspectRatioVerticalSpacingKey};
            const void *values[2] = {h, v};
            CFDictionaryRef ratio = CFDictionaryCreate(allocator, keys, values, 2, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
            CFDictionarySetValue(extensions, kCVImageBufferPixelAspectRatioKey, ratio);
            CFRelease(ratio);
            CFRelease(h);
            CFRelease(v);
        }
        if (first->hasColour) {
            charon_set_code(extensions, kCVImageBufferColorPrimariesKey, CVColorPrimariesGetStringForIntegerCodePoint(first->primaries));
            charon_set_code(extensions, kCVImageBufferTransferFunctionKey, CVTransferFunctionGetStringForIntegerCodePoint(first->transfer));
            charon_set_code(extensions, kCVImageBufferYCbCrMatrixKey, CVYCbCrMatrixGetStringForIntegerCodePoint(first->matrix));
        }
    }
    status = CMVideoFormatDescriptionCreate(allocator, kCMVideoCodecType_H264, sized->width, sized->height, extensions, formatDescriptionOut);
    CFRelease(extensions);
    free(parsed);
    free(sets);
    return status;
}
