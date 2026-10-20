#import "../RevenantSayOnce.h"

#import <AVFoundation/AVFoundation.h>

@implementation AVCaptureConnection (RevenantCameraIntrinsics)

- (BOOL)isCameraIntrinsicMatrixDeliverySupported
{
    return NO;
}

- (BOOL)isCameraIntrinsicMatrixDeliveryEnabled
{
    return NO;
}

- (void)setCameraIntrinsicMatrixDeliveryEnabled:(BOOL)enabled
{
    if (enabled)
        revenant_say_once_for(@"AVCaptureConnection.cameraIntrinsicMatrixDeliveryEnabled",
                            @"AVCaptureConnection on iOS 6 has no camera intrinsics to deliver: no depth capture output, "
                            @"no calibration data and no class or protocol of 6.1.3 or 4.3 carries the name, so "
                            @"cameraIntrinsicMatrixDeliverySupported answers NO and this flag cannot be honoured");
}

@end
