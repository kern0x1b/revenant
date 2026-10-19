#import <AVFoundation/AVFoundation.h>
#import <ImageIO/ImageIO.h>
#import <UIKit/UIKit.h>
#import "check.h"
#import "jpeg-exif.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

// AVCapturePhotoOutput as the release's still image output (facts/AVFoundation/AVCapturePhotoOutput.md):
// the release's own output in the same session as the control, the formats offered, the refusals, real
// captures with a preview at the display's size and at a size asked for, an uncompressed photo, a zoomed
// one, the flash modes, and the resolved settings every capture reports. Built with AVCapturePhotoOutput.m, the
// zoom's files, Accelerate/vImageYpCbCr8.m and Graphics/ImageIONames70.m, as the library carries them. A process of its own: the camera needs no permission on 6.1.3.
// The camera's flash is held Off, and the run sets neither On nor Auto on it unless asked, as they fire the flash of a
// device someone may be using: `photooutput <log> flash-on` takes the captures with the flash On and Auto,
// `photooutput <log> flash-auto` the one capture in Auto alone, and `photooutput <log> flash-scene` (or either of the
// others) monitors the scene for Auto, with a capture Off in between.

@interface CharonPhotoCatcher : NSObject <AVCapturePhotoCaptureDelegate>
@property (atomic) BOOL finished;
@property (atomic) size_t photoWidth, photoHeight, previewWidth, previewHeight;
@property (atomic) OSType previewFormat;
@property (atomic) BOOL hadPreview, photoIsJPEG, photoIsBGRA;
// The mean difference per channel, in levels of 255, between the preview and the photo drawn at the preview's
// size by the probe, and the same against the photo turned upside down (the control: a preview that is not the
// photo, or is drawn the wrong way up, is as far from one as from the other).
@property (atomic) double previewDifference, flippedDifference, previewSpread;
@property (atomic, strong) NSError *error;
// The resolved settings each callback was given, and what they answered at willBeginCapture and at the photo.
@property (atomic, strong) NSMutableArray *resolvedSeen, *callbacks;
@property (atomic) CMVideoDimensions beganPhoto, beganPreview, resolvedPhoto, resolvedPreview, resolvedRaw, resolvedLive, resolvedThumbnail;
// A JPEG photo as files: the sample buffer's own bytes, the port's +JPEGPhotoDataRepresentation... of it without and with
// its preview, and the release's +jpegStillImageNSDataRepresentation: of it.
@property (atomic, strong) NSData *photoBytes, *photoJPEG, *photoJPEGWithPreview, *releaseJPEG;
@property (atomic) BOOL beganFlash, resolvedFlash, resolvedStabilized;
@property (atomic) int64_t resolvedID;
// The Exif Flash tag the release attached to the still, -1 when there is none.
@property (atomic) long stillFlash;
// The {MakerApple} attachment of the photo's sample buffer, nil when it carries none.
@property (atomic, strong) NSDictionary *attachedMaker;
// The camera's flash mode at willCapturePhoto, right before the still image output is asked for the still.
@property (atomic) long cameraFlashAtCapture;
@end

static AVCaptureDevice *charon_camera;

// The photo as an image: a JPEG through UIImage, a 32BGRA buffer through a bitmap context over its bytes.
static CGImageRef create_photo_image(CMSampleBufferRef photo, BOOL *jpeg, BOOL *bgra)
{
    CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(photo);
    if (format && CMFormatDescriptionGetMediaSubType(format) == kCMVideoCodecType_JPEG) {
        NSData *data = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:photo];
        UIImage *image = data ? [UIImage imageWithData:data] : nil;
        *jpeg = image != nil;
        return image ? CGImageRetain(image.CGImage) : NULL;
    }
    CVPixelBufferRef pixels = CMSampleBufferGetImageBuffer(photo);
    if (!pixels || CVPixelBufferGetPixelFormatType(pixels) != kCVPixelFormatType_32BGRA)
        return NULL;
    *bgra = YES;
    CVPixelBufferLockBaseAddress(pixels, kCVPixelBufferLock_ReadOnly);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(CVPixelBufferGetBaseAddress(pixels), CVPixelBufferGetWidth(pixels), CVPixelBufferGetHeight(pixels), 8,
                                                 CVPixelBufferGetBytesPerRow(pixels), space, kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little);
    CGImageRef image = context ? CGBitmapContextCreateImage(context) : NULL;
    if (context)
        CGContextRelease(context);
    CGColorSpaceRelease(space);
    CVPixelBufferUnlockBaseAddress(pixels, kCVPixelBufferLock_ReadOnly);
    return image;
}

static double difference(CVPixelBufferRef preview, CGImageRef photo, BOOL flipped)
{
    size_t width = CVPixelBufferGetWidth(preview), height = CVPixelBufferGetHeight(preview);
    NSMutableData *drawn = [NSMutableData dataWithLength:width * height * 4];
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(drawn.mutableBytes, width, height, 8, width * 4, space, kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little);
    CGColorSpaceRelease(space);
    if (flipped) {
        CGContextTranslateCTM(context, 0, height);
        CGContextScaleCTM(context, 1, -1);
    }
    CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), photo);
    CGContextRelease(context);
    CVPixelBufferLockBaseAddress(preview, kCVPixelBufferLock_ReadOnly);
    const uint8_t *ours = drawn.bytes;
    double total = 0;
    OSType format = CVPixelBufferGetPixelFormatType(preview);
    if (format == kCVPixelFormatType_32BGRA) {
        const uint8_t *base = CVPixelBufferGetBaseAddress(preview);
        size_t row = CVPixelBufferGetBytesPerRow(preview);
        for (size_t y = 0; y < height; y++)
            for (size_t x = 0; x < width; x++)
                for (int c = 0; c < 3; c++)
                    total += abs((int)base[y * row + x * 4 + c] - (int)ours[(y * width + x) * 4 + c]);
        total /= 3;
    } else {
        // A 4:2:0 preview: its luma plane against the luma of the probe's drawing by ITU-R BT.601 (0.299 R + 0.587 G +
        // 0.114 B), in levels of 255 over the preview's range (16...235 for video range, 0...255 for full range).
        BOOL full = format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
        const uint8_t *luma = CVPixelBufferGetBaseAddressOfPlane(preview, 0);
        size_t row = CVPixelBufferGetBytesPerRowOfPlane(preview, 0);
        for (size_t y = 0; y < height; y++)
            for (size_t x = 0; x < width; x++) {
                const uint8_t *pixel = ours + (y * width + x) * 4;
                double expected = 0.299 * pixel[2] + 0.587 * pixel[1] + 0.114 * pixel[0];
                double measured = full ? luma[y * row + x] : (luma[y * row + x] - 16) * 255.0 / 219;
                total += fabs(measured - expected);
            }
    }
    CVPixelBufferUnlockBaseAddress(preview, kCVPixelBufferLock_ReadOnly);
    return total / (width * height);
}

// How much the picture varies: the mean distance of a channel from its mean, in levels of 255. A picture of one
// colour, which any wrong drawing could match, has none.
static double spread(CVPixelBufferRef preview)
{
    size_t width = CVPixelBufferGetWidth(preview), height = CVPixelBufferGetHeight(preview), row = CVPixelBufferGetBytesPerRow(preview);
    CVPixelBufferLockBaseAddress(preview, kCVPixelBufferLock_ReadOnly);
    const uint8_t *base = CVPixelBufferGetBaseAddress(preview);
    double mean[3] = {0, 0, 0}, total = 0;
    for (size_t y = 0; y < height; y++)
        for (size_t x = 0; x < width; x++)
            for (int c = 0; c < 3; c++)
                mean[c] += base[y * row + x * 4 + c];
    for (int c = 0; c < 3; c++)
        mean[c] /= width * height;
    for (size_t y = 0; y < height; y++)
        for (size_t x = 0; x < width; x++)
            for (int c = 0; c < 3; c++)
                total += fabs(base[y * row + x * 4 + c] - mean[c]);
    CVPixelBufferUnlockBaseAddress(preview, kCVPixelBufferLock_ReadOnly);
    printf("preview mean B %.1f G %.1f R %.1f\n", mean[0], mean[1], mean[2]);
    return total / (width * height * 3);
}

@implementation CharonPhotoCatcher

- (instancetype)init
{
    if ((self = [super init])) {
        _resolvedSeen = [NSMutableArray array];
        _callbacks = [NSMutableArray array];
    }
    return self;
}

- (void)captureOutput:(AVCapturePhotoOutput *)output willBeginCaptureForResolvedSettings:(AVCaptureResolvedPhotoSettings *)resolved
{
    [self.resolvedSeen addObject:resolved];
    [self.callbacks addObject:@"willBegin"];
    self.beganPhoto = resolved.photoDimensions;
    self.beganPreview = resolved.previewDimensions;
    self.beganFlash = resolved.flashEnabled;
}

- (void)captureOutput:(AVCapturePhotoOutput *)output willCapturePhotoForResolvedSettings:(AVCaptureResolvedPhotoSettings *)resolved
{
    [self.resolvedSeen addObject:resolved];
    [self.callbacks addObject:@"willCapture"];
    self.cameraFlashAtCapture = charon_camera.flashMode;
}

- (void)captureOutput:(AVCapturePhotoOutput *)output didCapturePhotoForResolvedSettings:(AVCaptureResolvedPhotoSettings *)resolved
{
    [self.resolvedSeen addObject:resolved];
    [self.callbacks addObject:@"didCapture"];
}

- (void)captureOutput:(AVCapturePhotoOutput *)output didFinishCaptureForResolvedSettings:(AVCaptureResolvedPhotoSettings *)resolved error:(NSError *)error
{
    [self.resolvedSeen addObject:resolved];
    [self.callbacks addObject:@"didFinishCapture"];
}

- (void)captureOutput:(AVCapturePhotoOutput *)output didFinishProcessingPhotoSampleBuffer:(CMSampleBufferRef)photo
    previewPhotoSampleBuffer:(CMSampleBufferRef)preview resolvedSettings:(AVCaptureResolvedPhotoSettings *)resolved
    bracketSettings:(AVCaptureBracketedStillImageSettings *)bracket error:(NSError *)error
{
    self.error = error;
    [self.resolvedSeen addObject:resolved];
    [self.callbacks addObject:@"didFinishProcessing"];
    self.resolvedID = resolved.uniqueID;
    self.resolvedPhoto = resolved.photoDimensions;
    self.resolvedPreview = resolved.previewDimensions;
    self.resolvedRaw = resolved.rawPhotoDimensions;
    self.resolvedLive = resolved.livePhotoMovieDimensions;
    self.resolvedThumbnail = resolved.embeddedThumbnailDimensions;
    self.resolvedFlash = resolved.flashEnabled;
    self.resolvedStabilized = resolved.stillImageStabilizationEnabled;
    CFDictionaryRef exif = photo ? CMGetAttachment(photo, kCGImagePropertyExifDictionary, NULL) : NULL;
    NSNumber *flashTag = exif ? ((__bridge NSDictionary *)exif)[(__bridge NSString *)kCGImagePropertyExifFlash] : nil;
    self.stillFlash = flashTag ? flashTag.longValue : -1;
    CFTypeRef maker = photo ? CMGetAttachment(photo, kCGImagePropertyMakerAppleDictionary, NULL) : NULL;
    self.attachedMaker = maker ? (__bridge NSDictionary *)maker : nil;
    BOOL jpeg = NO, bgra = NO;
    CGImageRef image = photo ? create_photo_image(photo, &jpeg, &bgra) : NULL;
    self.photoIsJPEG = jpeg;
    CMBlockBufferRef block = jpeg ? CMSampleBufferGetDataBuffer(photo) : NULL;
    if (block) {
        NSMutableData *bytes = [NSMutableData dataWithLength:CMBlockBufferGetDataLength(block)];
        if (CMBlockBufferCopyDataBytes(block, 0, bytes.length, bytes.mutableBytes) == kCMBlockBufferNoErr)
            self.photoBytes = bytes;
        self.photoJPEG = [AVCapturePhotoOutput JPEGPhotoDataRepresentationForJPEGSampleBuffer:photo previewPhotoSampleBuffer:NULL];
        self.photoJPEGWithPreview = preview ? [AVCapturePhotoOutput JPEGPhotoDataRepresentationForJPEGSampleBuffer:photo previewPhotoSampleBuffer:preview] : nil;
        self.releaseJPEG = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:photo];
    }
    self.photoIsBGRA = bgra;
    self.photoWidth = image ? CGImageGetWidth(image) : 0;
    self.photoHeight = image ? CGImageGetHeight(image) : 0;
    CVImageBufferRef pixels = preview ? CMSampleBufferGetImageBuffer(preview) : NULL;
    self.hadPreview = pixels != NULL;
    if (pixels) {
        self.previewWidth = CVPixelBufferGetWidth(pixels);
        self.previewHeight = CVPixelBufferGetHeight(pixels);
        self.previewFormat = CVPixelBufferGetPixelFormatType(pixels);
        if (image) {
            self.previewDifference = difference(pixels, image, NO);
            self.flippedDifference = difference(pixels, image, YES);
            if (self.previewFormat == kCVPixelFormatType_32BGRA)
                self.previewSpread = spread(pixels);
        }
    }
    if (image)
        CGImageRelease(image);
    self.finished = YES;
}

@end

static NSString *raised(void (^block)(void))
{
    @try {
        block();
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
    }
    return @"nothing";
}

static BOOL same_dimensions(CMVideoDimensions a, CMVideoDimensions b)
{
    return a.width == b.width && a.height == b.height;
}

// What the header says of the resolved settings, against what the capture delivered: one object for every callback of
// the request, under the request's unique ID, answering at willBeginCapture the dimensions of the photo and preview
// buffers that come after, no RAW photo and no Live Photo movie (none asked for, none this release can make), and no
// still image stabilization on 6.x, which has none.
static void check_resolved(CharonPhotoCatcher *c, AVCapturePhotoSettings *settings)
{
    AVCaptureResolvedPhotoSettings *first = c.resolvedSeen.firstObject;
    BOOL one = c.resolvedSeen.count == 5;
    for (id seen in c.resolvedSeen)
        one = one && seen == first;
    CMVideoDimensions photo = c.resolvedPhoto, preview = c.resolvedPreview, began = c.beganPhoto;
    printf("resolved: %d x %zu callbacks, id %lld of %lld, photo %dx%d (at will begin %dx%d), preview %dx%d, raw %dx%d, live %dx%d, flash %d, stabilized %d\n",
           one, c.resolvedSeen.count, c.resolvedID, settings.uniqueID, photo.width, photo.height, began.width, began.height, preview.width, preview.height,
           c.resolvedRaw.width, c.resolvedRaw.height, c.resolvedLive.width, c.resolvedLive.height, c.resolvedFlash, c.resolvedStabilized);
    CHECK(one && c.resolvedID == settings.uniqueID, "every callback of a capture gets one resolved settings, under the request's unique ID");
    CHECK_EQUAL(c.callbacks, (@[@"willBegin", @"willCapture", @"didCapture", @"didFinishProcessing", @"didFinishCapture"]), "in the header's order");
    CHECK(photo.width == (int32_t)c.photoWidth && photo.height == (int32_t)c.photoHeight, "its photo dimensions are the photo's");
    CHECK(same_dimensions(preview, (CMVideoDimensions){(int32_t)c.previewWidth, (int32_t)c.previewHeight}), "its preview dimensions the preview's, 0x0 with none");
    CHECK(same_dimensions(began, photo) && same_dimensions(c.beganPreview, preview) && c.beganFlash == c.resolvedFlash, "and it says both already at willBeginCapture");
    CHECK(same_dimensions(c.resolvedRaw, (CMVideoDimensions){0, 0}) && same_dimensions(c.resolvedLive, (CMVideoDimensions){0, 0}), "no RAW photo, no Live Photo movie");
    CHECK(!c.resolvedStabilized, "no still image stabilization on this release");
    CHECK(settings.embeddedThumbnailPhotoFormat || same_dimensions(c.resolvedThumbnail, (CMVideoDimensions){0, 0}), "no embedded thumbnail when none is asked");
    CHECK(settings.flashMode != AVCaptureFlashModeOff || !c.resolvedFlash, "the flash is not enabled when it is asked Off");
}

static CharonPhotoCatcher *capture_with(AVCapturePhotoOutput *output, AVCapturePhotoSettings *settings, NSDictionary *preview)
{
    settings.previewPhotoFormat = preview;
    CharonPhotoCatcher *catcher = [[CharonPhotoCatcher alloc] init];
    AVCaptureInputPort *port = [output connectionWithMediaType:AVMediaTypeVideo].inputPorts.firstObject;
    CMVideoDimensions portDimensions = port.formatDescription ? CMVideoFormatDescriptionGetDimensions(port.formatDescription) : (CMVideoDimensions){0, 0};
    printf("port before the capture: %s %dx%d\n", port.formatDescription ? "format" : "no format", portDimensions.width, portDimensions.height);
    [output capturePhotoWithSettings:settings delegate:catcher];
    for (int i = 0; i < 200 && !catcher.finished; i++)
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    printf("capture: finished %d, error %s, preview against the photo %.2f, upside down %.2f, spread %.2f\n", catcher.finished,
           catcher.error.description.UTF8String ?: "none", catcher.previewDifference, catcher.flippedDifference, catcher.previewSpread);
    if (catcher.finished)
        check_resolved(catcher, settings);
    return catcher;
}

static CharonPhotoCatcher *capture(AVCapturePhotoOutput *output, NSDictionary *preview)
{
    return capture_with(output, [AVCapturePhotoSettings photoSettings], preview);
}

// The preview is the photo, drawn the right way up: within a few levels of the probe's own drawing of it, and
// further from the photo turned upside down.
static BOOL drawn_from_photo(CharonPhotoCatcher *c)
{
    return c.hadPreview && c.previewDifference < 6 && c.flippedDifference > c.previewDifference;
}

// The control: the release's own still image output, captured the way the facade captures, so a failure can be
// told from the release's answer.
// The {MakerApple} dictionary and the MakerNote of a JPEG, read through ImageIO: what the release's own JPEG writer kept of it.
static NSDictionary *maker_apple(NSData *jpeg)
{
    CGImageSourceRef source = jpeg ? CGImageSourceCreateWithData((__bridge CFDataRef)jpeg, NULL) : NULL;
    NSDictionary *properties = source ? CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, NULL)) : nil;
    if (source)
        CFRelease(source);
    return properties[(__bridge NSString *)kCGImagePropertyMakerAppleDictionary];
}

static BOOL has_maker_note(NSData *jpeg)
{
    return jpeg && [jpeg rangeOfData:[NSData dataWithBytes:"Apple iOS" length:9] options:0 range:NSMakeRange(0, jpeg.length)].location != NSNotFound;
}

static BOOL bare_capture(AVCaptureStillImageOutput *still, const char *label)
{
    AVCaptureConnection *connection = [still connectionWithMediaType:AVMediaTypeVideo];
    __block BOOL finished = NO;
    __block NSError *failure = nil;
    __block size_t width = 0, height = 0;
    printf("%s: connection %p active %d enabled %d, capturing %d\n", label, (__bridge void *)connection, connection.active, connection.enabled,
           still.capturingStillImage);
    [still captureStillImageAsynchronouslyFromConnection:connection completionHandler:^(CMSampleBufferRef buffer, NSError *error) {
        failure = error;
        NSData *data = buffer ? [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:buffer] : nil;
        UIImage *image = data ? [UIImage imageWithData:data] : nil;
        width = (size_t)CGImageGetWidth(image.CGImage);
        height = (size_t)CGImageGetHeight(image.CGImage);
        finished = YES;
    }];
    for (int i = 0; i < 200 && !finished; i++)
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    printf("%s: finished %d, photo %zux%zu, error %s\n", label, finished, width, height, failure.description.UTF8String ?: "none");
    return finished && !failure && width > 0;
}

// The preview keeps the photo's aspect ratio to within the rounding of one pixel.
static BOOL same_aspect(CharonPhotoCatcher *c)
{
    double photo = (double)c.photoWidth / c.photoHeight, preview = (double)c.previewWidth / c.previewHeight;
    return fabs(photo * c.previewHeight - c.previewWidth) <= 1 || fabs(preview - photo) < 0.01;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        AVCapturePhotoSettings *probe = [AVCapturePhotoSettings photoSettings];
        NSArray *previewFormats = @[@(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange), @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange), @(kCVPixelFormatType_32BGRA)];
        CHECK_EQUAL(probe.availablePreviewPhotoPixelFormatTypes, previewFormats, "the preview formats offered are the host's: 420f, 420v, 32BGRA");

        AVCaptureSession *session = [[AVCaptureSession alloc] init];
        session.sessionPreset = AVCaptureSessionPresetPhoto;
        AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo] error:NULL];
        [session addInput:input];
        AVCaptureDevice *camera = input.device;
        AVCaptureFlashMode cameraFlash = camera.flashMode;
        charon_camera = camera;
        BOOL flashOn = argc > 2 && strcmp(argv[2], "flash-on") == 0, flashAuto = argc > 2 && strcmp(argv[2], "flash-auto") == 0;
        BOOL flashScene = flashOn || flashAuto || (argc > 2 && strcmp(argv[2], "flash-scene") == 0);
        if (camera.hasFlash && [camera lockForConfiguration:NULL]) {
            camera.flashMode = AVCaptureFlashModeOff;
            [camera unlockForConfiguration];
        }

        AVCaptureStillImageOutput *bare = [[AVCaptureStillImageOutput alloc] init];
        CHECK(input && [session canAddOutput:bare], "the camera and the release's still image output go into a session");
        [session addOutput:bare];
        [session startRunning];
        [NSThread sleepForTimeInterval:2];
        CHECK(bare_capture(bare, "control 1"), "the release's still image output captures a JPEG");
        CHECK(bare_capture(bare, "control 2"), "and captures again");
        [session beginConfiguration];
        [session removeOutput:bare];
        [session commitConfiguration];

        AVCapturePhotoOutput *output = [[AVCapturePhotoOutput alloc] init];
        CHECK([session canAddOutput:output], "the photo output goes into the same session");
        [session beginConfiguration];
        [session addOutput:output];
        [session commitConfiguration];
        [NSThread sleepForTimeInterval:2];
        CHECK_EQUAL(NSStringFromClass([output class]), @"AVCapturePhotoOutput", "the photo output keeps its class's name");
        CHECK([session.outputs containsObject:output], "and the session's outputs hold it");

        NSString *wrongFormat = raised(^{ capture(output, @{(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_422YpCbCr8)}); });
        CHECK([wrongFormat hasPrefix:@"NSInvalidArgumentException"], "a preview format not offered raises");
        NSString *halfSize = raised(^{ capture(output, @{(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
                                                         (__bridge NSString *)kCVPixelBufferWidthKey: @160}); });
        CHECK([halfSize hasPrefix:@"NSInvalidArgumentException"], "a width without a height raises");

        CharonPhotoCatcher *none = capture(output, nil);
        CHECK(none.finished && none.photoIsJPEG && !none.hadPreview, "without a preview format the photo comes alone");

        UIScreen *screen = [UIScreen mainScreen];
        size_t display = (size_t)(MAX(screen.bounds.size.width, screen.bounds.size.height) * screen.scale);
        CharonPhotoCatcher *full = capture(output, @{(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)});
        printf("photo %zux%zu, display longest %zu, preview %zux%zu format %08x\n", full.photoWidth, full.photoHeight, display, full.previewWidth, full.previewHeight,
               (unsigned)full.previewFormat);
        CHECK(full.finished && full.error == nil && full.hadPreview, "a preview comes with the photo");
        CHECK(full.previewFormat == kCVPixelFormatType_32BGRA, "in 32BGRA");
        CHECK(MAX(full.previewWidth, full.previewHeight) == MIN(display, MAX(full.photoWidth, full.photoHeight)), "at the display's size, or the photo's when smaller");
        CHECK(same_aspect(full), "with the photo's aspect ratio");
        CHECK(drawn_from_photo(full), "and it is the photo, drawn the right way up");

        CharonPhotoCatcher *asked = capture(output, @{(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
                                                      (__bridge NSString *)kCVPixelBufferWidthKey: @160, (__bridge NSString *)kCVPixelBufferHeightKey: @160});
        printf("asked 160x160: preview %zux%zu\n", asked.previewWidth, asked.previewHeight);
        CHECK(asked.hadPreview && MAX(asked.previewWidth, asked.previewHeight) == 160, "a size asked for sets the longest side");
        CHECK(same_aspect(asked), "and the photo's aspect ratio is kept, not the one asked");
        CHECK(drawn_from_photo(asked), "and it is the photo at that size");

        // The 4:2:0 previews, converted from the port's drawing by BT.601: the format asked, at the display's size, and
        // their luma the photo's, the right way up.
        for (NSNumber *format in @[@(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange), @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]) {
            CharonPhotoCatcher *ycbcr = capture(output, @{(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: format});
            printf("preview %08x: %zux%zu format %08x, luma against the photo %.2f, upside down %.2f\n", format.unsignedIntValue, ycbcr.previewWidth,
                   ycbcr.previewHeight, (unsigned)ycbcr.previewFormat, ycbcr.previewDifference, ycbcr.flippedDifference);
            CHECK(ycbcr.finished && ycbcr.error == nil && ycbcr.hadPreview && ycbcr.previewFormat == format.unsignedIntValue, "a 4:2:0 preview comes in the format asked");
            CHECK(ycbcr.previewWidth == full.previewWidth && ycbcr.previewHeight == full.previewHeight, "at the same size as the 32BGRA one");
            CHECK(drawn_from_photo(ycbcr), "and its luma is the photo's, the right way up");
        }

        CharonPhotoCatcher *huge = capture(output, @{(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
                                                     (__bridge NSString *)kCVPixelBufferWidthKey: @100000, (__bridge NSString *)kCVPixelBufferHeightKey: @100000});
        CHECK(huge.hadPreview && MAX(huge.previewWidth, huge.previewHeight) == MAX(full.previewWidth, full.previewHeight), "a size past the display is held to it");

        // An uncompressed photo: its preview is drawn through CoreImage, and the next photo settings without a format
        // ask for a JPEG again.
        NSArray *formats = output.availablePhotoPixelFormatTypes;
        printf("photo pixel formats:");
        for (NSNumber *format in formats)
            printf(" %08x", format.unsignedIntValue);
        printf("\n");
        CHECK([formats containsObject:@(kCVPixelFormatType_32BGRA)], "the photo output offers the release's uncompressed 32BGRA");
        AVCapturePhotoSettings *uncompressed = [AVCapturePhotoSettings photoSettingsWithFormat:@{(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)}];
        CharonPhotoCatcher *raw = capture_with(output, uncompressed, @{(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
                                                                        (__bridge NSString *)kCVPixelBufferWidthKey: @320, (__bridge NSString *)kCVPixelBufferHeightKey: @320});
        printf("uncompressed: photo %zux%zu bgra %d, preview %zux%zu\n", raw.photoWidth, raw.photoHeight, raw.photoIsBGRA, raw.previewWidth, raw.previewHeight);
        CHECK(raw.finished && raw.error == nil && raw.photoIsBGRA, "a format asked for gives an uncompressed photo");
        CHECK(MAX(raw.previewWidth, raw.previewHeight) == 320 && same_aspect(raw) && drawn_from_photo(raw), "whose preview is the photo at the size asked");
        CharonPhotoCatcher *again = capture(output, nil);
        CHECK(again.finished && again.photoIsJPEG, "the next settings without a format take a JPEG again");

        // The embedded thumbnail: asked in a JPEG's settings, a JPEG in IFD1 of the photo's own Exif at the resolved
        // dimensions (the larger side asked, the host's 160 with none, the photo's aspect ratio), read here by the Exif
        // layout, and kept in the port's JPEG of the photo; with the preview given, the port's JPEG holds the preview
        // no longer than 160 on its longest side, as the host writes it. What the release's own JPEG does is printed.
        CHECK_EQUAL([probe availableEmbeddedThumbnailPhotoCodecTypes], @[AVVideoCodecJPEG], "a JPEG photo offers a JPEG thumbnail");
        CHECK_EQUAL([uncompressed availableEmbeddedThumbnailPhotoCodecTypes], @[], "an uncompressed one none");
        CHECK([raised(^{ uncompressed.embeddedThumbnailPhotoFormat = @{AVVideoCodecKey: AVVideoCodecJPEG}; }) hasPrefix:@"NSInvalidArgumentException"],
              "and a thumbnail asked of it raises");
        NSString *layout = @"IFD1 0103/3/1=6 011a/5/1=72/1 011b/5/1=72/1 0128/3/1=2 0201/4/1=set 0202/4/1=set next 0;";
        NSArray *thumbnailFormats = @[@{AVVideoCodecKey: AVVideoCodecJPEG}, @{AVVideoCodecKey: AVVideoCodecJPEG, AVVideoWidthKey: @320, AVVideoHeightKey: @320}];
        AVCapturePhotoSettings *captured = nil;
        for (NSDictionary *thumbnailFormat in thumbnailFormats) {
            AVCapturePhotoSettings *thumbnailed = [AVCapturePhotoSettings photoSettings];
            thumbnailed.embeddedThumbnailPhotoFormat = thumbnailFormat;
            thumbnailed.metadata = @{(__bridge NSString *)kCGImagePropertyExifDictionary: @{(__bridge NSString *)kCGImagePropertyExifUserComment: @"photooutput10"}};
            CharonPhotoCatcher *t = capture_with(output, thumbnailed, @{(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)});
            captured = thumbnailed;
            CMVideoDimensions dimensions = t.resolvedThumbnail;
            size_t longest = thumbnailFormat[AVVideoWidthKey] ? 320 : 160;
            double scale = MIN(1.0, 160.0 / MAX(t.previewWidth, t.previewHeight));
            NSString *expected = [NSString stringWithFormat:@"%@ thumbnail %dx%d", layout, dimensions.width, dimensions.height];
            NSString *withPreview = [NSString stringWithFormat:@"%@ thumbnail %ldx%ld", layout, lround(t.previewWidth * scale), lround(t.previewHeight * scale)];
            NSString *own = jpeg_contents(t.photoBytes), *port = jpeg_contents(t.photoJPEG), *release = jpeg_contents(t.releaseJPEG);
            NSString *portWithPreview = jpeg_contents(t.photoJPEGWithPreview);
            printf("thumbnail %s: resolved %dx%d\n  photo's bytes: %s\n  port's JPEG: %s\n  port's JPEG with the preview: %s\n  release's JPEG: %s\n",
                   [[thumbnailFormat description] stringByReplacingOccurrencesOfString:@"\n" withString:@""].UTF8String, dimensions.width, dimensions.height,
                   own.UTF8String, port.UTF8String, portWithPreview.UTF8String, release.UTF8String);
            CHECK(t.finished && t.error == nil && t.photoIsJPEG, "a photo asked with a thumbnail comes");
            CHECK((size_t)MAX(dimensions.width, dimensions.height) == longest && labs((long)dimensions.width * (long)t.photoHeight - (long)dimensions.height * (long)t.photoWidth) < (long)MAX(t.photoWidth, t.photoHeight),
                  "its thumbnail resolves to the longest side asked and the photo's aspect ratio");
            CHECK([own hasSuffix:expected], "the photo's own JPEG holds it in IFD1 of its Exif, at those dimensions");
            CHECK([port hasSuffix:expected], "and the port's JPEG of the photo keeps it");
            NSString *picture = [NSString stringWithFormat:@"%zux%zu comment photooutput10;", t.photoWidth, t.photoHeight];
            CHECK([port hasPrefix:picture], "the port's JPEG carries the settings' metadata");
            CHECK([release hasPrefix:picture], "and so does the release's JPEG of the photo");
            CHECK([portWithPreview hasSuffix:withPreview], "with the preview given, the port's JPEG holds the preview, 160 on its longest side");
        }

        // {MakerApple}: the settings take the key, as the host does, and the capture merges it into the still's attachments.
        // Whether 6.1.3's JPEG writer keeps it is measured against a capture without it, and printed.
        {
            NSString *maker = (__bridge NSString *)kCGImagePropertyMakerAppleDictionary;
            CharonPhotoCatcher *plain = capture_with(output, [AVCapturePhotoSettings photoSettings], nil);
            AVCapturePhotoSettings *marked = [AVCapturePhotoSettings photoSettings];
            NSString *taken = raised(^{ marked.metadata = @{maker: @{@"1": @77}}; });
            CHECK([taken isEqualToString:@"nothing"] && [marked.metadata[maker][@"1"] isEqual:@77], "the settings take {MakerApple}");
            CharonPhotoCatcher *m = capture_with(output, marked, nil);
            CHECK(plain.finished && m.finished && m.error == nil && m.photoIsJPEG, "a photo with {MakerApple} in its metadata comes");
            CHECK(plain.attachedMaker == nil && [m.attachedMaker[@"1"] isEqual:@77], "the capture merges it into the still's attachments, and only when asked");
            printf("MakerApple: without: release's JPEG %s, MakerNote %d; with 1=77: release's JPEG %s, MakerNote %d; port's JPEG %s, MakerNote %d\n",
                   maker_apple(plain.releaseJPEG).description.UTF8String, has_maker_note(plain.releaseJPEG),
                   maker_apple(m.releaseJPEG).description.UTF8String, has_maker_note(m.releaseJPEG),
                   maker_apple(m.photoJPEG).description.UTF8String, has_maker_note(m.photoJPEG));
        }

        // Requests the header refuses on this output raise before anything is captured.
        NSDictionary *refusals = @{
            @"a RAW photo": ^{ [output capturePhotoWithSettings:[AVCapturePhotoSettings photoSettingsWithRawPixelFormatType:kCVPixelFormatType_14Bayer_RGGB]
                                                       delegate:[CharonPhotoCatcher new]]; },
            @"a Live Photo movie": ^{
                AVCapturePhotoSettings *live = [AVCapturePhotoSettings photoSettings];
                live.livePhotoMovieFileURL = [NSURL fileURLWithPath:@"/var/tmp/photooutput10-live.mov"];
                [output capturePhotoWithSettings:live delegate:[CharonPhotoCatcher new]]; },
            @"depth data": ^{
                AVCapturePhotoSettings *depth = [AVCapturePhotoSettings photoSettings];
                depth.depthDataDeliveryEnabled = YES;
                [output capturePhotoWithSettings:depth delegate:[CharonPhotoCatcher new]]; },
            @"a quality above the output's": ^{
                AVCapturePhotoSettings *quality = [AVCapturePhotoSettings photoSettings];
                quality.photoQualityPrioritization = AVCapturePhotoQualityPrioritizationQuality;
                [output capturePhotoWithSettings:quality delegate:[CharonPhotoCatcher new]]; },
            @"a settings object used twice": ^{ [output capturePhotoWithSettings:captured delegate:[CharonPhotoCatcher new]]; },
            @"a thumbnail width without a height": ^{
                AVCapturePhotoSettings *half = [AVCapturePhotoSettings photoSettings];
                half.embeddedThumbnailPhotoFormat = @{AVVideoCodecKey: AVVideoCodecJPEG, AVVideoWidthKey: @320};
                [output capturePhotoWithSettings:half delegate:[CharonPhotoCatcher new]]; },
            @"a delegate without the photo callback": ^{ [output capturePhotoWithSettings:[AVCapturePhotoSettings photoSettings] delegate:(id)[NSObject new]]; },
        };
        for (NSString *refusal in refusals) {
            NSString *answer = raised(refusals[refusal]);
            printf("refused, %s: %s\n", refusal.UTF8String, answer.UTF8String);
            CHECK([answer hasPrefix:@"NSInvalidArgumentException"], "a request the output cannot take raises");
        }

        // With the session running, settings are prepared at once, and the photo codec is the still image output's JPEG.
        __block int preparedCalls = 0;
        __block BOOL preparedAnswer = NO;
        [output setPreparedPhotoSettingsArray:@[[AVCapturePhotoSettings photoSettings]] completionHandler:^(BOOL prepared, NSError *error) {
            preparedCalls++;
            preparedAnswer = prepared;
        }];
        for (int i = 0; i < 100 && preparedCalls == 0; i++)
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        printf("prepared: %d calls, answer %d; photo codecs %s\n", preparedCalls, preparedAnswer, [[output.availablePhotoCodecTypes componentsJoinedByString:@" "] UTF8String]);
        CHECK(preparedCalls == 1 && preparedAnswer, "with the session running, prepared settings are answered YES, once");
        CHECK_EQUAL(output.availablePhotoCodecTypes, @[AVVideoCodecJPEG], "the photo codec offered is the still image output's JPEG");

        // The zoom of iOS 7 over the still image connection's own scale and crop: the photo output is zoomed as any
        // still image output is, and still captures.
        AVCaptureConnection *connection = [output connectionWithMediaType:AVMediaTypeVideo];
        printf("zoom: max %.2f, connection max %.2f\n", camera.activeFormat.videoMaxZoomFactor, connection.videoMaxScaleAndCropFactor);
        CGFloat zoom = MIN((CGFloat)2, MIN(camera.activeFormat.videoMaxZoomFactor, connection.videoMaxScaleAndCropFactor));
        if (zoom > 1 && [camera lockForConfiguration:NULL]) {
            camera.videoZoomFactor = zoom;
            [camera unlockForConfiguration];
            CharonPhotoCatcher *zoomed = capture(output, @{(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)});
            printf("zoomed %.2f: connection %.2f, photo %zux%zu, preview %zux%zu\n", zoom, connection.videoScaleAndCropFactor, zoomed.photoWidth, zoomed.photoHeight,
                   zoomed.previewWidth, zoomed.previewHeight);
            CHECK(connection.videoScaleAndCropFactor == zoom, "the zoom sets the photo output's scale and crop");
            CHECK(zoomed.finished && zoomed.error == nil && zoomed.photoIsJPEG && drawn_from_photo(zoomed), "and a zoomed photo comes with its preview");
            if ([camera lockForConfiguration:NULL]) {
                camera.videoZoomFactor = 1;
                [camera unlockForConfiguration];
            }
        } else {
            printf("zoom: this camera does not scale and crop its stills\n");
        }

        // The scene: with settings monitored for Auto, their mode is on the camera and isFlashScene is the camera's own
        // flashActive, once it has settled (0.035 s after the mode is set on the 4S, facts); with Off, NO. With none, the
        // camera has the application's own mode back (Off, above). The one capture is Off, so the flash does not fire.
        if (camera.hasFlash && flashScene) {
            AVCapturePhotoSettings *monitored = [AVCapturePhotoSettings photoSettings];
            monitored.flashMode = AVCaptureFlashModeAuto;
            output.photoSettingsForSceneMonitoring = monitored;
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
            BOOL scene = output.isFlashScene, active = camera.isFlashActive;
            AVCaptureFlashMode autoMode = camera.flashMode;
            // A capture with the flash Off (it does not fire) takes its own mode onto the camera, and the monitored
            // one comes back after it.
            AVCapturePhotoSettings *unlit = [AVCapturePhotoSettings photoSettings];
            unlit.flashMode = AVCaptureFlashModeOff;
            CharonPhotoCatcher *between = capture_with(output, unlit, nil);
            AVCaptureFlashMode afterCapture = camera.flashMode;
            output.photoSettingsForSceneMonitoring = nil;
            AVCaptureFlashMode unmonitored = camera.flashMode;
            monitored.flashMode = AVCaptureFlashModeOff;
            output.photoSettingsForSceneMonitoring = monitored;
            printf("scene: monitored Auto, camera mode %ld, flashActive %d, isFlashScene %d; none, camera mode %ld; monitored Off, camera mode %ld, isFlashScene %d\n",
                   (long)autoMode, active, scene, (long)unmonitored, (long)camera.flashMode, output.isFlashScene);
            CHECK(autoMode == AVCaptureFlashModeAuto && scene == active, "monitored for Auto, the scene is the camera's own flashActive");
            CHECK(unmonitored == AVCaptureFlashModeOff, "monitored for none, the camera has the application's own mode back");
            CHECK(camera.flashMode == AVCaptureFlashModeOff && !output.isFlashScene, "monitored for Off, the camera is Off and no flash scene");
            printf("scene: a capture Off while monitored for Auto: finished %d, camera mode at it %ld, after it %ld\n", between.finished,
                   between.cameraFlashAtCapture, (long)afterCapture);
            CHECK(between.finished && between.cameraFlashAtCapture == AVCaptureFlashModeOff && afterCapture == AVCaptureFlashModeAuto,
                  "a capture takes its own mode, and after it the camera is back on the monitored mode");
            output.photoSettingsForSceneMonitoring = nil;
        } else if (camera.hasFlash) {
            printf("scene: not run, as monitoring for Auto sets Auto on the camera; `flash-scene` runs it\n");
        }

        // The flash: the header offers the modes of the camera behind the output, Off, On and Auto for a camera with a
        // flash and Off alone for one without (the iPad 2). A capture takes its settings' mode onto the camera, where the
        // release's still image output reads it, and gives the application's own back after it; a photo still comes; the resolved settings say the flash is enabled
        // as the still's own Exif Flash tag says it fired (bit 0). On and Auto only when asked (above), Off last so the camera
        // is put back: with Off the port answers NO before the still and never reads its Exif, so only On and Auto reach
        // the Exif, and Auto in the dark is the case where `flashActive` read at once would have said NO.
        NSSet *flashModes = [NSSet setWithArray:output.supportedFlashModes];
        NSSet *cameraModes = camera.hasFlash ? [NSSet setWithObjects:@(AVCaptureFlashModeOff), @(AVCaptureFlashModeOn), @(AVCaptureFlashModeAuto), nil]
                                             : [NSSet setWithObject:@(AVCaptureFlashModeOff)];
        printf("flash: camera has one %d, modes offered %s\n", camera.hasFlash, [[output.supportedFlashModes componentsJoinedByString:@" "] UTF8String]);
        CHECK_EQUAL(flashModes, cameraModes, "the flash modes offered are the camera's");
        if (camera.hasFlash) {
            NSArray *modes = flashOn ? @[@(AVCaptureFlashModeOn), @(AVCaptureFlashModeAuto), @(AVCaptureFlashModeOff)]
                           : flashAuto ? @[@(AVCaptureFlashModeAuto)] : @[@(AVCaptureFlashModeOff)];
            for (NSNumber *mode in modes) {
                AVCapturePhotoSettings *flash = [AVCapturePhotoSettings photoSettings];
                flash.flashMode = mode.integerValue;
                CharonPhotoCatcher *lit = capture_with(output, flash, nil);
                printf("flash %ld: camera mode at the capture %ld, after it %ld, available %d, photo %zux%zu, resolved flash %d, Exif Flash %ld\n",
                       (long)mode.integerValue, lit.cameraFlashAtCapture, (long)camera.flashMode, camera.flashAvailable, lit.photoWidth,
                       lit.photoHeight, lit.resolvedFlash, lit.stillFlash);
                CHECK(lit.cameraFlashAtCapture == mode.integerValue, "a capture has its flash mode on the camera when it is taken");
                // With the flash Off on a camera that is Off nothing is saved or given back, so this holds whether or not the
                // give-back works: the give-back is not measured (facts, "The flash waits for the camera").
                CHECK(camera.flashMode == AVCaptureFlashModeOff, "and after it the camera has the application's own mode back, Off");
                CHECK(lit.finished && lit.error == nil && lit.photoIsJPEG, "and the photo comes");
                CHECK(lit.stillFlash >= 0, "the still says in its Exif whether the flash fired");
                CHECK(lit.resolvedFlash == (lit.stillFlash >= 0 && (lit.stillFlash & 1)), "and the resolved settings say the same");
            }
            if (!flashOn && !flashAuto)
                printf("flash: the On and Auto captures are not run; `flash-on` runs them\n");
        }
        [session beginConfiguration];
        [session removeOutput:output];
        [session addOutput:bare];
        [session commitConfiguration];
        CHECK(![session.outputs containsObject:output] && [session.outputs containsObject:bare], "removed, the session's outputs no longer hold it");
        [NSThread sleepForTimeInterval:2];
        CHECK(bare_capture(bare, "control after"), "the release's still image output still captures after the photo output");
        [session stopRunning];
        if (camera.hasFlash && [camera lockForConfiguration:NULL]) {
            camera.flashMode = cameraFlash;
            [camera unlockForConfiguration];
        }
        printf("%d checks, %d failed\n", charon_checks, charon_failures);
    }
    return charon_failures;
}
