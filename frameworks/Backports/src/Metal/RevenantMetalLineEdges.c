#include "RevenantMetalLineEdges.h"

size_t RevenantMetalTriangleEdges(int strip, const uint32_t *stream, size_t count, uint32_t *edges)
{
    size_t written = 0;
    for (size_t i = 0;; i++) {
        size_t reach = strip ? i + 3 : 3 * i + 3;
        if (reach > count)
            break;
        uint32_t a, b, c;
        if (strip) {
            a = stream[i];
            b = stream[i + 1];
            c = stream[i + 2];
        } else {
            a = stream[3 * i];
            b = stream[3 * i + 1];
            c = stream[3 * i + 2];
        }
        edges[written++] = a;
        edges[written++] = b;
        edges[written++] = b;
        edges[written++] = c;
        edges[written++] = c;
        edges[written++] = a;
    }
    return written;
}
