#ifndef REVENANT_VN_RECTANGLE_DETECTOR_H
#define REVENANT_VN_RECTANGLE_DETECTOR_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    float x;
    float y;
} RevenantVisionPoint;

typedef struct {
    RevenantVisionPoint corners[4];
    float confidence;
    float aspect_ratio;
    float size;
} RevenantVisionRectangle;

typedef struct {
    float minimum_aspect_ratio;
    float maximum_aspect_ratio;
    float quadrature_tolerance;
    float minimum_size;
    float minimum_confidence;
    size_t maximum_observations;
} RevenantVisionRectangleOptions;

void RevenantVisionEdgeMap(const uint8_t *luminance, size_t width, size_t height, unsigned low_threshold, unsigned high_threshold,
                           uint8_t *magnitude, uint8_t *edge, int scalar_only);

size_t RevenantVisionDetectRectangles(const uint8_t *luminance, size_t width, size_t height, size_t row_bytes,
                                      RevenantVisionRectangleOptions options,
                                      RevenantVisionRectangle *output, size_t capacity);

#ifdef __cplusplus
}
#endif

#endif
