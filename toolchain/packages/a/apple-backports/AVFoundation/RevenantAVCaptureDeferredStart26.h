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
