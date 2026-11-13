#import <Foundation/Foundation.h>
#include <stdio.h>

namespace {

int destroyed;

struct Guard {
    int *counter;
    explicit Guard(int *c) : counter(c) {}
    ~Guard() { ++*counter; }
};

}

@interface XLError : NSException
@end

@implementation XLError
@end

__attribute__((noinline)) static void level(int depth, int mode)
{
    Guard guard(&destroyed);
    if (depth > 0) {
        level(depth - 1, mode);
        return;
    }
    switch (mode) {
        case 0:
            @throw [NSException exceptionWithName:@"GuestError" reason:@"raised by the guest" userInfo:nil];
        case 1: {
            NSArray *array = [NSArray arrayWithObject:@1];
            (void)[array objectAtIndex:5];
            break;
        }
        case 2:
            @throw [[XLError alloc] initWithName:@"XLError" reason:@"raised by the guest" userInfo:nil];
        case 3:
            @throw @"a string";
        default:
            break;
    }
}

__attribute__((noinline)) static NSString *classify(int mode, int *finals)
{
    @try {
        level(3, mode);
        return @"nothing thrown";
    } @catch (XLError *error) {
        return [NSString stringWithFormat:@"XLError %@", [error name]];
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"NSException %@", [exception name]];
    } @catch (id object) {
        return [object isKindOfClass:[NSString class]] ? @"id string" : @"id other";
    } @finally {
        ++*finals;
    }
}

__attribute__((noinline)) static int catch_all(int mode)
{
    Guard guard(&destroyed);
    try {
        level(1, mode);
    } catch (...) {
        return 1;
    }
    return 0;
}

__attribute__((noinline)) static int frame(int seed)
{
    volatile char buffer[20000];
    for (int index = 0; index < 20000; index += 997) {
        buffer[index] = (char)(seed + index);
    }
    int sum = 0;
    for (int index = 0; index < 20000; index += 997) {
        sum += buffer[index];
    }
    return sum;
}

static void report(const char *name, bool ok)
{
    printf("%s %s\n", ok ? "ok" : "FAIL", name);
}

@interface LibExceptions : NSObject
@end

@implementation LibExceptions

- (void)stepGuest
{
    int finals = 0;
    destroyed = 0;
    NSString *text = classify(0, &finals);
    report("guest.throw", [text isEqualToString:@"NSException GuestError"]);
    report("guest.destructors", destroyed == 4);
    report("guest.finally", finals == 1);
}

- (void)stepHost
{
    int finals = 0;
    destroyed = 0;
    NSString *text = classify(1, &finals);
    report("host.throw", [text isEqualToString:@"NSException NSRangeException"]);
    report("host.destructors", destroyed == 4);
    report("host.finally", finals == 1);
}

- (void)stepSubclass
{
    int finals = 0;
    NSString *text = classify(2, &finals);
    report("subclass.throw", [text isEqualToString:@"XLError XLError"]);
    report("subclass.finally", finals == 1);
}

- (void)stepObject
{
    int finals = 0;
    NSString *text = classify(3, &finals);
    report("object.throw", [text isEqualToString:@"id string"]);
    report("object.finally", finals == 1);
}

- (void)stepCatchAll
{
    destroyed = 0;
    int caught = catch_all(0);
    report("catchall.throw", caught == 1);
    report("catchall.destructors", destroyed == 3);
    destroyed = 0;
    report("catchall.none", catch_all(9) == 0 && destroyed == 3);
}

- (void)stepFrame
{
    report("frame.stack", frame(3) == frame(3) && frame(3) == 25);
}

@end
