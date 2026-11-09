#ifndef REVENANT_DOCUMENT_WARP_H
#define REVENANT_DOCUMENT_WARP_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    float x;
    float y;
} RevenantDocumentPoint;

typedef struct {
    size_t width;
    size_t height;
} RevenantDocumentSize;

RevenantDocumentSize RevenantDocumentOutputSize(const RevenantDocumentPoint quad[4], size_t maximum_side);

int RevenantDocumentWarp(const uint8_t *source, size_t source_width, size_t source_height, size_t source_row_bytes,
                         const RevenantDocumentPoint quad[4], uint8_t *output, size_t output_width, size_t output_height,
                         size_t output_row_bytes);

#ifdef __cplusplus
}
#endif

#endif
