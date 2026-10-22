#import <Foundation/Foundation.h>
#import <objc/message.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const NSUInteger RevenantInvalidTask = (NSUInteger)-1;

@implementation NSProcessInfo (RevenantExpiringActivity82)

- (void)performExpiringActivityWithReason:(NSString *)reason usingBlock:(void (^)(BOOL expired))block
{
    id application = nil;
    Class applicationClass = NSClassFromString(@"UIApplication");
    if (applicationClass)
        application = ((id (*)(id, SEL))objc_msgSend)(applicationClass, @selector(sharedApplication));
    __block NSUInteger task = RevenantInvalidTask;
    __block BOOL finished = NO;
    NSObject *lock = [[NSObject alloc] init];
    void (^end)(void) = ^{
        NSUInteger ending;
        @synchronized (lock) {
            ending = task;
            task = RevenantInvalidTask;
        }
        if (application && ending != RevenantInvalidTask)
            ((void (*)(id, SEL, NSUInteger))objc_msgSend)(application, @selector(endBackgroundTask:), ending);
    };
    if (application) {
        NSUInteger started = ((NSUInteger (*)(id, SEL, void (^)(void)))objc_msgSend)(application, @selector(beginBackgroundTaskWithExpirationHandler:), ^{
            BOOL running;
            @synchronized (lock) {
                running = !finished;
                finished = YES;
            }
            if (running)
                block(YES);
            end();
        });
        @synchronized (lock) {
            task = started;
        }
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        BOOL expiredFirst;
        @synchronized (lock) {
            expiredFirst = finished;
        }
        if (!expiredFirst)
            block(NO);
        @synchronized (lock) {
            finished = YES;
        }
        end();
    });
}

@end
