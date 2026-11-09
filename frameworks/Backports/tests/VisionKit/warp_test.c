#include "RevenantDocumentWarp.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int checks;
static int failures;
static int negative;

static void check(int ok, const char *name)
{
    checks++;
    if (negative)
        ok = !ok;
    if (!ok) {
        failures++;
        printf("FAILED: %s\n", name);
    }
}

static RevenantDocumentPoint point(float x, float y)
{
    RevenantDocumentPoint p = {x, y};
    return p;
}

static uint8_t *make_pattern(size_t width, size_t height, size_t row_bytes)
{
    uint8_t *pixels = calloc(row_bytes * height, 1);
    for (size_t y = 0; y < height; ++y) {
        for (size_t x = 0; x < width; ++x) {
            uint8_t *p = pixels + y * row_bytes + x * 4;
            p[0] = (uint8_t)(x * 255 / (width - 1));
            p[1] = (uint8_t)(y * 255 / (height - 1));
            p[2] = (uint8_t)((x + y) % 2 ? 200 : 40);
            p[3] = 255;
        }
    }
    return pixels;
}

static int near(int actual, int expected, int tolerance)
{
    return abs(actual - expected) <= tolerance;
}

static void test_identity(void)
{
    size_t width = 64, height = 48;
    uint8_t *source = make_pattern(width, height, width * 4);
    uint8_t *output = calloc(width * height * 4, 1);
    RevenantDocumentPoint quad[4] = {point(0, 0), point((float)width, 0), point((float)width, (float)height), point(0, (float)height)};
    check(RevenantDocumentWarp(source, width, height, width * 4, quad, output, width, height, width * 4) == 1, "identity warp succeeds");
    check(memcmp(source, output, width * height * 4) == 0, "the full image quad reproduces the image exactly");
    free(source);
    free(output);
}

static void test_sizes(void)
{
    RevenantDocumentPoint rectangle[4] = {point(10, 10), point(110, 10), point(110, 60), point(10, 60)};
    RevenantDocumentSize size = RevenantDocumentOutputSize(rectangle, 0);
    check(size.width == 100 && size.height == 50, "a 100 by 50 rectangle keeps its size");
    size = RevenantDocumentOutputSize(rectangle, 40);
    check(size.width == 40 && size.height == 20, "a limit of 40 scales both sides");
    size = RevenantDocumentOutputSize(rectangle, 500);
    check(size.width == 100 && size.height == 50, "a limit above the size changes nothing");
    RevenantDocumentPoint trapezoid[4] = {point(30, 0), point(70, 0), point(100, 80), point(0, 80)};
    size = RevenantDocumentOutputSize(trapezoid, 0);
    check(size.width == 100 && size.height == 85, "a trapezoid takes its longest opposite edges");
    RevenantDocumentPoint tiny[4] = {point(0, 0), point(0.2f, 0), point(0.2f, 0.2f), point(0, 0.2f)};
    size = RevenantDocumentOutputSize(tiny, 0);
    check(size.width == 1 && size.height == 1, "a tiny quad still has one pixel");
}

static void test_perspective(void)
{
    size_t width = 400, height = 300;
    uint8_t *source = make_pattern(width, height, width * 4);
    RevenantDocumentPoint quad[4] = {point(80, 40), point(330, 70), point(380, 260), point(40, 230)};
    RevenantDocumentSize size = RevenantDocumentOutputSize(quad, 0);
    uint8_t *output = calloc(size.width * size.height * 4, 1);
    check(RevenantDocumentWarp(source, width, height, width * 4, quad, output, size.width, size.height, size.width * 4) == 1,
          "perspective warp succeeds");
    float x0 = quad[0].x, y0 = quad[0].y, x1 = quad[2].x, y1 = quad[2].y, x2 = quad[1].x, y2 = quad[1].y, x3 = quad[3].x, y3 = quad[3].y;
    float denominator = (x0 - x1) * (y2 - y3) - (y0 - y1) * (x2 - x3);
    float t = ((x0 - x2) * (y2 - y3) - (y0 - y2) * (x2 - x3)) / denominator;
    float cx = x0 + t * (x1 - x0), cy = y0 + t * (y1 - y0);
    const uint8_t *centre = output + (size.height / 2) * size.width * 4 + (size.width / 2) * 4;
    int expected_red = (int)(cx * 255 / (width - 1));
    int expected_green = (int)(cy * 255 / (height - 1));
    check(near(centre[0], expected_red, 3), "the centre of the output is the diagonal crossing of the quad (red)");
    check(near(centre[1], expected_green, 3), "the centre of the output is the diagonal crossing of the quad (green)");
    const uint8_t *top_left = output;
    check(near(top_left[0], (int)(quad[0].x * 255 / (width - 1)), 3) && near(top_left[1], (int)(quad[0].y * 255 / (height - 1)), 3),
          "the top left output pixel is the first corner");
    const uint8_t *bottom_right = output + (size.height - 1) * size.width * 4 + (size.width - 1) * 4;
    check(near(bottom_right[0], (int)(quad[2].x * 255 / (width - 1)), 4) && near(bottom_right[1], (int)(quad[2].y * 255 / (height - 1)), 4),
          "the bottom right output pixel is the third corner");
    free(source);
    free(output);
}

static void test_rotation(void)
{
    size_t width = 40, height = 20;
    uint8_t *source = make_pattern(width, height, width * 4);
    RevenantDocumentPoint quad[4] = {point((float)width, 0), point((float)width, (float)height), point(0, (float)height), point(0, 0)};
    RevenantDocumentSize size = RevenantDocumentOutputSize(quad, 0);
    check(size.width == 20 && size.height == 40, "a quarter turn swaps the size");
    uint8_t *output = calloc(size.width * size.height * 4, 1);
    check(RevenantDocumentWarp(source, width, height, width * 4, quad, output, size.width, size.height, size.width * 4) == 1,
          "rotated warp succeeds");
    const uint8_t *origin = output;
    const uint8_t *expected = source + (width - 1) * 4;
    check(near(origin[0], expected[0], 3) && near(origin[1], expected[1], 8), "the first output pixel is the top right source pixel");
    free(source);
    free(output);
}

static void test_clamping_and_strides(void)
{
    size_t width = 32, height = 32;
    size_t source_stride = width * 4 + 16;
    uint8_t *source = make_pattern(width, height, source_stride);
    RevenantDocumentPoint quad[4] = {point(-20, -20), point(60, -20), point(60, 60), point(-20, 60)};
    size_t out_width = 16, out_height = 16, out_stride = out_width * 4 + 8;
    uint8_t *output = malloc(out_stride * out_height);
    memset(output, 0xAB, out_stride * out_height);
    check(RevenantDocumentWarp(source, width, height, source_stride, quad, output, out_width, out_height, out_stride) == 1,
          "a quad beyond the image still warps");
    check(output[0] == source[0] && output[1] == source[1], "samples beyond the image take the nearest edge pixel");
    int padding_untouched = 1;
    for (size_t y = 0; y < out_height; ++y)
        for (size_t x = out_width * 4; x < out_stride; ++x)
            if (output[y * out_stride + x] != 0xAB)
                padding_untouched = 0;
    check(padding_untouched, "bytes after each output row are not written");
    free(source);
    free(output);
}

static void test_rejects(void)
{
    uint8_t source[4 * 4 * 4] = {0};
    uint8_t output[4 * 4 * 4] = {0};
    RevenantDocumentPoint line[4] = {point(0, 0), point(1, 1), point(2, 2), point(3, 3)};
    check(RevenantDocumentWarp(source, 4, 4, 16, line, output, 4, 4, 16) == 0, "collinear corners are refused");
    RevenantDocumentPoint bowtie[4] = {point(0, 0), point(4, 4), point(4, 0), point(0, 4)};
    check(RevenantDocumentWarp(source, 4, 4, 16, bowtie, output, 4, 4, 16) == 0, "crossing corners are refused");
    RevenantDocumentPoint good[4] = {point(0, 0), point(4, 0), point(4, 4), point(0, 4)};
    check(RevenantDocumentWarp(source, 0, 4, 16, good, output, 4, 4, 16) == 0, "an empty source is refused");
    check(RevenantDocumentWarp(source, 4, 4, 8, good, output, 4, 4, 16) == 0, "a source row shorter than its pixels is refused");
    check(RevenantDocumentWarp(source, 4, 4, 16, good, output, 4, 4, 8) == 0, "an output row shorter than its pixels is refused");
    check(RevenantDocumentWarp(NULL, 4, 4, 16, good, output, 4, 4, 16) == 0, "a missing source is refused");
}

int main(int argc, char **argv)
{
    negative = argc > 1 && strcmp(argv[1], "--negative") == 0;
    test_identity();
    test_sizes();
    test_perspective();
    test_rotation();
    test_clamping_and_strides();
    test_rejects();
    printf("checks=%d failures=%d\n", checks, failures);
    return failures ? 1 : 0;
}
