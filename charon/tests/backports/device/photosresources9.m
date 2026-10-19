#import <Photos/Photos.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <objc/message.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// PHAssetResourceManager's cancellation over the release's AssetsLibrary (facts/Photos/Changes.md), in a process of
// its own, with the Photos sources built in. A resource made with no asset behind it reads as "the asset is gone", so
// the answer of a request that is not cancelled is known without a photo library the process may read: it is the
// control for the answer of one that is.

@interface CharonRequestRecord : NSObject
@property (atomic) int completions, deliveries;
@property (atomic) BOOL completedBeforeCancel;
@property (atomic, strong) NSError *error;
@end

@implementation CharonRequestRecord
@end

static BOOL wait_for(BOOL (^done)(void))
{
    for (int i = 0; i < 200 && !done(); i++)
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
    return done();
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        printf("AssetsLibrary authorization %ld\n", (long)[ALAssetsLibrary authorizationStatus]);
        PHAssetResourceManager *manager = [PHAssetResourceManager defaultManager];
        PHAssetResource *resource = ((id (*)(id, SEL))objc_msgSend)([PHAssetResource alloc], @selector(init));

        CharonRequestRecord *plain = [[CharonRequestRecord alloc] init];
        [manager requestDataForAssetResource:resource options:nil dataReceivedHandler:^(NSData *data) {
            plain.deliveries++;
        } completionHandler:^(NSError *error) {
            plain.error = error;
            plain.completions++;
        }];
        CHECK(wait_for(^{ return (BOOL)(plain.completions > 0); }), "a request with no asset behind it completes");
        printf("not cancelled: %s\n", plain.error.description.UTF8String ?: "no error");
        CHECK(plain.error && plain.error.code != PHPhotosErrorUserCancelled && plain.deliveries == 0, "with the asset's error and no data");

        // Every request cancelled right after the call: one not completed by then completes once, cancelled, with no data.
        NSMutableArray<CharonRequestRecord *> *records = [NSMutableArray array];
        for (int i = 0; i < 50; i++) {
            CharonRequestRecord *record = [[CharonRequestRecord alloc] init];
            PHAssetResourceDataRequestID requestID = [manager requestDataForAssetResource:resource options:nil dataReceivedHandler:^(NSData *data) {
                record.deliveries++;
            } completionHandler:^(NSError *error) {
                record.error = error;
                record.completions++;
            }];
            record.completedBeforeCancel = record.completions > 0;
            [manager cancelDataRequest:requestID];
            [records addObject:record];
        }
        CHECK(wait_for(^{ return (BOOL)([[records valueForKeyPath:@"@min.completions"] intValue] > 0); }), "every cancelled request completes");
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
        int cancelled = 0, late = 0, wrong = 0;
        for (CharonRequestRecord *record in records) {
            if (record.completions != 1 || record.deliveries != 0)
                wrong++;
            else if (record.completedBeforeCancel)
                late++;
            else if ([record.error.domain isEqualToString:PHPhotosErrorDomain] && record.error.code == PHPhotosErrorUserCancelled)
                cancelled++;
            else
                wrong++;
        }
        printf("cancelled %d, completed before the cancel %d, other %d\n", cancelled, late, wrong);
        CHECK(wrong == 0, "each completes once, with no data, cancelled unless it had completed before the cancel");
        CHECK(cancelled > 0, "and the cancel reaches a request in flight");
        NSError *error = nil;
        for (CharonRequestRecord *record in records)
            if (record.error.code == PHPhotosErrorUserCancelled)
                error = record.error;
        printf("cancelled: %s\n", error.description.UTF8String ?: "none");

        // A cancel of a request that has completed, or of one never made, changes nothing.
        [manager cancelDataRequest:plain.completions ? 1 : 0];
        [manager cancelDataRequest:-5];
        CharonRequestRecord *after = [[CharonRequestRecord alloc] init];
        [manager requestDataForAssetResource:resource options:nil dataReceivedHandler:nil completionHandler:^(NSError *e) {
            after.error = e;
            after.completions++;
        }];
        CHECK(wait_for(^{ return (BOOL)(after.completions > 0); }) && after.error.code != PHPhotosErrorUserCancelled,
              "a later request is not cancelled by a cancel of another");
        printf("%d checks, %d failed\n", charon_checks, charon_failures);
    }
    return charon_failures;
}
