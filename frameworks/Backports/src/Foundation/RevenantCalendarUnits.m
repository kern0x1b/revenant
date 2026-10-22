#import <Foundation/Foundation.h>
#include <math.h>

const NSCalendarUnit RevenantCalendarAllUnits = NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond |
                                              NSCalendarUnitWeekday | NSCalendarUnitWeekdayOrdinal | NSCalendarUnitQuarter | NSCalendarUnitWeekOfMonth | NSCalendarUnitWeekOfYear |
                                              NSCalendarUnitYearForWeekOfYear | NSCalendarUnitNanosecond | NSCalendarUnitCalendar | NSCalendarUnitTimeZone;

NSInteger revenant_calendar_nanosecond(NSDate *date)
{
    double interval = date.timeIntervalSinceReferenceDate;
    return (NSInteger)((interval - floor(interval)) * 1000000000.0);
}

NSInteger revenant_calendar_nanosecond_exactly(NSDate *date)
{
    double interval = date.timeIntervalSinceReferenceDate;
    double fraction = interval - floor(interval);
    double product = fraction * 1000000000.0;
    NSInteger nanoseconds = (NSInteger)product;
    if (product == floor(product) && fma(fraction, 1000000000.0, -product) < 0)
        nanoseconds--;
    return nanoseconds;
}

NSInteger revenant_calendar_quarter(NSCalendar *calendar, NSDate *date)
{
    NSString *identifier = calendar.calendarIdentifier;
    if (![identifier isEqualToString:@"gregorian"] && ![identifier isEqualToString:@"iso8601"])
        return 0;
    NSInteger month = [calendar components:NSCalendarUnitMonth fromDate:date].month;
    return month == NSDateComponentUndefined ? NSDateComponentUndefined : (month - 1) / 3 + 1;
}

static BOOL revenant_calendar_repeated_day(NSCalendar *calendar, NSDate *date)
{
    NSTimeZone *zone = calendar.timeZone;
    NSDate *transition = [zone nextDaylightSavingTimeTransitionAfterDate:[date dateByAddingTimeInterval:-10800]];
    if (!transition || [transition compare:date] == NSOrderedDescending)
        return NO;
    NSDate *before = [transition dateByAddingTimeInterval:-1];
    NSInteger change = [zone secondsFromGMTForDate:transition] - [zone secondsFromGMTForDate:before];
    return change < 0 && [date timeIntervalSinceDate:transition] < -change;
}

NSDateComponents *revenant_calendar_components(NSCalendar *calendar, NSCalendarUnit units, NSDate *date)
{
    NSCalendarUnit derived = NSCalendarUnitDayOfYear | NSCalendarUnitIsRepeatedDay;
    NSDateComponents *components = [calendar components:units & ~(NSCalendarUnitNanosecond | derived) fromDate:date];
    if (units & NSCalendarUnitDayOfYear)
        components.dayOfYear = (NSInteger)[calendar ordinalityOfUnit:NSCalendarUnitDay inUnit:NSCalendarUnitYear forDate:date];
    if (units & NSCalendarUnitIsRepeatedDay)
        components.repeatedDay = revenant_calendar_repeated_day(calendar, date);
    if (units & NSCalendarUnitNanosecond)
        components.nanosecond = revenant_calendar_nanosecond(date);
    if ((units & NSCalendarUnitQuarter) && components.quarter <= 0)
        components.quarter = revenant_calendar_quarter(calendar, date);
    return components;
}

NSInteger revenant_calendar_value(NSDateComponents *components, NSCalendarUnit unit)
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
    case NSCalendarUnitDayOfYear:
        return components.dayOfYear;
    case NSCalendarUnitIsRepeatedDay:
        return components.repeatedDay ? 1 : 0;
    default:
        return NSDateComponentUndefined;
    }
}

BOOL revenant_calendar_set_value(NSDateComponents *components, NSCalendarUnit unit, NSInteger value)
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
    case NSCalendarUnitDayOfYear:
        components.dayOfYear = value;
        return YES;
    case NSCalendarUnitIsRepeatedDay:
        components.repeatedDay = value != 0;
        return YES;
    default:
        return NO;
    }
}

NSCalendarUnit revenant_calendar_given_units(NSDateComponents *components)
{
    NSCalendarUnit given = 0;
    NSCalendarUnit candidates[] = {NSCalendarUnitEra, NSCalendarUnitYear, NSCalendarUnitMonth, NSCalendarUnitDay, NSCalendarUnitHour, NSCalendarUnitMinute, NSCalendarUnitSecond,
                                   NSCalendarUnitWeekday, NSCalendarUnitWeekdayOrdinal, NSCalendarUnitQuarter, NSCalendarUnitWeekOfMonth, NSCalendarUnitWeekOfYear,
                                   NSCalendarUnitYearForWeekOfYear, NSCalendarUnitNanosecond, NSCalendarUnitDayOfYear};
    for (size_t index = 0; index < sizeof candidates / sizeof *candidates; index++) {
        if (revenant_calendar_value(components, candidates[index]) != NSDateComponentUndefined)
            given |= candidates[index];
    }
    return given;
}

NSCalendar *revenant_calendar_for_components(NSCalendar *calendar, NSDateComponents *components)
{
    NSCalendar *used = components.calendar ? components.calendar : calendar;
    if (components.timeZone && ![components.timeZone isEqual:used.timeZone]) {
        used = [used copy];
        used.timeZone = components.timeZone;
    }
    return used;
}
