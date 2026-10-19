#import <Foundation/Foundation.h>
#include <math.h>

const NSCalendarUnit CharonCalendarAllUnits = NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond |
                                              NSCalendarUnitWeekday | NSCalendarUnitWeekdayOrdinal | NSCalendarUnitQuarter | NSCalendarUnitWeekOfMonth | NSCalendarUnitWeekOfYear |
                                              NSCalendarUnitYearForWeekOfYear | NSCalendarUnitNanosecond | NSCalendarUnitCalendar | NSCalendarUnitTimeZone;

NSInteger charon_calendar_nanosecond(NSDate *date)
{
    double interval = date.timeIntervalSinceReferenceDate;
    return (NSInteger)((interval - floor(interval)) * 1000000000.0);
}

NSInteger charon_calendar_nanosecond_exactly(NSDate *date)
{
    double interval = date.timeIntervalSinceReferenceDate;
    double fraction = interval - floor(interval);
    double product = fraction * 1000000000.0;
    NSInteger nanoseconds = (NSInteger)product;
    if (product == floor(product) && fma(fraction, 1000000000.0, -product) < 0)
        nanoseconds--;
    return nanoseconds;
}

NSInteger charon_calendar_quarter(NSCalendar *calendar, NSDate *date)
{
    NSString *identifier = calendar.calendarIdentifier;
    if (![identifier isEqualToString:@"gregorian"] && ![identifier isEqualToString:@"iso8601"])
        return 0;
    NSInteger month = [calendar components:NSCalendarUnitMonth fromDate:date].month;
    return month == NSDateComponentUndefined ? NSDateComponentUndefined : (month - 1) / 3 + 1;
}

NSDateComponents *charon_calendar_components(NSCalendar *calendar, NSCalendarUnit units, NSDate *date)
{
    NSDateComponents *components = [calendar components:units & ~NSCalendarUnitNanosecond fromDate:date];
    if (units & NSCalendarUnitNanosecond)
        components.nanosecond = charon_calendar_nanosecond(date);
    if ((units & NSCalendarUnitQuarter) && components.quarter <= 0)
        components.quarter = charon_calendar_quarter(calendar, date);
    return components;
}

NSInteger charon_calendar_value(NSDateComponents *components, NSCalendarUnit unit)
{
    switch (unit) {
    case NSCalendarUnitEra:
        return components.era;
    case NSCalendarUnitYear:
        return components.year;
    case NSCalendarUnitMonth:
        return components.month;
    case NSCalendarUnitDay:
        return components.day;
    case NSCalendarUnitHour:
        return components.hour;
    case NSCalendarUnitMinute:
        return components.minute;
    case NSCalendarUnitSecond:
        return components.second;
    case NSCalendarUnitWeekday:
        return components.weekday;
    case NSCalendarUnitWeekdayOrdinal:
        return components.weekdayOrdinal;
    case NSCalendarUnitQuarter:
        return components.quarter;
    case NSCalendarUnitWeekOfMonth:
        return components.weekOfMonth;
    case NSCalendarUnitWeekOfYear:
        return components.weekOfYear;
    case NSCalendarUnitYearForWeekOfYear:
        return components.yearForWeekOfYear;
    case NSCalendarUnitNanosecond:
        return components.nanosecond;
    default:
        return NSDateComponentUndefined;
    }
}

BOOL charon_calendar_set_value(NSDateComponents *components, NSCalendarUnit unit, NSInteger value)
{
    switch (unit) {
    case NSCalendarUnitEra:
        components.era = value;
        return YES;
    case NSCalendarUnitYear:
        components.year = value;
        return YES;
    case NSCalendarUnitMonth:
        components.month = value;
        return YES;
    case NSCalendarUnitDay:
        components.day = value;
        return YES;
    case NSCalendarUnitHour:
        components.hour = value;
        return YES;
    case NSCalendarUnitMinute:
        components.minute = value;
        return YES;
    case NSCalendarUnitSecond:
        components.second = value;
        return YES;
    case NSCalendarUnitWeekday:
        components.weekday = value;
        return YES;
    case NSCalendarUnitWeekdayOrdinal:
        components.weekdayOrdinal = value;
        return YES;
    case NSCalendarUnitQuarter:
        components.quarter = value;
        return YES;
    case NSCalendarUnitWeekOfMonth:
        components.weekOfMonth = value;
        return YES;
    case NSCalendarUnitWeekOfYear:
        components.weekOfYear = value;
        return YES;
    case NSCalendarUnitYearForWeekOfYear:
        components.yearForWeekOfYear = value;
        return YES;
    case NSCalendarUnitNanosecond:
        components.nanosecond = value;
        return YES;
    default:
        return NO;
    }
}

NSCalendarUnit charon_calendar_given_units(NSDateComponents *components)
{
    NSCalendarUnit given = 0;
    NSCalendarUnit candidates[] = {NSCalendarUnitEra, NSCalendarUnitYear, NSCalendarUnitMonth, NSCalendarUnitDay, NSCalendarUnitHour, NSCalendarUnitMinute, NSCalendarUnitSecond,
                                   NSCalendarUnitWeekday, NSCalendarUnitWeekdayOrdinal, NSCalendarUnitQuarter, NSCalendarUnitWeekOfMonth, NSCalendarUnitWeekOfYear,
                                   NSCalendarUnitYearForWeekOfYear, NSCalendarUnitNanosecond};
    for (size_t index = 0; index < sizeof candidates / sizeof *candidates; index++) {
        if (charon_calendar_value(components, candidates[index]) != NSDateComponentUndefined)
            given |= candidates[index];
    }
    return given;
}

NSCalendar *charon_calendar_for_components(NSCalendar *calendar, NSDateComponents *components)
{
    NSCalendar *used = components.calendar ? components.calendar : calendar;
    if (components.timeZone && ![components.timeZone isEqual:used.timeZone]) {
        used = [used copy];
        used.timeZone = components.timeZone;
    }
    return used;
}
