#import "check.h"

static NSInteger revenant_component(NSCalendar *calendar, NSCalendarUnit unit, NSDate *date)
{
    SEL selector = @selector(component:fromDate:);
    return REVENANT_IMP(NSCalendar, selector, NSInteger (*)(id, SEL, NSCalendarUnit, NSDate *))(calendar, selector, unit, date);
}

static NSDate *revenant_utc(NSInteger year, NSInteger month, NSInteger day, NSInteger hour, NSInteger minute)
{
    NSCalendar *utc = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    utc.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    NSDateComponents *c = [[NSDateComponents alloc] init];
    c.year = year;
    c.month = month;
    c.day = day;
    c.hour = hour;
    c.minute = minute;
    return [utc dateFromComponents:c];
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    NSDateComponents *components = [[NSDateComponents alloc] init];
    revenant_check(components.dayOfYear == NSDateComponentUndefined, "an unset day of year is undefined", [NSString stringWithFormat:@"%ld", (long)components.dayOfYear]);
    components.dayOfYear = 70;
    revenant_check(components.dayOfYear == 70, "the day of year is stored", [NSString stringWithFormat:@"%ld", (long)components.dayOfYear]);
    revenant_check([components valueForComponent:NSCalendarUnitDayOfYear] == 70, "valueForComponent reads the day of year", @"differs");
    [components setValue:71 forComponent:NSCalendarUnitDayOfYear];
    revenant_check(components.dayOfYear == 71, "setValue sets the day of year", @"differs");
    revenant_check(!components.repeatedDay, "a day is not repeated by default", @"repeated");
    components.repeatedDay = YES;
    revenant_check(components.repeatedDay && [components valueForComponent:NSCalendarUnitIsRepeatedDay] == 1, "the repeated day flag is stored", @"not stored");
    NSCalendar *utc = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    utc.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    revenant_check(revenant_component(utc, NSCalendarUnitDayOfYear, revenant_utc(2024, 3, 10, 12, 0)) == (revenant_negative ? 69 : 70), "March 10th of a leap year is day 70", @"differs");
    revenant_check(revenant_component(utc, NSCalendarUnitDayOfYear, revenant_utc(2023, 12, 31, 12, 0)) == 365, "the last day of a common year is day 365", @"differs");
    NSCalendar *paulo = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    paulo.timeZone = [NSTimeZone timeZoneWithName:@"America/Sao_Paulo"];
    revenant_check(revenant_component(paulo, NSCalendarUnitIsRepeatedDay, revenant_utc(2018, 2, 18, 2, 30)) == 1, "the second 23:30 of the repeated day is repeated", @"not repeated");
    revenant_check(revenant_component(paulo, NSCalendarUnitIsRepeatedDay, revenant_utc(2018, 2, 18, 1, 30)) == 0, "the first 23:30 of the repeated day is not repeated", @"repeated");
    revenant_check(revenant_component(paulo, NSCalendarUnitIsRepeatedDay, revenant_utc(2018, 2, 17, 15, 0)) == 0, "an ordinary time is not repeated", @"repeated");
    return revenant_finish();
}
