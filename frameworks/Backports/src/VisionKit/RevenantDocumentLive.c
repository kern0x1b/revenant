#include "RevenantDocumentLive.h"

#include <math.h>
#include <stdlib.h>

#include "../Vision/VNRectangleDetector.h"

#define CANDIDATES 8
#define NEAR_LIMIT 0.15
#define LOSS_GRACE 0.6
#define STILL_LIMIT 0.03
#define MOVE_LIMIT 0.15

int RevenantDocumentLuminance(const uint8_t *plane, size_t width, size_t height, size_t row_bytes, unsigned quarter_turns,
                              size_t maximum_side, uint8_t *output, size_t *output_width, size_t *output_height)
{
    if (plane == NULL || output == NULL || output_width == NULL || output_height == NULL || width == 0 || height == 0 ||
        row_bytes < width || maximum_side == 0)
        return 0;
    size_t longest = width > height ? width : height;
    size_t factor = (longest + maximum_side - 1) / maximum_side;
    size_t blocks_x = width / factor;
    size_t blocks_y = height / factor;
    if (blocks_x == 0 || blocks_y == 0)
        return 0;
    unsigned turns = quarter_turns & 3;
    size_t out_width = (turns & 1) ? blocks_y : blocks_x;
    size_t out_height = (turns & 1) ? blocks_x : blocks_y;
    size_t area = factor * factor;
    for (size_t by = 0; by < blocks_y; ++by) {
        for (size_t bx = 0; bx < blocks_x; ++bx) {
            unsigned sum = 0;
            for (size_t y = 0; y < factor; ++y) {
                const uint8_t *row = plane + (by * factor + y) * row_bytes + bx * factor;
                for (size_t x = 0; x < factor; ++x)
                    sum += row[x];
            }
            size_t target_x = bx;
            size_t target_y = by;
            if (turns == 1) {
                target_x = blocks_y - 1 - by;
                target_y = bx;
            } else if (turns == 2) {
                target_x = blocks_x - 1 - bx;
                target_y = blocks_y - 1 - by;
            } else if (turns == 3) {
                target_x = by;
                target_y = blocks_x - 1 - bx;
            }
            output[target_y * out_width + target_x] = (uint8_t)((sum + area / 2) / area);
        }
    }
    *output_width = out_width;
    *output_height = out_height;
    return 1;
}

int RevenantDocumentLuminanceRGBA(const uint8_t *pixels, size_t width, size_t height, size_t row_bytes, size_t maximum_side,
                                  uint8_t *output, size_t *output_width, size_t *output_height)
{
    if (pixels == NULL || output == NULL || output_width == NULL || output_height == NULL || width == 0 || height == 0 ||
        row_bytes < width * 4 || maximum_side == 0)
        return 0;
    size_t longest = width > height ? width : height;
    size_t factor = (longest + maximum_side - 1) / maximum_side;
    size_t blocks_x = width / factor;
    size_t blocks_y = height / factor;
    if (blocks_x == 0 || blocks_y == 0)
        return 0;
    size_t step = factor >= 4 ? 2 : 1;
    for (size_t by = 0; by < blocks_y; ++by) {
        for (size_t bx = 0; bx < blocks_x; ++bx) {
            unsigned sum = 0;
            unsigned samples = 0;
            for (size_t y = 0; y < factor; y += step) {
                const uint8_t *row = pixels + (by * factor + y) * row_bytes + bx * factor * 4;
                for (size_t x = 0; x < factor; x += step) {
                    const uint8_t *pixel = row + x * 4;
                    sum += (77u * pixel[0] + 150u * pixel[1] + 29u * pixel[2]) >> 8;
                    samples++;
                }
            }
            output[by * blocks_x + bx] = (uint8_t)((sum + samples / 2) / samples);
        }
    }
    *output_width = blocks_x;
    *output_height = blocks_y;
    return 1;
}

static double corner_distance(RevenantDocumentPoint a, RevenantDocumentPoint b)
{
    double x = (double)a.x - (double)b.x;
    double y = (double)a.y - (double)b.y;
    return sqrt(x * x + y * y);
}

double RevenantDocumentQuadDistance(const RevenantDocumentQuad *a, const RevenantDocumentQuad *b)
{
    double largest = 0;
    for (int i = 0; i < 4; ++i) {
        double d = corner_distance(a->corners[i], b->corners[i]);
        if (d > largest)
            largest = d;
    }
    return largest;
}

double RevenantDocumentQuadArea(const RevenantDocumentQuad *quad)
{
    double twice = 0;
    for (int i = 0; i < 4; ++i) {
        RevenantDocumentPoint from = quad->corners[i];
        RevenantDocumentPoint to = quad->corners[(i + 1) & 3];
        twice += (double)from.x * (double)to.y - (double)to.x * (double)from.y;
    }
    return fabs(twice) * 0.5;
}

int RevenantDocumentFindQuad(const uint8_t *luminance, size_t width, size_t height, size_t row_bytes,
                             const RevenantDocumentQuad *near, RevenantDocumentQuad *quad)
{
    RevenantVisionRectangle found[CANDIDATES];
    RevenantVisionRectangleOptions options = {0.2f, 1.0f, 30.0f, 0.2f, 0.4f, CANDIDATES};
    size_t count = RevenantVisionDetectRectangles(luminance, width, height, row_bytes, options, found, CANDIDATES);
    if (count == 0 || count == SIZE_MAX)
        return 0;
    size_t chosen = 0;
    int have_near = 0;
    double best_distance = NEAR_LIMIT;
    for (size_t i = 0; i < count && near != NULL; ++i) {
        RevenantDocumentQuad candidate;
        for (int j = 0; j < 4; ++j) {
            candidate.corners[j].x = found[i].corners[j].x;
            candidate.corners[j].y = found[i].corners[j].y;
        }
        double distance = RevenantDocumentQuadDistance(&candidate, near);
        if (distance < best_distance) {
            best_distance = distance;
            chosen = i;
            have_near = 1;
        }
    }
    if (!have_near) {
        for (size_t i = 1; i < count; ++i)
            if (found[i].size > found[chosen].size)
                chosen = i;
    }
    for (int j = 0; j < 4; ++j) {
        quad->corners[j].x = found[chosen].corners[j].x;
        quad->corners[j].y = found[chosen].corners[j].y;
    }
    return 1;
}

void RevenantDocumentTrackerReset(RevenantDocumentTracker *tracker)
{
    tracker->since = 0;
    tracker->lost_since = -1;
    tracker->has_anchor = 0;
    tracker->armed = 1;
}

int RevenantDocumentTrackerUpdate(RevenantDocumentTracker *tracker, const RevenantDocumentQuad *quad, double now, double hold)
{
    if (quad == NULL) {
        if (tracker->lost_since < 0)
            tracker->lost_since = now;
        else if (now - tracker->lost_since >= LOSS_GRACE) {
            tracker->has_anchor = 0;
            tracker->armed = 1;
        }
        return 0;
    }
    tracker->lost_since = -1;
    if (!tracker->has_anchor) {
        tracker->anchor = *quad;
        tracker->since = now;
        tracker->has_anchor = 1;
        return 0;
    }
    double moved = RevenantDocumentQuadDistance(quad, &tracker->anchor);
    if (moved > STILL_LIMIT) {
        tracker->anchor = *quad;
        tracker->since = now;
        if (moved > MOVE_LIMIT)
            tracker->armed = 1;
        return 0;
    }
    return tracker->armed && now - tracker->since >= hold;
}

void RevenantDocumentTrackerCaptured(RevenantDocumentTracker *tracker)
{
    tracker->armed = 0;
    tracker->since = 0;
    tracker->has_anchor = 0;
}
