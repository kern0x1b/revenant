#import "CharonAVCapturePhoto.h"

// AVCaptureResolvedPhotoSettings, iOS 10.0.1: what AVCapturePhotoOutput resolved one request to, handed to every
// delegate callback of that request (facts/AVFoundation/AVCapturePhotoOutput.md, "The resolved settings"). Every member
// the class has at 10.0.1 answers; the photo output fills them in at -capturePhotoWithSettings:delegate:, before
// -captureOutput:willBeginCaptureForResolvedSettings:, from the camera and the still it is about to take.
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

// The header: "If you don't request a RAW capture, this property returns {0, 0}". None can be requested here: the
// photo output offers no RAW format (availableRawPhotoPixelFormatTypes is empty on this release).
- (CMVideoDimensions)rawPhotoDimensions
{
    return (CMVideoDimensions){0, 0};
}

- (CMVideoDimensions)previewDimensions
{
    return _charonPreviewDimensions;
}

// The header: "If you don't request Live Photo capture, this property returns {0, 0}". None can be requested here:
// livePhotoCaptureSupported is NO and livePhotoCaptureEnabled cannot be set YES.
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

// The members later releases add. The class is carried only below 10.0.1, but it is Apple's class there and the header
// declares them on it, so each answers: left alone, the compiler would synthesize every declared property to a zero,
// a silent fake (it did, up to this file). Each says what the capture delivers: none of these features is made here,
// and the facts file names the reason for each.

// 10.2, 13.0: the cameras of the releases this class serves are single cameras, with nothing to fuse.
- (BOOL)isDualCameraFusionEnabled
{
    return NO;
}

- (BOOL)isVirtualDeviceFusionEnabled
{
    return NO;
}

// 11.0: the header (AVCapturePhotoOutput.h:1934-1936) says how many times the didFinishProcessingPhoto:error: callback is called.
// A single photo is one; a bracket is its count, which the capture sets (charon_setExpectedPhotoCount:).
- (NSUInteger)expectedPhotoCount
{
    return _charonExpectedPhotoCount;
}

- (void)charon_setExpectedPhotoCount:(NSUInteger)expectedPhotoCount
{
    _charonExpectedPhotoCount = expectedPhotoCount;
}

// 11.0: the thumbnail the capture embeds in the photo's Exif when the settings ask for one, { 0, 0 } when they do not
// (the header).
- (CMVideoDimensions)embeddedThumbnailDimensions
{
    return _charonEmbeddedThumbnailDimensions;
}

// 12.0, 13.0: no RAW thumbnail, portrait effects matte or semantic segmentation matte is written by this capture, which
// delivers the still image output's own photo. What the header answers for one not requested, { 0, 0 }, is what is
// delivered.
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

// 12.0: red-eye reduction came to capture in 12.0 (autoRedEyeReductionEnabled, isAutoRedEyeReductionSupported: none of
// the selectors in the arm64 cache of 11.0, all in 12.0's); the still image output applies none.
- (BOOL)isRedEyeReductionEnabled
{
    return NO;
}

// 13.0: an estimate of the processing time the release does not make. An invalid range says so, where a zero range
// would say the photo takes no time.
- (CMTimeRange)photoProcessingTimeRange
{
    return kCMTimeRangeInvalid;
}

// 14.1: the correction arrived in 14.1 and is never applied here.
- (BOOL)isContentAwareDistortionCorrectionEnabled
{
    return NO;
}

@end
