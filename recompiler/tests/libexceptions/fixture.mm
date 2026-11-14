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

__attribute__((noinline)) static int risky(int value)
{
    if (value % 3 == 0) {
        @throw [NSException exceptionWithName:@"SwitchError" reason:@"raised by a case" userInfo:nil];
    }
    return value * 7 + 1;
}

#define BRANCH(n) \
    case n: \
        @try { \
            Guard inner(&destroyed); \
            result = risky(value + n); \
        } @catch (NSException *first) { \
            @try { \
                result = -risky(value + n + 3); \
            } @catch (NSException *second) { \
                if (n % 4 == 0) { \
                    @throw; \
                } \
                result = -n; \
            } \
        } \
        break;

__attribute__((noinline)) static int branch(int kind, int value)
{
    Guard guard(&destroyed);
    int result = 0;
    switch (kind) {
        BRANCH(0) BRANCH(1) BRANCH(2) BRANCH(3) BRANCH(4) BRANCH(5) BRANCH(6) BRANCH(7) BRANCH(8) BRANCH(9) BRANCH(10) BRANCH(11)
        default:
            result = value;
            break;
    }
    @try {
        Guard tail(&destroyed);
        result += risky(value * 3 + kind);
    } @catch (NSException *error) {
        result += 1000;
    }
    if (result % 7 == 0) {
        @throw [NSException exceptionWithName:@"SwitchEscape" reason:@"raised after the table" userInfo:nil];
    }
    return result;
}

struct Reference {
    int result;
    bool escaped;
    int destroyed;
};

static Reference branch_reference(int kind, int value)
{
    Reference reference = {0, false, 1};
    if (kind >= 0 && kind < 12) {
        ++reference.destroyed;
        int sum = value + kind;
        if (sum % 3 != 0) {
            reference.result = sum * 7 + 1;
        } else if (kind % 4 == 0) {
            reference.escaped = true;
            return reference;
        } else {
            reference.result = -kind;
        }
    } else {
        reference.result = value;
    }
    ++reference.destroyed;
    int tail = value * 3 + kind;
    reference.result += tail % 3 != 0 ? tail * 7 + 1 : 1000;
    if (reference.result % 7 == 0) {
        reference.escaped = true;
    }
    return reference;
}

__attribute__((noinline)) static int tail_leaf(int value)
{
    Guard guard(&destroyed);
    if (value % 5 == 0) {
        @throw [NSException exceptionWithName:@"TailError" reason:@"raised after two tail jumps" userInfo:nil];
    }
    return value * 3 + 1;
}

__attribute__((noinline)) static int tail_middle(int value)
{
    int result = 0;
    @try {
        Guard inner(&destroyed);
        result = risky(value);
    } @catch (NSException *error) {
        result = -1;
    }
    [[clang::musttail]] return tail_leaf(value + result);
}

__attribute__((noinline)) static int tail_first(int value)
{
    @try {
        Guard inner(&destroyed);
        if (value % 2 == 0) {
            risky(value * 3 + value % 4);
        }
    } @catch (NSException *error) {
        value += 1;
    }
    [[clang::musttail]] return tail_middle(value);
}

static Reference tail_reference(int value)
{
    Reference reference = {0, false, 2};
    if (value % 2 == 0 && (value * 3 + value % 4) % 3 == 0) {
        value += 1;
    }
    int result = value % 3 == 0 ? -1 : value * 7 + 1;
    ++reference.destroyed;
    value += result;
    if (value % 5 == 0) {
        reference.escaped = true;
    } else {
        reference.result = value * 3 + 1;
    }
    return reference;
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

- (void)stepSwitch
{
    int sum = 0, expected = 0, escaped = 0, expected_escaped = 0, expected_destroyed = 0;
    destroyed = 0;
    for (int kind = 0; kind < 14; kind++) {
        for (int value = 0; value < 9; value++) {
            Reference reference = branch_reference(kind, value);
            expected_destroyed += reference.destroyed;
            if (reference.escaped) {
                ++expected_escaped;
                expected += 1;
            } else {
                expected += reference.result;
            }
            @try {
                sum += branch(kind, value);
            } @catch (NSException *error) {
                ++escaped;
                sum += 1;
            }
        }
    }
    report("switch.sum", sum == expected);
    report("switch.escaped", escaped == expected_escaped && escaped > 0);
    report("switch.destructors", destroyed == expected_destroyed);
}

- (void)stepTail
{
    int sum = 0, expected = 0, escaped = 0, expected_escaped = 0, expected_destroyed = 0;
    destroyed = 0;
    for (int value = 0; value < 60; value++) {
        Reference reference = tail_reference(value);
        expected_destroyed += reference.destroyed;
        if (reference.escaped) {
            ++expected_escaped;
            expected += 1;
        } else {
            expected += reference.result;
        }
        @try {
            sum += tail_first(value);
        } @catch (NSException *error) {
            ++escaped;
            sum += 1;
        }
    }
    report("tail.sum", sum == expected);
    report("tail.escaped", escaped == expected_escaped && escaped > 0);
    report("tail.destructors", destroyed == expected_destroyed);
}

- (void)stepFrame
{
    report("frame.stack", frame(3) == frame(3) && frame(3) == 25);
}

@end
