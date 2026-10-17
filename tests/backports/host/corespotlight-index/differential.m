// differential.m - the same program, built once against the host's CoreSpotlight and once against the port's CSSearchableIndex.m
// and the sources it needs. Every line it prints must be the same on both sides. The lines cover the index's delegate
// property (its default, what it reads back, the weak reference) and the external-provider fetch: the answer for a bundle the
// caller has no item from, with and without a delegate, and the thread the completion handler runs on.
#import <Foundation/Foundation.h>
#import <CoreSpotlight/CoreSpotlight.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface Delegate : NSObject <CSSearchableIndexDelegate>
@property (nonatomic) NSInteger dataCalls;
@end

@implementation Delegate

- (void)searchableIndex:(CSSearchableIndex *)index reindexAllSearchableItemsWithAcknowledgementHandler:(void (^)(void))handler
{
    handler();
}

- (void)searchableIndex:(CSSearchableIndex *)index reindexSearchableItemsWithIdentifiers:(NSArray<NSString *> *)identifiers acknowledgementHandler:(void (^)(void))handler
{
    handler();
}

- (NSData *)dataForSearchableIndex:(CSSearchableIndex *)index itemIdentifier:(NSString *)itemIdentifier typeIdentifier:(NSString *)typeIdentifier error:(out NSError **)error
{
    self.dataCalls++;
    return nil;
}

@end

// The handler's answer is kept and printed by the caller, so the lines come out in order whichever thread answers.
static void fetch(CSSearchableIndex *index, NSString *name)
{
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    __block NSData *data = nil;
    __block NSError *error = nil;
    __block BOOL mainThread = YES;
    [index fetchDataForBundleIdentifier:@"com.example.nothere" itemIdentifier:@"x" contentType:[UTType typeWithIdentifier:@"public.text"]
                      completionHandler:^(NSData *d, NSError *e) {
                          data = d;
                          error = e;
                          mainThread = [NSThread isMainThread];
                          dispatch_semaphore_signal(done);
                      }];
    BOOL answered = dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)) == 0;
    printf("%s: answered=%d data=%s domain=%s code=%ld onMain=%d\n", name.UTF8String, answered, data ? "yes" : "nil",
           error.domain.UTF8String, (long)error.code, mainThread);
}

int main(void)
{
    @autoreleasepool {
        CSSearchableIndex *index = [CSSearchableIndex defaultSearchableIndex];
        printf("index.indexDelegate default nil: %d\n", index.indexDelegate == nil);
        fetch(index, @"fetch without delegate");

        Delegate *delegate = [[Delegate alloc] init];
        index.indexDelegate = delegate;
        printf("index.indexDelegate set: %d\n", index.indexDelegate == delegate);
        fetch(index, @"fetch with delegate");
        printf("index.dataForSearchableIndex calls: %ld\n", (long)delegate.dataCalls);

        @autoreleasepool {
            Delegate *freed = [[Delegate alloc] init];
            index.indexDelegate = freed;
        }
        printf("index.indexDelegate after the delegate is freed nil: %d\n", index.indexDelegate == nil);
    }
    return 0;
}
