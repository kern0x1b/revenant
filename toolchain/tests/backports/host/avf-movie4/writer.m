#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

static const double kAudioRate = 44100.0;
static const int kAudioChunk = 1024;

static int writeMovie(NSString *path, double seconds, int fps, int width, int height)
{
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    NSError *error = nil;
    AVAssetWriter *writer = [[AVAssetWriter alloc] initWithURL:[NSURL fileURLWithPath:path]
                                                      fileType:AVFileTypeQuickTimeMovie
                                                         error:&error];
    if (!writer) {
        fprintf(stderr, "writer: %s: %s\n", path.UTF8String, error.description.UTF8String);
        return 1;
    }

    AVAssetWriterInput *video = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                                   outputSettings:@{AVVideoCodecKey: AVVideoCodecTypeH264,
                                                                                    AVVideoWidthKey: @(width),
                                                                                    AVVideoHeightKey: @(height)}];
    video.expectsMediaDataInRealTime = NO;
    AVAssetWriterInputPixelBufferAdaptor *adaptor =
        [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:video
                                                                         sourcePixelBufferAttributes:@{
            (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
            (id)kCVPixelBufferWidthKey: @(width),
            (id)kCVPixelBufferHeightKey: @(height)}];

    AVAssetWriterInput *audio = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio
                                                                   outputSettings:@{AVFormatIDKey: @(kAudioFormatMPEG4AAC),
                                                                                    AVNumberOfChannelsKey: @2,
                                                                                    AVSampleRateKey: @(kAudioRate),
                                                                                    AVEncoderBitRateKey: @64000}];
    audio.expectsMediaDataInRealTime = NO;

    if (![writer canAddInput:video] || ![writer canAddInput:audio]) {
        fprintf(stderr, "writer: %s: an input cannot be added\n", path.UTF8String);
        return 1;
    }
    [writer addInput:video];
    [writer addInput:audio];
    if (![writer startWriting]) {
        fprintf(stderr, "writer: %s: startWriting: %s\n", path.UTF8String, writer.error.description.UTF8String);
        return 1;
    }
    [writer startSessionAtSourceTime:kCMTimeZero];

    AudioStreamBasicDescription asbd = {0};
    asbd.mSampleRate = kAudioRate;
    asbd.mFormatID = kAudioFormatLinearPCM;
    asbd.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    asbd.mBytesPerPacket = 4;
    asbd.mFramesPerPacket = 1;
    asbd.mBytesPerFrame = 4;
    asbd.mChannelsPerFrame = 2;
    asbd.mBitsPerChannel = 16;
    CMAudioFormatDescriptionRef pcm = NULL;
    CMAudioFormatDescriptionCreate(kCFAllocatorDefault, &asbd, 0, NULL, 0, NULL, NULL, &pcm);

    const int frames = (int)lround(seconds * fps);
    const long long audioFrames = llround(seconds * kAudioRate);
    __block int frame = 0;
    __block long long audioDone = 0;
    dispatch_queue_t queue = dispatch_queue_create("charon.avmovie4.writer", DISPATCH_QUEUE_SERIAL);
    dispatch_group_t inputs = dispatch_group_create();

    dispatch_group_enter(inputs);
    [video requestMediaDataWhenReadyOnQueue:queue usingBlock:^{
        while (video.readyForMoreMediaData) {
            if (frame >= frames) {
                [video markAsFinished];
                dispatch_group_leave(inputs);
                return;
            }
            CVPixelBufferRef pixels = NULL;
            CVPixelBufferPoolRef pool = adaptor.pixelBufferPool;
            if (pool)
                CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixels);
            if (!pixels)
                CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, NULL, &pixels);
            CVPixelBufferLockBaseAddress(pixels, 0);
            uint8_t *base = CVPixelBufferGetBaseAddress(pixels);
            size_t stride = CVPixelBufferGetBytesPerRow(pixels);
            for (int y = 0; y < height; y++)
                for (int x = 0; x < width; x++) {
                    uint8_t *px = base + y * stride + x * 4;
                    px[0] = (uint8_t)(x + frame * 3);
                    px[1] = (uint8_t)(y + frame);
                    px[2] = 0x80;
                    px[3] = 0xff;
                }
            CVPixelBufferUnlockBaseAddress(pixels, 0);
            BOOL appended = [adaptor appendPixelBuffer:pixels withPresentationTime:CMTimeMake(frame, fps)];
            CVPixelBufferRelease(pixels);
            if (!appended) {
                fprintf(stderr, "writer: %s: the video frame %d was not appended: %s\n", path.UTF8String, frame,
                        writer.error.description.UTF8String);
                exit(1);
            }
            frame++;
        }
    }];

    dispatch_group_enter(inputs);
    [audio requestMediaDataWhenReadyOnQueue:queue usingBlock:^{
        while (audio.readyForMoreMediaData) {
            if (audioDone >= audioFrames) {
                [audio markAsFinished];
                dispatch_group_leave(inputs);
                return;
            }
            long long left = audioFrames - audioDone;
            int n = (int)(left < kAudioChunk ? left : kAudioChunk);
            int16_t *samples = calloc((size_t)n * 2, sizeof(int16_t));
            for (int i = 0; i < n; i++) {
                double phase = (audioDone + i) / kAudioRate;
                samples[2 * i] = (int16_t)(8000.0 * sin(2.0 * M_PI * 440.0 * phase));
                samples[2 * i + 1] = samples[2 * i];
            }
            CMBlockBufferRef block = NULL;
            CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, samples, (size_t)n * 4, kCFAllocatorMalloc,
                                               NULL, 0, (size_t)n * 4, 0, &block);
            CMSampleTimingInfo timing = {CMTimeMake(1, (int32_t)kAudioRate),
                                         CMTimeMake(audioDone, (int32_t)kAudioRate), kCMTimeInvalid};
            CMSampleBufferRef buffer = NULL;
            CMSampleBufferCreate(kCFAllocatorDefault, block, true, NULL, NULL, pcm, n, 1, &timing, 0, NULL, &buffer);
            BOOL appended = buffer && [audio appendSampleBuffer:buffer];
            if (buffer)
                CFRelease(buffer);
            CFRelease(block);
            if (!appended) {
                fprintf(stderr, "writer: %s: the audio chunk at frame %lld was not appended: %s\n", path.UTF8String,
                        audioDone, writer.error.description.UTF8String);
                exit(1);
            }
            audioDone += n;
        }
    }];

    dispatch_group_wait(inputs, DISPATCH_TIME_FOREVER);
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    [writer finishWritingWithCompletionHandler:^{ dispatch_semaphore_signal(done); }];
    dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
    if (writer.status != AVAssetWriterStatusCompleted) {
        fprintf(stderr, "writer: %s: finished with status %ld: %s\n", path.UTF8String, (long)writer.status,
                writer.error.description.UTF8String);
        return 1;
    }
    return 0;
}

int main(int argc, const char **argv)
{
    @autoreleasepool {
        if (argc != 2) {
            fprintf(stderr, "usage: writer <output directory>\n");
            return 2;
        }
        NSString *dir = [NSString stringWithUTF8String:argv[1]];
        if (writeMovie([dir stringByAppendingPathComponent:@"movie-a.mov"], 1.0, 24, 64, 48) != 0)
            return 1;
        if (writeMovie([dir stringByAppendingPathComponent:@"movie-b.mov"], 2.0, 30, 96, 72) != 0)
            return 1;
        printf("writer: movie-a.mov (1.0 s, 24 fps) and movie-b.mov (2.0 s, 30 fps) written\n");
        return 0;
    }
}
