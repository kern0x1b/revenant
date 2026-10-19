#import "../CharonSayOnce.h"

#import <AVFoundation/AVFoundation.h>

// The camera intrinsics delivery of iOS 11.0, as the support probe the capture policy asks for.
//
// 11.0 puts the calibrated camera intrinsics on a connection (AVCaptureSession.h:978-995, the
// properties are declared on AVCaptureConnection) and asks first whether the connection can deliver
// them. This port's answer to that question is NO, and it is measured rather than assumed: no class
// or protocol name of iOS 6.1.3 (11378 classes, 1171 protocols) or of 4.3 (7187 and 564) contains
// "Intrinsic", neither release has a depth capture output, a depth format or a calibration object to
// deliver one from, and 6.1.3's AVCaptureConnection is 56 instance and 3 class selectors that end at
// scale and crop, frame duration and its bounds, orientation, mirroring, retained buffer count, audio
// levels, active and enabled, and the stabilization switch. There is no matrix here to hand an
// application, on any device these releases run on.
//
// So the probe answers NO and the flag answers NO, and asking for the flag is refused where it can
// be seen - the flag keeps answering NO - and said once in the log, which is the shape
// AVCaptureSession.usesApplicationAudioSession already carries for a negotiation 6.x cannot honour
// (AVCaptureSession+ApplicationAudioSession7.m). An application that gates on the probe is told the
// truth instead of raising on the flag.
//
// The header declares both with getter=is... (AVCaptureSession.h:985 and :995), so the selectors
// defined here are the ones the header names and the ones an application compiled against the real
// SDK sends: -isCameraIntrinsicMatrixDeliverySupported, -isCameraIntrinsicMatrixDeliveryEnabled and
// -setCameraIntrinsicMatrixDeliveryEnabled:. Nothing here hooks a release method and nothing is
// stored; there is no delivery to switch on.

@implementation AVCaptureConnection (CharonCameraIntrinsics)

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
        charon_say_once_for(@"AVCaptureConnection.cameraIntrinsicMatrixDeliveryEnabled",
                            @"AVCaptureConnection on iOS 6 has no camera intrinsics to deliver: no depth capture output, "
                            @"no calibration data and no class or protocol of 6.1.3 or 4.3 carries the name, so "
                            @"cameraIntrinsicMatrixDeliverySupported answers NO and this flag cannot be honoured");
}

@end
