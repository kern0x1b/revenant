#import <AssetsLibrary/AssetsLibrary.h>
#import <Photos/Photos.h>
#import <UIKit/UIKit.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

// PHPhotoLibrary's change observers over ALAssetsLibraryChangedNotification (facts/Photos/Changes.md).
// Each run adds three 8-by-8 solid-blue images to the saved photos, the fixtures the fleet keeps.
// An application of its own (photoschanges8-Info.plist): iOS 6 gives the photo library to a bundle
// identifier the user allowed, and a bare executable has none, so every write of it is refused.

static NSString *const results_folder = @"/private/var/backports";

@interface CharonChangeObserver : NSObject <PHPhotoLibraryChangeObserver>
@property (atomic, strong) PHChange *change;
@property (atomic) BOOL onMain;
@property (atomic) int calls;
@end

@implementation CharonChangeObserver

- (void)photoLibraryDidChange:(PHChange *)changeInstance
{
    self.onMain = [NSThread isMainThread];
    self.change = changeInstance;
    self.calls++;
}

@end

static UIImage *fixture(void)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(8, 8), YES, 1);
    [[UIColor blueColor] setFill];
    UIRectFill(CGRectMake(0, 0, 8, 8));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

// The identifier the asset is known by once the change is done: the placeholder's, read after the write.
static NSString *write_fixture(void)
{
    __block PHObjectPlaceholder *placeholder = nil;
    NSError *error = nil;
    BOOL written = [[PHPhotoLibrary sharedPhotoLibrary] performChangesAndWait:^{
        placeholder = [PHAssetChangeRequest creationRequestForAssetFromImage:fixture()].placeholderForCreatedAsset;
    } error:&error];
    if (!written)
        printf("write: %s\n", error.description.UTF8String);
    return written ? placeholder.localIdentifier : nil;
}

static void wait_until(double seconds, BOOL (^done)(void))
{
    for (int i = 0; i < seconds * 20 && !done(); i++)
        [NSThread sleepForTimeInterval:0.05];
}

static void check_raw_notification(void)
{
    // What the release itself posts for a write of the application, before any port code is asked: how
    // often, from which library, on which thread, and with what user info.
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    __block NSDictionary *info = nil;
    __block BOOL onMain = NO, nilInfo = NO;
    __block int posts = 0, fromThis = 0;
    id token = [[NSNotificationCenter defaultCenter] addObserverForName:ALAssetsLibraryChangedNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        info = note.userInfo;
        nilInfo = note.userInfo == nil;
        onMain = [NSThread isMainThread];
        posts++;
        fromThis += note.object == library;
    }];
    NSString *identifier = write_fixture();
    wait_until(10, ^{ return (BOOL)(posts > 0); });
    wait_until(2, ^{ return NO; });
    [[NSNotificationCenter defaultCenter] removeObserver:token];
    printf("raw: posts %d, from an instance that did not write %d, on main %d, user info nil %d, keys %s\n", posts, fromThis, onMain, nilInfo,
           [[[info.allKeys sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@","] UTF8String]);
    CHECK(identifier != nil, "the first fixture is written");
    CHECK(posts > 0, "6.1.3 posts ALAssetsLibraryChangedNotification for a write of the application itself");
    CHECK(!nilInfo && info.count == 0, "with an empty user info, although an asset was added: the release names nothing for it");
}

static void check_observer(void)
{
    PHFetchResult *albums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeSmartAlbumUserLibrary options:nil];
    CHECK(albums.count == 1, "the saved photos are found");
    PHFetchResult *before = [PHAsset fetchAssetsInAssetCollection:albums.firstObject options:nil];
    PHAsset *old = before.firstObject;
    CHECK(old != nil, "the saved photos hold an asset before the write");

    CharonChangeObserver *observer = [[CharonChangeObserver alloc] init];
    CharonChangeObserver *dropped = [[CharonChangeObserver alloc] init];
    __weak CharonChangeObserver *weakDropped = dropped;
    [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:observer];
    [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:dropped];
    dropped = nil;
    CHECK(weakDropped == nil, "the library holds an observer weakly");

    __block NSArray *keys = nil;
    id token = [[NSNotificationCenter defaultCenter] addObserverForName:ALAssetsLibraryChangedNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        keys = note.userInfo ? [note.userInfo.allKeys sortedArrayUsingSelector:@selector(compare:)] : @[@"(nil)"];
    }];
    NSString *identifier = write_fixture();
    CHECK(identifier != nil, "the second fixture is written");
    wait_until(10, ^{ return (BOOL)(observer.change != nil); });
    CHECK(observer.change != nil, "photoLibraryDidChange: is sent after the write");
    CHECK(!observer.onMain, "photoLibraryDidChange: is sent off the main thread");
    [[NSNotificationCenter defaultCenter] removeObserver:token];
    printf("second write: user info keys %s\n", [[keys componentsJoinedByString:@","] UTF8String]);

    PHFetchResultChangeDetails *details = [observer.change changeDetailsForFetchResult:before];
    CHECK(details != nil && details.fetchResultBeforeChanges == before, "the saved photos changed");
    CHECK(details.hasIncrementalChanges, "the change is incremental");
    CHECK(details.fetchResultAfterChanges.count == before.count + 1, "the fetch after holds one asset more");
    CHECK(details.insertedIndexes.count == 1 && details.removedIndexes.count == 0, "one insertion, no removal");
    CHECK_EQUAL([details.insertedObjects.firstObject localIdentifier], identifier, "the insertion is the asset written");
    CHECK(!details.hasMoves, "no moves");
    CHECK([observer.change changeDetailsForObject:old] == nil, "an asset the write did not touch has no change");
    PHAssetCollection *album = albums.firstObject;
    PHObjectChangeDetails *albumDetails = [observer.change changeDetailsForObject:album];
    CHECK(albumDetails != nil && !albumDetails.objectWasDeleted, "the saved photos album itself changed and is still there");
    CHECK([(PHAssetCollection *)albumDetails.objectAfterChanges estimatedAssetCount] == album.estimatedAssetCount + 1, "the album after counts one asset more");

    PHFetchResult *now = details.fetchResultAfterChanges;
    PHFetchResult *gone = [PHAsset fetchAssetsWithLocalIdentifiers:@[@"assets-library://asset/asset.JPG?id=00000000-0000-0000-0000-000000000000&ext=JPG"] options:nil];
    CHECK(gone.count == 0 && [observer.change changeDetailsForFetchResult:gone] == nil, "a fetch of nothing has no change");

    [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:observer];
    int calls = observer.calls;
    observer.change = nil;
    NSString *third = write_fixture();
    wait_until(5, ^{ return NO; });
    CHECK(third != nil && observer.calls == calls, "an unregistered observer is not told");
    PHFetchResultChangeDetails *manual = [PHFetchResultChangeDetails changeDetailsFromFetchResult:before toFetchResult:now changedObjects:@[]];
    CHECK(manual.insertedIndexes.count == 1 && manual.changedIndexes.count == 0, "changeDetailsFromFetchResult: computes the same insertion");
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
    check_raw_notification();
    check_observer();
    NSString *summary = [NSString stringWithFormat:@"%d checks, %d failed\n", charon_checks, charon_failures];
    printf("%s", summary.UTF8String);
    fflush(stdout);
    [summary writeToFile:[results_folder stringByAppendingPathComponent:@"photoschanges.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

@interface CharonChangesDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation CharonChangesDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"photoschanges.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"photoschanges.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    // Off the main thread, so that the main thread stays free for what the release answers on it and
    // for the observer check that the change is not told there.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ run_checks(); });
    return YES;
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([CharonChangesDelegate class]));
    }
}
