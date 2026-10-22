#import "check.h"
#import <objc/runtime.h>

static void revenant_perform(NSString *reason, void (^block)(BOOL))
{
    SEL selector = NSSelectorFromString(@"performExpiringActivityWithReason:usingBlock:");
    IMP implementation = method_getImplementation(class_getInstanceMethod([NSProcessInfo class], selector));
    ((void (*)(id, SEL, NSString *, void (^)(BOOL)))implementation)([NSProcessInfo processInfo], selector, reason, block);
}

static void (^revenant_expiration)(void);
static NSUInteger revenant_ended;
static NSUInteger revenant_ended_task;
static NSUInteger revenant_begun;

@interface UIApplication : NSObject
+ (instancetype)sharedApplication;
- (NSUInteger)beginBackgroundTaskWithExpirationHandler:(void (^)(void))handler;
- (void)endBackgroundTask:(NSUInteger)task;
@end

@implementation UIApplication

+ (instancetype)sharedApplication
{
    static UIApplication *application;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        application = [[UIApplication alloc] init];
    });
    return application;
}

- (NSUInteger)beginBackgroundTaskWithExpirationHandler:(void (^)(void))handler
{
    revenant_expiration = [handler copy];
    revenant_begun++;
    return 7;
}

- (void)endBackgroundTask:(NSUInteger)task
{
    revenant_ended++;
    revenant_ended_task = task;
}

@end

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    dispatch_semaphore_t finished = dispatch_semaphore_create(0);
    __block BOOL expired = YES;
    __block BOOL onMain = YES;
    revenant_perform(@"test", ^(BOOL value) {
        expired = value;
        onMain = [NSThread isMainThread];
        dispatch_semaphore_signal(finished);
    });
    dispatch_semaphore_wait(finished, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    usleep(100000);
    revenant_check(revenant_begun == 1 && !expired && !onMain, "the block runs off the main thread with expired NO", [NSString stringWithFormat:@"%lu %d %d", (unsigned long)revenant_begun, expired, onMain]);
    revenant_check(revenant_ended == 1 && revenant_ended_task == 7, "the task assertion ends when the block returns", [NSString stringWithFormat:@"%lu %lu", (unsigned long)revenant_ended, (unsigned long)revenant_ended_task]);
    dispatch_semaphore_t hold = dispatch_semaphore_create(0);
    dispatch_semaphore_t second = dispatch_semaphore_create(0);
    __block int calls = 0;
    __block BOOL lastExpired = NO;
    revenant_perform(@"long", ^(BOOL value) {
        calls++;
        lastExpired = value;
        if (!value)
            dispatch_semaphore_wait(hold, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC));
        else
            dispatch_semaphore_signal(second);
    });
    usleep(200000);
    revenant_expiration();
    dispatch_semaphore_wait(second, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    dispatch_semaphore_signal(hold);
    usleep(200000);
    revenant_check(calls == (revenant_negative ? 3 : 2) && lastExpired, "an expiring assertion calls the block again with expired YES", [NSString stringWithFormat:@"%d %d", calls, lastExpired]);
    revenant_check(revenant_ended == 2, "the expired activity ends its assertion once", [NSString stringWithFormat:@"%lu", (unsigned long)revenant_ended]);
    return revenant_finish();
}
