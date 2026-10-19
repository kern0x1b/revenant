#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>

// How AVCapturePhotoOutput.m makes the resolved settings of a request (AVCaptureResolvedPhotoSettings.m).
@interface AVCaptureResolvedPhotoSettings ()
- (instancetype)initCharonWithUniqueID:(int64_t)uniqueID photoDimensions:(CMVideoDimensions)photoDimensions
                     previewDimensions:(CMVideoDimensions)previewDimensions
           embeddedThumbnailDimensions:(CMVideoDimensions)embeddedThumbnailDimensions flashEnabled:(BOOL)flashEnabled
        stillImageStabilizationEnabled:(BOOL)stillImageStabilizationEnabled;
@end

// The RAW pixel formats, Bayer and Apple ProRAW (AVCapturePhotoSettings.m), for the settings and the output alike.
BOOL CharonIsBayerRAWPixelFormat(OSType format);
BOOL CharonIsAppleProRAWPixelFormat(OSType format);

// The wait of a capture for the camera's flash (AVCapturePhotoOutput.m): `then` runs once, at the first change of the
// camera's flashActive or after `bound` seconds. Hidden, for the host test of the photo output.
__attribute__((visibility("hidden"))) void CharonAfterFlashActiveChanges(id camera, NSTimeInterval bound, void (^then)(void));

// The one constructor of the photo settings (AVCapturePhotoSettings.m), for AVCapturePhotoBracketSettings.m, which allocates
// through it so a bracket is made by the same checks as a single photo's settings.
@interface AVCapturePhotoSettings ()
+ (instancetype)charon_settingsWithRaw:(OSType)raw rawFileType:(NSString *)rawFileType format:(NSDictionary *)format
                     processedFileType:(NSString *)processedFileType method:(NSString *)method;
@end

// The resolved settings' count of photos one request delivers (AVCaptureResolvedPhotoSettings.m): one for a single photo, the
// bracket's count for a bracket, which the capture sets before the request's first callback.
@interface AVCaptureResolvedPhotoSettings (CharonInternal)
- (void)charon_setExpectedPhotoCount:(NSUInteger)expectedPhotoCount;
@end

// AVCapturePhoto, iOS 11.0 (AVCapturePhoto11.m): the photo a capture delivers through -captureOutput:didFinishProcessingPhoto:error:.
// The object keeps the sample buffers it is given, retained.
@interface AVCapturePhoto ()
- (instancetype)initCharonWithSampleBuffer:(CMSampleBufferRef)photo previewSampleBuffer:(CMSampleBufferRef)preview
                          resolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings
                           bracketSettings:(AVCaptureBracketedStillImageSettings *)bracketSettings photoCount:(NSInteger)photoCount
              embeddedThumbnailPhotoFormat:(NSDictionary *)thumbnailFormat sourceDeviceType:(AVCaptureDeviceType)sourceDeviceType;
@end

// The still of `photo` no longer on its longest side than `longest`, as a CGImage the caller owns (AVCapturePhotoOutput.m).
CGImageRef CharonCreatePhotoImage(CMSampleBufferRef photo, size_t longest);
