#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>

@interface AVCaptureResolvedPhotoSettings ()
- (instancetype)initRevenantWithUniqueID:(int64_t)uniqueID photoDimensions:(CMVideoDimensions)photoDimensions
                     previewDimensions:(CMVideoDimensions)previewDimensions
           embeddedThumbnailDimensions:(CMVideoDimensions)embeddedThumbnailDimensions flashEnabled:(BOOL)flashEnabled
        stillImageStabilizationEnabled:(BOOL)stillImageStabilizationEnabled;
@end

BOOL RevenantIsBayerRAWPixelFormat(OSType format);
BOOL RevenantIsAppleProRAWPixelFormat(OSType format);

__attribute__((visibility("hidden"))) void RevenantAfterFlashActiveChanges(id camera, NSTimeInterval bound, void (^then)(void));

@interface AVCapturePhotoSettings ()
+ (instancetype)revenant_settingsWithRaw:(OSType)raw rawFileType:(NSString *)rawFileType format:(NSDictionary *)format
                     processedFileType:(NSString *)processedFileType method:(NSString *)method;
@end

@interface AVCaptureResolvedPhotoSettings (RevenantInternal)
- (void)revenant_setExpectedPhotoCount:(NSUInteger)expectedPhotoCount;
@end

@interface AVCapturePhoto ()
- (instancetype)initRevenantWithSampleBuffer:(CMSampleBufferRef)photo previewSampleBuffer:(CMSampleBufferRef)preview
                          resolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings
                           bracketSettings:(AVCaptureBracketedStillImageSettings *)bracketSettings photoCount:(NSInteger)photoCount
              embeddedThumbnailPhotoFormat:(NSDictionary *)thumbnailFormat sourceDeviceType:(AVCaptureDeviceType)sourceDeviceType;
@end

CGImageRef RevenantCreatePhotoImage(CMSampleBufferRef photo, size_t longest);
