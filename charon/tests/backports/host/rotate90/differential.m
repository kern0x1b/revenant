// vImage's quarter turns, held against the host's own: the same buffers through both, every sample
// compared, over the eight shapes the mapping was measured on and both destination shapes for each.
//
// The point of the comparison is that a quarter turn moves pixels and does not resample, so the two answers
// have to be equal sample for sample - there is no rounding to allow. Where they differ by more than
// nothing, the mapping is wrong; where the two shapes of the destination disagree with each other, the
// centring is wrong.

#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define RENAME(x) charonHost_##x
extern vImage_Error RENAME(vImageRotate90_ARGB16U)(const vImage_Buffer *, const vImage_Buffer *, uint8_t,
                                                   const Pixel_ARGB_16U, vImage_Flags);
extern vImage_Error RENAME(vImageRotate90_ARGB16S)(const vImage_Buffer *, const vImage_Buffer *, uint8_t,
                                                   const Pixel_ARGB_16S, vImage_Flags);
extern vImage_Error RENAME(vImageRotate90_ARGB16F)(const vImage_Buffer *, const vImage_Buffer *, uint8_t,
                                                   const Pixel_ARGB_16F, vImage_Flags);
extern vImage_Error RENAME(vImageRotate90_CbCr16F)(const vImage_Buffer *, const vImage_Buffer *, uint8_t,
                                                   const Pixel_16F16F, vImage_Flags);
extern vImage_Error RENAME(vImageRotate90_Planar16F)(const vImage_Buffer *, const vImage_Buffer *, uint8_t,
                                                     const Pixel_16F, vImage_Flags);

static int checks, failures;

static void report(BOOL passed, NSString *name, NSString *detail)
{
    checks++;
    if (passed) {
        printf("ok   %s\n", name.UTF8String);
        return;
    }
    failures++;
    printf("FAIL %s: %s\n", name.UTF8String, detail.UTF8String);
}

static vImage_Buffer make(vImagePixelCount width, vImagePixelCount height, size_t bytes)
{
    vImage_Buffer buffer = {0};
    buffer.width = width;
    buffer.height = height;
    buffer.rowBytes = (width * bytes + 63) & ~(size_t)63;
    buffer.data = calloc(buffer.rowBytes, height);
    return buffer;
}

static void fill(vImage_Buffer buffer)
{
    // A fixed sequence, so a run is reproducible: every channel of every pixel a different value, and the
    // three halves a set that spans the whole half range including the subnormals and the infinities.
    uint64_t seed = 0x9E3779B97F4A7C15ull;
    static const uint16_t halves[] = {0x0000, 0x8000, 0x3C00, 0xBC00, 0x0100, 0x7BFF, 0x0400, 0xC001,
                                      0x3555, 0xB555, 0x7C00, 0xFC00, 0x0200, 0x8200, 0x3AAA, 0xF800};
    for (vImagePixelCount row = 0; row < buffer.height; row++) {
        uint16_t *line = (uint16_t *)((uint8_t *)buffer.data + (size_t)row * buffer.rowBytes);
        for (size_t at = 0; at < buffer.rowBytes / 2; at++) {
            seed = seed * 6364136223846793005ull + 1442695040888963407ull;
            line[at] = (seed >> 33) & 0xFFFFu;
        }
        // and the halves drawn from the table, so a float shape is not all finite normals
        for (size_t at = 0; at < buffer.rowBytes / 2; at++)
            if ((at % 3) == 0)
                line[at] = halves[(at + row) % (sizeof halves / sizeof *halves)];
    }
}

static NSString *compare(vImage_Buffer theirs, vImage_Buffer ours)
{
    for (vImagePixelCount row = 0; row < theirs.height; row++) {
        const uint8_t *left = (const uint8_t *)theirs.data + (size_t)row * theirs.rowBytes;
        const uint8_t *right = (const uint8_t *)ours.data + (size_t)row * ours.rowBytes;
        for (size_t at = 0; at < theirs.rowBytes; at++) {
            if (left[at] == right[at])
                continue;
            return [NSString stringWithFormat:@"row %llu byte %llu: the system has 0x%02x, the port 0x%02x",
                                              (unsigned long long)row, (unsigned long long)at, left[at], right[at]];
        }
    }
    return nil;
}

// One shape, one destination shape, one constant, and whichever of the five functions the caller names.
static void one(NSString *label, vImagePixelCount srcW, vImagePixelCount srcH, vImagePixelCount destW,
                vImagePixelCount destH, size_t bytes, uint8_t constant, vImage_Flags flags)
{
    vImage_Buffer source = make(srcW, srcH, bytes);
    vImage_Buffer theirDest = make(destW, destH, bytes);
    vImage_Buffer ourDest = make(destW, destH, bytes);
    fill(source);
    // the same backColor for both, a value in the middle of the range that is not in the source sequence
    uint8_t back[8];
    for (size_t at = 0; at < bytes; at++)
        back[at] = (uint8_t)(0xA5u ^ (at * 31u));
    vImage_Error theirs, ours;
    if (bytes == 8 && strcmp(label.UTF8String, "ARGB16F") == 0) {
        theirs = vImageRotate90_ARGB16F(&source, &theirDest, constant, (const uint16_t *)back, flags);
        ours = RENAME(vImageRotate90_ARGB16F)(&source, &ourDest, constant, (const uint16_t *)back, flags);
    } else if (bytes == 8) {
        theirs = vImageRotate90_ARGB16U(&source, &theirDest, constant, (const uint16_t *)back, flags);
        ours = RENAME(vImageRotate90_ARGB16U)(&source, &ourDest, constant, (const uint16_t *)back, flags);
    } else if (bytes == 4) {
        theirs = vImageRotate90_CbCr16F(&source, &theirDest, constant, (const uint16_t *)back, flags);
        ours = RENAME(vImageRotate90_CbCr16F)(&source, &ourDest, constant, (const uint16_t *)back, flags);
    } else {
        Pixel_16F one16 = *(const uint16_t *)back;
        theirs = vImageRotate90_Planar16F(&source, &theirDest, constant, one16, flags);
        ours = RENAME(vImageRotate90_Planar16F)(&source, &ourDest, constant, one16, flags);
    }
    NSString *what = [NSString stringWithFormat:@"%@ %llux%llu into %llux%llu constant %u",
                                                label, (unsigned long long)srcW, (unsigned long long)srcH,
                                                (unsigned long long)destW, (unsigned long long)destH, constant];
    report(theirs == ours, [what stringByAppendingString:@": answers"],
           ([NSString stringWithFormat:@"the system answers %ld, the port %ld", (long)theirs, (long)ours]));
    if (theirs != kvImageNoError)
        return;
    NSString *difference = compare(theirDest, ourDest);
    report(difference == nil, [what stringByAppendingString:@": every sample agrees"], difference ?: @"");
    free(source.data);
    free(theirDest.data);
    free(ourDest.data);
}

int main(void)
{
    setbuf(stdout, NULL);
    @autoreleasepool {
        static const struct { int w, h; } shapes[] = {
            {6, 4}, {4, 6}, {4, 3}, {3, 4}, {5, 3}, {3, 5}, {5, 5}, {2, 3}, {3, 2}, {6, 5}, {7, 1}, {1, 7}};
        for (unsigned shape = 0; shape < sizeof shapes / sizeof *shapes; shape++) {
            vImagePixelCount w = (vImagePixelCount)shapes[shape].w, h = (vImagePixelCount)shapes[shape].h;
            for (uint8_t constant = 0; constant < 4; constant++) {
                // both destination shapes: the one the constant wants, and the other one, which the system
                // answers by centring the turned picture
                one(@"ARGB16U", w, h, w, h, 8, constant, kvImageBackgroundColorFill);
                one(@"ARGB16U", w, h, h, w, 8, constant, kvImageBackgroundColorFill);
                one(@"ARGB16S", w, h, w, h, 8, constant, kvImageBackgroundColorFill);
                one(@"ARGB16F", w, h, h, w, 8, constant, kvImageBackgroundColorFill);
                one(@"CbCr16F", w, h, h, w, 4, constant, kvImageBackgroundColorFill);
                one(@"Planar16F", w, h, h, w, 2, constant, kvImageBackgroundColorFill);
            }
            // the edging mode the header documents and the accumulation flag the half shapes take
            one(@"ARGB16U", w, h, h, w, 8, 1, kvImageEdgeExtend);
            one(@"ARGB16F", w, h, h, w, 8, 1, kvImageBackgroundColorFill | kvImageUseFP16Accumulator);
            one(@"Planar16F", w, h, h, w, 2, 3, kvImageDoNotTile);
        }

        // The refusals. A constant outside the four the header names, and a NULL buffer. There is no flag
        // check on either side, and the run below is why: the system answers kvImageNoError for every one
        // of the thirty-two bits, so a port that refused one would be refusing something the system never
        // refuses.
        vImage_Buffer source = make(4, 4, 8), dest = make(4, 4, 8);
        Pixel_ARGB_16U black = {0, 0, 0, 0xffff};
        for (unsigned bad = 4; bad < 8; bad++) {
            vImage_Error theirs = vImageRotate90_ARGB16U(&source, &dest, (uint8_t)bad, black, kvImageBackgroundColorFill);
            vImage_Error ours = RENAME(vImageRotate90_ARGB16U)(&source, &dest, (uint8_t)bad, black, kvImageBackgroundColorFill);
            report(theirs == ours, ([NSString stringWithFormat:@"a rotationConstant of %u is refused alike", bad]),
                   ([NSString stringWithFormat:@"the system answers %ld, the port %ld", (long)theirs, (long)ours]));
        }
        vImage_Error theirs = vImageRotate90_ARGB16U(&source, &dest, 0, black, (vImage_Flags)0x40000000);
        vImage_Error ours = RENAME(vImageRotate90_ARGB16U)(&source, &dest, 0, black, (vImage_Flags)0x40000000);
        report(theirs == ours, @"a flag the header does not list is answered, not refused",
               ([NSString stringWithFormat:@"the system answers %ld, the port %ld", (long)theirs, (long)ours]));
        theirs = vImageRotate90_ARGB16U(NULL, &dest, 0, black, kvImageBackgroundColorFill);
        ours = RENAME(vImageRotate90_ARGB16U)(NULL, &dest, 0, black, kvImageBackgroundColorFill);
        report(theirs == ours, @"a NULL source is refused alike",
               ([NSString stringWithFormat:@"the system answers %ld, the port %ld", (long)theirs, (long)ours]));

        theirs = vImageRotate90_ARGB16U(&source, &dest, 0, black, kvImageGetTempBufferSize);
        ours = RENAME(vImageRotate90_ARGB16U)(&source, &dest, 0, black, kvImageGetTempBufferSize);
        report(theirs == ours, @"kvImageGetTempBufferSize, which the header does not list here, is answered",
               ([NSString stringWithFormat:@"the system answers %ld, the port %ld", (long)theirs, (long)ours]));
        // every bit on its own, which is the measurement the port's missing flag check rests on
        for (int bit = 0; bit < 32; bit++) {
            vImage_Flags flag = (vImage_Flags)(1u << bit);
            vImage_Error a = vImageRotate90_ARGB16U(&source, &dest, 1, black, flag);
            vImage_Error b = RENAME(vImageRotate90_ARGB16U)(&source, &dest, 1, black, flag);
            if (a != b) {
                report(NO, ([NSString stringWithFormat:@"flag bit %d is answered alike", bit]),
                       ([NSString stringWithFormat:@"the system answers %ld, the port %ld", (long)a, (long)b]));
                break;
            }
        }
        report(YES, @"every one of the thirty-two flag bits is answered alike", @"");

        printf("\n%d checks, %d failures\n", checks, failures);
    }
    return failures ? 1 : 0;
}
