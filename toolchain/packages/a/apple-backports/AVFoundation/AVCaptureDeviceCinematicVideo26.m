#import "CharonAVCaptureDeviceCinematicVideo26.h"
#import <objc/runtime.h>

static const char charon_cinematic_video_enabled_key;

static void charon_cinematic_focus_refused(SEL selector)
{
    [NSException raise:NSInvalidArgumentException
                format:@"*** -[AVCaptureDevice %@] Not supported - use"
                       @" activeFormat.isCinematicVideoCaptureSupported",
                       NSStringFromSelector(selector)];
}

@implementation AVCaptureDevice (CharonCaptureDeviceCinematicVideo26)

- (NSSet<AVCaptureSceneMonitoringStatus> *)cinematicVideoCaptureSceneMonitoringStatuses
{
    return [NSSet set];
}

#define CHARON_CINEMATIC_VIDEO_FORMAT_SUPPORTS(device) \
    ({ id format = [(device) activeFormat]; format ? [format isCinematicVideoCaptureSupported] : NO; })

- (void)setCinematicVideoTrackingFocusWithDetectedObjectID:(NSInteger)detectedObjectID
                                                focusMode:(AVCaptureCinematicVideoFocusMode)focusMode API_AVAILABLE(ios(26.0))
{
    if (!CHARON_CINEMATIC_VIDEO_FORMAT_SUPPORTS(self)) {
        charon_cinematic_focus_refused(_cmd);
        return;
    }
}

- (void)setCinematicVideoTrackingFocusAtPoint:(CGPoint)point
                                    focusMode:(AVCaptureCinematicVideoFocusMode)focusMode API_AVAILABLE(ios(26.0))
{
    if (!CHARON_CINEMATIC_VIDEO_FORMAT_SUPPORTS(self)) {
        charon_cinematic_focus_refused(_cmd);
        return;
    }
}

- (void)setCinematicVideoFixedFocusAtPoint:(CGPoint)point
                                 focusMode:(AVCaptureCinematicVideoFocusMode)focusMode API_AVAILABLE(ios(26.0))
{
    if (!CHARON_CINEMATIC_VIDEO_FORMAT_SUPPORTS(self)) {
        charon_cinematic_focus_refused(_cmd);
        return;
    }
}

@end

@implementation AVCaptureDeviceFormat (CharonCaptureDeviceFormatCinematicVideo26)

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

@implementation AVCaptureDeviceInput (CharonCaptureDeviceInputCinematicVideo26)

- (BOOL)isCinematicVideoCaptureSupported API_AVAILABLE(ios(26.0))
{
    return CHARON_CINEMATIC_VIDEO_FORMAT_SUPPORTS(self.device);
}

- (BOOL)isCinematicVideoCaptureEnabled
{
    id stored = objc_getAssociatedObject(self, &charon_cinematic_video_enabled_key);
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
    objc_setAssociatedObject(self, &charon_cinematic_video_enabled_key, @(cinematicVideoCaptureEnabled),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
