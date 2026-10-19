#import <Foundation/Foundation.h>
#include <math.h>

extern const NSCalendarUnit CharonCalendarAllUnits;
NSInteger charon_calendar_nanosecond_exactly(NSDate *date);
NSInteger charon_calendar_quarter(NSCalendar *calendar, NSDate *date);
NSDateComponents *charon_calendar_components(NSCalendar *calendar, NSCalendarUnit units, NSDate *date);
NSInteger charon_calendar_value(NSDateComponents *components, NSCalendarUnit unit);
BOOL charon_calendar_set_value(NSDateComponents *components, NSCalendarUnit unit, NSInteger value);
NSCalendarUnit charon_calendar_given_units(NSDateComponents *components);
NSCalendar *charon_calendar_for_components(NSCalendar *calendar, NSDateComponents *components);

static BOOL charon_single_unit(NSCalendarUnit unit)
{
    return unit && !(unit & (unit - 1));
}

static NSDate *charon_start_of_quarter(NSCalendar *calendar, NSDate *date)
{
    NSDateComponents *components = [calendar components:NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth fromDate:date];
    NSInteger quarter = charon_calendar_quarter(calendar, date);
    if (quarter == NSDateComponentUndefined)
        return nil;
    components.month = (quarter - 1) * 3 + 1;
    components.day = 1;
    components.hour = 0;
    components.minute = 0;
    components.second = 0;
    return [calendar dateFromComponents:components];
}

static NSDate *charon_start_of_unit(NSCalendar *calendar, NSCalendarUnit unit, NSDate *date, BOOL *supported)
{
    NSDate *start = nil;
    *supported = [calendar rangeOfUnit:unit startDate:&start interval:NULL forDate:date];
    if (!*supported && unit == NSCalendarUnitQuarter) {
        start = charon_start_of_quarter(calendar, date);
        *supported = start != nil;
    }
    if (!*supported && unit == NSCalendarUnitWeekdayOrdinal)
        *supported = [calendar rangeOfUnit:NSCalendarUnitDay startDate:&start interval:NULL forDate:date];
    return start;
}

static NSComparisonResult charon_order(double first, double second)
{
    return first == second ? NSOrderedSame : first > second ? NSOrderedDescending : NSOrderedAscending;
}

static BOOL charon_repeats_months(NSCalendar *calendar)
{
    return [@[@"chinese", @"dangi", @"gujarati", @"kannada", @"marathi", @"telugu", @"vietnamese", @"vikram"] containsObject:calendar.calendarIdentifier];
}

static NSComparisonResult charon_compare(NSCalendar *calendar, NSDate *first, NSDate *second, NSCalendarUnit unit)
{
    if (!charon_single_unit(unit))
        return NSOrderedSame;
    NSComparisonResult fallback = [first compare:second];
    double one = first.timeIntervalSinceReferenceDate, two = second.timeIntervalSinceReferenceDate;
    switch (unit) {
    case NSCalendarUnitCalendar:
    case NSCalendarUnitTimeZone:
        return NSOrderedSame;
    case NSCalendarUnitDay:
    case NSCalendarUnitHour: {
        NSDate *start = nil;
        NSTimeInterval length = 0;
        if (![calendar rangeOfUnit:unit startDate:&start interval:&length forDate:first])
            return fallback;
        double from = start.timeIntervalSinceReferenceDate;
        if (two >= from && two < from + length)
            return NSOrderedSame;
        return two < from ? NSOrderedDescending : NSOrderedAscending;
    }
    case NSCalendarUnitMinute:
        return charon_order(floor(floor(one) / 60.0), floor(floor(two) / 60.0));
    case NSCalendarUnitSecond:
        return charon_order(floor(one), floor(two));
    case NSCalendarUnitNanosecond: {
        double seconds1 = trunc(one), seconds2 = trunc(two);
        if (seconds1 != seconds2)
            return charon_order(seconds1, seconds2);
        return charon_order(trunc(1e9 * (one - seconds1)), trunc(1e9 * (two - seconds2)));
    }
    default:
        break;
    }
    NSCalendarUnit units[5];
    size_t count;
    if (unit == NSCalendarUnitYearForWeekOfYear || unit == NSCalendarUnitWeekOfYear) {
        NSCalendarUnit chosen[] = {NSCalendarUnitEra, NSCalendarUnitYearForWeekOfYear, NSCalendarUnitWeekOfYear, NSCalendarUnitWeekday};
        count = 4;
        memcpy(units, chosen, sizeof chosen);
    } else if (unit == NSCalendarUnitWeekdayOrdinal) {
        NSCalendarUnit chosen[] = {NSCalendarUnitEra, NSCalendarUnitYear, NSCalendarUnitMonth, NSCalendarUnitWeekdayOrdinal, NSCalendarUnitDay};
        count = 5;
        memcpy(units, chosen, sizeof chosen);
    } else if (unit == NSCalendarUnitWeekday || unit == NSCalendarUnitWeekOfMonth) {
        NSCalendarUnit chosen[] = {NSCalendarUnitEra, NSCalendarUnitYear, NSCalendarUnitMonth, NSCalendarUnitWeekOfMonth, NSCalendarUnitWeekday};
        count = 5;
        memcpy(units, chosen, sizeof chosen);
    } else {
        NSCalendarUnit chosen[] = {NSCalendarUnitEra, NSCalendarUnitYear, NSCalendarUnitMonth, NSCalendarUnitDay};
        count = 4;
        memcpy(units, chosen, sizeof chosen);
    }
    NSCalendarUnit all = 0;
    for (size_t index = 0; index < count; index++)
        all |= units[index];
    NSDateComponents *components1 = [calendar components:all fromDate:first], *components2 = [calendar components:all fromDate:second];
    BOOL repeats = charon_repeats_months(calendar);
    for (size_t index = 0; index < count; index++) {
        NSInteger value1 = charon_calendar_value(components1, units[index]), value2 = charon_calendar_value(components2, units[index]);
        if (value1 == NSDateComponentUndefined || value2 == NSDateComponentUndefined)
            return fallback;
        if (value1 != value2)
            return value1 > value2 ? NSOrderedDescending : NSOrderedAscending;
        if (units[index] == NSCalendarUnitMonth && repeats && components1.leapMonth != components2.leapMonth)
            return components2.leapMonth ? NSOrderedAscending : NSOrderedDescending;
        if (units[index] == unit)
            return NSOrderedSame;
    }
    return NSOrderedSame;
}

static NSInteger charon_calendar_base_value(NSCalendarUnit unit)
{
    return (unit == NSCalendarUnitMonth || unit == NSCalendarUnitDay) ? 1 : 0;
}

static NSCalendarUnit charon_calendar_period_unit(NSCalendarUnit unit)
{
    switch (unit) {
    case NSCalendarUnitYear:
        return NSCalendarUnitEra;
    case NSCalendarUnitMonth:
        return NSCalendarUnitYear;
    case NSCalendarUnitDay:
        return NSCalendarUnitMonth;
    case NSCalendarUnitHour:
        return NSCalendarUnitDay;
    case NSCalendarUnitMinute:
        return NSCalendarUnitHour;
    case NSCalendarUnitSecond:
        return NSCalendarUnitMinute;
    default:
        return 0;
    }
}

/*
 * Builds the date the real Foundation builds when it fixes one field of a date: everything
 * coarser than `stepUnit` is kept from `date`, `stepUnit` itself becomes `stepValue`, and
 * everything finer is taken from `finerGiven` (when it names that field) or reset to its
 * period base (day/month: 1, everything else: 0). Measured against Catalyst - see
 * .agent-work/records/nscalendar-newmethods-wip.diff for the probes this came from.
 */
static NSDate *charon_calendar_direct_construct(NSCalendar *calendar, NSDate *date, NSCalendarUnit stepUnit, NSInteger stepValue, NSDateComponents *finerGiven)
{
    static const NSCalendarUnit chain[] = {NSCalendarUnitEra, NSCalendarUnitYear, NSCalendarUnitMonth, NSCalendarUnitDay, NSCalendarUnitHour, NSCalendarUnitMinute, NSCalendarUnitSecond};
    NSDateComponents *components = [calendar components:NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond fromDate:date];
    BOOL reachedStep = NO;
    for (size_t index = 0; index < sizeof chain / sizeof *chain; index++) {
        NSCalendarUnit unit = chain[index];
        if (unit == stepUnit) {
            charon_calendar_set_value(components, unit, stepValue);
            reachedStep = YES;
            continue;
        }
        if (!reachedStep)
            continue;
        NSInteger given = finerGiven ? charon_calendar_value(finerGiven, unit) : NSDateComponentUndefined;
        charon_calendar_set_value(components, unit, given != NSDateComponentUndefined ? given : charon_calendar_base_value(unit));
    }
    return [calendar dateFromComponents:components];
}

static NSDate *charon_calendar_roll_by_period(NSCalendar *calendar, NSDate *date, NSCalendarUnit periodUnit, NSInteger delta)
{
    if (!periodUnit)
        return nil;
    NSDateComponents *step = [[NSDateComponents alloc] init];
    charon_calendar_set_value(step, periodUnit, delta);
    return [calendar dateByAddingComponents:step toDate:date options:0];
}

/*
 * Builds the day=targetDay candidate `monthOffset` months from `date`'s own month, for
 * nextDateAfterDate's Day-stepUnit search. Measured on host: when targetDay does not exist in
 * that month (e.g. day 31 rolled back into a 30-day month), the real search does not clamp the
 * way -[NSCalendar dateFromComponents:] does - it carries the overflow into the following month
 * the way date arithmetic would, and drops every finer given field rather than trying to place
 * them on the carried-into day.
 */
static NSDate *charon_calendar_day_candidate(NSCalendar *calendar, NSDate *date, NSInteger monthOffset, NSInteger targetDay, NSDateComponents *finerGiven)
{
    NSDateComponents *base = [calendar components:NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth fromDate:date];
    NSDate *monthAnchor = [calendar dateFromComponents:base];
    if (monthOffset) {
        monthAnchor = charon_calendar_roll_by_period(calendar, monthAnchor, NSCalendarUnitMonth, monthOffset);
        if (!monthAnchor)
            return nil;
        base = [calendar components:NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth fromDate:monthAnchor];
    }
    NSRange days = [calendar rangeOfUnit:NSCalendarUnitDay inUnit:NSCalendarUnitMonth forDate:monthAnchor];
    if (days.location != NSNotFound && targetDay >= 1 && targetDay <= (NSInteger)days.length) {
        NSDateComponents *full = [base copy];
        full.day = targetDay;
        NSInteger hour = finerGiven ? charon_calendar_value(finerGiven, NSCalendarUnitHour) : NSDateComponentUndefined;
        full.hour = hour != NSDateComponentUndefined ? hour : 0;
        full.minute = 0;
        full.second = 0;
        return [calendar dateFromComponents:full];
    }
    /*
     * Measured on host: an out-of-range day does not carry the excess across the month
     * boundary arithmetically - whatever the overflow, the candidate lands exactly on day 1
     * of the following month, with every finer given field dropped.
     */
    NSDateComponents *first = [base copy];
    first.day = 1;
    first.hour = 0;
    first.minute = 0;
    first.second = 0;
    NSDate *startOfMonth = [calendar dateFromComponents:first];
    if (!startOfMonth)
        return nil;
    return charon_calendar_roll_by_period(calendar, startOfMonth, NSCalendarUnitMonth, 1);
}

static NSDate *charon_calendar_set_weekday(NSCalendar *calendar, NSDate *date, NSInteger value)
{
    NSInteger current = charon_calendar_value(charon_calendar_components(calendar, NSCalendarUnitWeekday, date), NSCalendarUnitWeekday);
    if (current == value)
        return date;
    NSDate *startOfWeek = nil;
    if (![calendar rangeOfUnit:NSCalendarUnitWeekOfYear startDate:&startOfWeek interval:NULL forDate:date])
        return nil;
    NSInteger firstWeekday = (NSInteger)calendar.firstWeekday;
    NSInteger offset = ((value - firstWeekday) % 7 + 7) % 7;
    NSDate *direct = charon_calendar_roll_by_period(calendar, startOfWeek, NSCalendarUnitDay, offset);
    NSDate *reference = nil;
    if (!direct || ![calendar rangeOfUnit:NSCalendarUnitDay startDate:&reference interval:NULL forDate:date])
        return nil;
    if ([direct compare:reference] == NSOrderedAscending)
        direct = charon_calendar_roll_by_period(calendar, direct, NSCalendarUnitDay, 7);
    return direct;
}

static NSDate *charon_add_unit(NSCalendar *calendar, NSCalendarUnit unit, NSInteger value, NSDate *date, NSCalendarOptions options)
{
    if (unit == NSCalendarUnitCalendar || unit == NSCalendarUnitTimeZone || value == NSDateComponentUndefined)
        return date;
    if (unit == NSCalendarUnitNanosecond)
        return [date dateByAddingTimeInterval:value / 1000000000.0];
    NSDateComponents *components = [[NSDateComponents alloc] init];
    if (!charon_calendar_set_value(components, unit, value))
        return nil;
    return [calendar dateByAddingComponents:components toDate:date options:options];
}

@implementation NSCalendar (CharonComponents)

+ (NSCalendar *)calendarWithIdentifier:(NSString *)calendarIdentifierConstant
{
    return [[NSCalendar alloc] initWithCalendarIdentifier:calendarIdentifierConstant];
}

- (void)getEra:(NSInteger *)eraValuePointer year:(NSInteger *)yearValuePointer month:(NSInteger *)monthValuePointer day:(NSInteger *)dayValuePointer fromDate:(NSDate *)date
{
    NSDateComponents *components = [self components:NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:date];
    if (eraValuePointer)
        *eraValuePointer = components.era;
    if (yearValuePointer)
        *yearValuePointer = components.year;
    if (monthValuePointer)
        *monthValuePointer = components.month;
    if (dayValuePointer)
        *dayValuePointer = components.day;
}

- (void)getEra:(NSInteger *)eraValuePointer yearForWeekOfYear:(NSInteger *)yearValuePointer weekOfYear:(NSInteger *)weekValuePointer weekday:(NSInteger *)weekdayValuePointer fromDate:(NSDate *)date
{
    NSDateComponents *components = [self components:NSCalendarUnitEra | NSCalendarUnitYearForWeekOfYear | NSCalendarUnitWeekOfYear | NSCalendarUnitWeekday fromDate:date];
    if (eraValuePointer)
        *eraValuePointer = components.era;
    if (yearValuePointer)
        *yearValuePointer = components.yearForWeekOfYear;
    if (weekValuePointer)
        *weekValuePointer = components.weekOfYear;
    if (weekdayValuePointer)
        *weekdayValuePointer = components.weekday;
}

- (void)getHour:(NSInteger *)hourValuePointer minute:(NSInteger *)minuteValuePointer second:(NSInteger *)secondValuePointer nanosecond:(NSInteger *)nanosecondValuePointer fromDate:(NSDate *)date
{
    NSDateComponents *components = [self components:NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond fromDate:date];
    if (hourValuePointer)
        *hourValuePointer = components.hour;
    if (minuteValuePointer)
        *minuteValuePointer = components.minute;
    if (secondValuePointer)
        *secondValuePointer = components.second;
    if (nanosecondValuePointer)
        *nanosecondValuePointer = charon_calendar_nanosecond_exactly(date);
}

- (NSInteger)component:(NSCalendarUnit)unit fromDate:(NSDate *)date
{
    if (!charon_single_unit(unit))
        return NSDateComponentUndefined;
    if (unit == NSCalendarUnitCalendar || unit == NSCalendarUnitTimeZone)
        return 0;
    if (unit == NSCalendarUnitNanosecond)
        return charon_calendar_nanosecond_exactly(date);
    return charon_calendar_value(charon_calendar_components(self, unit, date), unit);
}

- (NSDate *)dateWithEra:(NSInteger)eraValue year:(NSInteger)yearValue month:(NSInteger)monthValue day:(NSInteger)dayValue hour:(NSInteger)hourValue minute:(NSInteger)minuteValue second:(NSInteger)secondValue nanosecond:(NSInteger)nanosecondValue
{
    NSDateComponents *components = [[NSDateComponents alloc] init];
    components.era = eraValue;
    components.year = yearValue;
    components.month = monthValue;
    components.day = dayValue;
    components.hour = hourValue;
    components.minute = minuteValue;
    components.second = secondValue;
    NSDate *date = [self dateFromComponents:components];
    return nanosecondValue && date ? [date dateByAddingTimeInterval:nanosecondValue / 1000000000.0] : date;
}

- (NSDate *)dateWithEra:(NSInteger)eraValue yearForWeekOfYear:(NSInteger)yearValue weekOfYear:(NSInteger)weekValue weekday:(NSInteger)weekdayValue hour:(NSInteger)hourValue minute:(NSInteger)minuteValue second:(NSInteger)secondValue nanosecond:(NSInteger)nanosecondValue
{
    NSDateComponents *components = [[NSDateComponents alloc] init];
    components.era = eraValue;
    components.yearForWeekOfYear = yearValue;
    components.weekOfYear = weekValue;
    components.weekday = weekdayValue;
    components.hour = hourValue;
    components.minute = minuteValue;
    components.second = secondValue;
    NSDate *date = [self dateFromComponents:components];
    return nanosecondValue && date ? [date dateByAddingTimeInterval:nanosecondValue / 1000000000.0] : date;
}

- (NSDate *)startOfDayForDate:(NSDate *)date
{
    BOOL supported = NO;
    return charon_start_of_unit(self, NSCalendarUnitDay, date, &supported);
}

- (NSDateComponents *)componentsInTimeZone:(NSTimeZone *)timezone fromDate:(NSDate *)date
{
    NSCalendar *calendar = self;
    if (timezone && ![timezone isEqual:self.timeZone]) {
        calendar = [self copy];
        calendar.timeZone = timezone;
    }
    return charon_calendar_components(calendar, CharonCalendarAllUnits, date);
}

- (NSComparisonResult)compareDate:(NSDate *)date1 toDate:(NSDate *)date2 toUnitGranularity:(NSCalendarUnit)unit
{
    return charon_compare(self, date1, date2, unit);
}

- (BOOL)isDate:(NSDate *)date1 equalToDate:(NSDate *)date2 toUnitGranularity:(NSCalendarUnit)unit
{
    return charon_single_unit(unit) && charon_compare(self, date1, date2, unit) == NSOrderedSame;
}

- (BOOL)isDate:(NSDate *)date1 inSameDayAsDate:(NSDate *)date2
{
    return charon_compare(self, date1, date2, NSCalendarUnitDay) == NSOrderedSame;
}

- (BOOL)isDateInToday:(NSDate *)date
{
    return charon_compare(self, date, [NSDate date], NSCalendarUnitDay) == NSOrderedSame;
}

- (BOOL)isDateInYesterday:(NSDate *)date
{
    NSDate *yesterday = charon_add_unit(self, NSCalendarUnitDay, -1, [NSDate date], 0);
    return yesterday && charon_compare(self, date, yesterday, NSCalendarUnitDay) == NSOrderedSame;
}

- (BOOL)isDateInTomorrow:(NSDate *)date
{
    NSDate *tomorrow = charon_add_unit(self, NSCalendarUnitDay, 1, [NSDate date], 0);
    return tomorrow && charon_compare(self, date, tomorrow, NSCalendarUnitDay) == NSOrderedSame;
}

- (NSDateComponents *)components:(NSCalendarUnit)unitFlags fromDateComponents:(NSDateComponents *)startingDateComp toDateComponents:(NSDateComponents *)resultDateComp options:(NSCalendarOptions)options
{
    NSDate *start = [charon_calendar_for_components(self, startingDateComp) dateFromComponents:startingDateComp];
    NSDate *finish = [charon_calendar_for_components(self, resultDateComp) dateFromComponents:resultDateComp];
    if (!start || !finish)
        return nil;
    return [self components:unitFlags fromDate:start toDate:finish options:options];
}

- (NSDate *)dateByAddingUnit:(NSCalendarUnit)unit value:(NSInteger)value toDate:(NSDate *)date options:(NSCalendarOptions)options
{
    return charon_add_unit(self, unit, value, date, options);
}

- (NSDate *)dateBySettingHour:(NSInteger)h minute:(NSInteger)m second:(NSInteger)s ofDate:(NSDate *)date options:(NSCalendarOptions)opts
{
    if (h == NSDateComponentUndefined && m == NSDateComponentUndefined && s == NSDateComponentUndefined)
        return nil;
    h = h == NSDateComponentUndefined ? 0 : h;
    m = m == NSDateComponentUndefined ? 0 : m;
    s = s == NSDateComponentUndefined ? 0 : s;
    if (!NSLocationInRange(h, [self maximumRangeOfUnit:NSCalendarUnitHour]) || !NSLocationInRange(m, [self maximumRangeOfUnit:NSCalendarUnitMinute]) ||
        !NSLocationInRange(s, [self maximumRangeOfUnit:NSCalendarUnitSecond]))
        return nil;
    NSDateComponents *components = [self components:NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:date];
    components.hour = h;
    components.minute = m;
    components.second = s;
    NSDate *candidate = [self dateFromComponents:components];
    NSDateComponents *reached = candidate ? [self components:NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond fromDate:candidate] : nil;
    if (reached && reached.hour == h && reached.minute == m && reached.second == s)
        return candidate;
    if (opts & NSCalendarMatchStrictly) {
        for (NSInteger following = 1; following <= 400; following++) {
            NSDateComponents *day = [[NSDateComponents alloc] init];
            day.day = following;
            NSDate *next = [self dateByAddingComponents:day toDate:date options:0];
            NSDateComponents *parts = next ? [self components:NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:next] : nil;
            if (!parts)
                return nil;
            parts.hour = h;
            parts.minute = m;
            parts.second = s;
            NSDate *exact = [self dateFromComponents:parts];
            NSDateComponents *got = exact ? [self components:NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond fromDate:exact] : nil;
            if (got && got.hour == h && got.minute == m && got.second == s)
                return exact;
        }
        return nil;
    }
    NSDate *transition = [self.timeZone nextDaylightSavingTimeTransitionAfterDate:[self startOfDayForDate:date]];
    return transition && candidate && [transition compare:candidate] == NSOrderedAscending ? transition : candidate;
}

- (BOOL)date:(NSDate *)date matchesComponents:(NSDateComponents *)components
{
    NSCalendarUnit given = charon_calendar_given_units(components);
    NSDateComponents *found = charon_calendar_components(self, given, date);
    NSCalendarUnit candidates[] = {NSCalendarUnitEra, NSCalendarUnitYear, NSCalendarUnitMonth, NSCalendarUnitDay, NSCalendarUnitHour, NSCalendarUnitMinute, NSCalendarUnitSecond,
                                   NSCalendarUnitWeekday, NSCalendarUnitWeekdayOrdinal, NSCalendarUnitQuarter, NSCalendarUnitWeekOfMonth, NSCalendarUnitWeekOfYear,
                                   NSCalendarUnitYearForWeekOfYear, NSCalendarUnitNanosecond};
    for (size_t index = 0; index < sizeof candidates / sizeof *candidates; index++) {
        if (!(given & candidates[index]))
            continue;
        if (charon_calendar_value(components, candidates[index]) != charon_calendar_value(found, candidates[index]))
            return NO;
    }
    return YES;
}

- (NSDate *)dateBySettingUnit:(NSCalendarUnit)unit value:(NSInteger)value ofDate:(NSDate *)date options:(NSCalendarOptions)opts
{
    if (!date)
        return nil;
    if (unit == NSCalendarUnitWeekday)
        return charon_calendar_set_weekday(self, date, value);
    if (unit == NSCalendarUnitEra || unit == NSCalendarUnitYear || unit == NSCalendarUnitMonth || unit == NSCalendarUnitDay ||
        unit == NSCalendarUnitHour || unit == NSCalendarUnitMinute || unit == NSCalendarUnitSecond) {
        NSInteger current = [self component:unit fromDate:date];
        if (current == value)
            return date;
        NSDate *direct = charon_calendar_direct_construct(self, date, unit, value, nil);
        if (!direct)
            return nil;
        if (value < current)
            direct = charon_calendar_roll_by_period(self, direct, charon_calendar_period_unit(unit), 1) ?: direct;
        return direct;
    }
    NSDateComponents *current = charon_calendar_components(self, unit, date);
    if (charon_calendar_value(current, unit) == value)
        return date;
    for (NSInteger distance = 1; distance <= 800; distance++) {
        NSDate *forward = charon_add_unit(self, NSCalendarUnitDay, distance, date, 0);
        NSDateComponents *forwardParts = forward ? charon_calendar_components(self, unit, forward) : nil;
        if (forwardParts && charon_calendar_value(forwardParts, unit) == value)
            return forward;
        NSDate *backward = charon_add_unit(self, NSCalendarUnitDay, -distance, date, 0);
        NSDateComponents *backwardParts = backward ? charon_calendar_components(self, unit, backward) : nil;
        if (backwardParts && charon_calendar_value(backwardParts, unit) == value)
            return backward;
    }
    return nil;
}

- (NSDate *)nextDateAfterDate:(NSDate *)date matchingComponents:(NSDateComponents *)comps options:(NSCalendarOptions)opts
{
    if (!date || !comps)
        return nil;
    NSCalendarUnit given = charon_calendar_given_units(comps);
    if (!given)
        return nil;
    static const NSCalendarUnit chain[] = {NSCalendarUnitEra, NSCalendarUnitYear, NSCalendarUnitMonth, NSCalendarUnitDay, NSCalendarUnitHour, NSCalendarUnitMinute, NSCalendarUnitSecond};
    NSCalendarUnit stepUnit = 0;
    for (size_t i = 0; i < sizeof chain / sizeof *chain; i++) {
        if (given & chain[i]) {
            stepUnit = chain[i];
            break;
        }
    }
    BOOL forward = !(opts & NSCalendarSearchBackwards);
    if (!stepUnit) {
        NSCalendarUnit units[] = {NSCalendarUnitNanosecond, NSCalendarUnitWeekday, NSCalendarUnitWeekdayOrdinal, NSCalendarUnitWeekOfMonth,
                                  NSCalendarUnitWeekOfYear, NSCalendarUnitYearForWeekOfYear, NSCalendarUnitQuarter};
        for (size_t i = 0; i < sizeof units / sizeof *units; i++) {
            if (given & units[i]) {
                stepUnit = units[i];
                break;
            }
        }
        if (!stepUnit)
            return nil;
        NSInteger direction = forward ? 1 : -1;
        NSDate *cursor = charon_add_unit(self, stepUnit, direction, date, 0);
        if (!cursor)
            return nil;
        for (NSInteger iteration = 0; iteration < 2000000; iteration++) {
            if ([self date:cursor matchesComponents:comps])
                return cursor;
            NSDate *next = charon_add_unit(self, stepUnit, direction, cursor, 0);
            if (!next)
                return nil;
            cursor = next;
        }
        return nil;
    }
    NSInteger target = charon_calendar_value(comps, stepUnit);
    NSInteger current = [self component:stepUnit fromDate:date];
    NSDate *direct = stepUnit == NSCalendarUnitDay ? charon_calendar_day_candidate(self, date, 0, target, comps)
                                                    : charon_calendar_direct_construct(self, date, stepUnit, target, comps);
    if (!direct)
        return nil;
    /*
     * The real search compares the constructed instant to `date`, not the target/current pair -
     * a finer given field can validate a same-period candidate even when stepUnit ties (measured
     * on host: day-tie + a later hour stays in the same month for a forward search). The one
     * exception measured on host is Day itself searching backwards on a tie: real Foundation
     * always steps out to the previous month there regardless of any finer field, so that is
     * kept as an explicit override rather than folded into the general comparison.
     */
    BOOL roll;
    if (stepUnit == NSCalendarUnitDay && !forward && target == current)
        roll = YES;
    else
        roll = forward ? !([direct compare:date] == NSOrderedDescending) : !([direct compare:date] == NSOrderedAscending);
    if (roll) {
        if (stepUnit == NSCalendarUnitDay)
            direct = charon_calendar_day_candidate(self, date, forward ? 1 : -1, target, comps) ?: direct;
        else
            direct = charon_calendar_roll_by_period(self, direct, charon_calendar_period_unit(stepUnit), forward ? 1 : -1) ?: direct;
    }
    return direct;
}

- (void)enumerateDatesStartingAfterDate:(NSDate *)start matchingComponents:(NSDateComponents *)comps options:(NSCalendarOptions)opts usingBlock:(void (^)(NSDate *date, BOOL exactMatch, BOOL *stop))block
{
    if (!start || !comps || !block)
        return;
    NSDate *cursor = start;
    for (NSInteger iteration = 0; iteration < 1000; iteration++) {
        NSDate *match = [self nextDateAfterDate:cursor matchingComponents:comps options:opts & ~NSCalendarSearchBackwards];
        if (!match)
            return;
        BOOL exact = [self date:match matchesComponents:comps];
        BOOL stop = NO;
        block(match, exact, &stop);
        if (stop)
            return;
        cursor = match;
    }
}

@end
