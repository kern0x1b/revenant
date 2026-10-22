#import "check.h"

static NSString *revenant_stamp(NSCalendar *calendar, NSDate *date)
{
    NSDateComponents *c = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond fromDate:date];
    return [NSString stringWithFormat:@"%04ld-%02ld-%02ld %02ld:%02ld:%02ld", (long)c.year, (long)c.month, (long)c.day, (long)c.hour, (long)c.minute, (long)c.second];
}

static NSDate *revenant_next_hour(NSCalendar *calendar, NSDate *date, NSInteger hour, NSInteger minute, NSInteger second, NSCalendarOptions options)
{
    SEL selector = @selector(nextDateAfterDate:matchingHour:minute:second:options:);
    return REVENANT_IMP(NSCalendar, selector, NSDate *(*)(id, SEL, NSDate *, NSInteger, NSInteger, NSInteger, NSCalendarOptions))(calendar, selector, date, hour, minute, second, options);
}

static NSDate *revenant_next_unit(NSCalendar *calendar, NSDate *date, NSCalendarUnit unit, NSInteger value, NSCalendarOptions options)
{
    SEL selector = @selector(nextDateAfterDate:matchingUnit:value:options:);
    return REVENANT_IMP(NSCalendar, selector, NSDate *(*)(id, SEL, NSDate *, NSCalendarUnit, NSInteger, NSCalendarOptions))(calendar, selector, date, unit, value, options);
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    calendar.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    NSDateComponents *start = [[NSDateComponents alloc] init];
    start.year = 2024;
    start.month = 3;
    start.day = 10;
    start.hour = 12;
    NSDate *date = [calendar dateFromComponents:start];
    NSDate *hourMatch = revenant_next_hour(calendar, date, 14, 30, 0, NSCalendarMatchNextTime);
    revenant_expect_string("the next 14:30:00 after noon is the same day", revenant_stamp(calendar, hourMatch), revenant_negative ? @"2024-03-11 14:30:00" : @"2024-03-10 14:30:00");
    NSDate *earlier = revenant_next_hour(calendar, date, 9, 0, 0, NSCalendarMatchNextTime);
    revenant_expect_string("the next 09:00:00 after noon is the next day", revenant_stamp(calendar, earlier), @"2024-03-11 09:00:00");
    NSDate *month = revenant_next_unit(calendar, date, NSCalendarUnitMonth, 2, NSCalendarMatchNextTime);
    revenant_expect_string("the next February starts a year later", revenant_stamp(calendar, month), @"2025-02-01 00:00:00");
    NSDate *day = revenant_next_unit(calendar, date, NSCalendarUnitDay, 31, NSCalendarMatchNextTime);
    revenant_expect_string("the next 31st is later this month", revenant_stamp(calendar, day), @"2024-03-31 00:00:00");
    NSDate *backwards = revenant_next_unit(calendar, date, NSCalendarUnitDay, 5, NSCalendarSearchBackwards | NSCalendarMatchNextTime);
    revenant_expect_string("a backwards search finds the previous 5th", revenant_stamp(calendar, backwards), @"2024-03-05 00:00:00");
    return revenant_finish();
}
