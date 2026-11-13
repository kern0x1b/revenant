#import "../Foundation/check.h"
#import <QuartzCore/QuartzCore.h>
#import <Metal/Metal.h>
#import <objc/message.h>
#include <dlfcn.h>
#include <stdlib.h>

static NSString *const OurName = @"revenantContentsMultiplyColor";
static NSString *const OurKeyPath = @"filters.revenantContentsMultiplyColor.inputColor";

static id<MTLDevice> device;
static id<MTLCommandQueue> queue;
static IMP systemGetter;

@interface RevenantSystemLayer : CALayer
@end

@implementation RevenantSystemLayer
@end

@interface RevenantSwatchDrawer : NSObject <CALayerDelegate>
@end

@implementation RevenantSwatchDrawer

- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)context
{
    CGFloat components[4][4] = {{1, 1, 1, 1}, {1, 1, 1, 0.5}, {0.2, 0.8, 0.5, 1}, {0.4, 0.2, 0.1, 0.4}};
    for (int index = 0; index < 4; index++) {
        CGContextSetRGBFillColor(context, components[index][0], components[index][1], components[index][2], components[index][3]);
        CGContextFillRect(context, CGRectMake(index, 0, 1, 1));
    }
}

@end

static RevenantSwatchDrawer *drawer;

static CGColorRef color(CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha)
{
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    const CGFloat components[] = {red, green, blue, alpha};
    CGColorRef made = CGColorCreate(space, components);
    CGColorSpaceRelease(space);
    return (CGColorRef)CFAutorelease(made);
}

static CGImageRef swatches(void)
{
    static uint8_t pixels[16] = {255, 255, 255, 255, 128, 128, 128, 128, 51, 204, 128, 255, 40, 20, 10, 100};
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixels, 4, 1, 8, 16, space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGImageRef image = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    CGColorSpaceRelease(space);
    return (CGImageRef)CFAutorelease(image);
}

static CALayer *leaf_of(Class cls, BOOL drawn)
{
    CALayer *layer = [cls layer];
    layer.frame = CGRectMake(0, 0, 4, 1);
    layer.magnificationFilter = kCAFilterNearest;
    if (drawn) {
        layer.delegate = drawer;
        [layer setNeedsDisplay];
        [layer displayIfNeeded];
    } else {
        layer.contents = (__bridge id)swatches();
    }
    return layer;
}

static CALayer *leaf(BOOL drawn)
{
    return leaf_of([CALayer class], drawn);
}

static NSData *render(CALayer *layer)
{
    CALayer *root = [CALayer layer];
    root.frame = CGRectMake(0, 0, 4, 1);
    [root addSublayer:layer];
    MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:4 height:1 mipmapped:NO];
    descriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
    descriptor.storageMode = MTLStorageModeShared;
    id<MTLTexture> texture = [device newTextureWithDescriptor:descriptor];
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CARenderer *renderer = [CARenderer rendererWithMTLTexture:texture options:@{kCARendererColorSpace: (__bridge id)space, kCARendererMetalCommandQueue: queue}];
    CGColorSpaceRelease(space);
    renderer.layer = root;
    renderer.bounds = root.bounds;
    Method getter = class_getInstanceMethod([CALayer class], @selector(contentsMultiplyColor));
    IMP shim = method_setImplementation(getter, systemGetter);
    [CATransaction flush];
    method_setImplementation(getter, shim);
    [renderer beginFrameAtTime:CACurrentMediaTime() timeStamp:NULL];
    [renderer addUpdateRect:renderer.bounds];
    [renderer render];
    [renderer endFrame];
    id<MTLCommandBuffer> buffer = [queue commandBuffer];
    [buffer commit];
    [buffer waitUntilCompleted];
    uint8_t bytes[16];
    [texture getBytes:bytes bytesPerRow:16 fromRegion:MTLRegionMake2D(0, 0, 4, 1) mipmapLevel:0];
    return [NSData dataWithBytes:bytes length:sizeof bytes];
}

static NSString *describe(NSData *pixels)
{
    const uint8_t *bytes = pixels.bytes;
    NSMutableString *text = [NSMutableString string];
    for (int index = 0; index < 4; index++)
        [text appendFormat:@" (%d %d %d %d)", bytes[index * 4 + 2], bytes[index * 4 + 1], bytes[index * 4], bytes[index * 4 + 3]];
    return text;
}

static void expect_pixels(const char *name, NSData *seen, NSData *expected)
{
    const uint8_t *a = seen.bytes, *b = expected.bytes;
    BOOL same = YES;
    for (int index = 0; index < 16; index++) {
        if (abs((int)a[index] - (int)b[index]) > 1)
            same = NO;
    }
    revenant_check(same, name, [NSString stringWithFormat:@"%@ is not%@", describe(seen), describe(expected)]);
}

static NSData *system_render(BOOL drawn, CGColorRef tint)
{
    CALayer *layer = leaf_of([RevenantSystemLayer class], drawn);
    [layer setValue:(__bridge id)tint forKey:@"contentsMultiplyColor"];
    return render(layer);
}

static NSData *our_render(BOOL drawn, CGColorRef tint)
{
    CALayer *layer = leaf(drawn);
    [layer setValue:(__bridge id)tint forKey:@"contentsMultiplyColor"];
    return render(layer);
}

static NSUInteger our_filters(CALayer *layer)
{
    NSUInteger count = 0;
    for (id filter in layer.filters) {
        if ([[filter valueForKey:@"name"] isEqual:OurName])
            count++;
    }
    return count;
}

static BOOL adopt_system(SEL selector)
{
    Dl_info ours;
    dladdr((const void *)&adopt_system, &ours);
    unsigned count = 0;
    Method *methods = class_copyMethodList([CALayer class], &count);
    BOOL adopted = NO;
    for (unsigned index = 0; index < count; index++) {
        Dl_info info;
        IMP implementation = method_getImplementation(methods[index]);
        if (method_getName(methods[index]) == selector && dladdr((const void *)implementation, &info) && info.dli_fbase != ours.dli_fbase)
            adopted = class_addMethod([RevenantSystemLayer class], selector, implementation, method_getTypeEncoding(methods[index]));
        if (adopted && selector == @selector(contentsMultiplyColor))
            systemGetter = implementation;
    }
    free(methods);
    return adopted;
}

static id app_filter(void)
{
    id filter = ((id (*)(Class, SEL, NSString *))objc_msgSend)(NSClassFromString(@"CAFilter"), NSSelectorFromString(@"filterWithName:"), @"colorInvert");
    [filter setValue:@"appInvert" forKey:@"name"];
    return filter;
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    @autoreleasepool {
        device = MTLCreateSystemDefaultDevice();
        queue = [device newCommandQueue];
        drawer = [RevenantSwatchDrawer new];
        if (!device || !adopt_system(@selector(setContentsMultiplyColor:)) || !adopt_system(@selector(contentsMultiplyColor))) {
            printf("FAIL measurement: the host needs Metal and the system's contentsMultiplyColor as the oracle\n");
            return 1;
        }

        CGColorRef tints[] = {color(1, 0, 0, 1), color(0.4, 0.6, 1, 0.7), color(0.2, 0.9, 0.3, 0.5), color(0, 0, 0, 0), color(1, 1, 1, 0.25)};
        const char *names[] = {"opaque red", "translucent blue", "half green", "clear", "quarter white"};
        for (int index = 0; index < 5; index++) {
            char name[96];
            snprintf(name, sizeof name, "image contents times %s as the system", names[index]);
            expect_pixels(name, our_render(NO, tints[index]), system_render(NO, tints[index]));
            snprintf(name, sizeof name, "drawn contents times %s as the system", names[index]);
            expect_pixels(name, our_render(YES, tints[index]), system_render(YES, tints[index]));
        }

        CALayer *plain = leaf(NO);
        NSData *untinted = render(plain);
        CALayer *fresh = leaf(NO);
        id initial = [fresh valueForKey:@"contentsMultiplyColor"];
        revenant_check(initial && CGColorEqualToColor((__bridge CGColorRef)initial, color(1, 1, 1, 1)), "an untouched layer answers white", [NSString stringWithFormat:@"%@", initial]);
        revenant_check(fresh.filters == nil, "an untouched layer has no filter", [NSString stringWithFormat:@"%@", fresh.filters]);

        CALayer *layer = leaf(NO);
        CGColorRef red = color(1, 0, 0, 1);
        [layer setValue:(__bridge id)red forKey:@"contentsMultiplyColor"];
        revenant_check([layer valueForKey:@"contentsMultiplyColor"] == (__bridge id)red, "the color reads back", @"another value");
        revenant_check(our_filters(layer) == 1 && layer.filters.count == 1, "a tint is one filter", [NSString stringWithFormat:@"%@", layer.filters]);
        [layer setValue:(__bridge id)color(0, 0, 1, 1) forKey:@"contentsMultiplyColor"];
        revenant_check(our_filters(layer) == 1 && layer.filters.count == 1, "a new tint keeps one filter", [NSString stringWithFormat:@"%@", layer.filters]);
        expect_pixels("a new tint draws the new color", render(layer), system_render(NO, color(0, 0, 1, 1)));
        [layer setValue:nil forKey:@"contentsMultiplyColor"];
        revenant_check([layer valueForKey:@"contentsMultiplyColor"] == nil, "a nil tint reads back nil", @"a value");
        revenant_check(layer.filters == nil, "a nil tint removes the filter", [NSString stringWithFormat:@"%@", layer.filters]);
        expect_pixels("a nil tint draws the contents", render(layer), untinted);
        [layer setValue:(__bridge id)color(1, 1, 1, 1) forKey:@"contentsMultiplyColor"];
        revenant_check(layer.filters == nil, "a white tint costs no filter", [NSString stringWithFormat:@"%@", layer.filters]);
        expect_pixels("a white tint draws the contents", render(layer), untinted);

        CALayer *shared = leaf(NO);
        id invert = app_filter();
        shared.filters = @[invert];
        [shared setValue:(__bridge id)red forKey:@"contentsMultiplyColor"];
        revenant_check(shared.filters.count == 2 && our_filters(shared) == 1 && [[shared.filters[0] valueForKey:@"name"] isEqual:OurName], "a tint goes before the application's filter", [NSString stringWithFormat:@"%@", shared.filters]);
        shared.filters = @[invert];
        revenant_check(shared.filters.count == 2 && our_filters(shared) == 1, "replacing the filters keeps the tint", [NSString stringWithFormat:@"%@", shared.filters]);
        shared.filters = [shared.filters arrayByAddingObject:app_filter()];
        revenant_check(shared.filters.count == 3 && our_filters(shared) == 1, "filters read and written back hold one tint", [NSString stringWithFormat:@"%@", shared.filters]);
        [shared setValue:nil forKey:@"contentsMultiplyColor"];
        revenant_check(shared.filters.count == 2 && our_filters(shared) == 0, "removing the tint keeps the application's filters", [NSString stringWithFormat:@"%@", shared.filters]);
        CALayer *untouched = leaf(NO);
        untouched.filters = @[invert];
        revenant_check(untouched.filters.count == 1, "a layer without a tint keeps its filters as set", [NSString stringWithFormat:@"%@", untouched.filters]);

        CALayer *animated = leaf(NO);
        CGColorRef green = color(0, 1, 0, 1);
        [animated setValue:(__bridge id)color(1, 1, 1, 1) forKey:@"contentsMultiplyColor"];
        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"contentsMultiplyColor"];
        animation.fromValue = (__bridge id)green;
        animation.toValue = (__bridge id)green;
        animation.duration = 1000;
        [animated addAnimation:animation forKey:@"tint"];
        CAPropertyAnimation *added = (CAPropertyAnimation *)[animated animationForKey:@"tint"];
        revenant_check([added.keyPath isEqualToString:OurKeyPath], "an animation of the tint drives the filter", added.keyPath);
        revenant_check([animation.keyPath isEqualToString:@"contentsMultiplyColor"], "the caller's animation is not changed", animation.keyPath);
        expect_pixels("an animated tint draws its value", render(animated), system_render(NO, green));

        CALayer *keyed = leaf(NO);
        CAKeyframeAnimation *keyframes = [CAKeyframeAnimation animationWithKeyPath:@"contentsMultiplyColor"];
        keyframes.values = @[(__bridge id)red, (__bridge id)red];
        keyframes.duration = 1000;
        [keyed addAnimation:keyframes forKey:@"tint"];
        revenant_check([((CAPropertyAnimation *)[keyed animationForKey:@"tint"]).keyPath isEqualToString:OurKeyPath], "a keyframe animation of the tint drives the filter", @"another key path");
        expect_pixels("a keyframe tint on an untinted layer draws its value", render(keyed), system_render(NO, red));

        CALayer *other = leaf(NO);
        CABasicAnimation *opacity = [CABasicAnimation animationWithKeyPath:@"opacity"];
        [other addAnimation:opacity forKey:@"fade"];
        revenant_check([((CAPropertyAnimation *)[other animationForKey:@"fade"]).keyPath isEqualToString:@"opacity"] && other.filters == nil, "other animations pass through", @"changed");

        revenant_check(revenant_negative ? NO : YES, "negative control", @"the negative control is inverted");
    }
    return revenant_finish();
}
