// CharonAVCaptureDeviceRectsOfInterest26.h - the rectangles of interest AVCaptureDevice gained in iOS 26:
// the two support flags, the two minimum sizes, the two rectangles, and the two methods that give the
// default rectangle for a point of interest. SDK 16.4 declares none of it - its AVCaptureDevice.h has no
// focusRectOfInterest, no exposureRectOfInterest, no RectOfInterestSupported, no minRectOfInterestSize and
// no defaultRectFor:PointOfInterest: - so every member below is the port's own to declare. This is what this
// package's CharonAVCaptureControls18.h and CharonAVCaptureDeviceCapabilities18.h do for surface that
// arrived after the SDK the toolchain resolves.
//
//   iPhoneOS26.2.sdk/System/Library/Frameworks/AVFoundation.framework/Headers/AVCaptureDevice.h:1159-1187,
//       :1403-1429
//
// Nothing here names a type the SDK does not declare: CGPoint, CGSize, CGRect and BOOL are CoreGraphics' own
// and Foundation's, so this header adds declarations and no typedef.
//
// THE GUARD is the SDK's own knowledge of iOS 26, for the reason CharonAVCaptureDeviceCapabilities18.h gives:
// these members live in AVCaptureDevice.h in every SDK that declares them, so there is no header of their own
// to ask __has_include about, and a guard of the wrong shape would place this transcription beside a newer
// SDK's own declarations. MEASURED, the two SDKs this repository builds against: `clang -dM -E` over
// <Foundation/Foundation.h> defines __IPHONE_26_0 in the host SDK (MacOSX.sdk) and does not define it in
// SDK 16.4, and the host SDK's AVCaptureDevice.h declares all eight members below.
//
// The declarations are 26.2's own with ONE change, stated here rather than made silently: every `visionos`
// word is dropped from the availability annotations, because SDK 16.4's os/availability.h fails to expand one
// (measured in CharonAVCaptureDeviceCapabilities18.h: `API_UNAVAILABLE(visionos)` is `error: expected ','`
// while `API_UNAVAILABLE(watchos)` alone compiles clean, so watchos is Apple's own and stays).
//
// The names the port adds beyond the SDK are listed in the delivery for rule R4.
#if !defined(__IPHONE_26_0)
#import <Foundation/Foundation.h>
#import <AVFoundation/AVBase.h>
// AVCaptureDevice is declared in the 16.4 SDK's AVCaptureDevice.h, which is why there is no import of its own.
#import <AVFoundation/AVCaptureDevice.h>

NS_ASSUME_NONNULL_BEGIN

@interface AVCaptureDevice (CharonCaptureDeviceRectsOfInterest26)

@property(nonatomic, readonly, getter=isFocusRectOfInterestSupported) BOOL focusRectOfInterestSupported API_AVAILABLE(ios(26.0));
@property(nonatomic, readonly) CGSize minFocusRectOfInterestSize API_AVAILABLE(ios(26.0));
@property(nonatomic) CGRect focusRectOfInterest API_AVAILABLE(ios(26.0));
- (CGRect)defaultRectForFocusPointOfInterest:(CGPoint)pointOfInterest API_AVAILABLE(ios(26.0));

@property(nonatomic, readonly, getter=isExposureRectOfInterestSupported) BOOL exposureRectOfInterestSupported API_AVAILABLE(ios(26.0));
@property(nonatomic, readonly) CGSize minExposureRectOfInterestSize API_AVAILABLE(ios(26.0));
@property(nonatomic) CGRect exposureRectOfInterest API_AVAILABLE(ios(26.0));
- (CGRect)defaultRectForExposurePointOfInterest:(CGPoint)pointOfInterest API_AVAILABLE(ios(26.0));

@end

NS_ASSUME_NONNULL_END

#else
#import <AVFoundation/AVCaptureDevice.h>
#endif