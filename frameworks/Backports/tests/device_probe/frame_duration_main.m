#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <mach/mach_time.h>
#import <objc/message.h>

static double revenant_now(void)
{
    static mach_timebase_info_data_t base;
    if (!base.denom)
        mach_timebase_info(&base);
    return (double)mach_absolute_time() * base.numer / base.denom / 1e9;
}

static NSURL *revenant_clip(int frames, int bitrate, int width, int height)
{
    NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"revenant-long-%d-%d.mov", frames, bitrate]]];
    [[NSFileManager defaultManager] removeItemAtURL:url error:NULL];
    AVAssetWriter *writer = [AVAssetWriter assetWriterWithURL:url fileType:AVFileTypeQuickTimeMovie error:NULL];
    NSDictionary *settings = @{AVVideoCodecKey: AVVideoCodecH264, AVVideoWidthKey: @(width), AVVideoHeightKey: @(height), AVVideoCompressionPropertiesKey: @{AVVideoAverageBitRateKey: @(bitrate)}};
    AVAssetWriterInput *input = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:settings];
    NSDictionary *attributes = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA), (id)kCVPixelBufferWidthKey: @(width), (id)kCVPixelBufferHeightKey: @(height)};
    AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:input sourcePixelBufferAttributes:attributes];
    [writer addInput:input];
    [writer startWriting];
    [writer startSessionAtSourceTime:kCMTimeZero];
    uint32_t state = 12345;
    int64_t stamp = 0;
    for (int index = 0; index < frames; index++) {
        while (!input.isReadyForMoreMediaData)
            [NSThread sleepForTimeInterval:0.002];
        CVPixelBufferRef buffer = NULL;
        CVPixelBufferPoolCreatePixelBuffer(NULL, adaptor.pixelBufferPool, &buffer);
        if (!buffer) {
            printf("no pixel buffer at frame %d, status %ld %s\n", index, (long)writer.status, writer.error.description.UTF8String);
            return nil;
        }
        CVPixelBufferLockBaseAddress(buffer, 0);
        uint8_t *base = CVPixelBufferGetBaseAddress(buffer);
        size_t row = CVPixelBufferGetBytesPerRow(buffer);
        for (int y = 0; y < height; y++) {
            uint32_t *line = (uint32_t *)(base + y * row);
            for (int x = 0; x < width; x++) {
                state = state * 1664525u + 1013904223u;
                line[x] = ((state >> 24) & 0x3f) | ((uint32_t)(x + index * 3) & 0xff) << 8 | ((uint32_t)(y + index) & 0xff) << 16 | 0xff000000u;
            }
        }
        CVPixelBufferUnlockBaseAddress(buffer, 0);
        [adaptor appendPixelBuffer:buffer withPresentationTime:CMTimeMake(stamp, 600)];
        CVPixelBufferRelease(buffer);
        stamp += (index % 97 == 96) ? 10 : 20;
    }
    [input markAsFinished];
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    [writer finishWritingWithCompletionHandler:^{
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 600 * NSEC_PER_SEC));
    return writer.status == AVAssetWriterStatusCompleted ? url : nil;
}

int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        int frames = argc > 1 ? atoi(argv[1]) : 900;
        int bitrate = argc > 2 ? atoi(argv[2]) : 4000000;
        int width = argc > 3 ? atoi(argv[3]) : 480;
        int height = argc > 4 ? atoi(argv[4]) : 360;
        double started = revenant_now();
        NSURL *url = revenant_clip(frames, bitrate, width, height);
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:url.path error:NULL];
        printf("clip %d frames %dx%d at %d bit/s: %.1f s to write, %.1f MB\n", frames, width, height, bitrate, revenant_now() - started, [attributes fileSize] / 1048576.0);
        if (!url)
            return 1;
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
        AVAssetTrack *video = [asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
        printf("duration %.2f s, nominal rate %.3f\n", CMTimeGetSeconds(asset.duration), video.nominalFrameRate);
        SEL selector = NSSelectorFromString(@"minFrameDuration");
        if ([video respondsToSelector:selector]) {
            started = revenant_now();
            CMTime shortest = ((CMTime (*)(id, SEL))objc_msgSend_stret)(video, selector);
            printf("backport minFrameDuration %.6f s (%lld/%d) in %.3f s\n", CMTimeGetSeconds(shortest), shortest.value, shortest.timescale, revenant_now() - started);
            started = revenant_now();
            shortest = ((CMTime (*)(id, SEL))objc_msgSend_stret)(video, selector);
            printf("second call %.6f s in %.6f s\n", CMTimeGetSeconds(shortest), revenant_now() - started);
        }
        CMTime probes[] = {kCMTimeZero, CMTimeMake(1, 600), CMTimeMake(5, 600), CMTimeMake(19, 600), CMTimeMake(20, 600), CMTimeMake(21, 600), CMTimeMake(39, 600), CMTimeMake(40, 600), CMTimeMake(41, 600)};
        for (size_t index = 0; index < sizeof(probes) / sizeof(probes[0]); index++) {
            CMTime time = [video samplePresentationTimeForTrackTime:probes[index]];
            printf("samplePresentationTimeForTrackTime: %lld/600 gives %lld/%d\n", probes[index].value, time.value * 600 / time.timescale, 600);
        }
        started = revenant_now();
        long calls = 0;
        for (int index = 0; index < 400; index++) {
            CMTime time = [video samplePresentationTimeForTrackTime:CMTimeMake(index * 7, 600)];
            if (CMTIME_IS_VALID(time))
                calls++;
        }
        double elapsed = revenant_now() - started;
        printf("samplePresentationTimeForTrackTime: %ld calls in %.4f s, %.1f us per call\n", calls, elapsed, elapsed / calls * 1e6);
    }
    return 0;
}
