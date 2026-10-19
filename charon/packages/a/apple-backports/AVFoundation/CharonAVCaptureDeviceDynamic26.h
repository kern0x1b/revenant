// CharonAVCaptureDeviceDynamic26.h - the thirteen members of iOS 26's dynamic aspect ratio, camera lens
// smudge detection and simulated aperture, and the two types their answers need. SDK 16.4 declares none of
// them: its AVCaptureDevice.h has no dynamicAspectRatio, no dynamicDimensions, no cameraLensSmudgeDetection
// and no setDynamicAspectRatio:completionHandler:, and its AVCaptureInput.h has no simulatedAperture.
//
//   iPhoneOS26.2.sdk/System/Library/Frameworks/AVFoundation.framework/Headers/AVCaptureDevice.h:2698-2736,
//       :3862-3895
//   iPhoneOS26.2.sdk/System/Library/Frameworks/AVFoundation.framework/Headers/AVCaptureInput.h:443-452
//
// Both types are the header's own and declared with the members. **Neither one's constants are carried:
// AVCaptureAspectRatio's five values (AVCaptureAspectRatio1x1, 16x9, 9x16, 4x3, 3x4) are 26.0 code+lift rows
// of their own, and AVCaptureCameraLensSmudgeDetectionStatus's four are header-ok/lift rows** - so the
// aspect-ratio array this header's member returns is empty (a device with no dynamic ratio has none to
// list) and the smudge status the device answers is the enum's Disabled value, which the header numbers 0.
//
// THE GUARD is the SDK's own knowledge of iOS 26, and the `visionos` drop from the availability annotations
// is measured: SDK 16.4's os/availability.h fails to expand `API_UNAVAILABLE(visionos)` while
// `API_UNAVAILABLE(watchos)` compiles clean.
#if !defined(__IPHONE_26_0)
#import <Foundation/Foundation.h>
#import <AVFoundation/AVBase.h>
#import <AVFoundation/AVCaptureDevice.h>
#import <AVFoundation/AVCaptureInput.h>

NS_ASSUME_NONNULL_BEGIN

/// (AVCaptureDevice.h:2698). The five values are 26.0 code+lift rows of their own and are not carried.
/// The availability annotation 26.2 puts on this typedef - API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(macos,
/// macCatalyst, tvos, visionos) - is NOT repeated here, and that is stated rather than done silently: it marks
/// this an iOS-only type, and tests/backports/host/avf-capabilities compiles a copy of the port's source
/// against the HOST SDK to ask the port and Apple's class side by side, where a macOS-unavailable type in a
/// method signature is an error rather than a warning. Dropping it changes nothing for this port, which builds
/// for iOS - and CharonAVCaptureControls18.h drops API_UNAVAILABLE(macos) for exactly the same reason.
typedef NSString *AVCaptureAspectRatio NS_TYPED_ENUM;

/// four values are the header's own, and the ledger reads them header-ok/lift rather than code.
typedef NS_ENUM(NSInteger, AVCaptureCameraLensSmudgeDetectionStatus) {
    AVCaptureCameraLensSmudgeDetectionStatusDisabled          = 0,
    AVCaptureCameraLensSmudgeDetectionStatusSmudgeNotDetected = 1,
    AVCaptureCameraLensSmudgeDetectionStatusSmudged           = 2,
    AVCaptureCameraLensSmudgeDetectionStatusUnknown           = 3,
} API_AVAILABLE(ios(26.0));

@interface AVCaptureDevice (CharonCaptureDeviceDynamic26)

@property(nonatomic, readonly, nullable) AVCaptureAspectRatio dynamicAspectRatio API_AVAILABLE(ios(26.0));
@property(nonatomic, readonly) CMVideoDimensions dynamicDimensions API_AVAILABLE(ios(26.0));
- (void)setDynamicAspectRatio:(AVCaptureAspectRatio)dynamicAspectRatio completionHandler:(nullable void (^)(CMTime syncTime, NSError * _Nullable error))handler API_AVAILABLE(ios(26.0));
- (void)setCameraLensSmudgeDetectionEnabled:(BOOL)cameraLensSmudgeDetectionEnabled detectionInterval:(CMTime)detectionInterval API_AVAILABLE(ios(26.0));
@property(nonatomic, readonly, getter=isCameraLensSmudgeDetectionEnabled) BOOL cameraLensSmudgeDetectionEnabled API_AVAILABLE(ios(26.0));
@property(nonatomic, readonly) CMTime cameraLensSmudgeDetectionInterval API_AVAILABLE(ios(26.0));
@property(nonatomic, readonly) AVCaptureCameraLensSmudgeDetectionStatus cameraLensSmudgeDetectionStatus API_AVAILABLE(ios(26.0));

@end

// Five of the seven members the 26.2 AVCaptureDeviceFormatCinematicVideoSupport category declares; the other two
// of that category (cinematicVideoCaptureSupported and the cinematic zoom factors and frame rate range) are the
// Cinematic Video rows and are declared beside the members that read them.
@interface AVCaptureDeviceFormat (CharonCaptureDeviceFormatDynamic26)

@property(nonatomic, readonly, getter=isCameraLensSmudgeDetectionSupported) BOOL cameraLensSmudgeDetectionSupported API_AVAILABLE(ios(26.0));
@property(nonatomic, readonly) float defaultSimulatedAperture API_AVAILABLE(ios(26.0));
@property(nonatomic, readonly) float minSimulatedAperture API_AVAILABLE(ios(26.0));
@property(nonatomic, readonly) float maxSimulatedAperture API_AVAILABLE(ios(26.0));
@property(nonatomic, readonly, copy) NSArray<AVCaptureAspectRatio> *supportedDynamicAspectRatios API_AVAILABLE(ios(26.0));

@end

@interface AVCaptureDeviceInput (CharonCaptureDeviceInputDynamic26)

@property(nonatomic) float simulatedAperture API_AVAILABLE(ios(26.0));

@end

NS_ASSUME_NONNULL_END

#else
#import <AVFoundation/AVCaptureDevice.h>
#import <AVFoundation/AVCaptureInput.h>
#endif
