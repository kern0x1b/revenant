#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <ImageIO/ImageIO.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

@interface AVCaptureResolvedPhotoSettings (CharonProbe)
- (instancetype)initCharonWithUniqueID:(int64_t)uniqueID photoDimensions:(CMVideoDimensions)photoDimensions
                     previewDimensions:(CMVideoDimensions)previewDimensions
           embeddedThumbnailDimensions:(CMVideoDimensions)embeddedThumbnailDimensions flashEnabled:(BOOL)flashEnabled
        stillImageStabilizationEnabled:(BOOL)stillImageStabilizationEnabled;
@end

@interface AVCapturePhoto (CharonProbe)
- (instancetype)initCharonWithSampleBuffer:(CMSampleBufferRef)photo previewSampleBuffer:(CMSampleBufferRef)preview
                          resolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings
                           bracketSettings:(AVCaptureBracketedStillImageSettings *)bracketSettings photoCount:(NSInteger)photoCount
              embeddedThumbnailPhotoFormat:(NSDictionary *)thumbnailFormat sourceDeviceType:(AVCaptureDeviceType)sourceDeviceType;
@end

static int checks;
static int failed;

static void check(BOOL ok, NSString *name, NSString *detail)
{
    checks++;
    if (!ok)
        failed++;
    printf("check %s %s%s%s\n", name.UTF8String, ok ? "ok" : "FAIL", detail ? " " : "", detail ? detail.UTF8String : "");
    fflush(stdout);
}

static NSString *RaisedBy(void (^block)(void))
{
    @try {
        block();
        return nil;
    } @catch (NSException *exception) {
        return exception.name;
    }
}

static void SettingsChecks(void)
{
    AVCaptureAutoExposureBracketedStillImageSettings *minus = [AVCaptureAutoExposureBracketedStillImageSettings autoExposureSettingsWithExposureTargetBias:-1.0f];
    AVCaptureAutoExposureBracketedStillImageSettings *plus = [AVCaptureAutoExposureBracketedStillImageSettings autoExposureSettingsWithExposureTargetBias:1.0f];
    AVCaptureManualExposureBracketedStillImageSettings *manual = [AVCaptureManualExposureBracketedStillImageSettings manualExposureSettingsWithExposureDuration:CMTimeMake(1, 100) ISO:100];
    check(minus.exposureTargetBias == -1.0f && manual.ISO == 100 && CMTimeCompare(manual.exposureDuration, CMTimeMake(1, 100)) == 0,
          @"member-values", nil);

    NSDictionary *format = @{AVVideoCodecKey: AVVideoCodecJPEG};
    NSArray *members = @[minus, plus];
    AVCapturePhotoBracketSettings *bracket = [AVCapturePhotoBracketSettings photoBracketSettingsWithRawPixelFormatType:0
                                                                                                        processedFormat:format
                                                                                                      bracketedSettings:members];
    check([bracket isKindOfClass:[AVCapturePhotoBracketSettings class]] && [bracket isKindOfClass:[AVCapturePhotoSettings class]],
          @"factory-10-class", nil);
    check(bracket.bracketedSettings.count == 2 && bracket.bracketedSettings[0] == minus && bracket.bracketedSettings[1] == plus,
          @"factory-10-members", nil);
    check(!bracket.lensStabilizationEnabled, @"lens-default-no", nil);
    bracket.lensStabilizationEnabled = YES;
    check(bracket.lensStabilizationEnabled, @"lens-set-yes", nil);
    AVCapturePhotoBracketSettings *copy = [bracket copy];
    check([copy isKindOfClass:[AVCapturePhotoBracketSettings class]] && copy.bracketedSettings.count == 2 && copy.lensStabilizationEnabled,
          @"copy-keeps-bracket", nil);

    AVCapturePhotoBracketSettings *named = [AVCapturePhotoBracketSettings photoBracketSettingsWithRawPixelFormatType:0
                                                                                                         rawFileType:nil
                                                                                                     processedFormat:format
                                                                                                   processedFileType:AVFileTypeJPEG
                                                                                                   bracketedSettings:@[manual]];
    check([named isKindOfClass:[AVCapturePhotoBracketSettings class]] && [named.processedFileType isEqualToString:AVFileTypeJPEG]
              && named.bracketedSettings.count == 1 && named.bracketedSettings[0] == manual,
          @"factory-11-members", nil);

    NSArray *none = nil;
    check([RaisedBy(^{
              [AVCapturePhotoBracketSettings photoBracketSettingsWithRawPixelFormatType:0 processedFormat:format bracketedSettings:none];
          }) isEqualToString:NSInvalidArgumentException],
          @"refuse-nil-members", nil);
    check([RaisedBy(^{
              [AVCapturePhotoBracketSettings photoBracketSettingsWithRawPixelFormatType:0 processedFormat:format bracketedSettings:@[]];
          }) isEqualToString:NSInvalidArgumentException],
          @"refuse-empty-members", nil);
    check([RaisedBy(^{
              [AVCapturePhotoBracketSettings photoBracketSettingsWithRawPixelFormatType:0 processedFormat:format bracketedSettings:@[minus, manual]];
          }) isEqualToString:NSInvalidArgumentException],
          @"refuse-mixed-classes", nil);
    check([RaisedBy(^{
              [AVCapturePhotoBracketSettings photoBracketSettingsWithRawPixelFormatType:0 rawFileType:nil processedFormat:format
                                                                       processedFileType:AVFileTypeJPEG bracketedSettings:@[manual, minus]];
          }) isEqualToString:NSInvalidArgumentException],
          @"refuse-mixed-classes-11", nil);
}

@interface ProbeRecorder : NSObject <AVCapturePhotoCaptureDelegate>
@property (nonatomic, strong) NSMutableArray<NSString *> *events;
@property (nonatomic, strong) NSMutableArray<AVCapturePhoto *> *photos;
@property (nonatomic, strong) dispatch_semaphore_t finished;
@end

@implementation ProbeRecorder

- (instancetype)init
{
    if ((self = [super init])) {
        _events = [NSMutableArray array];
        _photos = [NSMutableArray array];
        _finished = dispatch_semaphore_create(0);
    }
    return self;
}

- (void)captureOutput:(AVCapturePhotoOutput *)output willBeginCaptureForResolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings
{
    @synchronized (self) { [self.events addObject:@"begin"]; }
}

- (void)captureOutput:(AVCapturePhotoOutput *)output willCapturePhotoForResolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings
{
    @synchronized (self) { [self.events addObject:@"will"]; }
}

- (void)captureOutput:(AVCapturePhotoOutput *)output didCapturePhotoForResolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings
{
    @synchronized (self) { [self.events addObject:@"did"]; }
}

- (void)captureOutput:(AVCapturePhotoOutput *)output didFinishProcessingPhoto:(AVCapturePhoto *)photo error:(NSError *)error
{
    @synchronized (self) {
        [self.events addObject:@"photo"];
        [self.photos addObject:photo];
    }
}

- (void)captureOutput:(AVCapturePhotoOutput *)output didFinishCaptureForResolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings error:(NSError *)error
{
    @synchronized (self) { [self.events addObject:@"finish"]; }
    dispatch_semaphore_signal(self.finished);
}

@end

@interface ProbeSampleRecorder : NSObject <AVCapturePhotoCaptureDelegate>
@property (nonatomic, strong) NSMutableArray<NSString *> *events;
@property (nonatomic, strong) id bracketSeen;
@property (nonatomic, strong) dispatch_semaphore_t finished;
@end

@implementation ProbeSampleRecorder

- (instancetype)init
{
    if ((self = [super init])) {
        _events = [NSMutableArray array];
        _finished = dispatch_semaphore_create(0);
    }
    return self;
}

- (void)captureOutput:(AVCapturePhotoOutput *)output didFinishProcessingPhotoSampleBuffer:(CMSampleBufferRef)photoSampleBuffer
   previewPhotoSampleBuffer:(CMSampleBufferRef)previewPhotoSampleBuffer resolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings
            bracketSettings:(AVCaptureBracketedStillImageSettings *)bracketSettings error:(NSError *)error
{
    @synchronized (self) {
        [self.events addObject:@"sample"];
        self.bracketSeen = bracketSettings;
    }
}

- (void)captureOutput:(AVCapturePhotoOutput *)output didFinishCaptureForResolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings error:(NSError *)error
{
    @synchronized (self) { [self.events addObject:@"finish"]; }
    dispatch_semaphore_signal(self.finished);
}

@end

static BOOL Wait(dispatch_semaphore_t finished)
{
    return dispatch_semaphore_wait(finished, dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC)) == 0;
}

static void OutputChecks(AVCapturePhotoOutput *output)
{
    check(output.maxBracketedCapturePhotoCount == 3, @"max-count-is-port",
          [NSString stringWithFormat:@"%lu", (unsigned long)output.maxBracketedCapturePhotoCount]);
    check(!output.lensStabilizationDuringBracketedCaptureSupported, @"lens-stabilization-unsupported", nil);

    AVCapturePhotoBracketSettings *lensBracket = [AVCapturePhotoBracketSettings
        photoBracketSettingsWithRawPixelFormatType:0 processedFormat:@{AVVideoCodecKey: AVVideoCodecJPEG}
                                 bracketedSettings:@[[AVCaptureAutoExposureBracketedStillImageSettings autoExposureSettingsWithExposureTargetBias:0]]];
    lensBracket.lensStabilizationEnabled = YES;
    ProbeRecorder *refused = [[ProbeRecorder alloc] init];
    check([RaisedBy(^{
              [output capturePhotoWithSettings:lensBracket delegate:refused];
          }) isEqualToString:NSInvalidArgumentException],
          @"refuse-lens-stabilization", nil);

    AVCapturePhotoSettings *single = [AVCapturePhotoSettings photoSettingsWithFormat:@{AVVideoCodecKey: AVVideoCodecJPEG}];
    check([RaisedBy(^{
              [output capturePhotoWithSettings:single delegate:(id<AVCapturePhotoCaptureDelegate>)[[NSObject alloc] init]];
          }) isEqualToString:NSInvalidArgumentException],
          @"refuse-delegate-without-photo-callback", nil);
}

static void BracketChecks(AVCapturePhotoOutput *output)
{
    NSArray *members = @[[AVCaptureAutoExposureBracketedStillImageSettings autoExposureSettingsWithExposureTargetBias:-1.0f],
                         [AVCaptureAutoExposureBracketedStillImageSettings autoExposureSettingsWithExposureTargetBias:0],
                         [AVCaptureAutoExposureBracketedStillImageSettings autoExposureSettingsWithExposureTargetBias:1.0f]];
    AVCapturePhotoBracketSettings *bracket = [AVCapturePhotoBracketSettings photoBracketSettingsWithRawPixelFormatType:0
                                                                                                        processedFormat:@{AVVideoCodecKey: AVVideoCodecJPEG}
                                                                                                      bracketedSettings:members];
    ProbeRecorder *recorder = [[ProbeRecorder alloc] init];
    [output capturePhotoWithSettings:bracket delegate:recorder];
    BOOL returned = Wait(recorder.finished);
    NSArray *events = nil;
    @synchronized (recorder) { events = [recorder.events copy]; }
    NSMutableArray *want = [NSMutableArray arrayWithObject:@"begin"];
    for (NSUInteger i = 0; i < members.count; i++)
        [want addObjectsFromArray:@[@"will", @"did", @"photo"]];
    [want addObject:@"finish"];
    check(returned && [events isEqualToArray:want], @"bracket-callback-order",
          [NSString stringWithFormat:@"%@ (%@)", [events componentsJoinedByString:@" "], returned ? @"returned" : @"timed out"]);
    NSArray *photos = nil;
    @synchronized (recorder) { photos = [recorder.photos copy]; }
    BOOL inOrder = photos.count == members.count;
    for (NSUInteger i = 0; inOrder && i < photos.count; i++) {
        AVCapturePhoto *photo = photos[i];
        inOrder = photo.bracketSettings == members[i] && photo.photoCount == (NSInteger)i + 1
                  && photo.resolvedSettings.expectedPhotoCount == members.count;
    }
    check(inOrder, @"bracket-photos-in-order", [NSString stringWithFormat:@"%lu photos", (unsigned long)photos.count]);
    check(photos.count > 0 && ((AVCapturePhoto *)photos[0]).resolvedSettings != nil, @"bracket-error-photos-carry-resolved", nil);
}

static void SingleSampleChecks(AVCapturePhotoOutput *output)
{
    AVCapturePhotoSettings *single = [AVCapturePhotoSettings photoSettingsWithFormat:@{AVVideoCodecKey: AVVideoCodecJPEG}];
    ProbeSampleRecorder *recorder = [[ProbeSampleRecorder alloc] init];
    [output capturePhotoWithSettings:single delegate:recorder];
    BOOL returned = Wait(recorder.finished);
    NSArray *events = nil;
    id bracketSeen = nil;
    @synchronized (recorder) {
        events = [recorder.events copy];
        bracketSeen = recorder.bracketSeen;
    }
    check(returned && [events isEqualToArray:@[@"sample", @"finish"]] && bracketSeen == nil, @"single-sample-callback",
          [NSString stringWithFormat:@"%@", [events componentsJoinedByString:@" "]]);
}

static CMVideoDimensions Dimensions(int32_t w, int32_t h)
{
    return (CMVideoDimensions){w, h};
}

static CMSampleBufferRef BGRASample(int32_t w, int32_t h)
{
    CVPixelBufferRef pixels = NULL;
    NSDictionary *surface = @{(__bridge NSString *)kCVPixelBufferIOSurfacePropertiesKey: @{}};
    CVPixelBufferCreate(kCFAllocatorDefault, w, h, kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef)surface, &pixels);
    CMVideoFormatDescriptionRef format = NULL;
    CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixels, &format);
    CMSampleTimingInfo timing = {CMTimeMake(5, 10), CMTimeMake(5, 10), kCMTimeInvalid};
    CMSampleBufferRef sample = NULL;
    CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixels, true, NULL, NULL, format, &timing, &sample);
    CFRelease(format);
    CVPixelBufferRelease(pixels);
    return sample;
}

static CMSampleBufferRef JPEGSample(int32_t w, int32_t h)
{
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, w, h, 8, 0, space, kCGImageAlphaPremultipliedLast);
    CGContextSetRGBFillColor(context, 0.2, 0.5, 0.8, 1);
    CGContextFillRect(context, CGRectMake(0, 0, w, h));
    CGImageRef image = CGBitmapContextCreateImage(context);
    NSMutableData *jpeg = [NSMutableData data];
    CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)jpeg, CFSTR("public.jpeg"), 1, NULL);
    CGImageDestinationAddImage(destination, image, NULL);
    CGImageDestinationFinalize(destination);
    CFRelease(destination);
    CGImageRelease(image);
    CGContextRelease(context);
    CGColorSpaceRelease(space);

    CMBlockBufferRef block = NULL;
    CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, NULL, jpeg.length, kCFAllocatorDefault, NULL, 0, jpeg.length, 0, &block);
    CMBlockBufferReplaceDataBytes(jpeg.bytes, block, 0, jpeg.length);
    CMVideoFormatDescriptionRef format = NULL;
    CMVideoFormatDescriptionCreate(kCFAllocatorDefault, kCMVideoCodecType_JPEG, w, h, NULL, &format);
    CMSampleBufferRef sample = NULL;
    CMSampleBufferCreate(kCFAllocatorDefault, block, true, NULL, NULL, format, 1, 0, NULL, 0, NULL, &sample);
    CFRelease(format);
    CFRelease(block);
    return sample;
}

static void PhotoObjectChecks(void)
{
    AVCaptureResolvedPhotoSettings *resolved = [[AVCaptureResolvedPhotoSettings alloc] initCharonWithUniqueID:7 photoDimensions:Dimensions(64, 48)
                                                                                           previewDimensions:Dimensions(0, 0)
                                                                                 embeddedThumbnailDimensions:Dimensions(0, 0)
                                                                                                flashEnabled:NO
                                                                              stillImageStabilizationEnabled:NO];
    CMSampleBufferRef bgra = BGRASample(64, 48);
    AVCapturePhoto *raw = [[AVCapturePhoto alloc] initCharonWithSampleBuffer:bgra previewSampleBuffer:NULL resolvedSettings:resolved
                                                             bracketSettings:nil photoCount:1 embeddedThumbnailPhotoFormat:nil
                                                             sourceDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera];
    CVPixelBufferRef buffer = raw.pixelBuffer;
    check(buffer != NULL && CVPixelBufferGetWidth(buffer) == 64 && CVPixelBufferGetHeight(buffer) == 48, @"photo-bgra-pixel-buffer", nil);
    check(raw.fileDataRepresentation == nil, @"photo-bgra-no-file", nil);
    CGImageRef image = raw.CGImageRepresentation;
    check(image != NULL && CGImageGetWidth(image) == 64 && CGImageGetHeight(image) == 48, @"photo-bgra-cgimage", nil);
    check(raw.previewPixelBuffer == NULL && raw.previewCGImageRepresentation == NULL, @"photo-bgra-no-preview", nil);
    check(!raw.isRawPhoto && raw.photoCount == 1 && raw.bracketSettings == nil && raw.resolvedSettings == resolved, @"photo-bgra-members", nil);
    check(raw.depthData == nil && raw.portraitEffectsMatte == nil && raw.cameraCalibrationData == nil && [raw.sourceDeviceType isEqualToString:AVCaptureDeviceTypeBuiltInWideAngleCamera], @"photo-no-depth-matte-calibration-source-type", nil);
    check(raw.metadata != nil && CMTIME_IS_VALID(raw.timestamp), @"photo-metadata-timestamp", nil);
    CFRelease(bgra);

    CMSampleBufferRef jpeg = JPEGSample(64, 48);
    AVCapturePhoto *jpegPhoto = [[AVCapturePhoto alloc] initCharonWithSampleBuffer:jpeg previewSampleBuffer:NULL resolvedSettings:resolved
                                                                    bracketSettings:nil photoCount:1 embeddedThumbnailPhotoFormat:nil sourceDeviceType:nil];
    NSData *file = jpegPhoto.fileDataRepresentation;
    check(jpegPhoto.pixelBuffer == NULL && file.length > 2 && ((const uint8_t *)file.bytes)[0] == 0xFF && ((const uint8_t *)file.bytes)[1] == 0xD8,
          @"photo-jpeg-file", [NSString stringWithFormat:@"%lu bytes", (unsigned long)file.length]);
    CGImageRef jpegImage = jpegPhoto.CGImageRepresentation;
    check(jpegImage != NULL && CGImageGetWidth(jpegImage) == 64, @"photo-jpeg-cgimage", nil);
    NSNumber *width = jpegPhoto.metadata[(__bridge NSString *)kCGImagePropertyPixelWidth];
    check(width.integerValue == 64, @"photo-jpeg-metadata-width", [NSString stringWithFormat:@"%@", width]);
    CFRelease(jpeg);

    AVCapturePhoto *failed = [[AVCapturePhoto alloc] initCharonWithSampleBuffer:NULL previewSampleBuffer:NULL resolvedSettings:resolved
                                                                 bracketSettings:nil photoCount:1 embeddedThumbnailPhotoFormat:nil
                                                                 sourceDeviceType:nil];
    check(failed != nil && failed.pixelBuffer == NULL && failed.fileDataRepresentation == nil && failed.CGImageRepresentation == NULL
              && failed.metadata.count == 0 && failed.resolvedSettings == resolved,
          @"photo-error-object", nil);
}

static void CheckCapture(void (^block)(void), NSString *name)
{
    NSString *raised = nil;
    @try {
        block();
    } @catch (NSException *exception) {
        raised = [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
    }
    if (raised)
        check(NO, [name stringByAppendingString:@"-raised"], raised);
}

static int RunProbe(void)
{
    SettingsChecks();

    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    AVCaptureDevice *camera = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    check(camera != nil, @"camera-present",
          [NSString stringWithFormat:@"%lu video devices", (unsigned long)[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo].count]);
    NSError *error = nil;
    AVCaptureDeviceInput *input = camera ? [AVCaptureDeviceInput deviceInputWithDevice:camera error:&error] : nil;
    check(input != nil, @"camera-input", error ? error.description : nil);
    AVCapturePhotoOutput *output = [[AVCapturePhotoOutput alloc] init];
    BOOL canInput = input != nil && [session canAddInput:input];
    BOOL canOutput = [session canAddOutput:output];
    check(canInput && canOutput, @"session-built", [NSString stringWithFormat:@"input %d output %d", canInput, canOutput]);
    if (canInput)
        [session addInput:input];
    if (canOutput)
        [session addOutput:output];
    [session startRunning];
    AVCaptureConnection *connection = [output connectionWithMediaType:AVMediaTypeVideo];
    check(connection != nil, @"connection-present", nil);

    OutputChecks(output);
    PhotoObjectChecks();
    if (connection) {
        CheckCapture(^{ BracketChecks(output); }, @"bracket");
        CheckCapture(^{ SingleSampleChecks(output); }, @"single-sample");
    }

    [session stopRunning];
    printf("checks: %d failed: %d\n", checks, failed);
    fflush(stdout);
    return failed;
}

int main(int argc, char *argv[])
{
    @autoreleasepool {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            exit(RunProbe());
        });
        dispatch_main();
    }
    return 0;
}
