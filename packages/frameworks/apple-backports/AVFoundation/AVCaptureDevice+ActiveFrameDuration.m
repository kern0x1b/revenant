#import "RevenantAVCapture.h"
#import <objc/runtime.h>

@interface AVCaptureDevice (RevenantReleaseLock)
- (BOOL)isLockedForConfiguration;
@end

static const char RevenantActiveMinFrameDurationKey;
static const char RevenantActiveMaxFrameDurationKey;

static CMTime revenant_default_min_frame_duration(AVCaptureDevice *device)
{
    CMTime shortest = kCMTimeInvalid;
    for (AVFrameRateRange *range in device.activeFormat.videoSupportedFrameRateRanges) {
        if (CMTIME_IS_INVALID(shortest) || CMTimeCompare(range.minFrameDuration, shortest) < 0)
            shortest = range.minFrameDuration;
    }
    return shortest;
}

static CMTime revenant_default_max_frame_duration(AVCaptureDevice *device)
{
    CMTime longest = kCMTimeInvalid;
    for (AVFrameRateRange *range in device.activeFormat.videoSupportedFrameRateRanges) {
        if (CMTIME_IS_INVALID(longest) || CMTimeCompare(range.maxFrameDuration, longest) > 0)
            longest = range.maxFrameDuration;
    }
    return longest;
}

static void revenant_apply_frame_durations(AVCaptureSession *session)
{
    for (AVCaptureOutput *output in session.outputs) {
        for (AVCaptureConnection *connection in output.connections) {
            AVCaptureInputPort *port = connection.inputPorts.firstObject;
            if (![port.mediaType isEqualToString:AVMediaTypeVideo] || ![port.input isKindOfClass:[AVCaptureDeviceInput class]])
                continue;
            AVCaptureDevice *device = ((AVCaptureDeviceInput *)port.input).device;
            NSValue *min = objc_getAssociatedObject(device, &RevenantActiveMinFrameDurationKey);
            NSValue *max = objc_getAssociatedObject(device, &RevenantActiveMaxFrameDurationKey);
            if (min && connection.isVideoMinFrameDurationSupported)
                connection.videoMinFrameDuration = min.CMTimeValue;
            if (max && connection.isVideoMaxFrameDurationSupported)
                connection.videoMaxFrameDuration = max.CMTimeValue;
        }
    }
}

@interface RevenantActiveFrameDurationInstaller : NSObject
@end

@implementation RevenantActiveFrameDurationInstaller

+ (void)load
{
    [[NSNotificationCenter defaultCenter] addObserverForName:REVENANT_CAPTURE_SESSION_CHANGED object:nil queue:nil usingBlock:^(NSNotification *note) {
        revenant_apply_frame_durations(note.object);
    }];
}

@end

@implementation AVCaptureDevice (RevenantActiveFrameDuration)

- (CMTime)activeVideoMinFrameDuration
{
    NSValue *stored = objc_getAssociatedObject(self, &RevenantActiveMinFrameDurationKey);
    return stored ? stored.CMTimeValue : revenant_default_min_frame_duration(self);
}

- (void)setActiveVideoMinFrameDuration:(CMTime)activeVideoMinFrameDuration
{
    if (![self isLockedForConfiguration])
        @throw [NSException exceptionWithName:NSGenericException
                                       reason:@"activeVideoMinFrameDuration cannot be set without first successfully gaining exclusive ownership of the device using -lockForConfiguration:"
                                     userInfo:nil];
    objc_setAssociatedObject(self, &RevenantActiveMinFrameDurationKey, CMTIME_IS_VALID(activeVideoMinFrameDuration) ? [NSValue valueWithCMTime:activeVideoMinFrameDuration] : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    for (AVCaptureSession *session in [self revenant_captureSessions])
        revenant_apply_frame_durations(session);
}

- (CMTime)activeVideoMaxFrameDuration
{
    NSValue *stored = objc_getAssociatedObject(self, &RevenantActiveMaxFrameDurationKey);
    return stored ? stored.CMTimeValue : revenant_default_max_frame_duration(self);
}

- (void)setActiveVideoMaxFrameDuration:(CMTime)activeVideoMaxFrameDuration
{
    if (![self isLockedForConfiguration])
        @throw [NSException exceptionWithName:NSGenericException
                                       reason:@"activeVideoMaxFrameDuration cannot be set without first successfully gaining exclusive ownership of the device using -lockForConfiguration:"
                                     userInfo:nil];
    objc_setAssociatedObject(self, &RevenantActiveMaxFrameDurationKey, CMTIME_IS_VALID(activeVideoMaxFrameDuration) ? [NSValue valueWithCMTime:activeVideoMaxFrameDuration] : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    for (AVCaptureSession *session in [self revenant_captureSessions])
        revenant_apply_frame_durations(session);
}

@end
