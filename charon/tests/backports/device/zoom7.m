#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// The zoom of iOS 7 over 6.1.3 (facts/AVFoundation/CaptureZoomAudioSession.md). First what the release does
// with its own scale and crop, then the port: the maximum by the release's rule, 7.0's checks and texts, the
// still connection's factor, the preview layer and its point conversions, the crop of a video data output's
// buffers held to a known picture, and the ramp. A process of its own: the camera needs no permission on 6.1.3.

@interface AVCaptureDevice (CharonReleaseLock)
- (BOOL)isLockedForConfiguration;
@end

// A frame reduced to a grid of mean luma, whole or its centre half.
#define GRID_W 32
#define GRID_H 24

@interface CharonGrid : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>
@property (atomic) int frames;
@property (atomic) size_t width, height;
@property (atomic) OSType format;
@property (atomic) BOOL wanted;
@property (atomic, strong) NSData *whole, *centre;
@end

static float luma_at(CVPixelBufferRef pixels, OSType format, size_t x, size_t y)
{
    if (format == kCVPixelFormatType_32BGRA) {
        const uint8_t *p = (const uint8_t *)CVPixelBufferGetBaseAddress(pixels) + y * CVPixelBufferGetBytesPerRow(pixels) + x * 4;
        return 0.114f * p[0] + 0.587f * p[1] + 0.299f * p[2];
    }
    return ((const uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixels, 0))[y * CVPixelBufferGetBytesPerRowOfPlane(pixels, 0) + x];
}

static NSData *grid(CVPixelBufferRef pixels, OSType format, size_t left, size_t top, size_t width, size_t height)
{
    NSMutableData *out = [NSMutableData dataWithLength:GRID_W * GRID_H * sizeof(float)];
    float *cells = out.mutableBytes;
    for (size_t gy = 0; gy < GRID_H; gy++)
        for (size_t gx = 0; gx < GRID_W; gx++) {
            float sum = 0;
            int count = 0;
            for (size_t y = top + gy * height / GRID_H; y < top + (gy + 1) * height / GRID_H; y += 2)
                for (size_t x = left + gx * width / GRID_W; x < left + (gx + 1) * width / GRID_W; x += 2) {
                    sum += luma_at(pixels, format, x, y);
                    count++;
                }
            cells[gy * GRID_W + gx] = count ? sum / count : 0;
        }
    return out;
}

static float difference(NSData *a, NSData *b)
{
    const float *x = a.bytes, *y = b.bytes;
    float sum = 0;
    for (int i = 0; i < GRID_W * GRID_H; i++)
        sum += fabsf(x[i] - y[i]);
    return sum / (GRID_W * GRID_H);
}

@implementation CharonGrid

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sample fromConnection:(AVCaptureConnection *)connection
{
    CVPixelBufferRef pixels = CMSampleBufferGetImageBuffer(sample);
    self.frames++;
    if (!self.wanted || !pixels)
        return;
    CVPixelBufferLockBaseAddress(pixels, kCVPixelBufferLock_ReadOnly);
    size_t width = CVPixelBufferGetWidth(pixels), height = CVPixelBufferGetHeight(pixels);
    OSType format = CVPixelBufferGetPixelFormatType(pixels);
    self.width = width;
    self.height = height;
    self.format = format;
    self.whole = grid(pixels, format, 0, 0, width, height);
    self.centre = grid(pixels, format, width / 4, height / 4, width / 2, height / 2);
    CVPixelBufferUnlockBaseAddress(pixels, kCVPixelBufferLock_ReadOnly);
    self.wanted = NO;
}

@end

static BOOL wait_until(BOOL (^done)(void), NSTimeInterval seconds)
{
    NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while (!done() && [limit timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
    return done();
}

static NSString *raised(void (^block)(void))
{
    @try {
        block();
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
    }
    return @"nothing";
}

static BOOL take(CharonGrid *frames)
{
    frames.wanted = YES;
    return wait_until(^BOOL { return !frames.wanted; }, 5);
}

CMSampleBufferRef charon_create_zoomed_sample(CMSampleBufferRef sample, CGFloat factor);

// A 64x48 buffer of a known picture: in 32BGRA blue is 4x, green 5y and red x+y; in 420v luma is 2x+2y,
// Cb 8 times the chroma column and Cr 10 times the chroma row. Zoomed by 2, the pixel at (X, Y) must be the
// source's at (16 + X/2, 12 + Y/2), the centre half scaled up, away from the edges the resampling filter reaches.
static void check_crop(OSType format, const char *name)
{
    CVPixelBufferRef pixels = NULL;
    NSDictionary *attributes = @{(__bridge NSString *)kCVPixelBufferIOSurfacePropertiesKey: @{}};
    CVPixelBufferCreate(kCFAllocatorDefault, 64, 48, format, (__bridge CFDictionaryRef)attributes, &pixels);
    CVPixelBufferLockBaseAddress(pixels, 0);
    BOOL bgra = format == kCVPixelFormatType_32BGRA;
    for (size_t y = 0; y < 48; y++)
        for (size_t x = 0; x < 64; x++) {
            if (bgra) {
                uint8_t *p = (uint8_t *)CVPixelBufferGetBaseAddress(pixels) + y * CVPixelBufferGetBytesPerRow(pixels) + x * 4;
                p[0] = (uint8_t)(4 * x), p[1] = (uint8_t)(5 * y), p[2] = (uint8_t)(x + y), p[3] = 255;
            } else {
                ((uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixels, 0))[y * CVPixelBufferGetBytesPerRowOfPlane(pixels, 0) + x] = (uint8_t)(2 * x + 2 * y);
                if (x < 32 && y < 24) {
                    uint8_t *c = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixels, 1) + y * CVPixelBufferGetBytesPerRowOfPlane(pixels, 1) + x * 2;
                    c[0] = (uint8_t)(8 * x), c[1] = (uint8_t)(10 * y);
                }
            }
        }
    CVPixelBufferUnlockBaseAddress(pixels, 0);
    CMVideoFormatDescriptionRef description = NULL;
    CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixels, &description);
    CMSampleTimingInfo timing = {CMTimeMake(1, 30), CMTimeMake(7, 30), kCMTimeInvalid};
    CMSampleBufferRef sample = NULL;
    CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixels, true, NULL, NULL, description, &timing, &sample);
    CMSampleBufferRef zoomed = charon_create_zoomed_sample(sample, 2);
    CVPixelBufferRef out = zoomed ? CMSampleBufferGetImageBuffer(zoomed) : NULL;
    char label[160];
    snprintf(label, sizeof label, "%s: a buffer is zoomed into one of its own size and format, at its time", name);
    CHECK(out && CVPixelBufferGetWidth(out) == 64 && CVPixelBufferGetHeight(out) == 48 && CVPixelBufferGetPixelFormatType(out) == format
          && CMTimeCompare(CMSampleBufferGetPresentationTimeStamp(zoomed), CMTimeMake(7, 30)) == 0, label);
    int worst = 0;
    if (out) {
        CVPixelBufferLockBaseAddress(out, kCVPixelBufferLock_ReadOnly);
        for (size_t y = 8; y < 40; y++)
            for (size_t x = 8; x < 56; x++) {
                double sx = 16 + (x + 0.5) / 2 - 0.5, sy = 12 + (y + 0.5) / 2 - 0.5;
                if (bgra) {
                    const uint8_t *p = (const uint8_t *)CVPixelBufferGetBaseAddress(out) + y * CVPixelBufferGetBytesPerRow(out) + x * 4;
                    int expected[3] = {(int)lround(4 * sx), (int)lround(5 * sy), (int)lround(sx + sy)};
                    for (int k = 0; k < 3; k++)
                        worst = MAX(worst, abs(p[k] - expected[k]));
                } else {
                    int luma = ((const uint8_t *)CVPixelBufferGetBaseAddressOfPlane(out, 0))[y * CVPixelBufferGetBytesPerRowOfPlane(out, 0) + x];
                    worst = MAX(worst, abs(luma - (int)lround(2 * sx + 2 * sy)));
                    if (x % 2 == 0 && y % 2 == 0 && x < 48 && y < 36 && x >= 16 && y >= 12) {
                        size_t cx = x / 2, cy = y / 2;
                        const uint8_t *c = (const uint8_t *)CVPixelBufferGetBaseAddressOfPlane(out, 1) + cy * CVPixelBufferGetBytesPerRowOfPlane(out, 1) + cx * 2;
                        double scx = 8 + (cx + 0.5) / 2 - 0.5, scy = 6 + (cy + 0.5) / 2 - 0.5;
                        worst = MAX(worst, abs(c[0] - (int)lround(8 * scx)));
                        worst = MAX(worst, abs(c[1] - (int)lround(10 * scy)));
                    }
                }
            }
        CVPixelBufferUnlockBaseAddress(out, kCVPixelBufferLock_ReadOnly);
    }
    printf("%s crop: largest difference from the centre half %d\n", name, worst);
    snprintf(label, sizeof label, "%s: each pixel is the centre half's, scaled by 2, within 2 levels", name);
    CHECK(out && worst <= 2, label);
    if (zoomed)
        CFRelease(zoomed);
    CFRelease(sample);
    CFRelease(description);
    CVPixelBufferRelease(pixels);
}

// The camera's own frames, at 1 and at 2: measured and printed, not held, since how much the centre half of a
// frame differs from the whole depends on what the camera looks at.
static void measure_frames(AVCaptureDevice *camera, CharonGrid *frames, const char *name)
{
    [camera lockForConfiguration:NULL];
    camera.videoZoomFactor = 1;
    wait_until(^BOOL { return NO; }, 0.5);
    CHECK(take(frames), "a frame at 1");
    NSData *whole = frames.whole, *centre = frames.centre;
    size_t width = frames.width, height = frames.height;
    camera.videoZoomFactor = 2;
    wait_until(^BOOL { return NO; }, 0.5);
    CHECK(take(frames), "a frame at 2");
    [camera unlockForConfiguration];
    float cropped = difference(frames.whole, centre), uncropped = difference(frames.whole, whole);
    printf("measure %s frames %zux%zu: at 2 against the centre at 1 %.2f, against the whole at 1 %.2f\n", name, frames.width, frames.height, cropped, uncropped);
    CHECK(frames.width == width && frames.height == height, "a zoomed frame of the camera keeps its dimensions");
    CHECK(cropped < uncropped, "and it is nearer the centre of the frame at 1 than the whole of it");
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        check_crop(kCVPixelFormatType_32BGRA, "32BGRA");
        check_crop(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, "420v");
        AVCaptureDevice *camera = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        for (AVCaptureDeviceFormat *format in camera.formats) {
            CMVideoDimensions size = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
            CHECK(format.videoMaxZoomFactor == MAX(1, MIN(size.width, size.height) / 16.0f) && format.videoZoomFactorUpscaleThreshold == 1,
                  "a format's maximum zoom is its short side over 16, as the release's own scale and crop; any zoom scales up");
        }
        CHECK_EQUAL(raised(^{ camera.videoZoomFactor = 2; }), @"NSRangeException: videoZoomFactor out of range", "without an active format the range is 1 to 1");
        CHECK_EQUAL(raised(^{ camera.videoZoomFactor = 1; }),
                    @"NSGenericException: You must call lockForConfiguration and successfully obtain the configuration lock before modifying zoom factor",
                    "1 is in range, and the lock is asked for as 7.0 asks");

        AVCaptureSession *session = [[AVCaptureSession alloc] init];
        session.sessionPreset = AVCaptureSessionPreset640x480;
        [session addInput:[AVCaptureDeviceInput deviceInputWithDevice:camera error:NULL]];
        AVCaptureVideoDataOutput *data = [[AVCaptureVideoDataOutput alloc] init];
        data.videoSettings = @{(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)};
        CharonGrid *frames = [[CharonGrid alloc] init];
        [data setSampleBufferDelegate:frames queue:dispatch_queue_create("frames", NULL)];
        CHECK([data.sampleBufferDelegate isEqual:frames] && [data.sampleBufferDelegate class] == [CharonGrid class],
              "the output's delegate answers as the application's: equal, of its class");
        [session addOutput:data];
        AVCaptureStillImageOutput *still = [[AVCaptureStillImageOutput alloc] init];
        [session addOutput:still];
        AVCaptureVideoPreviewLayer *preview = [AVCaptureVideoPreviewLayer layerWithSession:session];
        preview.frame = CGRectMake(0, 0, 320, 240);
        [session startRunning];
        CHECK(wait_until(^BOOL { return frames.frames > 10; }, 10), "frames arrive");
        AVCaptureConnection *stillConnection = [still connectionWithMediaType:AVMediaTypeVideo];
        CMVideoDimensions active = CMVideoFormatDescriptionGetDimensions(camera.activeFormat.formatDescription);
        printf("release: still max scale and crop %g, active format %dx%d, preview masks %d sublayers %lu\n", stillConnection.videoMaxScaleAndCropFactor,
               active.width, active.height, preview.masksToBounds, (unsigned long)preview.sublayers.count);
        CHECK(stillConnection.videoMaxScaleAndCropFactor == camera.activeFormat.videoMaxZoomFactor, "the still connection's maximum is the active format's maximum zoom");
        CHECK(preview.masksToBounds && preview.sublayers.count > 0, "the release's preview layer masks its bounds and draws in a sublayer");

        CGPoint corner = CGPointMake(240, 180);
        CGPoint deviceAtOne = [preview captureDevicePointOfInterestForPoint:corner];
        CGPoint halfway = [preview captureDevicePointOfInterestForPoint:CGPointMake(200, 150)];
        CHECK([camera lockForConfiguration:NULL] && [camera isLockedForConfiguration], "the lock is held and the release says so");
        CHECK_EQUAL(raised(^{ camera.videoZoomFactor = camera.activeFormat.videoMaxZoomFactor + 1; }), @"NSRangeException: videoZoomFactor out of range", "past the maximum raises");
        camera.videoZoomFactor = 2;
        [camera unlockForConfiguration];
        CHECK(camera.videoZoomFactor == 2 && stillConnection.videoScaleAndCropFactor == 2, "the still connection scales and crops by the zoom");
        CHECK(preview.sublayerTransform.m11 == 2 && preview.sublayerTransform.m22 == 2, "the preview layer's video is scaled by the zoom");
        CGPoint deviceAtTwo = [preview captureDevicePointOfInterestForPoint:corner];
        CGPoint back = [preview pointForCaptureDevicePointOfInterest:deviceAtTwo];
        CHECK(fabs(deviceAtTwo.x - halfway.x) < 0.001 && fabs(deviceAtTwo.y - halfway.y) < 0.001, "a point of the zoomed preview is the device point halfway to the centre");
        CHECK(fabs(back.x - corner.x) < 0.5 && fabs(back.y - corner.y) < 0.5, "and converts back");
        printf("corner at 1 (%.3f, %.3f), at 2 (%.3f, %.3f)\n", deviceAtOne.x, deviceAtOne.y, deviceAtTwo.x, deviceAtTwo.y);

        measure_frames(camera, frames, "32BGRA");
        data.videoSettings = @{(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)};
        wait_until(^BOOL { return NO; }, 0.5);
        measure_frames(camera, frames, "420v");

        [camera lockForConfiguration:NULL];
        camera.videoZoomFactor = 1;
        [camera rampToVideoZoomFactor:4 withRate:4];
        CHECK(camera.rampingVideoZoom, "a ramp is in progress");
        CHECK(wait_until(^BOOL { return !camera.rampingVideoZoom; }, 2) && camera.videoZoomFactor == 4, "a ramp at rate 4 reaches 4 within half a second or so, and ends");
        [camera rampToVideoZoomFactor:1 withRate:1];
        wait_until(^BOOL { return NO; }, 0.3);
        [camera cancelVideoZoomRamp];
        CGFloat stopped = camera.videoZoomFactor;
        CHECK(!camera.rampingVideoZoom && stopped < 4 && stopped > 1, "a cancelled ramp stops where it is");
        camera.videoZoomFactor = 1;
        [camera unlockForConfiguration];
        CHECK_EQUAL(raised(^{ camera.activeVideoMinFrameDuration = CMTimeMake(1, 15); }),
                    @"NSGenericException: activeVideoMinFrameDuration cannot be set without first successfully gaining exclusive ownership of the device using -lockForConfiguration:",
                    "the frame duration asks for the lock as 7.0 does");
        CHECK_EQUAL(raised(^{ [camera cancelVideoZoomRamp]; }),
                    @"NSGenericException: You must call lockForConfiguration and successfully obtain the configuration lock before modifying zoom factor",
                    "a cancel without the lock raises");
        [session stopRunning];

        // What a movie file output's connection can do on this release.
        AVCaptureSession *recording = [[AVCaptureSession alloc] init];
        [recording addInput:[AVCaptureDeviceInput deviceInputWithDevice:camera error:NULL]];
        AVCaptureMovieFileOutput *movie = [[AVCaptureMovieFileOutput alloc] init];
        [recording addOutput:movie];
        [recording startRunning];
        wait_until(^BOOL { return NO; }, 1);
        printf("release: movie file connection max scale and crop %g\n", [movie connectionWithMediaType:AVMediaTypeVideo].videoMaxScaleAndCropFactor);
        [recording stopRunning];
        printf("%d checks, %d failed\n", charon_checks, charon_failures);
    }
    return charon_failures;
}
