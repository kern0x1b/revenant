#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>

@implementation CIImage (RevenantCGOrientation)

- (CGAffineTransform)imageTransformForCGOrientation:(CGImagePropertyOrientation)orientation
{
    return [self imageTransformForOrientation:(int)orientation];
}

- (CIImage *)imageByApplyingCGOrientation:(CGImagePropertyOrientation)orientation
{
    return [self imageByApplyingOrientation:(int)orientation];
}

@end
