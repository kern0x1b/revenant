// unitfmt.m - NSLengthFormatter, NSMassFormatter and NSEnergyFormatter on the release the program runs on, through the name an
// application writes. A command-line program: build it as a daemon target that requires charon@apple-backports and run it with
// `xmake emulate -r 4.3|5.0|6.0 run /usr/libexec/unitfmt` (below6/run.sh does both). The three classes arrived in iOS 8.0 and the
// port carries them from 6.0 (registry/Foundation/ios8unitformat.json, `minimum: "6.0"`), so a band below 6.0 leaves them out and
// the program only runs where the port's own classes are the ones linked.
//
// This is a call test, not a differential: it calls every method of the three classes from the 26.2 header and holds to what holds
// on every release the port carries - a written form that is not empty, the unit reported, the names of the three unit styles, the
// two composite forms, the flag of each class, and the documented NO of the parse. It does NOT assert the wording of a form or the
// unit a value is written in, because those come out of the locale's own CLDR data, which no release the port carries has
// (facts/Foundation/NSUnitFormat.md) - they are measured on the host by tests/backports/host/unitformat instead.
//
// What this is for is the part a macOS host differential cannot see at all: the number is written through the *release's* own
// NSNumberFormatter and the system of units is read from the *release's* own locale, so the digits, the grouping, the decimal mark
// and which of the three systems of units a value is written in are the device's, and this is where they are called.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <string.h>
#import "check.h"

// The three unit styles and the three options of iOS 10.0 by their value: the port's headers of the release name none of them
// (the names sit behind an availability the generator's rule (tools/gen/target_availability.lua) lowers), so a program that wants
// them passes the numbers, as an application built for a newer SDK does.
static const NSInteger kShort = 1, kMedium = 2, kLong = 3;

static BOOL has_class(const char *name)
{
    return NSClassFromString([NSString stringWithUTF8String:name]) != Nil;
}

// One call with a double first argument and an NSInteger second, both by address, and an object
// result. The three classes take their scalars that way and nothing else, so this is the only shape
// that reaches the methods rather than a misread pointer.

static id charon_invoke(id target, SEL selector, double *value, NSInteger *which, BOOL wantId)
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
        charon_log_to(argc > 1 ? [NSString stringWithUTF8String:argv[1]] : nil);

        NSLocale *locale = [NSLocale currentLocale];
        NSString *system = [[locale objectForKey:NSLocaleMeasurementSystem] description];
        CHECK(system != nil, "the release's locale answers which system of units it uses");
        CHECK([system isEqualToString:@"U.S."] || [system isEqualToString:@"U.K."] || [system isEqualToString:@"Metric"],
              "and one of the three the port carries");
        CHECK([[locale objectForKey:NSLocaleLanguageCode] length] > 0, "the locale has a language");

        // The three classes, each whole, each of the three styles, with a fresh formatter so nothing carries over.
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
                // The two flags, one per class, and the class's own getter for it.
                for (NSString *flag in @[@"forPersonHeightUse", @"forPersonMassUse", @"forFoodEnergyUse"]) {
                    SEL setter = NSSelectorFromString([@"set" stringByAppendingString:[flag substringToIndex:1].uppercaseString]);
                    if (![formatter instancesRespondToSelector:setter]) continue;
                    [fresh setValue:@YES forKey:flag];
                    CHECK([[fresh valueForKey:flag] boolValue], "the flag takes what was set");
                    [fresh setValue:@NO forKey:flag];
                    CHECK(![[fresh valueForKey:flag] boolValue], "and the other value");
                }
                // -stringFromValue:unit: and -unitStringFromValue:unit: over the class's own unit enumeration, taken by value so the
                // program needs no name of its own.
                NSArray *units = nil;
                if ([name isEqualToString:@"NSLengthFormatter"]) {
                    units = @[@(8), @(9), @(11), @(14), @(1281), @(1282), @(1283), @(1284)];
                } else if ([name isEqualToString:@"NSMassFormatter"]) {
                    units = @[@(11), @(14), @(1537), @(1538), @(1539)];
                } else {
                    units = @[@(11), @(14), @(1793), @(1794)];
                }
                // -stringFromValue:unit: and -unitStringFromValue:unit: take a double and an NSInteger,
                // so they go through an NSInvocation and not through performSelector:, which would hand
                // them the *pointers* of two NSNumbers where the two scalars are expected.
                for (NSNumber *unit in units) {
                    for (NSNumber *value in @[@1, @0, @(-1), @2.5]) {
                        double scalar = value.doubleValue;
                        NSInteger which = unit.integerValue;
                        id written = charon_invoke(fresh, NSSelectorFromString(@"stringFromValue:unit:"), &scalar, &which, YES);
                        id named = charon_invoke(fresh, NSSelectorFromString(@"unitStringFromValue:unit:"), &scalar, &which, YES);
                        CHECK([written isKindOfClass:[NSString class]] && [written length] > 0, "a value and a unit write something");
                        CHECK([named isKindOfClass:[NSString class]] && [named length] > 0, "and name something");
                        // The unit named must be one of the ones the dimension has: a pointer read as a
                        // scalar lands outside the enumeration, and the system answers that with its own
                        // lookup key rather than a name.
                        CHECK(![named hasSuffix:@"_UNKNOWN"] && ![named isEqualToString:@"(null)"],
                              "and it is a name of the dimension, not the answer for a unit outside it");
                    }
                }
                // The three methods that pick a unit, and the unit they report.
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
                    id form = charon_invoke(fresh, scaled, &scalar, NULL, YES);
                    // -unitStringFrom...usedUnit: writes an NSInteger through the pointer, so it goes through an
                    // NSInvocation rather than performSelector:, which would read the pointer as an object.
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
                    // The two composite forms, where the class has one: a stone of mass and a person's height.
                    if ([name isEqualToString:@"NSMassFormatter"] && reported == 1539)
                        CHECK([form rangeOfString:@","].location != NSNotFound || [form rangeOfString:@" "].location != NSNotFound
                                  || [form rangeOfString:@"st"].location != NSNotFound, "a stone is written in stones");
                    if ([name isEqualToString:@"NSLengthFormatter"]) {
                        BOOL person = [[fresh valueForKey:@"forPersonHeightUse"] boolValue];
                        if (person)
                            CHECK([form length] > 0, "a person's height writes something");
                    }
                }
                // -getObjectValue:forString:errorDescription: is documented never to answer anything, and the host writes neither
                // out-parameter. This must be a NO and not a crash.
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
                // A copy and an archive keep the settings, which is what the class's own does.
                [fresh setValue:@(kLong) forKey:@"unitStyle"];
                id copy = [fresh copy];
                CHECK(copy != nil && [[copy valueForKey:@"unitStyle"] integerValue] == kLong, "a copy keeps the unit style");
            }
        }

        // The classes the port's own measurement stack is built on, so a device run says whether the numbers the formatters write
        // can be converted at all.
        CHECK(has_class("NSUnit"), "the release has NSUnit where the port carries it");
        if (has_class("NSUnit") && has_class("NSMeasurement")) {
            id a = [NSClassFromString(@"NSUnitLength") performSelector:NSSelectorFromString(@"meters")];
            id b = [NSClassFromString(@"NSUnitLength") performSelector:NSSelectorFromString(@"kilometers")];
            SEL can = NSSelectorFromString(@"canBeConvertedToUnit:");
            CHECK(a != nil && b != nil, "the unit class answers its own units");
            if (a && b)
                CHECK([a canBeConvertedToUnit:b], "and converts between them");
        }

        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        return charon_failures;
    }
}
