#import "CharonGraphicsRenderer.h"

@implementation UIGraphicsImageRendererContext

- (UIImage *)currentImage
{
    CGImageRef image = CGBitmapContextCreateImage(self.CGContext);
    if (!image)
        return nil;
    CGFloat scale = [(UIGraphicsImageRendererFormat *)self.format _contextScale];
    UIImage *made = [UIImage imageWithCGImage:image scale:scale != 0 ? scale : 1 orientation:UIImageOrientationUp];
    CGImageRelease(image);
    return made;
}

@end
