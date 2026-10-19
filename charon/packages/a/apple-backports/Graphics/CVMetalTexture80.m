#import <CoreVideo/CoreVideo.h>
#import <Metal/Metal.h>

CVReturn CVMetalTextureCacheCreate(CFAllocatorRef allocator, CFDictionaryRef cacheAttributes,
                                    id <MTLDevice> metalDevice, CFDictionaryRef textureAttributes,
                                    CVMetalTextureCacheRef *cacheOut)
{
    if (cacheOut)
        *cacheOut = NULL;
    return kCVReturnInvalidArgument;
}

CVReturn CVMetalTextureCacheCreateTextureFromImage(CFAllocatorRef allocator,
                                                    CVMetalTextureCacheRef textureCache,
                                                    CVImageBufferRef sourceImage,
                                                    CFDictionaryRef textureAttributes,
                                                    MTLPixelFormat pixelFormat,
                                                    size_t width, size_t height, size_t planeIndex,
                                                    CVMetalTextureRef *textureOut)
{
    if (textureOut)
        *textureOut = NULL;
    return kCVReturnInvalidArgument;
}

void CVMetalTextureCacheFlush(CVMetalTextureCacheRef textureCache, CVOptionFlags options)
{
}

id <MTLTexture> CVMetalTextureGetTexture(CVMetalTextureRef image)
{
    return nil;
}

CFTypeID CVMetalTextureCacheGetTypeID(void)
{
    return 0;
}

CFTypeID CVMetalTextureGetTypeID(void)
{
    return 0;
}

Boolean CVMetalTextureIsFlipped(CVMetalTextureRef image)
{
    return false;
}

void CVMetalTextureGetCleanTexCoords(CVMetalTextureRef image,
                                     float lowerLeft[2], float lowerRight[2],
                                     float upperRight[2], float upperLeft[2])
{
    if (lowerLeft) { lowerLeft[0] = 0.0f; lowerLeft[1] = 0.0f; }
    if (lowerRight) { lowerRight[0] = 0.0f; lowerRight[1] = 0.0f; }
    if (upperRight) { upperRight[0] = 0.0f; upperRight[1] = 0.0f; }
    if (upperLeft) { upperLeft[0] = 0.0f; upperLeft[1] = 0.0f; }
}
