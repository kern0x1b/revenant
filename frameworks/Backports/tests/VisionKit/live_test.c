#include "RevenantDocumentLive.h"
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

static int inside(const RevenantDocumentPoint q[4], double x, double y)
{
    int positive = 0;
    int negative_turn = 0;
    for (int i = 0; i < 4; ++i) {
        double ax = q[i].x, ay = q[i].y, bx = q[(i + 1) & 3].x, by = q[(i + 1) & 3].y;
        double turn = (bx - ax) * (y - ay) - (by - ay) * (x - ax);
        if (turn > 0)
            positive = 1;
        else if (turn < 0)
            negative_turn = 1;
    }
    return !(positive && negative_turn);
}

static uint8_t *scene(size_t width, size_t height, const RevenantDocumentPoint *first, const RevenantDocumentPoint *second)
{
    uint8_t *pixels = malloc(width * height);
    for (size_t y = 0; y < height; ++y) {
        for (size_t x = 0; x < width; ++x) {
            double px = (double)x + 0.5, py = (double)y + 0.5;
            uint8_t value = (uint8_t)(24 + (x * 12) / width);
            if (first != NULL && inside(first, px, py))
                value = 235;
            if (second != NULL && inside(second, px, py))
                value = 225;
            pixels[y * width + x] = value;
        }
    }
    return pixels;
}

static void test_luminance_turns(void)
{
    size_t width = 6, height = 4;
    uint8_t plane[6 * 4];
    for (size_t i = 0; i < sizeof plane; ++i)
        plane[i] = (uint8_t)(i * 10);
    uint8_t output[64];
    size_t out_width = 0, out_height = 0;
    int whole = 1;
    for (unsigned turns = 0; turns < 4; ++turns) {
        memset(output, 0, sizeof output);
        int ok = RevenantDocumentLuminance(plane, width, height, width, turns, 16, output, &out_width, &out_height);
        check(ok == 1, "a plane is converted");
        size_t expect_width = (turns & 1) ? height : width;
        size_t expect_height = (turns & 1) ? width : height;
        check(out_width == expect_width && out_height == expect_height, "the quarter turns swap or keep the size");
        for (size_t by = 0; by < height; ++by) {
            for (size_t bx = 0; bx < width; ++bx) {
                size_t tx = bx, ty = by;
                if (turns == 1) {
                    tx = height - 1 - by;
                    ty = bx;
                } else if (turns == 2) {
                    tx = width - 1 - bx;
                    ty = height - 1 - by;
                } else if (turns == 3) {
                    tx = by;
                    ty = width - 1 - bx;
                }
                if (output[ty * out_width + tx] != plane[by * width + bx])
                    whole = 0;
            }
        }
    }
    check(whole, "every pixel lands where a clockwise turn puts it");
    int ok = RevenantDocumentLuminance(plane, width, height, width, 5, 16, output, &out_width, &out_height);
    check(ok == 1 && out_width == height && out_height == width, "five quarter turns are one");
}

static void test_luminance_average(void)
{
    uint8_t plane[8 * 8];
    for (size_t y = 0; y < 8; ++y)
        for (size_t x = 0; x < 8; ++x)
            plane[y * 8 + x] = (uint8_t)((x / 2 + y / 2) % 2 ? 200 : 100);
    uint8_t output[16];
    size_t out_width = 0, out_height = 0;
    check(RevenantDocumentLuminance(plane, 8, 8, 8, 0, 4, output, &out_width, &out_height) == 1, "a plane larger than the side is reduced");
    check(out_width == 4 && out_height == 4, "the reduced plane is four by four");
    check(output[0] == 100 && output[1] == 200 && output[4] == 200 && output[5] == 100, "each block holds its own mean");
    uint8_t mixed[4] = {10, 20, 30, 41};
    uint8_t one[1];
    check(RevenantDocumentLuminance(mixed, 2, 2, 2, 0, 1, one, &out_width, &out_height) == 1 && one[0] == 25, "a block mean rounds to the nearest");
    uint8_t padded[3 * 2] = {50, 50, 99, 70, 70, 99};
    check(RevenantDocumentLuminance(padded, 2, 2, 3, 0, 1, one, &out_width, &out_height) == 1 && one[0] == 60, "a row stride beyond the width is skipped");
}

static void test_luminance_rejects(void)
{
    uint8_t plane[16] = {0};
    uint8_t output[16];
    size_t w, h;
    check(RevenantDocumentLuminance(NULL, 4, 4, 4, 0, 4, output, &w, &h) == 0, "a missing plane is refused");
    check(RevenantDocumentLuminance(plane, 0, 4, 4, 0, 4, output, &w, &h) == 0, "an empty plane is refused");
    check(RevenantDocumentLuminance(plane, 4, 4, 3, 0, 4, output, &w, &h) == 0, "a row shorter than the width is refused");
    check(RevenantDocumentLuminance(plane, 4, 4, 4, 0, 0, output, &w, &h) == 0, "a side of zero is refused");
}

static void test_luminance_rgba(void)
{
    uint8_t pixels[4 * 4 * 4];
    size_t out_width = 0, out_height = 0;
    uint8_t output[16];
    for (size_t i = 0; i < 16; ++i) {
        pixels[i * 4] = 255;
        pixels[i * 4 + 1] = 255;
        pixels[i * 4 + 2] = 255;
        pixels[i * 4 + 3] = 0;
    }
    check(RevenantDocumentLuminanceRGBA(pixels, 4, 4, 16, 4, output, &out_width, &out_height) == 1 && out_width == 4 && out_height == 4, "a small image keeps its size");
    check(output[0] == 255 && output[15] == 255, "white is full luminance whatever the fourth byte holds");
    uint8_t primaries[3 * 4] = {255, 0, 0, 0, 0, 255, 0, 0, 0, 0, 255, 0};
    uint8_t three[3];
    check(RevenantDocumentLuminanceRGBA(primaries, 3, 1, 12, 3, three, &out_width, &out_height) == 1 && three[0] == 76 && three[1] == 149 && three[2] == 28,
          "red, green and blue weigh as 76, 149 and 28");
    uint8_t wide[8 * 8 * 4];
    for (size_t y = 0; y < 8; ++y) {
        for (size_t x = 0; x < 8; ++x) {
            uint8_t value = (x % 2 == 0 && y % 2 == 0) ? 255 : 0;
            uint8_t *pixel = wide + (y * 8 + x) * 4;
            pixel[0] = value;
            pixel[1] = value;
            pixel[2] = value;
            pixel[3] = 0;
        }
    }
    uint8_t four[4];
    check(RevenantDocumentLuminanceRGBA(wide, 8, 8, 32, 2, four, &out_width, &out_height) == 1 && out_width == 2 && out_height == 2, "an image four times the side is reduced to it");
    check(four[0] == 255 && four[3] == 255, "blocks of four or more are sampled every second pixel");
    uint8_t halves[8 * 2 * 4 + 8];
    for (size_t y = 0; y < 2; ++y) {
        for (size_t x = 0; x < 8; ++x) {
            uint8_t value = y == 0 ? 100 : 200;
            uint8_t *pixel = halves + y * 40 + x * 4;
            pixel[0] = value;
            pixel[1] = value;
            pixel[2] = value;
            pixel[3] = 0;
        }
    }
    uint8_t row[4];
    check(RevenantDocumentLuminanceRGBA(halves, 8, 2, 40, 4, row, &out_width, &out_height) == 1 && out_width == 4 && out_height == 1 && row[0] == 150 && row[3] == 150,
          "a block takes the mean of its rows and skips the row padding");
    check(RevenantDocumentLuminanceRGBA(NULL, 4, 4, 16, 4, output, &out_width, &out_height) == 0, "a missing image is refused");
    check(RevenantDocumentLuminanceRGBA(pixels, 4, 4, 15, 4, output, &out_width, &out_height) == 0, "a row shorter than its pixels is refused");
    check(RevenantDocumentLuminanceRGBA(pixels, 4, 4, 16, 0, output, &out_width, &out_height) == 0, "a side of zero is refused");
}

static void test_quad_measures(void)
{
    RevenantDocumentQuad unit = {{point(0, 1), point(1, 1), point(1, 0), point(0, 0)}};
    RevenantDocumentQuad shifted = unit;
    shifted.corners[2].x = 1.0f + 0.03f;
    shifted.corners[2].y = 0.04f;
    check(fabs(RevenantDocumentQuadArea(&unit) - 1.0) < 1e-9, "the unit square has area one");
    check(RevenantDocumentQuadDistance(&unit, &unit) == 0, "a quad is at distance zero from itself");
    check(fabs(RevenantDocumentQuadDistance(&unit, &shifted) - 0.05) < 1e-6, "the distance is the largest corner move");
}

static void test_find(void)
{
    size_t width = 320, height = 240;
    RevenantDocumentPoint page[4] = {point(58, 30), point(268, 44), point(252, 208), point(44, 196)};
    uint8_t *pixels = scene(width, height, page, NULL);
    RevenantDocumentQuad found;
    check(RevenantDocumentFindQuad(pixels, width, height, width, NULL, &found) == 1, "a light page on a dark table is found");
    double worst = 0;
    for (int i = 0; i < 4; ++i) {
        double dx = found.corners[i].x - page[i].x / (double)width;
        double dy = found.corners[i].y - (1.0 - page[i].y / (double)height);
        double d = sqrt(dx * dx + dy * dy);
        if (d > worst)
            worst = d;
    }
    printf("measured: the worst corner is %.4f of the frame from the page\n", worst);
    check(worst < 0.02, "the corners come back top left, top right, bottom right, bottom left within two percent");
    free(pixels);

    uint8_t *empty = scene(width, height, NULL, NULL);
    check(RevenantDocumentFindQuad(empty, width, height, width, NULL, &found) == 0, "a plain table has no page");
    free(empty);

    RevenantDocumentPoint big[4] = {point(20, 20), point(190, 20), point(190, 215), point(20, 215)};
    RevenantDocumentPoint small[4] = {point(215, 60), point(305, 60), point(305, 150), point(215, 150)};
    uint8_t *two = scene(width, height, big, small);
    RevenantDocumentQuad largest, nearest, hint;
    check(RevenantDocumentFindQuad(two, width, height, width, NULL, &largest) == 1, "two pages are found");
    check(largest.corners[1].x < 0.7f, "without a hint the larger page wins");
    for (int i = 0; i < 4; ++i) {
        hint.corners[i].x = small[i].x / (float)width;
        hint.corners[i].y = 1.0f - small[i].y / (float)height;
    }
    check(RevenantDocumentFindQuad(two, width, height, width, &hint, &nearest) == 1, "a hint is found");
    check(nearest.corners[0].x > 0.6f, "the page nearest the hint wins");
    RevenantDocumentQuad far = {{point(0.4f, 0.95f), point(0.45f, 0.95f), point(0.45f, 0.9f), point(0.4f, 0.9f)}};
    RevenantDocumentQuad fallback;
    check(RevenantDocumentFindQuad(two, width, height, width, &far, &fallback) == 1 && fallback.corners[1].x < 0.7f, "a hint that matches nothing falls back to the larger page");
    free(two);
}

static void test_tracker(void)
{
    RevenantDocumentTracker tracker;
    RevenantDocumentTrackerReset(&tracker);
    RevenantDocumentQuad page = {{point(0.1f, 0.9f), point(0.9f, 0.9f), point(0.9f, 0.1f), point(0.1f, 0.1f)}};
    RevenantDocumentQuad jitter = page;
    jitter.corners[0].x += 0.01f;
    RevenantDocumentQuad moved = page;
    moved.corners[0].x += 0.1f;
    RevenantDocumentQuad elsewhere = page;
    for (int i = 0; i < 4; ++i)
        elsewhere.corners[i].x -= 0.2f;

    check(RevenantDocumentTrackerUpdate(&tracker, NULL, 0.0, 1.0) == 0, "nothing in view is never ready");
    check(RevenantDocumentTrackerUpdate(&tracker, &page, 1.0, 1.0) == 0, "the first sight is not ready");
    check(RevenantDocumentTrackerUpdate(&tracker, &jitter, 1.5, 1.0) == 0, "half the hold is not ready");
    check(RevenantDocumentTrackerUpdate(&tracker, &page, 2.0, 1.0) == 1, "a page held still for the hold is ready");
    RevenantDocumentTrackerCaptured(&tracker);
    check(RevenantDocumentTrackerUpdate(&tracker, &page, 3.0, 1.0) == 0, "after a capture the same page is not ready");
    check(RevenantDocumentTrackerUpdate(&tracker, &page, 9.0, 1.0) == 0, "after a capture the same page is never ready");
    check(RevenantDocumentTrackerUpdate(&tracker, NULL, 10.0, 1.0) == 0, "a short loss is not ready");
    check(RevenantDocumentTrackerUpdate(&tracker, NULL, 10.8, 1.0) == 0, "a long loss is not ready but arms the tracker");
    check(RevenantDocumentTrackerUpdate(&tracker, &page, 11.0, 1.0) == 0, "the page seen again starts the hold");
    check(RevenantDocumentTrackerUpdate(&tracker, &page, 12.1, 1.0) == 1, "the page seen again is ready after the hold");
    RevenantDocumentTrackerCaptured(&tracker);
    check(RevenantDocumentTrackerUpdate(&tracker, &page, 13.0, 1.0) == 0, "a captured page starts again");
    check(RevenantDocumentTrackerUpdate(&tracker, &elsewhere, 14.0, 1.0) == 0, "a page moved far away restarts the hold");
    check(RevenantDocumentTrackerUpdate(&tracker, &elsewhere, 15.1, 1.0) == 1, "a page moved far away arms the tracker again");
    RevenantDocumentTrackerReset(&tracker);
    check(RevenantDocumentTrackerUpdate(&tracker, &page, 20.0, 1.0) == 0, "a reset starts at the first sight");
    check(RevenantDocumentTrackerUpdate(&tracker, &moved, 20.9, 1.0) == 0, "a page that moves restarts the hold");
    check(RevenantDocumentTrackerUpdate(&tracker, &moved, 21.8, 1.0) == 0, "the hold counts from the move");
    check(RevenantDocumentTrackerUpdate(&tracker, &moved, 21.95, 1.0) == 1, "the hold ends one second after the move");
}

int main(int argc, char **argv)
{
    negative = argc > 1 && strcmp(argv[1], "--negative") == 0;
    test_luminance_turns();
    test_luminance_average();
    test_luminance_rejects();
    test_luminance_rgba();
    test_quad_measures();
    test_find();
    test_tracker();
    printf("checks=%d failures=%d\n", checks, failures);
    return failures ? 1 : 0;
}
