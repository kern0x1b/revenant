#import <QuartzCore/QuartzCore.h>
#import <QuartzCore/CAMetalLayer.h>
#include <dlfcn.h>
#import <objc/runtime.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        Class cls = NSClassFromString(@"CAMetalLayer");
        CHECK(cls != Nil, "CAMetalLayer exists");
        Dl_info info;
        CHECK(dladdr((__bridge void *)cls, &info) != 0 && [@(info.dli_fname).lastPathComponent isEqualToString:@"libMetalBackports.dylib"], "it comes from the backports");
        CAMetalLayer *layer = [CAMetalLayer layer];
        CHECK([layer isKindOfClass:[CALayer class]], "it is a layer");
        CHECK(layer.device == nil, "no device to start");
        CHECK((NSUInteger)layer.pixelFormat == 80, "BGRA8 to start");
        CHECK(layer.framebufferOnly, "framebuffer only to start");
        CHECK(!layer.presentsWithTransaction, "no transaction to start");
        CHECK(layer.maximumDrawableCount == 3, "three drawables to start");
        CHECK(layer.allowsNextDrawableTimeout, "the timeout is allowed to start");
        CHECK(layer.colorspace == NULL, "no colour space to start");
        layer.bounds = CGRectMake(0, 0, 100, 50);
        layer.contentsScale = 2;
        CHECK(CGSizeEqualToSize(layer.drawableSize, CGSizeMake(200, 100)), "the drawable size follows the bounds until it is set");
        layer.drawableSize = CGSizeMake(10, 20);
        CHECK(CGSizeEqualToSize(layer.drawableSize, CGSizeMake(10, 20)), "and is what it was set to");
        layer.pixelFormat = (MTLPixelFormat)70;
        layer.framebufferOnly = NO;
        layer.presentsWithTransaction = YES;
        layer.allowsNextDrawableTimeout = NO;
        layer.maximumDrawableCount = 2;
        CHECK((NSUInteger)layer.pixelFormat == 70 && !layer.framebufferOnly && layer.presentsWithTransaction && !layer.allowsNextDrawableTimeout && layer.maximumDrawableCount == 2, "each property answers what it was set to");
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        layer.colorspace = space;
        CHECK(layer.colorspace == space, "the colour space is kept");
        CGColorSpaceRelease(space);
        CHECK([layer nextDrawable] == nil, "a layer with no device has no drawable");
        CHECK(layer.preferredDevice == nil, "there is no preferred device");
        NSString *name = nil, *reason = nil;
        @try {
            layer.maximumDrawableCount = 5;
        } @catch (NSException *exception) {
            name = exception.name;
            reason = exception.reason;
        }
        CHECK_EQUAL(name, @"CAMetalLayerInvalidMaximumDrawableCount", "a maximum outside 2 to 3 raises");
        CHECK_EQUAL(reason, @"failed trying to set maximumDrawableCount to 5 outside of the valid range of [2, 3]", "with the reason of iOS 12");
        layer.wantsExtendedDynamicRangeContent = YES;
        layer.developerHUDProperties = @{@"mode": @"default"};
        CHECK(layer.wantsExtendedDynamicRangeContent && [layer.developerHUDProperties[@"mode"] isEqualToString:@"default"], "the properties of iOS 16 keep what they are given");
        CHECK(layer.EDRMetadata == nil, "and there is no extended range metadata");
        printf("%d checks, %d failed\n", charon_checks, charon_failures);
    }
    return charon_failures;
}
