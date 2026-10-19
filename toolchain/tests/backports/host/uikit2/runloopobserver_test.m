#import <Foundation/Foundation.h>
#import "check.h"

CFRunLoopObserverRef RevenantHostCFRunLoopObserverCreateWithHandler(CFAllocatorRef allocator, CFOptionFlags activities, Boolean repeats, CFIndex order,
                                                                  void (^block)(CFRunLoopObserverRef observer, CFRunLoopActivity activity));

typedef CFRunLoopObserverRef (*revenant_maker)(CFAllocatorRef, CFOptionFlags, Boolean, CFIndex, void (^)(CFRunLoopObserverRef, CFRunLoopActivity));

@interface RevenantProbe : NSObject
@end

@implementation RevenantProbe
@end

static NSDictionary *observe(revenant_maker make, CFOptionFlags activities, Boolean repeats, CFIndex order)
{
    NSMutableArray *seen = [NSMutableArray array];
    __weak RevenantProbe *weakProbe;
    __block CFRunLoopObserverRef given = NULL;
    BOOL sameObserver = YES;
    CFRunLoopObserverRef observer;
    @autoreleasepool {
        RevenantProbe *probe = [RevenantProbe new];
        weakProbe = probe;
        observer = make(NULL, activities, repeats, order, ^(CFRunLoopObserverRef which, CFRunLoopActivity activity) {
            (void)probe;
            given = which;
            [seen addObject:@(activity)];
        });
    }
    CFRunLoopAddObserver(CFRunLoopGetCurrent(), observer, kCFRunLoopDefaultMode);
    for (int turn = 0; turn < 3; turn++) {
        [NSTimer scheduledTimerWithTimeInterval:0.01 repeats:NO block:^(NSTimer *timer) {}];
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.05, true);
    }
    sameObserver = given == NULL || given == observer;
    NSDictionary *answer = @{@"seen": seen, @"valid": @(CFRunLoopObserverIsValid(observer)), @"activities": @(CFRunLoopObserverGetActivities(observer)),
                             @"repeats": @(CFRunLoopObserverDoesRepeat(observer)), @"order": @(CFRunLoopObserverGetOrder(observer)),
                             @"sameObserver": @(sameObserver), @"aliveWhileHeld": @(weakProbe != nil)};
    CFRunLoopObserverInvalidate(observer);
    CFRelease(observer);
    NSMutableDictionary *result = [answer mutableCopy];
    result[@"aliveAfterRelease"] = @(weakProbe != nil);
    return result;
}

int main(void)
{
    @autoreleasepool {
        struct { CFOptionFlags activities; Boolean repeats; CFIndex order; } cases[] = {
            {kCFRunLoopBeforeWaiting | kCFRunLoopAfterWaiting, true, 0},
            {kCFRunLoopAllActivities, true, 7},
            {kCFRunLoopBeforeTimers, false, -3},
            {kCFRunLoopEntry | kCFRunLoopExit, false, 0},
        };
        for (size_t index = 0; index < sizeof cases / sizeof cases[0]; index++) {
            NSDictionary *system = observe(CFRunLoopObserverCreateWithHandler, cases[index].activities, cases[index].repeats, cases[index].order);
            NSDictionary *ours = observe(RevenantHostCFRunLoopObserverCreateWithHandler, cases[index].activities, cases[index].repeats, cases[index].order);
            revenant_check([system isEqual:ours], "an observer made from a block behaves as the system's",
                         [NSString stringWithFormat:@"case %zu: ours %@ system %@", index, ours, system]);
            revenant_check([system[@"seen"] count] > 0, "the loop ran the observer at all", [NSString stringWithFormat:@"case %zu", index]);
        }
        printf("checks=%d failures=%d\n", revenant_checks, revenant_failures);
        return revenant_failures ? 1 : 0;
    }
}
