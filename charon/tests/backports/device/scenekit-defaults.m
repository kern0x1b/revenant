// The port's new SceneKit objects against the host's: every property the port carries, read by key-value coding
// through scenekit-defaults-cases.m, must answer what macOS SceneKit answers (scenekit-defaults-expectations.h,
// written by host/scenekit-defaults/refresh.sh). Needs no OpenGL: runs on the emulator as well as on a device.
#import <Foundation/Foundation.h>
#include <math.h>
#import "check.h"
#import "scenekit-defaults-cases.h"

static const char *expectations[][2] = {
#include "scenekit-defaults-expectations.h"
};

// Numbers are printed to six significant digits, and a CGFloat is a float here and a double on the host, so two
// equal values may differ by one in the last printed digit; anything more is a different value.
static BOOL agrees(NSString *actual, NSString *expected)
{
    if ([actual isEqualToString:expected]) {
        return YES;
    }
    NSArray *a = [actual componentsSeparatedByString:@" "];
    NSArray *e = [expected componentsSeparatedByString:@" "];
    if (a.count != e.count) {
        return NO;
    }
    for (NSUInteger i = 0; i < a.count; i++) {
        if ([a[i] isEqualToString:e[i]]) {
            continue;
        }
        NSScanner *actualScanner = [NSScanner scannerWithString:a[i]], *expectedScanner = [NSScanner scannerWithString:e[i]];
        double x, y;
        if (![actualScanner scanDouble:&x] || !actualScanner.isAtEnd || ![expectedScanner scanDouble:&y] || !expectedScanner.isAtEnd) {
            return NO;
        }
        if (y == 0 || fabs(x - y) > pow(10, floor(log10(fabs(y))) - 5) * 1.0000001) {
            return NO;
        }
    }
    return YES;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1) {
            charon_log_to(@(argv[1]));
        }
        NSMutableDictionary *expected = [NSMutableDictionary dictionary];
        for (size_t i = 0; i < sizeof(expectations) / sizeof(*expectations); i++) {
            expected[@(expectations[i][0])] = @(expectations[i][1]);
        }
        NSMutableSet *reached = [NSMutableSet set];
        charon_scenekit_default_cases(^(NSString *name, NSString *value) {
            [reached addObject:name];
            NSString *want = expected[name];
            charon_check(want != nil && agrees(value, want), name.UTF8String,
                         [NSString stringWithFormat:@"port %@, host %@", value, want ?: @"(no expectation)"]);
        });
        charon_check(reached.count == expected.count, "every expectation is reached",
                     [NSString stringWithFormat:@"%lu reached of %lu", (unsigned long)reached.count, (unsigned long)expected.count]);
        printf("%d of %d checks failed\n", charon_failures, charon_checks);
        return charon_failures;
    }
}
