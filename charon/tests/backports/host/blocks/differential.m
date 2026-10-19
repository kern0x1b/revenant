#import <Foundation/Foundation.h>
#import <objc/message.h>

void host_attach_prefixed(const char *prefix);

static int failures, checks;

static void compare(NSString *name, NSString *system, NSString *ours)
{
    checks++;
    if ([system isEqual:ours]) {
        printf("ok   %s: %s\n", name.UTF8String, system.UTF8String);
        return;
    }
    failures++;
    printf("FAIL %s: the system answers %s, the backport answers %s\n", name.UTF8String, system.UTF8String, ours.UTF8String);
}

static NSString *unprefixed(NSString *text)
{
    text = [text stringByReplacingOccurrencesOfString:@"charonHost_" withString:@""];
    return [text stringByReplacingOccurrencesOfString:@"CharonHost" withString:@""];
}

static NSString *raised(void (^block)(void))
{
    @try {
        block();
    } @catch (NSException *exception) {
        return unprefixed([NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]);
    }
    return @"nothing";
}

static void spin(NSTimeInterval seconds)
{
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
}

static SEL selector(BOOL ours, NSString *plain)
{
    return NSSelectorFromString(ours ? [@"charonHost_" stringByAppendingString:plain] : plain);
}

typedef NSTimer *(*TimerFactory)(id, SEL, NSTimeInterval, BOOL, void (^)(NSTimer *));
typedef NSTimer *(*TimerInit)(id, SEL, NSDate *, NSTimeInterval, BOOL, void (^)(NSTimer *));
typedef void (^TimerBlock)(NSTimer *);

static NSTimer *factory(BOOL ours, BOOL scheduled, NSTimeInterval interval, BOOL repeats, TimerBlock block)
{
    NSString *name = scheduled ? @"scheduledTimerWithTimeInterval:repeats:block:" : @"timerWithTimeInterval:repeats:block:";
    return ((TimerFactory)objc_msgSend)([NSTimer class], selector(ours, name), interval, repeats, block);
}

static NSTimer *initialized(BOOL ours, NSDate *date, NSTimeInterval interval, BOOL repeats, TimerBlock block)
{
    id timer = [NSTimer alloc];
    SEL init = ours ? NSSelectorFromString(@"initCharonHostWithFireDate:interval:repeats:block:")
                    : NSSelectorFromString(@"initWithFireDate:interval:repeats:block:");
    return ((TimerInit)objc_msgSend)(timer, init, date, interval, repeats, block);
}

static NSString *unscheduled_timer(BOOL ours)
{
    __block int runs = 0;
    __block BOOL sameTimer = NO;
    __block NSTimer *made = nil;
    made = factory(ours, NO, 0.05, NO, ^(NSTimer *timer) {
        runs++;
        sameTimer = timer == made;
    });
    spin(0.3);
    int before = runs;
    [[NSRunLoop currentRunLoop] addTimer:made forMode:NSDefaultRunLoopMode];
    spin(0.3);
    return [NSString stringWithFormat:@"before adding %d, after adding %d, argument is the timer %d, valid %d, interval %g, class %@",
                                      before, runs, sameTimer, made.isValid, made.timeInterval, NSStringFromClass([made class])];
}

static NSString *scheduled_timer(BOOL ours)
{
    __block int runs = 0;
    NSTimer *made = factory(ours, YES, 0.05, YES, ^(NSTimer *timer) {
        runs++;
    });
    spin(0.32);
    BOOL repeated = runs >= 4;
    [made invalidate];
    int atInvalidate = runs;
    spin(0.2);
    __block int once = 0;
    NSTimer *single = factory(ours, YES, 0.05, NO, ^(NSTimer *timer) {
        once++;
    });
    spin(0.3);
    return [NSString stringWithFormat:@"repeated %d, stopped %d, valid %d, interval %g, one shot ran %d and is valid %d", repeated,
                                      runs == atInvalidate, made.isValid, made.timeInterval, once, single.isValid];
}

static NSString *initialized_timer(BOOL ours)
{
    NSDate *date = [NSDate dateWithTimeIntervalSinceNow:0.2];
    __weak id captured;
    NSTimer *made;
    @autoreleasepool {
        id object = [NSObject new];
        captured = object;
        made = initialized(ours, date, 0.1, YES, ^(NSTimer *timer) {
            (void)object;
        });
    }
    BOOL heldWhileValid = captured != nil;
    NSString *shape = [NSString stringWithFormat:@"fire date kept %d, interval %g, valid %d, held while valid %d, class %@",
                                                 fabs([made.fireDate timeIntervalSinceDate:date]) < 0.001,
                                                 made.timeInterval, made.isValid, heldWhileValid, NSStringFromClass([made class])];
    [made invalidate];
    made = nil;
    spin(0.05);
    return [shape stringByAppendingFormat:@", released after invalidate %d", captured == nil];
}

static NSString *thread_via_init(BOOL ours)
{
    __block BOOL ran = NO, onMain = YES;
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    id thread = [NSThread alloc];
    void (^block)(void) = ^{
        ran = YES;
        onMain = [NSThread isMainThread];
        dispatch_semaphore_signal(done);
    };
    thread = ours ? ((id (*)(id, SEL, id))objc_msgSend)(thread, NSSelectorFromString(@"initCharonHostWithBlock:"), block)
                  : ((id (*)(id, SEL, id))objc_msgSend)(thread, NSSelectorFromString(@"initWithBlock:"), block);
    BOOL before = ran;
    [thread start];
    BOOL finished = dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC)) == 0;
    return [NSString stringWithFormat:@"ran before start %d, ran %d, on main %d, class %@", before, finished && ran, onMain, NSStringFromClass([thread class])];
}

static NSString *thread_detached(BOOL ours)
{
    __block BOOL ran = NO, onMain = YES;
    __block NSThread *inside = nil;
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    __weak id captured;
    @autoreleasepool {
        id object = [NSObject new];
        captured = object;
        void (^block)(void) = ^{
            (void)object;
            ran = YES;
            onMain = [NSThread isMainThread];
            inside = [NSThread currentThread];
            dispatch_semaphore_signal(done);
        };
        ((void (*)(id, SEL, id))objc_msgSend)([NSThread class], selector(ours, @"detachNewThreadWithBlock:"), block);
    }
    BOOL finished = dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC)) == 0;
    spin(0.3);
    return [NSString stringWithFormat:@"ran %d, on main %d, another thread %d, block released after the thread ends %d", finished && ran, onMain,
                                      inside != nil && inside != [NSThread currentThread], captured == nil];
}

static NSString *run_loop_block(BOOL ours)
{
    __block int runs = 0;
    __block BOOL onMain = NO;
    NSRunLoop *loop = [NSRunLoop currentRunLoop];
    ((void (*)(id, SEL, id))objc_msgSend)(loop, selector(ours, @"performBlock:"), ^{
        runs++;
        onMain = [NSThread isMainThread];
    });
    int before = runs;
    spin(0.1);
    return [NSString stringWithFormat:@"before the loop runs %d, after %d, on main %d", before, runs, onMain];
}

static NSString *run_loop_modes(BOOL ours)
{
    __block int runs = 0;
    NSRunLoop *loop = [NSRunLoop currentRunLoop];
    ((void (*)(id, SEL, id, id))objc_msgSend)(loop, selector(ours, @"performInModes:block:"), @[@"CharonProbeMode"], ^{
        runs++;
    });
    spin(0.1);
    int inDefault = runs;
    [loop addPort:[NSMachPort port] forMode:@"CharonProbeMode"];
    [loop runMode:@"CharonProbeMode" beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
    int inMode = runs;
    ((void (*)(id, SEL, id, id))objc_msgSend)(loop, selector(ours, @"performInModes:block:"), @[NSDefaultRunLoopMode, @"CharonProbeMode"], ^{
        runs++;
    });
    spin(0.1);
    return [NSString stringWithFormat:@"in the default mode %d, in its own mode %d, in two modes %d", inDefault, inMode, runs];
}

static NSString *run_loop_wakeup(BOOL ours)
{
    NSRunLoop *loop = [NSRunLoop currentRunLoop];
    __block BOOL ran = NO;
    __block NSTimeInterval ranAfter = 99;
    NSDate *start = [NSDate date];
    [loop addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC), dispatch_get_global_queue(0, 0), ^{
        ((void (*)(id, SEL, id))objc_msgSend)(loop, selector(ours, @"performBlock:"), ^{
            ran = YES;
            ranAfter = -[start timeIntervalSinceNow];
        });
    });
    [loop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:3]];
    return [NSString stringWithFormat:@"ran %d, woken at once %d", ran, ranAfter < 1];
}

static NSString *temporary(BOOL ours)
{
    NSURL *url = ((id (*)(id, SEL))objc_msgSend)([NSFileManager defaultManager], selector(ours, @"temporaryDirectory"));
    return [NSString stringWithFormat:@"path %@, file URL %d, directory path %d, string ends with a slash %d, class %@", url.path, url.isFileURL,
                                      url.hasDirectoryPath, [url.absoluteString hasSuffix:@"/"], NSStringFromClass([url class])];
}

int main(void)
{
    @autoreleasepool {
        host_attach_prefixed("");
        compare(@"a timer that is not scheduled", unscheduled_timer(NO), unscheduled_timer(YES));
        compare(@"a scheduled timer", scheduled_timer(NO), scheduled_timer(YES));
        compare(@"a timer made from a date", initialized_timer(NO), initialized_timer(YES));
        compare(@"a thread made from a block", thread_via_init(NO), thread_via_init(YES));
        compare(@"a detached thread", thread_detached(NO), thread_detached(YES));
        compare(@"a block on the run loop", run_loop_block(NO), run_loop_block(YES));
        compare(@"a block in chosen modes", run_loop_modes(NO), run_loop_modes(YES));
        compare(@"a block wakes the run loop", run_loop_wakeup(NO), run_loop_wakeup(YES));
        compare(@"the temporary directory", temporary(NO), temporary(YES));

        id (*send)(id, SEL, id) = (id (*)(id, SEL, id))objc_msgSend;
        void (^ignored)(void) = ^{};
        compare(@"a thread with no block", raised(^{ (void)send([NSThread alloc], NSSelectorFromString(@"initWithBlock:"), nil); }),
                raised(^{ (void)send([NSThread alloc], NSSelectorFromString(@"initCharonHostWithBlock:"), nil); }));
        compare(@"a detached thread with no block", raised(^{ send([NSThread class], NSSelectorFromString(@"detachNewThreadWithBlock:"), nil); }),
                raised(^{ send([NSThread class], NSSelectorFromString(@"charonHost_detachNewThreadWithBlock:"), nil); }));
        NSRunLoop *loop = [NSRunLoop currentRunLoop];
        void (*perform)(id, SEL, id, id) = (void (*)(id, SEL, id, id))objc_msgSend;
        for (NSArray *modes in @[[NSNull null], @[], @[NSDefaultRunLoopMode]]) {
            NSArray *given = [modes isKindOfClass:[NSNull class]] ? nil : modes;
            compare([NSString stringWithFormat:@"modes %@, no block", modes],
                    raised(^{ perform(loop, NSSelectorFromString(@"performInModes:block:"), given, nil); }),
                    raised(^{ perform(loop, NSSelectorFromString(@"charonHost_performInModes:block:"), given, nil); }));
        }
        for (NSArray *modes in @[[NSNull null], @[]]) {
            NSArray *given = [modes isKindOfClass:[NSNull class]] ? nil : modes;
            compare([NSString stringWithFormat:@"modes %@, with a block", modes],
                    raised(^{ perform(loop, NSSelectorFromString(@"performInModes:block:"), given, ignored); }),
                    raised(^{ perform(loop, NSSelectorFromString(@"charonHost_performInModes:block:"), given, ignored); }));
        }
        compare(@"a run loop block with no block", raised(^{ send(loop, NSSelectorFromString(@"performBlock:"), nil); }),
                raised(^{ send(loop, NSSelectorFromString(@"charonHost_performBlock:"), nil); }));
        printf("%d checks, %d failures\n", checks, failures);
        return failures;
    }
}
