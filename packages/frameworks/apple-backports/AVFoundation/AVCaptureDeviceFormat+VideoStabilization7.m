#import <AVFoundation/AVFoundation.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@interface AVCaptureDeviceFormat (RevenantReleaseStabilization)
- (int)supportedStabilizationMethod;
@end

@implementation AVCaptureDeviceFormat (RevenantVideoStabilization)

- (BOOL)isVideoStabilizationSupported
{
    return [self supportedStabilizationMethod] == 2;
}

@end
