#import "../app/revenant_check.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <Photos/Photos.h>
#import <UIKit/UIKit.h>
#include <dlfcn.h>
#include <mach/mach.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <stdio.h>
#include <unistd.h>

extern mach_port_t bootstrap_port;
kern_return_t bootstrap_look_up(mach_port_t bp, const char *service_name, mach_port_t *sp);

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
    printf("PHOTOS-PROBE status=%d\n", (int)[ALAssetsLibrary authorizationStatus]);
    struct stat tccDirectory, tccDatabase;
    int directoryResult = stat("/var/mobile/Library/TCC", &tccDirectory);
    int databaseResult = stat("/var/mobile/Library/TCC/TCC.db", &tccDatabase);
    printf("PHOTOS-PROBE uid=%u tcc-dir=%d mode=%o owner=%u group=%u tcc-db=%d size=%lld owner=%u group=%u mode=%o\n",
           getuid(), directoryResult, directoryResult == 0 ? (unsigned)tccDirectory.st_mode : 0,
           directoryResult == 0 ? (unsigned)tccDirectory.st_uid : 0, directoryResult == 0 ? (unsigned)tccDirectory.st_gid : 0,
           databaseResult, databaseResult == 0 ? (long long)tccDatabase.st_size : -1LL,
           databaseResult == 0 ? (unsigned)tccDatabase.st_uid : 0, databaseResult == 0 ? (unsigned)tccDatabase.st_gid : 0,
           databaseResult == 0 ? (unsigned)tccDatabase.st_mode : 0);
    fflush(stdout);
    void *tccFramework = dlopen("/System/Library/PrivateFrameworks/TCC.framework/TCC", RTLD_NOW);
    printf("PHOTOS-PROBE tcc-framework=%d\n", tccFramework != NULL);
    const char *tccNames[] = {"TCCAccessPreflight", "TCCAccessCopyInformation", "TCCAccessRequest", NULL};
    for (int index = 0; tccFramework && tccNames[index]; index++)
        printf("PHOTOS-PROBE symbol %s=%p\n", tccNames[index], dlsym(tccFramework, tccNames[index]));
    if (tccFramework) {
        int (*preflight)(CFStringRef service, CFDictionaryRef options) = (int (*)(CFStringRef, CFDictionaryRef))dlsym(tccFramework, "TCCAccessPreflight");
        if (preflight)
            printf("PHOTOS-PROBE preflight=%d\n", preflight(CFSTR("kTCCServicePhotos"), NULL));
    }
    void *sqlite = dlopen("/usr/lib/libsqlite3.dylib", RTLD_NOW);
    int (*open_database)(const char *, void **, int, const char *) = sqlite ? (int (*)(const char *, void **, int, const char *))dlsym(sqlite, "sqlite3_open_v2") : NULL;
    int (*prepare)(void *, const char *, int, void **, const char **) = sqlite ? (int (*)(void *, const char *, int, void **, const char **))dlsym(sqlite, "sqlite3_prepare_v2") : NULL;
    int (*step)(void *) = sqlite ? (int (*)(void *))dlsym(sqlite, "sqlite3_step") : NULL;
    const unsigned char *(*column_text)(void *, int) = sqlite ? (const unsigned char *(*)(void *, int))dlsym(sqlite, "sqlite3_column_text") : NULL;
    if (open_database && prepare && step && column_text) {
        void *database = NULL;
        int opened = open_database("/var/mobile/Library/TCC/TCC.db", &database, 1, NULL);
        printf("PHOTOS-PROBE tcc-db open=%d\n", opened);
        void *statement = NULL;
        if (opened == 0 && prepare(database, "SELECT service, client, client_type, allowed, prompt_count FROM access", -1, &statement, NULL) == 0) {
            while (step(statement) == 100)
                printf("PHOTOS-PROBE row %s|%s|%s|%s|%s\n", column_text(statement, 0), column_text(statement, 1), column_text(statement, 2), column_text(statement, 3), column_text(statement, 4));
        }
    }
    fflush(stdout);
    fflush(stdout);
    fflush(stdout);
    mach_port_t probePort = MACH_PORT_NULL;
    kern_return_t probeLookup = bootstrap_look_up(bootstrap_port, "com.apple.assetsd.messagingServer", &probePort);
    printf("PHOTOS-PROBE lookup assetsd=%d port=%u\n", probeLookup, probePort);
    probeLookup = bootstrap_look_up(bootstrap_port, "com.apple.tccd", &probePort);
    printf("PHOTOS-PROBE lookup tccd=%d port=%u\n", probeLookup, probePort);
    fflush(stdout);
    ALAssetsLibrary *probeLibrary = [[ALAssetsLibrary alloc] init];
    [probeLibrary enumerateGroupsWithTypes:ALAssetsGroupAll usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
        printf("PHOTOS-PROBE group=%s\n", group ? "yes" : "nil");
        fflush(stdout);
    } failureBlock:^(NSError *error) {
        printf("PHOTOS-PROBE failure domain=%s code=%ld %s\n", [error.domain UTF8String], (long)error.code, [[error localizedDescription] UTF8String]);
        fflush(stdout);
    }];
    NSDate *probeDeadline = [NSDate dateWithTimeIntervalSinceNow:5];
    while ([probeDeadline timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    printf("PHOTOS-PROBE after status=%d\n", (int)[ALAssetsLibrary authorizationStatus]);
    fflush(stdout);
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
