// CharonAVCaptureDeferredStart26.h - the deferred-start surface of iOS 26, on the three classes it belongs
// to: AVCaptureSession's four properties and its two methods, AVCaptureOutput's two and
// AVCaptureVideoPreviewLayer's two. SDK 16.4 declares none of them - its AVCaptureSession.h has no
// manuallyRunsDeferredStart, no automaticallyRunsDeferredStart, no deferredStartDelegate, no
// runDeferredStartWhenNeeded and no setDeferredStartDelegate:deferredStartDelegateCallbackQueue:, and neither
// AVCaptureOutputBase.h nor AVCaptureVideoPreviewLayer.h has a deferredStart member.
//
//   iPhoneOS26.2.sdk/System/Library/Frameworks/AVFoundation.framework/Headers/AVCaptureSession.h:670-725
//   iPhoneOS26.2.sdk/System/Library/Frameworks/AVFoundation.framework/Headers/AVCaptureOutputBase.h:117-131
//   iPhoneOS26.2.sdk/System/Library/Frameworks/AVFoundation.framework/Headers/AVCaptureVideoPreviewLayer.h:262-278
//
// -runDeferredStartWhenNeeded carries no API_AVAILABLE annotation where 26.2 puts one on it, and that is
// stated rather than done silently: the annotation on a void method whose signature names no 26.0 type guards
// nothing a caller can reach, and the definition in AVCaptureDeferredStart26.m carries it instead - which is
// what AVCaptureControls18.m and CharonAVCaptureDeviceExternalSync26.h do for the same reason.
//
// THE PROTOCOL IS NOT DECLARED HERE: AVCaptureSessionDeferredStartDelegate is in
// CharonAVFoundationProtocols.h, transcribed from the SDK 26.2 by tools/transcribe-protocols.py@52253c0650 and named by the
// generated protocol source with @protocol(...). It is named here as a forward declaration only, so the two
// signatures below resolve.
//
// THE GUARD is the SDK's own knowledge of iOS 26, and the `visionos` drop from the availability annotations is
// the one CharonAVCaptureDeviceCapabilities18.h measures: SDK 16.4's os/availability.h fails to expand
// `API_UNAVAILABLE(visionos)` while `API_UNAVAILABLE(watchos)` compiles clean.
#if !defined(__IPHONE_26_0)
#import <Foundation/Foundation.h>
#import <AVFoundation/AVBase.h>
#import <AVFoundation/AVCaptureSession.h>
#import <AVFoundation/AVCaptureOutput.h>
#import <AVFoundation/AVCaptureVideoPreviewLayer.h>

NS_ASSUME_NONNULL_BEGIN

@protocol AVCaptureSessionDeferredStartDelegate;

@interface AVCaptureSession (CharonCaptureDeferredStart26)

@property(nonatomic, readonly, getter=isManualDeferredStartSupported) BOOL manualDeferredStartSupported API_AVAILABLE(ios(26.0));
@property(nonatomic) BOOL automaticallyRunsDeferredStart API_AVAILABLE(ios(26.0));
- (void)runDeferredStartWhenNeeded;
@property(nonatomic, readonly, nullable) id<AVCaptureSessionDeferredStartDelegate> deferredStartDelegate API_AVAILABLE(ios(26.0));
@property(nonatomic, readonly, nullable) dispatch_queue_t deferredStartDelegateCallbackQueue API_AVAILABLE(ios(26.0));
- (void)setDeferredStartDelegate:(nullable id<AVCaptureSessionDeferredStartDelegate>)deferredStartDelegate deferredStartDelegateCallbackQueue:(nullable dispatch_queue_t)deferredStartDelegateCallbackQueue;

@end

@interface AVCaptureOutput (CharonCaptureDeferredStart26)

@property(nonatomic, readonly, getter=isDeferredStartSupported) BOOL deferredStartSupported API_AVAILABLE(ios(26.0));
@property(nonatomic, getter=isDeferredStartEnabled) BOOL deferredStartEnabled API_AVAILABLE(ios(26.0));

@end

@interface AVCaptureVideoPreviewLayer (CharonCaptureDeferredStart26)

@property(nonatomic, readonly, getter=isDeferredStartSupported) BOOL deferredStartSupported API_AVAILABLE(ios(26.0));
@property(nonatomic, getter=isDeferredStartEnabled) BOOL deferredStartEnabled API_AVAILABLE(ios(26.0));

@end

NS_ASSUME_NONNULL_END

#else
#import <AVFoundation/AVCaptureSession.h>
#import <AVFoundation/AVCaptureOutput.h>
#import <AVFoundation/AVCaptureVideoPreviewLayer.h>
#endif
