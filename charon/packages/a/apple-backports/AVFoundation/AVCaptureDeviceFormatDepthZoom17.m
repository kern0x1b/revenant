#import "CharonAVCaptureDeviceReactions17.h"

@implementation AVCaptureDeviceFormat (CharonCaptureDeviceFormatDepthZoom17)

- (NSArray<AVZoomRange *> *)supportedVideoZoomRangesForDepthDataDelivery
{
    return [NSArray array];
}

- (BOOL)zoomFactorsOutsideOfVideoZoomRangesForDepthDeliverySupported
{
    return NO;
}

@end
