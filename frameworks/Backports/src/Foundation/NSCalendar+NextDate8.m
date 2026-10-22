#import <Foundation/Foundation.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation NSCalendar (RevenantNextDate8)

- (NSDate *)nextDateAfterDate:(NSDate *)date matchingUnit:(NSCalendarUnit)unit value:(NSInteger)value options:(NSCalendarOptions)options
{
    NSDateComponents *components = [[NSDateComponents alloc] init];
    [components setValue:value forComponent:unit];
    return [self nextDateAfterDate:date matchingComponents:components options:options];
}

- (NSDate *)nextDateAfterDate:(NSDate *)date matchingHour:(NSInteger)hourValue minute:(NSInteger)minuteValue second:(NSInteger)secondValue options:(NSCalendarOptions)options
{
    NSDateComponents *components = [[NSDateComponents alloc] init];
    components.hour = hourValue;
    components.minute = minuteValue;
    components.second = secondValue;
    return [self nextDateAfterDate:date matchingComponents:components options:options];
}

@end
