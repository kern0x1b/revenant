#import "RevenantAVCapturePhoto.h"

@implementation AVCaptureResolvedPhotoSettings
{
    int64_t _revenantUniqueID;
    CMVideoDimensions _revenantPhotoDimensions;
    CMVideoDimensions _revenantPreviewDimensions;
    CMVideoDimensions _revenantEmbeddedThumbnailDimensions;
    BOOL _revenantFlashEnabled;
    BOOL _revenantStillImageStabilizationEnabled;
    NSUInteger _revenantExpectedPhotoCount;
}

- (instancetype)initRevenantWithUniqueID:(int64_t)uniqueID photoDimensions:(CMVideoDimensions)photoDimensions
                     previewDimensions:(CMVideoDimensions)previewDimensions
           embeddedThumbnailDimensions:(CMVideoDimensions)embeddedThumbnailDimensions flashEnabled:(BOOL)flashEnabled
        stillImageStabilizationEnabled:(BOOL)stillImageStabilizationEnabled
{
    if ((self = [super init])) {
        _revenantUniqueID = uniqueID;
        _revenantPhotoDimensions = photoDimensions;
        _revenantPreviewDimensions = previewDimensions;
        _revenantEmbeddedThumbnailDimensions = embeddedThumbnailDimensions;
        _revenantFlashEnabled = flashEnabled;
        _revenantStillImageStabilizationEnabled = stillImageStabilizationEnabled;
        _revenantExpectedPhotoCount = 1;
    }
    return self;
}

- (int64_t)uniqueID
{
    return _revenantUniqueID;
}

- (CMVideoDimensions)photoDimensions
{
    return _revenantPhotoDimensions;
}

- (CMVideoDimensions)rawPhotoDimensions
{
    return (CMVideoDimensions){0, 0};
}

- (CMVideoDimensions)previewDimensions
{
    return _revenantPreviewDimensions;
}

- (CMVideoDimensions)livePhotoMovieDimensions
{
    return (CMVideoDimensions){0, 0};
}

- (BOOL)isFlashEnabled
{
    return _revenantFlashEnabled;
}

- (BOOL)isStillImageStabilizationEnabled
{
    return _revenantStillImageStabilizationEnabled;
}

- (BOOL)isDualCameraFusionEnabled
{
    return NO;
}

- (BOOL)isVirtualDeviceFusionEnabled
{
    return NO;
}

- (NSUInteger)expectedPhotoCount
{
    return _revenantExpectedPhotoCount;
}

- (void)revenant_setExpectedPhotoCount:(NSUInteger)expectedPhotoCount
{
    _revenantExpectedPhotoCount = expectedPhotoCount;
}

- (CMVideoDimensions)embeddedThumbnailDimensions
{
    return _revenantEmbeddedThumbnailDimensions;
}

- (CMVideoDimensions)rawEmbeddedThumbnailDimensions
{
    return (CMVideoDimensions){0, 0};
}

- (CMVideoDimensions)portraitEffectsMatteDimensions
{
    return (CMVideoDimensions){0, 0};
}

- (CMVideoDimensions)dimensionsForSemanticSegmentationMatteOfType:(AVSemanticSegmentationMatteType)semanticSegmentationMatteType
{
    return (CMVideoDimensions){0, 0};
}

- (BOOL)isRedEyeReductionEnabled
{
    return NO;
}

- (CMTimeRange)photoProcessingTimeRange
{
    return kCMTimeRangeInvalid;
}

- (BOOL)isContentAwareDistortionCorrectionEnabled
{
    return NO;
}

@end
