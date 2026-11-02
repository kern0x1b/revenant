#import "../Foundation/check.h"
#import <QuartzCore/QuartzCore.h>
#import <IOSurface/IOSurfaceRef.h>

void RevenantIOSurfaceLayersRefresh(void);

static void revenant_write_surface(IOSurfaceRef surface, uint8_t seed)
{
    IOSurfaceLock(surface, 0, NULL);
    uint8_t *base = IOSurfaceGetBaseAddress(surface);
    size_t length = IOSurfaceGetBytesPerRow(surface) * IOSurfaceGetHeight(surface);
    for (size_t i = 0; i < length; i++)
        base[i] = (uint8_t)(seed + i * 7);
    IOSurfaceUnlock(surface, 0, NULL);
}

static IOSurfaceRef revenant_surface(size_t width, size_t height, OSType format, size_t bytesPerElement, uint8_t seed)
{
    NSDictionary *properties = @{
        (__bridge NSString *)kIOSurfaceWidth: @(width),
        (__bridge NSString *)kIOSurfaceHeight: @(height),
        (__bridge NSString *)kIOSurfaceBytesPerElement: @(bytesPerElement),
        (__bridge NSString *)kIOSurfacePixelFormat: @(format)
    };
    IOSurfaceRef surface = IOSurfaceCreate((__bridge CFDictionaryRef)properties);
    revenant_write_surface(surface, seed);
    return surface;
}

static BOOL revenant_same_bytes(IOSurfaceRef surface, CGImageRef image)
{
    CFDataRef data = CGDataProviderCopyData(CGImageGetDataProvider(image));
    IOSurfaceLock(surface, kIOSurfaceLockReadOnly, NULL);
    size_t length = IOSurfaceGetBytesPerRow(surface) * IOSurfaceGetHeight(surface);
    BOOL same = CFDataGetLength(data) == (CFIndex)length && memcmp(CFDataGetBytePtr(data), IOSurfaceGetBaseAddress(surface), length) == 0;
    IOSurfaceUnlock(surface, kIOSurfaceLockReadOnly, NULL);
    CFRelease(data);
    return same;
}

static BOOL revenant_is_image(id contents)
{
    return contents && CFGetTypeID((__bridge CFTypeRef)contents) == CGImageGetTypeID();
}

static BOOL revenant_is_surface(id contents)
{
    return contents && CFGetTypeID((__bridge CFTypeRef)contents) == IOSurfaceGetTypeID();
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    @autoreleasepool {
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        uint8_t pixels[2 * 2 * 4] = {0};
        CGContextRef context = CGBitmapContextCreate(pixels, 2, 2, 8, 8, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
        CGImageRef plain = CGBitmapContextCreateImage(context);
        CGContextRelease(context);
        CGColorSpaceRelease(space);

        CALayer *layer = [CALayer layer];
        layer.contents = (__bridge id)plain;
        revenant_check(layer.contents == (revenant_negative ? (id)[NSNull null] : (__bridge id)plain), "a CGImage is set as contents without a copy", @"the contents are not the CGImage");
        layer.contents = nil;
        revenant_check(layer.contents == nil, "nil clears the contents", @"the contents are not nil");

        IOSurfaceRef surface = revenant_surface(4, 3, 0x42475241, 4, 11);
        layer.contents = (__bridge id)surface;
        id first = layer.contents;
        revenant_check(revenant_is_image(first), "an IOSurface becomes a CGImage", @"the contents are not a CGImage");
        revenant_check(revenant_is_image(first) && CGImageGetWidth((__bridge CGImageRef)first) == 4 && CGImageGetHeight((__bridge CGImageRef)first) == 3, "the CGImage has the surface size", @"the size differs");
        revenant_check(revenant_is_image(first) && revenant_same_bytes(surface, (__bridge CGImageRef)first), "the CGImage holds the surface bytes", @"the bytes differ");

        layer.contents = (__bridge id)surface;
        revenant_check(layer.contents == first, "the same surface with the same seed keeps its CGImage", @"the CGImage was recreated");

        revenant_write_surface(surface, 29);
        RevenantIOSurfaceLayersRefresh();
        id second = layer.contents;
        revenant_check(second != first && revenant_is_image(second) && revenant_same_bytes(surface, (__bridge CGImageRef)second), "a write to the surface is shown after the refresh", @"the layer still shows the old CGImage");

        RevenantIOSurfaceLayersRefresh();
        revenant_check(layer.contents == second, "a refresh without a write keeps the CGImage", @"the CGImage was recreated");

        layer.contents = (__bridge id)plain;
        revenant_write_surface(surface, 47);
        RevenantIOSurfaceLayersRefresh();
        revenant_check(layer.contents == (__bridge id)plain, "a CGImage set after a surface stops the refresh", @"the refresh replaced the CGImage");

        IOSurfaceRef gray = revenant_surface(4, 4, 0x4C303038, 1, 3);
        layer.contents = (__bridge id)gray;
        revenant_check(revenant_is_surface(layer.contents), "an unsupported format is passed on unchanged", @"the surface was converted or dropped");

        layer.contents = nil;
        revenant_check(layer.contents == nil, "nil clears a passed-on surface", @"the contents are not nil");

        CALayer *background = [CALayer layer];
        IOSurfaceRef threaded = revenant_surface(2, 2, 0x42475241, 4, 5);
        CFRetain(threaded);
        dispatch_semaphore_t done = dispatch_semaphore_create(0);
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            background.contents = (__bridge id)threaded;
            dispatch_semaphore_signal(done);
        });
        dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
        NSDate *until = [NSDate dateWithTimeIntervalSinceNow:5];
        while (!revenant_is_image(background.contents) && [until timeIntervalSinceNow] > 0)
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
        revenant_check(revenant_is_image(background.contents) && revenant_same_bytes(threaded, (__bridge CGImageRef)background.contents), "a surface set from a background thread is shown on the main thread", @"the layer did not get the CGImage");
        CFRelease(threaded);
        CFRelease(surface);
        CFRelease(gray);
    }
    return revenant_finish();
}
