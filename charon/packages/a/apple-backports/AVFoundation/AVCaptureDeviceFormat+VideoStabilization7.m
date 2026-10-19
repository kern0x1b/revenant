#import <AVFoundation/AVFoundation.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

// 6.0 to 6.1.x read a format's stabilization from its own dictionary with -supportedStabilizationMethod,
// the release's own method on its own class; 7.0 answers that method with isVideoStabilizationSupported
// ? 2 : 0, so a format supports stabilization when the method answers 2 (facts/AVFoundation/VideoStabilization.md).

@interface AVCaptureDeviceFormat (CharonReleaseStabilization)
- (int)supportedStabilizationMethod;
@end

@implementation AVCaptureDeviceFormat (CharonVideoStabilization)

- (BOOL)isVideoStabilizationSupported
{
    return [self supportedStabilizationMethod] == 2;
}

@end
