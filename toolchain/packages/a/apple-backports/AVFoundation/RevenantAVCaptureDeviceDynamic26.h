#if !defined(__IPHONE_26_0)
#import <Foundation/Foundation.h>
#import <AVFoundation/AVBase.h>
#import <AVFoundation/AVCaptureDevice.h>
#import <AVFoundation/AVCaptureInput.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString *AVCaptureAspectRatio NS_TYPED_ENUM;

typedef NS_ENUM(NSInteger, AVCaptureCameraLensSmudgeDetectionStatus) {
    AVCaptureCameraLensSmudgeDetectionStatusDisabled          = 0,
    AVCaptureCameraLensSmudgeDetectionStatusSmudgeNotDetected = 1,
    AVCaptureCameraLensSmudgeDetectionStatusSmudged           = 2,
    AVCaptureCameraLensSmudgeDetectionStatusUnknown           = 3,
} API_AVAILABLE(ios(26.0));

@interface AVCaptureDevice (RevenantCaptureDeviceDynamic26)

@property(nonatomic, readonly, nullable) AVCaptureAspectRatio dynamicAspectRatio API_AVAILABLE(ios(26.0));
@property(nonatomic, readonly) CMVideoDimensions dynamicDimensions API_AVAILABLE(ios(26.0));
- (void)setDynamicAspectRatio:(AVCaptureAspectRatio)dynamicAspectRatio completionHandler:(nullable void (^)(CMTime syncTime, NSError * _Nullable error))handler API_AVAILABLE(ios(26.0));
- (void)setCameraLensSmudgeDetectionEnabled:(BOOL)cameraLensSmudgeDetectionEnabled detectionInterval:(CMTime)detectionInterval API_AVAILABLE(ios(26.0));
@property(nonatomic, readonly, getter=isCameraLensSmudgeDetectionEnabled) BOOL cameraLensSmudgeDetectionEnabled API_AVAILABLE(ios(26.0));
@property(nonatomic, readonly) CMTime cameraLensSmudgeDetectionInterval API_AVAILABLE(ios(26.0));
@property(nonatomic, readonly) AVCaptureCameraLensSmudgeDetectionStatus cameraLensSmudgeDetectionStatus API_AVAILABLE(ios(26.0));

@end

@interface AVCaptureDeviceFormat (RevenantCaptureDeviceFormatDynamic26)

@property(nonatomic, readonly, getter=isCameraLensSmudgeDetectionSupported) BOOL cameraLensSmudgeDetectionSupported API_AVAILABLE(ios(26.0));
@property(nonatomic, readonly) float defaultSimulatedAperture API_AVAILABLE(ios(26.0));
@property(nonatomic, readonly) float minSimulatedAperture API_AVAILABLE(ios(26.0));
@property(nonatomic, readonly) float maxSimulatedAperture API_AVAILABLE(ios(26.0));
@property(nonatomic, readonly, copy) NSArray<AVCaptureAspectRatio> *supportedDynamicAspectRatios API_AVAILABLE(ios(26.0));

@end

@interface AVCaptureDeviceInput (RevenantCaptureDeviceInputDynamic26)

@property(nonatomic) float simulatedAperture API_AVAILABLE(ios(26.0));

@end

NS_ASSUME_NONNULL_END

#else
#import <AVFoundation/AVCaptureDevice.h>
#import <AVFoundation/AVCaptureInput.h>
#endif
