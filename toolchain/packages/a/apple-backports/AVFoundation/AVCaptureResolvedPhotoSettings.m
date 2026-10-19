#import "CharonAVCapturePhoto.h"

@implementation AVCaptureResolvedPhotoSettings
{
    int64_t _charonUniqueID;
    CMVideoDimensions _charonPhotoDimensions;
    CMVideoDimensions _charonPreviewDimensions;
    CMVideoDimensions _charonEmbeddedThumbnailDimensions;
    BOOL _charonFlashEnabled;
    BOOL _charonStillImageStabilizationEnabled;
    NSUInteger _charonExpectedPhotoCount;
}

- (instancetype)initCharonWithUniqueID:(int64_t)uniqueID photoDimensions:(CMVideoDimensions)photoDimensions
                     previewDimensions:(CMVideoDimensions)previewDimensions
           embeddedThumbnailDimensions:(CMVideoDimensions)embeddedThumbnailDimensions flashEnabled:(BOOL)flashEnabled
        stillImageStabilizationEnabled:(BOOL)stillImageStabilizationEnabled
{
    if ((self = [super init])) {
        _charonUniqueID = uniqueID;
        _charonPhotoDimensions = photoDimensions;
        _charonPreviewDimensions = previewDimensions;
        _charonEmbeddedThumbnailDimensions = embeddedThumbnailDimensions;
        _charonFlashEnabled = flashEnabled;
        _charonStillImageStabilizationEnabled = stillImageStabilizationEnabled;
        _charonExpectedPhotoCount = 1;
    }
    return self;
}

- (int64_t)uniqueID
{
    return _charonUniqueID;
}

- (CMVideoDimensions)photoDimensions
{
    return _charonPhotoDimensions;
}

- (CMVideoDimensions)rawPhotoDimensions
{
    return (CMVideoDimensions){0, 0};
}

- (CMVideoDimensions)previewDimensions
{
    return _charonPreviewDimensions;
}

- (CMVideoDimensions)livePhotoMovieDimensions
{
    return (CMVideoDimensions){0, 0};
}

- (BOOL)isFlashEnabled
{
    return _charonFlashEnabled;
}

- (BOOL)isStillImageStabilizationEnabled
{
    return _charonStillImageStabilizationEnabled;
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
    return _charonExpectedPhotoCount;
}

- (void)charon_setExpectedPhotoCount:(NSUInteger)expectedPhotoCount
{
    _charonExpectedPhotoCount = expectedPhotoCount;
}

- (CMVideoDimensions)embeddedThumbnailDimensions
{
    return _charonEmbeddedThumbnailDimensions;
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
