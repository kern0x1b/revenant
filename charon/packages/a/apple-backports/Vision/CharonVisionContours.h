/* The contour tracer behind VNDetectContoursRequest: the boundaries of a binary picture, as chains of unit edges.
 *
 * A header of static functions, and not a .m, for the reason CharonVisionImage.h is one: a C function two files share
 * would be exported from the dylib, and the registry owes an entry for every exported name.
 *
 * What the tracer answers, as the host's VNDetectContoursRequest does for a binary picture (tests/backports/host/
 * vision-contours14 measures it):
 *   - the foreground is the set of pixels the caller marks, joined to its neighbours through all eight; the background is
 *     joined through four, and the picture is padded with background all round, so a foreground region that reaches an edge
 *     of the picture is bounded by the edge too;
 *   - a contour is the boundary of one region, traced as the chain of unit edges that separates it from the background,
 *     with the foreground on the left of the walk; its points are the midpoints of those edges, in pixel units, the walk
 *     starting on the outgoing edge of the region's bottom-right vertex;
 *   - an outer contour bounds a foreground region and a hole bounds a background region inside one; each hole is a child of
 *     the smallest contour that encloses it, and siblings are listed in the raster order of a pixel they enclose. */
#ifndef CHARON_VISION_CONTOURS_H
#define CHARON_VISION_CONTOURS_H

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    int count;       /* the number of unit edges, which is the number of points */
    int *vx, *vy;   /* the start vertex of each edge, in walk order */
    int *dir;        /* the direction of each edge: 0 east, 1 south, 2 west, 3 north */
    int outer;       /* 1 when the contour bounds a foreground region, 0 for a hole */
    int parent;      /* the index of the enclosing contour, or -1 */
    int sampleX, sampleY; /* a pixel the contour encloses, on the side its own region is on: the raster order of siblings */
} charon_contour;

static const int charon_contour_dx[4] = {1, 0, -1, 0};
static const int charon_contour_dy[4] = {0, 1, 0, -1};

/* The two pixels either side of the unit edge that starts at (vx, vy) and points along dir: the left one is on the walk's left. */
static inline void charon_contour_sides(int vx, int vy, int dir, int *lx, int *ly, int *rx, int *ry)
{
    switch (dir) {
    case 0: /* east: the pixel above is on the left */
        *lx = vx; *ly = vy - 1; *rx = vx; *ry = vy;
        break;
    case 1: /* south: the pixel to the east is on the left */
        *lx = vx; *ly = vy; *rx = vx - 1; *ry = vy;
        break;
    case 2: /* west: the pixel below is on the left */
        *lx = vx - 1; *ly = vy; *rx = vx - 1; *ry = vy - 1;
        break;
    default: /* north: the pixel to the west is on the left */
        *lx = vx - 1; *ly = vy - 1; *rx = vx; *ry = vy - 1;
        break;
    }
}

static inline int charon_contour_fg(const uint8_t *fg, int wide, int high, int x, int y)
{
    return x >= 0 && y >= 0 && x < wide && y < high && fg[y * wide + x] != 0;
}

/* An edge is on a contour when the foreground is on its left and the background on its right. */
static inline int charon_contour_edge(const uint8_t *fg, int wide, int high, int vx, int vy, int dir)
{
    int lx, ly, rx, ry;
    charon_contour_sides(vx, vy, dir, &lx, &ly, &rx, &ry);
    return charon_contour_fg(fg, wide, high, lx, ly) && !charon_contour_fg(fg, wide, high, rx, ry);
}

/* Midpoints of the edges, in pixel units, for the point-in-contour test and the output. */
static inline void charon_contour_midpoint(const charon_contour *contour, int index, double *x, double *y)
{
    double vx = contour->vx[index], vy = contour->vy[index];
    switch (contour->dir[index]) {
    case 0: *x = vx + 0.5; *y = vy; break;
    case 1: *x = vx; *y = vy + 0.5; break;
    case 2: *x = vx - 0.5; *y = vy; break;
    default: *x = vx; *y = vy - 0.5; break;
    }
}

/* Whether the point lies inside the contour's midpoint polygon. The points of a pixel centre are never on that polygon, because
 * its segments run on whole-number lines and a pixel centre has half-number coordinates on both axes. */
static inline int charon_contour_encloses(const charon_contour *contour, double px, double py)
{
    int inside = 0;
    int n = contour->count;
    for (int i = 0; i < n; i++) {
        double ax, ay, bx, by;
        charon_contour_midpoint(contour, i, &ax, &ay);
        charon_contour_midpoint(contour, (i + 1) % n, &bx, &by);
        if ((ay > py) != (by > py) && px < (bx - ax) * (py - ay) / (by - ay) + ax)
            inside = !inside;
    }
    return inside;
}

static inline double charon_contour_area(const charon_contour *contour)
{
    double sum = 0;
    for (int i = 0; i < contour->count; i++) {
        double ax, ay, bx, by;
        charon_contour_midpoint(contour, i, &ax, &ay);
        charon_contour_midpoint(contour, (i + 1) % contour->count, &bx, &by);
        sum += ax * by - bx * ay;
    }
    return sum < 0 ? -sum / 2 : sum / 2;
}

/* Traces every contour of the picture. fg holds one byte per pixel, nonzero for foreground. The result is malloc'd (free the
 * array and each contour's vx, vy and dir), and *count is its length; a picture with no foreground has no contours. */
static inline charon_contour *charon_contours_trace(const uint8_t *fg, int wide, int high, int *count)
{
    int vertices = (wide + 1) * (high + 1);
    uint8_t *used = calloc(4 * (size_t)vertices, 1);
    charon_contour *out = NULL;
    int capacity = 0;
    int n = 0;

    *count = 0;
    if (used == NULL)
        return NULL;
    for (int vy = 0; vy <= high; vy++) {
        for (int vx = 0; vx <= wide; vx++) {
            for (int start = 0; start < 4; start++) {
                if (used[start * vertices + vy * (wide + 1) + vx] || !charon_contour_edge(fg, wide, high, vx, vy, start))
                    continue;
                /* walk the contour from this edge: at each vertex take the left turn if it is an edge of the contour, else
                 * straight on, else the right turn */
                int cap = 64, length = 0;
                int *ex = malloc(sizeof(int) * cap), *ey = malloc(sizeof(int) * cap), *ed = malloc(sizeof(int) * cap);
                int x = vx, y = vy, d = start;
                do {
                    if (length == cap) {
                        cap *= 2;
                        ex = realloc(ex, sizeof(int) * cap);
                        ey = realloc(ey, sizeof(int) * cap);
                        ed = realloc(ed, sizeof(int) * cap);
                    }
                    used[d * vertices + y * (wide + 1) + x] = 1;
                    ex[length] = x; ey[length] = y; ed[length] = d;
                    length++;
                    int nx = x + charon_contour_dx[d], ny = y + charon_contour_dy[d];
                    int candidates[3] = {(d + 1) % 4, d, (d + 3) % 4};
                    int next = -1;
                    for (int k = 0; k < 3 && next < 0; k++)
                        if (charon_contour_edge(fg, wide, high, nx, ny, candidates[k]))
                            next = candidates[k];
                    if (next < 0)
                        break;
                    x = nx; y = ny; d = next;
                } while (!(x == vx && y == vy && d == start));

                /* rotate so the walk starts on the outgoing edge of the bottom-right vertex: the largest y, then the largest x */
                int first = 0;
                for (int i = 1; i < length; i++)
                    if (ey[i] > ey[first] || (ey[i] == ey[first] && ex[i] > ex[first]))
                        first = i;
                charon_contour c;
                c.count = length;
                c.vx = malloc(sizeof(int) * length);
                c.vy = malloc(sizeof(int) * length);
                c.dir = malloc(sizeof(int) * length);
                for (int i = 0; i < length; i++) {
                    c.vx[i] = ex[(first + i) % length];
                    c.vy[i] = ey[(first + i) % length];
                    c.dir[i] = ed[(first + i) % length];
                }
                free(ex); free(ey); free(ed);
                /* a contour that bounds a foreground region has its foreground on the left: its area's sign says which kind it is */
                double signedSum = 0;
                for (int i = 0; i < length; i++) {
                    int j = (i + 1) % length;
                    signedSum += (double)c.vx[i] * c.vy[j] - (double)c.vx[j] * c.vy[i];
                }
                c.outer = signedSum < 0;
                c.parent = -1;
                {
                    int lx, ly, rx, ry;
                    charon_contour_sides(c.vx[0], c.vy[0], c.dir[0], &lx, &ly, &rx, &ry);
                    if (c.outer) {
                        c.sampleX = lx; c.sampleY = ly;
                    } else {
                        c.sampleX = rx; c.sampleY = ry;
                    }
                }
                if (n == capacity) {
                    capacity = capacity ? capacity * 2 : 16;
                    out = realloc(out, sizeof(charon_contour) * capacity);
                }
                out[n++] = c;
            }
        }
    }
    free(used);
    /* the parent of each contour is the smallest contour that encloses the pixel it sits on */
    for (int i = 0; i < n; i++) {
        double best = -1;
        for (int j = 0; j < n; j++) {
            if (j == i || !charon_contour_encloses(&out[j], out[i].sampleX + 0.5, out[i].sampleY + 0.5))
                continue;
            double area = charon_contour_area(&out[j]);
            if (best < 0 || area < best) {
                best = area;
                out[i].parent = j;
            }
        }
    }
    *count = n;
    return out;
}

#endif /* CHARON_VISION_CONTOURS_H */
