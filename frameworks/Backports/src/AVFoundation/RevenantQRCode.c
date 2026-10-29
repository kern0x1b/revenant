#include "RevenantQRCode.h"

#include <math.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    int width;
    int height;
    uint8_t *cells;
} Grid;

typedef struct {
    float x;
    float y;
    float size;
    int count;
} Pattern;

typedef struct {
    Pattern *items;
    int count;
    int capacity;
} PatternList;

static Grid grid_make(int width, int height)
{
    Grid grid = {width, height, calloc((size_t)width * (size_t)height, 1)};
    return grid;
}

static void grid_free(Grid *grid)
{
    free(grid->cells);
    grid->cells = NULL;
}

static int grid_get(const Grid *grid, int x, int y)
{
    return grid->cells[y * grid->width + x];
}

static void grid_set(Grid *grid, int x, int y, int value)
{
    grid->cells[y * grid->width + x] = (uint8_t)value;
}

static int clamp_int(int value, int low, int high)
{
    return value < low ? low : value > high ? high : value;
}

static Grid binarize_hybrid(const uint8_t *luma, int width, int height, int stride)
{
    Grid grid = grid_make(width, height);
    int subWidth = (width + 7) >> 3;
    int subHeight = (height + 7) >> 3;
    int *black = malloc(sizeof(int) * (size_t)subWidth * (size_t)subHeight);
    for (int y = 0; y < subHeight; y++) {
        int yoffset = y << 3;
        if (yoffset > height - 8)
            yoffset = height - 8;
        for (int x = 0; x < subWidth; x++) {
            int xoffset = x << 3;
            if (xoffset > width - 8)
                xoffset = width - 8;
            int sum = 0, min = 255, max = 0;
            for (int yy = 0; yy < 8; yy++) {
                const uint8_t *row = luma + (size_t)(yoffset + yy) * (size_t)stride + xoffset;
                for (int xx = 0; xx < 8; xx++) {
                    int pixel = row[xx];
                    sum += pixel;
                    if (pixel < min)
                        min = pixel;
                    if (pixel > max)
                        max = pixel;
                }
            }
            int average = sum >> 6;
            if (max - min <= 24) {
                average = min / 2;
                if (y > 0 && x > 0) {
                    int neighbours = (black[(y - 1) * subWidth + x] + 2 * black[y * subWidth + x - 1] + black[(y - 1) * subWidth + x - 1]) >> 2;
                    if (min < neighbours)
                        average = neighbours;
                }
            }
            black[y * subWidth + x] = average;
        }
    }
    for (int y = 0; y < subHeight; y++) {
        int yoffset = y << 3;
        if (yoffset > height - 8)
            yoffset = height - 8;
        int top = clamp_int(y, 2, subHeight - 3);
        for (int x = 0; x < subWidth; x++) {
            int xoffset = x << 3;
            if (xoffset > width - 8)
                xoffset = width - 8;
            int left = clamp_int(x, 2, subWidth - 3);
            int sum = 0;
            for (int dy = -2; dy <= 2; dy++) {
                for (int dx = -2; dx <= 2; dx++) {
                    int by = clamp_int(top + dy, 0, subHeight - 1), bx = clamp_int(left + dx, 0, subWidth - 1);
                    sum += black[by * subWidth + bx];
                }
            }
            int threshold = sum / 25;
            for (int yy = 0; yy < 8; yy++) {
                const uint8_t *row = luma + (size_t)(yoffset + yy) * (size_t)stride + xoffset;
                for (int xx = 0; xx < 8; xx++)
                    grid_set(&grid, xoffset + xx, yoffset + yy, row[xx] <= threshold);
            }
        }
    }
    free(black);
    return grid;
}

static Grid binarize_global(const uint8_t *luma, int width, int height, int stride)
{
    Grid grid = grid_make(width, height);
    long histogram[256] = {0};
    for (int y = 0; y < height; y++) {
        const uint8_t *row = luma + (size_t)y * (size_t)stride;
        for (int x = 0; x < width; x++)
            histogram[row[x]]++;
    }
    long total = (long)width * height, sumAll = 0;
    for (int level = 0; level < 256; level++)
        sumAll += level * histogram[level];
    long weightBack = 0, sumBack = 0;
    double best = -1;
    int threshold = 127;
    for (int level = 0; level < 256; level++) {
        weightBack += histogram[level];
        if (!weightBack)
            continue;
        long weightFront = total - weightBack;
        if (!weightFront)
            break;
        sumBack += level * histogram[level];
        double meanBack = (double)sumBack / weightBack, meanFront = (double)(sumAll - sumBack) / weightFront;
        double between = (double)weightBack * weightFront * (meanBack - meanFront) * (meanBack - meanFront);
        if (between > best) {
            best = between;
            threshold = level;
        }
    }
    for (int y = 0; y < height; y++) {
        const uint8_t *row = luma + (size_t)y * (size_t)stride;
        for (int x = 0; x < width; x++)
            grid_set(&grid, x, y, row[x] <= threshold);
    }
    return grid;
}

static int found_cross(const int counts[5])
{
    int total = 0;
    for (int index = 0; index < 5; index++) {
        if (counts[index] == 0)
            return 0;
        total += counts[index];
    }
    if (total < 7)
        return 0;
    float moduleSize = total / 7.0f, variance = moduleSize / 2.0f;
    return fabsf(moduleSize - counts[0]) < variance && fabsf(moduleSize - counts[1]) < variance && fabsf(3.0f * moduleSize - counts[2]) < 3.0f * variance &&
           fabsf(moduleSize - counts[3]) < variance && fabsf(moduleSize - counts[4]) < variance;
}

static float center_from_end(const int counts[5], int end)
{
    return (float)(end - counts[4] - counts[3]) - counts[2] / 2.0f;
}

static float cross_check_vertical(const Grid *grid, int startY, int centerX, int maxCount, int originalTotal)
{
    int counts[5] = {0, 0, 0, 0, 0};
    int y = startY;
    while (y >= 0 && grid_get(grid, centerX, y)) {
        counts[2]++;
        y--;
    }
    if (y < 0)
        return NAN;
    while (y >= 0 && !grid_get(grid, centerX, y) && counts[1] <= maxCount) {
        counts[1]++;
        y--;
    }
    if (y < 0 || counts[1] > maxCount)
        return NAN;
    while (y >= 0 && grid_get(grid, centerX, y) && counts[0] <= maxCount) {
        counts[0]++;
        y--;
    }
    if (counts[0] > maxCount)
        return NAN;
    y = startY + 1;
    while (y < grid->height && grid_get(grid, centerX, y)) {
        counts[2]++;
        y++;
    }
    if (y == grid->height)
        return NAN;
    while (y < grid->height && !grid_get(grid, centerX, y) && counts[3] < maxCount) {
        counts[3]++;
        y++;
    }
    if (y == grid->height || counts[3] >= maxCount)
        return NAN;
    while (y < grid->height && grid_get(grid, centerX, y) && counts[4] < maxCount) {
        counts[4]++;
        y++;
    }
    if (counts[4] >= maxCount)
        return NAN;
    int total = counts[0] + counts[1] + counts[2] + counts[3] + counts[4];
    if (5 * abs(total - originalTotal) >= 2 * originalTotal)
        return NAN;
    return found_cross(counts) ? center_from_end(counts, y) : NAN;
}

static float cross_check_horizontal(const Grid *grid, int startX, int centerY, int maxCount, int originalTotal)
{
    int counts[5] = {0, 0, 0, 0, 0};
    int x = startX;
    while (x >= 0 && grid_get(grid, x, centerY)) {
        counts[2]++;
        x--;
    }
    if (x < 0)
        return NAN;
    while (x >= 0 && !grid_get(grid, x, centerY) && counts[1] <= maxCount) {
        counts[1]++;
        x--;
    }
    if (x < 0 || counts[1] > maxCount)
        return NAN;
    while (x >= 0 && grid_get(grid, x, centerY) && counts[0] <= maxCount) {
        counts[0]++;
        x--;
    }
    if (counts[0] > maxCount)
        return NAN;
    x = startX + 1;
    while (x < grid->width && grid_get(grid, x, centerY)) {
        counts[2]++;
        x++;
    }
    if (x == grid->width)
        return NAN;
    while (x < grid->width && !grid_get(grid, x, centerY) && counts[3] < maxCount) {
        counts[3]++;
        x++;
    }
    if (x == grid->width || counts[3] >= maxCount)
        return NAN;
    while (x < grid->width && grid_get(grid, x, centerY) && counts[4] < maxCount) {
        counts[4]++;
        x++;
    }
    if (counts[4] >= maxCount)
        return NAN;
    int total = counts[0] + counts[1] + counts[2] + counts[3] + counts[4];
    if (5 * abs(total - originalTotal) >= originalTotal)
        return NAN;
    return found_cross(counts) ? center_from_end(counts, x) : NAN;
}

static void list_add(PatternList *list, Pattern pattern)
{
    if (list->count == list->capacity) {
        list->capacity = list->capacity ? list->capacity * 2 : 16;
        list->items = realloc(list->items, sizeof(Pattern) * (size_t)list->capacity);
    }
    list->items[list->count++] = pattern;
}

static int handle_possible_center(const Grid *grid, PatternList *list, const int counts[5], int row, int end)
{
    int total = counts[0] + counts[1] + counts[2] + counts[3] + counts[4];
    float centerX = center_from_end(counts, end);
    float centerY = cross_check_vertical(grid, row, (int)centerX, counts[2], total);
    if (isnan(centerY))
        return 0;
    centerX = cross_check_horizontal(grid, (int)centerX, (int)centerY, counts[2], total);
    if (isnan(centerX))
        return 0;
    float estimated = total / 7.0f;
    for (int index = 0; index < list->count; index++) {
        Pattern *known = &list->items[index];
        if (fabsf(centerY - known->y) <= estimated && fabsf(centerX - known->x) <= estimated) {
            float difference = fabsf(estimated - known->size);
            if (difference <= 1.0f || difference <= known->size) {
                int count = known->count + 1;
                known->x = (known->count * known->x + centerX) / count;
                known->y = (known->count * known->y + centerY) / count;
                known->size = (known->count * known->size + estimated) / count;
                known->count = count;
                return 1;
            }
        }
    }
    list_add(list, (Pattern){centerX, centerY, estimated, 1});
    return 1;
}

static void find_finder_patterns(const Grid *grid, PatternList *list)
{
    int skip = (3 * grid->height) / (4 * 97);
    if (skip < 3)
        skip = 3;
    for (int y = skip - 1; y < grid->height; y += skip) {
        int counts[5] = {0, 0, 0, 0, 0};
        int state = 0;
        for (int x = 0; x < grid->width; x++) {
            if (grid_get(grid, x, y)) {
                if (state & 1)
                    state++;
                counts[state]++;
            } else if (!(state & 1)) {
                if (state == 4) {
                    if (found_cross(counts) && handle_possible_center(grid, list, counts, y, x)) {
                        state = 0;
                        memset(counts, 0, sizeof counts);
                    } else {
                        counts[0] = counts[2];
                        counts[1] = counts[3];
                        counts[2] = counts[4];
                        counts[3] = 1;
                        counts[4] = 0;
                        state = 3;
                    }
                } else {
                    counts[++state]++;
                }
            } else {
                counts[state]++;
            }
        }
        if (found_cross(counts))
            handle_possible_center(grid, list, counts, y, grid->width);
    }
}

static float point_distance(float ax, float ay, float bx, float by)
{
    return hypotf(ax - bx, ay - by);
}

static float run_size(const Grid *grid, int fromX, int fromY, int toX, int toY)
{
    int steep = abs(toY - fromY) > abs(toX - fromX);
    if (steep) {
        int swap = fromX;
        fromX = fromY;
        fromY = swap;
        swap = toX;
        toX = toY;
        toY = swap;
    }
    int dx = abs(toX - fromX), dy = abs(toY - fromY), error = -dx / 2;
    int xstep = fromX < toX ? 1 : -1, ystep = fromY < toY ? 1 : -1;
    int state = 0, limit = toX + xstep;
    for (int x = fromX, y = fromY; x != limit; x += xstep) {
        int realX = steep ? y : x, realY = steep ? x : y;
        if (realX < 0 || realY < 0 || realX >= grid->width || realY >= grid->height)
            break;
        if ((state == 1) == (grid_get(grid, realX, realY) != 0)) {
            if (state == 2)
                return point_distance((float)x, (float)y, (float)fromX, (float)fromY);
            state++;
        }
        error += dy;
        if (error > 0) {
            if (y == toY)
                break;
            y += ystep;
            error -= dx;
        }
    }
    if (state == 2)
        return point_distance((float)(toX + xstep), (float)toY, (float)fromX, (float)fromY);
    return NAN;
}

static float run_size_both_ways(const Grid *grid, int fromX, int fromY, int toX, int toY)
{
    float result = run_size(grid, fromX, fromY, toX, toY);
    float scale = 1.0f;
    int otherX = fromX - (toX - fromX);
    if (otherX < 0) {
        scale = fromX / (float)(fromX - otherX);
        otherX = 0;
    } else if (otherX >= grid->width) {
        scale = (grid->width - 1 - fromX) / (float)(otherX - fromX);
        otherX = grid->width - 1;
    }
    int otherY = (int)(fromY - (toY - fromY) * scale);
    scale = 1.0f;
    if (otherY < 0) {
        scale = fromY / (float)(fromY - otherY);
        otherY = 0;
    } else if (otherY >= grid->height) {
        scale = (grid->height - 1 - fromY) / (float)(otherY - fromY);
        otherY = grid->height - 1;
    }
    otherX = (int)(fromX + (otherX - fromX) * scale);
    result += run_size(grid, fromX, fromY, otherX, otherY);
    return result - 1.0f;
}

static float module_size_one_way(const Grid *grid, Pattern a, Pattern b)
{
    float first = run_size_both_ways(grid, (int)a.x, (int)a.y, (int)b.x, (int)b.y);
    float second = run_size_both_ways(grid, (int)b.x, (int)b.y, (int)a.x, (int)a.y);
    if (isnan(first))
        return second / 7.0f;
    if (isnan(second))
        return first / 7.0f;
    return (first + second) / 14.0f;
}

static float module_size(const Grid *grid, Pattern topLeft, Pattern topRight, Pattern bottomLeft)
{
    float size = (module_size_one_way(grid, topLeft, topRight) + module_size_one_way(grid, topLeft, bottomLeft)) / 2.0f;
    return size;
}

typedef struct {
    double a[3][3];
} Transform;

static int solve_transform(const double source[4][2], const double target[4][2], Transform *out)
{
    double m[8][9];
    for (int index = 0; index < 4; index++) {
        double u = source[index][0], v = source[index][1], x = target[index][0], y = target[index][1];
        double *r0 = m[2 * index], *r1 = m[2 * index + 1];
        r0[0] = u; r0[1] = v; r0[2] = 1; r0[3] = 0; r0[4] = 0; r0[5] = 0; r0[6] = -u * x; r0[7] = -v * x; r0[8] = x;
        r1[0] = 0; r1[1] = 0; r1[2] = 0; r1[3] = u; r1[4] = v; r1[5] = 1; r1[6] = -u * y; r1[7] = -v * y; r1[8] = y;
    }
    for (int column = 0; column < 8; column++) {
        int pivot = column;
        for (int row = column + 1; row < 8; row++) {
            if (fabs(m[row][column]) > fabs(m[pivot][column]))
                pivot = row;
        }
        if (fabs(m[pivot][column]) < 1e-12)
            return 0;
        if (pivot != column) {
            for (int k = 0; k < 9; k++) {
                double swap = m[column][k];
                m[column][k] = m[pivot][k];
                m[pivot][k] = swap;
            }
        }
        for (int row = 0; row < 8; row++) {
            if (row == column)
                continue;
            double factor = m[row][column] / m[column][column];
            for (int k = column; k < 9; k++)
                m[row][k] -= factor * m[column][k];
        }
    }
    double h[8];
    for (int index = 0; index < 8; index++)
        h[index] = m[index][8] / m[index][index];
    out->a[0][0] = h[0]; out->a[0][1] = h[1]; out->a[0][2] = h[2];
    out->a[1][0] = h[3]; out->a[1][1] = h[4]; out->a[1][2] = h[5];
    out->a[2][0] = h[6]; out->a[2][1] = h[7]; out->a[2][2] = 1;
    return 1;
}

static int apply_transform(const Transform *t, double u, double v, double *x, double *y)
{
    double w = t->a[2][0] * u + t->a[2][1] * v + t->a[2][2];
    if (fabs(w) < 1e-12)
        return 0;
    *x = (t->a[0][0] * u + t->a[0][1] * v + t->a[0][2]) / w;
    *y = (t->a[1][0] * u + t->a[1][1] * v + t->a[1][2]) / w;
    return 1;
}

static int alignment_score(const Grid *grid, float cx, float cy, const float step[2][2])
{
    int matches = 0;
    for (int dy = -2; dy <= 2; dy++) {
        for (int dx = -2; dx <= 2; dx++) {
            int x = (int)lroundf(cx + dx * step[0][0] + dy * step[1][0]);
            int y = (int)lroundf(cy + dx * step[0][1] + dy * step[1][1]);
            if (x < 0 || y < 0 || x >= grid->width || y >= grid->height)
                continue;
            int expected = (abs(dx) > 1 || abs(dy) > 1) || (dx == 0 && dy == 0);
            if ((grid_get(grid, x, y) != 0) == expected)
                matches++;
        }
    }
    return matches;
}

static int find_alignment(const Grid *grid, float estimatedX, float estimatedY, float moduleSizeEstimate, float allowanceFactor, const float step[2][2], Pattern *found)
{
    int allowance = (int)(allowanceFactor * moduleSizeEstimate);
    int left = clamp_int((int)estimatedX - allowance, 0, grid->width - 1);
    int right = clamp_int((int)estimatedX + allowance, 0, grid->width - 1);
    int top = clamp_int((int)estimatedY - allowance, 0, grid->height - 1);
    int bottom = clamp_int((int)estimatedY + allowance, 0, grid->height - 1);
    if (right - left < moduleSizeEstimate * 3 || bottom - top < moduleSizeEstimate * 3)
        return 0;
    PatternList list = {0};
    for (int y = top; y <= bottom; y++) {
        int runs[3] = {0, 0, 0};
        int state = 0;
        int x = left;
        while (x <= right && !grid_get(grid, x, y))
            x++;
        for (; x <= right; x++) {
            if (grid_get(grid, x, y)) {
                if (state == 1) {
                    runs[1]++;
                } else if (state == 2) {
                    float size = moduleSizeEstimate, variance = size / 2;
                    if (fabsf(size - runs[0]) < variance && fabsf(size - runs[1]) < variance && fabsf(size - runs[2]) < variance) {
                        float centerX = (float)(x - runs[2]) - runs[1] / 2.0f;
                        int vertical[3] = {0, 0, 0};
                        int cy = y, cx = (int)centerX;
                        int up = cy;
                        while (up >= 0 && grid_get(grid, cx, up)) {
                            vertical[1]++;
                            up--;
                        }
                        while (up >= 0 && !grid_get(grid, cx, up) && vertical[0] <= 2 * (int)ceilf(size)) {
                            vertical[0]++;
                            up--;
                        }
                        int down = cy + 1;
                        while (down < grid->height && grid_get(grid, cx, down)) {
                            vertical[1]++;
                            down++;
                        }
                        while (down < grid->height && !grid_get(grid, cx, down) && vertical[2] <= 2 * (int)ceilf(size)) {
                            vertical[2]++;
                            down++;
                        }
                        if (fabsf(size - vertical[0]) < variance && fabsf(size - vertical[1]) < variance && fabsf(size - vertical[2]) < variance) {
                            float centerY = (float)(down - vertical[2]) - vertical[1] / 2.0f;
                            int merged = 0;
                            for (int index = 0; index < list.count && !merged; index++) {
                                if (fabsf(centerX - list.items[index].x) < size && fabsf(centerY - list.items[index].y) < size)
                                    merged = 1;
                            }
                            if (!merged)
                                list_add(&list, (Pattern){centerX, centerY, size, alignment_score(grid, centerX, centerY, step)});
                        }
                    }
                    runs[0] = runs[2];
                    runs[1] = 1;
                    runs[2] = 0;
                    state = 1;
                } else {
                    runs[++state]++;
                }
            } else {
                if (state == 1)
                    state++;
                runs[state]++;
            }
        }
    }
    int best = -1;
    float bestDistance = 0;
    for (int index = 0; index < list.count; index++) {
        if (list.items[index].count < 22)
            continue;
        float distance = point_distance(list.items[index].x, list.items[index].y, estimatedX, estimatedY) - list.items[index].count * moduleSizeEstimate;
        if (best < 0 || distance < bestDistance) {
            best = index;
            bestDistance = distance;
        }
    }
    int ok = best >= 0;
    if (ok)
        *found = list.items[best];
    free(list.items);
    return ok;
}

static const int ecc_codewords_per_block[4][41] = {
    {-1, 7, 10, 15, 20, 26, 18, 20, 24, 30, 18, 20, 24, 26, 30, 22, 24, 28, 30, 28, 28, 28, 28, 30, 30, 26, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30},
    {-1, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26, 30, 22, 22, 24, 24, 28, 28, 26, 26, 26, 26, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28},
    {-1, 13, 22, 18, 26, 18, 24, 18, 22, 20, 24, 28, 26, 24, 20, 30, 24, 28, 28, 26, 30, 28, 30, 30, 30, 30, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30},
    {-1, 17, 28, 22, 16, 22, 28, 26, 26, 24, 28, 24, 28, 22, 24, 24, 30, 28, 28, 26, 28, 30, 24, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30},
};

static const int ecc_block_count[4][41] = {
    {-1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 4, 4, 4, 4, 4, 6, 6, 6, 6, 7, 8, 8, 9, 9, 10, 12, 12, 12, 13, 14, 15, 16, 17, 18, 19, 19, 20, 21, 22, 24, 25},
    {-1, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5, 5, 8, 9, 9, 10, 10, 11, 13, 14, 16, 17, 17, 18, 20, 21, 23, 25, 26, 28, 29, 31, 33, 35, 37, 38, 40, 43, 45, 47, 49},
    {-1, 1, 1, 2, 2, 4, 4, 6, 6, 8, 8, 8, 10, 12, 16, 12, 17, 16, 18, 21, 20, 23, 23, 25, 27, 29, 34, 34, 35, 38, 40, 43, 45, 48, 51, 53, 56, 59, 62, 65, 68},
    {-1, 1, 1, 2, 4, 4, 4, 5, 6, 8, 8, 11, 11, 16, 16, 18, 16, 19, 21, 25, 25, 25, 34, 30, 32, 35, 37, 40, 42, 45, 48, 51, 54, 57, 60, 63, 66, 70, 74, 77, 81},
};

static const int level_for_bits[4] = {1, 0, 3, 2};

static int alignment_positions(int version, int *positions)
{
    if (version == 1)
        return 0;
    int count = version / 7 + 2;
    int step = version == 32 ? 26 : (version * 4 + count * 2 + 1) / (count * 2 - 2) * 2;
    positions[0] = 6;
    for (int index = count - 1, position = version * 4 + 10; index >= 1; index--, position -= step)
        positions[index] = position;
    return count;
}

static int raw_codewords(int version)
{
    int modules = (16 * version + 128) * version + 64;
    if (version >= 2) {
        int count = version / 7 + 2;
        modules -= (25 * count - 10) * count - 55;
        if (version >= 7)
            modules -= 36;
    }
    return modules / 8;
}

static void build_function_mask(int version, Grid *mask)
{
    int size = version * 4 + 17;
    *mask = grid_make(size, size);
    for (int y = 0; y < 9; y++) {
        for (int x = 0; x < 9; x++)
            grid_set(mask, x, y, 1);
    }
    for (int y = 0; y < 9; y++) {
        for (int x = size - 8; x < size; x++)
            grid_set(mask, x, y, 1);
    }
    for (int y = size - 8; y < size; y++) {
        for (int x = 0; x < 9; x++)
            grid_set(mask, x, y, 1);
    }
    for (int index = 0; index < size; index++) {
        grid_set(mask, index, 6, 1);
        grid_set(mask, 6, index, 1);
    }
    int positions[8];
    int count = alignment_positions(version, positions);
    for (int row = 0; row < count; row++) {
        for (int column = 0; column < count; column++) {
            if ((row == 0 && column == 0) || (row == 0 && column == count - 1) || (row == count - 1 && column == 0))
                continue;
            for (int dy = -2; dy <= 2; dy++) {
                for (int dx = -2; dx <= 2; dx++)
                    grid_set(mask, positions[column] + dx, positions[row] + dy, 1);
            }
        }
    }
    if (version >= 7) {
        for (int y = 0; y < 6; y++) {
            for (int x = size - 11; x < size - 8; x++) {
                grid_set(mask, x, y, 1);
                grid_set(mask, y, x, 1);
            }
        }
    }
}

static int bch_remainder(int value, int generator, int generatorBits)
{
    int shift = 0;
    for (int bits = generator; bits > 1; bits >>= 1)
        shift++;
    (void)generatorBits;
    for (int bit = 31 - __builtin_clz(value | 1); bit >= shift; bit--) {
        if (value & (1 << bit))
            value ^= generator << (bit - shift);
    }
    return value;
}

static int format_word(int data)
{
    int word = (data << 10) | bch_remainder(data << 10, 0x537, 11);
    return word ^ 0x5412;
}

static int version_word(int version)
{
    return (version << 12) | bch_remainder(version << 12, 0x1F25, 13);
}

static int decode_format(int first, int second)
{
    int best = -1, distance = 4;
    for (int data = 0; data < 32; data++) {
        int word = format_word(data);
        int d1 = __builtin_popcount(first ^ word), d2 = __builtin_popcount(second ^ word);
        int d = d1 < d2 ? d1 : d2;
        if (d < distance) {
            distance = d;
            best = data;
        }
    }
    return best;
}

static int decode_version(int first, int second)
{
    int best = -1, distance = 4;
    for (int version = 7; version <= 40; version++) {
        int word = version_word(version);
        int d1 = __builtin_popcount(first ^ word), d2 = __builtin_popcount(second ^ word);
        int d = d1 < d2 ? d1 : d2;
        if (d < distance) {
            distance = d;
            best = version;
        }
    }
    return best;
}

static int data_mask_bit(int mask, int row, int column)
{
    switch (mask) {
    case 0: return (row + column) % 2 == 0;
    case 1: return row % 2 == 0;
    case 2: return column % 3 == 0;
    case 3: return (row + column) % 3 == 0;
    case 4: return (row / 2 + column / 3) % 2 == 0;
    case 5: return (row * column) % 2 + (row * column) % 3 == 0;
    case 6: return ((row * column) % 2 + (row * column) % 3) % 2 == 0;
    default: return ((row + column) % 2 + (row * column) % 3) % 2 == 0;
    }
}

static uint8_t gf_exp[512];
static uint8_t gf_log[256];
static int gf_ready;

static void gf_init(void)
{
    if (gf_ready)
        return;
    int value = 1;
    for (int index = 0; index < 255; index++) {
        gf_exp[index] = (uint8_t)value;
        gf_log[value] = (uint8_t)index;
        value <<= 1;
        if (value & 0x100)
            value ^= 0x11D;
    }
    for (int index = 255; index < 512; index++)
        gf_exp[index] = gf_exp[index - 255];
    gf_ready = 1;
}

static uint8_t gf_mul(uint8_t a, uint8_t b)
{
    if (!a || !b)
        return 0;
    return gf_exp[gf_log[a] + gf_log[b]];
}

static uint8_t gf_div(uint8_t a, uint8_t b)
{
    if (!a)
        return 0;
    return gf_exp[gf_log[a] + 255 - gf_log[b]];
}

static int rs_correct(uint8_t *block, int length, int parity)
{
    gf_init();
    uint8_t syndromes[64];
    int clean = 1;
    for (int index = 0; index < parity; index++) {
        uint8_t value = 0;
        for (int position = 0; position < length; position++)
            value = (uint8_t)(gf_mul(value, gf_exp[index]) ^ block[position]);
        syndromes[index] = value;
        if (value)
            clean = 0;
    }
    if (clean)
        return 0;
    uint8_t locator[65] = {1}, previous[65] = {1}, scratch[65];
    int degree = 0, gap = 1;
    uint8_t lastDiscrepancy = 1;
    for (int step = 0; step < parity; step++) {
        uint8_t discrepancy = syndromes[step];
        for (int index = 1; index <= degree; index++)
            discrepancy ^= gf_mul(locator[index], syndromes[step - index]);
        if (!discrepancy) {
            gap++;
        } else if (2 * degree <= step) {
            memcpy(scratch, locator, sizeof locator);
            uint8_t factor = gf_div(discrepancy, lastDiscrepancy);
            for (int index = 0; index + gap <= 64; index++)
                locator[index + gap] ^= gf_mul(factor, previous[index]);
            degree = step + 1 - degree;
            memcpy(previous, scratch, sizeof previous);
            lastDiscrepancy = discrepancy;
            gap = 1;
        } else {
            uint8_t factor = gf_div(discrepancy, lastDiscrepancy);
            for (int index = 0; index + gap <= 64; index++)
                locator[index + gap] ^= gf_mul(factor, previous[index]);
            gap++;
        }
    }
    if (degree > parity / 2 || degree == 0)
        return -1;
    int positions[32], found = 0;
    for (int position = 0; position < length && found <= degree; position++) {
        int exponent = (255 - position) % 255;
        uint8_t value = 0;
        for (int index = 0; index <= degree; index++)
            value ^= gf_mul(locator[index], gf_exp[(exponent * index) % 255]);
        if (!value) {
            if (found == 32)
                return -1;
            positions[found++] = position;
        }
    }
    if (found != degree)
        return -1;
    uint8_t omega[64] = {0};
    for (int index = 0; index < parity; index++) {
        uint8_t value = 0;
        for (int k = 0; k <= index && k <= degree; k++)
            value ^= gf_mul(locator[k], syndromes[index - k]);
        omega[index] = value;
    }
    for (int index = 0; index < found; index++) {
        int position = positions[index];
        int exponent = (255 - position) % 255;
        uint8_t numerator = 0, denominator = 0;
        for (int k = 0; k < parity; k++)
            numerator ^= gf_mul(omega[k], gf_exp[(exponent * k) % 255]);
        for (int k = 1; k <= degree; k += 2)
            denominator ^= gf_mul(locator[k], gf_exp[(exponent * (k - 1)) % 255]);
        if (!denominator)
            return -1;
        uint8_t magnitude = gf_mul(gf_exp[position % 255], gf_div(numerator, denominator));
        block[length - 1 - position] ^= magnitude;
    }
    for (int index = 0; index < parity; index++) {
        uint8_t value = 0;
        for (int position = 0; position < length; position++)
            value = (uint8_t)(gf_mul(value, gf_exp[index]) ^ block[position]);
        if (value)
            return -1;
    }
    return found;
}

typedef struct {
    const uint8_t *bytes;
    size_t length;
    size_t position;
} BitReader;

static int bits_available(const BitReader *reader)
{
    return (int)(reader->length * 8 - reader->position);
}

static int bits_read(BitReader *reader, int count)
{
    int value = 0;
    for (int index = 0; index < count; index++) {
        size_t byte = reader->position >> 3;
        int bit = (reader->bytes[byte] >> (7 - (reader->position & 7))) & 1;
        value = (value << 1) | bit;
        reader->position++;
    }
    return value;
}

typedef struct {
    char *bytes;
    size_t length;
    size_t capacity;
    int undecodable;
} Buffer;

static void buffer_append(Buffer *buffer, const char *data, size_t length)
{
    if (buffer->length + length + 1 > buffer->capacity) {
        buffer->capacity = (buffer->length + length + 1) * 2;
        buffer->bytes = realloc(buffer->bytes, buffer->capacity);
    }
    memcpy(buffer->bytes + buffer->length, data, length);
    buffer->length += length;
    buffer->bytes[buffer->length] = 0;
}

static void buffer_utf8(Buffer *buffer, unsigned scalar)
{
    char out[4];
    size_t length;
    if (scalar < 0x80) {
        out[0] = (char)scalar;
        length = 1;
    } else if (scalar < 0x800) {
        out[0] = (char)(0xC0 | (scalar >> 6));
        out[1] = (char)(0x80 | (scalar & 0x3F));
        length = 2;
    } else if (scalar < 0x10000) {
        out[0] = (char)(0xE0 | (scalar >> 12));
        out[1] = (char)(0x80 | ((scalar >> 6) & 0x3F));
        out[2] = (char)(0x80 | (scalar & 0x3F));
        length = 3;
    } else {
        out[0] = (char)(0xF0 | (scalar >> 18));
        out[1] = (char)(0x80 | ((scalar >> 12) & 0x3F));
        out[2] = (char)(0x80 | ((scalar >> 6) & 0x3F));
        out[3] = (char)(0x80 | (scalar & 0x3F));
        length = 4;
    }
    buffer_append(buffer, out, length);
}

static int valid_utf8(const uint8_t *bytes, size_t length)
{
    size_t index = 0;
    while (index < length) {
        uint8_t lead = bytes[index];
        size_t extra;
        if (lead < 0x80)
            extra = 0;
        else if ((lead >> 5) == 6 && lead >= 0xC2)
            extra = 1;
        else if ((lead >> 4) == 14)
            extra = 2;
        else if ((lead >> 3) == 30 && lead <= 0xF4)
            extra = 3;
        else
            return 0;
        if (index + extra >= length + (extra == 0 ? 1 : 0) && extra != 0)
            return 0;
        for (size_t k = 1; k <= extra; k++) {
            if ((bytes[index + k] & 0xC0) != 0x80)
                return 0;
        }
        index += extra + 1;
    }
    return 1;
}

static RevenantQRConverter converter_hook;

void revenant_qr_set_converter(RevenantQRConverter converter)
{
    converter_hook = converter;
}

static void append_converted(Buffer *buffer, int eci, const uint8_t *bytes, size_t length)
{
    char *converted = NULL;
    size_t convertedLength = 0;
    if (converter_hook && converter_hook(eci, bytes, length, &converted, &convertedLength) && converted)
        buffer_append(buffer, converted, convertedLength);
    else
        buffer->undecodable = 1;
    free(converted);
}

static const char alphanumeric_chars[] = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:";

static int count_bits(int version, int mode)
{
    int band = version <= 9 ? 0 : version <= 26 ? 1 : 2;
    static const int numeric[3] = {10, 12, 14}, alphanumeric[3] = {9, 11, 13}, byte[3] = {8, 16, 16}, kanji[3] = {8, 10, 12};
    switch (mode) {
    case 1: return numeric[band];
    case 2: return alphanumeric[band];
    case 4: return byte[band];
    default: return kanji[band];
    }
}

static int parse_stream(const uint8_t *data, size_t length, int version, Buffer *out)
{
    BitReader reader = {data, length, 0};
    int eci = -1;
    int fnc1 = 0;
    while (bits_available(&reader) >= 4) {
        int mode = bits_read(&reader, 4);
        if (mode == 0)
            break;
        if (mode == 3) {
            if (bits_available(&reader) < 16)
                return 0;
            bits_read(&reader, 16);
            continue;
        }
        if (mode == 5) {
            fnc1 = 1;
            continue;
        }
        if (mode == 9) {
            if (bits_available(&reader) < 8)
                return 0;
            bits_read(&reader, 8);
            fnc1 = 2;
            continue;
        }
        if (mode == 7) {
            if (bits_available(&reader) < 8)
                return 0;
            int first = bits_read(&reader, 8);
            if ((first & 0x80) == 0) {
                eci = first;
            } else if ((first & 0xC0) == 0x80) {
                if (bits_available(&reader) < 8)
                    return 0;
                eci = ((first & 0x3F) << 8) | bits_read(&reader, 8);
            } else {
                if (bits_available(&reader) < 16)
                    return 0;
                eci = ((first & 0x1F) << 16) | bits_read(&reader, 16);
            }
            continue;
        }
        if (mode != 1 && mode != 2 && mode != 4 && mode != 8)
            return 0;
        int bits = count_bits(version, mode);
        if (bits_available(&reader) < bits)
            return 0;
        int count = bits_read(&reader, bits);
        if (mode == 1) {
            while (count >= 3) {
                if (bits_available(&reader) < 10)
                    return 0;
                int value = bits_read(&reader, 10);
                if (value >= 1000)
                    return 0;
                char digits[3] = {(char)('0' + value / 100), (char)('0' + (value / 10) % 10), (char)('0' + value % 10)};
                buffer_append(out, digits, 3);
                count -= 3;
            }
            if (count == 2) {
                if (bits_available(&reader) < 7)
                    return 0;
                int value = bits_read(&reader, 7);
                if (value >= 100)
                    return 0;
                char digits[2] = {(char)('0' + value / 10), (char)('0' + value % 10)};
                buffer_append(out, digits, 2);
            } else if (count == 1) {
                if (bits_available(&reader) < 4)
                    return 0;
                int value = bits_read(&reader, 4);
                if (value >= 10)
                    return 0;
                char digit = (char)('0' + value);
                buffer_append(out, &digit, 1);
            }
        } else if (mode == 2) {
            size_t start = out->length;
            while (count >= 2) {
                if (bits_available(&reader) < 11)
                    return 0;
                int value = bits_read(&reader, 11);
                if (value / 45 >= 45)
                    return 0;
                char pair[2] = {alphanumeric_chars[value / 45], alphanumeric_chars[value % 45]};
                buffer_append(out, pair, 2);
                count -= 2;
            }
            if (count == 1) {
                if (bits_available(&reader) < 6)
                    return 0;
                int value = bits_read(&reader, 6);
                if (value >= 45)
                    return 0;
                buffer_append(out, &alphanumeric_chars[value], 1);
            }
            if (fnc1 && out->length > start) {
                char *text = out->bytes;
                size_t write = start;
                for (size_t read = start; read < out->length; read++) {
                    if (text[read] == '%') {
                        if (read + 1 < out->length && text[read + 1] == '%') {
                            text[write++] = '%';
                            read++;
                        } else {
                            text[write++] = 0x1D;
                        }
                    } else {
                        text[write++] = text[read];
                    }
                }
                out->length = write;
                out->bytes[write] = 0;
            }
        } else if (mode == 4) {
            uint8_t *raw = malloc((size_t)count + 1);
            if (bits_available(&reader) < 8 * count) {
                free(raw);
                return 0;
            }
            for (int index = 0; index < count; index++)
                raw[index] = (uint8_t)bits_read(&reader, 8);
            if (eci == 1 || eci == 3 || (eci < 0 && !valid_utf8(raw, (size_t)count))) {
                for (int index = 0; index < count; index++)
                    buffer_utf8(out, raw[index]);
            } else if (eci < 0 || eci == 26 || eci == 27) {
                buffer_append(out, (const char *)raw, (size_t)count);
            } else {
                append_converted(out, eci, raw, (size_t)count);
            }
            free(raw);
        } else {
            uint8_t *raw = malloc((size_t)count * 2 + 1);
            for (int index = 0; index < count; index++) {
                if (bits_available(&reader) < 13) {
                    free(raw);
                    return 0;
                }
                int value = bits_read(&reader, 13);
                unsigned assembled = (unsigned)(((value / 0xC0) << 8) | (value % 0xC0));
                assembled += assembled < 0x1F00 ? 0x8140 : 0xC140;
                raw[2 * index] = (uint8_t)(assembled >> 8);
                raw[2 * index + 1] = (uint8_t)assembled;
            }
            append_converted(out, 20, raw, (size_t)count * 2);
            free(raw);
        }
    }
    return 1;
}

static int read_bit(const Grid *grid, int x, int y, int mirror)
{
    return mirror ? grid_get(grid, y, x) : grid_get(grid, x, y);
}

static int copy_bit(const Grid *grid, int x, int y, int mirror, int bits)
{
    return (bits << 1) | (read_bit(grid, x, y, mirror) ? 1 : 0);
}

static int decode_grid(const Grid *grid, int mirror, Buffer *out, int *versionOut, int *levelOut)
{
    int size = grid->width;
    if (size < 21 || (size - 17) % 4 != 0)
        return 0;
    int version = (size - 17) / 4;
    int first = 0;
    for (int x = 0; x < 6; x++)
        first = copy_bit(grid, x, 8, mirror, first);
    first = copy_bit(grid, 7, 8, mirror, first);
    first = copy_bit(grid, 8, 8, mirror, first);
    first = copy_bit(grid, 8, 7, mirror, first);
    for (int y = 5; y >= 0; y--)
        first = copy_bit(grid, 8, y, mirror, first);
    int second = 0;
    for (int y = size - 1; y >= size - 7; y--)
        second = copy_bit(grid, 8, y, mirror, second);
    for (int x = size - 8; x < size; x++)
        second = copy_bit(grid, x, 8, mirror, second);
    int format = decode_format(first, second);
    if (format < 0)
        return 0;
    int level = level_for_bits[format >> 3], maskPattern = format & 7;
    if (version >= 7) {
        int versionFirst = 0, versionSecond = 0;
        for (int y = 5; y >= 0; y--) {
            for (int x = size - 9; x >= size - 11; x--)
                versionFirst = copy_bit(grid, x, y, mirror, versionFirst);
        }
        for (int x = 5; x >= 0; x--) {
            for (int y = size - 9; y >= size - 11; y--)
                versionSecond = copy_bit(grid, x, y, mirror, versionSecond);
        }
        int decoded = decode_version(versionFirst, versionSecond);
        if (decoded != version)
            return 0;
    }
    Grid functions;
    build_function_mask(version, &functions);
    int total = raw_codewords(version);
    uint8_t *codewords = calloc((size_t)total + 1, 1);
    int bitCount = 0, byteIndex = 0, current = 0, up = 1;
    for (int column = size - 1; column > 0; column -= 2) {
        if (column == 6)
            column--;
        for (int count = 0; count < size; count++) {
            int row = up ? size - 1 - count : count;
            for (int offset = 0; offset < 2; offset++) {
                int x = column - offset;
                if (grid_get(&functions, x, row))
                    continue;
                int bit = read_bit(grid, x, row, mirror) ? 1 : 0;
                if (data_mask_bit(maskPattern, row, x))
                    bit ^= 1;
                current = (current << 1) | bit;
                if (++bitCount == 8) {
                    if (byteIndex < total)
                        codewords[byteIndex] = (uint8_t)current;
                    byteIndex++;
                    bitCount = 0;
                    current = 0;
                }
            }
        }
        up = !up;
    }
    grid_free(&functions);
    if (byteIndex < total) {
        free(codewords);
        return 0;
    }
    int blocks = ecc_block_count[level][version], parity = ecc_codewords_per_block[level][version];
    int shortLength = total / blocks, shortCount = blocks - total % blocks;
    uint8_t *data = malloc((size_t)total);
    uint8_t **block = calloc((size_t)blocks, sizeof(uint8_t *));
    int *blockLength = calloc((size_t)blocks, sizeof(int));
    uint8_t **padded = calloc((size_t)blocks, sizeof(uint8_t *));
    for (int index = 0; index < blocks; index++) {
        blockLength[index] = shortLength + (index < shortCount ? 0 : 1);
        block[index] = malloc((size_t)blockLength[index]);
        padded[index] = calloc((size_t)shortLength + 1, 1);
    }
    int cursor = 0;
    for (int position = 0; position <= shortLength; position++) {
        for (int index = 0; index < blocks; index++) {
            if (position == shortLength - parity && index < shortCount)
                continue;
            padded[index][position] = codewords[cursor++];
        }
    }
    for (int index = 0; index < blocks; index++) {
        if (index < shortCount) {
            int dataLength = shortLength - parity;
            memcpy(block[index], padded[index], (size_t)dataLength);
            memcpy(block[index] + dataLength, padded[index] + dataLength + 1, (size_t)parity);
        } else {
            memcpy(block[index], padded[index], (size_t)shortLength + 1);
        }
        free(padded[index]);
    }
    free(padded);
    free(codewords);
    int ok = 1, produced = 0;
    for (int index = 0; index < blocks && ok; index++) {
        if (rs_correct(block[index], blockLength[index], parity) < 0) {
            ok = 0;
            break;
        }
        memcpy(data + produced, block[index], (size_t)(blockLength[index] - parity));
        produced += blockLength[index] - parity;
    }
    for (int index = 0; index < blocks; index++)
        free(block[index]);
    free(block);
    free(blockLength);
    if (ok)
        ok = parse_stream(data, (size_t)produced, version, out);
    free(data);
    if (ok) {
        *versionOut = version;
        *levelOut = level;
    }
    return ok;
}

static int sample_and_decode(const Grid *image, const Transform *transform, int dimension, int mirrorFirst, Buffer *out, int *versionOut, int *levelOut, int *mirroredOut)
{
    Grid sampled = grid_make(dimension, dimension);
    for (int y = 0; y < dimension; y++) {
        for (int x = 0; x < dimension; x++) {
            double px, py;
            if (!apply_transform(transform, x + 0.5, y + 0.5, &px, &py) || px < 0 || py < 0 || px >= image->width || py >= image->height) {
                grid_free(&sampled);
                return 0;
            }
            grid_set(&sampled, x, y, grid_get(image, (int)px, (int)py));
        }
    }
    int ok = decode_grid(&sampled, mirrorFirst, out, versionOut, levelOut);
    *mirroredOut = mirrorFirst;
    if (!ok) {
        free(out->bytes);
        *out = (Buffer){0};
        ok = decode_grid(&sampled, !mirrorFirst, out, versionOut, levelOut);
        *mirroredOut = !mirrorFirst;
    }
    grid_free(&sampled);
    return ok;
}

static int try_triple(const Grid *image, Pattern topLeft, Pattern topRight, Pattern bottomLeft, RevenantQRResult *result)
{
    float size = module_size(image, topLeft, topRight, bottomLeft);
    if (!(size >= 1.0f))
        return 0;
    int dimension;
    int across = (int)lroundf(point_distance(topLeft.x, topLeft.y, topRight.x, topRight.y) / size);
    int down = (int)lroundf(point_distance(topLeft.x, topLeft.y, bottomLeft.x, bottomLeft.y) / size);
    dimension = (across + down) / 2 + 7;
    switch (dimension & 3) {
    case 0:
        dimension++;
        break;
    case 2:
        dimension--;
        break;
    case 3:
        return 0;
    }
    if (dimension < 21 || dimension > 177)
        return 0;
    int version = (dimension - 17) / 4;
    float bottomRightX = topRight.x - topLeft.x + bottomLeft.x, bottomRightY = topRight.y - topLeft.y + bottomLeft.y;
    float correction = 1.0f - 3.0f / (float)(dimension - 7);
    float estimatedX = topLeft.x + correction * (bottomRightX - topLeft.x), estimatedY = topLeft.y + correction * (bottomRightY - topLeft.y);
    double modules = dimension - 3.5;
    double sourceBottomRight = modules;
    float realBottomRightX = bottomRightX, realBottomRightY = bottomRightY;
    if (version > 1) {
        float span = (float)(dimension - 7);
        float step[2][2] = {{(topRight.x - topLeft.x) / span, (topRight.y - topLeft.y) / span}, {(bottomLeft.x - topLeft.x) / span, (bottomLeft.y - topLeft.y) / span}};
        Pattern alignment;
        int found = 0;
        for (int factor = 4; factor <= 16 && !found; factor *= 2)
            found = find_alignment(image, estimatedX, estimatedY, size, (float)factor, step, &alignment);
        if (found) {
            realBottomRightX = alignment.x;
            realBottomRightY = alignment.y;
            sourceBottomRight = modules - 3;
        } else {
            realBottomRightX = estimatedX;
            realBottomRightY = estimatedY;
            sourceBottomRight = modules - 3;
        }
    }
    double source[4][2] = {{3.5, 3.5}, {modules, 3.5}, {sourceBottomRight, sourceBottomRight}, {3.5, modules}};
    double target[4][2] = {{topLeft.x, topLeft.y}, {topRight.x, topRight.y}, {realBottomRightX, realBottomRightY}, {bottomLeft.x, bottomLeft.y}};
    Transform transform;
    if (!solve_transform(source, target, &transform))
        return 0;
    Buffer out = {0};
    int decodedVersion = 0, level = 0, mirrored = 0;
    if (!sample_and_decode(image, &transform, dimension, 0, &out, &decodedVersion, &level, &mirrored)) {
        free(out.bytes);
        return 0;
    }
    result->undecodable = out.undecodable;
    if (out.undecodable) {
        free(out.bytes);
        out.bytes = NULL;
        out.length = 0;
    }
    result->text = out.bytes ? out.bytes : calloc(1, 1);
    result->length = out.length;
    result->version = decodedVersion;
    result->level = level;
    result->mirrored = mirrored;
    double corners[4][2] = {{0, 0}, {dimension, 0}, {dimension, dimension}, {0, dimension}};
    for (int index = 0; index < 4; index++) {
        double x = 0, y = 0;
        apply_transform(&transform, corners[index][0], corners[index][1], &x, &y);
        result->corners[index][0] = (float)x;
        result->corners[index][1] = (float)y;
    }
    return 1;
}

static void order_patterns(Pattern *a, Pattern *b, Pattern *c)
{
    float ab = point_distance(a->x, a->y, b->x, b->y), bc = point_distance(b->x, b->y, c->x, c->y), ac = point_distance(a->x, a->y, c->x, c->y);
    Pattern bottomLeft, topLeft, topRight;
    if (bc >= ab && bc >= ac) {
        topLeft = *a;
        bottomLeft = *b;
        topRight = *c;
    } else if (ac >= bc && ac >= ab) {
        topLeft = *b;
        bottomLeft = *a;
        topRight = *c;
    } else {
        topLeft = *c;
        bottomLeft = *a;
        topRight = *b;
    }
    float cross = (topRight.x - topLeft.x) * (bottomLeft.y - topLeft.y) - (topRight.y - topLeft.y) * (bottomLeft.x - topLeft.x);
    if (cross < 0) {
        Pattern swap = bottomLeft;
        bottomLeft = topRight;
        topRight = swap;
    }
    *a = bottomLeft;
    *b = topLeft;
    *c = topRight;
}

static int plausible(Pattern a, Pattern b, Pattern c)
{
    float ab = point_distance(a.x, a.y, b.x, b.y), bc = point_distance(b.x, b.y, c.x, c.y), ac = point_distance(a.x, a.y, c.x, c.y);
    float longest = fmaxf(ab, fmaxf(bc, ac));
    float other1, other2;
    if (longest == ab) {
        other1 = bc;
        other2 = ac;
    } else if (longest == bc) {
        other1 = ab;
        other2 = ac;
    } else {
        other1 = ab;
        other2 = bc;
    }
    if (other1 <= 0 || other2 <= 0)
        return 0;
    float ratio = other1 / other2;
    if (ratio < 0.5f || ratio > 2.0f)
        return 0;
    float expected = sqrtf(other1 * other1 + other2 * other2);
    if (fabsf(longest - expected) > 0.25f * expected)
        return 0;
    float low = fminf(a.size, fminf(b.size, c.size)), high = fmaxf(a.size, fmaxf(b.size, c.size));
    return high <= low * 1.8f;
}

static int already_used(const RevenantQRResult *results, int count, Pattern topLeft)
{
    for (int index = 0; index < count; index++) {
        float minX = results[index].corners[0][0], maxX = minX, minY = results[index].corners[0][1], maxY = minY;
        for (int corner = 1; corner < 4; corner++) {
            minX = fminf(minX, results[index].corners[corner][0]);
            maxX = fmaxf(maxX, results[index].corners[corner][0]);
            minY = fminf(minY, results[index].corners[corner][1]);
            maxY = fmaxf(maxY, results[index].corners[corner][1]);
        }
        if (topLeft.x >= minX && topLeft.x <= maxX && topLeft.y >= minY && topLeft.y <= maxY)
            return 1;
    }
    return 0;
}

static int decode_with(const Grid *image, RevenantQRResult *results, int capacity)
{
    PatternList list = {0};
    find_finder_patterns(image, &list);
    int usable[64], usableCount = 0;
    for (int pass = 0; pass < 2 && usableCount < 3; pass++) {
        usableCount = 0;
        for (int index = 0; index < list.count && usableCount < 64; index++) {
            if (list.items[index].count >= 2 - pass)
                usable[usableCount++] = index;
        }
    }
    for (int i = 0; i < usableCount; i++) {
        for (int j = i + 1; j < usableCount; j++) {
            if (list.items[usable[j]].count > list.items[usable[i]].count) {
                int swap = usable[i];
                usable[i] = usable[j];
                usable[j] = swap;
            }
        }
    }
    if (usableCount > 12)
        usableCount = 12;
    int found = 0;
    for (int i = 0; i < usableCount && found < capacity; i++) {
        for (int j = i + 1; j < usableCount && found < capacity; j++) {
            for (int k = j + 1; k < usableCount && found < capacity; k++) {
                Pattern a = list.items[usable[i]], b = list.items[usable[j]], c = list.items[usable[k]];
                if (!plausible(a, b, c))
                    continue;
                order_patterns(&a, &b, &c);
                if (already_used(results, found, b))
                    continue;
                RevenantQRResult result = {0};
                if (try_triple(image, b, c, a, &result))
                    results[found++] = result;
            }
        }
    }
    free(list.items);
    return found;
}

int revenant_qr_decode(const uint8_t *luma, int width, int height, int stride, RevenantQRResult *results, int capacity)
{
    if (!luma || width < 21 || height < 21 || capacity < 1)
        return 0;
    gf_init();
    int found = 0;
    Grid image;
    if (width >= 40 && height >= 40) {
        image = binarize_hybrid(luma, width, height, stride);
        found = decode_with(&image, results, capacity);
        grid_free(&image);
    }
    if (!found) {
        image = binarize_global(luma, width, height, stride);
        found = decode_with(&image, results, capacity);
        grid_free(&image);
    }
    return found;
}

static int revenant_qr_region_edge(float edge, int limit)
{
    if (!(edge > 0))
        return 0;
    if (edge >= (float)limit)
        return limit;
    return (int)edge;
}

int revenant_qr_decode_region(const uint8_t *luma, int width, int height, int stride, float x, float y, float regionWidth, float regionHeight, RevenantQRResult *results, int capacity)
{
    if (!luma || width < 1 || height < 1)
        return 0;
    int left = revenant_qr_region_edge(floorf(x * width), width);
    int top = revenant_qr_region_edge(floorf(y * height), height);
    int right = revenant_qr_region_edge(ceilf((x + regionWidth) * width), width);
    int bottom = revenant_qr_region_edge(ceilf((y + regionHeight) * height), height);
    if (right <= left || bottom <= top)
        return 0;
    int found = revenant_qr_decode(luma + (size_t)top * stride + left, right - left, bottom - top, stride, results, capacity);
    for (int index = 0; index < found; index++)
        for (int corner = 0; corner < 4; corner++) {
            results[index].corners[corner][0] += (float)left;
            results[index].corners[corner][1] += (float)top;
        }
    return found;
}

void revenant_qr_result_free(RevenantQRResult *result)
{
    free(result->text);
    result->text = NULL;
    result->length = 0;
}
