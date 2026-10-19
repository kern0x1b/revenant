#import <AssetsLibrary/AssetsLibrary.h>
#import <Photos/Photos.h>
#import <objc/runtime.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// PHPhotoLibrary's library availability of iOS 13 (facts/Photos/Availability.md), in a process the
// release denies the photo library, which is what makes the unavailable case measurable without a
// library anybody's: a daemon on 6.1.3 is denied it, and this program writes nothing and reads no
// asset. Run through tests/backports/device/photos/run.sh.
//
// The state that cannot be measured here is named as such and not asserted: an authorised process,
// whose -[PHPhotoLibrary unavailabilityReason] is nil, needs a bundle identifier the user allowed, so
// it is the same program's next run as an application.

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

@interface CharonPhotosStore : NSObject
+ (ALAssetsLibrary *)library;
@end

// The port's own listener is registered for this name and this object; posting it is what makes the
// port re-read the authorization, which is the only way it learns of a change on this release.
static void post_library_changed(void)
{
    [[NSNotificationCenter defaultCenter] postNotificationName:ALAssetsLibraryChangedNotification object:[CharonPhotosStore library]];
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
            charon_log_to(@(argv[1]));

        // The precondition, and the control: without it nothing below means anything.
        ALAuthorizationStatus status = [ALAssetsLibrary authorizationStatus];
        printf("AssetsLibrary authorization %ld\n", (long)status);
        CHECK(status == ALAuthorizationStatusDenied, "this process is denied the photo library");

        PHPhotoLibrary *library = [PHPhotoLibrary sharedPhotoLibrary];

        // The class carries the members, and not NSObject's.
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
            // Already unavailable when it registered: a registration is not a second way of asking
            // for the reason, and the release posted nothing.
            CHECK(observer.calls == 0, "an observer registered while the library is unavailable is told nothing");

            [library unregisterAvailabilityObserver:observer];
            [library unregisterAvailabilityObserver:observer];
            post_library_changed();
            turn(20);
            CHECK(observer.calls == 0, "an unregistered observer is told nothing, and unregistering twice is not a crash");
        }

        // Weakly held: an observer that goes away is dropped without being unregistered, so a
        // notification after it is gone reaches nobody and does not crash.
        @autoreleasepool {
            AvailabilityObserver *gone = [[AvailabilityObserver alloc] init];
            [library registerAvailabilityObserver:gone];
        }
        post_library_changed();
        turn(20);
        printf("survived a notification with no observer alive\n");

        // An observer registered now is told nothing either: the state has not changed since.
        AvailabilityObserver *late = [[AvailabilityObserver alloc] init];
        [library registerAvailabilityObserver:late];
        turn(20);
        CHECK(late.calls == 0, "a registration after the state is known tells nothing");
        CHECK(!late.onMain || late.calls == 0, "nothing was delivered on the main thread");

        printf("%d checks, %d failed\n", charon_checks, charon_failures);
    }
    return charon_failures;
}
