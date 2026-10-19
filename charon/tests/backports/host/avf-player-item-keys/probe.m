#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <objc/message.h>
#import <objc/runtime.h>
#include <dlfcn.h>
#include <stdio.h>

#if CHARON_PORT_BUILD
#import "CharonStandInPlayerItem.h"
#define ITEM_CLASS CharonStandInPlayerItem
static AVPlayerItem *nativeItem(id item) { return [(CharonStandInPlayerItem *)item item]; }
static id plainItem(AVAsset *asset) { return [[CharonStandInPlayerItem alloc] initWithAsset:asset]; }
#else
#define ITEM_CLASS AVPlayerItem
static AVPlayerItem *nativeItem(id item) { return (AVPlayerItem *)item; }
static id plainItem(AVAsset *asset) { return [AVPlayerItem playerItemWithAsset:asset]; }
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

static NSURL *writeMovie(NSString *dir)
{
    NSURL *url = [NSURL fileURLWithPath:[dir stringByAppendingPathComponent:@"keys.mov"]];
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

static long keyStatus(AVAsset *asset, NSString *key)
{
    NSError *error = nil;
    return (long)[asset statusOfValueForKey:key error:&error];
}

static NSString *keysOf(id item)
{
    NSArray *keys = ((NSArray *(*)(id, SEL))objc_msgSend)(item, sel_registerName("automaticallyLoadedAssetKeys"));
    return keys ? [keys componentsJoinedByString:@","] : nil;
}

static void printOwner(Class cls, const char *selectorName, BOOL classMethod)
{
    Method method = classMethod ? class_getClassMethod(cls, sel_registerName(selectorName))
                                : class_getInstanceMethod(cls, sel_registerName(selectorName));
    Dl_info info;
    if (!method || !dladdr((const void *)method_getImplementation(method), &info) || !info.dli_fname) {
        printf("owner: %s unknown\n", selectorName);
        return;
    }
    NSString *path = [NSString stringWithUTF8String:info.dli_fname];
    printf("owner: %s %s\n", selectorName, [path hasPrefix:@"/System/Library/"] ? "system" : "executable");
}

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        if (argc != 2) { fprintf(stderr, "usage: probe <output directory>\n"); return 2; }
        NSURL *movie = writeMovie([NSString stringWithUTF8String:argv[1]]);
        NSArray *keys = @[@"duration", @"tracks"];
        printOwner([ITEM_CLASS class], "playerItemWithAsset:automaticallyLoadedAssetKeys:", YES);
        printOwner([ITEM_CLASS class], "initWithAsset:automaticallyLoadedAssetKeys:", NO);
        printOwner([ITEM_CLASS class], "automaticallyLoadedAssetKeys", NO);

        AVURLAsset *assetA = [AVURLAsset URLAssetWithURL:movie options:nil];
        id itemA = ((id (*)(id, SEL, id, id))objc_msgSend)([ITEM_CLASS class],
            sel_registerName("playerItemWithAsset:automaticallyLoadedAssetKeys:"), assetA, keys);
        emitInt("A.made", itemA != nil);
        emit("A.keys.start", keysOf(itemA));
        spin(1.0);
        emitInt("A.duration.status", keyStatus(assetA, @"duration"));
        emitInt("A.tracks.status", keyStatus(assetA, @"tracks"));
        emitInt("A.playable.status", keyStatus(assetA, @"playable"));
        emitInt("A.item.status", nativeItem(itemA).status);
        emit("A.keys.end", keysOf(itemA));

        AVURLAsset *assetB = [AVURLAsset URLAssetWithURL:movie options:nil];
        id itemB = plainItem(assetB);
        emit("B.keys", keysOf(itemB));
        spin(1.0);
        emitInt("B.duration.status", keyStatus(assetB, @"duration"));
        emit("B.keys.end", keysOf(itemB));

        AVURLAsset *assetC = [AVURLAsset URLAssetWithURL:movie options:nil];
        id itemC = ((id (*)(id, SEL, id, id))objc_msgSend)([ITEM_CLASS alloc],
            sel_registerName("initWithAsset:automaticallyLoadedAssetKeys:"), assetC, @[@"charon-no-such-key"]);
        emitInt("C.made", itemC != nil);
        emit("C.keys.start", keysOf(itemC));
        spin(1.0);
        emitInt("C.item.status", nativeItem(itemC).status);
        emit("C.keys.end", keysOf(itemC));

        AVURLAsset *assetD = [AVURLAsset URLAssetWithURL:movie options:nil];
        id itemD = ((id (*)(id, SEL, id, id))objc_msgSend)([ITEM_CLASS class],
            sel_registerName("playerItemWithAsset:automaticallyLoadedAssetKeys:"), assetD, keys);
        AVPlayer *playerD = [AVPlayer playerWithPlayerItem:nativeItem(itemD)];
        emitInt("D.player", playerD != nil);
        spin(1.5);
        emitInt("D.duration.status", keyStatus(assetD, @"duration"));
        emitInt("D.tracks.status", keyStatus(assetD, @"tracks"));
        emitInt("D.item.status", nativeItem(itemD).status);
        emit("D.keys.end", keysOf(itemD));

        AVURLAsset *assetE = [AVURLAsset URLAssetWithURL:movie options:nil];
        id itemE = plainItem(assetE);
        AVPlayer *playerE = [AVPlayer playerWithPlayerItem:nativeItem(itemE)];
        emitInt("E.player", playerE != nil);
        spin(1.5);
        emitInt("E.duration.status", keyStatus(assetE, @"duration"));
        emitInt("E.item.status", nativeItem(itemE).status);
        printf("rows: %d\n", rows);
    }
    return 0;
}
