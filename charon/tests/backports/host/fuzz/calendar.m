#import <Foundation/Foundation.h>
#import <objc/message.h>

#import "fuzz.h"

void host_attach_prefixed(const char *prefix);
static uint32_t roll(uint32_t n) { return fuzz_roll(n); }
static BOOL ours;
static SEL named(NSString *selector) { return NSSelectorFromString(ours ? [@"charonHost_" stringByAppendingString:selector] : selector); }

static NSString *date_text(NSDate *date) { return date ? [NSString stringWithFormat:@"%.3f", date.timeIntervalSinceReferenceDate] : @"nil"; }

static NSString *components_text(NSDateComponents *c)
{
    if (!c)
        return @"nil";
    NSMutableArray *parts = [NSMutableArray array];
    NSInteger values[] = {c.era, c.year, c.month, c.day, c.hour, c.minute, c.second, c.nanosecond, c.weekday, c.weekdayOrdinal, c.quarter,
                          c.weekOfMonth, c.weekOfYear, c.yearForWeekOfYear};
    for (size_t i = 0; i < sizeof values / sizeof *values; i++)
        [parts addObject:values[i] == NSDateComponentUndefined ? @"-" : [NSString stringWithFormat:@"%ld", (long)values[i]]];
    [parts addObject:[NSString stringWithFormat:@"leap %d", c.isLeapMonth]];
    [parts addObject:c.calendar ? c.calendar.calendarIdentifier : @"-"];
    [parts addObject:c.timeZone ? c.timeZone.name : @"-"];
    return [parts componentsJoinedByString:@" "];
}

static NSDate *random_date(void)
{
    switch (roll(4)) {
        case 0: return [NSDate dateWithTimeIntervalSinceReferenceDate:(double)(int32_t)(fuzz_roll(0xffffffffu)) * (roll(2) ? 1 : 40)];
        case 1: return [NSDate dateWithTimeIntervalSinceReferenceDate:694224000 + roll(86400 * 400) + roll(1000) / 1000.0];
        case 2: return [NSDate dateWithTimeIntervalSinceReferenceDate:(double)(roll(40) * 86400 * 91) - 86400.0 * 365 * 20 + roll(7200)];
        default: return [NSDate dateWithTimeIntervalSinceReferenceDate:715000000 + (double)roll(3600 * 24 * 14)];
    }
}

static NSCalendar *random_calendar(void)
{
    NSArray *identifiers = @[NSCalendarIdentifierGregorian, NSCalendarIdentifierBuddhist, NSCalendarIdentifierJapanese, NSCalendarIdentifierHebrew,
                             NSCalendarIdentifierIslamicCivil, NSCalendarIdentifierChinese, NSCalendarIdentifierISO8601, NSCalendarIdentifierPersian];
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:identifiers[roll((uint32_t)identifiers.count)]];
    NSArray *zones = @[@"UTC", @"America/New_York", @"Asia/Kathmandu", @"Australia/Lord_Howe", @"Europe/Moscow", @"Pacific/Apia", @"America/Sao_Paulo"];
    calendar.timeZone = [NSTimeZone timeZoneWithName:zones[roll((uint32_t)zones.count)]];
    NSArray *locales = @[@"en_US", @"ar_SA", @"he_IL", @"hi_IN", @"fr_FR", @"fa_IR", @"en_GB"];
    calendar.locale = [NSLocale localeWithLocaleIdentifier:locales[roll((uint32_t)locales.count)]];
    calendar.firstWeekday = 1 + roll(7);
    calendar.minimumDaysInFirstWeek = 1 + roll(7);
    return calendar;
}

static NSCalendarUnit random_unit(void)
{
    NSCalendarUnit units[] = {NSCalendarUnitEra, NSCalendarUnitYear, NSCalendarUnitMonth, NSCalendarUnitDay, NSCalendarUnitHour, NSCalendarUnitMinute,
                              NSCalendarUnitSecond, NSCalendarUnitWeekday, NSCalendarUnitWeekdayOrdinal, NSCalendarUnitQuarter,
                              NSCalendarUnitWeekOfMonth, NSCalendarUnitWeekOfYear, NSCalendarUnitYearForWeekOfYear, NSCalendarUnitNanosecond,
                              NSCalendarUnitCalendar, NSCalendarUnitTimeZone};
    return units[roll(sizeof units / sizeof *units)];
}

static NSInteger random_value(void)
{
    switch (roll(5)) {
        case 0: return (NSInteger)roll(3) - 1;
        case 1: return (NSInteger)roll(60) - 5;
        case 2: return (NSInteger)roll(10000) - 5000;
        case 3: return NSDateComponentUndefined;
        default: return (NSInteger)roll(32);
    }
}

static NSString *run(NSString *(^work)(void))
{
    @try {
        return work();
    } @catch (NSException *exception) {
        return [@"raised " stringByAppendingString:exception.name];
    }
}

static void both(NSString *what, NSString *(^work)(void))
{
    ours = NO;
    NSString *system = run(work);
    ours = YES;
    NSString *port = run(work);
    NSString *category = [what hasPrefix:@"dateWithEra week "] ? @"dateWithEra.weekOfYear" : [what componentsSeparatedByString:@" "][0];
    fuzz_compare(category, what, system, port);
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        host_attach_prefixed("");
        int rounds = 3000;
        fuzz_start(argc, argv, &rounds);
        for (int round = 0; round < rounds; round++) @autoreleasepool {
            NSCalendar *calendar = random_calendar();
            NSDate *date = random_date(), *other = roll(3) ? random_date() : [date dateByAddingTimeInterval:roll(200000)];
            NSString *where = [NSString stringWithFormat:@"%@ %@ %@ first %lu min %lu date %@", calendar.calendarIdentifier, calendar.timeZone.name,
                               calendar.locale.localeIdentifier, (unsigned long)calendar.firstWeekday, (unsigned long)calendar.minimumDaysInFirstWeek, date_text(date)];
            NSCalendarUnit unit = random_unit();
            both([NSString stringWithFormat:@"component %lu %@", (unsigned long)unit, where], ^{
                return [NSString stringWithFormat:@"%ld", (long)((NSInteger (*)(id, SEL, NSCalendarUnit, id))objc_msgSend)(calendar, named(@"component:fromDate:"), unit, date)];
            });
            both([NSString stringWithFormat:@"getEra %@", where], ^{
                NSInteger e = -9, y = -9, m = -9, d = -9, w = -9, wy = -9, wd = -9, h = -9, mi = -9, s = -9, n = -9;
                ((void (*)(id, SEL, NSInteger *, NSInteger *, NSInteger *, NSInteger *, id))objc_msgSend)(calendar, named(@"getEra:year:month:day:fromDate:"), &e, &y, &m, &d, date);
                ((void (*)(id, SEL, NSInteger *, NSInteger *, NSInteger *, NSInteger *, id))objc_msgSend)(calendar, named(@"getEra:yearForWeekOfYear:weekOfYear:weekday:fromDate:"), &e, &wy, &w, &wd, date);
                ((void (*)(id, SEL, NSInteger *, NSInteger *, NSInteger *, NSInteger *, id))objc_msgSend)(calendar, named(@"getHour:minute:second:nanosecond:fromDate:"), &h, &mi, &s, &n, date);
                return [NSString stringWithFormat:@"%ld %ld %ld %ld | %ld %ld %ld | %ld %ld %ld %ld", (long)e, (long)y, (long)m, (long)d, (long)wy, (long)w, (long)wd, (long)h, (long)mi, (long)s, (long)n];
            });
            NSInteger era = random_value(), year = roll(2) ? (NSInteger)roll(3000) : random_value(), month = random_value(), day = random_value(),
                      hour = random_value(), minute = random_value(), second = random_value(), nano = roll(2) ? 0 : random_value() * 1000;
            both([NSString stringWithFormat:@"dateWithEra %ld %ld %ld %ld %ld %ld %ld %ld %@", (long)era, (long)year, (long)month, (long)day, (long)hour, (long)minute, (long)second, (long)nano, where], ^{
                return date_text(((id (*)(id, SEL, NSInteger, NSInteger, NSInteger, NSInteger, NSInteger, NSInteger, NSInteger, NSInteger))objc_msgSend)(calendar,
                    named(@"dateWithEra:year:month:day:hour:minute:second:nanosecond:"), era, year, month, day, hour, minute, second, nano));
            });
            both([NSString stringWithFormat:@"dateWithEra week %ld %ld %ld %ld %@", (long)era, (long)year, (long)month, (long)day, where], ^{
                return date_text(((id (*)(id, SEL, NSInteger, NSInteger, NSInteger, NSInteger, NSInteger, NSInteger, NSInteger, NSInteger))objc_msgSend)(calendar,
                    named(@"dateWithEra:yearForWeekOfYear:weekOfYear:weekday:hour:minute:second:nanosecond:"), era, year, month, day, hour, minute, second, nano));
            });
            both([NSString stringWithFormat:@"startOfDay %@", where], ^{ return date_text(((id (*)(id, SEL, id))objc_msgSend)(calendar, named(@"startOfDayForDate:"), date)); });
            NSTimeZone *zone = roll(4) ? [NSTimeZone timeZoneWithName:@"Asia/Kathmandu"] : [NSTimeZone timeZoneForSecondsFromGMT:(NSInteger)roll(100000) - 50000];
            both([NSString stringWithFormat:@"componentsInTimeZone %@ %@", zone.name, where], ^{
                return components_text(((id (*)(id, SEL, id, id))objc_msgSend)(calendar, named(@"componentsInTimeZone:fromDate:"), zone, date));
            });
            both([NSString stringWithFormat:@"compare %lu %@ other %@", (unsigned long)unit, where, date_text(other)], ^{
                return [NSString stringWithFormat:@"%ld %d %d", (long)((NSComparisonResult (*)(id, SEL, id, id, NSCalendarUnit))objc_msgSend)(calendar, named(@"compareDate:toDate:toUnitGranularity:"), date, other, unit),
                        ((BOOL (*)(id, SEL, id, id, NSCalendarUnit))objc_msgSend)(calendar, named(@"isDate:equalToDate:toUnitGranularity:"), date, other, unit),
                        ((BOOL (*)(id, SEL, id, id))objc_msgSend)(calendar, named(@"isDate:inSameDayAsDate:"), date, other)];
            });
            NSInteger amount = roll(3) ? (NSInteger)roll(40) - 20 : random_value();
            NSCalendarOptions addOptions = roll(3) == 0 ? NSCalendarWrapComponents : 0;
            both([NSString stringWithFormat:@"add %lu %ld options %lu %@", (unsigned long)unit, (long)amount, (unsigned long)addOptions, where], ^{
                return date_text(((id (*)(id, SEL, NSCalendarUnit, NSInteger, id, NSCalendarOptions))objc_msgSend)(calendar, named(@"dateByAddingUnit:value:toDate:options:"), unit, amount, date, addOptions));
            });
            NSCalendarOptions setOptions = [@[@0, @(NSCalendarMatchStrictly), @(NSCalendarMatchNextTime), @(NSCalendarMatchNextTimePreservingSmallerUnits),
                                            @(NSCalendarMatchPreviousTimePreservingSmallerUnits), @(NSCalendarMatchLast), @(NSCalendarMatchFirst)][roll(7)] unsignedIntegerValue];
            NSInteger sh = roll(3) ? (NSInteger)roll(24) : random_value(), sm = roll(3) ? (NSInteger)roll(60) : random_value(), ss = roll(3) ? (NSInteger)roll(60) : random_value();
            NSString *settingCategory = date.timeIntervalSinceReferenceDate < -2524521600 ? @"setting.beforeStandardTime" : @"setting";
            both([NSString stringWithFormat:@"%@ %ld:%ld:%ld options %lu %@", settingCategory, (long)sh, (long)sm, (long)ss, (unsigned long)setOptions, where], ^{
                return date_text(((id (*)(id, SEL, NSInteger, NSInteger, NSInteger, id, NSCalendarOptions))objc_msgSend)(calendar, named(@"dateBySettingHour:minute:second:ofDate:options:"), sh, sm, ss, date, setOptions));
            });
            NSDateComponents *wanted = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour fromDate:date];
            if (roll(2)) wanted.hour = random_value();
            if (roll(3) == 0) wanted.day = random_value();
            both([NSString stringWithFormat:@"matches [%@] %@", components_text(wanted), where], ^{
                return ((BOOL (*)(id, SEL, id, id))objc_msgSend)(calendar, named(@"date:matchesComponents:"), date, wanted) ? @"YES" : @"NO";
            });
            NSDateComponents *from = [NSDateComponents new], *to = [NSDateComponents new];
            from.year = roll(2) ? 2000 + roll(30) : NSDateComponentUndefined; from.month = random_value(); from.day = random_value();
            to.year = 2000 + roll(30); to.month = random_value(); to.day = random_value(); to.hour = random_value();
            NSCalendarUnit flags = NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | (roll(2) ? NSCalendarUnitHour : 0) | (roll(3) == 0 ? NSCalendarUnitWeekOfYear : 0);
            both([NSString stringWithFormat:@"components from [%@] to [%@] flags %lu %@", components_text(from), components_text(to), (unsigned long)flags, where], ^{
                return components_text(((id (*)(id, SEL, NSCalendarUnit, id, id, NSCalendarOptions))objc_msgSend)(calendar, named(@"components:fromDateComponents:toDateComponents:options:"), flags, from, to, 0));
            });
            NSDateComponents *validity = [NSDateComponents new];
            validity.year = roll(3000); validity.month = random_value(); validity.day = random_value(); validity.hour = random_value(); validity.minute = random_value();
            if (roll(2)) validity.calendar = calendar;
            if (roll(3) == 0) validity.leapMonth = YES;
            both([NSString stringWithFormat:@"%@ [%@] %@", validity.leapMonth ? @"valid.leapMonth" : @"valid", components_text(validity), where], ^{
                return [NSString stringWithFormat:@"%d %d", ((BOOL (*)(id, SEL, id))objc_msgSend)(validity, named(@"isValidDateInCalendar:"), calendar),
                        ((BOOL (*)(id, SEL))objc_msgSend)(validity, named(@"isValidDate"))];
            });
            NSCalendarOptions direction = roll(2) ? NSCalendarSearchBackwards : 0;
            both([NSString stringWithFormat:@"weekend %@ options %lu", where, (unsigned long)direction], ^{
                NSDate *start = nil, *next = nil;
                NSTimeInterval length = -1, nextLength = -1;
                BOOL inWeekend = ((BOOL (*)(id, SEL, id))objc_msgSend)(calendar, named(@"isDateInWeekend:"), date);
                BOOL range = ((BOOL (*)(id, SEL, NSDate **, NSTimeInterval *, id))objc_msgSend)(calendar, named(@"rangeOfWeekendStartDate:interval:containingDate:"), &start, &length, date);
                BOOL found = ((BOOL (*)(id, SEL, NSDate **, NSTimeInterval *, NSCalendarOptions, id))objc_msgSend)(calendar, named(@"nextWeekendStartDate:interval:options:afterDate:"), &next, &nextLength, direction, date);
                return [NSString stringWithFormat:@"%d | %d %@ %.0f | %d %@ %.0f", inWeekend, range, date_text(start), length, found, date_text(next), nextLength];
            });
        }
        return fuzz_finish();
    }
}
