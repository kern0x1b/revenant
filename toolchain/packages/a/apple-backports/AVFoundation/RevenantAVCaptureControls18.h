#if !__has_include(<AVFCore/AVCaptureControl.h>)
#import <Foundation/Foundation.h>
#import <AVFoundation/AVBase.h>
#import <AVFoundation/AVCaptureSession.h>

@protocol AVCaptureSessionControlsDelegate;

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(macos(15), ios(18), tvos(18))
@interface AVCaptureControl : NSObject

AV_INIT_UNAVAILABLE

@property(nonatomic, getter=isEnabled) BOOL enabled;

@end

API_AVAILABLE(macos(15), ios(18), tvos(18))
@interface AVCaptureSession (RevenantCaptureControls18)

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
