#import <AssetsLibrary/AssetsLibrary.h>
#import <Photos/Photos.h>
#include <dlfcn.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

static NSString *image_of(Class cls)
{
    Dl_info info;
    return dladdr((__bridge const void *)cls, &info) ? @(info.dli_fname).lastPathComponent : @"?";
}

static void check_status(void)
{
    Class cls = NSClassFromString(@"PHPhotoLibrary");
    CHECK(cls != Nil, "PHPhotoLibrary exists");
    CHECK_EQUAL(image_of(cls), @"libPhotosBackports.dylib", "PHPhotoLibrary comes from the backports");
    ALAuthorizationStatus assets = [ALAssetsLibrary authorizationStatus];
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    CHECK((NSInteger)status == (NSInteger)assets, "the status is the ALAssetsLibrary status");
    CHECK(status >= PHAuthorizationStatusNotDetermined && status <= PHAuthorizationStatusAuthorized, "the status is one of the four of iOS 8");
    CHECK([PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelReadWrite] == status, "the read-write level answers the same");
    CHECK([PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelAddOnly] == status, "the add-only level answers the same");
    CHECK(status != PHAuthorizationStatusLimited, "the status is never limited");
    CHECK([PHPhotoLibrary sharedPhotoLibrary] != nil, "there is a shared library");
    CHECK([PHPhotoLibrary sharedPhotoLibrary] == [PHPhotoLibrary sharedPhotoLibrary], "it is the same object twice");
}

static void check_request(void)
{
    PHAuthorizationStatus before = [PHPhotoLibrary authorizationStatus];
    if (before == PHAuthorizationStatusNotDetermined) {
        printf("the status is not determined; the request would show the prompt and is not called\n");
        return;
    }
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    __block PHAuthorizationStatus given = PHAuthorizationStatusNotDetermined;
    __block BOOL onMain = YES;
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        given = status;
        onMain = [NSThread isMainThread];
        dispatch_semaphore_signal(done);
    }];
    CHECK(dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) == 0, "the handler is called");
    CHECK(given == before, "the handler is given the decided status");
    CHECK(!onMain, "the handler is called off the main thread");
    dispatch_semaphore_t again = dispatch_semaphore_create(0);
    __block PHAuthorizationStatus levelled = PHAuthorizationStatusNotDetermined;
    [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelReadWrite handler:^(PHAuthorizationStatus status) {
        levelled = status;
        dispatch_semaphore_signal(again);
    }];
    CHECK(dispatch_semaphore_wait(again, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) == 0, "the handler of the level request is called");
    CHECK(levelled == before, "the level request gives the same status");
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        check_status();
        check_request();
        printf("%d checks, %d failed\n", charon_checks, charon_failures);
    }
    return charon_failures;
}
