#import <UIKit/UIKit.h>

@implementation UIImage (CharonHorizontalFlip)

- (UIImage *)imageWithHorizontallyFlippedOrientation
{
    UIImageOrientation orientation = self.imageOrientation;
    UIImageOrientation flipped = orientation < 8 ? (UIImageOrientation)((orientation + 4) % 8) : orientation;
    UIImage *image = nil;
    if (self.images.count)
        image = [UIImage animatedImageWithImages:self.images duration:self.duration];
    else if (self.CGImage)
        image = [UIImage imageWithCGImage:self.CGImage scale:self.scale orientation:flipped];
    else if (self.CIImage)
        image = [UIImage imageWithCIImage:self.CIImage scale:self.scale orientation:flipped];
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
    return image;
}

@end
