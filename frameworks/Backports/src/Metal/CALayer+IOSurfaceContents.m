#import <QuartzCore/QuartzCore.h>
#import <IOSurface/IOSurfaceRef.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dispatch/dispatch.h>

static const char RevenantIOSurfaceContentsKey;
static const OSType RevenantSurfaceFormatBGRA = 0x42475241;
static const OSType RevenantSurfaceFormatRGBA = 0x52474241;
static NSHashTable *RevenantIOSurfaceLayers;

@interface RevenantIOSurfaceContents : NSObject
@property (nonatomic, readonly) uint32_t seed;
- (instancetype)initWithSurface:(IOSurfaceRef)surface seed:(uint32_t)seed;
- (IOSurfaceRef)surface;
@end

@implementation RevenantIOSurfaceContents {
    IOSurfaceRef _surface;
    uint32_t _seed;
}

- (instancetype)initWithSurface:(IOSurfaceRef)surface seed:(uint32_t)seed
{
    if ((self = [super init])) {
        _surface = (IOSurfaceRef)CFRetain(surface);
        _seed = seed;
    }
    return self;
}

- (void)dealloc
{
    CFRelease(_surface);
}

- (IOSurfaceRef)surface
{
    return _surface;
}

- (uint32_t)seed
{
    return _seed;
}

@end

static CGImageRef RevenantIOSurfaceCreateImage(IOSurfaceRef surface, uint32_t *seed)
{
    size_t width = IOSurfaceGetWidth(surface), height = IOSurfaceGetHeight(surface);
    OSType format = IOSurfaceGetPixelFormat(surface);
    if (width == 0 || height == 0 || IOSurfaceGetBytesPerElement(surface) != 4)
        return NULL;
    CGBitmapInfo info;
    if (format == RevenantSurfaceFormatBGRA)
        info = kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst;
    else if (format == RevenantSurfaceFormatRGBA)
        info = (CGBitmapInfo)kCGImageAlphaPremultipliedLast;
    else
        return NULL;
    IOSurfaceLock(surface, kIOSurfaceLockReadOnly, seed);
    size_t bytesPerRow = IOSurfaceGetBytesPerRow(surface);
    CFDataRef data = CFDataCreate(kCFAllocatorDefault, IOSurfaceGetBaseAddress(surface), (CFIndex)(bytesPerRow * height));
    IOSurfaceUnlock(surface, kIOSurfaceLockReadOnly, NULL);
    if (!data)
        return NULL;
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGImageRef image = CGImageCreate(width, height, 8, 32, bytesPerRow, space, info, provider, NULL, NO, kCGRenderingIntentDefault);
    CGColorSpaceRelease(space);
    CGDataProviderRelease(provider);
    CFRelease(data);
    return image;
}

@implementation CALayer (RevenantIOSurfaceContents)

+ (void)load
{
    RevenantIOSurfaceLayers = [NSHashTable weakObjectsHashTable];
    Method original = class_getInstanceMethod(self, @selector(setContents:));
    Method replacement = class_getInstanceMethod(self, @selector(revenant_setContents:));
    if (original && replacement)
        method_exchangeImplementations(original, replacement);
}

- (void)revenant_setContents:(id)value
{
    if (!value || CFGetTypeID((__bridge CFTypeRef)value) != IOSurfaceGetTypeID()) {
        if (objc_getAssociatedObject(self, &RevenantIOSurfaceContentsKey)) {
            objc_setAssociatedObject(self, &RevenantIOSurfaceContentsKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            @synchronized(RevenantIOSurfaceLayers) {
                [RevenantIOSurfaceLayers removeObject:self];
            }
        }
        [self revenant_setContents:value];
        return;
    }
    IOSurfaceRef surface = (__bridge IOSurfaceRef)value;
    if ([NSThread isMainThread]) {
        [self revenantShowIOSurface:surface];
        return;
    }
    CFRetain(surface);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self revenantShowIOSurface:surface];
        CFRelease(surface);
    });
}

- (void)revenantShowIOSurface:(IOSurfaceRef)surface
{
    RevenantIOSurfaceContents *held = objc_getAssociatedObject(self, &RevenantIOSurfaceContentsKey);
    if (held && held.surface == surface && held.seed == IOSurfaceGetSeed(surface))
        return;
    uint32_t seed = 0;
    CGImageRef image = RevenantIOSurfaceCreateImage(surface, &seed);
    if (!image) {
        NSLog(@"CALayer: an IOSurface with an unsupported format is set as contents; it is passed on unchanged");
        if (held) {
            objc_setAssociatedObject(self, &RevenantIOSurfaceContentsKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            @synchronized(RevenantIOSurfaceLayers) {
                [RevenantIOSurfaceLayers removeObject:self];
            }
        }
        [self revenant_setContents:(__bridge id)surface];
        return;
    }
    RevenantIOSurfaceContents *state = [[RevenantIOSurfaceContents alloc] initWithSurface:surface seed:seed];
    objc_setAssociatedObject(self, &RevenantIOSurfaceContentsKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    @synchronized(RevenantIOSurfaceLayers) {
        [RevenantIOSurfaceLayers addObject:self];
    }
    [self revenant_setContents:(__bridge id)image];
    CGImageRelease(image);
}

- (void)revenantRefreshIOSurface
{
    RevenantIOSurfaceContents *held = objc_getAssociatedObject(self, &RevenantIOSurfaceContentsKey);
    if (held && IOSurfaceGetSeed(held.surface) != held.seed)
        [self revenantShowIOSurface:held.surface];
}

@end

void RevenantIOSurfaceLayersRefresh(void)
{
    NSArray *layers;
    @synchronized(RevenantIOSurfaceLayers) {
        layers = [RevenantIOSurfaceLayers allObjects];
    }
    if (layers.count == 0)
        return;
    if ([NSThread isMainThread]) {
        for (CALayer *layer in layers)
            [layer revenantRefreshIOSurface];
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        for (CALayer *layer in layers)
            [layer revenantRefreshIOSurface];
    });
}
