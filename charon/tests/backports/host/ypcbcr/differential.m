#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>
#include <stdio.h>
#include <stdlib.h>

extern const vImage_YpCbCrToARGBMatrix *charonHost_kvImage_YpCbCrToARGBMatrix_ITU_R_601_4;
extern const vImage_YpCbCrToARGBMatrix *charonHost_kvImage_YpCbCrToARGBMatrix_ITU_R_709_2;
extern const vImage_ARGBToYpCbCrMatrix *charonHost_kvImage_ARGBToYpCbCrMatrix_ITU_R_601_4;
extern const vImage_ARGBToYpCbCrMatrix *charonHost_kvImage_ARGBToYpCbCrMatrix_ITU_R_709_2;
extern vImage_Error charonHost_vImageConvert_YpCbCrToARGB_GenerateConversion(const vImage_YpCbCrToARGBMatrix *, const vImage_YpCbCrPixelRange *, vImage_YpCbCrToARGB *, vImageYpCbCrType, vImageARGBType, vImage_Flags);
extern vImage_Error charonHost_vImageConvert_ARGBToYpCbCr_GenerateConversion(const vImage_ARGBToYpCbCrMatrix *, const vImage_YpCbCrPixelRange *, vImage_ARGBToYpCbCr *, vImageARGBType, vImageYpCbCrType, vImage_Flags);
extern vImage_Error charonHost_vImageConvert_420Yp8_CbCr8ToARGB8888(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_YpCbCrToARGB *, const uint8_t[4], const uint8_t, vImage_Flags);
extern vImage_Error charonHost_vImageConvert_420Yp8_Cb8_Cr8ToARGB8888(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_YpCbCrToARGB *, const uint8_t[4], const uint8_t, vImage_Flags);
extern vImage_Error charonHost_vImageConvert_ARGB8888To420Yp8_CbCr8(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_ARGBToYpCbCr *, const uint8_t[4], vImage_Flags);
extern vImage_Error charonHost_vImageConvert_ARGB8888To420Yp8_Cb8_Cr8(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_ARGBToYpCbCr *, const uint8_t[4], vImage_Flags);
extern vImage_Error charonHost_vImageExtractChannel_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, long, vImage_Flags);
extern vImage_Error charonHost_vImageConvert_RGB565toBGRA8888(Pixel_8, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
extern vImage_Error charonHost_vImageConvert_BGRA8888toRGB565(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
extern vImage_Error charonHost_vImageConvert_ARGB16UtoRGB16U(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
extern vImage_Error charonHost_vImageConvert_ARGBFFFFtoRGBFFF(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);

static int failures, checks;

static void report(BOOL passed, const char *name, NSString *detail)
{
    checks++;
    if (passed) {
        printf("ok   %s\n", name);
        return;
    }
    failures++;
    printf("FAIL %s: %s\n", name, detail.UTF8String);
}

static vImage_Buffer make(vImagePixelCount width, vImagePixelCount height, unsigned channels)
{
    vImage_Buffer buffer = {NULL, height, width, ((size_t)width * channels + 15) & ~(size_t)15};
    buffer.data = calloc(buffer.rowBytes, height);
    return buffer;
}

static void fill(vImage_Buffer buffer, unsigned channels)
{
    for (vImagePixelCount row = 0; row < buffer.height; row++) {
        uint8_t *line = (uint8_t *)buffer.data + row * buffer.rowBytes;
        for (vImagePixelCount column = 0; column < buffer.width * channels; column++)
            line[column] = (uint8_t)(random() & 0xFF);
    }
}

static unsigned long long counted, apart;
static int widest;

static NSString *compare(vImage_Buffer theirs, vImage_Buffer ours, unsigned channels)
{
    int worst = 0;
    unsigned long long where = 0;
    for (vImagePixelCount row = 0; row < theirs.height; row++) {
        const uint8_t *left = (const uint8_t *)theirs.data + row * theirs.rowBytes;
        const uint8_t *right = (const uint8_t *)ours.data + row * ours.rowBytes;
        for (vImagePixelCount column = 0; column < theirs.width * channels; column++) {
            int difference = (int)left[column] - (int)right[column];
            if (difference < 0)
                difference = -difference;
            counted++;
            if (difference == 0)
                continue;
            apart++;
            if (difference > widest)
                widest = difference;
            if (difference > worst) {
                worst = difference;
                where = (unsigned long long)row * 1000000 + column;
            }
        }
    }
    if (worst <= 1)
        return nil;
    return [NSString stringWithFormat:@"row %llu byte %llu differs by %d, which is more than the last bit",
                                      where / 1000000, where % 1000000, worst];
}

struct range_case {
    const char *name;
    vImage_YpCbCrPixelRange range;
};

static const struct range_case ranges[] = {
    {"video range, unclamped", {16, 128, 235, 240, 255, 0, 255, 1}},
    {"video range, clamped", {16, 128, 235, 240, 235, 16, 240, 16}},
    {"full range, clamped", {0, 128, 255, 255, 255, 1, 255, 0}},
    {"full range, wide open", {0, 128, 255, 255, 255, 0, 255, 0}}
};

static void run_size(vImagePixelCount width, vImagePixelCount height, const struct range_case *example,
                     const char *matrixName, const vImage_YpCbCrToARGBMatrix *toARGB,
                     const vImage_ARGBToYpCbCrMatrix *toYpCbCr, const vImage_YpCbCrToARGBMatrix *ourToARGB,
                     const vImage_ARGBToYpCbCrMatrix *ourToYpCbCr, const uint8_t permuteMap[4], uint8_t alpha)
{
    NSString *what = [NSString stringWithFormat:@"%s %s %llux%llu permute %u%u%u%u", matrixName, example->name,
                                                (unsigned long long)width, (unsigned long long)height,
                                                permuteMap[0], permuteMap[1], permuteMap[2], permuteMap[3]];
    vImagePixelCount chromaWidth = (width + 1) / 2, chromaHeight = (height + 1) / 2;
    vImage_Buffer source = make(width, height, 4);
    fill(source, 4);

    vImage_ARGBToYpCbCr theirForward, ourForward;
    vImage_Error theirs = vImageConvert_ARGBToYpCbCr_GenerateConversion(toYpCbCr, &example->range, &theirForward, kvImageARGB8888, kvImage420Yp8_CbCr8, kvImageNoFlags);
    vImage_Error ours = charonHost_vImageConvert_ARGBToYpCbCr_GenerateConversion(ourToYpCbCr, &example->range, &ourForward, kvImageARGB8888, kvImage420Yp8_CbCr8, kvImageNoFlags);
    report(theirs == ours, [what stringByAppendingString:@": the forward conversion is generated"].UTF8String,
           ([NSString stringWithFormat:@"%ld against %ld", (long)theirs, (long)ours]));

    vImage_Buffer theirLuma = make(width, height, 1), ourLuma = make(width, height, 1);
    vImage_Buffer theirCbCr = make(chromaWidth, chromaHeight, 2), ourCbCr = make(chromaWidth, chromaHeight, 2);
    theirs = vImageConvert_ARGB8888To420Yp8_CbCr8(&source, &theirLuma, &theirCbCr, &theirForward, permuteMap, kvImageNoFlags);
    ours = charonHost_vImageConvert_ARGB8888To420Yp8_CbCr8(&source, &ourLuma, &ourCbCr, &ourForward, permuteMap, kvImageNoFlags);
    report(theirs == ours && theirs == kvImageNoError, [what stringByAppendingString:@": ARGB to 420 CbCr answers"].UTF8String,
           ([NSString stringWithFormat:@"%ld against %ld", (long)theirs, (long)ours]));
    NSString *difference = compare(theirLuma, ourLuma, 1);
    report(difference == nil, [what stringByAppendingString:@": the luma plane is within the last bit"].UTF8String, difference ?: @"");
    difference = compare(theirCbCr, ourCbCr, 2);
    report(difference == nil, [what stringByAppendingString:@": the chroma plane is within the last bit"].UTF8String, difference ?: @"");

    vImage_Buffer theirCb = make(chromaWidth, chromaHeight, 1), theirCr = make(chromaWidth, chromaHeight, 1);
    vImage_Buffer ourCb = make(chromaWidth, chromaHeight, 1), ourCr = make(chromaWidth, chromaHeight, 1);
    vImage_Buffer theirPlanarLuma = make(width, height, 1), ourPlanarLuma = make(width, height, 1);
    theirs = vImageConvert_ARGB8888To420Yp8_Cb8_Cr8(&source, &theirPlanarLuma, &theirCb, &theirCr, &theirForward, permuteMap, kvImageNoFlags);
    ours = charonHost_vImageConvert_ARGB8888To420Yp8_Cb8_Cr8(&source, &ourPlanarLuma, &ourCb, &ourCr, &ourForward, permuteMap, kvImageNoFlags);
    report(theirs == ours && theirs == kvImageNoError, [what stringByAppendingString:@": ARGB to 420 Cb Cr answers"].UTF8String,
           ([NSString stringWithFormat:@"%ld against %ld", (long)theirs, (long)ours]));
    difference = compare(theirPlanarLuma, ourPlanarLuma, 1);
    report(difference == nil, [what stringByAppendingString:@": the planar luma is within the last bit"].UTF8String, difference ?: @"");
    difference = compare(theirCb, ourCb, 1);
    report(difference == nil, [what stringByAppendingString:@": the Cb plane is within the last bit"].UTF8String, difference ?: @"");
    difference = compare(theirCr, ourCr, 1);
    report(difference == nil, [what stringByAppendingString:@": the Cr plane is within the last bit"].UTF8String, difference ?: @"");

    vImage_YpCbCrToARGB theirBackward, ourBackward;
    theirs = vImageConvert_YpCbCrToARGB_GenerateConversion(toARGB, &example->range, &theirBackward, kvImage420Yp8_CbCr8, kvImageARGB8888, kvImageNoFlags);
    ours = charonHost_vImageConvert_YpCbCrToARGB_GenerateConversion(ourToARGB, &example->range, &ourBackward, kvImage420Yp8_CbCr8, kvImageARGB8888, kvImageNoFlags);
    report(theirs == ours, [what stringByAppendingString:@": the backward conversion is generated"].UTF8String,
           ([NSString stringWithFormat:@"%ld against %ld", (long)theirs, (long)ours]));

    vImage_Buffer theirBack = make(width, height, 4), ourBack = make(width, height, 4);
    theirs = vImageConvert_420Yp8_CbCr8ToARGB8888(&theirLuma, &theirCbCr, &theirBack, &theirBackward, permuteMap, alpha, kvImageNoFlags);
    ours = charonHost_vImageConvert_420Yp8_CbCr8ToARGB8888(&theirLuma, &theirCbCr, &ourBack, &ourBackward, permuteMap, alpha, kvImageNoFlags);
    report(theirs == ours && theirs == kvImageNoError, [what stringByAppendingString:@": 420 CbCr to ARGB answers"].UTF8String,
           ([NSString stringWithFormat:@"%ld against %ld", (long)theirs, (long)ours]));
    difference = compare(theirBack, ourBack, 4);
    report(difference == nil, [what stringByAppendingString:@": the picture from 420 CbCr is within the last bit"].UTF8String, difference ?: @"");

    vImage_Buffer theirBackPlanar = make(width, height, 4), ourBackPlanar = make(width, height, 4);
    theirs = vImageConvert_420Yp8_Cb8_Cr8ToARGB8888(&theirLuma, &theirCb, &theirCr, &theirBackPlanar, &theirBackward, permuteMap, alpha, kvImageNoFlags);
    ours = charonHost_vImageConvert_420Yp8_Cb8_Cr8ToARGB8888(&theirLuma, &theirCb, &theirCr, &ourBackPlanar, &ourBackward, permuteMap, alpha, kvImageNoFlags);
    report(theirs == ours && theirs == kvImageNoError, [what stringByAppendingString:@": 420 Cb Cr to ARGB answers"].UTF8String,
           ([NSString stringWithFormat:@"%ld against %ld", (long)theirs, (long)ours]));
    difference = compare(theirBackPlanar, ourBackPlanar, 4);
    report(difference == nil, [what stringByAppendingString:@": the picture from 420 Cb Cr is within the last bit"].UTF8String, difference ?: @"");

    for (long channel = 0; channel < 4; channel++) {
        vImage_Buffer theirChannel = make(width, height, 1), ourChannel = make(width, height, 1);
        theirs = vImageExtractChannel_ARGB8888(&source, &theirChannel, channel, kvImageNoFlags);
        ours = charonHost_vImageExtractChannel_ARGB8888(&source, &ourChannel, channel, kvImageNoFlags);
        NSString *name = [what stringByAppendingFormat:@": channel %ld", channel];
        report(theirs == ours && theirs == kvImageNoError, name.UTF8String,
               ([NSString stringWithFormat:@"%ld against %ld", (long)theirs, (long)ours]));
        difference = compare(theirChannel, ourChannel, 1);
        report(difference == nil, [name stringByAppendingString:@" is within the last bit"].UTF8String, difference ?: @"");
        free(theirChannel.data);
        free(ourChannel.data);
    }

    free(source.data);
    free(theirLuma.data); free(ourLuma.data);
    free(theirCbCr.data); free(ourCbCr.data);
    free(theirCb.data); free(theirCr.data); free(ourCb.data); free(ourCr.data);
    free(theirPlanarLuma.data); free(ourPlanarLuma.data);
    free(theirBack.data); free(ourBack.data);
    free(theirBackPlanar.data); free(ourBackPlanar.data);
}

static void run_refusals(void)
{
    vImage_YpCbCrPixelRange range = ranges[0].range;
    vImage_YpCbCrToARGB theirBackward, ourBackward;
    vImage_ARGBToYpCbCr theirForward, ourForward;

    struct { const char *name; vImage_Error theirs; vImage_Error ours; } cases[] = {
        {"an unknown flag on the backward conversion",
         vImageConvert_YpCbCrToARGB_GenerateConversion(kvImage_YpCbCrToARGBMatrix_ITU_R_601_4, &range, &theirBackward, kvImage420Yp8_CbCr8, kvImageARGB8888, (vImage_Flags)0x40000000),
         charonHost_vImageConvert_YpCbCrToARGB_GenerateConversion(charonHost_kvImage_YpCbCrToARGBMatrix_ITU_R_601_4, &range, &ourBackward, kvImage420Yp8_CbCr8, kvImageARGB8888, (vImage_Flags)0x40000000)},
        {"an unknown flag on the forward conversion",
         vImageConvert_ARGBToYpCbCr_GenerateConversion(kvImage_ARGBToYpCbCrMatrix_ITU_R_601_4, &range, &theirForward, kvImageARGB8888, kvImage420Yp8_CbCr8, (vImage_Flags)0x40000000),
         charonHost_vImageConvert_ARGBToYpCbCr_GenerateConversion(charonHost_kvImage_ARGBToYpCbCrMatrix_ITU_R_601_4, &range, &ourForward, kvImageARGB8888, kvImage420Yp8_CbCr8, (vImage_Flags)0x40000000)},
        {"an ARGB type neither side converts",
         vImageConvert_YpCbCrToARGB_GenerateConversion(kvImage_YpCbCrToARGBMatrix_ITU_R_601_4, &range, &theirBackward, kvImage420Yp8_CbCr8, kvImageARGB16U, kvImageNoFlags),
         charonHost_vImageConvert_YpCbCrToARGB_GenerateConversion(charonHost_kvImage_YpCbCrToARGBMatrix_ITU_R_601_4, &range, &ourBackward, kvImage420Yp8_CbCr8, kvImageARGB16U, kvImageNoFlags)}
    };
    for (unsigned index = 0; index < sizeof cases / sizeof cases[0]; index++)
        report(cases[index].theirs == cases[index].ours, cases[index].name,
               ([NSString stringWithFormat:@"the system answers %ld, the backport answers %ld", (long)cases[index].theirs, (long)cases[index].ours]));

    vImage_YpCbCrPixelRange wideRange = {4096, 32768, 60160, 61440, 65535, 0, 65535, 1};
    /* The port used to carry only the 420 8-bit types and refused the rest as unsupported; it carries the
       whole of Conversion.h's set now, and tests/backports/host/ypcbcr8 asks every Y'CbCr type against
       every ARGB type and holds both to the system's answers. What is left here is the pair neither
       carries: a sixteen-bit Y'CbCr type with a Q12 destination, and the same with a Q12 source. */
    report(charonHost_vImageConvert_YpCbCrToARGB_GenerateConversion(charonHost_kvImage_YpCbCrToARGBMatrix_ITU_R_601_4, &wideRange, &ourBackward, kvImage422CbYpCrYp16, kvImageARGB16Q12, kvImageNoFlags) == vImageConvert_YpCbCrToARGB_GenerateConversion(kvImage_YpCbCrToARGBMatrix_ITU_R_601_4, &wideRange, &theirBackward, kvImage422CbYpCrYp16, kvImageARGB16Q12, kvImageNoFlags),
           "a sixteen-bit Y'CbCr type into a Q12 destination is refused alike", @"one side answered something else");
    report(charonHost_vImageConvert_ARGBToYpCbCr_GenerateConversion(charonHost_kvImage_ARGBToYpCbCrMatrix_ITU_R_601_4, &wideRange, &ourForward, kvImageARGB16Q12, kvImage444AYpCbCr16, kvImageNoFlags) == vImageConvert_ARGBToYpCbCr_GenerateConversion(kvImage_ARGBToYpCbCrMatrix_ITU_R_601_4, &wideRange, &theirForward, kvImageARGB16Q12, kvImage444AYpCbCr16, kvImageNoFlags),
           "a Q12 source into a sixteen-bit Y'CbCr type is refused alike", @"one side answered something else");

    vImage_Buffer source = make(8, 8, 4), channel = make(8, 8, 1);
    for (long bad = -1; bad <= 4; bad += 5) {
        vImage_Error theirs = vImageExtractChannel_ARGB8888(&source, &channel, bad, kvImageNoFlags);
        vImage_Error ours = charonHost_vImageExtractChannel_ARGB8888(&source, &channel, bad, kvImageNoFlags);
        report(theirs == ours, "a channel index outside the pixel is refused alike",
               ([NSString stringWithFormat:@"index %ld: the system answers %ld, the backport answers %ld", bad, (long)theirs, (long)ours]));
    }
    vImage_Buffer bigger = make(16, 16, 1);
    vImage_Error theirs = vImageExtractChannel_ARGB8888(&source, &bigger, 0, kvImageNoFlags);
    vImage_Error ours = charonHost_vImageExtractChannel_ARGB8888(&source, &bigger, 0, kvImageNoFlags);
    report(theirs == ours, "a destination larger than the source is refused alike",
           ([NSString stringWithFormat:@"the system answers %ld, the backport answers %ld", (long)theirs, (long)ours]));
    free(source.data);
    free(channel.data);
    free(bigger.data);
}

static void run_pixels(void)
{
    const vImagePixelCount width = 37, height = 11;
    vImage_Buffer packed = make(width, height, 2), theirWide = make(width, height, 4), ourWide = make(width, height, 4);
    fill(packed, 2);
    vImage_Error theirs = vImageConvert_RGB565toBGRA8888(0xC3, &packed, &theirWide, kvImageNoFlags);
    vImage_Error ours = charonHost_vImageConvert_RGB565toBGRA8888(0xC3, &packed, &ourWide, kvImageNoFlags);
    report(theirs == ours && theirs == kvImageNoError, "RGB565 becomes BGRA8888",
           ([NSString stringWithFormat:@"%ld against %ld", (long)theirs, (long)ours]));
    NSString *difference = compare(theirWide, ourWide, 4);
    report(difference == nil, "the BGRA8888 from RGB565 is within the last bit", difference ?: @"");

    vImage_Buffer wide = make(width, height, 4), theirPacked = make(width, height, 2), ourPacked = make(width, height, 2);
    fill(wide, 4);
    theirs = vImageConvert_BGRA8888toRGB565(&wide, &theirPacked, kvImageNoFlags);
    ours = charonHost_vImageConvert_BGRA8888toRGB565(&wide, &ourPacked, kvImageNoFlags);
    report(theirs == ours && theirs == kvImageNoError, "BGRA8888 becomes RGB565",
           ([NSString stringWithFormat:@"%ld against %ld", (long)theirs, (long)ours]));
    difference = compare(theirPacked, ourPacked, 2);
    report(difference == nil, "the RGB565 from BGRA8888 is within the last bit", difference ?: @"");

    vImage_Buffer deep = make(width, height, 8), theirThree = make(width, height, 6), ourThree = make(width, height, 6);
    fill(deep, 8);
    theirs = vImageConvert_ARGB16UtoRGB16U(&deep, &theirThree, kvImageNoFlags);
    ours = charonHost_vImageConvert_ARGB16UtoRGB16U(&deep, &ourThree, kvImageNoFlags);
    report(theirs == ours && theirs == kvImageNoError, "ARGB16U loses its alpha",
           ([NSString stringWithFormat:@"%ld against %ld", (long)theirs, (long)ours]));
    difference = compare(theirThree, ourThree, 6);
    report(difference == nil, "the RGB16U is the bytes of the ARGB16U", difference ?: @"");

    vImage_Buffer floats = make(width, height, 16), theirFloats = make(width, height, 12), ourFloats = make(width, height, 12);
    fill(floats, 16);
    theirs = vImageConvert_ARGBFFFFtoRGBFFF(&floats, &theirFloats, kvImageNoFlags);
    ours = charonHost_vImageConvert_ARGBFFFFtoRGBFFF(&floats, &ourFloats, kvImageNoFlags);
    report(theirs == ours && theirs == kvImageNoError, "ARGBFFFF loses its alpha",
           ([NSString stringWithFormat:@"%ld against %ld", (long)theirs, (long)ours]));
    difference = compare(theirFloats, ourFloats, 12);
    report(difference == nil, "the RGBFFF is the bytes of the ARGBFFFF", difference ?: @"");

    vImage_Buffer small = make(4, 4, 4);
    theirs = vImageConvert_BGRA8888toRGB565(&small, &theirPacked, kvImageNoFlags);
    ours = charonHost_vImageConvert_BGRA8888toRGB565(&small, &ourPacked, kvImageNoFlags);
    report(theirs == ours, "a destination larger than the source is refused alike by RGB565",
           ([NSString stringWithFormat:@"the system answers %ld, the backport answers %ld", (long)theirs, (long)ours]));
    vImage_Buffer tinyPacked = make(4, 4, 2);
    theirs = vImageConvert_RGB565toBGRA8888(0, &tinyPacked, &theirWide, kvImageNoFlags);
    ours = charonHost_vImageConvert_RGB565toBGRA8888(0, &tinyPacked, &ourWide, kvImageNoFlags);
    report(theirs == ours, "a destination larger than the source is refused alike by the 565 expansion",
           ([NSString stringWithFormat:@"the system answers %ld, the backport answers %ld", (long)theirs, (long)ours]));
    free(tinyPacked.data);
    theirs = vImageConvert_RGB565toBGRA8888(0, &packed, &theirWide, (vImage_Flags)0x40000000);
    ours = charonHost_vImageConvert_RGB565toBGRA8888(0, &packed, &ourWide, (vImage_Flags)0x40000000);
    report(theirs == ours, "an unknown flag is refused alike by RGB565",
           ([NSString stringWithFormat:@"the system answers %ld, the backport answers %ld", (long)theirs, (long)ours]));
    theirs = vImageConvert_RGB565toBGRA8888(0, &packed, &theirWide, kvImageGetTempBufferSize);
    ours = charonHost_vImageConvert_RGB565toBGRA8888(0, &packed, &ourWide, kvImageGetTempBufferSize);
    report(theirs == ours, "asked for a temporary buffer both answer the same",
           ([NSString stringWithFormat:@"the system answers %ld, the backport answers %ld", (long)theirs, (long)ours]));

    free(packed.data); free(theirWide.data); free(ourWide.data);
    free(wide.data); free(theirPacked.data); free(ourPacked.data);
    free(deep.data); free(theirThree.data); free(ourThree.data);
    free(floats.data); free(theirFloats.data); free(ourFloats.data);
    free(small.data);
}

int main(void)
{
    @autoreleasepool {
        srandom(20260921);
        static const uint8_t permutations[][4] = {{0, 1, 2, 3}, {3, 2, 1, 0}, {1, 2, 3, 0}, {2, 1, 0, 3}};
        static const vImagePixelCount sizes[][2] = {{16, 8}, {64, 48}, {2, 2}, {34, 18}};
        for (unsigned example = 0; example < sizeof ranges / sizeof ranges[0]; example++)
            for (unsigned size = 0; size < sizeof sizes / sizeof sizes[0]; size++) {
                unsigned which = (example + size) % (sizeof permutations / sizeof permutations[0]);
                run_size(sizes[size][0], sizes[size][1], &ranges[example], "601-4",
                         kvImage_YpCbCrToARGBMatrix_ITU_R_601_4, kvImage_ARGBToYpCbCrMatrix_ITU_R_601_4,
                         charonHost_kvImage_YpCbCrToARGBMatrix_ITU_R_601_4, charonHost_kvImage_ARGBToYpCbCrMatrix_ITU_R_601_4,
                         permutations[which], (uint8_t)(0x20 * which + 15));
                run_size(sizes[size][0], sizes[size][1], &ranges[example], "709-2",
                         kvImage_YpCbCrToARGBMatrix_ITU_R_709_2, kvImage_ARGBToYpCbCrMatrix_ITU_R_709_2,
                         charonHost_kvImage_YpCbCrToARGBMatrix_ITU_R_709_2, charonHost_kvImage_ARGBToYpCbCrMatrix_ITU_R_709_2,
                         permutations[which], (uint8_t)(0x20 * which + 15));
            }
        run_refusals();
        run_pixels();

        report(memcmp(kvImage_YpCbCrToARGBMatrix_ITU_R_601_4, charonHost_kvImage_YpCbCrToARGBMatrix_ITU_R_601_4, sizeof(vImage_YpCbCrToARGBMatrix)) == 0,
               "the 601-4 YpCbCr to ARGB matrix is the system's own", @"the coefficients differ");
        report(memcmp(kvImage_YpCbCrToARGBMatrix_ITU_R_709_2, charonHost_kvImage_YpCbCrToARGBMatrix_ITU_R_709_2, sizeof(vImage_YpCbCrToARGBMatrix)) == 0,
               "the 709-2 YpCbCr to ARGB matrix is the system's own", @"the coefficients differ");
        report(memcmp(kvImage_ARGBToYpCbCrMatrix_ITU_R_601_4, charonHost_kvImage_ARGBToYpCbCrMatrix_ITU_R_601_4, sizeof(vImage_ARGBToYpCbCrMatrix)) == 0,
               "the 601-4 ARGB to YpCbCr matrix is the system's own", @"the coefficients differ");
        report(memcmp(kvImage_ARGBToYpCbCrMatrix_ITU_R_709_2, charonHost_kvImage_ARGBToYpCbCrMatrix_ITU_R_709_2, sizeof(vImage_ARGBToYpCbCrMatrix)) == 0,
               "the 709-2 ARGB to YpCbCr matrix is the system's own", @"the coefficients differ");

        printf("%llu of %llu bytes differ by one, none by more; the widest difference is %d\n", apart, counted, widest);
        printf("%d of %d checks failed\n", failures, checks);
        return failures > 0;
    }
}
