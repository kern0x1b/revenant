#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <string.h>
#import "check.h"

static const NSInteger kShort = 1, kMedium = 2, kLong = 3;

static BOOL has_class(const char *name)
{
    return NSClassFromString([NSString stringWithUTF8String:name]) != Nil;
}

static id revenant_invoke(id target, SEL selector, double *value, NSInteger *which, BOOL wantId)
{
    NSMethodSignature *signature = [target methodSignatureForSelector:selector];
    if (!signature)
        return nil;
    NSInvocation *call = [NSInvocation invocationWithMethodSignature:signature];
    call.selector = selector;
    call.target = target;
    if (value)
        [call setArgument:value atIndex:2];
    if (which)
        [call setArgument:which atIndex:3];
    [call invoke];
    if (!wantId)
        return nil;
    id result = nil;
    [call getReturnValue:&result];
    return result;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        revenant_log_to(argc > 1 ? [NSString stringWithUTF8String:argv[1]] : nil);

        NSLocale *locale = [NSLocale currentLocale];
        NSString *system = [[locale objectForKey:NSLocaleMeasurementSystem] description];
        CHECK(system != nil, "the release's locale answers which system of units it uses");
        CHECK([system isEqualToString:@"U.S."] || [system isEqualToString:@"U.K."] || [system isEqualToString:@"Metric"],
              "and one of the three the port carries");
        CHECK([[locale objectForKey:NSLocaleLanguageCode] length] > 0, "the locale has a language");

        NSArray *names = @[@"NSLengthFormatter", @"NSMassFormatter", @"NSEnergyFormatter"];
        for (NSString *name in names) {
            Class formatter = NSClassFromString(name);
            CHECK(formatter != Nil, "the class is there");
            if (!formatter)
                continue;
            CHECK([formatter instancesRespondToSelector:@selector(numberFormatter)], "it has a number formatter");
            CHECK([formatter instancesRespondToSelector:@selector(unitStyle)], "it has a unit style");
            CHECK([formatter instancesRespondToSelector:@selector(getObjectValue:forString:errorDescription:)], "it has the parse");
            for (NSNumber *style in @[@(kShort), @(kMedium), @(kLong)]) {
                id fresh = [[formatter alloc] init];
                [fresh setValue:style forKey:@"unitStyle"];
                CHECK([[fresh valueForKey:@"unitStyle"] integerValue] == [style integerValue], "the unit style takes what was set");
                CHECK([fresh valueForKey:@"numberFormatter"] != nil, "the number formatter is one of the release's own");
                for (NSString *flag in @[@"forPersonHeightUse", @"forPersonMassUse", @"forFoodEnergyUse"]) {
                    SEL setter = NSSelectorFromString([@"set" stringByAppendingString:[flag substringToIndex:1].uppercaseString]);
                    if (![formatter instancesRespondToSelector:setter]) continue;
                    [fresh setValue:@YES forKey:flag];
                    CHECK([[fresh valueForKey:flag] boolValue], "the flag takes what was set");
                    [fresh setValue:@NO forKey:flag];
                    CHECK(![[fresh valueForKey:flag] boolValue], "and the other value");
                }
                NSArray *units = nil;
                if ([name isEqualToString:@"NSLengthFormatter"]) {
                    units = @[@(8), @(9), @(11), @(14), @(1281), @(1282), @(1283), @(1284)];
                } else if ([name isEqualToString:@"NSMassFormatter"]) {
                    units = @[@(11), @(14), @(1537), @(1538), @(1539)];
                } else {
                    units = @[@(11), @(14), @(1793), @(1794)];
                }
                for (NSNumber *unit in units) {
                    for (NSNumber *value in @[@1, @0, @(-1), @2.5]) {
                        double scalar = value.doubleValue;
                        NSInteger which = unit.integerValue;
                        id written = revenant_invoke(fresh, NSSelectorFromString(@"stringFromValue:unit:"), &scalar, &which, YES);
                        id named = revenant_invoke(fresh, NSSelectorFromString(@"unitStringFromValue:unit:"), &scalar, &which, YES);
                        CHECK([written isKindOfClass:[NSString class]] && [written length] > 0, "a value and a unit write something");
                        CHECK([named isKindOfClass:[NSString class]] && [named length] > 0, "and name something");
                        CHECK(![named hasSuffix:@"_UNKNOWN"] && ![named isEqualToString:@"(null)"],
                              "and it is a name of the dimension, not the answer for a unit outside it");
                    }
                }
                SEL scaled = [name isEqualToString:@"NSLengthFormatter"] ? NSSelectorFromString(@"stringFromMeters:")
                           : [name isEqualToString:@"NSMassFormatter"] ? NSSelectorFromString(@"stringFromKilograms:")
                                                                         : NSSelectorFromString(@"stringFromJoules:");
                SEL withUnit = [name isEqualToString:@"NSLengthFormatter"] ? NSSelectorFromString(@"unitStringFromMeters:usedUnit:")
                             : [name isEqualToString:@"NSMassFormatter"] ? NSSelectorFromString(@"unitStringFromKilograms:usedUnit:")
                                                                           : NSSelectorFromString(@"unitStringFromJoules:usedUnit:");
                double scales[] = {0, 0.0001, 0.5, 1, 1.5, 100, 1000, 100000, -1, -1000};
                for (unsigned index = 0; index < sizeof(scales) / sizeof(*scales); index++) {
                    double value = scales[index];
                    double scalar = value;
                    id form = revenant_invoke(fresh, scaled, &scalar, NULL, YES);
                    NSInteger reported = -1;
                    NSMethodSignature *signature = [formatter instanceMethodSignatureForSelector:withUnit];
                    NSInvocation *call = [NSInvocation invocationWithMethodSignature:signature];
                    call.selector = withUnit;
                    call.target = fresh;
                    [call setArgument:&value atIndex:2];
                    [call setArgument:&reported atIndex:3];
                    [call invoke];
                    NSString *named = nil;
                    [call getReturnValue:&named];
                    CHECK([form isKindOfClass:[NSString class]] && [form length] > 0, "a value writes something");
                    CHECK([named isKindOfClass:[NSString class]] && [named length] > 0, "and names a unit");
                    CHECK(reported != -1, "and reports which unit");
                    if ([name isEqualToString:@"NSMassFormatter"] && reported == 1539)
                        CHECK([form rangeOfString:@","].location != NSNotFound || [form rangeOfString:@" "].location != NSNotFound
                                  || [form rangeOfString:@"st"].location != NSNotFound, "a stone is written in stones");
                    if ([name isEqualToString:@"NSLengthFormatter"]) {
                        BOOL person = [[fresh valueForKey:@"forPersonHeightUse"] boolValue];
                        if (person)
                            CHECK([form length] > 0, "a person's height writes something");
                    }
                }
                for (NSString *text in @[@"", @"1", @"1.5 km", @"nonsense"]) {
                    id object = @"untouched";
                    NSString *why = @"untouched";
                    SEL parse = NSSelectorFromString(@"getObjectValue:forString:errorDescription:");
                    NSMethodSignature *signature = [formatter instanceMethodSignatureForSelector:parse];
                    NSInvocation *call = [NSInvocation invocationWithMethodSignature:signature];
                    call.selector = parse;
                    call.target = fresh;
                    [call setArgument:&object atIndex:2];
                    [call setArgument:&text atIndex:3];
                    [call setArgument:&why atIndex:4];
                    [call invoke];
                    BOOL answered = NO;
                    [call getReturnValue:&answered];
                    CHECK(!answered, "the parse answers NO");
                    CHECK(object == nil, "and writes no object");
                    CHECK(why == nil, "and no reason");
                }
                [fresh setValue:@(kLong) forKey:@"unitStyle"];
                id copy = [fresh copy];
                CHECK(copy != nil && [[copy valueForKey:@"unitStyle"] integerValue] == kLong, "a copy keeps the unit style");
            }
        }

        CHECK(has_class("NSUnit"), "the release has NSUnit where the port carries it");
        if (has_class("NSUnit") && has_class("NSMeasurement")) {
            id a = [NSClassFromString(@"NSUnitLength") performSelector:NSSelectorFromString(@"meters")];
            id b = [NSClassFromString(@"NSUnitLength") performSelector:NSSelectorFromString(@"kilometers")];
            SEL can = NSSelectorFromString(@"canBeConvertedToUnit:");
            CHECK(a != nil && b != nil, "the unit class answers its own units");
            if (a && b)
                CHECK([a canBeConvertedToUnit:b], "and converts between them");
        }

        printf("checks=%d failures=%d\n", revenant_checks, revenant_failures);
        return revenant_failures;
    }
}
