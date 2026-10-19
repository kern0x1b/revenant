#import "CharonAVCaptureDeviceCapabilities18.h"
#import <objc/runtime.h>

static const char charon_auto_video_frame_rate_key;
static const char charon_multichannel_audio_mode_key;
static const char charon_wind_noise_removal_key;

static id charon_capture_value(id object, const char *key, id fallback)
{
    id stored = objc_getAssociatedObject(object, key);
    return stored ? stored : fallback;
}

@implementation AVCaptureDevice (CharonCaptureDeviceCapabilities18)

- (BOOL)isAutoVideoFrameRateEnabled
{
    return [charon_capture_value(self, &charon_auto_video_frame_rate_key, @NO) boolValue];
}

- (void)setAutoVideoFrameRateEnabled:(BOOL)enabled
{
    id format = self.activeFormat;
    if (![format isAutoVideoFrameRateSupported]) {
        [NSException raise:NSInvalidArgumentException
                    format:@"*** -[AVCaptureDevice %@] Not supported - use "
                           @"-[AVCaptureDeviceFormat autoVideoFrameRateSupported]",
                           NSStringFromSelector(_cmd)];
        return;
    }
    objc_setAssociatedObject(self, &charon_auto_video_frame_rate_key, @(enabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isBackgroundReplacementActive
{
    return NO;
}

+ (BOOL)isBackgroundReplacementEnabled
{
    return NO;
}

- (CGFloat)displayVideoZoomFactorMultiplier
{
    return 1.0;
}

- (NSSet<AVSpatialCaptureDiscomfortReason> *)spatialCaptureDiscomfortReasons
{
    return [NSSet set];
}

@end

@implementation AVCaptureDeviceFormat (CharonCaptureDeviceFormatCapabilities18)

- (BOOL)isAutoVideoFrameRateSupported
{
    return NO;
}

- (BOOL)isBackgroundReplacementSupported
{
    return NO;
}

- (BOOL)isSpatialVideoCaptureSupported
{
    return NO;
}

- (AVExposureBiasRange *)systemRecommendedExposureBiasRange
{
    return nil;
}

- (AVZoomRange *)systemRecommendedVideoZoomRange
{
    return nil;
}

- (AVFrameRateRange *)videoFrameRateRangeForBackgroundReplacement
{
    return nil;
}

@end

@implementation AVCaptureDeviceInput (CharonCaptureDeviceInputCapabilities18)

- (BOOL)isMultichannelAudioModeSupported:(AVCaptureMultichannelAudioMode)multichannelAudioMode
{
    return multichannelAudioMode == AVCaptureMultichannelAudioModeNone;
}

- (AVCaptureMultichannelAudioMode)multichannelAudioMode
{
    return (AVCaptureMultichannelAudioMode)[charon_capture_value(self, &charon_multichannel_audio_mode_key,
                                                                @(AVCaptureMultichannelAudioModeNone)) integerValue];
}

- (void)setMultichannelAudioMode:(AVCaptureMultichannelAudioMode)multichannelAudioMode
{
    if (![self isMultichannelAudioModeSupported:multichannelAudioMode]) {
        [NSException raise:NSInvalidArgumentException
                    format:@"*** -[AVCaptureDeviceInput %@] Not supported", NSStringFromSelector(_cmd)];
        return;
    }
    objc_setAssociatedObject(self, &charon_multichannel_audio_mode_key, @(multichannelAudioMode),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isWindNoiseRemovalSupported
{
    return NO;
}

- (BOOL)isWindNoiseRemovalEnabled
{
    return [charon_capture_value(self, &charon_wind_noise_removal_key, @NO) boolValue];
}

- (void)setWindNoiseRemovalEnabled:(BOOL)windNoiseRemovalEnabled
{
    objc_setAssociatedObject(self, &charon_wind_noise_removal_key, @(windNoiseRemovalEnabled),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
