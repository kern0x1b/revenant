#import <CoreVideo/CoreVideo.h>
#import <Metal/Metal.h>
#import <dispatch/dispatch.h>
#import "../RevenantCFRuntime.h"
#import "../Metal/RevenantMetal.h"

// A CVMetalTextureCache is a CoreFoundation object over the OpenGL ES texture cache of the Metal device, and a
// CVMetalTexture is one plane of a pixel buffer as a RevenantMetalTexture. Both are retained and released like the
// other CoreVideo references; the GL texture itself is owned and released by RevenantMetalTexture.

struct RevenantCVMetalTextureCacheState {
    void *device;
};

struct RevenantCVMetalTextureState {
    void *texture;
};

static struct RevenantCVMetalTextureCacheState *revenant_cv_metal_cache_state(CFTypeRef cf)
{
    return (struct RevenantCVMetalTextureCacheState *)((uint8_t *)cf + sizeof(RevenantCFRuntimeBase));
}

static struct RevenantCVMetalTextureState *revenant_cv_metal_texture_state(CFTypeRef cf)
{
    return (struct RevenantCVMetalTextureState *)((uint8_t *)cf + sizeof(RevenantCFRuntimeBase));
}

static void revenant_cv_metal_cache_finalize(CFTypeRef cf)
{
    struct RevenantCVMetalTextureCacheState *state = revenant_cv_metal_cache_state(cf);
    if (state->device) {
        id device = (__bridge_transfer id)state->device;
        state->device = NULL;
        (void)device;
    }
}

static void revenant_cv_metal_texture_finalize(CFTypeRef cf)
{
    struct RevenantCVMetalTextureState *state = revenant_cv_metal_texture_state(cf);
    if (state->texture) {
        id texture = (__bridge_transfer id)state->texture;
        state->texture = NULL;
        (void)texture;
    }
}

static CFTypeID revenant_cv_metal_cache_type(void)
{
    static CFTypeID typeID;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        static const RevenantCFRuntimeClass cacheClass = {
            .version = 0,
            .className = "CVMetalTextureCache",
            .finalize = revenant_cv_metal_cache_finalize,
        };
        typeID = _CFRuntimeRegisterClass(&cacheClass);
    });
    return typeID;
}

static CFTypeID revenant_cv_metal_texture_type(void)
{
    static CFTypeID typeID;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        static const RevenantCFRuntimeClass textureClass = {
            .version = 0,
            .className = "CVMetalTexture",
            .finalize = revenant_cv_metal_texture_finalize,
        };
        typeID = _CFRuntimeRegisterClass(&textureClass);
    });
    return typeID;
}

static BOOL revenant_cv_metal_is_cache(CVMetalTextureCacheRef cache)
{
    return cache && CFGetTypeID((CFTypeRef)cache) == revenant_cv_metal_cache_type();
}

static BOOL revenant_cv_metal_is_texture(CVMetalTextureRef image)
{
    return image && CFGetTypeID((CFTypeRef)image) == revenant_cv_metal_texture_type();
}

static RevenantMetalTexture *revenant_cv_metal_texture_object(CVMetalTextureRef image)
{
    if (!revenant_cv_metal_is_texture(image))
        return nil;
    return (__bridge RevenantMetalTexture *)revenant_cv_metal_texture_state((CFTypeRef)image)->texture;
}

CVReturn CVMetalTextureCacheCreate(CFAllocatorRef allocator, CFDictionaryRef cacheAttributes,
                                    id <MTLDevice> metalDevice, CFDictionaryRef textureAttributes,
                                    CVMetalTextureCacheRef *cacheOut)
{
    if (cacheOut)
        *cacheOut = NULL;
    if (!cacheOut || ![metalDevice isKindOfClass:[RevenantMetalDevice class]])
        return kCVReturnInvalidArgument;
    CFTypeRef object = _CFRuntimeCreateInstance(allocator, revenant_cv_metal_cache_type(), sizeof(struct RevenantCVMetalTextureCacheState), NULL);
    if (!object)
        return kCVReturnAllocationFailed;
    revenant_cv_metal_cache_state(object)->device = (__bridge_retained void *)metalDevice;
    *cacheOut = (CVMetalTextureCacheRef)object;
    return kCVReturnSuccess;
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
    if (!textureOut || !revenant_cv_metal_is_cache(textureCache) || !sourceImage)
        return kCVReturnInvalidArgument;
    RevenantMetalDevice *device = (__bridge RevenantMetalDevice *)revenant_cv_metal_cache_state((CFTypeRef)textureCache)->device;
    CVReturn status = kCVReturnSuccess;
    RevenantMetalTexture *texture = [RevenantMetalTexture revenantTextureFromImage:sourceImage device:device pixelFormat:pixelFormat width:width height:height plane:planeIndex status:&status];
    if (!texture)
        return status;
    CFTypeRef object = _CFRuntimeCreateInstance(allocator, revenant_cv_metal_texture_type(), sizeof(struct RevenantCVMetalTextureState), NULL);
    if (!object)
        return kCVReturnAllocationFailed;
    revenant_cv_metal_texture_state(object)->texture = (__bridge_retained void *)texture;
    *textureOut = (CVMetalTextureRef)object;
    return kCVReturnSuccess;
}

void CVMetalTextureCacheFlush(CVMetalTextureCacheRef textureCache, CVOptionFlags options)
{
    if (!revenant_cv_metal_is_cache(textureCache))
        return;
    RevenantMetalDevice *device = (__bridge RevenantMetalDevice *)revenant_cv_metal_cache_state((CFTypeRef)textureCache)->device;
    [device acquire];
    CVOpenGLESTextureCacheRef glCache = [device textureCache];
    if (glCache)
        CVOpenGLESTextureCacheFlush(glCache, options);
    [device relinquish];
}

id <MTLTexture> CVMetalTextureGetTexture(CVMetalTextureRef image)
{
    return revenant_cv_metal_texture_object(image);
}

CFTypeID CVMetalTextureCacheGetTypeID(void)
{
    return revenant_cv_metal_cache_type();
}

CFTypeID CVMetalTextureGetTypeID(void)
{
    return revenant_cv_metal_texture_type();
}

Boolean CVMetalTextureIsFlipped(CVMetalTextureRef image)
{
    CVOpenGLESTextureRef surface = [revenant_cv_metal_texture_object(image) revenantOpenGLESTexture];
    return surface ? CVOpenGLESTextureIsFlipped(surface) : false;
}

void CVMetalTextureGetCleanTexCoords(CVMetalTextureRef image,
                                     float lowerLeft[2], float lowerRight[2],
                                     float upperRight[2], float upperLeft[2])
{
    float coords[8] = {0.0f, 0.0f, 1.0f, 0.0f, 1.0f, 1.0f, 0.0f, 1.0f};
    CVOpenGLESTextureRef surface = [revenant_cv_metal_texture_object(image) revenantOpenGLESTexture];
    if (surface)
        CVOpenGLESTextureGetCleanTexCoords(surface, coords, coords + 2, coords + 4, coords + 6);
    if (lowerLeft) { lowerLeft[0] = coords[0]; lowerLeft[1] = coords[1]; }
    if (lowerRight) { lowerRight[0] = coords[2]; lowerRight[1] = coords[3]; }
    if (upperRight) { upperRight[0] = coords[4]; upperRight[1] = coords[5]; }
    if (upperLeft) { upperLeft[0] = coords[6]; upperLeft[1] = coords[7]; }
}
