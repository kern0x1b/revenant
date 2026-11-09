#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <objc/runtime.h>
#import "check.h"

static NSString *revenant_failure;

static NSURL *revenant_variable_video(void)
{
    NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"revenant-frames-%@.mov", [[NSUUID UUID] UUIDString]]]];
    AVAssetWriter *writer = [AVAssetWriter assetWriterWithURL:url fileType:AVFileTypeQuickTimeMovie error:NULL];
    NSDictionary *settings = @{AVVideoCodecKey: @"avc1", AVVideoWidthKey: @320, AVVideoHeightKey: @240};
    AVAssetWriterInput *input = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:settings];
    NSDictionary *attributes = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA), (id)kCVPixelBufferWidthKey: @320, (id)kCVPixelBufferHeightKey: @240};
    AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:input sourcePixelBufferAttributes:attributes];
    [writer addInput:input];
    [writer startWriting];
    [writer startSessionAtSourceTime:kCMTimeZero];
    const int stamps[] = {0, 20, 40, 50, 60, 80, 100, 110, 120};
    const int count = sizeof stamps / sizeof stamps[0];
    for (int index = 0; index < count; index++) {
        while (!input.isReadyForMoreMediaData)
            [NSThread sleepForTimeInterval:0.005];
        CVPixelBufferRef buffer = NULL;
        CVPixelBufferPoolCreatePixelBuffer(NULL, adaptor.pixelBufferPool, &buffer);
        if (!buffer) {
            revenant_failure = [NSString stringWithFormat:@"no pixel buffer, writer status %ld, %@", (long)writer.status, writer.error];
            return nil;
        }
        [adaptor appendPixelBuffer:buffer withPresentationTime:CMTimeMake(stamps[index], 600)];
        CVPixelBufferRelease(buffer);
    }
    [input markAsFinished];
    [writer endSessionAtSourceTime:CMTimeMake(140, 600)];
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    [writer finishWritingWithCompletionHandler:^{
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC));
    return writer.status == AVAssetWriterStatusCompleted ? url : nil;
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    @autoreleasepool {
        NSURL *url = revenant_variable_video();
        revenant_check(url != nil, "a clip of frames with unequal durations is written", revenant_failure ?: @"the writer failed");
        if (!url)
            return revenant_finish();
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
        AVAssetTrack *video = [asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
        CMTime (*backport)(id, SEL) = (CMTime (*)(id, SEL))method_getImplementation(class_getInstanceMethod([AVAssetTrack class], @selector(minFrameDuration)));
        CMTime shortest = backport(video, @selector(minFrameDuration));
        revenant_check((CMTIME_IS_NUMERIC(shortest) && fabs(CMTimeGetSeconds(shortest) - 10.0 / 600.0) < 1e-9) != revenant_negative, "the minimum frame duration of a track is its shortest frame, a sixtieth of a second here", [NSString stringWithFormat:@"%f s", CMTimeGetSeconds(shortest)]);
        CMTime again = backport(video, @selector(minFrameDuration));
        revenant_check((CMTimeCompare(shortest, again) == 0) != revenant_negative, "asking again gives the same duration", @"the second answer differs");
        double rate = 1.0 / CMTimeGetSeconds(shortest);
        revenant_check((rate > video.nominalFrameRate) != revenant_negative, "the reciprocal of the shortest frame exceeds the average rate of a track with unequal frames", [NSString stringWithFormat:@"%f against %f", rate, video.nominalFrameRate]);

        AVMutableComposition *composition = [AVMutableComposition composition];
        AVMutableCompositionTrack *placed = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
        NSError *inserted = nil;
        BOOL inserted_ok = [placed insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration) ofTrack:video atTime:kCMTimeZero error:&inserted];
        revenant_check(inserted_ok, "a composition track plays the clip", inserted.description ?: @"insertTimeRange failed");
        CMTime (*forComposition)(id, SEL) = (CMTime (*)(id, SEL))method_getImplementation(class_getInstanceMethod([AVCompositionTrack class], @selector(minFrameDuration)));
        CMTime played = forComposition(placed, @selector(minFrameDuration));
        revenant_check((CMTIME_IS_NUMERIC(played) && fabs(CMTimeGetSeconds(played) - 10.0 / 600.0) < 1e-9) != revenant_negative, "a composition track has the shortest frame of the clip it plays", [NSString stringWithFormat:@"%f s", CMTimeGetSeconds(played)]);
        [placed insertEmptyTimeRange:CMTimeRangeMake(asset.duration, CMTimeMake(1, 1))];
        CMTime withGap = forComposition(placed, @selector(minFrameDuration));
        revenant_check((CMTIME_IS_NUMERIC(withGap) && CMTimeCompare(withGap, played) == 0) != revenant_negative, "an empty segment adds no frame", [NSString stringWithFormat:@"%f s", CMTimeGetSeconds(withGap)]);
        [composition scaleTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration) toDuration:CMTimeMultiplyByFloat64(asset.duration, 2.0)];
        CMTime stretched = forComposition(placed, @selector(minFrameDuration));
        revenant_check((CMTIME_IS_NUMERIC(stretched) && fabs(CMTimeGetSeconds(stretched) - 20.0 / 600.0) < 1e-6) != revenant_negative, "stretching the clip to twice its length doubles the shortest frame of its track", [NSString stringWithFormat:@"%f s", CMTimeGetSeconds(stretched)]);
        AVMutableCompositionTrack *audio = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
        CMTime silent = forComposition(audio, @selector(minFrameDuration));
        revenant_check((CMTIME_IS_INVALID(silent)) != revenant_negative, "a composition track that is not video has no frame duration", [NSString stringWithFormat:@"%f s", CMTimeGetSeconds(silent)]);
    }
    return revenant_finish();
}
