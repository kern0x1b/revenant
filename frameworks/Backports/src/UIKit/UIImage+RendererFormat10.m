#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation UIImage (RevenantRendererFormat10)

- (UIGraphicsImageRendererFormat *)imageRendererFormat
{
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.scale = self.scale;
    CGImageAlphaInfo alpha = self.CGImage ? CGImageGetAlphaInfo(self.CGImage) : kCGImageAlphaPremultipliedLast;
    format.opaque = alpha == kCGImageAlphaNone || alpha == kCGImageAlphaNoneSkipFirst || alpha == kCGImageAlphaNoneSkipLast;
    return format;
}

@end
