// CharonAVCaptureDeviceCinematicVideo26.h - the ten members of iOS 26's Cinematic Video capture, the string
// type one of them hands back, and the focus-mode enum the other three take. SDK 16.4 declares none of it: its AVCaptureDevice.h has no
// cinematicVideoCaptureSceneMonitoringStatuses, no CinematicVideoCaptureSupported and no
// ZoomFactorForCinematicVideo, and its AVCaptureInput.h has no cinematicVideoCaptureEnabled. So every
// declaration below is the port's own to make. This is what this package's
// CharonAVCaptureDeviceCapabilities18.h does for the same three classes a release earlier.
//
//   iPhoneOS26.2.sdk/System/Library/Frameworks/AVFoundation.framework/Headers/AVCaptureDevice.h:1299-1328,
//       :2682-2696, :3782-3818
//   iPhoneOS26.2.sdk/System/Library/Frameworks/AVFoundation.framework/Headers/AVCaptureInput.h:425-439
//
// Nothing here names a type the SDK does not declare except the one string enum, which is declared below.
//
// THE GUARD is the SDK's own knowledge of iOS 26, for the reason CharonAVCaptureDeviceCapabilities18.h gives:
// these members live in AVCaptureDevice.h and AVCaptureInput.h in every SDK that declares them, so there is no
// header of their own to ask __has_include about. MEASURED: `clang -dM -E` over <Foundation/Foundation.h>
// __IPHONE_26_0 is defined by the host SDK and absent from SDK 16.4.
//
// The declarations are the 26.2 interface's, written for this port, with ONE change, stated here rather than made silently: every `visionos` word
// is dropped from the availability annotations, because SDK 16.4's os/availability.h fails to expand one
// (measured: `API_UNAVAILABLE(visionos)` is `error: expected ','`, `API_UNAVAILABLE(watchos)` compiles clean).
//
// The names the port adds beyond the SDK are listed in the delivery for rule R4.
#if !defined(__IPHONE_26_0)
#import <Foundation/Foundation.h>
#import <AVFoundation/AVBase.h>
// AVCaptureDevice, AVCaptureDeviceFormat and AVCaptureDeviceInput are all declared in the 16.4 SDK's
// AVCaptureDevice.h and AVCaptureInput.h, which is why there is no import of their own here.
#import <AVFoundation/AVCaptureDevice.h>
#import <AVFoundation/AVCaptureInput.h>

NS_ASSUME_NONNULL_BEGIN

/// The focus behaviour when recording a Cinematic Video (AVCaptureDevice.h:1301-1308), with three values: None, Strong and Weak.
typedef NS_ENUM(NSInteger, AVCaptureCinematicVideoFocusMode) {
    AVCaptureCinematicVideoFocusModeNone   = 0,
    AVCaptureCinematicVideoFocusModeStrong = 1,
    AVCaptureCinematicVideoFocusModeWeak   = 2,
} API_AVAILABLE(ios(26.0));

/// AVCaptureSceneMonitoringStatusNotEnoughLight, is a 26.0 row of its own and is not carried here** - it is
/// an exported symbol, so the set this header's property returns is
/// empty on this release and nothing a caller can name is ever in it.
typedef NSString *AVCaptureSceneMonitoringStatus NS_TYPED_ENUM API_AVAILABLE(ios(26.0));

@interface AVCaptureDevice (CharonCaptureDeviceCinematicVideo26)

@property(nonatomic, readonly) NSSet<AVCaptureSceneMonitoringStatus> *cinematicVideoCaptureSceneMonitoringStatuses API_AVAILABLE(ios(26.0));

// The three focus methods of the same category 26.2 declares (AVCaptureDevice.h:1310-1328). Each one names a
// location in the device's own normalized coordinate space and a focus mode, and Apple's own refusal
// for all three names the format member they need. They are one line each because the 26.2 declarations are:
// a reader comparing the two headers line by line should find the same lines.
- (void)setCinematicVideoTrackingFocusWithDetectedObjectID:(NSInteger)detectedObjectID focusMode:(AVCaptureCinematicVideoFocusMode)focusMode API_AVAILABLE(ios(26.0));
- (void)setCinematicVideoTrackingFocusAtPoint:(CGPoint)point focusMode:(AVCaptureCinematicVideoFocusMode)focusMode API_AVAILABLE(ios(26.0));
- (void)setCinematicVideoFixedFocusAtPoint:(CGPoint)point focusMode:(AVCaptureCinematicVideoFocusMode)focusMode API_AVAILABLE(ios(26.0));

@end

// Six of the seven properties the 26.2 AVCaptureDeviceFormatCinematicVideoSupport category declares; the other
// three of that category (defaultSimulatedAperture, minSimulatedAperture, maxSimulatedAperture) are the
// simulated-aperture rows and are declared beside the members that set them.
@interface AVCaptureDeviceFormat (CharonCaptureDeviceFormatCinematicVideo26)

@property(nonatomic, readonly, getter=isCinematicVideoCaptureSupported) BOOL cinematicVideoCaptureSupported API_AVAILABLE(ios(26.0));
@property(nonatomic, readonly) CGFloat videoMinZoomFactorForCinematicVideo API_AVAILABLE(ios(26.0));
@property(nonatomic, readonly) CGFloat videoMaxZoomFactorForCinematicVideo API_AVAILABLE(ios(26.0));
@property(nonatomic, readonly, nullable) AVFrameRateRange *videoFrameRateRangeForCinematicVideo API_AVAILABLE(ios(26.0));

@end

@interface AVCaptureDeviceInput (CharonCaptureDeviceInputCinematicVideo26)

@property(nonatomic, readonly, getter=isCinematicVideoCaptureSupported) BOOL cinematicVideoCaptureSupported API_AVAILABLE(ios(26.0));
@property(nonatomic, getter=isCinematicVideoCaptureEnabled) BOOL cinematicVideoCaptureEnabled API_AVAILABLE(ios(26.0));

@end

NS_ASSUME_NONNULL_END

#else
#import <AVFoundation/AVCaptureDevice.h>
#import <AVFoundation/AVCaptureInput.h>
#endif
