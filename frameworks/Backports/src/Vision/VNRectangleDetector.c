#include "VNRectangleDetector.h"
#include <math.h>
#include <stdlib.h>
#include <string.h>
#if defined(__ARM_NEON__)
#include <arm_neon.h>
#endif

typedef struct { int x; int y; } Point;

static int rectangle_compare(const void *left, const void *right)
{
    const RevenantVisionRectangle *a = left, *b = right;
    return a->confidence < b->confidence ? 1 : a->confidence > b->confidence ? -1 : 0;
}

static int point_compare(const void *left, const void *right)
{
    const Point *a = left, *b = right;
    return a->x == b->x ? a->y - b->y : a->x - b->x;
}

static float cross(Point o, Point a, Point b)
{
    return (float)(a.x - o.x) * (b.y - o.y) - (float)(a.y - o.y) * (b.x - o.x);
}

static float distance(Point a, Point b)
{
    float x = (float)(a.x - b.x), y = (float)(a.y - b.y);
    return sqrtf(x * x + y * y);
}

static float dot_angle(Point a, Point b, Point c)
{
    float ax = a.x - b.x, ay = a.y - b.y, cx = c.x - b.x, cy = c.y - b.y;
    float denominator = sqrtf((ax * ax + ay * ay) * (cx * cx + cy * cy));
    if (denominator == 0)
        return 1;
    return fabsf((ax * cx + ay * cy) / denominator);
}

static unsigned char gradient(const uint8_t *image, size_t width, size_t height, size_t stride, size_t x, size_t y)
{
    const uint8_t *p = image + y * stride + x;
    int gx = -p[-(int)stride - 1] + p[-(int)stride + 1] - 2 * p[-1] + 2 * p[1] - p[(int)stride - 1] + p[(int)stride + 1];
    int gy = -p[-(int)stride - 1] - 2 * p[-(int)stride] - p[-(int)stride + 1] + p[(int)stride - 1] + 2 * p[(int)stride] + p[(int)stride + 1];
    (void)width;
    (void)height;
    return (unsigned char)fminf(255, sqrtf((float)(gx * gx + gy * gy)) / 4.0f);
}

static void make_edge_row(const uint8_t *image, uint8_t *edge, size_t width, size_t y, unsigned low_threshold, unsigned high_threshold)
{
    size_t x = 1;
#if defined(__ARM_NEON__)
    for (; x + 8 < width; x += 8) {
        int16x8_t tl = vreinterpretq_s16_u16(vmovl_u8(vld1_u8(image + (y - 1) * width + x - 1)));
        int16x8_t tr = vreinterpretq_s16_u16(vmovl_u8(vld1_u8(image + (y - 1) * width + x + 1)));
        int16x8_t ml = vreinterpretq_s16_u16(vmovl_u8(vld1_u8(image + y * width + x - 1)));
        int16x8_t mr = vreinterpretq_s16_u16(vmovl_u8(vld1_u8(image + y * width + x + 1)));
        int16x8_t bl = vreinterpretq_s16_u16(vmovl_u8(vld1_u8(image + (y + 1) * width + x - 1)));
        int16x8_t br = vreinterpretq_s16_u16(vmovl_u8(vld1_u8(image + (y + 1) * width + x + 1)));
        int16x8_t tc = vreinterpretq_s16_u16(vmovl_u8(vld1_u8(image + (y - 1) * width + x)));
        int16x8_t bc = vreinterpretq_s16_u16(vmovl_u8(vld1_u8(image + (y + 1) * width + x)));
        int16x8_t gx = vaddq_s16(vsubq_s16(tr, tl), vaddq_s16(vshlq_n_s16(vsubq_s16(mr, ml), 1), vsubq_s16(br, bl)));
        int16x8_t gy = vaddq_s16(vsubq_s16(bl, tl), vaddq_s16(vshlq_n_s16(vsubq_s16(bc, tc), 1), vsubq_s16(br, tr)));
        uint16x8_t magnitude = vshrq_n_u16(vaddq_u16(vreinterpretq_u16_s16(vabsq_s16(gx)), vreinterpretq_u16_s16(vabsq_s16(gy))), 2);
        uint8x8_t value = vqmovn_u16(magnitude);
        uint8x8_t low = vand_u8(vcge_u8(value, vdup_n_u8((uint8_t)low_threshold)), vdup_n_u8(1));
        uint8x8_t high = vand_u8(vcge_u8(value, vdup_n_u8((uint8_t)high_threshold)), vdup_n_u8(1));
        vst1_u8(edge + y * width + x, vadd_u8(low, high));
    }
#endif
    for (; x + 1 < width; ++x)
    {
        unsigned value = gradient(image, width, width, width, x, y);
        edge[y * width + x] = value >= high_threshold ? 2 : value >= low_threshold ? 1 : 0;
    }
}

static size_t make_hull(Point *points, size_t count, Point *hull)
{
    if (count < 4)
        return 0;
    qsort(points, count, sizeof(Point), point_compare);
    size_t k = 0;
    for (size_t i = 0; i < count; ++i) {
        while (k >= 2 && cross(hull[k - 2], hull[k - 1], points[i]) <= 0)
            --k;
        hull[k++] = points[i];
    }
    size_t lower = k;
    for (size_t i = count - 1; i > 0; --i) {
        while (k > lower && cross(hull[k - 2], hull[k - 1], points[i - 1]) <= 0)
            --k;
        hull[k++] = points[i - 1];
    }
    return k > 1 ? k - 1 : 0;
}

static void choose_quad(const Point *hull, size_t count, Point quad[4])
{
    float mean_x = 0, mean_y = 0;
    for (size_t i = 0; i < count; ++i) { mean_x += hull[i].x; mean_y += hull[i].y; }
    mean_x /= count; mean_y /= count;
    float xx = 0, yy = 0, xy = 0;
    for (size_t i = 0; i < count; ++i) {
        float x = hull[i].x - mean_x, y = hull[i].y - mean_y;
        xx += x * x; yy += y * y; xy += x * y;
    }
    float angle = 0.5f * atan2f(2 * xy, xx - yy);
    float ux = cosf(angle), uy = sinf(angle), vx = -uy, vy = ux;
    float best[4] = {INFINITY, -INFINITY, -INFINITY, INFINITY};
    for (size_t i = 0; i < count; ++i) {
        float u = hull[i].x * ux + hull[i].y * uy;
        float v = hull[i].x * vx + hull[i].y * vy;
        float sum = u + v;
        float difference = u - v;
        if (sum < best[0]) { best[0] = sum; quad[0] = hull[i]; }
        if (difference > best[1]) { best[1] = difference; quad[1] = hull[i]; }
        if (sum > best[2]) { best[2] = sum; quad[2] = hull[i]; }
        if (difference < best[3]) { best[3] = difference; quad[3] = hull[i]; }
    }
}

static float side_support(const uint8_t *edge, size_t width, size_t height, size_t stride, Point a, Point b)
{
    float length = distance(a, b);
    int samples = (int)ceilf(length);
    if (samples < 1)
        return 0;
    int found = 0;
    for (int i = 0; i <= samples; ++i) {
        float t = (float)i / samples;
        int x = (int)lroundf(a.x + (b.x - a.x) * t);
        int y = (int)lroundf(a.y + (b.y - a.y) * t);
        int hit = 0;
        for (int dy = -2; dy <= 2 && !hit; ++dy)
            for (int dx = -2; dx <= 2; ++dx) {
                int px = x + dx, py = y + dy;
                if (px >= 0 && py >= 0 && (size_t)px < width && (size_t)py < height && edge[(size_t)py * stride + (size_t)px]) {
                    hit = 1;
                    break;
                }
            }
        found += hit;
    }
    return (float)found / (samples + 1);
}

static float area_quad(Point q[4])
{
    float area = 0;
    for (int i = 0; i < 4; ++i)
        area += (float)q[i].x * q[(i + 1) & 3].y - (float)q[(i + 1) & 3].x * q[i].y;
    return fabsf(area) * 0.5f;
}

static void order_corners(Point q[4])
{
    int start = 0;
    float best = q[0].x + q[0].y;
    for (int i = 1; i < 4; ++i) {
        float score = q[i].x + q[i].y;
        if (score < best) { best = score; start = i; }
    }
    Point ordered[4] = {q[0], q[1], q[2], q[3]};
    for (int i = 0; i < 4; ++i)
        q[i] = ordered[(start + i) & 3];
}

size_t RevenantVisionDetectRectangles(const uint8_t *source, size_t source_width, size_t source_height, size_t row_bytes,
                                      RevenantVisionRectangleOptions options,
                                      RevenantVisionRectangle *output, size_t capacity)
{
    if (!source || !output || source_width < 16 || source_height < 16 || row_bytes < source_width || capacity == 0)
        return 0;
    size_t scale = (source_width > 320 || source_height > 320) ? (size_t)ceil(fmax((double)source_width / 320.0, (double)source_height / 320.0)) : 1;
    size_t width = (source_width + scale - 1) / scale, height = (source_height + scale - 1) / scale;
    if (width < 16 || height < 16 || width > SIZE_MAX / height)
        return 0;
    uint8_t *gray = malloc(width * height), *edge = calloc(width * height, 1), *seen = calloc(width * height, 1);
    size_t *queue = malloc(width * height * sizeof(size_t));
    Point *points = malloc(width * height * sizeof(Point)), *hull = malloc(width * height * sizeof(Point));
    if (!gray || !edge || !seen || !queue || !points || !hull) {
        free(gray); free(edge); free(seen); free(queue); free(points); free(hull);
        return SIZE_MAX;
    }
    for (size_t y = 0; y < height; ++y)
        for (size_t x = 0; x < width; ++x)
            gray[y * width + x] = source[(y * scale) * row_bytes + x * scale];
    unsigned low_threshold = 18, high_threshold = 48;
    for (size_t y = 1; y + 1 < height; ++y)
        make_edge_row(gray, edge, width, y, low_threshold, high_threshold);
    size_t edge_tail = 0;
    for (size_t i = 0; i < width * height; ++i)
        if (edge[i] == 2) queue[edge_tail++] = i;
    for (size_t head = 0; head < edge_tail; ++head) {
        size_t index = queue[head], x = index % width, y = index / width;
        size_t y0 = y ? y - 1 : y, y1 = y + 1 < height ? y + 1 : y;
        size_t x0 = x ? x - 1 : x, x1 = x + 1 < width ? x + 1 : x;
        for (size_t py = y0; py <= y1; ++py)
            for (size_t px = x0; px <= x1; ++px) {
                size_t next = py * width + px;
                if (edge[next] == 1) { edge[next] = 2; queue[edge_tail++] = next; }
            }
    }
    for (size_t i = 0; i < width * height; ++i)
        edge[i] = edge[i] == 2;
    size_t found = 0;
    float min_dimension = (float)(width < height ? width : height);
    float min_area = options.minimum_size * min_dimension;
    min_area *= min_area;
    size_t pixel_count = width * height;
    for (size_t start = 0; start < pixel_count && found < capacity; ++start) {
        if (!edge[start] || seen[start])
            continue;
        size_t head = 0, tail = 0, count = 0;
        queue[tail++] = start; seen[start] = 1;
        while (head < tail) {
            size_t index = queue[head++], x = index % width, y = index / width;
            points[count++] = (Point){(int)x, (int)y};
            size_t y0 = y ? y - 1 : y, y1 = y + 1 < height ? y + 1 : y;
            size_t x0 = x ? x - 1 : x, x1 = x + 1 < width ? x + 1 : x;
            for (size_t py = y0; py <= y1; ++py)
                for (size_t px = x0; px <= x1; ++px) {
                    size_t next = py * width + px;
                    if (edge[next] && !seen[next]) { seen[next] = 1; queue[tail++] = next; }
                }
        }
        if (count < min_dimension * 1.5f)
            continue;
        size_t hull_count = make_hull(points, count, hull);
        if (hull_count < 4)
            continue;
        Point q[4]; choose_quad(hull, hull_count, q);
        int unique = 1;
        for (int i = 0; i < 4; ++i)
            for (int j = i + 1; j < 4; ++j)
                if (q[i].x == q[j].x && q[i].y == q[j].y) unique = 0;
        float area = area_quad(q);
        if (!unique || area < min_area)
            continue;
        float sides[4], min_side = INFINITY, max_side = 0;
        for (int i = 0; i < 4; ++i) { sides[i] = distance(q[i], q[(i + 1) & 3]); if (sides[i] < min_side) min_side = sides[i]; if (sides[i] > max_side) max_side = sides[i]; }
        float aspect = min_side / max_side;
        if (aspect < options.minimum_aspect_ratio || aspect > options.maximum_aspect_ratio)
            continue;
        float angle_limit = sinf(options.quadrature_tolerance * 0.01745329252f);
        int angles = 1;
        for (int i = 0; i < 4; ++i)
            if (dot_angle(q[(i + 3) & 3], q[i], q[(i + 1) & 3]) > angle_limit) angles = 0;
        if (!angles)
            continue;
        float confidence = 0;
        for (int i = 0; i < 4; ++i)
            confidence += side_support(edge, width, height, width, q[i], q[(i + 1) & 3]) * 0.25f;
        if (confidence < options.minimum_confidence)
            continue;
        order_corners(q);
        RevenantVisionRectangle candidate;
        for (int i = 0; i < 4; ++i) {
            candidate.corners[i].x = (float)q[i].x * scale / source_width;
            candidate.corners[i].y = 1.0f - (float)q[i].y * scale / source_height;
        }
        candidate.confidence = confidence;
        candidate.aspect_ratio = aspect;
        candidate.size = sqrtf(area) / min_dimension;
        float left = candidate.corners[0].x, right = left, bottom = candidate.corners[0].y, top = bottom;
        for (int i = 1; i < 4; ++i) { if (candidate.corners[i].x < left) left = candidate.corners[i].x; if (candidate.corners[i].x > right) right = candidate.corners[i].x; if (candidate.corners[i].y < bottom) bottom = candidate.corners[i].y; if (candidate.corners[i].y > top) top = candidate.corners[i].y; }
        int duplicate = 0;
        for (size_t i = 0; i < found; ++i) {
            float oldLeft = output[i].corners[0].x, oldRight = oldLeft, oldBottom = output[i].corners[0].y, oldTop = oldBottom;
            for (int j = 1; j < 4; ++j) { if (output[i].corners[j].x < oldLeft) oldLeft = output[i].corners[j].x; if (output[i].corners[j].x > oldRight) oldRight = output[i].corners[j].x; if (output[i].corners[j].y < oldBottom) oldBottom = output[i].corners[j].y; if (output[i].corners[j].y > oldTop) oldTop = output[i].corners[j].y; }
            float intersection = fmaxf(0, fminf(right, oldRight) - fmaxf(left, oldLeft)) * fmaxf(0, fminf(top, oldTop) - fmaxf(bottom, oldBottom));
            float union_area = (right - left) * (top - bottom) + (oldRight - oldLeft) * (oldTop - oldBottom) - intersection;
            if (union_area > 0 && intersection / union_area >= 0.65f) {
                if (candidate.confidence > output[i].confidence) output[i] = candidate;
                duplicate = 1;
                break;
            }
        }
        if (!duplicate)
            output[found++] = candidate;
    }
    qsort(output, found, sizeof(RevenantVisionRectangle), rectangle_compare);
    if (options.maximum_observations && found > options.maximum_observations)
        found = options.maximum_observations;
    free(gray); free(edge); free(seen); free(queue); free(points); free(hull);
    return found;
}
