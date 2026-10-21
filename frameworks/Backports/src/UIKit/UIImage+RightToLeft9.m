#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char RevenantImageFlipsKey;

@implementation UIImage (RevenantRightToLeft9)

- (BOOL)flipsForRightToLeftLayoutDirection
{
    return [objc_getAssociatedObject(self, &RevenantImageFlipsKey) boolValue];
}

- (UIImage *)imageFlippedForRightToLeftLayoutDirection
{
    UIImage *image = nil;
    if (self.images.count)
        image = [UIImage animatedImageWithImages:self.images duration:self.duration];
    else if (self.CGImage)
        image = [UIImage imageWithCGImage:self.CGImage scale:self.scale orientation:self.imageOrientation];
    else if (self.CIImage)
        image = [UIImage imageWithCIImage:self.CIImage scale:self.scale orientation:self.imageOrientation];
    if (!image)
        return self;
    UIEdgeInsets capInsets = self.capInsets;
    if (!UIEdgeInsetsEqualToEdgeInsets(capInsets, UIEdgeInsetsZero))
        image = [image resizableImageWithCapInsets:capInsets resizingMode:self.resizingMode];
    UIEdgeInsets alignmentInsets = self.alignmentRectInsets;
    if (!UIEdgeInsetsEqualToEdgeInsets(alignmentInsets, UIEdgeInsetsZero))
        image = [image imageWithAlignmentRectInsets:alignmentInsets];
    if (self.renderingMode != UIImageRenderingModeAutomatic)
        image = [image imageWithRenderingMode:self.renderingMode];
    objc_setAssociatedObject(image, &RevenantImageFlipsKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return image;
}

@end
