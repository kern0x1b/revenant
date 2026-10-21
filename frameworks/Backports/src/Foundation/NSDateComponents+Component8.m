#import <Foundation/Foundation.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation NSDateComponents (RevenantComponent8)

- (void)setValue:(NSInteger)value forComponent:(NSCalendarUnit)unit
{
    switch (unit) {
        case NSCalendarUnitEra: self.era = value; break;
        case NSCalendarUnitYear: self.year = value; break;
        case NSCalendarUnitMonth: self.month = value; break;
        case NSCalendarUnitDay: self.day = value; break;
        case NSCalendarUnitHour: self.hour = value; break;
        case NSCalendarUnitMinute: self.minute = value; break;
        case NSCalendarUnitSecond: self.second = value; break;
        case NSWeekCalendarUnit: self.week = value; break;
        case NSCalendarUnitWeekday: self.weekday = value; break;
        case NSCalendarUnitWeekdayOrdinal: self.weekdayOrdinal = value; break;
        case NSCalendarUnitQuarter: self.quarter = value; break;
        case NSCalendarUnitWeekOfMonth: self.weekOfMonth = value; break;
        case NSCalendarUnitWeekOfYear: self.weekOfYear = value; break;
        case NSCalendarUnitYearForWeekOfYear: self.yearForWeekOfYear = value; break;
        case NSCalendarUnitNanosecond: self.nanosecond = value; break;
        default:
            [NSException raise:NSInvalidArgumentException format:@"NSDateComponents cannot set calendar unit %lu by component", (unsigned long)unit];
    }
}

- (NSInteger)valueForComponent:(NSCalendarUnit)unit
{
    switch (unit) {
        case NSCalendarUnitEra: return self.era;
        case NSCalendarUnitYear: return self.year;
        case NSCalendarUnitMonth: return self.month;
        case NSCalendarUnitDay: return self.day;
        case NSCalendarUnitHour: return self.hour;
        case NSCalendarUnitMinute: return self.minute;
        case NSCalendarUnitSecond: return self.second;
        case NSWeekCalendarUnit: return self.week;
        case NSCalendarUnitWeekday: return self.weekday;
        case NSCalendarUnitWeekdayOrdinal: return self.weekdayOrdinal;
        case NSCalendarUnitQuarter: return self.quarter;
        case NSCalendarUnitWeekOfMonth: return self.weekOfMonth;
        case NSCalendarUnitWeekOfYear: return self.weekOfYear;
        case NSCalendarUnitYearForWeekOfYear: return self.yearForWeekOfYear;
        case NSCalendarUnitNanosecond: return self.nanosecond;
        default:
            [NSException raise:NSInvalidArgumentException format:@"NSDateComponents has no value for calendar unit %lu by component", (unsigned long)unit];
            return NSDateComponentUndefined;
    }
}

@end
