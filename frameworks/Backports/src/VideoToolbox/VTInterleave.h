#ifndef REVENANT_VT_INTERLEAVE_H
#define REVENANT_VT_INTERLEAVE_H

#include <stddef.h>
#include <stdint.h>

__attribute__((visibility("hidden"))) void RevenantVTCopyPlane(uint8_t *out, size_t outStride, const uint8_t *in, size_t inStride, size_t width, size_t height);
__attribute__((visibility("hidden"))) void RevenantVTInterleaveChromaScalar(uint8_t *out, size_t outStride, const uint8_t *blue, size_t blueStride, const uint8_t *red, size_t redStride, size_t width, size_t height);

#if defined(__ARM_NEON)
__attribute__((visibility("hidden"))) void RevenantVTInterleaveChromaNEON(uint8_t *out, size_t outStride, const uint8_t *blue, size_t blueStride, const uint8_t *red, size_t redStride, size_t width, size_t height);
#endif

#endif
