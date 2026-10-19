#import <Foundation/Foundation.h>

NSInteger charon_calendar_value(NSDateComponents *components, NSCalendarUnit unit);
NSCalendarUnit charon_calendar_given_units(NSDateComponents *components);
NSCalendar *charon_calendar_for_components(NSCalendar *calendar, NSDateComponents *components);

static BOOL charon_components_valid(NSDateComponents *self, NSCalendar *calendar)
{
    NSCalendar *used = charon_calendar_for_components(calendar, self);
    NSDate *date = [used dateFromComponents:self];
    if (!date)
        return NO;
    NSCalendarUnit given = charon_calendar_given_units(self) & ~NSCalendarUnitNanosecond;
    NSDateComponents *found = [used components:given fromDate:date];
    NSCalendarUnit candidates[] = {NSCalendarUnitEra, NSCalendarUnitYear, NSCalendarUnitMonth, NSCalendarUnitDay, NSCalendarUnitHour, NSCalendarUnitMinute, NSCalendarUnitSecond,
                                   NSCalendarUnitWeekday, NSCalendarUnitWeekdayOrdinal, NSCalendarUnitQuarter, NSCalendarUnitWeekOfMonth, NSCalendarUnitWeekOfYear,
                                   NSCalendarUnitYearForWeekOfYear};
    for (size_t index = 0; index < sizeof candidates / sizeof *candidates; index++) {
        if (!(given & candidates[index]))
            continue;
        if (charon_calendar_value(self, candidates[index]) != charon_calendar_value(found, candidates[index]))
            return NO;
    }
    return YES;
}

@implementation NSDateComponents (CharonValidation)

- (BOOL)isValidDateInCalendar:(NSCalendar *)calendar
{
    return charon_components_valid(self, calendar);
}

- (BOOL)isValidDate
{
    return self.calendar && charon_components_valid(self, self.calendar);
}

@end
