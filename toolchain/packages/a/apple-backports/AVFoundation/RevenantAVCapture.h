#import <AVFoundation/AVFoundation.h>

#define CHARON_DUAL_CAMERA_TYPE @"AVCaptureDeviceTypeBuiltInDualCamera"

#define CHARON_AVFOUNDATION_UNAVAILABLE_INIT                                                                   \
    -(instancetype)init                                                                                       \
    {                                                                                                         \
                     \
        return nil;                                                                                           \
    }

NSArray *charon_capture_devices(NSArray *deviceTypes, NSString *mediaType, AVCaptureDevicePosition position);

#define CHARON_CAPTURE_SESSION_CHANGED @"CharonCaptureSessionChanged"

@interface AVCaptureDevice (CharonCaptureSessions)
- (NSArray<AVCaptureSession *> *)charon_captureSessions;
@end

@interface AVCaptureSession (CharonCaptureSessions)
- (NSArray<AVCaptureVideoPreviewLayer *> *)charon_previewLayers;
@end
