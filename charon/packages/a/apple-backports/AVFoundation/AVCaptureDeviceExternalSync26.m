#import "CharonAVCaptureDeviceExternalSync26.h"

@interface AVCaptureDevice (CharonCaptureDeviceExternalSync26Minima)
- (CMTime)minSupportedLockedVideoFrameDuration;
- (CMTime)minSupportedExternalSyncFrameDuration;
@end

static BOOL charon_device_supports_locked_frame_duration(AVCaptureDevice *device)
{
    return device ? !CMTIME_IS_INVALID([device minSupportedLockedVideoFrameDuration]) : NO;
}

static BOOL charon_device_supports_external_sync(AVCaptureDevice *device)
{
    return device ? !CMTIME_IS_INVALID([device minSupportedExternalSyncFrameDuration]) : NO;
}

@implementation AVCaptureDevice (CharonCaptureDeviceExternalSync26)

- (BOOL)isVideoFrameDurationLocked
{
    return NO;
}

- (CMTime)minSupportedLockedVideoFrameDuration
{
    return kCMTimeInvalid;
}

- (BOOL)isFollowingExternalSyncDevice
{
    return NO;
}

- (CMTime)minSupportedExternalSyncFrameDuration
{
    return kCMTimeInvalid;
}

@end

@implementation AVCaptureDeviceInput (CharonCaptureDeviceInputExternalSync26)

- (BOOL)isLockedVideoFrameDurationSupported
{
    return charon_device_supports_locked_frame_duration(self.device);
}

- (CMTime)activeLockedVideoFrameDuration
{
    return kCMTimeInvalid;
}

- (void)setActiveLockedVideoFrameDuration:(CMTime)activeLockedVideoFrameDuration API_AVAILABLE(ios(26.0))
{
    if (CMTIME_IS_INVALID(activeLockedVideoFrameDuration))
        return;
    [NSException raise:NSInvalidArgumentException
                format:@"*** -[AVCaptureDeviceInput %@] The device's minSupportedLockedVideoFrameDuration is"
                       @" kCMTimeInvalid, so this AVCaptureInput cannot lock a frame duration"
                       @", and the property is left at kCMTimeInvalid",
                       NSStringFromSelector(_cmd)];
}

- (BOOL)isExternalSyncSupported
{
    return charon_device_supports_external_sync(self.device);
}

- (CMTime)activeExternalSyncVideoFrameDuration
{
    return kCMTimeInvalid;
}

- (AVExternalSyncDevice *)externalSyncDevice
{
    return nil;
}

- (void)followExternalSyncDevice:(AVExternalSyncDevice *)externalSyncDevice
                 videoFrameDuration:(CMTime)frameDuration
                        delegate:(id<AVExternalSyncDeviceDelegate>)delegate API_AVAILABLE(ios(26.0))
{
    [NSException raise:NSInvalidArgumentException
                format:@"*** -[AVCaptureDeviceInput %@] %@ is not supported on this device. Check the device"
                       @" minSupportedExternalSyncFrameDuration property.",
                       NSStringFromSelector(_cmd), NSStringFromSelector(_cmd)];
}

- (void)unfollowExternalSyncDevice
{
}

@end
