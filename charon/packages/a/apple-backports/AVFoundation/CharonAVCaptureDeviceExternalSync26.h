// CharonAVCaptureDeviceExternalSync26.h - the eleven members of iOS 26's external sync and locked frame
// duration, over AVCaptureDevice and AVCaptureDeviceInput. SDK 16.4 declares none of them: its
// AVCaptureDevice.h has no videoFrameDurationLocked, no minSupportedLockedVideoFrameDuration, no
// followingExternalSyncDevice and no minSupportedExternalSyncFrameDuration, and its AVCaptureInput.h has no
// lockedVideoFrameDurationSupported, no activeLockedVideoFrameDuration, no externalSyncSupported, no
// externalSyncDevice, no activeExternalSyncVideoFrameDuration and neither of the two external-sync methods.
//
//   iPhoneOS26.2.sdk/System/Library/Frameworks/AVFoundation.framework/Headers/AVCaptureDevice.h:376-393
//   iPhoneOS26.2.sdk/System/Library/Frameworks/AVFoundation.framework/Headers/AVCaptureInput.h:286-350
//
// The two methods below carry no API_AVAILABLE annotation where 26.2 puts one on them, and that is stated
// rather than done silently: the annotation on a void method with no 26.0 type in its signature guards nothing
// a caller can reach, and the definitions in AVCaptureDeviceExternalSync26.m carry API_AVAILABLE(ios(26.0))
// instead - which is where AVCaptureControls18.m puts it for the same reason.
//
// Nothing here names a type the SDK does not declare except AVExternalSyncDevice, which is forward-declared:
// it is iOS 26's own class with its own rows (its six properties, its -init and +new, its discovery session
// and its delegate protocol are a family of their own in the ledger), and this header needs only the name to
// spell -externalSyncDevice's type. No instance of it is ever made here - see the object.
//
// THE GUARD is the SDK's own knowledge of iOS 26, for the reason CharonAVCaptureDeviceCapabilities18.h gives,
// and the `visionos` drop from the availability annotations is that header's, measured: SDK 16.4's
// os/availability.h fails to expand `API_UNAVAILABLE(visionos)` while `API_UNAVAILABLE(watchos)` compiles.
#if !defined(__IPHONE_26_0)
#import <Foundation/Foundation.h>
#import <AVFoundation/AVBase.h>
#import <AVFoundation/AVCaptureDevice.h>
#import <AVFoundation/AVCaptureInput.h>

NS_ASSUME_NONNULL_BEGIN

/// The delegate an external sync device's owner implements, named by -followExternalSyncDevice:...delegate:.
/// iOS 26's own protocol with two methods of its own, a family of its own in the ledger, and forward-declared
/// here for the same reason as the class: a caller that conforms needs the name to resolve, and this port
/// never sends either message because it never follows a device.
@protocol AVExternalSyncDeviceDelegate;

/// An external sync device - a genlock or a house-sync box an input can follow. iOS 26's own class, and not
/// carried here: its rows are a family of their own, so this header only names it, which is what
/// -externalSyncDevice's signature needs.
@class AVExternalSyncDevice;

@interface AVCaptureDevice (CharonCaptureDeviceExternalSync26)

@property(nonatomic, readonly, getter=isVideoFrameDurationLocked) BOOL videoFrameDurationLocked API_AVAILABLE(ios(26.0));
@property(nonatomic, readonly) CMTime minSupportedLockedVideoFrameDuration API_AVAILABLE(ios(26.0));
@property(nonatomic, readonly, getter=isFollowingExternalSyncDevice) BOOL followingExternalSyncDevice API_AVAILABLE(ios(26.0));
@property(nonatomic, readonly) CMTime minSupportedExternalSyncFrameDuration API_AVAILABLE(ios(26.0));

@end

@interface AVCaptureDeviceInput (CharonCaptureDeviceInputExternalSync26)

@property(nonatomic, readonly, getter=isLockedVideoFrameDurationSupported) BOOL lockedVideoFrameDurationSupported API_AVAILABLE(ios(26.0));
@property(nonatomic) CMTime activeLockedVideoFrameDuration API_AVAILABLE(ios(26.0));
@property(nonatomic, readonly, getter=isExternalSyncSupported) BOOL externalSyncSupported API_AVAILABLE(ios(26.0));
@property(nonatomic, readonly) CMTime activeExternalSyncVideoFrameDuration API_AVAILABLE(ios(26.0));
@property(nonatomic, readonly, nullable) AVExternalSyncDevice *externalSyncDevice API_AVAILABLE(ios(26.0));
- (void)followExternalSyncDevice:(AVExternalSyncDevice *)externalSyncDevice videoFrameDuration:(CMTime)frameDuration delegate:(nullable id<AVExternalSyncDeviceDelegate>)delegate API_AVAILABLE(ios(26.0));
- (void)unfollowExternalSyncDevice;

@end

NS_ASSUME_NONNULL_END

#else
#import <AVFoundation/AVCaptureDevice.h>
#import <AVFoundation/AVCaptureInput.h>
#endif
