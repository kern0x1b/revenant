#include "RevenantDocumentWarp.h"

#include <math.h>

#define SPAN 8
#define LARGEST_SIDE 16384
#define COORDINATE_LIMIT 16384.0f

typedef struct {
    double a, b, c, d, e, f, g, h;
} Projection;

static double distance(RevenantDocumentPoint from, RevenantDocumentPoint to)
{
    double x = (double)to.x - (double)from.x;
    double y = (double)to.y - (double)from.y;
    return sqrt(x * x + y * y);
}

static double larger(double left, double right)
{
    return left > right ? left : right;
}

static double cross(RevenantDocumentPoint origin, RevenantDocumentPoint a, RevenantDocumentPoint b)
{
    return ((double)a.x - origin.x) * ((double)b.y - origin.y) - ((double)a.y - origin.y) * ((double)b.x - origin.x);
}

static int is_convex(const RevenantDocumentPoint q[4])
{
    int positive = 0;
    int negative = 0;
    for (int i = 0; i < 4; ++i) {
        double turn = cross(q[i], q[(i + 1) & 3], q[(i + 2) & 3]);
        if (turn > 1e-6)
            positive = 1;
        else if (turn < -1e-6)
            negative = 1;
        else
            return 0;
    }
    return positive != negative;
}

static int make_projection(const RevenantDocumentPoint q[4], Projection *p)
{
    if (!is_convex(q))
        return 0;
    double x0 = q[0].x, y0 = q[0].y, x1 = q[1].x, y1 = q[1].y;
    double x2 = q[2].x, y2 = q[2].y, x3 = q[3].x, y3 = q[3].y;
    double sx = x0 - x1 + x2 - x3;
    double sy = y0 - y1 + y2 - y3;
    p->c = x0;
    p->f = y0;
    if (fabs(sx) < 1e-9 && fabs(sy) < 1e-9) {
        p->a = x1 - x0;
        p->b = x3 - x0;
        p->d = y1 - y0;
        p->e = y3 - y0;
        p->g = 0;
        p->h = 0;
        return 1;
    }
    double dx1 = x1 - x2, dx2 = x3 - x2, dy1 = y1 - y2, dy2 = y3 - y2;
    double determinant = dx1 * dy2 - dx2 * dy1;
    if (fabs(determinant) < 1e-9)
        return 0;
    p->g = (sx * dy2 - dx2 * sy) / determinant;
    p->h = (dx1 * sy - sx * dy1) / determinant;
    p->a = x1 - x0 + p->g * x1;
    p->b = x3 - x0 + p->h * x3;
    p->d = y1 - y0 + p->g * y1;
    p->e = y3 - y0 + p->h * y3;
    return 1;
}

RevenantDocumentSize RevenantDocumentOutputSize(const RevenantDocumentPoint quad[4], size_t maximum_side)
{
    double width = larger(distance(quad[0], quad[1]), distance(quad[3], quad[2]));
    double height = larger(distance(quad[0], quad[3]), distance(quad[1], quad[2]));
    double longest = larger(width, height);
    if (maximum_side > 0 && longest > (double)maximum_side) {
        double scale = (double)maximum_side / longest;
        width *= scale;
        height *= scale;
    }
    RevenantDocumentSize size;
    size.width = width < 1 ? 1 : (size_t)(width + 0.5);
    size.height = height < 1 ? 1 : (size_t)(height + 0.5);
    return size;
}

typedef struct {
    float a, b, c, d, e, f, g, h;
} Coefficients;

static float limited(float value)
{
    return value < -COORDINATE_LIMIT ? -COORDINATE_LIMIT : (value > COORDINATE_LIMIT ? COORDINATE_LIMIT : value);
}

static void project(const Coefficients *k, float u, float v, float *sx, float *sy)
{
    float w = k->g * u + k->h * v + 1.0f;
    if (w < 1e-6f)
        w = 1e-6f;
    float inverse = 1.0f / w;
    *sx = limited((k->a * u + k->b * v + k->c) * inverse - 0.5f);
    *sy = limited((k->d * u + k->e * v + k->f) * inverse - 0.5f);
}

static int32_t clamped(int32_t value, int32_t last)
{
    return value < 0 ? 0 : (value > last ? last : value);
}

int RevenantDocumentWarp(const uint8_t *source, size_t source_width, size_t source_height, size_t source_row_bytes,
                         const RevenantDocumentPoint quad[4], uint8_t *output, size_t output_width, size_t output_height,
                         size_t output_row_bytes)
{
    if (source == NULL || output == NULL || quad == NULL || source_width == 0 || source_height == 0 || output_width == 0 ||
        output_height == 0 || source_row_bytes < source_width * 4 || output_row_bytes < output_width * 4 ||
        source_width > LARGEST_SIDE || source_height > LARGEST_SIDE)
        return 0;
    Projection projection;
    if (!make_projection(quad, &projection))
        return 0;
    const Coefficients k = {(float)projection.a, (float)projection.b, (float)projection.c, (float)projection.d,
                            (float)projection.e, (float)projection.f, (float)projection.g, (float)projection.h};
    const int32_t last_x = (int32_t)(source_width - 1) << 8;
    const int32_t last_y = (int32_t)(source_height - 1) << 8;
    const float step_u = 1.0f / (float)output_width;
    const float step_v = 1.0f / (float)output_height;
    for (size_t y = 0; y < output_height; ++y) {
        const float v = ((float)y + 0.5f) * step_v;
        uint8_t *out = output + y * output_row_bytes;
        float start_x, start_y;
        project(&k, 0.5f * step_u, v, &start_x, &start_y);
        for (size_t x0 = 0; x0 < output_width;) {
            size_t x1 = x0 + SPAN < output_width ? x0 + SPAN : output_width;
            const float count = (float)(x1 - x0);
            float end_x, end_y;
            project(&k, ((float)x1 + 0.5f) * step_u, v, &end_x, &end_y);
            int32_t position_x = (int32_t)(start_x * 65536.0f);
            int32_t position_y = (int32_t)(start_y * 65536.0f);
            const int32_t delta_x = (int32_t)((end_x - start_x) * 65536.0f / count);
            const int32_t delta_y = (int32_t)((end_y - start_y) * 65536.0f / count);
            for (size_t x = x0; x < x1; ++x, out += 4, position_x += delta_x, position_y += delta_y) {
                const int32_t qx = clamped((position_x + 128) >> 8, last_x);
                const int32_t qy = clamped((position_y + 128) >> 8, last_y);
                const size_t ix = (size_t)(qx >> 8);
                const size_t iy = (size_t)(qy >> 8);
                const int32_t fx = qx & 255;
                const int32_t fy = qy & 255;
                const size_t jx = ix + 1 < source_width ? ix + 1 : ix;
                const size_t jy = iy + 1 < source_height ? iy + 1 : iy;
                const uint8_t *top = source + iy * source_row_bytes;
                const uint8_t *bottom = source + jy * source_row_bytes;
                const uint8_t *p00 = top + ix * 4, *p10 = top + jx * 4;
                const uint8_t *p01 = bottom + ix * 4, *p11 = bottom + jx * 4;
                for (int channel = 0; channel < 4; ++channel) {
                    const int32_t upper = p00[channel] * (256 - fx) + p10[channel] * fx;
                    const int32_t lower = p01[channel] * (256 - fx) + p11[channel] * fx;
                    out[channel] = (uint8_t)((upper * (256 - fy) + lower * fy + 32768) >> 16);
                }
            }
            start_x = end_x;
            start_y = end_y;
            x0 = x1;
        }
    }
    return 1;
}
