#import <AVFoundation/AVFoundation.h>

#define REVENANT_DUAL_CAMERA_TYPE @"AVCaptureDeviceTypeBuiltInDualCamera"

#define REVENANT_AVFOUNDATION_UNAVAILABLE_INIT                                                                   \
    -(instancetype)init                                                                                       \
    {                                                                                                         \
                     \
        return nil;                                                                                           \
    }

NSArray *revenant_capture_devices(NSArray *deviceTypes, NSString *mediaType, AVCaptureDevicePosition position);

#define REVENANT_CAPTURE_SESSION_CHANGED @"RevenantCaptureSessionChanged"

@interface AVCaptureDevice (RevenantCaptureSessions)
- (NSArray<AVCaptureSession *> *)revenant_captureSessions;
@end

@interface AVCaptureSession (RevenantCaptureSessions)
- (NSArray<AVCaptureVideoPreviewLayer *> *)revenant_previewLayers;
@end
