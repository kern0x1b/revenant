#ifndef REVENANT_VT_CONVERT_BIPLANAR_H
#define REVENANT_VT_CONVERT_BIPLANAR_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

void RevenantVTConvertBiPlanarScalar(uint8_t *out, size_t rowBytes, const uint8_t *luma, size_t lumaStride, const uint8_t *chroma, size_t chromaStride, size_t width, size_t height, bool fullRange, bool bt709);

#if defined(__ARM_NEON)
void RevenantVTConvertBiPlanarNEON(uint8_t *out, size_t rowBytes, const uint8_t *luma, size_t lumaStride, const uint8_t *chroma, size_t chromaStride, size_t width, size_t height, bool fullRange, bool bt709);
#endif

#endif
