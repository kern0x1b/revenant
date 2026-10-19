#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>

@interface AVCaptureResolvedPhotoSettings ()
- (instancetype)initCharonWithUniqueID:(int64_t)uniqueID photoDimensions:(CMVideoDimensions)photoDimensions
                     previewDimensions:(CMVideoDimensions)previewDimensions
           embeddedThumbnailDimensions:(CMVideoDimensions)embeddedThumbnailDimensions flashEnabled:(BOOL)flashEnabled
        stillImageStabilizationEnabled:(BOOL)stillImageStabilizationEnabled;
@end

BOOL CharonIsBayerRAWPixelFormat(OSType format);
BOOL CharonIsAppleProRAWPixelFormat(OSType format);

__attribute__((visibility("hidden"))) void CharonAfterFlashActiveChanges(id camera, NSTimeInterval bound, void (^then)(void));

@interface AVCapturePhotoSettings ()
+ (instancetype)charon_settingsWithRaw:(OSType)raw rawFileType:(NSString *)rawFileType format:(NSDictionary *)format
                     processedFileType:(NSString *)processedFileType method:(NSString *)method;
@end

@interface AVCaptureResolvedPhotoSettings (CharonInternal)
- (void)charon_setExpectedPhotoCount:(NSUInteger)expectedPhotoCount;
@end

@interface AVCapturePhoto ()
- (instancetype)initCharonWithSampleBuffer:(CMSampleBufferRef)photo previewSampleBuffer:(CMSampleBufferRef)preview
                          resolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings
                           bracketSettings:(AVCaptureBracketedStillImageSettings *)bracketSettings photoCount:(NSInteger)photoCount
              embeddedThumbnailPhotoFormat:(NSDictionary *)thumbnailFormat sourceDeviceType:(AVCaptureDeviceType)sourceDeviceType;
@end

CGImageRef CharonCreatePhotoImage(CMSampleBufferRef photo, size_t longest);
