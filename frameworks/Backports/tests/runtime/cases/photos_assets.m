#import "../app/revenant_check.h"
#import <Photos/Photos.h>
#import <UIKit/UIKit.h>
#include <stdio.h>
#include <unistd.h>

@interface RevenantPhotosTestObserver : NSObject <PHPhotoLibraryChangeObserver>
@property (nonatomic, copy) void (^handler)(PHChange *change);
@end

@implementation RevenantPhotosTestObserver

- (void)photoLibraryDidChange:(PHChange *)change
{
    if (self.handler)
        self.handler(change);
}

@end

static BOOL revenant_wait_for_photo_authorization(void)
{
    __block PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    if (status == PHAuthorizationStatusNotDetermined) {
        __block BOOL finished = NO;
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus result) {
            status = result;
            finished = YES;
        }];
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:10];
        while (!finished && [deadline timeIntervalSinceNow] > 0)
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    return status == PHAuthorizationStatusAuthorized;
}

static BOOL revenant_wait_for_file(NSString *path)
{
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:10];
    while (![NSFileManager.defaultManager fileExistsAtPath:path] && [deadline timeIntervalSinceNow] > 0)
        usleep(10000);
    return [NSFileManager.defaultManager fileExistsAtPath:path];
}

REVENANT_CASE(photos_assets)
{
    BOOL authorized = revenant_wait_for_photo_authorization();
    revenant_expect_true(@"the photo library grants access", authorized, @"authorization was not granted");
    if (!authorized)
        return;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(256, 256), YES, 1);
    [[UIColor colorWithRed:0.2 green:0.4 blue:0.7 alpha:1] setFill];
    UIRectFill(CGRectMake(0, 0, 256, 256));
    UIImage *sample = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    PHFetchOptions *options = [[PHFetchOptions alloc] init];
    options.predicate = [NSPredicate predicateWithFormat:@"mediaType = %d", PHAssetMediaTypeImage];
    options.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
    PHFetchResult<PHAsset *> *before = [PHAsset fetchAssetsWithOptions:options];
    RevenantPhotosTestObserver *observer = [[RevenantPhotosTestObserver alloc] init];
    __block PHChange *change = nil;
    NSLock *changeLock = [[NSLock alloc] init];
    observer.handler = ^(PHChange *updated) {
        [changeLock lock];
        change = updated;
        [changeLock unlock];
    };
    [PHPhotoLibrary.sharedPhotoLibrary registerChangeObserver:observer];
    NSError *writeError = nil;
    BOOL wrote = [PHPhotoLibrary.sharedPhotoLibrary performChangesAndWait:^{
        [PHAssetChangeRequest creationRequestForAssetFromImage:sample];
    } error:&writeError];
    revenant_expect_true(@"a test photo can be saved to the AssetsLibrary-backed library", wrote, writeError.localizedDescription ?: @"no error was returned");
    if (!wrote) {
        [PHPhotoLibrary.sharedPhotoLibrary unregisterChangeObserver:observer];
        return;
    }
    NSDate *changeDeadline = [NSDate dateWithTimeIntervalSinceNow:10];
    BOOL receivedChange = NO;
    while ([changeDeadline timeIntervalSinceNow] > 0) {
        [changeLock lock];
        receivedChange = change != nil;
        [changeLock unlock];
        if (receivedChange)
            break;
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    [PHPhotoLibrary.sharedPhotoLibrary unregisterChangeObserver:observer];
    PHChange *deliveredChange;
    [changeLock lock];
    deliveredChange = change;
    [changeLock unlock];
    PHFetchResultChangeDetails *details = deliveredChange ? [deliveredChange changeDetailsForFetchResult:before] : nil;
    revenant_expect_true(@"a library change refetches the registered asset results", details.fetchResultAfterChanges.count > before.count,
                         @"the observer delivered no inserted photo");
    PHFetchResult<PHAsset *> *assets = [PHAsset fetchAssetsWithOptions:options];
    PHAsset *asset = assets.firstObject;
    revenant_expect_true(@"a sorted image fetch returns an asset", assets.count > 0 && asset != nil, @"the photo fetch was empty");
    if (!asset)
        return;
    NSArray *resources = [PHAssetResource assetResourcesForAsset:asset];
    BOOL locallyAvailable = resources.firstObject && [[resources.firstObject valueForKey:@"locallyAvailable"] boolValue];
    revenant_expect_true(@"a local asset resource reports local availability", locallyAvailable, @"the resource did not report a local representation");
    PHImageRequestOptions *requestOptions = [[PHImageRequestOptions alloc] init];
    requestOptions.synchronous = YES;
    NSString *perfReady = @"/var/mobile/Library/Caches/revenant-photos-perf-ready";
    NSString *perfDone = @"/var/mobile/Library/Caches/revenant-photos-perf-done";
    [NSFileManager.defaultManager removeItemAtPath:perfReady error:nil];
    [NSFileManager.defaultManager removeItemAtPath:perfDone error:nil];
    __block UIImage *thumbnail = nil;
    __block NSDictionary *info = nil;
    if (!negative) {
        printf("REVENANT-PERF-BEGIN photos-thumbnail\n");
        fflush(stdout);
        revenant_expect_true(@"the thumbnail performance window starts", revenant_wait_for_file(perfReady), @"the emulator did not acknowledge perf-begin");
    }
    [[PHImageManager defaultManager] requestImageForAsset:asset targetSize:CGSizeMake(64, 64)
                                             contentMode:PHImageContentModeAspectFit options:requestOptions
                                            resultHandler:^(UIImage *image, NSDictionary *resultInfo) {
        thumbnail = image;
        info = resultInfo;
    }];
    if (!negative) {
        printf("REVENANT-PERF-END\n");
        fflush(stdout);
        revenant_expect_true(@"the thumbnail performance window ends", revenant_wait_for_file(perfDone), @"the emulator did not acknowledge perf-end");
    }
    revenant_expect_true(@"a thumbnail request returns an image", negative ? thumbnail == nil : thumbnail != nil,
                         [info[PHImageErrorKey] localizedDescription] ?: @"the thumbnail result did not match the expected control");
    if (thumbnail)
        revenant_expect_true(@"the thumbnail is bounded by its requested size", thumbnail.size.width <= 64 && thumbnail.size.height <= 64,
                             [NSString stringWithFormat:@"%gx%g", thumbnail.size.width, thumbnail.size.height]);
}
