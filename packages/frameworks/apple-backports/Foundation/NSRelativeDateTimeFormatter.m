#import <Foundation/Foundation.h>
#include <math.h>

typedef struct {
    NSCalendarUnit unit;
    const char *fullSingular;
    const char *fullPlural;
    const char *shortSingular;
    const char *shortPlural;
    const char *abbreviated;
} RevenantRelativeUnit;

static const RevenantRelativeUnit revenant_relative_units[] = {
    {NSCalendarUnitYear, "year", "years", "yr.", "yr.", "y"},
    {NSCalendarUnitMonth, "month", "months", "mo.", "mo.", "mo"},
    {NSCalendarUnitWeekOfMonth, "week", "weeks", "wk.", "wk.", "w"},
    {NSCalendarUnitDay, "day", "days", "day", "days", "d"},
    {NSCalendarUnitHour, "hour", "hours", "hr.", "hr.", "h"},
    {NSCalendarUnitMinute, "minute", "minutes", "min.", "min.", "m"},
    {NSCalendarUnitSecond, "second", "seconds", "sec.", "sec.", "s"},
};

static const NSUInteger revenant_relative_unit_count = sizeof(revenant_relative_units) / sizeof(revenant_relative_units[0]);

static const NSCalendarUnit revenant_relative_units_asked = NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitWeekOfMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;

static NSInteger revenant_relative_value(NSDateComponents *components, NSUInteger index)
{
    switch (index) {
    case 0: return components.year;
    case 1: return components.month;
    case 2: return components.weekOfMonth;
    case 3: return components.day;
    case 4: return components.hour;
    case 5: return components.minute;
    default: return components.second;
    }
}

static NSString *revenant_relative_capitalized(NSString *text, NSLocale *locale)
{
    if (!text.length)
        return text;
    NSRange first = [text rangeOfComposedCharacterSequenceAtIndex:0];
    return [[[text substringWithRange:first] uppercaseStringWithLocale:locale] stringByAppendingString:[text substringFromIndex:NSMaxRange(first)]];
}

@implementation NSRelativeDateTimeFormatter {
    NSRelativeDateTimeFormatterStyle _dateTimeStyle;
    NSRelativeDateTimeFormatterUnitsStyle _unitsStyle;
    NSFormattingContext _formattingContext;
    NSCalendar *_calendar;
    NSLocale *_locale;
}

- (NSRelativeDateTimeFormatterStyle)dateTimeStyle
{
    return _dateTimeStyle;
}

- (void)setDateTimeStyle:(NSRelativeDateTimeFormatterStyle)dateTimeStyle
{
    _dateTimeStyle = dateTimeStyle;
}

- (NSRelativeDateTimeFormatterUnitsStyle)unitsStyle
{
    return _unitsStyle;
}

- (void)setUnitsStyle:(NSRelativeDateTimeFormatterUnitsStyle)unitsStyle
{
    _unitsStyle = unitsStyle;
}

- (NSFormattingContext)formattingContext
{
    return _formattingContext;
}

- (void)setFormattingContext:(NSFormattingContext)formattingContext
{
    _formattingContext = formattingContext;
}

- (NSCalendar *)calendar
{
    return _calendar ?: [NSCalendar currentCalendar];
}

- (void)setCalendar:(NSCalendar *)calendar
{
    _calendar = [calendar copy];
}

- (NSLocale *)locale
{
    return _locale ?: [NSLocale currentLocale];
}

- (void)setLocale:(NSLocale *)locale
{
    _locale = [locale copy];
}

- (id)copyWithZone:(NSZone *)zone
{
    NSRelativeDateTimeFormatter *copy = [[[self class] allocWithZone:zone] init];
    copy->_dateTimeStyle = _dateTimeStyle;
    copy->_unitsStyle = _unitsStyle;
    copy->_formattingContext = _formattingContext;
    copy->_calendar = [_calendar copy];
    copy->_locale = [_locale copy];
    return copy;
}

- (NSString *)revenant_number:(NSInteger)value
{
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.locale = self.locale;
    formatter.numberStyle = _unitsStyle == NSRelativeDateTimeFormatterUnitsStyleSpellOut ? NSNumberFormatterSpellOutStyle : NSNumberFormatterDecimalStyle;
    return [formatter stringFromNumber:@(value)];
}

- (NSString *)revenant_unit:(NSUInteger)index plural:(BOOL)plural
{
    const RevenantRelativeUnit *unit = &revenant_relative_units[index];
    switch (_unitsStyle) {
    case NSRelativeDateTimeFormatterUnitsStyleShort: return @(plural ? unit->shortPlural : unit->shortSingular);
    case NSRelativeDateTimeFormatterUnitsStyleAbbreviated: return @(unit->abbreviated);
    default: return @(plural ? unit->fullPlural : unit->fullSingular);
    }
}

- (NSString *)revenant_named:(NSUInteger)index value:(NSInteger)value
{
    if (index == 3)
        return value == 0 ? @"today" : value > 0 ? @"tomorrow" : @"yesterday";
    if (index == 6)
        return @"now";
    NSString *name = index > 3 ? @(revenant_relative_units[index].fullSingular) : [self revenant_named_unit:index];
    return value == 0 ? [@"this " stringByAppendingString:name] : value > 0 ? [@"next " stringByAppendingString:name] : [@"last " stringByAppendingString:name];
}

- (NSString *)revenant_named_unit:(NSUInteger)index
{
    const RevenantRelativeUnit *unit = &revenant_relative_units[index];
    return @(_unitsStyle == NSRelativeDateTimeFormatterUnitsStyleShort || _unitsStyle == NSRelativeDateTimeFormatterUnitsStyleAbbreviated ? unit->shortSingular : unit->fullSingular);
}

- (NSString *)revenant_phrase:(NSUInteger)index value:(NSInteger)value
{
    if (_dateTimeStyle == NSRelativeDateTimeFormatterStyleNamed && (value == 0 || ((value == 1 || value == -1) && index < 4)))
        return [self revenant_named:index value:value];
    NSInteger magnitude = value < 0 ? -value : value;
    NSString *separator = _unitsStyle == NSRelativeDateTimeFormatterUnitsStyleAbbreviated ? @"" : @" ";
    NSString *amount = [NSString stringWithFormat:@"%@%@%@", [self revenant_number:magnitude], separator, [self revenant_unit:index plural:magnitude != 1]];
    return value < 0 ? [amount stringByAppendingString:@" ago"] : [@"in " stringByAppendingString:amount];
}

- (NSString *)revenant_finish:(NSString *)text
{
    return _formattingContext == NSFormattingContextBeginningOfSentence ? revenant_relative_capitalized(text, self.locale) : text;
}

- (NSString *)localizedStringFromDateComponents:(NSDateComponents *)components
{
    NSInteger values[7];
    NSInteger smallest = -1;
    for (NSUInteger index = 0; index < revenant_relative_unit_count; index++) {
        values[index] = revenant_relative_value(components, index);
        if (values[index] != NSDateComponentUndefined)
            smallest = index;
    }
    if (smallest < 0)
        return nil;
    for (NSUInteger index = 0; index < revenant_relative_unit_count; index++) {
        if (values[index] != NSDateComponentUndefined && values[index] != 0)
            return [self revenant_finish:[self revenant_phrase:index value:values[index]]];
    }
    return [self revenant_finish:[self revenant_phrase:smallest value:0]];
}

- (NSString *)localizedStringForDate:(NSDate *)date relativeToDate:(NSDate *)referenceDate
{
    NSTimeInterval difference = [date timeIntervalSinceDate:referenceDate];
    NSDate *whole = [referenceDate dateByAddingTimeInterval:difference < 0 ? ceil(difference) : floor(difference)];
    NSDateComponents *components = [self.calendar components:revenant_relative_units_asked fromDate:referenceDate toDate:whole options:0];
    return [self localizedStringFromDateComponents:components];
}

- (NSString *)localizedStringFromTimeInterval:(NSTimeInterval)timeInterval
{
    NSDate *now = [NSDate date];
    return [self localizedStringForDate:[now dateByAddingTimeInterval:timeInterval] relativeToDate:now];
}

- (NSString *)stringForObjectValue:(id)object
{
    if (![object isKindOfClass:[NSDate class]])
        return nil;
    return [self localizedStringForDate:object relativeToDate:[NSDate date]];
}

@end
