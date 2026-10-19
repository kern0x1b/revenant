#import "CharonImageBaseline.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation UIImage (CharonFifteen)

- (UIImage *)imageByPreparingForDisplay
{
    if (self.images.count || !self.CGImage)
        return self;
    size_t width = CGImageGetWidth(self.CGImage);
    size_t height = CGImageGetHeight(self.CGImage);
    if (!width || !height)
        return self;
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo info = kCGBitmapByteOrder32Host | kCGImageAlphaPremultipliedFirst;
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, 0, space, info);
    CGColorSpaceRelease(space);
    if (!context)
        return self;
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), self.CGImage);
    CGImageRef decoded = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    if (!decoded)
        return self;
    UIImage *result = [UIImage imageWithCGImage:decoded scale:self.scale orientation:self.imageOrientation];
    CGImageRelease(decoded);
    if (!result)
        return self;
    UIEdgeInsets capInsets = self.capInsets;
    if (!UIEdgeInsetsEqualToEdgeInsets(capInsets, UIEdgeInsetsZero))
        result = [result resizableImageWithCapInsets:capInsets resizingMode:self.resizingMode];
    UIEdgeInsets alignmentInsets = self.alignmentRectInsets;
    if (!UIEdgeInsetsEqualToEdgeInsets(alignmentInsets, UIEdgeInsetsZero))
        result = [result imageWithAlignmentRectInsets:alignmentInsets];
    if (self.renderingMode != UIImageRenderingModeAutomatic)
        result = [result imageWithRenderingMode:self.renderingMode];
    charon_set_image_baseline(result, charon_image_baseline(self));
    return result;
}

// The system hands the prepared image to the handler from a queue of its own.
- (void)prepareForDisplayWithCompletionHandler:(void (^)(UIImage *))completionHandler
{
    void (^handler)(UIImage *) = [completionHandler copy];
    if (!handler)
        return;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        handler([self imageByPreparingForDisplay]);
    });
}

// A bitmap of exactly the size asked, in pixels at scale 1, with the image drawn
// upright and stretched to fill it.
- (UIImage *)imageByPreparingThumbnailOfSize:(CGSize)size
{
    size_t width = (size_t)ceil(size.width), height = (size_t)ceil(size.height);
    if (!(size.width > 0) || !(size.height > 0) || (!self.CGImage && !self.CIImage))
        return nil;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(width, height), NO, 1);
    [self drawInRect:CGRectMake(0, 0, width, height)];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

- (void)prepareThumbnailOfSize:(CGSize)size completionHandler:(void (^)(UIImage *))completionHandler
{
    void (^handler)(UIImage *) = [completionHandler copy];
    if (!handler)
        return;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        handler([self imageByPreparingThumbnailOfSize:size]);
    });
}

@end
