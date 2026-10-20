#import <AVFoundation/AVFoundation.h>

static const CGFloat RevenantVideoZoomRangeFloor = 1;

@implementation AVCaptureDevice (RevenantVideoZoomRange)

- (CGFloat)maxAvailableVideoZoomFactor
{
    AVCaptureDeviceFormat *format = self.activeFormat;
    return format ? format.videoMaxZoomFactor : RevenantVideoZoomRangeFloor;
}

- (CGFloat)minAvailableVideoZoomFactor
{
    return RevenantVideoZoomRangeFloor;
}

@end
