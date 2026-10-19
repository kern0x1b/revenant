#import <Foundation/Foundation.h>
#include <dlfcn.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "check.h"

static NSString *image_of(const void *address)
{
    Dl_info info;
    return dladdr(address, &info) ? @(info.dli_fname).lastPathComponent : @"?";
}

static NSString *raised(void (^block)(void))
{
    @try {
        block();
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
    }
    return @"nothing";
}

static void spin(NSTimeInterval seconds)
{
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
}

static id (*send_object)(id, SEL, id) = (id (*)(id, SEL, id))objc_msgSend;

int main(void)
{
    @autoreleasepool {
        NSArray *carried = @[@[[NSTimer class], @"timerWithTimeInterval:repeats:block:", @YES],
                             @[[NSTimer class], @"scheduledTimerWithTimeInterval:repeats:block:", @YES],
                             @[[NSTimer class], @"initWithFireDate:interval:repeats:block:", @NO],
                             @[[NSThread class], @"initWithBlock:", @NO],
                             @[[NSThread class], @"detachNewThreadWithBlock:", @YES],
                             @[[NSRunLoop class], @"performBlock:", @NO],
                             @[[NSRunLoop class], @"performInModes:block:", @NO],
                             @[[NSFileManager class], @"temporaryDirectory", @NO]];
        for (NSArray *entry in carried) {
            Class cls = entry[0];
            SEL name = NSSelectorFromString(entry[1]);
            Method method = [entry[2] boolValue] ? class_getClassMethod(cls, name) : class_getInstanceMethod(cls, name);
            CHECK_EQUAL(image_of(method ? (const void *)method_getImplementation(method) : NULL), @"libFoundationBackports.dylib",
                        ([[NSString stringWithFormat:@"%@ %@ comes from the backports library", cls, entry[1]] UTF8String]));
        }

        __block int runs = 0;
        __block BOOL sameTimer = NO;
        __block NSTimer *made = nil;
        made = [NSTimer timerWithTimeInterval:0.05 repeats:NO block:^(NSTimer *timer) {
            runs++;
            sameTimer = timer == made;
        }];
        spin(0.3);
        int before = runs;
        [[NSRunLoop currentRunLoop] addTimer:made forMode:NSDefaultRunLoopMode];
        spin(0.4);
        CHECK(before == 0 && runs == 1 && sameTimer && !made.isValid && made.timeInterval == 0,
              "a timer made with a block runs once when it is put on a run loop, with itself as the argument, and is then invalid");

        __block int repeats = 0;
        NSTimer *scheduled = [NSTimer scheduledTimerWithTimeInterval:0.05 repeats:YES block:^(NSTimer *timer) {
            repeats++;
        }];
        spin(0.5);
        int atInvalidate = repeats;
        [scheduled invalidate];
        spin(0.3);
        CHECK(atInvalidate >= 4 && repeats == atInvalidate && !scheduled.isValid && scheduled.timeInterval == 0.05,
              "a scheduled timer repeats on the current run loop until it is invalidated");

        __block int single = 0;
        NSTimer *once = [NSTimer scheduledTimerWithTimeInterval:0.05 repeats:NO block:^(NSTimer *timer) {
            single++;
        }];
        spin(0.4);
        CHECK(single == 1 && !once.isValid, "a scheduled timer that does not repeat runs once");

        NSDate *date = [NSDate dateWithTimeIntervalSinceNow:0.3];
        __weak id captured;
        NSTimer *initialized;
        @autoreleasepool {
            id object = [NSObject new];
            captured = object;
            initialized = [[NSTimer alloc] initWithFireDate:date interval:0.1 repeats:YES block:^(NSTimer *timer) {
                (void)object;
            }];
        }
        BOOL held = captured != nil;
        CHECK(fabs([initialized.fireDate timeIntervalSinceDate:date]) < 0.001 && initialized.timeInterval == 0.1 && initialized.isValid && held,
              "a timer made from a date keeps the date and the interval, and holds its block");
        [initialized invalidate];
        initialized = nil;
        spin(0.05);
        CHECK(captured == nil, "and lets the block go when it is invalidated");

        __block BOOL ran = NO, onMain = YES;
        dispatch_semaphore_t done = dispatch_semaphore_create(0);
        NSThread *thread = send_object([NSThread alloc], @selector(initWithBlock:), ^{
            ran = YES;
            onMain = [NSThread isMainThread];
            dispatch_semaphore_signal(done);
        });
        BOOL beforeStart = ran;
        [thread start];
        BOOL finished = dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC)) == 0;
        CHECK(!beforeStart && finished && ran && !onMain, "a thread made from a block runs it on another thread once it is started");

        __block BOOL detachedRan = NO, detachedOnMain = YES;
        __weak id detachedCaptured;
        dispatch_semaphore_t detachedDone = dispatch_semaphore_create(0);
        @autoreleasepool {
            id object = [NSObject new];
            detachedCaptured = object;
            [NSThread detachNewThreadWithBlock:^{
                (void)object;
                detachedRan = YES;
                detachedOnMain = [NSThread isMainThread];
                dispatch_semaphore_signal(detachedDone);
            }];
        }
        BOOL detachedFinished = dispatch_semaphore_wait(detachedDone, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC)) == 0;
        spin(0.4);
        CHECK(detachedFinished && detachedRan && !detachedOnMain && detachedCaptured == nil,
              "a detached thread runs the block off the main thread and lets it go when the thread ends");

        CHECK_EQUAL(raised(^{ (void)send_object([NSThread alloc], @selector(initWithBlock:), nil); }),
                    @"NSInvalidArgumentException: *** -[NSThread initWithBlock:]: block targets for threads cannot be nil",
                    "a thread with no block raises");
        CHECK_EQUAL(raised(^{ send_object([NSThread class], @selector(detachNewThreadWithBlock:), nil); }),
                    @"NSInvalidArgumentException: *** +[NSThread detachNewThreadWithBlock:]: block targets for threads cannot be nil",
                    "a detached thread with no block raises");

        NSRunLoop *loop = [NSRunLoop currentRunLoop];
        __block int loopRuns = 0;
        __block BOOL loopOnMain = NO;
        [loop performBlock:^{
            loopRuns++;
            loopOnMain = [NSThread isMainThread];
        }];
        int loopBefore = loopRuns;
        spin(0.2);
        CHECK(loopBefore == 0 && loopRuns == 1 && loopOnMain, "a block for the run loop waits until the loop runs, then runs once on it");

        __block int inModes = 0;
        [loop performInModes:@[@"CharonProbeMode"] block:^{
            inModes++;
        }];
        spin(0.2);
        int inDefault = inModes;
        [loop addPort:[NSMachPort port] forMode:@"CharonProbeMode"];
        [loop runMode:@"CharonProbeMode" beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.3]];
        int inOwnMode = inModes;
        [loop performInModes:@[NSDefaultRunLoopMode, @"CharonProbeMode"] block:^{
            inModes++;
        }];
        spin(0.2);
        CHECK(inDefault == 0 && inOwnMode == 1 && inModes == 2, "a block for chosen modes runs when one of them runs, and only then");

        __block BOOL woken = NO;
        __block NSTimeInterval wokenAfter = 99;
        NSDate *start = [NSDate date];
        [loop addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC), dispatch_get_global_queue(0, 0), ^{
            [loop performBlock:^{
                woken = YES;
                wokenAfter = -[start timeIntervalSinceNow];
            }];
        });
        [loop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:3]];
        CHECK(woken && wokenAfter < 1, "a block put on a run loop from another thread wakes it at once");

        void (*perform)(id, SEL, id, id) = (void (*)(id, SEL, id, id))objc_msgSend;
        void (^nothing)(void) = ^{};
        CHECK_EQUAL(raised(^{ perform(loop, @selector(performInModes:block:), @[NSDefaultRunLoopMode], nil); }),
                    @"NSInvalidArgumentException: *** -[NSRunLoop performInModes:block:]: block targets for run loops cannot be nil",
                    "a run loop block with no block raises");
        CHECK_EQUAL(raised(^{ perform(loop, @selector(performInModes:block:), nil, nothing); }),
                    @"NSInvalidArgumentException: *** -[NSRunLoop performInModes:block:]: modes for block performers on run loops cannot be nil or contain no elements",
                    "and with no modes raises");
        CHECK_EQUAL(raised(^{ perform(loop, @selector(performInModes:block:), @[], nothing); }),
                    @"NSInvalidArgumentException: *** -[NSRunLoop performInModes:block:]: modes for block performers on run loops cannot be nil or contain no elements",
                    "and with an empty list of modes raises the same");
        CHECK_EQUAL(raised(^{ perform(loop, @selector(performInModes:block:), nil, nil); }),
                    @"NSInvalidArgumentException: *** -[NSRunLoop performInModes:block:]: block targets for run loops cannot be nil",
                    "and with neither, the block is what it names");
        CHECK_EQUAL(raised(^{ send_object(loop, @selector(performBlock:), nil); }),
                    @"NSInvalidArgumentException: *** -[NSRunLoop performInModes:block:]: block targets for run loops cannot be nil",
                    "-performBlock: with no block names -performInModes:block:");

        NSURL *temporary = [[NSFileManager defaultManager] temporaryDirectory];
        NSString *expected = [NSTemporaryDirectory() stringByStandardizingPath];
        CHECK(temporary.isFileURL && [temporary.path isEqual:expected] && [temporary.absoluteString hasSuffix:@"/"],
              "the temporary directory is a file URL of NSTemporaryDirectory(), with a slash at its end");

        printf("%d checks, %d failures\n", charon_checks, charon_failures);
        return charon_failures;
    }
}
