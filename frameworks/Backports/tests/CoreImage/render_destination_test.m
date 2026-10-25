#import "../Foundation/check.h"
#import <CoreImage/CoreImage.h>
#import <CoreVideo/CoreVideo.h>
#import <IOSurface/IOSurfaceObjC.h>
#import <Metal/Metal.h>
#define GL_SILENCE_DEPRECATION
#import <OpenGL/OpenGL.h>
#import <OpenGL/gl.h>
#import "RevenantCIRenderDestination.h"

typedef struct {
    BOOL flipped;
    CGPoint at;
    CGRect from;
} revenant_region_case;

static const revenant_region_case revenant_region_cases[] = {
    {YES, {0, 0}, {{2, 2}, {8, 8}}},
    {YES, {1, 1}, {{2, 2}, {8, 8}}},
    {YES, {2, 2}, {{2, 2}, {4, 4}}},
    {NO, {0, 0}, {{2, 2}, {8, 8}}},
    {NO, {1, 1}, {{2, 2}, {8, 8}}},
    {NO, {2, 2}, {{2, 2}, {4, 4}}},
};

static const size_t revenant_region_case_count = sizeof(revenant_region_cases) / sizeof(revenant_region_cases[0]);

static BOOL revenant_bytes_close(NSData *expected, NSData *actual, int tolerance)
{
    if (expected.length != actual.length)
        return NO;
    const uint8_t *a = expected.bytes, *b = actual.bytes;
    for (NSUInteger index = 0; index < expected.length; index++) {
        int difference = (int)a[index] - (int)b[index];
        if (difference < -tolerance || difference > tolerance)
            return NO;
    }
    return YES;
}

static NSString *revenant_first_pixel(NSData *data)
{
    const uint8_t *bytes = data.bytes;
    return [NSString stringWithFormat:@"%u %u %u %u", bytes[0], bytes[1], bytes[2], bytes[3]];
}

static NSString *revenant_difference(NSData *expected, NSData *actual)
{
    const uint8_t *a = expected.bytes, *b = actual.bytes;
    NSMutableString *text = [NSMutableString string];
    NSUInteger count = 0;
    for (NSUInteger index = 0; index < expected.length && index < actual.length; index++) {
        if (a[index] != b[index]) {
            if (count < 16)
                [text appendFormat:@"[%lu] %u/%u ", (unsigned long)index, a[index], b[index]];
            count++;
        }
    }
    return [NSString stringWithFormat:@"%lu bytes differ: %@", (unsigned long)count, text];
}

static void revenant_compare_value(NSString *key, id host, id backport)
{
    id expected = [host valueForKey:key];
    id actual = [backport valueForKey:key];
    revenant_check(expected == actual || [expected isEqual:actual], [key UTF8String], [NSString stringWithFormat:@"%@ != %@", expected, actual]);
}

static NSString *revenant_case_name(const revenant_region_case *regionCase)
{
    return [NSString stringWithFormat:@"flipped %d at (%g,%g) from (%g,%g %g %g)", regionCase->flipped, (double)regionCase->at.x, (double)regionCase->at.y, (double)regionCase->from.origin.x, (double)regionCase->from.origin.y, (double)regionCase->from.size.width, (double)regionCase->from.size.height];
}

static CIImage *revenant_gradient(void)
{
    CIImage *canvas = [[CIImage imageWithColor:[CIColor colorWithRed:0 green:0 blue:0 alpha:1]] imageByCroppingToRect:CGRectMake(0, 0, 16, 16)];
    for (int column = 0; column < 16; column++) {
        for (int row = 0; row < 16; row++) {
            CIImage *dot = [[CIImage imageWithColor:[CIColor colorWithRed:column / 15.0 green:row / 15.0 blue:0 alpha:1]] imageByCroppingToRect:CGRectMake(column, row, 1, 1)];
            canvas = [dot imageByCompositingOverImage:canvas];
        }
    }
    return canvas;
}

static NSData *revenant_copy_rows(const void *base, size_t bytesPerRow, size_t rows, size_t rowBytes)
{
    NSMutableData *data = [NSMutableData dataWithLength:rowBytes * rows];
    for (size_t row = 0; row < rows; row++) {
        memcpy((uint8_t *)data.mutableBytes + row * rowBytes, (const uint8_t *)base + row * bytesPerRow, rowBytes);
    }
    return data;
}

static CVPixelBufferRef revenant_pixel_buffer(void)
{
    CVPixelBufferRef buffer = NULL;
    CVPixelBufferCreate(kCFAllocatorDefault, 8, 8, kCVPixelFormatType_32BGRA, NULL, &buffer);
    CVPixelBufferLockBaseAddress(buffer, 0);
    memset(CVPixelBufferGetBaseAddress(buffer), 0x40, CVPixelBufferGetBytesPerRow(buffer) * 8);
    CVPixelBufferUnlockBaseAddress(buffer, 0);
    return buffer;
}

static NSData *revenant_pixel_buffer_bytes(CVPixelBufferRef buffer)
{
    CVPixelBufferLockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
    NSData *data = revenant_copy_rows(CVPixelBufferGetBaseAddress(buffer), CVPixelBufferGetBytesPerRow(buffer), 8, 32);
    CVPixelBufferUnlockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
    return data;
}

static IOSurfaceRef revenant_surface(void)
{
    NSDictionary *properties = @{(__bridge NSString *)kIOSurfaceWidth: @8, (__bridge NSString *)kIOSurfaceHeight: @8, (__bridge NSString *)kIOSurfaceBytesPerElement: @4, (__bridge NSString *)kIOSurfacePixelFormat: @((uint32_t)kCVPixelFormatType_32BGRA)};
    IOSurfaceRef surface = IOSurfaceCreate((__bridge CFDictionaryRef)properties);
    IOSurfaceLock(surface, 0, NULL);
    memset(IOSurfaceGetBaseAddress(surface), 0x40, IOSurfaceGetBytesPerRow(surface) * 8);
    IOSurfaceUnlock(surface, 0, NULL);
    return surface;
}

static NSData *revenant_surface_bytes(IOSurfaceRef surface)
{
    IOSurfaceLock(surface, kIOSurfaceLockReadOnly, NULL);
    NSData *data = revenant_copy_rows(IOSurfaceGetBaseAddress(surface), IOSurfaceGetBytesPerRow(surface), 8, 32);
    IOSurfaceUnlock(surface, kIOSurfaceLockReadOnly, NULL);
    return data;
}

static void revenant_prefill_gl(GLuint texture)
{
    uint8_t prefill[8 * 8 * 4];
    memset(prefill, 0x40, sizeof(prefill));
    glBindTexture(GL_TEXTURE_2D, texture);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 8, 8, 0, GL_RGBA, GL_UNSIGNED_BYTE, prefill);
}

static NSData *revenant_read_gl(GLuint texture)
{
    NSMutableData *data = [NSMutableData dataWithLength:8 * 8 * 4];
    glFinish();
    glBindTexture(GL_TEXTURE_2D, texture);
    glGetTexImage(GL_TEXTURE_2D, 0, GL_RGBA, GL_UNSIGNED_BYTE, data.mutableBytes);
    return data;
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    Class destinationClass = NSClassFromString(@"CIRenderDestinationRevenant");
    revenant_check((destinationClass != Nil) != revenant_negative, "CIRenderDestination implementation is present", NSStringFromClass(destinationClass));
    if (!destinationClass)
        return revenant_finish();

    CIContext *context = [CIContext contextWithOptions:nil];
    CIImage *image = [[CIImage imageWithColor:[CIColor colorWithRed:0.2 green:0.6 blue:0.9 alpha:0.8]] imageByCroppingToRect:CGRectMake(0, 0, 8, 8)];

    const NSUInteger width = 8, height = 8, rowBytes = width * 4;
    NSMutableData *hostBytes = [NSMutableData dataWithLength:rowBytes * height];
    NSMutableData *backportBytes = [NSMutableData dataWithLength:rowBytes * height];

    CIRenderDestination *hostDestination = [[CIRenderDestination alloc] initWithBitmapData:hostBytes.mutableBytes width:width height:height bytesPerRow:rowBytes format:kCIFormatRGBA8];
    id backportDestination = [[destinationClass alloc] initWithBitmapData:backportBytes.mutableBytes width:width height:height bytesPerRow:rowBytes format:kCIFormatRGBA8];
    revenant_compare_value(@"width", hostDestination, backportDestination);
    revenant_compare_value(@"height", hostDestination, backportDestination);
    revenant_compare_value(@"alphaMode", hostDestination, backportDestination);
    revenant_compare_value(@"flipped", hostDestination, backportDestination);
    revenant_compare_value(@"dithered", hostDestination, backportDestination);
    revenant_compare_value(@"clamped", hostDestination, backportDestination);
    revenant_compare_value(@"blendsInDestinationColorSpace", hostDestination, backportDestination);

    NSError *error = nil;
    CIRenderTask *hostTask = [context startTaskToRender:image toDestination:hostDestination error:&error];
    revenant_check(hostTask != nil && error == nil, "the host renders the bitmap destination", error.localizedDescription ?: @"rendered");
    error = nil;
    [hostTask waitUntilCompletedAndReturnError:&error];
    id backportTask = [backportDestination revenant_renderImage:image context:context error:&error];
    revenant_check(backportTask != nil && error == nil, "the backport renders the bitmap destination", error.localizedDescription ?: @"rendered");
    revenant_check([hostBytes isEqualToData:backportBytes], "bitmap pixels match the host", [NSString stringWithFormat:@"host %@ backport %@", revenant_first_pixel(hostBytes), revenant_first_pixel(backportBytes)]);

    CIImage *gradient = revenant_gradient();
    for (size_t index = 0; index < revenant_region_case_count; index++) {
        const revenant_region_case *regionCase = &revenant_region_cases[index];
        NSString *name = revenant_case_name(regionCase);
        NSMutableData *hostRegionPixels = [NSMutableData dataWithLength:rowBytes * height];
        memset(hostRegionPixels.mutableBytes, 0x40, rowBytes * height);
        NSMutableData *backportRegionPixels = [NSMutableData dataWithLength:rowBytes * height];
        memset(backportRegionPixels.mutableBytes, 0x40, rowBytes * height);
        CIRenderDestination *hostRegion = [[CIRenderDestination alloc] initWithBitmapData:hostRegionPixels.mutableBytes width:width height:height bytesPerRow:rowBytes format:kCIFormatRGBA8];
        [hostRegion setValue:@(regionCase->flipped) forKey:@"flipped"];
        NSError *hostError = nil;
        CIRenderTask *hostRegionTask = [context startTaskToRender:gradient fromRect:regionCase->from toDestination:hostRegion atPoint:regionCase->at error:&hostError];
        [hostRegionTask waitUntilCompletedAndReturnError:nil];
        id backportRegion = [[destinationClass alloc] initWithBitmapData:backportRegionPixels.mutableBytes width:width height:height bytesPerRow:rowBytes format:kCIFormatRGBA8];
        [backportRegion setValue:@(regionCase->flipped) forKey:@"flipped"];
        NSError *backportError = nil;
        id backportRegionTask = [backportRegion revenant_renderImage:gradient fromRect:regionCase->from atPoint:regionCase->at context:context error:&backportError];
        revenant_check(hostRegionTask != nil && backportRegionTask != nil && hostError == nil && backportError == nil, [[NSString stringWithFormat:@"the bitmap region renders: %@", name] UTF8String], backportError.localizedDescription ?: @"rendered");
        revenant_check([hostRegionPixels isEqualToData:backportRegionPixels], [[NSString stringWithFormat:@"bitmap region pixels match the host: %@", name] UTF8String], revenant_difference(hostRegionPixels, backportRegionPixels));
    }

    CVPixelBufferRef hostBuffer = revenant_pixel_buffer();
    CVPixelBufferRef backportBuffer = revenant_pixel_buffer();
    revenant_check(hostBuffer != NULL && backportBuffer != NULL, "the host creates the BGRA pixel buffers", @"CVPixelBufferCreate");
    for (size_t index = 0; index < revenant_region_case_count; index++) {
        const revenant_region_case *regionCase = &revenant_region_cases[index];
        NSString *name = revenant_case_name(regionCase);
        CVPixelBufferRef hostBufferCase = revenant_pixel_buffer();
        CVPixelBufferRef backportBufferCase = revenant_pixel_buffer();
        CIRenderDestination *hostPixelBufferDestination = [[CIRenderDestination alloc] initWithPixelBuffer:hostBufferCase];
        [hostPixelBufferDestination setValue:@(regionCase->flipped) forKey:@"flipped"];
        NSError *hostError = nil;
        CIRenderTask *hostPixelBufferTask = [context startTaskToRender:gradient fromRect:regionCase->from toDestination:hostPixelBufferDestination atPoint:regionCase->at error:&hostError];
        [hostPixelBufferTask waitUntilCompletedAndReturnError:nil];
        id backportPixelBufferDestination = [[destinationClass alloc] initWithPixelBuffer:backportBufferCase];
        [backportPixelBufferDestination setValue:@(regionCase->flipped) forKey:@"flipped"];
        NSError *backportError = nil;
        id backportPixelBufferTask = [backportPixelBufferDestination revenant_renderImage:gradient fromRect:regionCase->from atPoint:regionCase->at context:context error:&backportError];
        revenant_check(hostPixelBufferTask != nil && backportPixelBufferTask != nil && hostError == nil && backportError == nil, [[NSString stringWithFormat:@"the pixel buffer region renders: %@", name] UTF8String], backportError.localizedDescription ?: @"rendered");
        NSData *hostPixelBufferBytes = revenant_pixel_buffer_bytes(hostBufferCase);
        NSData *backportPixelBufferBytes = revenant_pixel_buffer_bytes(backportBufferCase);
        revenant_check([hostPixelBufferBytes isEqualToData:backportPixelBufferBytes], [[NSString stringWithFormat:@"pixel buffer region matches the host: %@", name] UTF8String], revenant_difference(hostPixelBufferBytes, backportPixelBufferBytes));
        CVPixelBufferRelease(hostBufferCase);
        CVPixelBufferRelease(backportBufferCase);
    }
    CVPixelBufferRelease(hostBuffer);
    CVPixelBufferRelease(backportBuffer);

    IOSurfaceRef hostSurface = revenant_surface();
    IOSurfaceRef backportSurface = revenant_surface();
    IOSurface *hostSurfaceObject = (__bridge IOSurface *)hostSurface;
    IOSurface *backportSurfaceObject = (__bridge IOSurface *)backportSurface;
    for (size_t index = 0; index < revenant_region_case_count; index++) {
        const revenant_region_case *regionCase = &revenant_region_cases[index];
        NSString *name = revenant_case_name(regionCase);
        IOSurfaceRef hostSurfaceCase = revenant_surface();
        IOSurfaceRef backportSurfaceCase = revenant_surface();
        CIRenderDestination *hostSurfaceDestination = [[CIRenderDestination alloc] initWithIOSurface:(__bridge IOSurface *)hostSurfaceCase];
        [hostSurfaceDestination setValue:@(regionCase->flipped) forKey:@"flipped"];
        NSError *hostError = nil;
        CIRenderTask *hostSurfaceTask = [context startTaskToRender:gradient fromRect:regionCase->from toDestination:hostSurfaceDestination atPoint:regionCase->at error:&hostError];
        [hostSurfaceTask waitUntilCompletedAndReturnError:nil];
        id backportSurfaceDestination = [[destinationClass alloc] initWithIOSurface:(__bridge IOSurface *)backportSurfaceCase];
        [backportSurfaceDestination setValue:@(regionCase->flipped) forKey:@"flipped"];
        NSError *backportError = nil;
        id backportSurfaceTask = [backportSurfaceDestination revenant_renderImage:gradient fromRect:regionCase->from atPoint:regionCase->at context:context error:&backportError];
        revenant_check(hostSurfaceTask != nil && backportSurfaceTask != nil && hostError == nil && backportError == nil, [[NSString stringWithFormat:@"the surface region renders: %@", name] UTF8String], backportError.localizedDescription ?: @"rendered");
        NSData *hostSurfaceBytes = revenant_surface_bytes(hostSurfaceCase);
        NSData *backportSurfaceBytes = revenant_surface_bytes(backportSurfaceCase);
        revenant_check([hostSurfaceBytes isEqualToData:backportSurfaceBytes], [[NSString stringWithFormat:@"surface region matches the host: %@", name] UTF8String], revenant_difference(hostSurfaceBytes, backportSurfaceBytes));
        CFRelease(hostSurfaceCase);
        CFRelease(backportSurfaceCase);
    }
    CFRelease(hostSurface);
    CFRelease(backportSurface);
    (void)hostSurfaceObject;
    (void)backportSurfaceObject;

    CGLPixelFormatAttribute attributes[] = {kCGLPFAAccelerated, kCGLPFAOpenGLProfile, (CGLPixelFormatAttribute)kCGLOGLPVersion_Legacy, 0};
    CGLPixelFormatObj pixelFormat = NULL;
    GLint pixelFormatCount = 0;
    CGLChoosePixelFormat(attributes, &pixelFormat, &pixelFormatCount);
    CGLContextObj cgl = NULL;
    CGLCreateContext(pixelFormat, NULL, &cgl);
    revenant_check(cgl != NULL, "the host creates an OpenGL context", @"CGLCreateContext");
    if (cgl) {
        CGLSetCurrentContext(cgl);
        CIContext *glContext = [CIContext contextWithCGLContext:cgl pixelFormat:pixelFormat colorSpace:nil options:nil];
        for (size_t index = 0; index < revenant_region_case_count; index++) {
            const revenant_region_case *regionCase = &revenant_region_cases[index];
            NSString *name = revenant_case_name(regionCase);
            GLuint hostTexture = 0, backportTexture = 0;
            glGenTextures(1, &hostTexture);
            glGenTextures(1, &backportTexture);
            revenant_prefill_gl(hostTexture);
            revenant_prefill_gl(backportTexture);
            CIRenderDestination *hostGL = [[CIRenderDestination alloc] initWithGLTexture:hostTexture target:GL_TEXTURE_2D width:width height:height];
            [hostGL setValue:@(regionCase->flipped) forKey:@"flipped"];
            NSError *hostError = nil;
            CIRenderTask *hostGLTask = [glContext startTaskToRender:gradient fromRect:regionCase->from toDestination:hostGL atPoint:regionCase->at error:&hostError];
            [hostGLTask waitUntilCompletedAndReturnError:nil];
            id backportGL = [[destinationClass alloc] initWithGLTexture:backportTexture target:GL_TEXTURE_2D width:width height:height];
            [backportGL setValue:@(regionCase->flipped) forKey:@"flipped"];
            NSError *backportError = nil;
            id backportGLTask = [backportGL revenant_renderImage:gradient fromRect:regionCase->from atPoint:regionCase->at context:glContext error:&backportError];
            revenant_check(hostGLTask != nil && backportGLTask != nil && hostError == nil && backportError == nil, [[NSString stringWithFormat:@"the GL region renders: %@", name] UTF8String], backportError.localizedDescription ?: @"rendered");
            NSData *hostGLBytes = revenant_read_gl(hostTexture);
            NSData *backportGLBytes = revenant_read_gl(backportTexture);
            revenant_check(revenant_bytes_close(hostGLBytes, backportGLBytes, 2), [[NSString stringWithFormat:@"GL region matches the host within rounding: %@", name] UTF8String], revenant_difference(hostGLBytes, backportGLBytes));
            revenant_check(glGetError() == GL_NO_ERROR, [[NSString stringWithFormat:@"GL region leaves no GL error: %@", name] UTF8String], @"glGetError");
            glDeleteTextures(1, &hostTexture);
            glDeleteTextures(1, &backportTexture);
        }
        CGLSetCurrentContext(NULL);
        CGLDestroyContext(cgl);
    }

    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    revenant_check(device != nil, "the host has a Metal device", @"no device");
    if (!device)
        return revenant_finish();
    MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:width height:height mipmapped:NO];
    descriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
    descriptor.storageMode = MTLStorageModeShared;
    id<MTLTexture> hostTexture = [device newTextureWithDescriptor:descriptor];
    id<MTLTexture> backportTexture = [device newTextureWithDescriptor:descriptor];

    CIRenderDestination *hostTextureDestination = [[CIRenderDestination alloc] initWithMTLTexture:hostTexture commandBuffer:nil];
    error = nil;
    CIRenderTask *hostTextureTask = [context startTaskToRender:image toDestination:hostTextureDestination error:&error];
    revenant_check(hostTextureTask != nil && error == nil, "the host renders the texture destination", error.localizedDescription ?: @"rendered");
    [hostTextureTask waitUntilCompletedAndReturnError:nil];
    NSMutableData *hostTextureBytes = [NSMutableData dataWithLength:rowBytes * height];
    [hostTexture getBytes:hostTextureBytes.mutableBytes bytesPerRow:rowBytes fromRegion:MTLRegionMake2D(0, 0, width, height) mipmapLevel:0];

    id backportTextureDestination = [[destinationClass alloc] initWithMTLTexture:backportTexture commandBuffer:nil];
    error = nil;
    id backportTextureTask = [backportTextureDestination revenant_renderImage:image context:context error:&error];
    revenant_check(backportTextureTask != nil && error == nil, "the backport renders the texture destination", error.localizedDescription ?: @"rendered");
    NSMutableData *backportTextureBytes = [NSMutableData dataWithLength:rowBytes * height];
    [backportTexture getBytes:backportTextureBytes.mutableBytes bytesPerRow:rowBytes fromRegion:MTLRegionMake2D(0, 0, width, height) mipmapLevel:0];
    revenant_check(revenant_bytes_close(hostTextureBytes, backportTextureBytes, 2), "texture pixels match the host within rounding", [NSString stringWithFormat:@"host %@ backport %@", revenant_first_pixel(hostTextureBytes), revenant_first_pixel(backportTextureBytes)]);

    CIImage *asymmetric = [[CIImage imageWithColor:[CIColor colorWithRed:0 green:0 blue:1 alpha:0.5]] imageByCroppingToRect:CGRectMake(0, 4, 8, 4)];
    asymmetric = [asymmetric imageByCompositingOverImage:[[CIImage imageWithColor:[CIColor colorWithRed:1 green:0 blue:0 alpha:1]] imageByCroppingToRect:CGRectMake(0, 0, 8, 4)]];
    NSArray<NSDictionary *> *configurations = @[@{@"flipped": @NO}, @{@"alphaMode": @0}, @{@"alphaMode": @2}];
    for (NSDictionary *configuration in configurations) {
        NSMutableData *hostPixels = [NSMutableData dataWithLength:rowBytes * height];
        NSMutableData *backportPixels = [NSMutableData dataWithLength:rowBytes * height];
        CIRenderDestination *hostConfigured = [[CIRenderDestination alloc] initWithBitmapData:hostPixels.mutableBytes width:width height:height bytesPerRow:rowBytes format:kCIFormatRGBA8];
        id backportConfigured = [[destinationClass alloc] initWithBitmapData:backportPixels.mutableBytes width:width height:height bytesPerRow:rowBytes format:kCIFormatRGBA8];
        [configuration enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
            [hostConfigured setValue:value forKey:key];
            [backportConfigured setValue:value forKey:key];
        }];
        error = nil;
        [[context startTaskToRender:asymmetric toDestination:hostConfigured error:&error] waitUntilCompletedAndReturnError:nil];
        error = nil;
        id backportConfiguredTask = [backportConfigured revenant_renderImage:asymmetric context:context error:&error];
        revenant_check(backportConfiguredTask != nil && error == nil, [[NSString stringWithFormat:@"the backport renders %@", configuration] UTF8String], error.localizedDescription ?: @"rendered");
        revenant_check(revenant_bytes_close(hostPixels, backportPixels, 1), [[NSString stringWithFormat:@"%@ pixels match the host", configuration] UTF8String], [NSString stringWithFormat:@"host %@ backport %@", revenant_first_pixel(hostPixels), revenant_first_pixel(backportPixels)]);
    }

    error = nil;
    BOOL hostPrepared = [context prepareRender:image fromRect:CGRectMake(0, 0, width, height) toDestination:hostDestination atPoint:CGPointZero error:&error];
    NSError *backportPrepareError = nil;
    BOOL backportPrepared = [backportDestination revenant_prepareRenderWithError:&backportPrepareError];
    revenant_check(hostPrepared == backportPrepared && hostPrepared, "prepareRender accepts the bitmap destination like the host", backportPrepareError.localizedDescription ?: @"prepared");

    id<MTLTexture> hostUnsupported = [device newTextureWithDescriptor:[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR8Unorm width:width height:height mipmapped:NO]];
    id<MTLTexture> backportUnsupported = [device newTextureWithDescriptor:[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR8Unorm width:width height:height mipmapped:NO]];
    CIRenderDestination *hostUnsupportedDestination = [[CIRenderDestination alloc] initWithMTLTexture:hostUnsupported commandBuffer:nil];
    error = nil;
    BOOL hostUnsupportedPrepared = [context prepareRender:image fromRect:CGRectMake(0, 0, width, height) toDestination:hostUnsupportedDestination atPoint:CGPointZero error:&error];
    id backportUnsupportedDestination = [[destinationClass alloc] initWithMTLTexture:backportUnsupported commandBuffer:nil];
    NSError *backportUnsupportedError = nil;
    BOOL backportUnsupportedPrepared = [backportUnsupportedDestination revenant_prepareRenderWithError:&backportUnsupportedError];
    revenant_check(hostUnsupportedPrepared == backportUnsupportedPrepared, "prepareRender agrees with the host on an R8 texture", [NSString stringWithFormat:@"host %d backport %d", hostUnsupportedPrepared, backportUnsupportedPrepared]);

    return revenant_finish();
}
