#include "VNRectangleDetector.h"
#include "VNRectangleDetectorInternal.h"
#include <math.h>
#include <stdlib.h>
#include <string.h>
#if defined(__ARM_NEON__)
#include <arm_neon.h>
#endif

typedef struct { int x; int y; } Point;
typedef struct { float x; float y; } FloatPoint;
typedef struct { float nx; float ny; float offset; } FittedLine;

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

static void sobel(const uint8_t *image, size_t width, size_t height, size_t x, size_t y, int *gx, int *gy)
{
    size_t left = x ? x - 1 : x, right = x + 1 < width ? x + 1 : x;
    size_t up = y ? y - 1 : y, down = y + 1 < height ? y + 1 : y;
    const uint8_t *top = image + up * width, *middle = image + y * width, *bottom = image + down * width;
    *gx = -top[left] + top[right] - 2 * middle[left] + 2 * middle[right] - bottom[left] + bottom[right];
    *gy = -top[left] - 2 * top[x] - top[right] + bottom[left] + 2 * bottom[x] + bottom[right];
}

static unsigned gradient(const uint8_t *image, size_t width, size_t height, size_t x, size_t y)
{
    int gx, gy;
    sobel(image, width, height, x, y, &gx, &gy);
    int magnitude = (abs(gx) + abs(gy)) >> 2;
    return magnitude < 255 ? (unsigned)magnitude : 255;
}

static void make_edge_pixel(const uint8_t *image, uint8_t *magnitude_map, uint8_t *edge, size_t width, size_t height, size_t x, size_t y, unsigned low_threshold, unsigned high_threshold)
{
    unsigned value = gradient(image, width, height, x, y);
    magnitude_map[y * width + x] = (uint8_t)value;
    edge[y * width + x] = value >= high_threshold ? 2 : value >= low_threshold ? 1 : 0;
}

static void make_edge_row(const uint8_t *image, uint8_t *magnitude_map, uint8_t *edge, size_t width, size_t height, size_t y, unsigned low_threshold, unsigned high_threshold, int scalar_only)
{
    size_t x = 1;
#if defined(__ARM_NEON__)
    for (; !scalar_only && x + 8 < width; x += 8) {
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
        vst1_u8(magnitude_map + y * width + x, value);
        uint8x8_t low = vand_u8(vcge_u8(value, vdup_n_u8((uint8_t)low_threshold)), vdup_n_u8(1));
        uint8x8_t high = vand_u8(vcge_u8(value, vdup_n_u8((uint8_t)high_threshold)), vdup_n_u8(1));
        vst1_u8(edge + y * width + x, vadd_u8(low, high));
    }
#else
    (void)scalar_only;
#endif
    for (; x + 1 < width; ++x)
        make_edge_pixel(image, magnitude_map, edge, width, height, x, y, low_threshold, high_threshold);
}

static void make_edge_map(const uint8_t *gray, size_t width, size_t height, unsigned low_threshold, unsigned high_threshold, uint8_t *magnitude, uint8_t *edge, int scalar_only)
{
    for (size_t y = 0; y < height; ++y) {
        if (y == 0 || y + 1 == height) {
            for (size_t x = 0; x < width; ++x)
                make_edge_pixel(gray, magnitude, edge, width, height, x, y, low_threshold, high_threshold);
            continue;
        }
        make_edge_pixel(gray, magnitude, edge, width, height, 0, y, low_threshold, high_threshold);
        make_edge_row(gray, magnitude, edge, width, height, y, low_threshold, high_threshold, scalar_only);
        make_edge_pixel(gray, magnitude, edge, width, height, width - 1, y, low_threshold, high_threshold);
    }
}

void RevenantVisionEdgeMap(const uint8_t *gray, size_t width, size_t height, unsigned low_threshold, unsigned high_threshold, uint8_t *magnitude, uint8_t *edge)
{
    make_edge_map(gray, width, height, low_threshold, high_threshold, magnitude, edge, 0);
}

void RevenantVisionEdgeMapScalar(const uint8_t *gray, size_t width, size_t height, unsigned low_threshold, unsigned high_threshold, uint8_t *magnitude, uint8_t *edge)
{
    make_edge_map(gray, width, height, low_threshold, high_threshold, magnitude, edge, 1);
}

static float bilinear(const uint8_t *image, size_t width, size_t height, float x, float y)
{
    x = fminf(fmaxf(x, 0), (float)(width - 1));
    y = fminf(fmaxf(y, 0), (float)(height - 1));
    size_t left = (size_t)x, top = (size_t)y;
    size_t right = left + 1 < width ? left + 1 : left, bottom = top + 1 < height ? top + 1 : top;
    float fx = x - left, fy = y - top;
    float a = image[top * width + left], b = image[top * width + right];
    float c = image[bottom * width + left], d = image[bottom * width + right];
    return (a + (b - a) * fx) + ((c + (d - c) * fx) - (a + (b - a) * fx)) * fy;
}

static FloatPoint subpixel_edge(const uint8_t *gray, const uint8_t *magnitude, size_t width, size_t height, Point point)
{
    int gx, gy;
    sobel(gray, width, height, (size_t)point.x, (size_t)point.y, &gx, &gy);
    float norm = sqrtf((float)gx * gx + (float)gy * gy);
    FloatPoint result = {(float)point.x, (float)point.y};
    if (norm < 1)
        return result;
    float nx = gx / norm, ny = gy / norm;
    float center = magnitude[(size_t)point.y * width + (size_t)point.x];
    float before = bilinear(magnitude, width, height, point.x - nx, point.y - ny);
    float after = bilinear(magnitude, width, height, point.x + nx, point.y + ny);
    float denominator = before - 2 * center + after;
    if (fabsf(denominator) < 0.001f)
        return result;
    float offset = 0.5f * (before - after) / denominator;
    if (offset < -0.5f) offset = -0.5f;
    if (offset > 0.5f) offset = 0.5f;
    result.x += offset * nx;
    result.y += offset * ny;
    return result;
}

static int on_side(Point point, FloatPoint start, float dx, float dy, float length)
{
    float px = point.x - start.x, py = point.y - start.y;
    float along = px * dx + py * dy, across = fabsf(px * dy - py * dx);
    return along >= -4 * length && along <= length * (length + 4) && across <= 6 * length;
}

static int fit_side(const Point *points, const FloatPoint *edge, size_t count, FloatPoint start, FloatPoint end, FittedLine *line)
{
    float dx = end.x - start.x, dy = end.y - start.y;
    float length = sqrtf(dx * dx + dy * dy);
    if (length < 8)
        return 0;
    float mean_x = 0, mean_y = 0;
    size_t used = 0;
    for (size_t i = 0; i < count; ++i) {
        if (!on_side(points[i], start, dx, dy, length))
            continue;
        mean_x += edge[i].x;
        mean_y += edge[i].y;
        ++used;
    }
    if (used < 8)
        return 0;
    mean_x /= used;
    mean_y /= used;
    float xx = 0, yy = 0, xy = 0;
    for (size_t i = 0; i < count; ++i) {
        if (!on_side(points[i], start, dx, dy, length))
            continue;
        float x = edge[i].x - mean_x, y = edge[i].y - mean_y;
        xx += x * x;
        yy += y * y;
        xy += x * y;
    }
    float angle = 0.5f * atan2f(2 * xy, xx - yy);
    line->nx = -sinf(angle);
    line->ny = cosf(angle);
    line->offset = line->nx * mean_x + line->ny * mean_y;
    return 1;
}

static int intersect_lines(FittedLine a, FittedLine b, FloatPoint *point)
{
    float determinant = a.nx * b.ny - a.ny * b.nx;
    if (fabsf(determinant) < 0.05f)
        return 0;
    point->x = (a.offset * b.ny - a.ny * b.offset) / determinant;
    point->y = (a.nx * b.offset - a.offset * b.nx) / determinant;
    return isfinite(point->x) && isfinite(point->y);
}

static int refine_quad(const Point *points, const FloatPoint *edge, size_t count, Point quad[4], FloatPoint refined[4])
{
    FloatPoint corners[4];
    for (int i = 0; i < 4; ++i)
        corners[i] = (FloatPoint){(float)quad[i].x, (float)quad[i].y};
    FittedLine lines[4];
    for (int i = 0; i < 4; ++i)
        if (!fit_side(points, edge, count, corners[i], corners[(i + 1) & 3], &lines[i]))
            return 0;
    for (int i = 0; i < 4; ++i) {
        if (!intersect_lines(lines[(i + 3) & 3], lines[i], &refined[i]))
            return 0;
        float dx = refined[i].x - corners[i].x, dy = refined[i].y - corners[i].y;
        if (dx * dx + dy * dy > 196)
            return 0;
    }
    return 1;
}

static float distance_float(FloatPoint a, FloatPoint b)
{
    float x = a.x - b.x, y = a.y - b.y;
    return sqrtf(x * x + y * y);
}

static float area_quad_float(FloatPoint q[4])
{
    float area = 0;
    for (int i = 0; i < 4; ++i)
        area += q[i].x * q[(i + 1) & 3].y - q[(i + 1) & 3].x * q[i].y;
    return fabsf(area) * 0.5f;
}

static float dot_angle_float(FloatPoint a, FloatPoint b, FloatPoint c)
{
    float ax = a.x - b.x, ay = a.y - b.y, cx = c.x - b.x, cy = c.y - b.y;
    float denominator = sqrtf((ax * ax + ay * ay) * (cx * cx + cy * cy));
    return denominator < 0.001f ? 1 : fabsf((ax * cx + ay * cy) / denominator);
}

static void order_corners_float(FloatPoint q[4])
{
    int start = 0;
    float best = q[0].x + q[0].y;
    for (int i = 1; i < 4; ++i) {
        float score = q[i].x + q[i].y;
        if (score < best) { best = score; start = i; }
    }
    FloatPoint ordered[4] = {q[0], q[1], q[2], q[3]};
    for (int i = 0; i < 4; ++i)
        q[i] = ordered[(start + i) & 3];
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

static void block_average_row(const uint8_t *source, size_t row_bytes, size_t source_width, size_t source_height, size_t scale, size_t width, size_t y, uint8_t *out)
{
    size_t y0 = y * scale, y1 = y0 + scale < source_height ? y0 + scale : source_height;
    size_t x = 0;
#if defined(__ARM_NEON__)
    if (scale == 2 && y1 - y0 == 2) {
        const uint8_t *top = source + y0 * row_bytes, *bottom = top + row_bytes;
        for (; x + 16 <= width && 2 * x + 32 <= source_width; x += 16) {
            uint8x16x2_t a = vld2q_u8(top + 2 * x), b = vld2q_u8(bottom + 2 * x);
            uint16x8_t low = vaddq_u16(vaddl_u8(vget_low_u8(a.val[0]), vget_low_u8(a.val[1])), vaddl_u8(vget_low_u8(b.val[0]), vget_low_u8(b.val[1])));
            uint16x8_t high = vaddq_u16(vaddl_u8(vget_high_u8(a.val[0]), vget_high_u8(a.val[1])), vaddl_u8(vget_high_u8(b.val[0]), vget_high_u8(b.val[1])));
            low = vaddq_u16(low, vdupq_n_u16(2));
            high = vaddq_u16(high, vdupq_n_u16(2));
            vst1q_u8(out + x, vcombine_u8(vshrn_n_u16(low, 2), vshrn_n_u16(high, 2)));
        }
    }
#endif
    for (; x < width; ++x) {
        size_t x0 = x * scale, x1 = x0 + scale < source_width ? x0 + scale : source_width;
        unsigned sum = 0;
        for (size_t sy = y0; sy < y1; ++sy)
            for (size_t sx = x0; sx < x1; ++sx)
                sum += source[sy * row_bytes + sx];
        unsigned count = (unsigned)((y1 - y0) * (x1 - x0));
        out[x] = (uint8_t)((sum + count / 2) / count);
    }
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
    uint8_t *gray = malloc(width * height), *magnitude = calloc(width * height, 1), *edge = calloc(width * height, 1), *seen = calloc(width * height, 1);
    size_t *queue = malloc(width * height * sizeof(size_t));
    Point *points = malloc(width * height * sizeof(Point)), *hull = malloc(width * height * sizeof(Point));
    FloatPoint *subpixel = malloc(width * height * sizeof(FloatPoint));
    if (!gray || !magnitude || !edge || !seen || !queue || !points || !hull || !subpixel) {
        free(gray); free(magnitude); free(edge); free(seen); free(queue); free(points); free(hull); free(subpixel);
        return SIZE_MAX;
    }
    for (size_t y = 0; y < height; ++y)
        block_average_row(source, row_bytes, source_width, source_height, scale, width, y, gray + y * width);
    unsigned low_threshold = 18, high_threshold = 48;
    make_edge_map(gray, width, height, low_threshold, high_threshold, magnitude, edge, 0);
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
        for (size_t i = 0; i < count; ++i)
            subpixel[i] = subpixel_edge(gray, magnitude, width, height, points[i]);
        FloatPoint refined[4];
        if (!refine_quad(points, subpixel, count, q, refined))
            for (int i = 0; i < 4; ++i) refined[i] = (FloatPoint){q[i].x, q[i].y};
        int unique = 1;
        for (int i = 0; i < 4; ++i)
            for (int j = i + 1; j < 4; ++j)
                if (q[i].x == q[j].x && q[i].y == q[j].y) unique = 0;
        float area = area_quad_float(refined);
        if (!unique || area < min_area)
            continue;
        float sides[4], min_side = INFINITY, max_side = 0;
        for (int i = 0; i < 4; ++i) { sides[i] = distance_float(refined[i], refined[(i + 1) & 3]); if (sides[i] < min_side) min_side = sides[i]; if (sides[i] > max_side) max_side = sides[i]; }
        float aspect = min_side / max_side;
        if (aspect < options.minimum_aspect_ratio || aspect > options.maximum_aspect_ratio)
            continue;
        float angle_limit = sinf(options.quadrature_tolerance * 0.01745329252f);
        int angles = 1;
        for (int i = 0; i < 4; ++i)
            if (dot_angle_float(refined[(i + 3) & 3], refined[i], refined[(i + 1) & 3]) > angle_limit) angles = 0;
        if (!angles)
            continue;
        float confidence = 0;
        for (int i = 0; i < 4; ++i)
            confidence += side_support(edge, width, height, width, q[i], q[(i + 1) & 3]) * 0.25f;
        if (confidence < options.minimum_confidence)
            continue;
        order_corners_float(refined);
        RevenantVisionRectangle candidate;
        for (int i = 0; i < 4; ++i) {
            candidate.corners[i].x = (refined[i].x + 0.5f) * scale / source_width;
            candidate.corners[i].y = 1.0f - (refined[i].y + 0.5f) * scale / source_height;
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
    free(gray); free(magnitude); free(edge); free(seen); free(queue); free(points); free(hull); free(subpixel);
    return found;
}
