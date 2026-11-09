#ifndef REVENANT_DOCUMENT_LIVE_H
#define REVENANT_DOCUMENT_LIVE_H

#include <stddef.h>
#include <stdint.h>

#include "RevenantDocumentWarp.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    RevenantDocumentPoint corners[4];
} RevenantDocumentQuad;

int RevenantDocumentLuminance(const uint8_t *plane, size_t width, size_t height, size_t row_bytes, unsigned quarter_turns,
                              size_t maximum_side, uint8_t *output, size_t *output_width, size_t *output_height);

int RevenantDocumentLuminanceRGBA(const uint8_t *pixels, size_t width, size_t height, size_t row_bytes, size_t maximum_side,
                                  uint8_t *output, size_t *output_width, size_t *output_height);

int RevenantDocumentFindQuad(const uint8_t *luminance, size_t width, size_t height, size_t row_bytes,
                             const RevenantDocumentQuad *near, RevenantDocumentQuad *quad);

double RevenantDocumentQuadDistance(const RevenantDocumentQuad *a, const RevenantDocumentQuad *b);

double RevenantDocumentQuadArea(const RevenantDocumentQuad *quad);

typedef struct {
    RevenantDocumentQuad anchor;
    double since;
    double lost_since;
    int has_anchor;
    int armed;
} RevenantDocumentTracker;

void RevenantDocumentTrackerReset(RevenantDocumentTracker *tracker);
int RevenantDocumentTrackerUpdate(RevenantDocumentTracker *tracker, const RevenantDocumentQuad *quad, double now, double hold);
void RevenantDocumentTrackerCaptured(RevenantDocumentTracker *tracker);

#ifdef __cplusplus
}
#endif

#endif
