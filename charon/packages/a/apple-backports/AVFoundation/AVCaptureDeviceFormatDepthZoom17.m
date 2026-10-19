// AVCaptureDeviceFormatDepthZoom17.m - the two members iOS 17.2 added to AVCaptureDeviceFormat, their own
// object because their own release: 17.2 is not 17.0, and one object holds API of one release.
//
// Both answers are Apple's own for this port's hardware, and one of them the host agrees with exactly:
//
//   -supportedVideoZoomRangesForDepthDataDelivery   an empty array. "The video zoom ranges supported for
//       depth data delivery" (AVCaptureDeviceFormat.h): this camera has no depth sensor, so no zoom range
//       of it feeds depth delivery. Measured: this host's own camera answers an empty array here as well,
//       for the same reason.
//   -zoomFactorsOutsideOfVideoZoomRangesForDepthDeliverySupported   NO. Measured: NO on this host's own
//       camera as well, so this row's answer is not only the port's judgement about its own hardware.
//
// facts/AVFoundation/CaptureDeviceReactions.md has both host measurements, the run that asks the port and
// the host side by side, and the mutation that proves the run can fail.
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