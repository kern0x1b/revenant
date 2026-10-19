// probe.m - what the host RUNTIME does with -[INDateComponentsRange initWithEKRecurrenceRule:] and its getter
// -[INDateComponentsRange EKRecurrenceRule], asked for a set of rule shapes, and with the Intents rules the EventKit
// rule cannot name (minute and hourly).
//
// Every Intents selector is looked up by name at run time, so the framework's header does not decide the answer. The
// answers printed are the ones that do not depend on the clock: which date components are set (the weekday's value
// is printed, the others are only named), the frequency, the interval, the weekday option, which days come back, and
// whether the getter raises and why.
//
//   xcrun clang -fno-objc-arc -framework Foundation -framework Intents -framework EventKit probe.m -o probe   (macOS)
//   xcrun clang -fno-objc-arc -target arm64-apple-ios15.0-macabi -isysroot $(xcrun --show-sdk-path) \
//       -iframework $(xcrun --show-sdk-path)/System/iOSSupport/System/Library/Frameworks \
//       -framework Foundation -framework Intents -framework EventKit probe.m -o probe-catalyst
#import <Foundation/Foundation.h>
#import <EventKit/EventKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <stdio.h>
#include <string.h>

// The port's classes are the same classes with the prefix run.sh renames them to (the port build, -DPORT); the host's
// are the framework's own, with no prefix.
#ifdef PORT
#define PREFIX "CharonHost"
#else
#define PREFIX ""
#endif

static Class charonClass(NSString *name)
{
    return NSClassFromString([NSString stringWithFormat:@"%s%@", PREFIX, name]);
}

// The class's name as Apple's, with the port's prefix taken off, so the two builds print the same line.
static const char *className(id object)
{
    const char *name = class_getName([object class]);
    size_t prefix = strlen(PREFIX);
    return strncmp(name, PREFIX, prefix) == 0 ? name + prefix : name;
}

// The value of a property by its key, if the object has it; "absent" if it does not.
static void key(const char *label, id owner, const char *name)
{
    if (!owner) {
        printf("%s\towner-nil\n", label);
        return;
    }
    if (![owner respondsToSelector:NSSelectorFromString(@(name))]) {
        printf("%s\tabsent\n", label);
        return;
    }
    id value = [owner valueForKey:@(name)];
    if (!value) {
        printf("%s\tnil\n", label);
    } else if ([value isKindOfClass:[NSNumber class]]) {
        printf("%s\tnumber %ld\n", label, (long)[value integerValue]);
    } else if ([value isKindOfClass:[NSArray class]]) {
        printf("%s\tarray %lu\n", label, (unsigned long)[value count]);
    } else {
        printf("%s\t%s\n", label, className(value));
    }
}

// Which fields of a date-components object are set: the weekday with its value, the others by name.
static void setFields(const char *label, NSDateComponents *components)
{
    if (!components) {
        printf("%s\tnil\n", label);
        return;
    }
    printf("%s\t", label);
    const char *names[] = { "year", "month", "day", "weekday", "hour", "minute", "second", "weekdayOrdinal" };
    NSCalendarUnit units[] = { NSCalendarUnitYear, NSCalendarUnitMonth, NSCalendarUnitDay, NSCalendarUnitWeekday,
                               NSCalendarUnitHour, NSCalendarUnitMinute, NSCalendarUnitSecond, NSCalendarUnitWeekdayOrdinal };
    int any = 0;
    for (int i = 0; i < 8; i++) {
        NSInteger value = [components valueForComponent:units[i]];
        if (value == NSDateComponentUndefined)
            continue;
        if (units[i] == NSCalendarUnitWeekday)
            printf("%sweekday=%ld", any ? " " : "", (long)value);
        else if (units[i] == NSCalendarUnitWeekdayOrdinal)
            printf("%sweekdayOrdinal=%ld", any ? " " : "", (long)value);
        else
            printf("%s%s", any ? " " : "", names[i]);
        any = 1;
    }
    printf("%s\n", any ? "" : "none");
}

static void endOf(const char *label, id end)
{
    if (!end) {
        printf("%s\tnil\n", label);
        return;
    }
    printf("%s\t%s\n", label, className(end));
    key("    occurrenceCount", end, "occurrenceCount");
    key("    endDate", end, "endDate");
}

// The getter, read on a range. Its raise is printed by name and reason; nothing is caught silently.
static void readGetter(id range, id rule)
{
    @try {
        id back = [range performSelector:NSSelectorFromString(@"EKRecurrenceRule")];
        if (!back) {
            printf("  EKRecurrenceRule\tnil\n");
            return;
        }
        printf("  EKRecurrenceRule\t%s\n", className(back));
        printf("  EKRecurrenceRule is the object given\t%s\n", back == rule ? "YES" : "NO");
        key("    frequency", back, "frequency");
        key("    interval", back, "interval");
        key("    daysOfTheWeek", back, "daysOfTheWeek");
        key("    daysOfTheMonth", back, "daysOfTheMonth");
        endOf("    recurrenceEnd", [back valueForKey:@"recurrenceEnd"]);
        for (EKRecurrenceDayOfWeek *day in [back valueForKey:@"daysOfTheWeek"]) {
            printf("    day\tweekday %ld, weekNumber %ld\n", (long)day.dayOfTheWeek, (long)day.weekNumber);
        }
    } @catch (NSException *e) {
        printf("  EKRecurrenceRule raises\t%s\n", [[e name] UTF8String]);
        printf("    reason\t%s\n", [[e reason] UTF8String]);
    }
}

static void rangeCase(const char *name, id rule)
{
    Class rangeClass = charonClass(@"INDateComponentsRange");
    SEL initSel = NSSelectorFromString(@"initWithEKRecurrenceRule:");
    printf("case\t%s\n", name);
    id range = [[rangeClass alloc] performSelector:initSel withObject:rule];
    if (!range) {
        printf("  range\tnil\n");
        return;
    }
    key("  range.recurrenceRule", range, "recurrenceRule");
    id kept = [range valueForKey:@"recurrenceRule"];
    key("  recurrenceRule.frequency", kept, "frequency");
    key("  recurrenceRule.interval", kept, "interval");
    key("  recurrenceRule.weeklyRecurrenceDays", kept, "weeklyRecurrenceDays");
    setFields("  startDateComponents", [range valueForKey:@"startDateComponents"]);
    setFields("  endDateComponents", [range valueForKey:@"endDateComponents"]);
    readGetter(range, rule);
}

// A range made from an Intents rule by its own designated initialiser, read through the EventKit getter.
static void intentsCase(const char *name, NSInteger frequency, NSInteger interval)
{
    Class ruleClass = charonClass(@"INRecurrenceRule");
    Class rangeClass = charonClass(@"INDateComponentsRange");
    id rule = ((id (*)(id, SEL, NSUInteger, NSInteger))objc_msgSend)([ruleClass alloc],
                  NSSelectorFromString(@"initWithInterval:frequency:"), (NSUInteger)interval, frequency);
    id range = ((id (*)(id, SEL, id, id, id))objc_msgSend)([rangeClass alloc],
                  NSSelectorFromString(@"initWithStartDateComponents:endDateComponents:recurrenceRule:"), nil, nil, rule);
    printf("intents case\t%s\n", name);
    key("  recurrenceRule.frequency", range ? [range valueForKey:@"recurrenceRule"] : nil, "frequency");
    readGetter(range, nil);
}

// A range given a start weekday with an Intents rule, through the designated initialiser, read through the getter.
static void startedCase(const char *name, NSInteger frequency, NSInteger interval, NSInteger weekday)
{
    Class ruleClass = charonClass(@"INRecurrenceRule");
    Class rangeClass = charonClass(@"INDateComponentsRange");
    id rule = ((id (*)(id, SEL, NSUInteger, NSInteger))objc_msgSend)([ruleClass alloc],
                  NSSelectorFromString(@"initWithInterval:frequency:"), (NSUInteger)interval, frequency);
    NSDateComponents *start = [[NSDateComponents alloc] init];
    start.weekday = weekday;
    id range = ((id (*)(id, SEL, id, id, id))objc_msgSend)([rangeClass alloc],
                  NSSelectorFromString(@"initWithStartDateComponents:endDateComponents:recurrenceRule:"), start, nil, rule);
    printf("started case\t%s\n", name);
    setFields("  startDateComponents", [range valueForKey:@"startDateComponents"]);
    readGetter(range, nil);
}

int main(void)
{
    @autoreleasepool {
        Class rangeClass = charonClass(@"INDateComponentsRange");
        printf("responds\tinit %d\tget %d\n", [rangeClass instancesRespondToSelector:NSSelectorFromString(@"initWithEKRecurrenceRule:")],
               [rangeClass instancesRespondToSelector:NSSelectorFromString(@"EKRecurrenceRule")]);

        EKRecurrenceDayOfWeek *monday = [EKRecurrenceDayOfWeek dayOfWeek:2];
        EKRecurrenceDayOfWeek *friday = [EKRecurrenceDayOfWeek dayOfWeek:6];
        EKRecurrenceEnd *fiveTimes = [EKRecurrenceEnd recurrenceEndWithOccurrenceCount:5];

        rangeCase("daily, interval 2, no end", [[EKRecurrenceRule alloc] initRecurrenceWithFrequency:EKRecurrenceFrequencyDaily interval:2 end:nil]);
        rangeCase("daily, interval 1, five times", [[EKRecurrenceRule alloc] initRecurrenceWithFrequency:EKRecurrenceFrequencyDaily interval:1 end:fiveTimes]);
        rangeCase("weekly, interval 1, no days, no end", [[EKRecurrenceRule alloc] initRecurrenceWithFrequency:EKRecurrenceFrequencyWeekly interval:1 end:nil]);
        rangeCase("weekly, Monday only", [[EKRecurrenceRule alloc] initRecurrenceWithFrequency:EKRecurrenceFrequencyWeekly interval:1 daysOfTheWeek:@[monday] daysOfTheMonth:nil monthsOfTheYear:nil weeksOfTheYear:nil daysOfTheYear:nil setPositions:nil end:nil]);
        rangeCase("weekly, Friday only", [[EKRecurrenceRule alloc] initRecurrenceWithFrequency:EKRecurrenceFrequencyWeekly interval:1 daysOfTheWeek:@[friday] daysOfTheMonth:nil monthsOfTheYear:nil weeksOfTheYear:nil daysOfTheYear:nil setPositions:nil end:nil]);
        rangeCase("weekly, Monday and Friday, five times", [[EKRecurrenceRule alloc] initRecurrenceWithFrequency:EKRecurrenceFrequencyWeekly interval:1 daysOfTheWeek:@[monday, friday] daysOfTheMonth:nil monthsOfTheYear:nil weeksOfTheYear:nil daysOfTheYear:nil setPositions:nil end:fiveTimes]);
        rangeCase("weekly, Friday and Monday, in that order", [[EKRecurrenceRule alloc] initRecurrenceWithFrequency:EKRecurrenceFrequencyWeekly interval:1 daysOfTheWeek:@[friday, monday] daysOfTheMonth:nil monthsOfTheYear:nil weeksOfTheYear:nil daysOfTheYear:nil setPositions:nil end:nil]);
        rangeCase("weekly, Monday with week number 2", [[EKRecurrenceRule alloc] initRecurrenceWithFrequency:EKRecurrenceFrequencyWeekly interval:1 daysOfTheWeek:@[[EKRecurrenceDayOfWeek dayOfWeek:2 weekNumber:2]] daysOfTheMonth:nil monthsOfTheYear:nil weeksOfTheYear:nil daysOfTheYear:nil setPositions:nil end:nil]);
        rangeCase("weekly, no days, five times", [[EKRecurrenceRule alloc] initRecurrenceWithFrequency:EKRecurrenceFrequencyWeekly interval:1 end:fiveTimes]);
        rangeCase("monthly, interval 1, no end", [[EKRecurrenceRule alloc] initRecurrenceWithFrequency:EKRecurrenceFrequencyMonthly interval:1 end:nil]);
        rangeCase("yearly, interval 1, no end", [[EKRecurrenceRule alloc] initRecurrenceWithFrequency:EKRecurrenceFrequencyYearly interval:1 end:nil]);
        rangeCase("daily, Monday given", [[EKRecurrenceRule alloc] initRecurrenceWithFrequency:EKRecurrenceFrequencyDaily interval:1 daysOfTheWeek:@[monday] daysOfTheMonth:nil monthsOfTheYear:nil weeksOfTheYear:nil daysOfTheYear:nil setPositions:nil end:nil]);
        rangeCase("monthly, Monday given", [[EKRecurrenceRule alloc] initRecurrenceWithFrequency:EKRecurrenceFrequencyMonthly interval:1 daysOfTheWeek:@[monday] daysOfTheMonth:nil monthsOfTheYear:nil weeksOfTheYear:nil daysOfTheYear:nil setPositions:nil end:nil]);
        rangeCase("weekly, Monday, last of the month", [[EKRecurrenceRule alloc] initRecurrenceWithFrequency:EKRecurrenceFrequencyWeekly interval:1 daysOfTheWeek:@[[EKRecurrenceDayOfWeek dayOfWeek:2 weekNumber:-1]] daysOfTheMonth:nil monthsOfTheYear:nil weeksOfTheYear:nil daysOfTheYear:nil setPositions:nil end:nil]);
        rangeCase("monthly, Friday, the second", [[EKRecurrenceRule alloc] initRecurrenceWithFrequency:EKRecurrenceFrequencyMonthly interval:1 daysOfTheWeek:@[[EKRecurrenceDayOfWeek dayOfWeek:6 weekNumber:2]] daysOfTheMonth:nil monthsOfTheYear:nil weeksOfTheYear:nil daysOfTheYear:nil setPositions:nil end:nil]);
        rangeCase("nil rule", nil);

        // Intents frequencies with no EventKit name: minute is 1, hourly 2, daily 3.
        intentsCase("minute, interval 1", 1, 1);
        intentsCase("hourly, interval 1", 2, 1);
        intentsCase("daily, interval 1, made by the Intents rule", 3, 1);
        startedCase("daily, interval 1, starts on Monday", 3, 1, 2);
        startedCase("weekly, interval 2, starts on Friday", 4, 2, 6);
        startedCase("monthly, interval 1, starts on Monday", 5, 1, 2);

        // A range made by its plain initialiser, read through the EventKit getter.
        id plain = [[rangeClass alloc] init];
        printf("plain range\t%s\n", plain ? className(plain) : "nil");
        key("  plain EKRecurrenceRule", plain, "EKRecurrenceRule");
    }
    return 0;
}
