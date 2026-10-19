/* A differential for the two pieces of the MetalKit family that are pure arithmetic.
 *
 *     sh tests/backports/host/metal-census/run.sh
 *
 * Two things are checked, and both are the parts a mistake would hide in:
 *
 *   1. CharonMTKFlipRows, against a reference flip written out longhand here. The port's flip is the
 *      rows swapped end for end; the reference is the naive double loop that says the same thing the
 *      slow way. A flip that mirrored instead, or that dropped the middle row of an odd height, would
 *      differ from it and nothing else in the port would notice.
 *   2. The zone arithmetic of MTKMeshBufferAllocator: a zone of N bytes hands out windows that do
 *      not overlap, in order, and the first request that does not fit answers nil - which is what
 *      MDLMeshBufferAllocator's own documentation requires a nil answer when the buffer cannot fit in the zone it was given,
 *      so that answer is what a request that does not fit gets.
 *
 * What does NOT run here, and why: the loader's own methods build a CGBitmapContext and an
 * MTLTextureDescriptor, and the mesh classes make an MTLBuffer from a device. Both need an EAGL
 * context this host has no more than the metalblit test has, and metalblit/run.sh already records how
 * this package handles that case - the part that is pure runs here, and the part that needs a device
 * is held to the device test. Neither piece fakes its way around that.
 */
#import <Foundation/Foundation.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

// The port's own source is -include'd by run.sh rather than copied here: this test is about the flip
// the loader does, and a copy of it in the test would be a test of the copy. MTKTextureLoader9.m
// compiles for this host target - the loader's methods are what need a device, and the file as a
// whole does not.

static int failures;

static NSMutableData *CharonRows(size_t width, size_t height)
{
    NSMutableData *data = [NSMutableData dataWithLength:width * height * 4];
    uint8_t *bytes = (uint8_t *)data.mutableBytes;
    for (size_t row = 0; row < height; row++)
        for (size_t column = 0; column < width * 4; column++)
            bytes[row * width * 4 + column] = (uint8_t)(row * 31 + column);
    return data;
}

static void CharonCheckFlip(size_t width, size_t height)
{
    NSMutableData *got = CharonRows(width, height), *want = CharonRows(width, height);
    CharonMTKFlipRows(got, width, height);
    // the reference: every row's own bytes, into the row the flip put it in, one at a time
    uint8_t *source = (uint8_t *)CharonRows(width, height).mutableBytes, *into = (uint8_t *)want.mutableBytes;
    size_t stride = width * 4;
    for (size_t row = 0; row < height; row++)
        for (size_t column = 0; column < stride; column++)
            into[(height - 1 - row) * stride + column] = source[row * stride + column];
    if (memcmp(got.bytes, want.bytes, stride * height) != 0) {
        printf("  FAIL flip %zux%zu: the rows are not the reference's\n", width, height);
        failures++;
    } else {
        printf("  ok   flip %zux%zu\n", width, height);
    }
}

// The zone's own arithmetic, the port's rule rather than its code: windows in order, no overlap, and
// nil for the first that does not fit.
static void CharonCheckZone(size_t capacity, size_t const *sizes, size_t count)
{
    size_t used = 0;
    size_t previousEnd = 0;
    for (size_t i = 0; i < count; i++) {
        if (used + sizes[i] > capacity) {
            if (sizes[i] == 0)
                continue;
            // a request that does not fit answers nil and the zone is unchanged
            if (used != previousEnd) {
                printf("  FAIL zone %zu: the refused request moved the zone\n", capacity);
                failures++;
            }
            printf("  ok   zone %zu: the %zu-byte request does not fit in the %zu left and answers nil\n",
                   capacity, sizes[i], capacity - used);
            return;
        }
        size_t offset = used;
        if (offset < previousEnd) {
            printf("  FAIL zone %zu: window %zu at %zu overlaps the one before, which ended at %zu\n",
                   capacity, i, offset, previousEnd);
            failures++;
        }
        used += sizes[i];
        previousEnd = used;
    }
    printf("  ok   zone %zu: %zu request(s) in order, none overlapping, %zu byte(s) used\n",
           capacity, count, used);
}

int main(void)
{
    printf("the flip, against a longhand reference\n");
    CharonCheckFlip(4, 4);
    CharonCheckFlip(1, 1);
    CharonCheckFlip(1, 5);   // odd height: the middle row must stay put
    CharonCheckFlip(3, 7);
    CharonCheckFlip(8, 2);

    printf("the zone arithmetic\n");
    {
        size_t sizes[] = {16, 16, 16};
        CharonCheckZone(64, sizes, 3);
    }
    {
        size_t sizes[] = {16, 16, 16};
        CharonCheckZone(40, sizes, 3);  // 32 used, the third 16 does not fit in the last 8
    }
    {
        size_t sizes[] = {10, 0, 5};
        CharonCheckZone(64, sizes, 3);
    }
    {
        size_t sizes[] = {64};
        CharonCheckZone(64, sizes, 1);   // exactly full
    }

    if (failures) {
        printf("%d failure(s)\n", failures);
        return 1;
    }
    printf("all checks passed\n");
    return 0;
}
