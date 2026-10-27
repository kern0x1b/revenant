#ifndef REVENANT_VT_DECODE_HEVC_H
#define REVENANT_VT_DECODE_HEVC_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef struct RevenantVTHEVCDecoder RevenantVTHEVCDecoder;

typedef enum {
    RevenantVTHEVCOK = 0,
    RevenantVTHEVCNoDecoder,
    RevenantVTHEVCBadData,
    RevenantVTHEVCUnsupportedFormat,
    RevenantVTHEVCOutOfMemory,
    RevenantVTHEVCMalfunction,
    RevenantVTHEVCBusy,
} RevenantVTHEVCResult;

typedef enum {
    RevenantVTHEVCMatrixUnspecified = 0,
    RevenantVTHEVCMatrixBT601,
    RevenantVTHEVCMatrixBT709,
} RevenantVTHEVCMatrix;

typedef struct {
    int64_t sequence;
    int width;
    int height;
    const uint8_t *luma;
    size_t lumaStride;
    const uint8_t *chromaBlue;
    size_t chromaBlueStride;
    const uint8_t *chromaRed;
    size_t chromaRedStride;
    bool fullRange;
    RevenantVTHEVCMatrix matrix;
} RevenantVTHEVCPicture;

typedef void (*RevenantVTHEVCSink)(void *context, const RevenantVTHEVCPicture *picture);

__attribute__((visibility("hidden"))) RevenantVTHEVCDecoder *RevenantVTHEVCDecoderCreate(const uint8_t *configuration, size_t size, int threads, RevenantVTHEVCResult *result);
__attribute__((visibility("hidden"))) RevenantVTHEVCResult RevenantVTHEVCDecoderDecode(RevenantVTHEVCDecoder *decoder, const uint8_t *data, size_t size, int64_t sequence, RevenantVTHEVCSink sink, void *context);
__attribute__((visibility("hidden"))) RevenantVTHEVCResult RevenantVTHEVCDecoderWait(RevenantVTHEVCDecoder *decoder, RevenantVTHEVCSink sink, void *context);
__attribute__((visibility("hidden"))) RevenantVTHEVCResult RevenantVTHEVCDecoderFinish(RevenantVTHEVCDecoder *decoder, RevenantVTHEVCSink sink, void *context);
__attribute__((visibility("hidden"))) void RevenantVTHEVCDecoderDestroy(RevenantVTHEVCDecoder *decoder);

#endif
