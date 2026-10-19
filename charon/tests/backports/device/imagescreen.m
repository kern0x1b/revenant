#import <UIKit/UIKit.h>
#include <dlfcn.h>
#import <objc/message.h>
#import "check.h"

static NSString *image_of(const void *address)
{
    Dl_info info;
    return dladdr(address, &info) ? @(info.dli_fname).lastPathComponent : @"?";
}

static CGImageRef make_pixels(int width, int height)
{
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, 0, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGContextSetRGBFillColor(context, 1, 0, 0, 1);
    CGContextFillRect(context, CGRectMake(0, 0, width / 2, height));
    CGImageRef pixels = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    CGColorSpaceRelease(space);
    return pixels;
}

int main(void)
{
    @autoreleasepool {
        CHECK_EQUAL(image_of((const void *)[UIImage instanceMethodForSelector:@selector(imageWithHorizontallyFlippedOrientation)]),
                    @"libUIKitBackports.dylib", "-imageWithHorizontallyFlippedOrientation comes from the backports library");
        CHECK_EQUAL(image_of((const void *)[UIScreen instanceMethodForSelector:@selector(maximumFramesPerSecond)]),
                    @"libUIKitBackports.dylib", "-maximumFramesPerSecond comes from the backports library");

        UIScreen *screen = [UIScreen mainScreen];
        double interval = [(id)screen respondsToSelector:@selector(_refreshRate)] ? ((double (*)(id, SEL))objc_msgSend)(screen, @selector(_refreshRate)) : -1;
        printf("the release's own refresh interval is %g\n", interval);
        CHECK(interval == 0 || (interval > 0.01 && interval < 0.02),
              "the release answers the refresh rate of the display as an interval in seconds, or 0 where the display keeps none");
        CHECK(screen.maximumFramesPerSecond == 60, "the main screen runs at 60 frames a second, from the interval or, with none, as the release says");

        CGImageRef pixels = make_pixels(8, 4);
        BOOL mirrored = YES, doubled = YES, sameShape = YES;
        for (NSInteger orientation = 0; orientation < 8; orientation++) {
            UIImage *image = [UIImage imageWithCGImage:pixels scale:2 orientation:(UIImageOrientation)orientation];
            UIImage *flipped = [image imageWithHorizontallyFlippedOrientation];
            mirrored = mirrored && flipped.imageOrientation == (UIImageOrientation)((orientation + 4) % 8);
            doubled = doubled && [flipped imageWithHorizontallyFlippedOrientation].imageOrientation == image.imageOrientation;
            sameShape = sameShape && CGSizeEqualToSize(flipped.size, image.size) && flipped.scale == 2 && flipped.CGImage == image.CGImage
                        && flipped != image;
        }
        CHECK(mirrored, "each of the eight orientations becomes the mirrored one, four places on");
        CHECK(doubled, "flipping twice gives the orientation back");
        CHECK(sameShape, "the flipped image keeps its size, its scale and its pixels, and is another image");

        UIImage *base = [UIImage imageWithCGImage:pixels scale:1 orientation:UIImageOrientationLeft];
        UIImage *all = [[[base resizableImageWithCapInsets:UIEdgeInsetsMake(1, 2, 1, 2) resizingMode:UIImageResizingModeTile]
            imageWithAlignmentRectInsets:UIEdgeInsetsMake(0, 1, 0, 1)] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        UIImage *flippedAll = [all imageWithHorizontallyFlippedOrientation];
        CHECK(UIEdgeInsetsEqualToEdgeInsets(flippedAll.capInsets, UIEdgeInsetsMake(1, 2, 1, 2)) && flippedAll.resizingMode == UIImageResizingModeTile
              && UIEdgeInsetsEqualToEdgeInsets(flippedAll.alignmentRectInsets, UIEdgeInsetsMake(0, 1, 0, 1))
              && flippedAll.renderingMode == UIImageRenderingModeAlwaysTemplate && flippedAll.imageOrientation == UIImageOrientationLeftMirrored,
              "the cap insets, the resizing mode, the alignment insets and the rendering mode are kept");

        UIImage *frames = [UIImage animatedImageWithImages:@[base, [UIImage imageWithCGImage:pixels]] duration:0.5];
        UIImage *flippedFrames = [frames imageWithHorizontallyFlippedOrientation];
        CHECK(flippedFrames.images.count == 2 && flippedFrames.duration == 0.5, "an animated image keeps its frames and its duration");
        CGImageRelease(pixels);

        printf("%d checks, %d failures\n", charon_checks, charon_failures);
        return charon_failures;
    }
}
