#import "check.h"

static NSString *revenant_stamp(NSCalendar *calendar, NSDate *date)
{
    NSDateComponents *c = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond fromDate:date];
    return [NSString stringWithFormat:@"%04ld-%02ld-%02ld %02ld:%02ld:%02ld", (long)c.year, (long)c.month, (long)c.day, (long)c.hour, (long)c.minute, (long)c.second];
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
    NSDate *hourMatch = [calendar nextDateAfterDate:date matchingHour:14 minute:30 second:0 options:NSCalendarMatchNextTime];
    revenant_expect_string("the next 14:30:00 after noon is the same day", revenant_stamp(calendar, hourMatch), revenant_negative ? @"2024-03-11 14:30:00" : @"2024-03-10 14:30:00");
    NSDate *earlier = [calendar nextDateAfterDate:date matchingHour:9 minute:0 second:0 options:NSCalendarMatchNextTime];
    revenant_expect_string("the next 09:00:00 after noon is the next day", revenant_stamp(calendar, earlier), @"2024-03-11 09:00:00");
    NSDate *month = [calendar nextDateAfterDate:date matchingUnit:NSCalendarUnitMonth value:2 options:NSCalendarMatchNextTime];
    revenant_expect_string("the next February starts a year later", revenant_stamp(calendar, month), @"2025-02-01 00:00:00");
    NSDate *day = [calendar nextDateAfterDate:date matchingUnit:NSCalendarUnitDay value:31 options:NSCalendarMatchNextTime];
    revenant_expect_string("the next 31st is later this month", revenant_stamp(calendar, day), @"2024-03-31 00:00:00");
    NSDate *backwards = [calendar nextDateAfterDate:date matchingUnit:NSCalendarUnitDay value:5 options:NSCalendarSearchBackwards | NSCalendarMatchNextTime];
    revenant_expect_string("a backwards search finds the previous 5th", revenant_stamp(calendar, backwards), @"2024-03-05 00:00:00");
    return revenant_finish();
}
