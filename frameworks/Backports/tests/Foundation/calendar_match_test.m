#import "check.h"

typedef NSDate *(*NextFunction)(id, SEL, NSDate *, NSDateComponents *, NSCalendarOptions);

static NSString *revenant_stamp(NSCalendar *calendar, NSDate *date)
{
    if (!date) {
        return @"nil";
    }
    NSDateComponents *c = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond | NSCalendarUnitWeekday fromDate:date];
    return [NSString stringWithFormat:@"%04ld-%02ld-%02ld %02ld:%02ld:%02ld w%ld (%+.0fs)", (long)c.year, (long)c.month, (long)c.day, (long)c.hour, (long)c.minute, (long)c.second, (long)c.weekday, (double)[calendar.timeZone secondsFromGMTForDate:date]];
}

static NSDateComponents *revenant_make(NSInteger year, NSInteger month, NSInteger day, NSInteger hour, NSInteger minute, NSInteger second, NSInteger weekday, NSInteger ordinal)
{
    NSDateComponents *c = [[NSDateComponents alloc] init];
    if (year != NSDateComponentUndefined) c.year = year;
    if (month != NSDateComponentUndefined) c.month = month;
    if (day != NSDateComponentUndefined) c.day = day;
    if (hour != NSDateComponentUndefined) c.hour = hour;
    if (minute != NSDateComponentUndefined) c.minute = minute;
    if (second != NSDateComponentUndefined) c.second = second;
    if (weekday != NSDateComponentUndefined) c.weekday = weekday;
    if (ordinal != NSDateComponentUndefined) c.weekdayOrdinal = ordinal;
    return c;
}

static NSCalendar *revenant_calendar(NSString *zone)
{
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    calendar.timeZone = [NSTimeZone timeZoneWithName:zone];
    calendar.locale = [NSLocale localeWithLocaleIdentifier:@"en_US"];
    return calendar;
}

static NSDate *revenant_at(NSCalendar *calendar, NSInteger year, NSInteger month, NSInteger day, NSInteger hour, NSInteger minute, NSInteger second)
{
    return [calendar dateFromComponents:revenant_make(year, month, day, hour, minute, second, NSDateComponentUndefined, NSDateComponentUndefined)];
}

static BOOL revenant_host_defect(NSString *shape, NSString *zone, BOOL backward, NSInteger instant)
{
    if (!backward) {
        return NO;
    }
    if ([shape hasPrefix:@"weekday+ordinal"]) {
        return YES;
    }
    return ([shape isEqualToString:@"day29"] || [shape isEqualToString:@"day31"]) && [zone isEqualToString:@"Europe/Berlin"] && instant >= 1698537600 && instant <= 1698544800;
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    const NSInteger U = NSDateComponentUndefined;
    SEL selector = @selector(nextDateAfterDate:matchingComponents:options:);
    NextFunction backport = REVENANT_IMP(NSCalendar, selector, NextFunction);

    NSCalendar *utc = revenant_calendar(@"UTC");
    NSCalendar *newYork = revenant_calendar(@"America/New_York");
    NSDate *sunday = revenant_at(utc, 2024, 3, 10, 12, 0, 0);
    NSDateComponents *mondayNine = revenant_make(U, U, U, 9, U, U, 2, U);
    revenant_expect_string("Monday 09:00 after a Sunday noon is the next day", revenant_stamp(utc, backport(utc, selector, sunday, mondayNine, NSCalendarMatchNextTime)), revenant_negative ? @"2024-03-04 09:00:00 w2 (+0s)" : @"2024-03-11 09:00:00 w2 (+0s)");
    revenant_expect_string("Monday 09:00 searched backwards is the previous week", revenant_stamp(utc, backport(utc, selector, sunday, mondayNine, NSCalendarMatchNextTime | NSCalendarSearchBackwards)), @"2024-03-04 09:00:00 w2 (+0s)");
    revenant_expect_string("February 29 after March 2024 is 2028", revenant_stamp(utc, backport(utc, selector, sunday, revenant_make(U, 2, 29, U, U, U, U, U), NSCalendarMatchStrictly)), @"2028-02-29 00:00:00 w3 (+0s)");

    NSDate *beforeGap = revenant_at(newYork, 2024, 3, 9, 12, 0, 0);
    NSDateComponents *insideGap = revenant_make(U, U, U, 2, 30, U, U, U);
    revenant_expect_string("a time inside the spring gap moves to the end of the gap", revenant_stamp(newYork, backport(newYork, selector, beforeGap, insideGap, NSCalendarMatchNextTime)), @"2024-03-10 03:00:00 w1 (-14400s)");
    revenant_expect_string("a time inside the spring gap keeps its minutes when it moves on", revenant_stamp(newYork, backport(newYork, selector, beforeGap, insideGap, NSCalendarMatchNextTimePreservingSmallerUnits)), @"2024-03-10 03:30:00 w1 (-14400s)");
    revenant_expect_string("a time inside the spring gap keeps its minutes when it moves back", revenant_stamp(newYork, backport(newYork, selector, beforeGap, insideGap, NSCalendarMatchPreviousTimePreservingSmallerUnits)), @"2024-03-10 01:30:00 w1 (-18000s)");

    NSDate *beforeOverlap = revenant_at(newYork, 2024, 11, 2, 12, 0, 0);
    NSDateComponents *repeated = revenant_make(U, U, U, 1, 30, U, U, U);
    NSDate *first = backport(newYork, selector, beforeOverlap, repeated, NSCalendarMatchNextTime | NSCalendarMatchFirst);
    NSDate *last = backport(newYork, selector, beforeOverlap, repeated, NSCalendarMatchNextTime | NSCalendarMatchLast);
    revenant_check(first && last && [last timeIntervalSinceDate:first] == 3600, "a repeated autumn hour has a first and a last occurrence an hour apart", [NSString stringWithFormat:@"%@ then %@", revenant_stamp(newYork, first), revenant_stamp(newYork, last)]);

    NSArray *zones = @[@"UTC", @"America/New_York", @"Europe/Berlin", @"Asia/Kolkata", @"Australia/Lord_Howe", @"America/Sao_Paulo"];
    NSArray *instants = @[@1710072000, @1710054000, @1710064800, @1730613000, @1730606400, @1709164800, @1709251200, @1735689599, @1735689600, @1711846799, @1711850400, @1698537600, @1698539400, @1698541200, @1698544800, @1730616600, @1700000000, @1721000000, @1733000000, @1715000123];
    NSArray *optionSets = @[@(NSCalendarMatchNextTime), @(NSCalendarMatchNextTimePreservingSmallerUnits), @(NSCalendarMatchPreviousTimePreservingSmallerUnits), @(NSCalendarMatchStrictly), @(NSCalendarMatchNextTime | NSCalendarMatchLast),
                            @(NSCalendarMatchNextTime | NSCalendarSearchBackwards), @(NSCalendarMatchNextTimePreservingSmallerUnits | NSCalendarSearchBackwards),
                            @(NSCalendarMatchPreviousTimePreservingSmallerUnits | NSCalendarSearchBackwards), @(NSCalendarMatchStrictly | NSCalendarSearchBackwards), @(NSCalendarMatchNextTime | NSCalendarMatchLast | NSCalendarSearchBackwards)];
    NSArray *shapeNames = @[@"h", @"hm", @"hms", @"hms-now", @"hms-now+weekday", @"hms-now+weekday-today", @"hms+weekday", @"m", @"s", @"ms", @"day", @"day31", @"day29", @"day+hm", @"month", @"month+day", @"month+day+hms", @"year", @"weekday", @"weekday+ordinal", @"weekday+ordinal+month"];
    NSMutableDictionary<NSString *, NSMutableArray<NSString *> *> *differences = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString *, NSNumber *> *compared = [NSMutableDictionary dictionary];
    NSInteger skipped = 0;
    for (NSString *zone in zones) {
        NSCalendar *calendar = revenant_calendar(zone);
        for (NSNumber *instantValue in instants) {
            NSDate *date = [NSDate dateWithTimeIntervalSince1970:instantValue.doubleValue];
            NSDateComponents *now = [calendar components:NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond fromDate:date];
            NSDateComponents *nowOnTuesday = [now copy];
            nowOnTuesday.weekday = 3;
            NSDateComponents *nowToday = [now copy];
            nowToday.weekday = [calendar component:NSCalendarUnitWeekday fromDate:date];
            NSArray *shapes = @[revenant_make(U, U, U, 9, U, U, U, U), revenant_make(U, U, U, 14, 30, U, U, U), revenant_make(U, U, U, 14, 30, 15, U, U), now, nowOnTuesday, nowToday,
                                revenant_make(U, U, U, 2, 30, 0, 6, U), revenant_make(U, U, U, U, 45, U, U, U), revenant_make(U, U, U, U, U, 30, U, U), revenant_make(U, U, U, U, 15, 20, U, U),
                                revenant_make(U, U, 15, U, U, U, U, U), revenant_make(U, U, 31, U, U, U, U, U), revenant_make(U, U, 29, U, U, U, U, U), revenant_make(U, U, 10, 8, 15, U, U, U),
                                revenant_make(U, 6, U, U, U, U, U, U), revenant_make(U, 2, 29, U, U, U, U, U), revenant_make(U, 12, 25, 9, 0, 0, U, U), revenant_make(2030, U, U, U, U, U, U, U),
                                revenant_make(U, U, U, U, U, U, 2, U), revenant_make(U, U, U, U, U, U, 2, 2), revenant_make(U, 11, U, U, U, U, 5, 4)];
            for (NSUInteger shapeIndex = 0; shapeIndex < shapes.count; shapeIndex++) {
                for (NSNumber *optionValue in optionSets) {
                    NSCalendarOptions options = optionValue.unsignedIntegerValue;
                    BOOL backward = (options & NSCalendarSearchBackwards) != 0;
                    if (revenant_host_defect(shapeNames[shapeIndex], zone, backward, instantValue.integerValue)) {
                        skipped++;
                        continue;
                    }
                    NSDate *expected = [calendar nextDateAfterDate:date matchingComponents:shapes[shapeIndex] options:options];
                    NSDate *got = backport(calendar, selector, date, shapes[shapeIndex], revenant_negative ? (options ^ NSCalendarSearchBackwards) : options);
                    compared[shapeNames[shapeIndex]] = @(compared[shapeNames[shapeIndex]].integerValue + 1);
                    BOOL same = (!expected && !got) || (expected && got && fabs([expected timeIntervalSinceDate:got]) < 0.5);
                    if (!same) {
                        NSMutableArray<NSString *> *list = differences[shapeNames[shapeIndex]] ?: [NSMutableArray array];
                        differences[shapeNames[shapeIndex]] = list;
                        if (list.count < 3) {
                            [list addObject:[NSString stringWithFormat:@"%@ from %@ options %lu: system %@, backport %@", zone, revenant_stamp(calendar, date), (unsigned long)options, revenant_stamp(calendar, expected), revenant_stamp(calendar, got)]];
                        } else {
                            [list addObject:@""];
                        }
                    }
                }
            }
        }
    }
    for (NSString *shape in shapeNames) {
        NSArray<NSString *> *list = differences[shape];
        NSString *name = [NSString stringWithFormat:@"the backport agrees with the system on the %@ shape (%ld cases)", shape, (long)compared[shape].integerValue];
        NSMutableString *seen = [NSMutableString stringWithFormat:@"%lu differ", (unsigned long)list.count];
        for (NSUInteger index = 0; index < MIN(list.count, 3u); index++) {
            [seen appendFormat:@"; %@", list[index]];
        }
        revenant_check(list.count == 0, [name UTF8String], seen);
    }
    printf("compared %ld cases, left out %ld the system answers wrongly\n", (long)[[compared.allValues valueForKeyPath:@"@sum.self"] integerValue], (long)skipped);
    return revenant_finish();
}
