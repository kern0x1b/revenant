#ifndef REVENANT_VN_RECTANGLE_DETECTOR_INTERNAL_H
#define REVENANT_VN_RECTANGLE_DETECTOR_INTERNAL_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

void RevenantVisionEdgeMap(const uint8_t *luminance, size_t width, size_t height, unsigned low_threshold, unsigned high_threshold,
                           uint8_t *magnitude, uint8_t *edge);

void RevenantVisionEdgeMapScalar(const uint8_t *luminance, size_t width, size_t height, unsigned low_threshold, unsigned high_threshold,
                                 uint8_t *magnitude, uint8_t *edge);

#ifdef __cplusplus
}
#endif

#endif
