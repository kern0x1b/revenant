#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// The stabilization modes of iOS 8 over the one switch 6.x has, enablesVideoStabilizationWhenAvailable.
// 8.0 keeps the preferred mode and answers the old switch as "the preferred mode is Standard"; 6.x runs
// its stabilization from the switch, which 8.0 maps to Standard, and has no Cinematic. The resolution of
// a mode follows 8.0's -_resolveActiveVideoStabilizationMode:format: (facts/AVFoundation/VideoStabilization.md).

static const void *charon_preferred_mode = &charon_preferred_mode;

@implementation AVCaptureDeviceFormat (CharonVideoStabilizationMode)

- (BOOL)isVideoStabilizationModeSupported:(AVCaptureVideoStabilizationMode)videoStabilizationMode
{
    switch (videoStabilizationMode) {
    case AVCaptureVideoStabilizationModeAuto:
    case AVCaptureVideoStabilizationModeOff:
        return YES;
    case AVCaptureVideoStabilizationModeStandard:
        return self.videoStabilizationSupported;
    default:
        return NO;
    }
}

@end

@implementation AVCaptureConnection (CharonVideoStabilizationMode)

- (AVCaptureDeviceFormat *)charon_sourceFormat
{
    for (AVCaptureInputPort *port in self.inputPorts) {
        if ([port.input isKindOfClass:[AVCaptureDeviceInput class]])
            return ((AVCaptureDeviceInput *)port.input).device.activeFormat;
    }
    return nil;
}

// Only a movie file output and a video data output are stabilized; Auto takes Standard first on a format
// that runs faster than 60 frames a second and Cinematic first otherwise.
- (AVCaptureVideoStabilizationMode)charon_resolvedStabilizationMode:(AVCaptureVideoStabilizationMode)mode
{
    if (![self.output isKindOfClass:[AVCaptureMovieFileOutput class]] && ![self.output isKindOfClass:[AVCaptureVideoDataOutput class]])
        return AVCaptureVideoStabilizationModeOff;
    AVCaptureDeviceFormat *format = [self charon_sourceFormat];
    if (mode != AVCaptureVideoStabilizationModeAuto)
        return [format isVideoStabilizationModeSupported:mode] ? mode : AVCaptureVideoStabilizationModeOff;
    BOOL fast = [format.videoSupportedFrameRateRanges.lastObject maxFrameRate] > 60;
    AVCaptureVideoStabilizationMode first = fast ? AVCaptureVideoStabilizationModeStandard : AVCaptureVideoStabilizationModeCinematic;
    AVCaptureVideoStabilizationMode second = fast ? AVCaptureVideoStabilizationModeCinematic : AVCaptureVideoStabilizationModeStandard;
    if ([format isVideoStabilizationModeSupported:first])
        return first;
    if ([format isVideoStabilizationModeSupported:second])
        return second;
    return AVCaptureVideoStabilizationModeOff;
}

// The preferred mode is kept with the switch it left the release at: once the switch is changed through
// the old property, the preferred mode is what 8.0 makes of that setter, Standard or Off.
- (AVCaptureVideoStabilizationMode)preferredVideoStabilizationMode
{
    NSArray *kept = objc_getAssociatedObject(self, charon_preferred_mode);
    BOOL enables = self.enablesVideoStabilizationWhenAvailable;
    if (kept && [kept[1] boolValue] == enables)
        return (AVCaptureVideoStabilizationMode)[kept[0] integerValue];
    return enables ? AVCaptureVideoStabilizationModeStandard : AVCaptureVideoStabilizationModeOff;
}

- (void)setPreferredVideoStabilizationMode:(AVCaptureVideoStabilizationMode)preferredVideoStabilizationMode
{
    if (preferredVideoStabilizationMode < AVCaptureVideoStabilizationModeAuto || preferredVideoStabilizationMode > AVCaptureVideoStabilizationModeCinematic)
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:[NSString stringWithFormat:@"Supplied preferredVideoStabilizationMode (%ld) is outside of the range of AVCaptureVideoStabilizationMode.", (long)preferredVideoStabilizationMode]
                                     userInfo:nil];
    BOOL wants = [self charon_resolvedStabilizationMode:preferredVideoStabilizationMode] == AVCaptureVideoStabilizationModeStandard;
    // The release raises when the switch is set on a connection that cannot stabilize; 8.0 takes the mode
    // there and resolves it to Off, which is what the switch left off gives.
    if (self.supportsVideoStabilization)
        self.enablesVideoStabilizationWhenAvailable = wants;
    objc_setAssociatedObject(self, charon_preferred_mode, @[@(preferredVideoStabilizationMode), @(self.enablesVideoStabilizationWhenAvailable)], OBJC_ASSOCIATION_RETAIN);
}

- (AVCaptureVideoStabilizationMode)activeVideoStabilizationMode
{
    return self.videoStabilizationEnabled ? AVCaptureVideoStabilizationModeStandard : AVCaptureVideoStabilizationModeOff;
}

@end
