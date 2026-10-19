#import <AssetsLibrary/AssetsLibrary.h>
#import <Photos/Photos.h>
#import <objc/runtime.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface AvailabilityObserver : NSObject <PHPhotoLibraryAvailabilityObserver>
@property (atomic) int calls;
@property (atomic) BOOL onMain;
@end

@implementation AvailabilityObserver

- (void)photoLibraryDidBecomeUnavailable:(PHPhotoLibrary *)photoLibrary
{
    self.calls++;
    self.onMain = [NSThread isMainThread];
    (void)photoLibrary;
}

@end

@interface RevenantPhotosStore : NSObject
+ (ALAssetsLibrary *)library;
@end

static void post_library_changed(void)
{
    [[NSNotificationCenter defaultCenter] postNotificationName:ALAssetsLibraryChangedNotification object:[RevenantPhotosStore library]];
}

static void turn(NSUInteger times)
{
    for (NSUInteger i = 0; i < times; i++)
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            revenant_log_to(@(argv[1]));

        ALAuthorizationStatus status = [ALAssetsLibrary authorizationStatus];
        printf("AssetsLibrary authorization %ld\n", (long)status);
        CHECK(status == ALAuthorizationStatusDenied, "this process is denied the photo library");

        PHPhotoLibrary *library = [PHPhotoLibrary sharedPhotoLibrary];

        CHECK(class_getInstanceMethod([PHPhotoLibrary class], @selector(unavailabilityReason)) != NULL,
              "PHPhotoLibrary carries -unavailabilityReason");
        CHECK(class_getInstanceMethod([PHPhotoLibrary class], @selector(registerAvailabilityObserver:)) != NULL,
              "PHPhotoLibrary carries -registerAvailabilityObserver:");
        CHECK(class_getInstanceMethod([PHPhotoLibrary class], @selector(unregisterAvailabilityObserver:)) != NULL,
              "PHPhotoLibrary carries -unregisterAvailabilityObserver:");

        NSError *reason = library.unavailabilityReason;
        printf("unavailabilityReason: %s\n", reason.description.UTF8String ?: "nil");
        CHECK(reason != nil, "a denied process has an unavailability reason");
        CHECK([reason.domain isEqualToString:PHPhotosErrorDomain], "the reason is in the header's PHPhotosErrorDomain");
        CHECK(reason.code == 3311, "the reason is PHPhotosErrorAccessUserDenied (3311)");

        @autoreleasepool {
            AvailabilityObserver *observer = [[AvailabilityObserver alloc] init];
            [library registerAvailabilityObserver:observer];
            post_library_changed();
            turn(20);
            CHECK(observer.calls == 0, "an observer registered while the library is unavailable is told nothing");

            [library unregisterAvailabilityObserver:observer];
            [library unregisterAvailabilityObserver:observer];
            post_library_changed();
            turn(20);
            CHECK(observer.calls == 0, "an unregistered observer is told nothing, and unregistering twice is not a crash");
        }

        @autoreleasepool {
            AvailabilityObserver *gone = [[AvailabilityObserver alloc] init];
            [library registerAvailabilityObserver:gone];
        }
        post_library_changed();
        turn(20);
        printf("survived a notification with no observer alive\n");

        AvailabilityObserver *late = [[AvailabilityObserver alloc] init];
        [library registerAvailabilityObserver:late];
        turn(20);
        CHECK(late.calls == 0, "a registration after the state is known tells nothing");
        CHECK(!late.onMain || late.calls == 0, "nothing was delivered on the main thread");

        printf("%d checks, %d failed\n", revenant_checks, revenant_failures);
    }
    return revenant_failures;
}
