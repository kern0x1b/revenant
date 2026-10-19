#import <Accelerate/Accelerate.h>
#import <CoreGraphics/CoreGraphics.h>
#include <stdlib.h>
#include <string.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"

static const vImage_Flags charon_init_flags = kvImageNoAllocate | kvImagePrintDiagnosticsToConsole;

vImage_Error vImageBuffer_Init(vImage_Buffer *buf, vImagePixelCount height, vImagePixelCount width, uint32_t pixelBits, vImage_Flags flags)
{
    if (flags & ~charon_init_flags)
        return kvImageUnknownFlagsBit;
    size_t bytes = 0;
    if (width && pixelBits) {
        unsigned long long bits = (unsigned long long)width * pixelBits;
        if (bits / pixelBits != width || bits > 0xFFFFFFFFull * 8)
            return kvImageMemoryAllocationError;
        bytes = (size_t)((bits + 7) / 8);
    }
    size_t rowBytes = bytes ? (bytes + 15) & ~(size_t)15 : 0;
    if (bytes && rowBytes < bytes)
        return kvImageMemoryAllocationError;
    if (flags & kvImageNoAllocate) {
        buf->height = height;
        buf->width = width;
        buf->rowBytes = rowBytes;
        return 16;
    }
    unsigned long long total = (unsigned long long)rowBytes * height;
    if (rowBytes && total / rowBytes != height)
        return kvImageMemoryAllocationError;
    if (total > (size_t)-1 / 2)
        return kvImageMemoryAllocationError;
    void *data = NULL;
    if (posix_memalign(&data, 64, total ? (size_t)total : 1) != 0 || !data)
        return kvImageMemoryAllocationError;
    buf->data = data;
    buf->height = height;
    buf->width = width;
    buf->rowBytes = rowBytes;
    return kvImageNoError;
}
