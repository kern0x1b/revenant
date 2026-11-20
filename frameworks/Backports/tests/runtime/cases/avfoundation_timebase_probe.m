#import "../app/revenant_check.h"
#import <CoreMedia/CoreMedia.h>
#import <dlfcn.h>

typedef const void *NotificationCenter;
typedef void (*NotificationCallback)(NotificationCenter, const void *, CFStringRef, const void *, CFTypeRef);
typedef NotificationCenter (*GetCenterFunction)(void);
typedef OSStatus (*AddListenerFunction)(NotificationCenter, const void *, NotificationCallback, CFStringRef, const void *, UInt32);
typedef OSStatus (*RemoveListenerFunction)(NotificationCenter, const void *, NotificationCallback, CFStringRef, const void *);

static void spin(NSTimeInterval seconds)
{
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
}

static void listener(NotificationCenter center, const void *observer, CFStringRef name, const void *object, CFTypeRef payload)
{
    int *count = (int *)observer;
    (*count)++;
}

@interface TimebaseProbe : NSObject {
@public
    CMTimebaseRef timebase;
    dispatch_queue_t queue;
    dispatch_source_t source;
    volatile int fired;
}
@end

@implementation TimebaseProbe

- (instancetype)init
{
    self = [super init];
    CMTimebaseCreateWithMasterClock(kCFAllocatorDefault, CMClockGetHostTimeClock(), &timebase);
    queue = dispatch_queue_create("revenant.timebase.probe", DISPATCH_QUEUE_SERIAL);
    source = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    __unsafe_unretained TimebaseProbe *unretained = self;
    dispatch_source_set_event_handler(source, ^{
        unretained->fired++;
    });
    dispatch_resume(source);
    CMTimebaseAddTimerDispatchSource(timebase, source);
    return self;
}

- (void)finish
{
    CMTimebaseSetTimerDispatchSourceNextFireTime(timebase, source, kCMTimeInvalid, 0);
    CMTimebaseRemoveTimerDispatchSource(timebase, source);
    dispatch_source_cancel(source);
    CFRelease(timebase);
}

@end

REVENANT_CASE(avfoundation_timebase_probe)
{
    BOOL flip = (BOOL)negative;
    TimebaseProbe *probe = [[TimebaseProbe alloc] init];
    revenant_expect_true(@"a timebase made on the host clock is stopped",
                         (CMTimebaseGetRate(probe->timebase) == 0.0 && CMTimebaseGetEffectiveRate(probe->timebase) == 0.0) != flip,
                         [NSString stringWithFormat:@"rate %.2f", CMTimebaseGetRate(probe->timebase)]);
    CMTimebaseSetTimerDispatchSourceNextFireTime(probe->timebase, probe->source, CMTimeMake(2, 1), 0);
    CMTimebaseSetTime(probe->timebase, CMTimeMake(2, 1));
    spin(1.5);
    revenant_expect_true(@"a timer does not fire when a stopped timebase is set to its fire time on iOS 6.1.3",
                         (probe->fired == 0) != flip, [NSString stringWithFormat:@"fired %d", probe->fired]);
    [probe finish];

    probe = [[TimebaseProbe alloc] init];
    CMTimebaseSetTime(probe->timebase, CMTimeMake(0, 1));
    CMTimebaseSetTimerDispatchSourceNextFireTime(probe->timebase, probe->source, CMTimeMake(1, 1), 0);
    CMTimebaseSetTime(probe->timebase, CMTimeMake(3, 1));
    spin(1.5);
    revenant_expect_true(@"a timer does not fire when a stopped timebase is set past its fire time on iOS 6.1.3",
                         (probe->fired == 0) != flip, [NSString stringWithFormat:@"fired %d", probe->fired]);
    [probe finish];

    probe = [[TimebaseProbe alloc] init];
    CMTimebaseSetTime(probe->timebase, CMTimeMake(0, 1));
    CMTimebaseSetTimerDispatchSourceNextFireTime(probe->timebase, probe->source, CMTimeMake(4, 10), 0);
    CMTimebaseSetRate(probe->timebase, 1.0);
    spin(1.5);
    revenant_expect_true(@"a timer fires once when a running timebase reaches its fire time",
                         (probe->fired == 1) != flip, [NSString stringWithFormat:@"fired %d", probe->fired]);
    [probe finish];

    probe = [[TimebaseProbe alloc] init];
    CMTimebaseSetTimerDispatchSourceToFireImmediately(probe->timebase, probe->source);
    spin(0.5);
    revenant_expect_true(@"a timer set to fire immediately fires on a stopped timebase",
                         (probe->fired == 1) != flip, [NSString stringWithFormat:@"fired %d", probe->fired]);
    [probe finish];

    probe = [[TimebaseProbe alloc] init];
    int jumps = 0;
    GetCenterFunction getCenter = (GetCenterFunction)dlsym(RTLD_DEFAULT, "CMNotificationCenterGetDefaultLocalCenter");
    AddListenerFunction addListener = (AddListenerFunction)dlsym(RTLD_DEFAULT, "CMNotificationCenterAddListener");
    RemoveListenerFunction removeListener = (RemoveListenerFunction)dlsym(RTLD_DEFAULT, "CMNotificationCenterRemoveListener");
    NotificationCenter center = getCenter ? getCenter() : NULL;
    OSStatus added = addListener ? addListener(center, &jumps, listener, kCMTimebaseNotification_TimeJumped, probe->timebase, 0) : -1;
    CMTimebaseSetTime(probe->timebase, CMTimeMake(5, 1));
    spin(1.0);
    int afterFirst = jumps;
    CMTimebaseSetTime(probe->timebase, CMTimeMake(6, 1));
    spin(0.5);
    revenant_expect_true(@"kCMTimebaseNotification_TimeJumped reaches a listener once for each CMTimebaseSetTime",
                         (added == 0 && afterFirst == 1 && jumps == 2) != flip,
                         [NSString stringWithFormat:@"added %d, after the first %d, after the second %d", (int)added, afterFirst, jumps]);
    if (removeListener)
        removeListener(center, &jumps, listener, kCMTimebaseNotification_TimeJumped, probe->timebase);
    [probe finish];
}
