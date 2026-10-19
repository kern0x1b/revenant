#import <Photos/Photos.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface RevenantPhotosStore : NSObject
+ (BOOL)findAlbumWithName:(NSString *)name found:(BOOL *)found error:(NSError **)error;
@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            revenant_log_to(@(argv[1]));
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

        if (![RevenantPhotosStore respondsToSelector:@selector(findAlbumWithName:found:error:)]) {
            printf("FAIL the control needs the port's album check, and this binary has none\n");
            printf("1 checks, 1 failed\n");
            return 1;
        }

        BOOL found = NO;
        NSError *error = nil;
        BOOL listed = [RevenantPhotosStore findAlbumWithName:@"RevenantPhotosProbe" found:&found error:&error];
        NSString *answer = error ? error.description : (listed ? @"listed" : @"not listed");
        printf("the port's album check: %s\n", answer.UTF8String);
        CHECK(listed && found == NO, "CONTROL: the check answers \"no such album\" instead of the release's refusal");
        printf("%d checks, %d failed\n", revenant_checks, revenant_failures);
    }
    return revenant_failures;
}
