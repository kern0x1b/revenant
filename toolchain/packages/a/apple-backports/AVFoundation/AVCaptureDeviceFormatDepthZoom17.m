#import "RevenantAVCaptureDeviceReactions17.h"

@implementation AVCaptureDeviceFormat (RevenantCaptureDeviceFormatDepthZoom17)

- (NSArray<AVZoomRange *> *)supportedVideoZoomRangesForDepthDataDelivery
{
    return [NSArray array];
}

- (BOOL)zoomFactorsOutsideOfVideoZoomRangesForDepthDeliverySupported
{
    return NO;
}

@end
