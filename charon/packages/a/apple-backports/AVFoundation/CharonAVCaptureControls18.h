// CharonAVCaptureControls18.h - AVCaptureSession's controls API, declared from the SDK 26.2 header the
// port is written against. SDK 16.4 ships no AVCaptureControl.h and declares none of the controls API on
// AVCaptureSession (AVCaptureSession.h has no "AVCaptureControl" in it at all), so the class below and the
// category that carries the session's members are the port's own to declare; this is what this package's
// CharonAVMetrics18.h and CharonAVFoundationCaption18.h do for surface that arrived after the SDK the
// toolchain resolves.
//
//   iPhoneOS26.2.sdk/System/Library/Frameworks/AVFoundation.framework/Headers/AVCaptureControl.h
//   iPhoneOS26.2.sdk/System/Library/Frameworks/AVFoundation.framework/Headers/AVCaptureSession.h:373-479,
//                                                                   :578-585, :733-792
//
// The declarations below are the 26.2 interface's, written for this port, with TWO changes, stated here rather than made silently:
//
//   * all `, visionos(<version>)` and `, watchos(<version>)` are DROPPED from the availability annotations.
//     SDK 16.4's availability.h does not know the words, and expanding one there is `error: expected ','`
//     on the line after the macro's own argument. Nothing is lost: the annotations mark platforms this
//     port does not build for.
//
//   * `API_UNAVAILABLE(macos, visionos)` on -configuresApplicationAudioSessionToMixWithOthers becomes
//     nothing, for the same reason and with the same loss, EXCEPT that the property is one the macOS
//     headers do not carry at all (measured: this host's AVCaptureSession.h:564 marks it unavailable,
//     and the runtime answers the selector while no caller may send it). The property is iOS and tvOS's,
//     and this port builds for iOS.
//
// The names the port adds beyond the SDK are listed in the delivery for rule R4.
//
// The protocol is NOT declared here: AVCaptureSessionControlsDelegate belongs to
// CharonAVFoundationProtocols.h, which is the header modules/apple/backports.lua's generated protocol
// sources import and the one tools/transcribe-protocols.py@52253c0650 writes. A second declaration of the same
// protocol in this folder would be a duplicate definition in every translation unit that sees both.
#if !__has_include(<AVFCore/AVCaptureControl.h>)
#import <Foundation/Foundation.h>
#import <AVFoundation/AVBase.h>
#import <AVFoundation/AVCaptureSession.h>

// Named here for the signatures below and defined in CharonAVFoundationProtocols.h, which is where the
// generated protocol sources find it; this is the forward declaration, not a second definition.
@protocol AVCaptureSessionControlsDelegate;

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(macos(15), ios(18), tvos(18))
@interface AVCaptureControl : NSObject

AV_INIT_UNAVAILABLE

@property(nonatomic, getter=isEnabled) BOOL enabled;

@end

// The members AVCaptureSession gained with it, as one category on the release's own class. A category
// declaration adds no metadata: it is here so that a caller, and this package's own sources, can see the
// selectors Apple's 16.4 headers do not declare. The port adds no member to this list.
// The availability is the 26.2 interface's, on the category because its signatures name AVCaptureControl, which the
// annotation above introduces in iOS 18: without it every declaration below is an unguarded use of an
// iOS 18 type at this port's deployment target (UIKit/UIAccessibilityBlocks17.h:52 is the same shape).
API_AVAILABLE(macos(15), ios(18), tvos(18))
@interface AVCaptureSession (CharonCaptureControls18)

- (BOOL)canAddControl:(AVCaptureControl *)control;
- (void)addControl:(AVCaptureControl *)control;
- (void)removeControl:(AVCaptureControl *)control;
- (void)setControlsDelegate:(nullable id<AVCaptureSessionControlsDelegate>)controlsDelegate
                      queue:(nullable dispatch_queue_t)controlsDelegateCallbackQueue;
@property(nonatomic, readonly) BOOL supportsControls;
@property(nonatomic, readonly) NSInteger maxControlsCount;
@property(nonatomic, readonly) NSArray<__kindof AVCaptureControl *> *controls;
@property(nonatomic, readonly, nullable) id<AVCaptureSessionControlsDelegate> controlsDelegate;
@property(nonatomic, readonly, nullable) dispatch_queue_t controlsDelegateCallbackQueue;
@property(nonatomic) BOOL configuresApplicationAudioSessionToMixWithOthers;

@end

NS_ASSUME_NONNULL_END

#else
#import <AVFCore/AVCaptureControl.h>
#endif
