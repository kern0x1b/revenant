#import <Foundation/Foundation.h>

typedef struct {
    NSCalendarUnit unit;
    const char *abbreviated;
    const char *shortSingular;
    const char *shortPlural;
    const char *fullSingular;
    const char *fullPlural;
} CharonUnitNames;

static const CharonUnitNames charon_units[] = {
    {NSCalendarUnitYear, "y", "yr", "yrs", "year", "years"},
    {NSCalendarUnitMonth, "mo", "mth", "mths", "month", "months"},
    {NSCalendarUnitWeekOfMonth, "w", "wk", "wks", "week", "weeks"},
    {NSCalendarUnitDay, "d", "day", "days", "day", "days"},
    {NSCalendarUnitHour, "h", "hr", "hr", "hour", "hours"},
    {NSCalendarUnitMinute, "m", "min", "min", "minute", "minutes"},
    {NSCalendarUnitSecond, "s", "sec", "sec", "second", "seconds"},
};

static const NSUInteger charon_unit_count = sizeof(charon_units) / sizeof(charon_units[0]);

static const NSCalendarUnit charon_all_units = NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitWeekOfMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;

static NSInteger charon_value(NSDateComponents *components, NSCalendarUnit unit)
{
    switch (unit) {
    case NSCalendarUnitYear: return components.year;
    case NSCalendarUnitMonth: return components.month;
    case NSCalendarUnitWeekOfMonth: return components.weekOfMonth;
    case NSCalendarUnitDay: return components.day;
    case NSCalendarUnitHour: return components.hour;
    case NSCalendarUnitMinute: return components.minute;
    default: return components.second;
    }
}

static NSDateComponents *charon_single(NSCalendarUnit unit, NSInteger value)
{
    NSDateComponents *components = [[NSDateComponents alloc] init];
    switch (unit) {
    case NSCalendarUnitYear: components.year = value; break;
    case NSCalendarUnitMonth: components.month = value; break;
    case NSCalendarUnitWeekOfMonth: components.weekOfMonth = value; break;
    case NSCalendarUnitDay: components.day = value; break;
    case NSCalendarUnitHour: components.hour = value; break;
    case NSCalendarUnitMinute: components.minute = value; break;
    default: components.second = value; break;
    }
    return components;
}

@implementation NSDateComponentsFormatter {
    NSDateComponentsFormatterUnitsStyle _unitsStyle;
    NSDateComponentsFormatterZeroFormattingBehavior _zeroFormattingBehavior;
    NSCalendarUnit _allowedUnits;
    NSCalendar *_calendar;
    NSDate *_referenceDate;
    BOOL _allowsFractionalUnits;
    NSInteger _maximumUnitCount;
    BOOL _collapsesLargestUnit;
    BOOL _includesApproximationPhrase;
    BOOL _includesTimeRemainingPhrase;
    NSFormattingContext _formattingContext;
}

- (instancetype)init
{
    self = [super init];
    if (self)
        _zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorDefault;
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    NSDateComponentsFormatter *copy = [[[self class] allocWithZone:zone] init];
    copy->_unitsStyle = _unitsStyle;
    copy->_zeroFormattingBehavior = _zeroFormattingBehavior;
    copy->_allowedUnits = _allowedUnits;
    copy->_calendar = [_calendar copy];
    copy->_allowsFractionalUnits = _allowsFractionalUnits;
    copy->_maximumUnitCount = _maximumUnitCount;
    copy->_collapsesLargestUnit = _collapsesLargestUnit;
    copy->_includesApproximationPhrase = _includesApproximationPhrase;
    copy->_includesTimeRemainingPhrase = _includesTimeRemainingPhrase;
    return copy;
}

- (NSDateComponentsFormatterUnitsStyle)unitsStyle
{
    return _unitsStyle;
}

- (void)setUnitsStyle:(NSDateComponentsFormatterUnitsStyle)style
{
    _unitsStyle = style;
}

- (NSCalendarUnit)allowedUnits
{
    return _allowedUnits;
}

- (void)setAllowedUnits:(NSCalendarUnit)units
{
    if (units & ~charon_all_units)
        [NSException raise:NSInternalInconsistencyException format:@"Invalid parameter not satisfying: allowedUnits == 0 || !(allowedUnits & ~(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitWeekOfMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond))"];
    _allowedUnits = units;
}

- (NSDateComponentsFormatterZeroFormattingBehavior)zeroFormattingBehavior
{
    return _zeroFormattingBehavior;
}

- (void)setZeroFormattingBehavior:(NSDateComponentsFormatterZeroFormattingBehavior)behavior
{
    _zeroFormattingBehavior = behavior;
}

- (NSCalendar *)calendar
{
    return _calendar;
}

- (void)setCalendar:(NSCalendar *)calendar
{
    _calendar = [calendar copy];
}

- (NSDate *)referenceDate
{
    return _referenceDate;
}

- (void)setReferenceDate:(NSDate *)date
{
    _referenceDate = [date copy];
}

- (BOOL)allowsFractionalUnits
{
    return _allowsFractionalUnits;
}

- (void)setAllowsFractionalUnits:(BOOL)allows
{
    _allowsFractionalUnits = allows;
}

- (NSInteger)maximumUnitCount
{
    return _maximumUnitCount;
}

- (void)setMaximumUnitCount:(NSInteger)count
{
    _maximumUnitCount = count;
}

- (BOOL)collapsesLargestUnit
{
    return _collapsesLargestUnit;
}

- (void)setCollapsesLargestUnit:(BOOL)collapses
{
    _collapsesLargestUnit = collapses;
}

- (BOOL)includesApproximationPhrase
{
    return _includesApproximationPhrase;
}

- (void)setIncludesApproximationPhrase:(BOOL)includes
{
    _includesApproximationPhrase = includes;
}

- (BOOL)includesTimeRemainingPhrase
{
    return _includesTimeRemainingPhrase;
}

- (void)setIncludesTimeRemainingPhrase:(BOOL)includes
{
    _includesTimeRemainingPhrase = includes;
}

- (NSFormattingContext)formattingContext
{
    return _formattingContext;
}

- (void)setFormattingContext:(NSFormattingContext)context
{
    _formattingContext = context;
}

+ (NSString *)localizedStringFromDateComponents:(NSDateComponents *)components unitsStyle:(NSDateComponentsFormatterUnitsStyle)unitsStyle
{
    NSDateComponentsFormatter *formatter = [[NSDateComponentsFormatter alloc] init];
    formatter.unitsStyle = unitsStyle;
    return [formatter stringFromDateComponents:components];
}

- (NSString *)stringForObjectValue:(id)object
{
    return [object isKindOfClass:[NSDateComponents class]] ? [self stringFromDateComponents:object] : nil;
}

- (BOOL)getObjectValue:(id *)object forString:(NSString *)string errorDescription:(NSString **)error
{
    if (error)
        *error = @"Formatter does not support parsing";
    return NO;
}

- (NSString *)stringFromTimeInterval:(NSTimeInterval)interval
{
    if (isnan(interval) || isinf(interval))
        [NSException raise:NSInternalInconsistencyException format:@"Invalid parameter not satisfying: isfinite(timeInterval) && !isnan(timeInterval)"];
    NSDate *start = _referenceDate ?: [NSDate dateWithTimeIntervalSinceReferenceDate:0];
    return [self stringFromDate:start toDate:[start dateByAddingTimeInterval:interval]];
}

- (NSString *)stringFromDateComponents:(NSDateComponents *)components
{
    if (!components)
        [NSException raise:NSInternalInconsistencyException format:@"Invalid parameter not satisfying: components != nil"];
    NSCalendar *calendar = _calendar ?: [NSCalendar currentCalendar];
    NSDate *start = _referenceDate ?: [NSDate dateWithTimeIntervalSinceReferenceDate:0];
    NSDate *end = [calendar dateByAddingComponents:components toDate:start options:0];
    BOOL any = NO;
    for (NSUInteger index = 0; index < charon_unit_count && !any; index++)
        any = charon_value(components, charon_units[index].unit) != NSDateComponentUndefined && charon_value(components, charon_units[index].unit) != 0;
    if (!any && charon_value(components, NSCalendarUnitSecond) == NSDateComponentUndefined && charon_value(components, NSCalendarUnitMinute) == NSDateComponentUndefined && charon_value(components, NSCalendarUnitHour) == NSDateComponentUndefined && charon_value(components, NSCalendarUnitDay) == NSDateComponentUndefined && charon_value(components, NSCalendarUnitWeekOfMonth) == NSDateComponentUndefined && charon_value(components, NSCalendarUnitMonth) == NSDateComponentUndefined && charon_value(components, NSCalendarUnitYear) == NSDateComponentUndefined)
        return nil;
    return [self stringFromDate:start toDate:end];
}

- (NSString *)stringFromDate:(NSDate *)startDate toDate:(NSDate *)endDate
{
    NSCalendar *calendar = _calendar ?: [NSCalendar currentCalendar];
    BOOL negative = [endDate compare:startDate] == NSOrderedAscending;
    NSCalendarUnit allowed = _allowedUnits ?: charon_all_units;
    NSString *body = [self charon_format:startDate to:endDate calendar:calendar allowed:allowed negative:negative];
    if (_includesApproximationPhrase)
        body = [NSString stringWithFormat:@"About %@", body];
    if (_includesTimeRemainingPhrase)
        body = [NSString stringWithFormat:@"%@ remaining", body];
    return body;
}

- (NSArray<NSNumber *> *)charon_valuesFrom:(NSDate *)from to:(NSDate *)to calendar:(NSCalendar *)calendar allowed:(NSCalendarUnit)allowed
{
    NSDateComponents *components = [calendar components:allowed fromDate:from toDate:to options:0];
    NSMutableArray *values = [NSMutableArray array];
    for (NSUInteger index = 0; index < charon_unit_count; index++) {
        if (allowed & charon_units[index].unit)
            [values addObject:@(llabs((long long)charon_value(components, charon_units[index].unit)))];
    }
    return values;
}

- (NSArray<NSNumber *> *)charon_unitsAllowed:(NSCalendarUnit)allowed
{
    NSMutableArray *units = [NSMutableArray array];
    for (NSUInteger index = 0; index < charon_unit_count; index++) {
        if (allowed & charon_units[index].unit)
            [units addObject:@(charon_units[index].unit)];
    }
    return units;
}

- (NSUInteger)charon_dropBits
{
    NSUInteger bits = _zeroFormattingBehavior & (NSDateComponentsFormatterZeroFormattingBehaviorDropAll);
    if (!bits && (_zeroFormattingBehavior & NSDateComponentsFormatterZeroFormattingBehaviorDefault) && !(_zeroFormattingBehavior & NSDateComponentsFormatterZeroFormattingBehaviorPad))
        bits = _unitsStyle == NSDateComponentsFormatterUnitsStylePositional ? NSDateComponentsFormatterZeroFormattingBehaviorDropLeading : NSDateComponentsFormatterZeroFormattingBehaviorDropAll;
    return bits;
}

- (NSArray<NSNumber *> *)charon_displayedIndexes:(NSArray<NSNumber *> *)values before:(NSInteger)cut
{
    NSInteger first = -1, last = -1;
    for (NSInteger index = 0; index < cut; index++) {
        if ([values[index] integerValue] != 0) {
            if (first < 0)
                first = index;
            last = index;
        }
    }
    NSUInteger bits = [self charon_dropBits];
    NSUInteger anyDrop = NSDateComponentsFormatterZeroFormattingBehaviorDropLeading | NSDateComponentsFormatterZeroFormattingBehaviorDropMiddle | NSDateComponentsFormatterZeroFormattingBehaviorDropTrailing;
    NSMutableArray *shown = [NSMutableArray array];
    for (NSInteger index = 0; index < cut; index++) {
        BOOL zero = [values[index] integerValue] == 0;
        BOOL keep = YES;
        if (zero) {
            if (first < 0)
                keep = !(bits & anyDrop) || index == (NSInteger)values.count - 1;
            else if (index < first)
                keep = !(bits & (NSDateComponentsFormatterZeroFormattingBehaviorDropLeading | NSDateComponentsFormatterZeroFormattingBehaviorDropMiddle));
            else if (index > last)
                keep = !(bits & NSDateComponentsFormatterZeroFormattingBehaviorDropTrailing);
            else
                keep = !(bits & NSDateComponentsFormatterZeroFormattingBehaviorDropMiddle);
        }
        if (keep)
            [shown addObject:@(index)];
    }
    return shown;
}

- (BOOL)charon_rounds:(NSInteger)value unit:(NSCalendarUnit)unit larger:(NSCalendarUnit)larger base:(NSDate *)base calendar:(NSCalendar *)calendar
{
    switch (unit) {
    case NSCalendarUnitSecond:
    case NSCalendarUnitMinute:
        return value * 2 >= 60;
    case NSCalendarUnitHour:
        return value * 2 >= 24;
    case NSCalendarUnitDay: {
        NSInteger size = larger == NSCalendarUnitWeekOfMonth ? 7 : larger == NSCalendarUnitYear ? (NSInteger)[calendar rangeOfUnit:NSCalendarUnitDay inUnit:NSCalendarUnitYear forDate:base].length : (NSInteger)[calendar rangeOfUnit:NSCalendarUnitDay inUnit:NSCalendarUnitMonth forDate:base].length;
        return value * 2 > size;
    }
    case NSCalendarUnitWeekOfMonth:
        if (larger == NSCalendarUnitYear)
            return value >= 30;
        return value * 2 > (NSInteger)[calendar rangeOfUnit:NSCalendarUnitDay inUnit:NSCalendarUnitMonth forDate:base].length / 7.0 + 0.999;
    case NSCalendarUnitMonth:
        return value * 2 > 12;
    default:
        return NO;
    }
}

- (NSString *)charon_format:(NSDate *)from to:(NSDate *)to calendar:(NSCalendar *)calendar allowed:(NSCalendarUnit)allowed negative:(BOOL)negative
{
    NSArray<NSNumber *> *units = [self charon_unitsAllowed:allowed];
    if (_unitsStyle == NSDateComponentsFormatterUnitsStylePositional) {
        BOOL started = NO, gap = NO, ended = NO;
        for (NSUInteger index = 0; index < charon_unit_count; index++) {
            BOOL present = (allowed & charon_units[index].unit) != 0;
            if (present && ended)
                gap = YES;
            if (present)
                started = YES;
            else if (started)
                ended = YES;
        }
        if (gap)
            [NSException raise:NSInvalidArgumentException format:@"Specifying positional units with gaps is ambiguous, and therefore unsupported"];
    }
    NSMutableArray<NSNumber *> *values = [[self charon_valuesFrom:from to:to calendar:calendar allowed:allowed] mutableCopy];
    NSInteger count = (NSInteger)values.count;
    NSInteger cut = count, modified = -1;
    if (_maximumUnitCount > 0) {
        for (int pass = 0; pass < 12; pass++) {
            NSMutableArray *nonzero = [NSMutableArray array];
            for (NSInteger index = 0; index < count; index++)
                if ([values[index] integerValue] != 0)
                    [nonzero addObject:@(index)];
            if ((NSInteger)nonzero.count <= _maximumUnitCount)
                break;
            NSInteger leading = [nonzero[_maximumUnitCount] integerValue];
            NSDateComponents *kept = [[NSDateComponents alloc] init];
            for (NSInteger index = 0; index < leading; index++)
                [self charon_add:(negative ? -1 : 1) * [values[index] integerValue] unit:[units[index] unsignedIntegerValue] to:kept];
            if (leading > 0 && [self charon_rounds:[values[leading] integerValue] unit:[units[leading] unsignedIntegerValue] larger:[units[leading - 1] unsignedIntegerValue] base:[calendar dateByAddingComponents:kept toDate:from options:0] calendar:calendar]) {
                for (NSInteger index = leading; index < count; index++)
                    values[index] = @0;
                NSInteger target = leading - 1;
                values[target] = @([values[target] integerValue] + 1);
                modified = modified < 0 ? target : MIN(modified, target);
                while (target > 0) {
                    NSCalendarUnit carried = [units[target] unsignedIntegerValue];
                    NSInteger parent = carried == NSCalendarUnitSecond || carried == NSCalendarUnitMinute ? 60 : carried == NSCalendarUnitHour ? 24 : carried == NSCalendarUnitMonth ? 12 : 0;
                    if (parent <= 0 || [values[target] integerValue] < parent)
                        break;
                    values[target] = @0;
                    values[target - 1] = @([values[target - 1] integerValue] + 1);
                    target--;
                    modified = MIN(modified, target);
                }
            } else {
                cut = leading;
                break;
            }
        }
    }
    NSInteger end = count;
    if (cut < count)
        end = cut;
    else if (modified >= 0)
        end = modified + 1;
    if (_collapsesLargestUnit) {
        NSInteger largest = -1;
        for (NSInteger index = 0; index < end && largest < 0; index++)
            if ([values[index] integerValue] != 0)
                largest = index;
        if (largest >= 0 && largest + 1 < count && [values[largest] integerValue] == 1) {
            NSCalendarUnit unit = [units[largest] unsignedIntegerValue];
            NSCalendarUnit following = [units[largest + 1] unsignedIntegerValue];
            BOOL collapsible = (unit == NSCalendarUnitMonth && following == NSCalendarUnitDay) || (unit == NSCalendarUnitDay && following == NSCalendarUnitHour) || (unit == NSCalendarUnitHour && following == NSCalendarUnitMinute) || (unit == NSCalendarUnitMinute && following == NSCalendarUnitSecond);
            if (collapsible) {
                NSDateComponents *kept = [[NSDateComponents alloc] init];
                for (NSInteger index = 0; index <= largest; index++)
                    [self charon_add:(negative ? -1 : 1) * [values[index] integerValue] unit:[units[index] unsignedIntegerValue] to:kept];
                NSDate *base = [calendar dateByAddingComponents:kept toDate:from options:0];
                NSDate *nextWhole = [calendar dateByAddingComponents:charon_single(unit, negative ? -1 : 1) toDate:base options:0];
                NSDate *nextUnit = [calendar dateByAddingComponents:charon_single(following, negative ? -1 : 1) toDate:base options:0];
                NSTimeInterval ratio = fabs([nextWhole timeIntervalSinceDate:base]) / MAX(1, fabs([nextUnit timeIntervalSinceDate:base]));
                double fraction = [values[largest + 1] integerValue] / ratio;
                if (ratio > 0 && (fraction < 0.1 || fraction > 0.9))
                    return [self charon_format:from to:to calendar:calendar allowed:allowed & ~unit negative:negative];
            }
        }
    }
    NSArray<NSNumber *> *shown = [self charon_displayedIndexes:values before:end];
    return [self charon_join:shown values:values units:units negative:negative];
}

- (void)charon_add:(NSInteger)value unit:(NSCalendarUnit)unit to:(NSDateComponents *)components
{
    switch (unit) {
    case NSCalendarUnitYear: components.year = value; break;
    case NSCalendarUnitMonth: components.month = value; break;
    case NSCalendarUnitWeekOfMonth: components.weekOfMonth = value; break;
    case NSCalendarUnitDay: components.day = value; break;
    case NSCalendarUnitHour: components.hour = value; break;
    case NSCalendarUnitMinute: components.minute = value; break;
    default: components.second = value; break;
    }
}

- (NSString *)charon_number:(NSInteger)value
{
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = _unitsStyle == NSDateComponentsFormatterUnitsStyleSpellOut ? NSNumberFormatterSpellOutStyle : NSNumberFormatterDecimalStyle;
    return [formatter stringFromNumber:@(value)];
}

- (const CharonUnitNames *)charon_names:(NSCalendarUnit)unit
{
    for (NSUInteger index = 0; index < charon_unit_count; index++) {
        if (charon_units[index].unit == unit)
            return &charon_units[index];
    }
    return NULL;
}

- (NSString *)charon_named:(NSInteger)value unit:(NSCalendarUnit)unit
{
    const CharonUnitNames *names = [self charon_names:unit];
    NSString *number = [self charon_number:value];
    BOOL single = value == 1 || value == -1;
    switch (_unitsStyle) {
    case NSDateComponentsFormatterUnitsStylePositional:
    case NSDateComponentsFormatterUnitsStyleAbbreviated:
        return [NSString stringWithFormat:@"%@%s", number, names->abbreviated];
    case NSDateComponentsFormatterUnitsStyleShort:
        return [NSString stringWithFormat:@"%@ %s", number, single ? names->shortSingular : names->shortPlural];
    case NSDateComponentsFormatterUnitsStyleBrief:
        return [NSString stringWithFormat:@"%@%s", number, single ? names->shortSingular : names->shortPlural];
    default:
        return [NSString stringWithFormat:@"%@ %s", number, single ? names->fullSingular : names->fullPlural];
    }
}

- (NSString *)charon_join:(NSArray<NSNumber *> *)shown values:(NSArray<NSNumber *> *)values units:(NSArray<NSNumber *> *)units negative:(BOOL)negative
{
    NSInteger signedIndex = negative && shown.count && [values[[shown[0] integerValue]] integerValue] != 0 ? [shown[0] integerValue] : -1;
    NSInteger (^signedValue)(NSInteger) = ^NSInteger(NSInteger index) {
        NSInteger value = [values[index] integerValue];
        return index == signedIndex ? -value : value;
    };
    NSMutableArray *parts = [NSMutableArray array];
    if (_unitsStyle == NSDateComponentsFormatterUnitsStylePositional) {
        NSMutableArray *time = [NSMutableArray array];
        for (NSNumber *shownIndex in shown) {
            NSInteger index = shownIndex.integerValue;
            NSCalendarUnit unit = [units[index] unsignedIntegerValue];
            if (unit == NSCalendarUnitHour || unit == NSCalendarUnitMinute || unit == NSCalendarUnitSecond)
                [time addObject:shownIndex];
            else
                [parts addObject:[self charon_named:signedValue(index) unit:unit]];
        }
        BOOL contiguous = time.count > 1;
        for (NSUInteger index = 1; contiguous && index < time.count; index++)
            contiguous = [time[index] integerValue] == [time[index - 1] integerValue] + 1;
        BOOL pad = (_zeroFormattingBehavior & NSDateComponentsFormatterZeroFormattingBehaviorPad) != 0;
        if (contiguous) {
            NSMutableString *clock = [NSMutableString string];
            for (NSUInteger index = 0; index < time.count; index++) {
                NSInteger value = signedValue([time[index] integerValue]);
                if (index)
                    [clock appendString:@":"];
                if (index == 0 && !pad)
                    [clock appendString:[self charon_number:value]];
                else
                    [clock appendFormat:@"%@%02ld", value < 0 ? @"-" : @"", (long)labs(value)];
            }
            [parts addObject:clock];
        } else if (time.count == 1 && !parts.count && shown.count == 1) {
            NSInteger value = signedValue([time[0] integerValue]);
            [parts addObject:pad ? [NSString stringWithFormat:@"%@%02ld", value < 0 ? @"-" : @"", (long)labs(value)] : [self charon_number:value]];
        } else {
            for (NSNumber *shownIndex in time) {
                NSInteger index = shownIndex.integerValue;
                [parts addObject:[self charon_named:signedValue(index) unit:[units[index] unsignedIntegerValue]]];
            }
        }
        return [parts componentsJoinedByString:@" "];
    }
    for (NSNumber *shownIndex in shown) {
        NSInteger index = shownIndex.integerValue;
        [parts addObject:[self charon_named:signedValue(index) unit:[units[index] unsignedIntegerValue]]];
    }
    BOOL comma = _unitsStyle == NSDateComponentsFormatterUnitsStyleShort || _unitsStyle == NSDateComponentsFormatterUnitsStyleFull || _unitsStyle == NSDateComponentsFormatterUnitsStyleSpellOut;
    return [parts componentsJoinedByString:comma ? @", " : @" "];
}

@end
