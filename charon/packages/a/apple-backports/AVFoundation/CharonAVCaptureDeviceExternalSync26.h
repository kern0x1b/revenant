#if !defined(__IPHONE_26_0)
#import <Foundation/Foundation.h>
#import <AVFoundation/AVBase.h>
#import <AVFoundation/AVCaptureDevice.h>
#import <AVFoundation/AVCaptureInput.h>

NS_ASSUME_NONNULL_BEGIN

@protocol AVExternalSyncDeviceDelegate;

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
