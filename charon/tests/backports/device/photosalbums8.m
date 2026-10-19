#import <Photos/Photos.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// The check an album's creation makes for its name, when the release refuses to list the albums
// (facts/Photos/Changes.md). A daemon is denied the photo library on 6.1.3, so its enumeration fails for real;
// the Photos sources are built in, and the check is called as the change's own validation calls it.

@interface CharonPhotosStore : NSObject
+ (BOOL)findAlbumWithName:(NSString *)name found:(BOOL *)found error:(NSError **)error;
@end

@interface CharonPhotosTransaction : NSObject
+ (BOOL)runAndWait:(dispatch_block_t)changes error:(NSError **)error;
@end

@interface PHAssetCollectionChangeRequest (CharonValidation)
- (BOOL)charon_validate:(NSError **)error;
@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        ALAuthorizationStatus status = [ALAssetsLibrary authorizationStatus];
        printf("AssetsLibrary authorization %ld\n", (long)status);

        // The control: the release itself refuses this process the list of albums.
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
        CHECK(refusal != nil, "the release refuses this process the list of albums");

        if ([CharonPhotosStore respondsToSelector:@selector(findAlbumWithName:found:error:)]) {
            BOOL found = NO;
            NSError *error = nil;
            BOOL listed = [CharonPhotosStore findAlbumWithName:@"CharonPhotosProbe" found:&found error:&error];
            CHECK(!listed && [error.domain isEqualToString:refusal.domain] && error.code == refusal.code, "the album check answers the release's refusal, not \"no such album\"");
        }

        // The change's validation, as the transaction runs it; the transaction itself stops earlier, at the authorization.
        __block PHAssetCollectionChangeRequest *request = nil;
        NSError *committed = nil;
        [CharonPhotosTransaction runAndWait:^{
            request = [PHAssetCollectionChangeRequest creationRequestForAssetCollectionWithTitle:@"CharonPhotosProbe-validate"];
        } error:&committed];
        printf("the change: %s\n", committed.description.UTF8String ?: "committed");
        NSError *invalid = nil;
        BOOL valid = [request charon_validate:&invalid];
        printf("its validation: %d, %s\n", valid, invalid.description.UTF8String ?: "no error");
        CHECK(!valid && [invalid.domain isEqualToString:refusal.domain] && invalid.code == refusal.code, "an album's creation fails on the refusal instead of writing on");
        printf("%d checks, %d failed\n", charon_checks, charon_failures);
    }
    return charon_failures;
}
