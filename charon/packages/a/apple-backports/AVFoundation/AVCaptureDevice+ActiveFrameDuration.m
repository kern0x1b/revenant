#import "CharonAVCapture.h"
#import <objc/runtime.h>

@interface AVCaptureDevice (CharonReleaseLock)
- (BOOL)isLockedForConfiguration;
@end

static const char CharonActiveMinFrameDurationKey;
static const char CharonActiveMaxFrameDurationKey;

static CMTime charon_default_min_frame_duration(AVCaptureDevice *device)
{
    CMTime shortest = kCMTimeInvalid;
    for (AVFrameRateRange *range in device.activeFormat.videoSupportedFrameRateRanges) {
        if (CMTIME_IS_INVALID(shortest) || CMTimeCompare(range.minFrameDuration, shortest) < 0)
            shortest = range.minFrameDuration;
    }
    return shortest;
}

static CMTime charon_default_max_frame_duration(AVCaptureDevice *device)
{
    CMTime longest = kCMTimeInvalid;
    for (AVFrameRateRange *range in device.activeFormat.videoSupportedFrameRateRanges) {
        if (CMTIME_IS_INVALID(longest) || CMTimeCompare(range.maxFrameDuration, longest) > 0)
            longest = range.maxFrameDuration;
    }
    return longest;
}

static void charon_apply_frame_durations(AVCaptureSession *session)
{
    for (AVCaptureOutput *output in session.outputs) {
        for (AVCaptureConnection *connection in output.connections) {
            AVCaptureInputPort *port = connection.inputPorts.firstObject;
            if (![port.mediaType isEqualToString:AVMediaTypeVideo] || ![port.input isKindOfClass:[AVCaptureDeviceInput class]])
                continue;
            AVCaptureDevice *device = ((AVCaptureDeviceInput *)port.input).device;
            NSValue *min = objc_getAssociatedObject(device, &CharonActiveMinFrameDurationKey);
            NSValue *max = objc_getAssociatedObject(device, &CharonActiveMaxFrameDurationKey);
            if (min && connection.isVideoMinFrameDurationSupported)
                connection.videoMinFrameDuration = min.CMTimeValue;
            if (max && connection.isVideoMaxFrameDurationSupported)
                connection.videoMaxFrameDuration = max.CMTimeValue;
        }
    }
}

@interface CharonActiveFrameDurationInstaller : NSObject
@end

@implementation CharonActiveFrameDurationInstaller

+ (void)load
{
    [[NSNotificationCenter defaultCenter] addObserverForName:CHARON_CAPTURE_SESSION_CHANGED object:nil queue:nil usingBlock:^(NSNotification *note) {
        charon_apply_frame_durations(note.object);
    }];
}

@end

@implementation AVCaptureDevice (CharonActiveFrameDuration)

- (CMTime)activeVideoMinFrameDuration
{
    NSValue *stored = objc_getAssociatedObject(self, &CharonActiveMinFrameDurationKey);
    return stored ? stored.CMTimeValue : charon_default_min_frame_duration(self);
}

- (void)setActiveVideoMinFrameDuration:(CMTime)activeVideoMinFrameDuration
{
    // 7.0 asks the release's own -isLockedForConfiguration first, as 6.1.3's setters of the device do.
    if (![self isLockedForConfiguration])
        @throw [NSException exceptionWithName:NSGenericException
                                       reason:@"activeVideoMinFrameDuration cannot be set without first successfully gaining exclusive ownership of the device using -lockForConfiguration:"
                                     userInfo:nil];
    objc_setAssociatedObject(self, &CharonActiveMinFrameDurationKey, CMTIME_IS_VALID(activeVideoMinFrameDuration) ? [NSValue valueWithCMTime:activeVideoMinFrameDuration] : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    for (AVCaptureSession *session in [self charon_captureSessions])
        charon_apply_frame_durations(session);
}

- (CMTime)activeVideoMaxFrameDuration
{
    NSValue *stored = objc_getAssociatedObject(self, &CharonActiveMaxFrameDurationKey);
    return stored ? stored.CMTimeValue : charon_default_max_frame_duration(self);
}

- (void)setActiveVideoMaxFrameDuration:(CMTime)activeVideoMaxFrameDuration
{
    // 7.0 asks the release's own -isLockedForConfiguration first, as 6.1.3's setters of the device do.
    if (![self isLockedForConfiguration])
        @throw [NSException exceptionWithName:NSGenericException
                                       reason:@"activeVideoMaxFrameDuration cannot be set without first successfully gaining exclusive ownership of the device using -lockForConfiguration:"
                                     userInfo:nil];
    objc_setAssociatedObject(self, &CharonActiveMaxFrameDurationKey, CMTIME_IS_VALID(activeVideoMaxFrameDuration) ? [NSValue valueWithCMTime:activeVideoMaxFrameDuration] : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    for (AVCaptureSession *session in [self charon_captureSessions])
        charon_apply_frame_durations(session);
}

@end
