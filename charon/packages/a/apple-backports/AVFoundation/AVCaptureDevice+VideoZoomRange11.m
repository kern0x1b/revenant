#import <AVFoundation/AVFoundation.h>

static const CGFloat CharonVideoZoomRangeFloor = 1;

@implementation AVCaptureDevice (CharonVideoZoomRange)

- (CGFloat)maxAvailableVideoZoomFactor
{
    AVCaptureDeviceFormat *format = self.activeFormat;
    return format ? format.videoMaxZoomFactor : CharonVideoZoomRangeFloor;
}

- (CGFloat)minAvailableVideoZoomFactor
{
    return CharonVideoZoomRangeFloor;
}

@end
