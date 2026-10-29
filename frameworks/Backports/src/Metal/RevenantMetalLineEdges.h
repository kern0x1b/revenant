#ifndef REVENANT_METAL_LINE_EDGES_H
#define REVENANT_METAL_LINE_EDGES_H

#include <stddef.h>
#include <stdint.h>

size_t RevenantMetalTriangleEdges(int strip, const uint32_t *stream, size_t count, uint32_t *edges);

#endif
