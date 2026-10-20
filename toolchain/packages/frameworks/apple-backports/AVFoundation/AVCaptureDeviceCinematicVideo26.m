#import "RevenantAVCaptureDeviceCinematicVideo26.h"
#import <objc/runtime.h>

static const char revenant_cinematic_video_enabled_key;

static void revenant_cinematic_focus_refused(SEL selector)
{
    [NSException raise:NSInvalidArgumentException
                format:@"*** -[AVCaptureDevice %@] Not supported - use"
                       @" activeFormat.isCinematicVideoCaptureSupported",
                       NSStringFromSelector(selector)];
}

@implementation AVCaptureDevice (RevenantCaptureDeviceCinematicVideo26)

- (NSSet<AVCaptureSceneMonitoringStatus> *)cinematicVideoCaptureSceneMonitoringStatuses
{
    return [NSSet set];
}

#define REVENANT_CINEMATIC_VIDEO_FORMAT_SUPPORTS(device) \
    ({ id format = [(device) activeFormat]; format ? [format isCinematicVideoCaptureSupported] : NO; })

- (void)setCinematicVideoTrackingFocusWithDetectedObjectID:(NSInteger)detectedObjectID
                                                focusMode:(AVCaptureCinematicVideoFocusMode)focusMode API_AVAILABLE(ios(26.0))
{
    if (!REVENANT_CINEMATIC_VIDEO_FORMAT_SUPPORTS(self)) {
        revenant_cinematic_focus_refused(_cmd);
        return;
    }
}

- (void)setCinematicVideoTrackingFocusAtPoint:(CGPoint)point
                                    focusMode:(AVCaptureCinematicVideoFocusMode)focusMode API_AVAILABLE(ios(26.0))
{
    if (!REVENANT_CINEMATIC_VIDEO_FORMAT_SUPPORTS(self)) {
        revenant_cinematic_focus_refused(_cmd);
        return;
    }
}

- (void)setCinematicVideoFixedFocusAtPoint:(CGPoint)point
                                 focusMode:(AVCaptureCinematicVideoFocusMode)focusMode API_AVAILABLE(ios(26.0))
{
    if (!REVENANT_CINEMATIC_VIDEO_FORMAT_SUPPORTS(self)) {
        revenant_cinematic_focus_refused(_cmd);
        return;
    }
}

@end

@implementation AVCaptureDeviceFormat (RevenantCaptureDeviceFormatCinematicVideo26)

- (BOOL)isCinematicVideoCaptureSupported
{
    return NO;
}

- (CGFloat)videoMinZoomFactorForCinematicVideo
{
    return 1.0;
}

- (CGFloat)videoMaxZoomFactorForCinematicVideo
{
    return 1.0;
}

- (AVFrameRateRange *)videoFrameRateRangeForCinematicVideo
{
    return nil;
}

@end

@implementation AVCaptureDeviceInput (RevenantCaptureDeviceInputCinematicVideo26)

- (BOOL)isCinematicVideoCaptureSupported API_AVAILABLE(ios(26.0))
{
    return REVENANT_CINEMATIC_VIDEO_FORMAT_SUPPORTS(self.device);
}

- (BOOL)isCinematicVideoCaptureEnabled
{
    id stored = objc_getAssociatedObject(self, &revenant_cinematic_video_enabled_key);
    return stored ? [stored boolValue] : NO;
}

- (void)setCinematicVideoCaptureEnabled:(BOOL)cinematicVideoCaptureEnabled
{
    if (cinematicVideoCaptureEnabled && !self.isCinematicVideoCaptureSupported) {
        [NSException raise:NSInvalidArgumentException
                    format:@"*** -[AVCaptureDeviceInput %@] Not supported - use"
                           @" isCinematicVideoCaptureSupported",
                           NSStringFromSelector(_cmd)];
        return;
    }
    objc_setAssociatedObject(self, &revenant_cinematic_video_enabled_key, @(cinematicVideoCaptureEnabled),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
