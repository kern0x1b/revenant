#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static const void *revenant_preferred_mode = &revenant_preferred_mode;

@implementation AVCaptureDeviceFormat (RevenantVideoStabilizationMode)

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

@implementation AVCaptureConnection (RevenantVideoStabilizationMode)

- (AVCaptureDeviceFormat *)revenant_sourceFormat
{
    for (AVCaptureInputPort *port in self.inputPorts) {
        if ([port.input isKindOfClass:[AVCaptureDeviceInput class]])
            return ((AVCaptureDeviceInput *)port.input).device.activeFormat;
    }
    return nil;
}

- (AVCaptureVideoStabilizationMode)revenant_resolvedStabilizationMode:(AVCaptureVideoStabilizationMode)mode
{
    if (![self.output isKindOfClass:[AVCaptureMovieFileOutput class]] && ![self.output isKindOfClass:[AVCaptureVideoDataOutput class]])
        return AVCaptureVideoStabilizationModeOff;
    AVCaptureDeviceFormat *format = [self revenant_sourceFormat];
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

- (AVCaptureVideoStabilizationMode)preferredVideoStabilizationMode
{
    NSArray *kept = objc_getAssociatedObject(self, revenant_preferred_mode);
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
    BOOL wants = [self revenant_resolvedStabilizationMode:preferredVideoStabilizationMode] == AVCaptureVideoStabilizationModeStandard;
    if (self.supportsVideoStabilization)
        self.enablesVideoStabilizationWhenAvailable = wants;
    objc_setAssociatedObject(self, revenant_preferred_mode, @[@(preferredVideoStabilizationMode), @(self.enablesVideoStabilizationWhenAvailable)], OBJC_ASSOCIATION_RETAIN);
}

- (AVCaptureVideoStabilizationMode)activeVideoStabilizationMode
{
    return self.videoStabilizationEnabled ? AVCaptureVideoStabilizationModeStandard : AVCaptureVideoStabilizationModeOff;
}

@end
