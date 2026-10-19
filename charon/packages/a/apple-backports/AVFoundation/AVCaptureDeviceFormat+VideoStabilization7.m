#import <AVFoundation/AVFoundation.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@interface AVCaptureDeviceFormat (CharonReleaseStabilization)
- (int)supportedStabilizationMethod;
@end

@implementation AVCaptureDeviceFormat (CharonVideoStabilization)

- (BOOL)isVideoStabilizationSupported
{
    return [self supportedStabilizationMethod] == 2;
}

@end
