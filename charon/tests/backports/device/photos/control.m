#import <Photos/Photos.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// The negative control of tests/backports/device/photos/run.sh, and the reason that run.sh can say
// "0 failures" about photosalbums8.m.
//
// photosalbums8.m holds the port's album-name check to the release's own answer in a process the
// release denies: the check must NOT read that refusal as "no such album". This program asserts the
// opposite -- that the check answers "no such album" -- on the same call, in the same process, on
// whatever device it is run on. It must report a failure, or the check it guards is not being
// exercised: a device where the release does not deny this process makes the guarded check vacuous,
// and that is the one state in which "0 failures" would mean nothing.
//
// It reads: it enumerates the release's album list and asks the port's check about one name. It
// writes nothing, so it is safe on any device.

@interface CharonPhotosStore : NSObject
+ (BOOL)findAlbumWithName:(NSString *)name found:(BOOL *)found error:(NSError **)error;
@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
        __block BOOL answered = NO;
        __block NSError *refusal = nil;
        [library enumerateGroupsWithTypes:ALAssetsGroupAlbum usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
            if (!group)
                answered = YES;
        } failureBlock:^(NSError *error) {
            refusal = error;
            answered = YES;
        }];
        for (int i = 0; i < 200 && !answered; i++)
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
        printf("the release's enumeration: %s\n", refusal.description.UTF8String ?: "listed");

        if (![CharonPhotosStore respondsToSelector:@selector(findAlbumWithName:found:error:)]) {
            printf("FAIL the control needs the port's album check, and this binary has none\n");
            printf("1 checks, 1 failed\n");
            return 1;
        }

        BOOL found = NO;
        NSError *error = nil;
        BOOL listed = [CharonPhotosStore findAlbumWithName:@"CharonPhotosProbe" found:&found error:&error];
        NSString *answer = error ? error.description : (listed ? @"listed" : @"not listed");
        printf("the port's album check: %s\n", answer.UTF8String);
        // The wrong answer, on purpose: a failure here is the control working.
        CHECK(listed && found == NO, "CONTROL: the check answers \"no such album\" instead of the release's refusal");
        printf("%d checks, %d failed\n", charon_checks, charon_failures);
    }
    return charon_failures;
}
