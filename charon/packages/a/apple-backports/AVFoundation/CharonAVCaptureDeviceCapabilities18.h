// CharonAVCaptureDeviceCapabilities18.h - the fifteen members AVCaptureDevice, AVCaptureDeviceFormat and
// AVCaptureDeviceInput gained in iOS 18, and the three types their signatures name. SDK 16.4 declares none
// of them: its AVCaptureDevice.h has no autoVideoFrameRateEnabled, no backgroundReplacement, no
// spatialCaptureDiscomfortReasons and no systemRecommendedVideoZoomRange, and its AVCaptureInput.h has no
// multichannelAudioMode, so every typedef, forward declaration and member below is the port's own to
// declare. This is what this package's CharonAVCaptureControls18.h and CharonAVCaptureDeviceReactions17.h do
// for surface that arrived after the SDK the toolchain resolves.
//
//   iPhoneOS26.2.sdk/System/Library/Frameworks/AVFoundation.framework/Headers/AVCaptureDevice.h:396-404,
//       :1982-1989, :2513-2531, :2647-2677, :2960-2999 (AVExposureBiasRange), :3272-3281, :3304-3313,
//       :3503-3510, :3551-3555, :3731-3748
//   iPhoneOS26.2.sdk/System/Library/Frameworks/AVFoundation.framework/Headers/AVCaptureInput.h:353-397,
//       :400-417
//
// THE GUARD is the SDK's own knowledge of iOS 18 and not the name of a header, which is what the two
// headers above this one test for. These members live in AVCaptureDevice.h and AVCaptureInput.h in every SDK
// that declares them, so there is no header of their own to ask __has_include about, and a guard of the
// wrong shape would use this copy of the declarations beside a newer SDK's declarations - a duplicate interface,
// measured as one by tests/backports/host/avf-globals for the controls family. MEASURED, the two SDKs this
// repository builds against: `clang -dM -E` over <Foundation/Foundation.h> defines __IPHONE_18_0 in the host
// SDK (MacOSX.sdk) and does not define it in SDK 16.4, and the host SDK's AVCaptureDevice.h declares all
// fifteen of these members.
//
// The declarations are the 26.2 interface's, written for this port, with ONE change, stated here rather than made silently: every
// `visionos` word is dropped from the availability annotations. SDK 16.4's os/availability.h expands
// API_AVAILABLE and API_UNAVAILABLE over the platform names it knows and fails on any other - measured: a
// typedef carrying `API_AVAILABLE(macos(15.0), ios(18.0), macCatalyst(18.0), tvos(18.0))
// API_UNAVAILABLE(watchos, visionos)` is `error: expected ','` reported at the closing token, and `API_UNAVAILABLE
// (visionos)` alone is the same error while `API_UNAVAILABLE(watchos)` alone compiles clean. So `watchos`
// is kept, as the interface has it, and only `visionos` goes. Nothing is lost: it marks a platform this port does not
// build for. (This is the same drop CharonAVCaptureControls18.h makes for the same reason, measured there
// for API_AVAILABLE alone.)
//
// The names the port adds beyond the SDK are listed in the delivery for rule R4.
#if !defined(__IPHONE_18_0)
#import <Foundation/Foundation.h>
#import <AVFoundation/AVBase.h>
// AVCaptureDevice, AVCaptureDeviceFormat and AVCaptureDeviceInput are all declared in the 16.4 SDK's
// AVCaptureDevice.h and AVCaptureInput.h, which is why there is no import of their own here.
#import <AVFoundation/AVCaptureDevice.h>
#import <AVFoundation/AVCaptureInput.h>

NS_ASSUME_NONNULL_BEGIN

/// The modes of multichannel audio, as AVCaptureDeviceInput's multichannelAudioMode and
/// -isMultichannelAudioModeSupported: take them (AVCaptureInput.h:353-397).
typedef NS_ENUM(NSInteger, AVCaptureMultichannelAudioMode) {
    AVCaptureMultichannelAudioModeNone                 = 0,
    AVCaptureMultichannelAudioModeStereo               = 1,
    AVCaptureMultichannelAudioModeFirstOrderAmbisonics = 2,
} API_AVAILABLE(ios(18.0)) API_UNAVAILABLE(watchos);

/// One reason a scene is not comfortable to watch as a spatial capture (AVCaptureDevice.h:2647-2664). The two
/// constants of this type are 18.0 rows of their own and are not carried here, so nothing in this header
/// declares them and no caller can read one; the type is what AVCaptureDevice.spatialCaptureDiscomfortReasons
/// hands back, and an empty set of them.
typedef NSString *AVSpatialCaptureDiscomfortReason NS_TYPED_ENUM API_AVAILABLE(ios(18.0));

/// The span of exposure bias values a format can take, in EV units: what AVCaptureDeviceFormat's
/// systemRecommendedExposureBiasRange hands back (AVCaptureDevice.h:2960-2999). The 16.4 SDK declares
/// neither this class nor its members: its own rows are a family of their own, and this header only needs
/// the name to spell the property's type, which is what a forward declaration is.
@class AVExposureBiasRange;

/// A range of supported zoom factors, what AVCaptureDeviceFormat's systemRecommendedVideoZoomRange hands back
/// (AVCaptureDevice.h:3272-3281). The 16.4 SDK declares no AVZoomRange either; its own rows are a family of
/// their own.
@class AVZoomRange;

@interface AVCaptureDevice (CharonCaptureDeviceCapabilities18)

// AV_INIT_UNAVAILABLE is not on this category: these are members of a class every release already carries,
// and what the header says about them is in the availability annotation of each.

@property(nonatomic, getter=isAutoVideoFrameRateEnabled) BOOL autoVideoFrameRateEnabled API_AVAILABLE(ios(18.0));
@property(nonatomic, readonly, getter=isBackgroundReplacementActive) BOOL backgroundReplacementActive API_AVAILABLE(ios(18.0));
@property(class, readonly, getter=isBackgroundReplacementEnabled) BOOL backgroundReplacementEnabled API_AVAILABLE(ios(18.0));
@property(nonatomic, readonly) CGFloat displayVideoZoomFactorMultiplier API_AVAILABLE(ios(18.0));
@property(nonatomic, readonly) NSSet<AVSpatialCaptureDiscomfortReason> *spatialCaptureDiscomfortReasons API_AVAILABLE(ios(18.0));

@end

@interface AVCaptureDeviceFormat (CharonCaptureDeviceFormatCapabilities18)

@property(nonatomic, readonly, getter=isAutoVideoFrameRateSupported) BOOL autoVideoFrameRateSupported API_AVAILABLE(ios(18.0));
@property(nonatomic, readonly, getter=isBackgroundReplacementSupported) BOOL backgroundReplacementSupported API_AVAILABLE(ios(18.0));
@property(nonatomic, readonly, getter=isSpatialVideoCaptureSupported) BOOL spatialVideoCaptureSupported API_AVAILABLE(ios(18.0));
@property(nonatomic, readonly, nullable) AVExposureBiasRange *systemRecommendedExposureBiasRange API_AVAILABLE(ios(18.0));
@property(nonatomic, readonly, nullable) AVZoomRange *systemRecommendedVideoZoomRange API_AVAILABLE(ios(18.0));
@property(nonatomic, readonly, nullable) AVFrameRateRange *videoFrameRateRangeForBackgroundReplacement API_AVAILABLE(ios(18.0));

@end

@interface AVCaptureDeviceInput (CharonCaptureDeviceInputCapabilities18)

- (BOOL)isMultichannelAudioModeSupported:(AVCaptureMultichannelAudioMode)multichannelAudioMode API_AVAILABLE(ios(18.0));
@property(nonatomic) AVCaptureMultichannelAudioMode multichannelAudioMode API_AVAILABLE(ios(18.0));
@property(nonatomic, readonly, getter=isWindNoiseRemovalSupported) BOOL windNoiseRemovalSupported API_AVAILABLE(ios(18.0));
@property(nonatomic, getter=isWindNoiseRemovalEnabled) BOOL windNoiseRemovalEnabled API_AVAILABLE(ios(18.0));

@end

NS_ASSUME_NONNULL_END

#else
#import <AVFoundation/AVCaptureDevice.h>
#import <AVFoundation/AVCaptureInput.h>
#endif
