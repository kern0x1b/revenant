#import <AVFoundation/AVFoundation.h>

// The zoom range iOS 11.0 asks a device for, over the limit this port already carries at 7.0.
//
// 11.0's header (AVCaptureDevice.h:2047-2068) documents each of the two against the non-virtual
// case, which is every device these releases run on: the minimum is 1.0 and the maximum is the active format's
// videoMaxZoomFactor. So neither
// number is a new capability and neither is invented here - both are read out of the port's own
// 7.0 property, which is itself the release's own limit for its scale and crop.
//
// 6.1.3's AVCaptureDevice carries 100 own instance methods and no zoom of any kind among them: the
// zoom is this port's own (AVCaptureDevice+VideoZoom7.m, the release's scale and crop applied to a
// preview layer, a still connection and a data output's buffers), over a format limit that is the
// release's own too - max(1, min(width, height) * 0.0625) of the format's dimensions, read out of
// the format description 6.1.3 really has. So the maximum is that limit for the device's active
// format, and the floor is what the port's own setVideoZoomFactor: range check enforces: 7.0 raises
// NSRangeException below 1 and 6.1.3 has no second, wider lens to go below 1 with.
//
// The empty case is the release's own rather than a placeholder: 6.1.3 has an active format only
// inside a running session and 7.0 always has one, so outside a session the answer is the floor -
// which is exactly the range charon_check_zoom checks against there.

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
