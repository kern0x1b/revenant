#import <Foundation/Foundation.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

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

static void CharonCheckZone(size_t capacity, size_t const *sizes, size_t count)
{
    size_t used = 0;
    size_t previousEnd = 0;
    for (size_t i = 0; i < count; i++) {
        if (used + sizes[i] > capacity) {
            if (sizes[i] == 0)
                continue;
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
    CharonCheckFlip(1, 5);
    CharonCheckFlip(3, 7);
    CharonCheckFlip(8, 2);

    printf("the zone arithmetic\n");
    {
        size_t sizes[] = {16, 16, 16};
        CharonCheckZone(64, sizes, 3);
    }
    {
        size_t sizes[] = {16, 16, 16};
        CharonCheckZone(40, sizes, 3);
    }
    {
        size_t sizes[] = {10, 0, 5};
        CharonCheckZone(64, sizes, 3);
    }
    {
        size_t sizes[] = {64};
        CharonCheckZone(64, sizes, 1);
    }

    if (failures) {
        printf("%d failure(s)\n", failures);
        return 1;
    }
    printf("all checks passed\n");
    return 0;
}
