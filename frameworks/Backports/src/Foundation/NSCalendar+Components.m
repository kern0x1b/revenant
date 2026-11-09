#import <Foundation/Foundation.h>
#include <math.h>

extern const NSCalendarUnit RevenantCalendarAllUnits;
NSInteger revenant_calendar_nanosecond_exactly(NSDate *date);
NSInteger revenant_calendar_quarter(NSCalendar *calendar, NSDate *date);
NSDateComponents *revenant_calendar_components(NSCalendar *calendar, NSCalendarUnit units, NSDate *date);
NSInteger revenant_calendar_value(NSDateComponents *components, NSCalendarUnit unit);
BOOL revenant_calendar_set_value(NSDateComponents *components, NSCalendarUnit unit, NSInteger value);
NSCalendarUnit revenant_calendar_given_units(NSDateComponents *components);
NSCalendar *revenant_calendar_for_components(NSCalendar *calendar, NSDateComponents *components);

static BOOL revenant_single_unit(NSCalendarUnit unit)
{
    return unit && !(unit & (unit - 1));
}

static NSDate *revenant_start_of_quarter(NSCalendar *calendar, NSDate *date)
{
    NSDateComponents *components = [calendar components:NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth fromDate:date];
    NSInteger quarter = revenant_calendar_quarter(calendar, date);
    if (quarter == NSDateComponentUndefined)
        return nil;
    components.month = (quarter - 1) * 3 + 1;
    components.day = 1;
    components.hour = 0;
    components.minute = 0;
    components.second = 0;
    return [calendar dateFromComponents:components];
}

static NSDate *revenant_start_of_unit(NSCalendar *calendar, NSCalendarUnit unit, NSDate *date, BOOL *supported)
{
    NSDate *start = nil;
    *supported = [calendar rangeOfUnit:unit startDate:&start interval:NULL forDate:date];
    if (!*supported && unit == NSCalendarUnitQuarter) {
        start = revenant_start_of_quarter(calendar, date);
        *supported = start != nil;
    }
    if (!*supported && unit == NSCalendarUnitWeekdayOrdinal)
        *supported = [calendar rangeOfUnit:NSCalendarUnitDay startDate:&start interval:NULL forDate:date];
    return start;
}

static NSComparisonResult revenant_order(double first, double second)
{
    return first == second ? NSOrderedSame : first > second ? NSOrderedDescending : NSOrderedAscending;
}

static BOOL revenant_repeats_months(NSCalendar *calendar)
{
    return [@[@"chinese", @"dangi", @"gujarati", @"kannada", @"marathi", @"telugu", @"vietnamese", @"vikram"] containsObject:calendar.calendarIdentifier];
}

static NSComparisonResult revenant_compare(NSCalendar *calendar, NSDate *first, NSDate *second, NSCalendarUnit unit)
{
    if (!revenant_single_unit(unit))
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
        return revenant_order(floor(floor(one) / 60.0), floor(floor(two) / 60.0));
    case NSCalendarUnitSecond:
        return revenant_order(floor(one), floor(two));
    case NSCalendarUnitNanosecond: {
        double seconds1 = trunc(one), seconds2 = trunc(two);
        if (seconds1 != seconds2)
            return revenant_order(seconds1, seconds2);
        return revenant_order(trunc(1e9 * (one - seconds1)), trunc(1e9 * (two - seconds2)));
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
    BOOL repeats = revenant_repeats_months(calendar);
    for (size_t index = 0; index < count; index++) {
        NSInteger value1 = revenant_calendar_value(components1, units[index]), value2 = revenant_calendar_value(components2, units[index]);
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

static NSInteger revenant_calendar_base_value(NSCalendarUnit unit)
{
    return (unit == NSCalendarUnitMonth || unit == NSCalendarUnitDay) ? 1 : 0;
}

static NSCalendarUnit revenant_calendar_period_unit(NSCalendarUnit unit)
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

static NSDate *revenant_calendar_direct_construct(NSCalendar *calendar, NSDate *date, NSCalendarUnit stepUnit, NSInteger stepValue, NSDateComponents *finerGiven)
{
    static const NSCalendarUnit chain[] = {NSCalendarUnitEra, NSCalendarUnitYear, NSCalendarUnitMonth, NSCalendarUnitDay, NSCalendarUnitHour, NSCalendarUnitMinute, NSCalendarUnitSecond};
    NSDateComponents *components = [calendar components:NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond fromDate:date];
    BOOL reachedStep = NO;
    for (size_t index = 0; index < sizeof chain / sizeof *chain; index++) {
        NSCalendarUnit unit = chain[index];
        if (unit == stepUnit) {
            revenant_calendar_set_value(components, unit, stepValue);
            reachedStep = YES;
            continue;
        }
        if (!reachedStep)
            continue;
        NSInteger given = finerGiven ? revenant_calendar_value(finerGiven, unit) : NSDateComponentUndefined;
        revenant_calendar_set_value(components, unit, given != NSDateComponentUndefined ? given : revenant_calendar_base_value(unit));
    }
    return [calendar dateFromComponents:components];
}

static NSDate *revenant_calendar_roll_by_period(NSCalendar *calendar, NSDate *date, NSCalendarUnit periodUnit, NSInteger delta)
{
    if (!periodUnit)
        return nil;
    NSDateComponents *step = [[NSDateComponents alloc] init];
    revenant_calendar_set_value(step, periodUnit, delta);
    return [calendar dateByAddingComponents:step toDate:date options:0];
}

static NSDate *revenant_calendar_day_candidate(NSCalendar *calendar, NSDate *date, NSInteger monthOffset, NSInteger targetDay, NSDateComponents *finerGiven)
{
    NSDateComponents *base = [calendar components:NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth fromDate:date];
    NSDate *monthAnchor = [calendar dateFromComponents:base];
    if (monthOffset) {
        monthAnchor = revenant_calendar_roll_by_period(calendar, monthAnchor, NSCalendarUnitMonth, monthOffset);
        if (!monthAnchor)
            return nil;
        base = [calendar components:NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth fromDate:monthAnchor];
    }
    NSRange days = [calendar rangeOfUnit:NSCalendarUnitDay inUnit:NSCalendarUnitMonth forDate:monthAnchor];
    if (days.location != NSNotFound && targetDay >= 1 && targetDay <= (NSInteger)days.length) {
        NSDateComponents *full = [base copy];
        full.day = targetDay;
        NSInteger hour = finerGiven ? revenant_calendar_value(finerGiven, NSCalendarUnitHour) : NSDateComponentUndefined;
        full.hour = hour != NSDateComponentUndefined ? hour : 0;
        full.minute = 0;
        full.second = 0;
        return [calendar dateFromComponents:full];
    }
    NSDateComponents *first = [base copy];
    first.day = 1;
    first.hour = 0;
    first.minute = 0;
    first.second = 0;
    NSDate *startOfMonth = [calendar dateFromComponents:first];
    if (!startOfMonth)
        return nil;
    return revenant_calendar_roll_by_period(calendar, startOfMonth, NSCalendarUnitMonth, 1);
}

static NSDate *revenant_calendar_set_weekday(NSCalendar *calendar, NSDate *date, NSInteger value)
{
    NSInteger current = revenant_calendar_value(revenant_calendar_components(calendar, NSCalendarUnitWeekday, date), NSCalendarUnitWeekday);
    if (current == value)
        return date;
    NSDate *startOfWeek = nil;
    if (![calendar rangeOfUnit:NSCalendarUnitWeekOfYear startDate:&startOfWeek interval:NULL forDate:date])
        return nil;
    NSInteger firstWeekday = (NSInteger)calendar.firstWeekday;
    NSInteger offset = ((value - firstWeekday) % 7 + 7) % 7;
    NSDate *direct = revenant_calendar_roll_by_period(calendar, startOfWeek, NSCalendarUnitDay, offset);
    NSDate *reference = nil;
    if (!direct || ![calendar rangeOfUnit:NSCalendarUnitDay startDate:&reference interval:NULL forDate:date])
        return nil;
    if ([direct compare:reference] == NSOrderedAscending)
        direct = revenant_calendar_roll_by_period(calendar, direct, NSCalendarUnitDay, 7);
    return direct;
}

static NSDate *revenant_add_unit(NSCalendar *calendar, NSCalendarUnit unit, NSInteger value, NSDate *date, NSCalendarOptions options)
{
    if (unit == NSCalendarUnitCalendar || unit == NSCalendarUnitTimeZone || value == NSDateComponentUndefined)
        return date;
    if (unit == NSCalendarUnitNanosecond)
        return [date dateByAddingTimeInterval:value / 1000000000.0];
    NSDateComponents *components = [[NSDateComponents alloc] init];
    if (!revenant_calendar_set_value(components, unit, value))
        return nil;
    return [calendar dateByAddingComponents:components toDate:date options:options];
}

typedef NS_ENUM(NSInteger, RevenantMatchPolicy) {
    RevenantMatchPolicyStrict,
    RevenantMatchPolicyNextTime,
    RevenantMatchPolicyNextTimePreserving,
    RevenantMatchPolicyPreviousTimePreserving,
};

static const NSCalendarUnit revenant_chain_units[] = {NSCalendarUnitYear, NSCalendarUnitMonth, NSCalendarUnitDay, NSCalendarUnitHour, NSCalendarUnitMinute, NSCalendarUnitSecond};
static const NSCalendarUnit revenant_chain_mask = NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
static const NSInteger revenant_match_iterations = 5000;

static NSDate *revenant_period_start(NSCalendar *calendar, NSCalendarUnit period, NSDate *date)
{
    if (period == NSCalendarUnitSecond)
        return [NSDate dateWithTimeIntervalSinceReferenceDate:floor(date.timeIntervalSinceReferenceDate)];
    if (period == NSCalendarUnitMinute) {
        NSInteger second = [calendar components:NSCalendarUnitSecond fromDate:date].second;
        return [NSDate dateWithTimeIntervalSinceReferenceDate:floor(date.timeIntervalSinceReferenceDate) - second];
    }
    NSDate *start = nil;
    return [calendar rangeOfUnit:period startDate:&start interval:NULL forDate:date] ? start : nil;
}

static NSDate *revenant_step(NSCalendar *calendar, NSDate *date, NSCalendarUnit unit, NSInteger count)
{
    if (!date)
        return nil;
    if (unit == NSCalendarUnitSecond)
        return [date dateByAddingTimeInterval:count];
    if (unit == NSCalendarUnitMinute)
        return [date dateByAddingTimeInterval:count * 60.0];
    return revenant_add_unit(calendar, unit, count, date, 0);
}

static NSCalendarUnit revenant_finest_given(NSCalendarUnit given)
{
    static const NSCalendarUnit order[] = {NSCalendarUnitSecond, NSCalendarUnitMinute, NSCalendarUnitHour, NSCalendarUnitDay, NSCalendarUnitWeekday, NSCalendarUnitWeekdayOrdinal,
                                           NSCalendarUnitWeekOfMonth, NSCalendarUnitWeekOfYear, NSCalendarUnitMonth, NSCalendarUnitQuarter, NSCalendarUnitYear};
    for (size_t index = 0; index < sizeof order / sizeof *order; index++) {
        if (given & order[index])
            return order[index];
    }
    return 0;
}

static NSCalendarUnit revenant_candidate_period(NSCalendarUnit finest)
{
    switch (finest) {
    case NSCalendarUnitSecond:
    case NSCalendarUnitMinute:
    case NSCalendarUnitHour:
    case NSCalendarUnitYear:
        return finest;
    case NSCalendarUnitMonth:
    case NSCalendarUnitQuarter:
        return NSCalendarUnitMonth;
    default:
        return NSCalendarUnitDay;
    }
}

static NSDate *revenant_with_time(NSCalendar *calendar, NSDate *day, NSInteger hour, NSInteger minute, NSInteger second)
{
    NSDateComponents *components = [calendar components:NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:day];
    components.hour = hour;
    components.minute = minute;
    components.second = second;
    return [calendar dateFromComponents:components];
}

static BOOL revenant_same_wall_time(NSCalendar *calendar, NSDate *first, NSDate *second)
{
    NSDateComponents *one = [calendar components:revenant_chain_mask fromDate:first];
    NSDateComponents *two = [calendar components:revenant_chain_mask fromDate:second];
    return one.year == two.year && one.month == two.month && one.day == two.day && one.hour == two.hour && one.minute == two.minute && one.second == two.second;
}

static double revenant_wall_time(NSCalendar *calendar, NSDate *date)
{
    return date.timeIntervalSinceReferenceDate + [calendar.timeZone secondsFromGMTForDate:date];
}

static NSArray<NSDate *> *revenant_occurrences(NSCalendar *calendar, NSDate *date)
{
    NSMutableArray<NSDate *> *occurrences = [NSMutableArray arrayWithObject:date];
    static const NSTimeInterval shifts[] = {-3600, -1800, 1800, 3600};
    for (size_t index = 0; index < sizeof shifts / sizeof *shifts; index++) {
        NSDate *other = [date dateByAddingTimeInterval:shifts[index]];
        if (revenant_same_wall_time(calendar, date, other))
            [occurrences addObject:other];
    }
    return [occurrences sortedArrayUsingSelector:@selector(compare:)];
}

static NSDate *revenant_pick_occurrence(NSCalendar *calendar, NSDate *date, BOOL forward, NSDate *threshold, NSCalendarOptions options, BOOL wall)
{
    if (!wall) {
        NSComparisonResult order = [date compare:threshold];
        return order == (forward ? NSOrderedDescending : NSOrderedAscending) ? date : nil;
    }
    BOOL last = (options & NSCalendarMatchLast) != 0;
    double thresholdValue = revenant_wall_time(calendar, threshold);
    NSArray<NSDate *> *occurrences = revenant_occurrences(calendar, date);
    NSDate *chosen = nil;
    for (NSDate *candidate in forward ? occurrences : [[occurrences reverseObjectEnumerator] allObjects]) {
        double value = revenant_wall_time(calendar, candidate);
        BOOL beyondWall = forward ? value > thresholdValue : value < thresholdValue;
        BOOL beyondAbsolute = [candidate compare:threshold] == (forward ? NSOrderedDescending : NSOrderedAscending);
        if (!beyondWall && !(last && value == thresholdValue && beyondAbsolute))
            continue;
        if (!chosen || last)
            chosen = candidate;
    }
    return chosen;
}

static NSDate *revenant_occurrence_beside(NSCalendar *calendar, NSDate *date, NSDate *cursor, BOOL forward)
{
    NSArray<NSDate *> *occurrences = revenant_occurrences(calendar, date);
    for (NSDate *candidate in forward ? occurrences : [[occurrences reverseObjectEnumerator] allObjects]) {
        if ([candidate compare:cursor] == (forward ? NSOrderedDescending : NSOrderedAscending))
            return candidate;
    }
    return nil;
}

static BOOL revenant_chain_matches(NSDateComponents *found, NSDateComponents *expected, NSCalendarUnit through)
{
    for (size_t index = 0; index < sizeof revenant_chain_units / sizeof *revenant_chain_units; index++) {
        NSCalendarUnit unit = revenant_chain_units[index];
        if (revenant_calendar_value(found, unit) != revenant_calendar_value(expected, unit))
            return NO;
        if (unit == through)
            break;
    }
    return YES;
}

static BOOL revenant_other_units_match(NSDateComponents *found, NSDateComponents *comps, NSCalendarUnit others)
{
    for (NSCalendarUnit unit = NSCalendarUnitWeekday; unit <= NSCalendarUnitWeekOfYear; unit <<= 1) {
        if ((others & unit) && revenant_calendar_value(found, unit) != revenant_calendar_value(comps, unit))
            return NO;
    }
    return YES;
}

static NSDate *revenant_gap_resolution(NSCalendar *calendar, NSDate *cursor, NSInteger hour, NSInteger minute, NSInteger second, RevenantMatchPolicy policy)
{
    if (policy == RevenantMatchPolicyStrict)
        return nil;
    NSTimeZone *zone = calendar.timeZone;
    NSDate *dayStart = revenant_period_start(calendar, NSCalendarUnitDay, cursor);
    NSDate *transition = dayStart ? [zone nextDaylightSavingTimeTransitionAfterDate:dayStart] : nil;
    if (!transition)
        return nil;
    NSDate *before = [transition dateByAddingTimeInterval:-1];
    NSInteger jump = [zone secondsFromGMTForDate:transition] - [zone secondsFromGMTForDate:before];
    NSDateComponents *wall = [calendar components:NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond fromDate:before];
    NSInteger gapStart = wall.hour * 3600 + wall.minute * 60 + wall.second + 1;
    NSInteger offset = hour * 3600 + minute * 60 + second - gapStart;
    if (jump <= 0 || offset < 0 || offset >= jump)
        return nil;
    if (policy == RevenantMatchPolicyNextTime)
        return transition;
    if (policy == RevenantMatchPolicyNextTimePreserving)
        return [transition dateByAddingTimeInterval:offset];
    return [transition dateByAddingTimeInterval:offset - jump];
}

static NSInteger revenant_time_part(NSDateComponents *comps, NSDateComponents *reference, NSCalendarUnit unit)
{
    NSInteger given = revenant_calendar_value(comps, unit);
    return given != NSDateComponentUndefined ? given : revenant_calendar_value(reference, unit);
}

static NSDate *revenant_missing_day_resolution(NSCalendar *calendar, NSDate *cursor, NSDate *reference, NSDateComponents *comps, RevenantMatchPolicy policy)
{
    if (policy == RevenantMatchPolicyStrict)
        return nil;
    NSDate *monthStart = revenant_period_start(calendar, NSCalendarUnitMonth, cursor);
    NSDate *nextMonth = revenant_step(calendar, monthStart, NSCalendarUnitMonth, 1);
    if (policy == RevenantMatchPolicyNextTime || !nextMonth)
        return nextMonth;
    NSDateComponents *kept = [calendar components:NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond fromDate:reference];
    NSInteger hour = revenant_time_part(comps, kept, NSCalendarUnitHour);
    NSInteger minute = revenant_time_part(comps, kept, NSCalendarUnitMinute);
    NSInteger second = revenant_time_part(comps, kept, NSCalendarUnitSecond);
    if (policy == RevenantMatchPolicyNextTimePreserving)
        return revenant_with_time(calendar, nextMonth, hour, minute, second);
    NSDate *lastDay = revenant_step(calendar, nextMonth, NSCalendarUnitDay, -1);
    return lastDay ? revenant_with_time(calendar, lastDay, hour, minute, second) : nil;
}

static BOOL revenant_next_match(NSCalendar *calendar, NSDate *date, NSDateComponents *comps, NSCalendarUnit given, NSCalendarOptions options, NSDate **result)
{
    const NSCalendarUnit unsupported = NSCalendarUnitEra | NSCalendarUnitYearForWeekOfYear | NSCalendarUnitNanosecond | NSCalendarUnitDayOfYear;
    if (given & unsupported)
        return NO;
    if ((given & NSCalendarUnitQuarter) && revenant_calendar_quarter(calendar, date) <= 0)
        return NO;
    NSCalendarUnit finest = revenant_finest_given(given);
    NSCalendarUnit period = revenant_candidate_period(finest);
    if (!finest || !period)
        return NO;
    BOOL forward = !(options & NSCalendarSearchBackwards);
    NSCalendarUnit chainGiven = given & revenant_chain_mask;
    NSCalendarUnit otherGiven = given & (NSCalendarUnitWeekday | NSCalendarUnitWeekdayOrdinal | NSCalendarUnitQuarter | NSCalendarUnitWeekOfMonth | NSCalendarUnitWeekOfYear);
    BOOL coarseSingle = !(given & (given - 1)) && (given & (NSCalendarUnitDay | NSCalendarUnitWeekday | NSCalendarUnitMonth | NSCalendarUnitQuarter | NSCalendarUnitWeekOfMonth | NSCalendarUnitWeekOfYear));
    RevenantMatchPolicy policy = (options & NSCalendarMatchStrictly) ? RevenantMatchPolicyStrict
        : (options & NSCalendarMatchPreviousTimePreservingSmallerUnits) ? RevenantMatchPolicyPreviousTimePreserving
        : (options & NSCalendarMatchNextTimePreservingSmallerUnits) ? RevenantMatchPolicyNextTimePreserving : RevenantMatchPolicyNextTime;
    NSCalendarUnit coarsest = 0;
    for (size_t index = 0; index < sizeof revenant_chain_units / sizeof *revenant_chain_units && !coarsest; index++) {
        if (chainGiven & revenant_chain_units[index])
            coarsest = revenant_chain_units[index];
    }
    NSCalendarUnit excluded = coarsest == NSCalendarUnitDay ? NSCalendarUnitDay : coarseSingle ? period : 0;
    BOOL wall = coarsest != NSCalendarUnitMinute && coarsest != NSCalendarUnitSecond;
    NSDate *startOfPeriod = revenant_period_start(calendar, period, date);
    NSDate *threshold = (!forward && excluded) ? revenant_period_start(calendar, excluded, date) : date;
    if (!startOfPeriod || !threshold)
        return NO;
    NSCalendarUnit enclosing = coarsest ? revenant_calendar_period_unit(coarsest) : 0;
    NSDate *cursor;
    if (forward && enclosing && enclosing != NSCalendarUnitEra) {
        cursor = revenant_period_start(calendar, enclosing, date);
    } else if (forward) {
        cursor = revenant_step(calendar, startOfPeriod, period, 1);
    } else {
        NSDate *base = revenant_period_start(calendar, period, threshold);
        cursor = [base compare:threshold] == NSOrderedAscending ? base : revenant_step(calendar, base, period, -1);
    }
    NSCalendarUnit read = revenant_chain_mask | otherGiven | NSCalendarUnitWeekday;
    NSDate *fallback = nil;
    NSComparisonResult towardsEnd = forward ? NSOrderedAscending : NSOrderedDescending;
    for (NSInteger iteration = 0; iteration < revenant_match_iterations && cursor; iteration++) {
        if (fallback && [cursor compare:fallback] != towardsEnd) {
            *result = fallback;
            return YES;
        }
        NSDateComponents *found = revenant_calendar_components(calendar, read, cursor);
        NSCalendarUnit mismatch = 0;
        for (size_t index = 0; index < sizeof revenant_chain_units / sizeof *revenant_chain_units; index++) {
            NSCalendarUnit unit = revenant_chain_units[index];
            if ((chainGiven & unit) && revenant_calendar_value(found, unit) != revenant_calendar_value(comps, unit)) {
                mismatch = unit;
                break;
            }
        }
        NSCalendarUnit parent = mismatch ? revenant_calendar_period_unit(mismatch) : 0;
        if (mismatch) {
            NSInteger target = revenant_calendar_value(comps, mismatch);
            NSInteger current = revenant_calendar_value(found, mismatch);
            BOOL reachable = forward ? target > current : target < current;
            NSDate *next = nil;
            BOOL absentDay = mismatch == NSCalendarUnitDay && target > (NSInteger)[calendar rangeOfUnit:NSCalendarUnitDay inUnit:NSCalendarUnitMonth forDate:cursor].length;
            if (absentDay) {
                NSDate *resolved = revenant_missing_day_resolution(calendar, cursor, date, comps, policy);
                if (resolved) {
                    NSComparisonResult order = [resolved compare:date];
                    BOOL beyond = forward ? order == NSOrderedDescending : order == NSOrderedAscending;
                    if (beyond && (!fallback || [resolved compare:fallback] == (forward ? NSOrderedAscending : NSOrderedDescending)))
                        fallback = resolved;
                }
            } else if (reachable) {
                NSDateComponents *expected = [found copy];
                revenant_calendar_set_value(expected, mismatch, target);
                NSDate *landing = revenant_calendar_direct_construct(calendar, cursor, mismatch, target, nil);
                NSDateComponents *landed = landing ? [calendar components:revenant_chain_mask fromDate:landing] : nil;
                if (landed && revenant_chain_matches(landed, expected, mismatch)) {
                    NSDate *instant = revenant_occurrence_beside(calendar, landing, cursor, forward);
                    next = !instant ? nil : forward ? instant : revenant_step(calendar, revenant_step(calendar, instant, mismatch, 1), period, -1);
                } else if (landing) {
                    NSDate *resolved = nil;
                    if (mismatch == NSCalendarUnitHour && revenant_other_units_match(found, comps, otherGiven)) {
                        NSInteger minute = revenant_calendar_value(comps, NSCalendarUnitMinute);
                        NSInteger second = revenant_calendar_value(comps, NSCalendarUnitSecond);
                        resolved = revenant_gap_resolution(calendar, cursor, target, minute == NSDateComponentUndefined ? 0 : minute, second == NSDateComponentUndefined ? 0 : second, policy);
                    }
                    if (resolved) {
                        NSComparisonResult order = [resolved compare:date];
                        BOOL beyond = forward ? order == NSOrderedDescending : order == NSOrderedAscending;
                        if (beyond && (!fallback || [resolved compare:fallback] == (forward ? NSOrderedAscending : NSOrderedDescending)))
                            fallback = resolved;
                    }
                }
            }
            if (!next) {
                if (!parent || parent == NSCalendarUnitEra)
                    break;
                NSDate *parentStart = revenant_period_start(calendar, parent, cursor);
                next = forward ? revenant_step(calendar, parentStart, parent, 1) : revenant_step(calendar, parentStart, period, -1);
            }
            cursor = next;
            continue;
        }
        BOOL aligned = revenant_other_units_match(found, comps, otherGiven);
        if (aligned && (finest == NSCalendarUnitWeekOfMonth || finest == NSCalendarUnitWeekOfYear) && !(given & NSCalendarUnitWeekday))
            aligned = found.weekday == (NSInteger)calendar.firstWeekday;
        if (aligned && finest == NSCalendarUnitQuarter)
            aligned = (found.month - 1) % 3 == 0;
        if (!aligned) {
            if (period == NSCalendarUnitDay || period == NSCalendarUnitHour || period == NSCalendarUnitMinute || period == NSCalendarUnitSecond) {
                NSDate *dayStart = revenant_period_start(calendar, NSCalendarUnitDay, cursor);
                cursor = forward ? revenant_step(calendar, dayStart, NSCalendarUnitDay, 1) : revenant_step(calendar, dayStart, period, -1);
            } else {
                cursor = revenant_step(calendar, cursor, period, forward ? 1 : -1);
            }
            continue;
        }
        NSDate *exact = revenant_pick_occurrence(calendar, cursor, forward, threshold, options, wall);
        if (!exact) {
            NSCalendarUnit outer = coarsest ? revenant_calendar_period_unit(coarsest) : 0;
            if (!outer) {
                cursor = revenant_step(calendar, cursor, period, forward ? 1 : -1);
            } else if (outer == NSCalendarUnitEra) {
                break;
            } else {
                NSDate *outerStart = revenant_period_start(calendar, outer, cursor);
                cursor = forward ? revenant_step(calendar, outerStart, outer, 1) : revenant_step(calendar, outerStart, period, -1);
            }
            continue;
        }
        if (fallback && [fallback compare:exact] == towardsEnd)
            exact = fallback;
        *result = exact;
        return YES;
    }
    *result = fallback;
    return YES;
}

@implementation NSCalendar (RevenantComponents)

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
        *nanosecondValuePointer = revenant_calendar_nanosecond_exactly(date);
}

- (NSInteger)component:(NSCalendarUnit)unit fromDate:(NSDate *)date
{
    if (!revenant_single_unit(unit))
        return NSDateComponentUndefined;
    if (unit == NSCalendarUnitCalendar || unit == NSCalendarUnitTimeZone)
        return 0;
    if (unit == NSCalendarUnitNanosecond)
        return revenant_calendar_nanosecond_exactly(date);
    return revenant_calendar_value(revenant_calendar_components(self, unit, date), unit);
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
    return revenant_start_of_unit(self, NSCalendarUnitDay, date, &supported);
}

- (NSDateComponents *)componentsInTimeZone:(NSTimeZone *)timezone fromDate:(NSDate *)date
{
    NSCalendar *calendar = self;
    if (timezone && ![timezone isEqual:self.timeZone]) {
        calendar = [self copy];
        calendar.timeZone = timezone;
    }
    return revenant_calendar_components(calendar, RevenantCalendarAllUnits, date);
}

- (NSComparisonResult)compareDate:(NSDate *)date1 toDate:(NSDate *)date2 toUnitGranularity:(NSCalendarUnit)unit
{
    return revenant_compare(self, date1, date2, unit);
}

- (BOOL)isDate:(NSDate *)date1 equalToDate:(NSDate *)date2 toUnitGranularity:(NSCalendarUnit)unit
{
    return revenant_single_unit(unit) && revenant_compare(self, date1, date2, unit) == NSOrderedSame;
}

- (BOOL)isDate:(NSDate *)date1 inSameDayAsDate:(NSDate *)date2
{
    return revenant_compare(self, date1, date2, NSCalendarUnitDay) == NSOrderedSame;
}

- (BOOL)isDateInToday:(NSDate *)date
{
    return revenant_compare(self, date, [NSDate date], NSCalendarUnitDay) == NSOrderedSame;
}

- (BOOL)isDateInYesterday:(NSDate *)date
{
    NSDate *yesterday = revenant_add_unit(self, NSCalendarUnitDay, -1, [NSDate date], 0);
    return yesterday && revenant_compare(self, date, yesterday, NSCalendarUnitDay) == NSOrderedSame;
}

- (BOOL)isDateInTomorrow:(NSDate *)date
{
    NSDate *tomorrow = revenant_add_unit(self, NSCalendarUnitDay, 1, [NSDate date], 0);
    return tomorrow && revenant_compare(self, date, tomorrow, NSCalendarUnitDay) == NSOrderedSame;
}

- (NSDateComponents *)components:(NSCalendarUnit)unitFlags fromDateComponents:(NSDateComponents *)startingDateComp toDateComponents:(NSDateComponents *)resultDateComp options:(NSCalendarOptions)options
{
    NSDate *start = [revenant_calendar_for_components(self, startingDateComp) dateFromComponents:startingDateComp];
    NSDate *finish = [revenant_calendar_for_components(self, resultDateComp) dateFromComponents:resultDateComp];
    if (!start || !finish)
        return nil;
    return [self components:unitFlags fromDate:start toDate:finish options:options];
}

- (NSDate *)dateByAddingUnit:(NSCalendarUnit)unit value:(NSInteger)value toDate:(NSDate *)date options:(NSCalendarOptions)options
{
    return revenant_add_unit(self, unit, value, date, options);
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
    NSCalendarUnit given = revenant_calendar_given_units(components);
    NSDateComponents *found = revenant_calendar_components(self, given, date);
    NSCalendarUnit candidates[] = {NSCalendarUnitEra, NSCalendarUnitYear, NSCalendarUnitMonth, NSCalendarUnitDay, NSCalendarUnitHour, NSCalendarUnitMinute, NSCalendarUnitSecond,
                                   NSCalendarUnitWeekday, NSCalendarUnitWeekdayOrdinal, NSCalendarUnitQuarter, NSCalendarUnitWeekOfMonth, NSCalendarUnitWeekOfYear,
                                   NSCalendarUnitYearForWeekOfYear, NSCalendarUnitNanosecond};
    for (size_t index = 0; index < sizeof candidates / sizeof *candidates; index++) {
        if (!(given & candidates[index]))
            continue;
        if (revenant_calendar_value(components, candidates[index]) != revenant_calendar_value(found, candidates[index]))
            return NO;
    }
    return YES;
}

- (NSDate *)dateBySettingUnit:(NSCalendarUnit)unit value:(NSInteger)value ofDate:(NSDate *)date options:(NSCalendarOptions)opts
{
    if (!date)
        return nil;
    if (unit == NSCalendarUnitWeekday)
        return revenant_calendar_set_weekday(self, date, value);
    if (unit == NSCalendarUnitEra || unit == NSCalendarUnitYear || unit == NSCalendarUnitMonth || unit == NSCalendarUnitDay ||
        unit == NSCalendarUnitHour || unit == NSCalendarUnitMinute || unit == NSCalendarUnitSecond) {
        NSInteger current = [self component:unit fromDate:date];
        if (current == value)
            return date;
        NSDate *direct = revenant_calendar_direct_construct(self, date, unit, value, nil);
        if (!direct)
            return nil;
        if (value < current)
            direct = revenant_calendar_roll_by_period(self, direct, revenant_calendar_period_unit(unit), 1) ?: direct;
        return direct;
    }
    NSDateComponents *current = revenant_calendar_components(self, unit, date);
    if (revenant_calendar_value(current, unit) == value)
        return date;
    for (NSInteger distance = 1; distance <= 800; distance++) {
        NSDate *forward = revenant_add_unit(self, NSCalendarUnitDay, distance, date, 0);
        NSDateComponents *forwardParts = forward ? revenant_calendar_components(self, unit, forward) : nil;
        if (forwardParts && revenant_calendar_value(forwardParts, unit) == value)
            return forward;
        NSDate *backward = revenant_add_unit(self, NSCalendarUnitDay, -distance, date, 0);
        NSDateComponents *backwardParts = backward ? revenant_calendar_components(self, unit, backward) : nil;
        if (backwardParts && revenant_calendar_value(backwardParts, unit) == value)
            return backward;
    }
    return nil;
}

- (NSDate *)nextDateAfterDate:(NSDate *)date matchingComponents:(NSDateComponents *)comps options:(NSCalendarOptions)opts
{
    if (!date || !comps)
        return nil;
    NSCalendarUnit given = revenant_calendar_given_units(comps);
    if (!given)
        return nil;
    NSDate *matched = nil;
    if (revenant_next_match(self, date, comps, given, opts, &matched))
        return matched;
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
        NSDate *cursor = revenant_add_unit(self, stepUnit, direction, date, 0);
        if (!cursor)
            return nil;
        for (NSInteger iteration = 0; iteration < 2000000; iteration++) {
            if ([self date:cursor matchesComponents:comps])
                return cursor;
            NSDate *next = revenant_add_unit(self, stepUnit, direction, cursor, 0);
            if (!next)
                return nil;
            cursor = next;
        }
        return nil;
    }
    NSInteger target = revenant_calendar_value(comps, stepUnit);
    NSInteger current = [self component:stepUnit fromDate:date];
    NSDate *direct = stepUnit == NSCalendarUnitDay ? revenant_calendar_day_candidate(self, date, 0, target, comps)
                                                    : revenant_calendar_direct_construct(self, date, stepUnit, target, comps);
    if (!direct)
        return nil;
    BOOL roll;
    if (stepUnit == NSCalendarUnitDay && !forward && target == current)
        roll = YES;
    else
        roll = forward ? !([direct compare:date] == NSOrderedDescending) : !([direct compare:date] == NSOrderedAscending);
    if (roll) {
        if (stepUnit == NSCalendarUnitDay)
            direct = revenant_calendar_day_candidate(self, date, forward ? 1 : -1, target, comps) ?: direct;
        else
            direct = revenant_calendar_roll_by_period(self, direct, revenant_calendar_period_unit(stepUnit), forward ? 1 : -1) ?: direct;
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
