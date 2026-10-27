#import <AVFoundation/AVFoundation.h>

@implementation AVCaptureVideoPreviewLayer (RevenantMetadataRect)

- (CGRect)metadataOutputRectOfInterestForRect:(CGRect)rect
{
    CGPoint corners[4] = {
        CGPointMake(CGRectGetMinX(rect), CGRectGetMinY(rect)),
        CGPointMake(CGRectGetMaxX(rect), CGRectGetMinY(rect)),
        CGPointMake(CGRectGetMinX(rect), CGRectGetMaxY(rect)),
        CGPointMake(CGRectGetMaxX(rect), CGRectGetMaxY(rect)),
    };
    CGFloat minX = CGFLOAT_MAX, minY = CGFLOAT_MAX, maxX = -CGFLOAT_MAX, maxY = -CGFLOAT_MAX;
    for (NSUInteger index = 0; index < 4; index++) {
        CGPoint point = [self captureDevicePointOfInterestForPoint:corners[index]];
        minX = MIN(minX, point.x);
        minY = MIN(minY, point.y);
        maxX = MAX(maxX, point.x);
        maxY = MAX(maxY, point.y);
    }
    return CGRectMake(minX, minY, maxX - minX, maxY - minY);
}

@end
