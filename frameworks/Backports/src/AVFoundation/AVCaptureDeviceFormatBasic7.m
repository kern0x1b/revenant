#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

static const char revenant_active_format_key;
static const char revenant_formats_key;

@interface AVCaptureDeviceFormat (RevenantBasic7)

- (instancetype)initRevenantWithVideoSupportedFrameRateRanges:(NSArray<AVFrameRateRange *> *)ranges
                            videoFieldOfView:(CGFloat)fieldOfView
                               videoHDRSupported:(BOOL)hdrSupported
                                maxFrameRate:(float)maxFrameRate
                           videoMaxZoomFactor:(CGFloat)maxZoomFactor;

@end

@implementation AVCaptureDeviceFormat (RevenantBasic7)

- (instancetype)initRevenantWithVideoSupportedFrameRateRanges:(NSArray<AVFrameRateRange *> *)ranges
                            videoFieldOfView:(CGFloat)fieldOfView
                               videoHDRSupported:(BOOL)hdrSupported
                                maxFrameRate:(float)maxFrameRate
                           videoMaxZoomFactor:(CGFloat)maxZoomFactor
{
    if ((self = [super init])) {
        objc_setAssociatedObject(self, @selector(videoSupportedFrameRateRanges), ranges ?: @[], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, @selector(videoFieldOfView), @(fieldOfView), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, @selector(videoHDRSupported), @(hdrSupported), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, @selector(maxFrameRate), @(maxFrameRate), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, @selector(videoMaxZoomFactor), @(maxZoomFactor), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return self;
}

- (NSArray<AVFrameRateRange *> *)videoSupportedFrameRateRanges
{
    return objc_getAssociatedObject(self, @selector(videoSupportedFrameRateRanges)) ?: @[];
}

- (CGFloat)videoFieldOfView
{
    return [objc_getAssociatedObject(self, @selector(videoFieldOfView)) floatValue];
}

- (BOOL)videoHDRSupported
{
    return [objc_getAssociatedObject(self, @selector(videoHDRSupported)) boolValue];
}

- (float)maxFrameRate
{
    return [objc_getAssociatedObject(self, @selector(maxFrameRate)) floatValue];
}

- (CGFloat)videoMaxZoomFactor
{
    return [objc_getAssociatedObject(self, @selector(videoMaxZoomFactor)) floatValue];
}

@end

@implementation AVCaptureDevice (RevenantBasic7)

- (NSArray<AVCaptureDeviceFormat *> *)formats
{
    NSArray *stored = objc_getAssociatedObject(self, &revenant_formats_key);
    if (stored)
        return stored;

    AVCaptureDeviceFormat *format = [[AVCaptureDeviceFormat alloc] initRevenantWithVideoSupportedFrameRateRanges:@[]
                                                                                                    videoFieldOfView:60.0
                                                                                                       videoHDRSupported:NO
                                                                                                        maxFrameRate:30.0
                                                                                               videoMaxZoomFactor:1.0];
    NSArray *formats = @[format];
    objc_setAssociatedObject(self, &revenant_formats_key, formats, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return formats;
}

- (AVCaptureDeviceFormat *)activeFormat
{
    AVCaptureDeviceFormat *stored = objc_getAssociatedObject(self, &revenant_active_format_key);
    if (stored)
        return stored;

    AVCaptureDeviceFormat *format = [self.formats firstObject];
    objc_setAssociatedObject(self, &revenant_active_format_key, format, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return format;
}

- (void)setActiveFormat:(AVCaptureDeviceFormat *)format
{
    if (![self.formats containsObject:format]) {
        [NSException raise:NSInvalidArgumentException format:@"*** -[AVCaptureDevice setActiveFormat:] format not in formats array"];
        return;
    }
    objc_setAssociatedObject(self, &revenant_active_format_key, format, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isFlashAvailable
{
    return NO;
}

- (BOOL)isFlashActive
{
    return NO;
}

- (AVCaptureFlashMode)flashMode
{
    return AVCaptureFlashModeOff;
}

- (void)setFlashMode:(AVCaptureFlashMode)flashMode
{
    if (flashMode != AVCaptureFlashModeOff && ![self isFlashAvailable]) {
        [NSException raise:NSInvalidArgumentException format:@"*** -[AVCaptureDevice setFlashMode:] Flash not available"];
        return;
    }
}

- (BOOL)isTorchAvailable
{
    return NO;
}

- (BOOL)isTorchActive
{
    return NO;
}

- (AVCaptureTorchMode)torchMode
{
    return AVCaptureTorchModeOff;
}

- (void)setTorchMode:(AVCaptureTorchMode)torchMode
{
    if (torchMode != AVCaptureTorchModeOff && ![self isTorchAvailable]) {
        [NSException raise:NSInvalidArgumentException format:@"*** -[AVCaptureDevice setTorchMode:] Torch not available"];
        return;
    }
}

- (float)deviceWhiteBalanceGains
{
    return 0;
}

- (void)setWhiteBalanceMode:(AVCaptureWhiteBalanceMode)whiteBalanceMode
{
}

- (AVCaptureWhiteBalanceMode)whiteBalanceMode
{
    return AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance;
}

- (BOOL)isFocusModeSupported:(AVCaptureFocusMode)focusMode
{
    return focusMode == AVCaptureFocusModeContinuousAutoFocus;
}

- (AVCaptureFocusMode)focusMode
{
    return AVCaptureFocusModeContinuousAutoFocus;
}

- (void)setFocusMode:(AVCaptureFocusMode)focusMode
{
    if (![self isFocusModeSupported:focusMode]) {
        [NSException raise:NSInvalidArgumentException format:@"*** -[AVCaptureDevice setFocusMode:] Focus mode not supported"];
        return;
    }
}

- (BOOL)isExposureModeSupported:(AVCaptureExposureMode)exposureMode
{
    return exposureMode == AVCaptureExposureModeContinuousAutoExposure;
}

- (AVCaptureExposureMode)exposureMode
{
    return AVCaptureExposureModeContinuousAutoExposure;
}

- (void)setExposureMode:(AVCaptureExposureMode)exposureMode
{
    if (![self isExposureModeSupported:exposureMode]) {
        [NSException raise:NSInvalidArgumentException format:@"*** -[AVCaptureDevice setExposureMode:] Exposure mode not supported"];
        return;
    }
}

@end