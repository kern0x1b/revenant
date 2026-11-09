#import <CoreFoundation/CoreFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreImage/CoreImage.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <QuartzCore/QuartzCore.h>
#import <dlfcn.h>
#import <objc/message.h>
#import "check.h"

typedef CFTypeRef IOSurfaceHandle;

static const char *revenant_names[] = {
    "IOSurfaceAlignProperty", "IOSurfaceAllowsPixelSizeCasting", "IOSurfaceCopyAllValues", "IOSurfaceCopyValue", "IOSurfaceCreate",
    "IOSurfaceCreateMachPort", "IOSurfaceCreatePort", "IOSurfaceDecrementUseCount", "IOSurfaceGetAllocSize", "IOSurfaceGetBaseAddress",
    "IOSurfaceGetBaseAddressOfPlane", "IOSurfaceGetBitDepthOfComponentOfPlane", "IOSurfaceGetBitOffsetOfComponentOfPlane",
    "IOSurfaceGetBytesPerElement", "IOSurfaceGetBytesPerElementOfPlane", "IOSurfaceGetBytesPerRow", "IOSurfaceGetBytesPerRowOfPlane",
    "IOSurfaceGetElementHeight", "IOSurfaceGetElementHeightOfPlane", "IOSurfaceGetElementWidth", "IOSurfaceGetElementWidthOfPlane",
    "IOSurfaceGetHeight", "IOSurfaceGetHeightOfPlane", "IOSurfaceGetID", "IOSurfaceGetNameOfComponentOfPlane",
    "IOSurfaceGetNumberOfComponentsOfPlane", "IOSurfaceGetPixelFormat", "IOSurfaceGetPlaneCount", "IOSurfaceGetPropertyAlignment",
    "IOSurfaceGetPropertyMaximum", "IOSurfaceGetRangeOfComponentOfPlane", "IOSurfaceGetSeed", "IOSurfaceGetSubsampling",
    "IOSurfaceGetTypeID", "IOSurfaceGetTypeOfComponentOfPlane", "IOSurfaceGetUseCount", "IOSurfaceGetWidth", "IOSurfaceGetWidthOfPlane",
    "IOSurfaceIncrementUseCount", "IOSurfaceIsInUse", "IOSurfaceLock", "IOSurfaceLookup", "IOSurfaceLookupFromMachPort",
    "IOSurfaceRemoveAllValues", "IOSurfaceRemoveValue", "IOSurfaceSetOwnershipIdentity", "IOSurfaceSetPurgeable", "IOSurfaceSetValue",
    "IOSurfaceSetValues", "IOSurfaceUnlock", "IOSurfaceFlushProcessCaches", "IOSurfaceGetPlaneCount", "IOSurfaceSetCacheMode",
    "IOSurfaceGetCacheMode", "IOSurfaceCreateWithProperties", "IOSurfaceGetPurgeable", "IOSurfaceGetLockCount", "IOSurfaceGetModificationSeed",
    "IOSurfaceLookupAndLock", "IOSurfaceGetUserClient", "IOSurfaceMemoryRegion", "IOSurfaceCopyPurgeable"
};

static const char *revenant_constants[] = {
    "kIOSurfaceAllocSize", "kIOSurfaceBytesPerElement", "kIOSurfaceBytesPerRow", "kIOSurfaceCacheMode", "kIOSurfaceColorSpace",
    "kIOSurfaceElementHeight", "kIOSurfaceElementWidth", "kIOSurfaceHeight", "kIOSurfaceIsGlobal", "kIOSurfaceName", "kIOSurfaceOffset",
    "kIOSurfacePixelFormat", "kIOSurfacePlaneBase", "kIOSurfacePlaneBitsPerElement", "kIOSurfacePlaneBytesPerElement",
    "kIOSurfacePlaneBytesPerRow", "kIOSurfacePlaneElementHeight", "kIOSurfacePlaneElementWidth", "kIOSurfacePlaneHeight",
    "kIOSurfacePlaneInfo", "kIOSurfacePlaneOffset", "kIOSurfacePlaneSize", "kIOSurfacePlaneWidth", "kIOSurfaceWidth",
    "kIOSurfaceSubsampling", "kIOSurfaceICCProfile", "kIOSurfacePixelSizeCastingAllowed", "kIOSurfacePlaneComponentBitDepths"
};

typedef IOSurfaceHandle (*CreateFn)(CFDictionaryRef);
typedef int (*LockFn)(IOSurfaceHandle, uint32_t, uint32_t *);
typedef void *(*BaseFn)(IOSurfaceHandle);
typedef size_t (*SizeFn)(IOSurfaceHandle);
typedef uint32_t (*IdFn)(IOSurfaceHandle);
typedef IOSurfaceHandle (*LookupFn)(uint32_t);

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    @autoreleasepool {
        void *handle = dlopen("/System/Library/PrivateFrameworks/IOSurface.framework/IOSurface", RTLD_NOW);
        revenant_check(handle != NULL, "the private IOSurface framework opens", [NSString stringWithUTF8String:dlerror() ?: ""]);
        if (!handle)
            return revenant_finish();
        NSMutableArray *missing = [NSMutableArray array];
        NSMutableArray *present = [NSMutableArray array];
        for (size_t index = 0; index < sizeof(revenant_names) / sizeof(*revenant_names); index++)
            [(dlsym(handle, revenant_names[index]) ? present : missing) addObject:[NSString stringWithUTF8String:revenant_names[index]]];
        printf("functions present (%lu): %s\n", (unsigned long)present.count, [[present componentsJoinedByString:@" "] UTF8String]);
        printf("functions missing (%lu): %s\n", (unsigned long)missing.count, [[missing componentsJoinedByString:@" "] UTF8String]);
        NSMutableArray *constantsMissing = [NSMutableArray array];
        NSMutableArray *constantsPresent = [NSMutableArray array];
        for (size_t index = 0; index < sizeof(revenant_constants) / sizeof(*revenant_constants); index++) {
            void *symbol = dlsym(handle, revenant_constants[index]);
            if (symbol)
                [constantsPresent addObject:[NSString stringWithFormat:@"%s=%@", revenant_constants[index], *(CFStringRef *)symbol]];
            else
                [constantsMissing addObject:[NSString stringWithUTF8String:revenant_constants[index]]];
        }
        printf("constants present: %s\n", [[constantsPresent componentsJoinedByString:@" "] UTF8String]);
        printf("constants missing: %s\n", [[constantsMissing componentsJoinedByString:@" "] UTF8String]);

        CreateFn create = dlsym(handle, "IOSurfaceCreate");
        LockFn lock = dlsym(handle, "IOSurfaceLock");
        LockFn unlock = dlsym(handle, "IOSurfaceUnlock");
        BaseFn base = dlsym(handle, "IOSurfaceGetBaseAddress");
        SizeFn rowBytes = dlsym(handle, "IOSurfaceGetBytesPerRow");
        SizeFn allocation = dlsym(handle, "IOSurfaceGetAllocSize");
        SizeFn width = dlsym(handle, "IOSurfaceGetWidth");
        IdFn surfaceID = dlsym(handle, "IOSurfaceGetID");
        IdFn seed = dlsym(handle, "IOSurfaceGetSeed");
        LookupFn lookup = dlsym(handle, "IOSurfaceLookup");
        revenant_check(create && lock && unlock && base, "create, lock, unlock and base address resolve", @"missing");
        if (!create)
            return revenant_finish();
        NSDictionary *properties = @{@"IOSurfaceWidth": @64, @"IOSurfaceHeight": @64, @"IOSurfaceBytesPerElement": @4, @"IOSurfacePixelFormat": @(0x42475241)};
        IOSurfaceHandle surface = create((__bridge CFDictionaryRef)properties);
        revenant_check(surface != NULL, "a 64 by 64 BGRA surface is created", @"IOSurfaceCreate returned NULL");
        if (!surface)
            return revenant_finish();
        printf("surface id=%u alloc=%zu bytesPerRow=%zu width=%zu seed=%u\n", surfaceID ? surfaceID(surface) : 0, allocation ? allocation(surface) : 0, rowBytes ? rowBytes(surface) : 0, width ? width(surface) : 0, seed ? seed(surface) : 0);
        int locked = lock(surface, 0, NULL);
        revenant_check(locked == 0, "the surface locks", [NSString stringWithFormat:@"%d", locked]);
        uint8_t *bytes = base(surface);
        size_t stride = rowBytes(surface);
        for (int row = 0; row < 64; row++) {
            for (int column = 0; column < 64; column++) {
                uint8_t *pixel = bytes + row * stride + column * 4;
                pixel[0] = (uint8_t)(column * 4);
                pixel[1] = (uint8_t)(row * 4);
                pixel[2] = 200;
                pixel[3] = 255;
            }
        }
        unlock(surface, 0, NULL);
        printf("seed after write unlock=%u\n", seed ? seed(surface) : 0);
        if (lookup && surfaceID) {
            IOSurfaceHandle again = lookup(surfaceID(surface));
            revenant_check(again == surface, "lookup by id finds the surface in the same process", [NSString stringWithFormat:@"%p vs %p", again, surface]);
            if (again)
                CFRelease(again);
        }

        EAGLContext *context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        revenant_check(context != nil && [EAGLContext setCurrentContext:context], "an ES2 context is current", @"no context");
        SEL bind = @selector(texImageIOSurface:target:internalFormat:width:height:format:type:plane:invert:);
        revenant_check([context respondsToSelector:bind], "the context binds an IOSurface to a texture", @"selector missing");
        if ([context respondsToSelector:bind]) {
            GLuint texture = 0;
            glGenTextures(1, &texture);
            glBindTexture(GL_TEXTURE_2D, texture);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
            typedef BOOL (*BindFn)(id, SEL, IOSurfaceHandle, GLenum, GLenum, GLsizei, GLsizei, GLenum, GLenum, GLuint, BOOL);
            BOOL bound = ((BindFn)objc_msgSend)(context, bind, surface, GL_TEXTURE_2D, GL_RGBA, 64, 64, GL_BGRA_EXT, GL_UNSIGNED_BYTE, 0, NO);
            GLenum error = glGetError();
            printf("texImageIOSurface bound=%d glError=0x%x\n", bound, error);
            revenant_check(bound && error == GL_NO_ERROR, "the surface is bound as a texture", [NSString stringWithFormat:@"bound %d error 0x%x", bound, error]);
            if (bound && error == GL_NO_ERROR) {
                GLuint framebuffer = 0;
                glGenFramebuffers(1, &framebuffer);
                glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
                glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texture, 0);
                GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
                uint8_t pixels[4] = {0};
                glReadPixels(10, 20, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
                printf("framebuffer status=0x%x pixel(10,20) rgba=%u %u %u %u glError=0x%x\n", status, pixels[0], pixels[1], pixels[2], pixels[3], glGetError());
                revenant_check(status == GL_FRAMEBUFFER_COMPLETE, "a framebuffer over the surface texture is complete", [NSString stringWithFormat:@"0x%x", status]);
                revenant_check(pixels[0] == 200 && pixels[1] == 80 && pixels[2] == 40 && pixels[3] == 255, "the texture holds what the CPU wrote", [NSString stringWithFormat:@"%u %u %u %u", pixels[0], pixels[1], pixels[2], pixels[3]]);
                glClearColor(0.0f, 1.0f, 0.0f, 1.0f);
                glClear(GL_COLOR_BUFFER_BIT);
                glFinish();
                lock(surface, 1, NULL);
                uint8_t *after = base(surface);
                printf("after GL clear, CPU pixel (10,20) bgra=%u %u %u %u\n", after[20 * stride + 40], after[20 * stride + 41], after[20 * stride + 42], after[20 * stride + 43]);
                revenant_check(after[20 * stride + 41] == 255 && after[20 * stride + 40] == 0, "a GL clear shows in the CPU's view of the surface", [NSString stringWithFormat:@"%u %u %u %u", after[20 * stride + 40], after[20 * stride + 41], after[20 * stride + 42], after[20 * stride + 43]]);
                unlock(surface, 1, NULL);
            }
        }

        CIImage *image = nil;
        if ([CIImage respondsToSelector:@selector(imageWithIOSurface:)])
            image = [CIImage performSelector:@selector(imageWithIOSurface:) withObject:(__bridge id)surface];
        printf("CIImage imageWithIOSurface: %s extent %g x %g\n", image ? "made" : "nil", image.extent.size.width, image.extent.size.height);

        CALayer *layer = [CALayer layer];
        layer.frame = CGRectMake(0, 0, 64, 64);
        layer.contents = (__bridge id)surface;
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        CGContextRef bitmap = CGBitmapContextCreate(NULL, 64, 64, 8, 256, space, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
        CGContextTranslateCTM(bitmap, 0, 64);
        CGContextScaleCTM(bitmap, 1, -1);
        [layer renderInContext:bitmap];
        const uint8_t *rendered = CGBitmapContextGetData(bitmap);
        printf("renderInContext layer with surface contents pixel(10,20) bgra=%u %u %u %u\n", rendered[20 * 256 + 40], rendered[20 * 256 + 41], rendered[20 * 256 + 42], rendered[20 * 256 + 43]);
        CGContextRelease(bitmap);
        CGColorSpaceRelease(space);
        CFRelease(surface);
    }
    return revenant_finish();
}
