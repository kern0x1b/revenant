#import <Foundation/Foundation.h>
#import <objc/message.h>

static NSUInteger revenant_awake_count;
static BOOL revenant_awake_saved;
static NSLock *revenant_awake_lock;

static void revenant_on_main(void (^block)(void))
{
    if ([NSThread isMainThread])
        block();
    else
        dispatch_async(dispatch_get_main_queue(), block);
}

static id revenant_application(void)
{
    Class cls = NSClassFromString(@"UIApplication");
    return cls ? ((id (*)(id, SEL))objc_msgSend)(cls, @selector(sharedApplication)) : nil;
}

static void revenant_keep_awake(BOOL keep)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{ revenant_awake_lock = [[NSLock alloc] init]; });
    [revenant_awake_lock lock];
    BOOL first = keep && revenant_awake_count++ == 0;
    BOOL last = !keep && revenant_awake_count > 0 && --revenant_awake_count == 0;
    [revenant_awake_lock unlock];
    if (!first && !last)
        return;
    revenant_on_main(^{
        id application = revenant_application();
        if (!application)
            return;
        if (first) {
            revenant_awake_saved = ((BOOL (*)(id, SEL))objc_msgSend)(application, @selector(isIdleTimerDisabled));
            ((void (*)(id, SEL, BOOL))objc_msgSend)(application, @selector(setIdleTimerDisabled:), YES);
        } else {
            ((void (*)(id, SEL, BOOL))objc_msgSend)(application, @selector(setIdleTimerDisabled:), revenant_awake_saved);
        }
    });
}

@interface RevenantProcessActivity : NSObject
- (instancetype)initWithOptions:(NSActivityOptions)options reason:(NSString *)reason;
- (void)end;
@end

@implementation RevenantProcessActivity {
    NSActivityOptions _options;
    NSString *_reason;
    BOOL _ended;
    BOOL _awake;
    NSUInteger _task;
}

- (instancetype)initWithOptions:(NSActivityOptions)options reason:(NSString *)reason
{
    if ((self = [super init])) {
        _options = options;
        _reason = [reason copy];
        _awake = (options & (NSActivityIdleSystemSleepDisabled | NSActivityIdleDisplaySleepDisabled)) != 0;
        if (_awake)
            revenant_keep_awake(YES);
        if ((options & 0x00FFFFFFULL) == 0x00FFFFFFULL) {
            id application = revenant_application();
            if (application)
                _task = ((NSUInteger (*)(id, SEL, id))objc_msgSend)(application, @selector(beginBackgroundTaskWithExpirationHandler:), nil);
        }
    }
    return self;
}

- (void)end
{
    @synchronized (self) {
        if (_ended) {
            NSLog(@"Warning: NSActivity %@ was ended multiple times", self);
            return;
        }
        _ended = YES;
    }
    if (_awake)
        revenant_keep_awake(NO);
    if (_task) {
        NSUInteger task = _task;
        revenant_on_main(^{ ((void (*)(id, SEL, NSUInteger))objc_msgSend)(revenant_application(), @selector(endBackgroundTask:), task); });
    }
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %p> {options = 0x%llx, reason = %@}", [self class], self, (unsigned long long)_options, _reason];
}

@end

@implementation NSProcessInfo (RevenantActivity)

- (id<NSObject>)beginActivityWithOptions:(NSActivityOptions)options reason:(NSString *)reason
{
    return [[RevenantProcessActivity alloc] initWithOptions:options reason:reason];
}

- (void)endActivity:(id<NSObject>)activity
{
    if ([activity isKindOfClass:[RevenantProcessActivity class]])
        [(RevenantProcessActivity *)activity end];
}

- (void)performActivityWithOptions:(NSActivityOptions)options reason:(NSString *)reason usingBlock:(void (^)(void))block
{
    if (!reason.length)
        [NSException raise:NSInvalidArgumentException format:@"Cannot begin activity without reason string or empty reason string"];
    RevenantProcessActivity *activity = [[RevenantProcessActivity alloc] initWithOptions:options reason:reason];
    block();
    [activity end];
}

@end
