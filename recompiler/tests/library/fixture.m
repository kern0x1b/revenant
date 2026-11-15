#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "RCFixture.h"
#include <dispatch/dispatch.h>

static NSInteger RCFCreated;

@implementation RCFToken
- (instancetype)initWithValue:(NSInteger)value
{
    self = [super init];
    if (self)
        _value = value;
    return self;
}
@end

@implementation RCFClient {
    NSInteger _seed;
    NSInteger _counter;
}

+ (RCFClient *)clientWithSeed:(NSInteger)seed
{
    RCFClient *client = [[RCFClient alloc] init];
    client->_seed = seed;
    RCFCreated++;
    return client;
}

- (NSInteger)bump
{
    return ++_counter;
}

- (NSInteger)seed
{
    return _seed;
}

- (NSInteger)describedLength
{
    return (NSInteger)[NSString stringWithFormat:@"client-%ld-%ld", (long)_seed, (long)_counter].length;
}

- (NSObject *)hostBundle
{
    return [NSBundle mainBundle];
}

- (RCFToken *)tokenForAction:(NSInteger)action
{
    return [[RCFToken alloc] initWithValue:_seed * 1000 + action * 10 + RCFCreated];
}

- (void)executeWithAction:(NSInteger)action completion:(void (^)(RCFToken *token, NSError *error))completion
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        completion([self tokenForAction:action], nil);
    });
}

- (NSUInteger)threadNumber
{
    return [[NSThread currentThread] isMainThread] ? 1 : 2;
}
@end

@implementation RCFClient (RCFExtra)
- (NSInteger)categoryValue
{
    return [self seed] + 35;
}
@end

@implementation RCFHooked
@end

static objc_hook_getClass RCFOldHook;
static NSInteger RCFHookCalls;

static BOOL RCFClassHook(const char *name, Class *outClass)
{
    RCFHookCalls++;
    if (strcmp(name, "RCFixture.Hooked") == 0) {
        *outClass = [RCFHooked class];
        return YES;
    }
    return RCFOldHook ? RCFOldHook(name, outClass) : NO;
}

static void RCFNote(NSMutableArray *lines, NSString *name, BOOL passed)
{
    [lines addObject:[NSString stringWithFormat:@"%@ %@", passed ? @"ok" : @"FAIL", name]];
}

@implementation RCFHook
+ (NSArray *)run
{
    NSMutableArray *lines = [NSMutableArray array];
    const char *dotted = "RCFixture.Hooked";
    RCFNote(lines, @"hook.absent", objc_getClass(dotted) == Nil && objc_lookUpClass(dotted) == Nil && NSClassFromString(@"RCFixture.Hooked") == Nil);
    objc_setHook_getClass(RCFClassHook, &RCFOldHook);
    Class sink = Nil;
    RCFNote(lines, @"hook.old", RCFOldHook != NULL && !RCFOldHook(dotted, &sink) && sink == Nil);
    Class hooked = [RCFHooked class];
    RCFNote(lines, @"hook.guest", objc_getClass(dotted) == hooked && objc_lookUpClass(dotted) == hooked && NSClassFromString(@"RCFixture.Hooked") == hooked);
    NSInteger asked = RCFHookCalls;
    BOOL exact = objc_getClass("RCFClient") == [RCFClient class] && NSClassFromString(@"RCFHooked") == hooked;
    RCFNote(lines, @"hook.exact", exact && RCFHookCalls == asked);
    RCFNote(lines, @"hook.unknown", objc_getClass("RCFixture.Nothing") == Nil && NSClassFromString(@"RCFixture.Nothing") == Nil && RCFHookCalls == asked + 2);
    return lines;
}
@end
