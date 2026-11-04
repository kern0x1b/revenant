#ifndef REVENANT_MPS_BILINEAR_H
#define REVENANT_MPS_BILINEAR_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    double scaleX, scaleY, translateX, translateY;
} RevenantMPSBilinearTransform;

enum {
    RevenantMPSBilinearEdgeZero = 0,
    RevenantMPSBilinearEdgeClamp = 1,
};

int RevenantMPSBilinearResample(const float *source, size_t sourceWidth, size_t sourceHeight, size_t channels,
                                int edgeMode, RevenantMPSBilinearTransform transform,
                                float *output, size_t originX, size_t originY, size_t width, size_t height);

#ifdef __cplusplus
}
#endif

#endif
