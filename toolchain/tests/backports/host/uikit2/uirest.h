#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <dlfcn.h>
#import "check.h"

#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
#pragma clang diagnostic ignored "-Wnonnull"
#pragma clang diagnostic ignored "-Wincompatible-pointer-types"
#pragma clang diagnostic ignored "-Wundeclared-selector"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

static inline NSString *ur_norm(id object)
{
    NSString *text = [NSString stringWithFormat:@"%@", object];
    text = [text stringByReplacingOccurrencesOfString:@"CharonHost" withString:@""];
    NSRegularExpression *pointer = [NSRegularExpression regularExpressionWithPattern:@"0x[0-9a-f]+" options:0 error:nil];
    return [pointer stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@"PTR"];
}

static inline NSString *ur_raised(id (^block)(void))
{
    @try {
        return [NSString stringWithFormat:@"ok %@", ur_norm(block())];
    } @catch (NSException *exception) {
        NSString *reason = ur_norm(exception.reason);
        if ([exception.name isEqualToString:NSInvalidArgumentException] && [reason rangeOfString:@"unrecognized selector"].location != NSNotFound)
            reason = @"unrecognized selector";
        return [NSString stringWithFormat:@"raised %@ %@", exception.name, reason];
    }
}

static inline NSString *ur_yes(BOOL value)
{
    return value ? @"YES" : @"NO";
}

static inline NSString *ur_line(NSString *label, id value)
{
    return [NSString stringWithFormat:@"%@ %@", label, ur_norm(value)];
}

static inline void ur_agree(NSString *name, NSArray *ours, NSArray *system)
{
    NSMutableString *detail = [NSMutableString string];
    for (NSUInteger index = 0; index < MAX(ours.count, system.count); index++) {
        NSString *a = index < ours.count ? ours[index] : @"<none>", *b = index < system.count ? system[index] : @"<none>";
        if (![a isEqual:b])
            [detail appendFormat:@"\n    port   %@\n    system %@", a, b];
    }
    charon_check(detail.length == 0, name.UTF8String, detail);
}

static inline void ur_spin(BOOL (^done)(void), NSTimeInterval seconds)
{
    NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while (!done() && [limit timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
}
