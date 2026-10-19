#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <objc/message.h>
#include <stdio.h>

#if REVENANT_PORT_BUILD
#define LOOPER_CLASS_NAME @"revenant_host_AVPlayerLooper"
#else
#define LOOPER_CLASS_NAME @"AVPlayerLooper"
#endif

static int rows = 0;

static void emit(const char *key, NSString *value)
{
    printf("%s = %s\n", key, value ? [value UTF8String] : "nil");
    rows++;
}

static void emitInt(const char *key, long long value)
{
    printf("%s = %lld\n", key, value);
    rows++;
}

static void spin(double seconds)
{
    NSDate *until = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while ([until timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
}

static NSInteger intOf(id target, const char *selector)
{
    return ((NSInteger (*)(id, SEL))objc_msgSend)(target, sel_registerName(selector));
}

static id objOf(id target, const char *selector)
{
    return ((id (*)(id, SEL))objc_msgSend)(target, sel_registerName(selector));
}

static NSURL *writeMovie(NSString *dir)
{
    NSURL *url = [NSURL fileURLWithPath:[dir stringByAppendingPathComponent:@"loop.mov"]];
    [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
    NSError *error = nil;
    AVAssetWriter *writer = [[AVAssetWriter alloc] initWithURL:url fileType:AVFileTypeQuickTimeMovie error:&error];
    if (!writer) { fprintf(stderr, "writer: %s\n", [[error description] UTF8String]); exit(1); }
    AVAssetWriterInput *input = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                 outputSettings:@{AVVideoCodecKey: AVVideoCodecTypeH264, AVVideoWidthKey: @16, AVVideoHeightKey: @16}];
    AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor
        assetWriterInputPixelBufferAdaptorWithAssetWriterInput:input sourcePixelBufferAttributes:nil];
    [writer addInput:input];
    [writer startWriting];
    [writer startSessionAtSourceTime:kCMTimeZero];
    for (int frame = 0; frame < 10; frame++) {
        while (!input.readyForMoreMediaData)
            [NSThread sleepForTimeInterval:0.005];
        CVPixelBufferRef buffer = NULL;
        CVPixelBufferCreate(kCFAllocatorDefault, 16, 16, kCVPixelFormatType_32BGRA, NULL, &buffer);
        [adaptor appendPixelBuffer:buffer withPresentationTime:CMTimeMake(frame, 10)];
        CVPixelBufferRelease(buffer);
    }
    [input markAsFinished];
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    [writer finishWritingWithCompletionHandler:^{ dispatch_semaphore_signal(done); }];
    dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
    if (writer.status != AVAssetWriterStatusCompleted) { fprintf(stderr, "writer: status %ld\n", (long)writer.status); exit(1); }
    return url;
}

static void waitForStatus(id looper, double limit)
{
    NSDate *until = [NSDate dateWithTimeIntervalSinceNow:limit];
    while (intOf(looper, "status") == 0 && [until timeIntervalSinceNow] > 0)
        spin(0.02);
}

static void sectionDefault(Class looperClass, NSURL *movie)
{
    AVQueuePlayer *queue = [AVQueuePlayer queuePlayerWithItems:@[]];
    AVPlayerItem *template = [AVPlayerItem playerItemWithAsset:[AVURLAsset URLAssetWithURL:movie options:nil]];
    id looper = ((id (*)(id, SEL, id, id))objc_msgSend)(looperClass, sel_registerName("playerLooperWithPlayer:templateItem:"), queue, template);
    emitInt("A.created", looper != nil);
    emitInt("A.status.start", intOf(looper, "status"));
    emitInt("A.loopingItems.start", [(NSArray *)objOf(looper, "loopingPlayerItems") count]);
    emitInt("A.queueItems.start", queue.items.count);
    waitForStatus(looper, 5.0);
    emitInt("A.status.ready", intOf(looper, "status"));
    emitInt("A.loopingItems.ready", [(NSArray *)objOf(looper, "loopingPlayerItems") count]);
    emitInt("A.queueItems.ready", queue.items.count);
    emitInt("A.templateInQueue", [queue.items containsObject:template]);
    emitInt("A.templateInLooping", [(NSArray *)objOf(looper, "loopingPlayerItems") containsObject:template]);
    NSArray *looping = objOf(looper, "loopingPlayerItems");
    emitInt("A.loopingSameAsset", looping.count > 0 && [[(AVPlayerItem *)looping[0] asset] isEqual:template.asset]);
    emitInt("A.endValid.whole", looping.count > 0 && CMTIME_IS_VALID(((AVPlayerItem *)looping[0]).forwardPlaybackEndTime));

    [queue play];
    spin(1.5);
    emitInt("A.loopCount.mid", intOf(looper, "loopCount"));
    emitInt("A.status.mid", intOf(looper, "status"));
    emitInt("A.loopingItems.mid", [(NSArray *)objOf(looper, "loopingPlayerItems") count]);
    emitInt("A.queueItems.mid", queue.items.count);

    ((void (*)(id, SEL))objc_msgSend)(looper, sel_registerName("disableLooping"));
    emitInt("A.status.disabled", intOf(looper, "status"));
    spin(2.5);
    emitInt("A.loopCount.end", intOf(looper, "loopCount"));
    emitInt("A.queueItems.end", queue.items.count);
    emitInt("A.status.end", intOf(looper, "status"));
    emit("A.error.end", objOf(looper, "error") ? @"set" : nil);
}

static void sectionRange(Class looperClass, NSURL *movie, int hundredths)
{
    char key[64];
    AVQueuePlayer *queue = [AVQueuePlayer queuePlayerWithItems:@[]];
    AVPlayerItem *template = [AVPlayerItem playerItemWithAsset:[AVURLAsset URLAssetWithURL:movie options:nil]];
    CMTimeRange range = CMTimeRangeMake(kCMTimeZero, CMTimeMake(hundredths, 100));
    SEL factory = sel_registerName("playerLooperWithPlayer:templateItem:timeRange:");
    id looper = ((id (*)(id, SEL, id, id, CMTimeRange))objc_msgSend)(looperClass, factory, queue, template, range);
    snprintf(key, sizeof key, "B%d.created", hundredths);
    emitInt(key, looper != nil);
    waitForStatus(looper, 5.0);
    snprintf(key, sizeof key, "B%d.status.ready", hundredths);
    emitInt(key, intOf(looper, "status"));
    NSArray *looping = objOf(looper, "loopingPlayerItems");
    snprintf(key, sizeof key, "B%d.loopingItems.ready", hundredths);
    emitInt(key, looping.count);
    snprintf(key, sizeof key, "B%d.queueItems.ready", hundredths);
    emitInt(key, queue.items.count);
    if (looping.count > 0) {
        CMTime end = ((AVPlayerItem *)looping[0]).forwardPlaybackEndTime;
        snprintf(key, sizeof key, "B%d.endValid", hundredths);
        emitInt(key, CMTIME_IS_VALID(end));
        snprintf(key, sizeof key, "B%d.endHundredths", hundredths);
        emitInt(key, CMTIME_IS_VALID(end) ? (long long)llround(CMTimeGetSeconds(end) * 100) : -1);
    }
    if (hundredths == 50) {
        [queue play];
        spin(1.25);
        emitInt("B50.loopCount.mid", intOf(looper, "loopCount"));
        emitInt("B50.loopingItems.mid", [(NSArray *)objOf(looper, "loopingPlayerItems") count]);
        emitInt("B50.queueItems.mid", queue.items.count);
    }
    ((void (*)(id, SEL))objc_msgSend)(looper, sel_registerName("disableLooping"));
    snprintf(key, sizeof key, "B%d.status.disabled", hundredths);
    emitInt(key, intOf(looper, "status"));
}

static void sectionDefaultLoaded(Class looperClass, NSURL *movie)
{
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:movie options:nil];
    dispatch_semaphore_t loaded = dispatch_semaphore_create(0);
    [asset loadValuesAsynchronouslyForKeys:@[@"duration"] completionHandler:^{ dispatch_semaphore_signal(loaded); }];
    dispatch_semaphore_wait(loaded, dispatch_time(DISPATCH_TIME_NOW, 5LL * NSEC_PER_SEC));
    emitInt("D.durationLoaded", CMTIME_IS_VALID(asset.duration));
    AVQueuePlayer *queue = [AVQueuePlayer queuePlayerWithItems:@[]];
    AVPlayerItem *template = [AVPlayerItem playerItemWithAsset:asset];
    id looper = ((id (*)(id, SEL, id, id))objc_msgSend)(looperClass, sel_registerName("playerLooperWithPlayer:templateItem:"), queue, template);
    waitForStatus(looper, 5.0);
    emitInt("D.status.ready", intOf(looper, "status"));
    emitInt("D.loopingItems.ready", [(NSArray *)objOf(looper, "loopingPlayerItems") count]);
    emitInt("D.queueItems.ready", queue.items.count);
    ((void (*)(id, SEL))objc_msgSend)(looper, sel_registerName("disableLooping"));
}

static void sectionOffsetRange(Class looperClass, NSURL *movie)
{
    AVQueuePlayer *queue = [AVQueuePlayer queuePlayerWithItems:@[]];
    AVPlayerItem *template = [AVPlayerItem playerItemWithAsset:[AVURLAsset URLAssetWithURL:movie options:nil]];
    CMTimeRange range = CMTimeRangeMake(CMTimeMake(50, 100), CMTimeMake(50, 100));
    SEL factory = sel_registerName("playerLooperWithPlayer:templateItem:timeRange:");
    id looper = ((id (*)(id, SEL, id, id, CMTimeRange))objc_msgSend)(looperClass, factory, queue, template, range);
    waitForStatus(looper, 5.0);
    emitInt("E.status.ready", intOf(looper, "status"));
    [queue play];
    spin(0.75);
    emitInt("E.loopCount.early", intOf(looper, "loopCount"));
    spin(0.5);
    emitInt("E.loopCount.mid", intOf(looper, "loopCount"));
    spin(0.5);
    emitInt("E.loopCount.late", intOf(looper, "loopCount"));
    ((void (*)(id, SEL))objc_msgSend)(looper, sel_registerName("disableLooping"));
}

static void sectionFailed(Class looperClass)
{
    NSURL *missing = [NSURL fileURLWithPath:@"/nonexistent-revenant-looper/missing.mov"];
    AVQueuePlayer *queue = [AVQueuePlayer queuePlayerWithItems:@[]];
    AVPlayerItem *template = [AVPlayerItem playerItemWithAsset:[AVURLAsset URLAssetWithURL:missing options:nil]];
    id looper = ((id (*)(id, SEL, id, id))objc_msgSend)(looperClass, sel_registerName("playerLooperWithPlayer:templateItem:"), queue, template);
    emitInt("C.created", looper != nil);
    spin(1.5);
    emitInt("C.status", intOf(looper, "status"));
    emit("C.error", objOf(looper, "error") ? @"set" : nil);
    emitInt("C.loopingItems", [(NSArray *)objOf(looper, "loopingPlayerItems") count]);
    emitInt("C.queueItems", queue.items.count);
}

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        if (argc != 2) { fprintf(stderr, "usage: probe <output directory>\n"); return 2; }
        NSURL *movie = writeMovie([NSString stringWithUTF8String:argv[1]]);

        Class looperClass = NSClassFromString(LOOPER_CLASS_NAME);
        emitInt("class", looperClass != Nil);
        if (!looperClass) { printf("rows: %d\n", rows); return 1; }
        emitInt("factory", [looperClass respondsToSelector:sel_registerName("playerLooperWithPlayer:templateItem:")]);

        sectionDefault(looperClass, movie);
        sectionRange(looperClass, movie, 50);
        sectionRange(looperClass, movie, 100);
        sectionRange(looperClass, movie, 25);
        sectionRange(looperClass, movie, 10);
        sectionDefaultLoaded(looperClass, movie);
        sectionOffsetRange(looperClass, movie);
        sectionFailed(looperClass);
        printf("rows: %d\n", rows);
    }
    return 0;
}
