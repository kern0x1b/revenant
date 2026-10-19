#import <AssetsLibrary/AssetsLibrary.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#include <unistd.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

// The data of the resources of Photos over ALAssetsLibrary (facts/Photos/Changes.md): a resource read back in chunks
// and written to a file, and a read cancelled between two chunks. What a chunk holds is held to a direct read of the
// same asset through the release's ALAssetRepresentation, not to anything of the port.
// An application of its own (photosdata9-Info.plist): iOS 6 gives the photo library to a bundle identifier the user
// allowed, and a bare executable has none. Each run adds one video of blue noise, a few megabytes so that it spans
// more than one read, to the saved photos and to a new album CharonPhotosProbe-<time>, the fixtures the fleet keeps.

static NSString *const results_folder = @"/private/var/backports";

static void wait_until(double seconds, BOOL (^done)(void))
{
    for (int i = 0; i < seconds * 20 && !done(); i++)
        [NSThread sleepForTimeInterval:0.05];
}

// A blue video: noise in the blue channel (no red, no green) at a high bit rate, so the encoder cannot make it small,
// or a solid blue one.
static NSURL *blue_video_of_type(NSString *fileType, int frames, int width, int height, BOOL noise)
{
    NSString *extension = [fileType isEqualToString:AVFileTypeMPEG4] ? @"mp4" : @"mov";
    NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"charon-%@.%@", [NSUUID UUID].UUIDString, extension]]];
    NSError *error = nil;
    AVAssetWriter *writer = [AVAssetWriter assetWriterWithURL:url fileType:fileType error:&error];
    AVAssetWriterInput *input = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:@{
        AVVideoCodecKey: AVVideoCodecH264, AVVideoWidthKey: @(width), AVVideoHeightKey: @(height),
        AVVideoCompressionPropertiesKey: @{AVVideoAverageBitRateKey: @(40 * 1000 * 1000), AVVideoMaxKeyFrameIntervalKey: @1}}];
    AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:input
        sourcePixelBufferAttributes:@{(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
                                      (__bridge NSString *)kCVPixelBufferWidthKey: @(width), (__bridge NSString *)kCVPixelBufferHeightKey: @(height)}];
    if (!writer || ![writer canAddInput:input]) {
        printf("video writer: %s\n", error.description.UTF8String ?: "cannot add the input");
        return nil;
    }
    [writer addInput:input];
    [writer startWriting];
    [writer startSessionAtSourceTime:kCMTimeZero];
    srandom(1);
    for (int frame = 0; frame < frames; frame++) {
        while (!input.readyForMoreMediaData)
            [NSThread sleepForTimeInterval:0.01];
        CVPixelBufferRef buffer = NULL;
        if (CVPixelBufferPoolCreatePixelBuffer(NULL, adaptor.pixelBufferPool, &buffer) != kCVReturnSuccess)
            break;
        CVPixelBufferLockBaseAddress(buffer, 0);
        uint8_t *base = CVPixelBufferGetBaseAddress(buffer);
        size_t stride = CVPixelBufferGetBytesPerRow(buffer);
        for (int y = 0; y < height; y++) {
            uint8_t *row = base + y * stride;
            for (int x = 0; x < width; x++) {
                row[4 * x] = noise ? (uint8_t)random() : 255;
                row[4 * x + 1] = 0;
                row[4 * x + 2] = 0;
                row[4 * x + 3] = 255;
            }
        }
        CVPixelBufferUnlockBaseAddress(buffer, 0);
        [adaptor appendPixelBuffer:buffer withPresentationTime:CMTimeMake(frame, 30)];
        CVPixelBufferRelease(buffer);
    }
    [input markAsFinished];
    __block BOOL finished = NO;
    [writer finishWritingWithCompletionHandler:^{ finished = YES; }];
    wait_until(60, ^{ return finished; });
    if (writer.status != AVAssetWriterStatusCompleted) {
        printf("video writer: status %ld %s\n", (long)writer.status, writer.error.description.UTF8String ?: "");
        return nil;
    }
    return url;
}

static NSURL *blue_video(int frames, int width, int height, BOOL noise)
{
    return blue_video_of_type(AVFileTypeQuickTimeMovie, frames, width, height, noise);
}

static NSString *album_name(void)
{
    NSDateFormatter *stamp = [[NSDateFormatter alloc] init];
    stamp.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    stamp.dateFormat = @"yyyyMMdd-HHmmss";
    return [@"CharonPhotosProbe-" stringByAppendingString:[stamp stringFromDate:[NSDate date]]];
}

// The bytes of the asset read straight from the release, the oracle of every read of the port.
static NSData *direct_read(NSString *identifier)
{
    __block NSData *data = nil;
    __block BOOL answered = NO;
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    [library assetForURL:[NSURL URLWithString:identifier] resultBlock:^(ALAsset *asset) {
        ALAssetRepresentation *representation = asset.defaultRepresentation;
        NSMutableData *bytes = [NSMutableData dataWithLength:(NSUInteger)representation.size];
        NSUInteger got = [representation getBytes:bytes.mutableBytes fromOffset:0 length:bytes.length error:NULL];
        data = got == bytes.length ? bytes : nil;
        answered = YES;
    } failureBlock:^(NSError *error) {
        answered = YES;
    }];
    wait_until(30, ^{ return answered; });
    return data;
}

static PHAsset *asset_with_identifier(NSString *identifier)
{
    return identifier ? [PHAsset fetchAssetsWithLocalIdentifiers:@[identifier] options:nil].firstObject : nil;
}

@interface CharonReadRecord : NSObject
@property (atomic, strong) NSMutableArray<NSData *> *chunks;
@property (atomic, strong) NSMutableArray<NSNumber *> *progress;
@property (atomic, strong) NSError *error;
@property (atomic) int completions;
@end

@implementation CharonReadRecord
@end

static CharonReadRecord *read_resource(PHAssetResource *resource, BOOL cancelAtFirstChunk)
{
    CharonReadRecord *record = [[CharonReadRecord alloc] init];
    record.chunks = [NSMutableArray array];
    record.progress = [NSMutableArray array];
    PHAssetResourceRequestOptions *options = [[PHAssetResourceRequestOptions alloc] init];
    options.progressHandler = ^(double progress) {
        [record.progress addObject:@(progress)];
    };
    PHAssetResourceManager *manager = [PHAssetResourceManager defaultManager];
    __block PHAssetResourceDataRequestID requestID = PHInvalidAssetResourceDataRequestID;
    dispatch_semaphore_t issued = dispatch_semaphore_create(0);
    requestID = [manager requestDataForAssetResource:resource options:options dataReceivedHandler:^(NSData *data) {
        [record.chunks addObject:[data copy]];
        if (cancelAtFirstChunk && record.chunks.count == 1) {
            dispatch_semaphore_wait(issued, DISPATCH_TIME_FOREVER);
            [manager cancelDataRequest:requestID];
        }
    } completionHandler:^(NSError *error) {
        record.error = error;
        record.completions++;
    }];
    dispatch_semaphore_signal(issued);
    wait_until(60, ^{ return (BOOL)(record.completions > 0); });
    [NSThread sleepForTimeInterval:0.2];
    return record;
}

static void check_read(PHAssetResource *resource, NSData *direct)
{
    CharonReadRecord *record = read_resource(resource, NO);
    NSMutableData *joined = [NSMutableData data];
    NSUInteger largest = 0;
    BOOL anyEmpty = NO;
    for (NSData *chunk in record.chunks) {
        [joined appendData:chunk];
        largest = MAX(largest, chunk.length);
        anyEmpty = anyEmpty || chunk.length == 0;
    }
    printf("read: %lu bytes in %lu chunks, the largest %lu\n", (unsigned long)joined.length, (unsigned long)record.chunks.count, (unsigned long)largest);
    CHECK(record.completions == 1 && record.error == nil, "a read completes once, with no error");
    CHECK([joined isEqualToData:direct], "its chunks together are the bytes of a direct read of the asset");
    CHECK(!anyEmpty, "no chunk is empty");
    CHECK(record.chunks.count > 1 && largest < direct.length, "a video of several megabytes is not handed over in one piece");
    BOOL rising = record.progress.count == record.chunks.count;
    double last = 0;
    for (NSNumber *value in record.progress) {
        rising = rising && value.doubleValue > last;
        last = value.doubleValue;
    }
    CHECK(rising && last == 1.0, "progress rises once per chunk and ends at 1.0");

    CharonReadRecord *cancelled = read_resource(resource, YES);
    CHECK(cancelled.completions == 1 && cancelled.chunks.count == 1 && cancelled.error.code == PHPhotosErrorUserCancelled,
          "a read cancelled at its first chunk hands over no other and completes once, cancelled");
}

static NSError *write_resource(PHAssetResource *resource, NSURL *url)
{
    __block NSError *given = nil;
    __block BOOL answered = NO;
    [[PHAssetResourceManager defaultManager] writeDataForAssetResource:resource toFile:url options:nil completionHandler:^(NSError *error) {
        given = error;
        answered = YES;
    }];
    wait_until(60, ^{ return answered; });
    CHECK(answered, "a write completes");
    return given;
}

static void check_write(PHAssetResource *resource, NSData *direct)
{
    NSString *folder = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID UUID].UUIDString];
    [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL];
    NSURL *url = [NSURL fileURLWithPath:[folder stringByAppendingPathComponent:@"resource.mov"]];
    NSError *error = write_resource(resource, url);
    CHECK(error == nil && [[NSData dataWithContentsOfURL:url] isEqualToData:direct], "a write leaves the bytes of a direct read in the file");
    NSArray *left = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:folder error:NULL];
    CHECK(left.count == 1, "and nothing else beside it");

    // What a write onto a file that is already there does is not checked: the port replaces it, and what Photos itself
    // does is not measured (facts/Photos/Changes.md).
    NSData *before = [@"a file that was there" dataUsingEncoding:NSUTF8StringEncoding];
    [before writeToURL:url atomically:YES];
    // A resource with no asset behind it, as photosresources9.m makes one: the header gives the class no public initializer.
    PHAssetResource *orphan = ((id (*)(id, SEL))objc_msgSend)([PHAssetResource alloc], @selector(init));
    error = write_resource(orphan, url);
    printf("write of a resource with no asset: %s\n", error.description.UTF8String ?: "no error");
    CHECK(error != nil && [[NSData dataWithContentsOfURL:url] isEqualToData:before], "a write that fails leaves the file as it was");
    left = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:folder error:NULL];
    CHECK(left.count == 1, "and leaves nothing of its own beside it");
    [[NSFileManager defaultManager] removeItemAtPath:folder error:NULL];
}

static NSUInteger saved_photos_count(void)
{
    PHAssetCollection *saved = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeSmartAlbumUserLibrary options:nil].firstObject;
    return saved ? [PHAsset fetchAssetsInAssetCollection:saved options:nil].count : 0;
}

static NSError *add_video(NSURL *url, BOOL move, NSString **identifier)
{
    __block NSString *made = nil;
    NSError *error = nil;
    BOOL added = [[PHPhotoLibrary sharedPhotoLibrary] performChangesAndWait:^{
        PHAssetResourceCreationOptions *options = [[PHAssetResourceCreationOptions alloc] init];
        options.shouldMoveFile = move;
        PHAssetCreationRequest *request = [PHAssetCreationRequest creationRequestForAsset];
        [request addResourceWithType:PHAssetResourceTypeVideo fileURL:url options:options];
        made = request.placeholderForCreatedAsset.localIdentifier;
    } error:&error];
    if (identifier)
        *identifier = added ? made : nil;
    return added ? nil : (error ?: [NSError errorWithDomain:@"charon.test" code:0 userInfo:nil]);
}

// shouldMoveFile: the header says the original file goes away once the asset is created, and its hard-linked
// file that cannot be moved. Each adds a solid-blue video, 640 by 480, the fixture the fleet keeps. Not smaller: the
// iPad 2's H.264 encoder refuses 64 by 64 (AVAssetWriter fails with OSStatus -12902, 2026-09-24) and writes 640 by 480.
static void check_move(void)
{
    NSFileManager *files = [NSFileManager defaultManager];
    NSURL *kept = blue_video(15, 640, 480, NO);
    NSString *identifier = nil;
    NSError *error = add_video(kept, NO, &identifier);
    CHECK(error == nil && asset_with_identifier(identifier) && [files fileExistsAtPath:kept.path], "a file not moved stays where it was");
    [files removeItemAtURL:kept error:NULL];

    NSURL *moved = blue_video(15, 640, 480, NO);
    error = add_video(moved, YES, &identifier);
    CHECK(error == nil && asset_with_identifier(identifier) && ![files fileExistsAtPath:moved.path], "a moved file is gone once the asset is made");

    NSURL *linked = blue_video(15, 640, 480, NO);
    NSURL *second = [linked URLByAppendingPathExtension:@"link.mov"];
    // Through -path, not straight: -[NSURL fileSystemRepresentation] is of iOS 7.0 (NSURL.h:118) and
    // this test runs on 6.1.3, where it raises -- which is what it did on an iPad 2 running 6.1.3 on
    // 2026-10-01, ten checks into the run and with no figure written. The same call in
    // PHAssetCreationRequest9.m and PHHAssetResourceManager9.m is fixed the same way in the port.
    CHECK(link(linked.path.fileSystemRepresentation, second.path.fileSystemRepresentation) == 0, "a second hard link to a video is made");
    NSUInteger before = saved_photos_count();
    error = add_video(linked, YES, NULL);
    printf("move of a hard-linked file: %s\n", error.description.UTF8String ?: "no error");
    CHECK([error.domain isEqualToString:PHPhotosErrorDomain] && error.code == PHPhotosErrorInvalidResource, "a hard-linked file is refused as an invalid resource");
    CHECK(saved_photos_count() == before && [files fileExistsAtPath:linked.path] && [files fileExistsAtPath:second.path], "before anything is written, and both links stay");
    [files removeItemAtURL:linked error:NULL];
    [files removeItemAtURL:second error:NULL];
}

// A video given as data is staged in a file of the process for ALAssetsLibrary, which takes a video only as a file and
// tells a movie by the file's extension (printed below: the same bytes with and without it); the staged file must be
// gone once the change is done. Adds one solid-blue video, 640 by 480, of the given container.
static void check_staged(NSString *fileType)
{
    NSFileManager *files = [NSFileManager defaultManager];
    NSURL *source = blue_video_of_type(fileType, 15, 640, 480, NO);
    NSData *data = [NSData dataWithContentsOfURL:source];
    NSURL *bare = [source URLByDeletingPathExtension];
    [data writeToURL:bare atomically:NO];
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    printf("%s: the library takes it as %s %d, with no extension %d\n", fileType.UTF8String, source.pathExtension.UTF8String,
           [library videoAtPathIsCompatibleWithSavedPhotosAlbum:source], [library videoAtPathIsCompatibleWithSavedPhotosAlbum:bare]);
    [files removeItemAtURL:bare error:NULL];
    [files removeItemAtURL:source error:NULL];
    NSSet *before = [NSSet setWithArray:[files contentsOfDirectoryAtPath:NSTemporaryDirectory() error:NULL]];
    __block NSString *identifier = nil;
    NSError *error = nil;
    BOOL added = [[PHPhotoLibrary sharedPhotoLibrary] performChangesAndWait:^{
        PHAssetCreationRequest *request = [PHAssetCreationRequest creationRequestForAsset];
        [request addResourceWithType:PHAssetResourceTypeVideo data:data options:nil];
        identifier = request.placeholderForCreatedAsset.localIdentifier;
    } error:&error];
    printf("video from data: %s\n", added ? "written" : error.description.UTF8String);
    NSSet *after = [NSSet setWithArray:[files contentsOfDirectoryAtPath:NSTemporaryDirectory() error:NULL]];
    CHECK(added && asset_with_identifier(identifier) != nil, "a video given as data is added");
    CHECK([after isEqualToSet:before], "and the file it was staged in is gone");
}

static NSError *change_error(dispatch_block_t changes)
{
    NSError *error = nil;
    BOOL made = [[PHPhotoLibrary sharedPhotoLibrary] performChangesAndWait:changes error:&error];
    return made ? nil : error;
}

static BOOL is_photos_error(NSError *error, NSInteger code)
{
    return [error.domain isEqualToString:PHPhotosErrorDomain] && error.code == code;
}

// Each error is the header's code for the case it names (facts/Photos/Changes.md), made to happen here. Nothing of these
// is written, but the album of the last one, which is this run's own.
static void check_codes(NSString *albumIdentifier)
{
    NSUInteger before = saved_photos_count();
    NSError *error = change_error(^{
        [PHAssetCreationRequest creationRequestForAsset];
    });
    printf("no resource: %s\n", error.description.UTF8String ?: "no error");
    CHECK(is_photos_error(error, PHPhotosErrorMissingResource), "a creation request with no resource is a missing resource");

    error = change_error(^{
        [[PHAssetCreationRequest creationRequestForAsset] addResourceWithType:PHAssetResourceTypePhoto data:[@"not an image" dataUsingEncoding:NSUTF8StringEncoding] options:nil];
    });
    CHECK(is_photos_error(error, PHPhotosErrorInvalidResource), "photo data that is not an image is an invalid resource");

    error = change_error(^{
        [PHAssetChangeRequest creationRequestForAssetFromImage:[[UIImage alloc] init]];
    });
    CHECK(is_photos_error(error, PHPhotosErrorInvalidResource), "an image with no pixels is an invalid resource");
    CHECK(saved_photos_count() == before, "and none of the three wrote anything");

    // A placeholder whose change never committed: its change was refused, so no asset stands behind it.
    __block PHObjectPlaceholder *orphan = nil;
    change_error(^{
        orphan = [PHAssetCreationRequest creationRequestForAsset].placeholderForCreatedAsset;
    });
    PHAssetCollection *album = albumIdentifier ? [PHAssetCollection fetchAssetCollectionsWithLocalIdentifiers:@[albumIdentifier] options:nil].firstObject : nil;
    CHECK(album != nil, "this run's album is found again");
    error = change_error(^{
        [[PHAssetCollectionChangeRequest changeRequestForAssetCollection:album] addAssets:@[orphan]];
    });
    printf("an asset no change made: %s\n", error.description.UTF8String ?: "no error");
    CHECK(is_photos_error(error, PHPhotosErrorIdentifierNotFound), "an asset no committed change made is not found");

    CharonReadRecord *record = read_resource(((id (*)(id, SEL))objc_msgSend)([PHAssetResource alloc], @selector(init)), NO);
    CHECK(record.chunks.count == 0 && is_photos_error(record.error, PHPhotosErrorIdentifierNotFound), "a resource whose asset is not there reads as not found");
}

static void run_checks(void)
{
    dispatch_semaphore_t answered = dispatch_semaphore_create(0);
    __block PHAuthorizationStatus status = PHAuthorizationStatusNotDetermined;
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus given) {
        status = given;
        dispatch_semaphore_signal(answered);
    }];
    dispatch_semaphore_wait(answered, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(120 * NSEC_PER_SEC)));
    CHECK(status == PHAuthorizationStatusAuthorized, "the application may use the photo library");

    NSURL *video = blue_video(90, 640, 480, YES);
    NSNumber *size = nil;
    [video getResourceValue:&size forKey:NSURLFileSizeKey error:NULL];
    printf("fixture video: %lld bytes\n", size.longLongValue);
    CHECK(video != nil, "the fixture video is made");

    __block NSString *identifier = nil, *albumIdentifier = nil;
    NSString *name = album_name();
    NSError *error = nil;
    // The album request comes first and is given the placeholder of an asset a later request of the block creates: Photos
    // names no order for the requests of one block.
    BOOL made = [[PHPhotoLibrary sharedPhotoLibrary] performChangesAndWait:^{
        PHAssetCollectionChangeRequest *album = [PHAssetCollectionChangeRequest creationRequestForAssetCollectionWithTitle:name];
        PHAssetCreationRequest *request = [PHAssetCreationRequest creationRequestForAsset];
        [request addResourceWithType:PHAssetResourceTypeVideo fileURL:video options:nil];
        [album addAssets:@[request.placeholderForCreatedAsset]];
        identifier = request.placeholderForCreatedAsset.localIdentifier;
        albumIdentifier = album.placeholderForCreatedAssetCollection.localIdentifier;
    } error:&error];
    printf("fixture in %s: %s\n", name.UTF8String, made ? "written" : error.description.UTF8String);
    PHAsset *asset = asset_with_identifier(identifier);
    PHAssetResource *resource = asset ? [PHAssetResource assetResourcesForAsset:asset].firstObject : nil;
    NSData *direct = asset ? direct_read(asset.localIdentifier) : nil;
    printf("direct read: %lu bytes\n", (unsigned long)direct.length);
    CHECK(made && resource && direct.length > 0, "the video is in the library and reads back directly");
    PHAssetCollection *album = albumIdentifier ? [PHAssetCollection fetchAssetCollectionsWithLocalIdentifiers:@[albumIdentifier] options:nil].firstObject : nil;
    PHFetchResult *inAlbum = album ? [PHAsset fetchAssetsInAssetCollection:album options:nil] : nil;
    CHECK(inAlbum.count == 1 && [[inAlbum.firstObject localIdentifier] isEqualToString:asset.localIdentifier],
          "an album made before the asset in the same block holds it");
    if (resource && direct.length) {
        check_read(resource, direct);
        check_write(resource, direct);
    }
    [[NSFileManager defaultManager] removeItemAtURL:video error:NULL];
    check_move();
    check_staged(AVFileTypeQuickTimeMovie);
    check_staged(AVFileTypeMPEG4);
    check_codes(albumIdentifier);

    NSString *summary = [NSString stringWithFormat:@"%d checks, %d failed\n", charon_checks, charon_failures];
    printf("%s", summary.UTF8String);
    fflush(stdout);
    [summary writeToFile:[results_folder stringByAppendingPathComponent:@"photosdata.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

@interface CharonDataDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation CharonDataDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"photosdata.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"photosdata.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    // Off the main thread: ALAssetsLibrary and the port over it answer on the main queue, which a wait here would block.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ run_checks(); });
    return YES;
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([CharonDataDelegate class]));
    }
}
