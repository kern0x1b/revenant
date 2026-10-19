#import "CharonUserNotifications.h"

static const NSCalendarUnit CharonDayUnits = NSEraCalendarUnit | NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit
                                           | NSWeekdayCalendarUnit | NSWeekdayOrdinalCalendarUnit | NSWeekOfMonthCalendarUnit
                                           | NSWeekOfYearCalendarUnit | NSYearForWeekOfYearCalendarUnit;

static BOOL charon_given(NSInteger value)
{
    return value != NSUndefinedDateComponent;
}

static BOOL charon_day_matches(NSDateComponents *wanted, NSDateComponents *day, NSInteger firstWeekday, NSInteger highest)
{
    const struct { NSInteger want, have, rank, floor; } fields[] = {
        {wanted.era, day.era, 7, NSUndefinedDateComponent},
        {wanted.year, day.year, 6, NSUndefinedDateComponent},
        {wanted.yearForWeekOfYear, day.yearForWeekOfYear, 6, NSUndefinedDateComponent},
        {wanted.month, day.month, 5, 1},
        {wanted.weekOfYear, day.weekOfYear, 4, NSUndefinedDateComponent},
        {wanted.weekOfMonth, day.weekOfMonth, 4, NSUndefinedDateComponent},
        {wanted.weekdayOrdinal, day.weekdayOrdinal, 3, NSUndefinedDateComponent},
        {wanted.day, day.day, 3, charon_given(wanted.weekday) || charon_given(wanted.weekdayOrdinal) ? NSUndefinedDateComponent : 1},
        {wanted.weekday, day.weekday, 3, NSUndefinedDateComponent},
    };
    for (unsigned index = 0; index < sizeof(fields) / sizeof(*fields); index++) {
        if (charon_given(fields[index].want)) {
            if (fields[index].want != fields[index].have)
                return NO;
        } else if (fields[index].rank < highest && charon_given(fields[index].floor) && fields[index].have != fields[index].floor) {
            return NO;
        }
    }
    if ((charon_given(wanted.weekOfMonth) || charon_given(wanted.weekOfYear)) && !charon_given(wanted.weekday)
        && day.weekday != firstWeekday)
        return NO;
    return YES;
}

static BOOL charon_skips_missing_day(NSCalendar *calendar, NSDateComponents *wanted, NSDateComponents *day, NSDate *dayStart)
{
    if (!charon_given(wanted.day) || charon_given(wanted.weekday) || charon_given(wanted.weekdayOrdinal)
        || charon_given(wanted.weekOfMonth) || charon_given(wanted.weekOfYear))
        return NO;
    NSRange days = [calendar rangeOfUnit:NSDayCalendarUnit inUnit:NSMonthCalendarUnit forDate:dayStart];
    if (day.day != (NSInteger)NSMaxRange(days) - 1 || wanted.day < (NSInteger)NSMaxRange(days))
        return NO;
    return (!charon_given(wanted.month) || wanted.month == day.month) && (!charon_given(wanted.year) || wanted.year == day.year)
        && (!charon_given(wanted.era) || wanted.era == day.era);
}

NSDate *charon_next_date_matching(NSCalendar *calendar, NSDateComponents *wanted, NSDate *after)
{
    if (!wanted || !after)
        return nil;
    calendar = [(wanted.calendar ?: calendar ?: [NSCalendar currentCalendar]) copy];
    if (wanted.timeZone)
        calendar.timeZone = wanted.timeZone;
    const NSInteger ranks[] = {
        charon_given(wanted.second) ? 0 : NSIntegerMax, charon_given(wanted.minute) ? 1 : NSIntegerMax,
        charon_given(wanted.hour) ? 2 : NSIntegerMax,
        charon_given(wanted.day) || charon_given(wanted.weekday) || charon_given(wanted.weekdayOrdinal) ? 3 : NSIntegerMax,
        charon_given(wanted.weekOfMonth) || charon_given(wanted.weekOfYear) ? 4 : NSIntegerMax,
        charon_given(wanted.month) ? 5 : NSIntegerMax,
        charon_given(wanted.year) || charon_given(wanted.yearForWeekOfYear) ? 6 : NSIntegerMax,
        charon_given(wanted.era) ? 7 : NSIntegerMax };
    NSInteger highest = -1;
    for (unsigned index = 0; index < sizeof(ranks) / sizeof(*ranks); index++)
        if (ranks[index] != NSIntegerMax)
            highest = MAX(highest, ranks[index]);
    if (highest < 0)
        return nil;
    NSInteger hours[24], minutes[60], second = charon_given(wanted.second) ? wanted.second : 0;
    NSUInteger hourCount = 0, minuteCount = 0;
    if (charon_given(wanted.hour))
        hours[hourCount++] = wanted.hour;
    else if (highest < 2)
        for (NSInteger hour = 0; hour < 24; hour++)
            hours[hourCount++] = hour;
    else
        hours[hourCount++] = 0;
    if (charon_given(wanted.minute))
        minutes[minuteCount++] = wanted.minute;
    else if (highest < 1)
        for (NSInteger minute = 0; minute < 60; minute++)
            minutes[minuteCount++] = minute;
    else
        minutes[minuteCount++] = 0;

    NSDateComponents *today = [calendar components:NSEraCalendarUnit | NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit
                                          fromDate:after];
    if (charon_given(wanted.year) && (!charon_given(wanted.era) || wanted.era == today.era)) {
        if (wanted.year < today.year)
            return nil;
        if (wanted.year > today.year) {
            today.year = wanted.year;
            today.month = 1;
            today.day = 1;
        }
    }
    NSDate *start = [calendar dateFromComponents:today];
    NSDateComponents *clock = [calendar components:NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit fromDate:after];
    NSDateComponents *step = [[NSDateComponents alloc] init];
    for (NSInteger offset = 0; offset < 366 * 9; offset++) {
        step.day = offset;
        NSDate *dayStart = [calendar dateByAddingComponents:step toDate:start options:0];
        NSDateComponents *day = [calendar components:CharonDayUnits fromDate:dayStart];
        if (!charon_day_matches(wanted, day, (NSInteger)calendar.firstWeekday, highest)) {
            if (!charon_skips_missing_day(calendar, wanted, day, dayStart))
                continue;
            step.day = offset + 1;
            NSDateComponents *next = [calendar components:CharonDayUnits fromDate:[calendar dateByAddingComponents:step toDate:start options:0]];
            NSDateComponents *moment = [[NSDateComponents alloc] init];
            moment.era = next.era;
            moment.year = next.year;
            moment.month = next.month;
            moment.day = next.day;
            moment.hour = charon_given(wanted.hour) ? wanted.hour : clock.hour;
            moment.minute = charon_given(wanted.minute) ? wanted.minute : clock.minute;
            moment.second = charon_given(wanted.second) ? wanted.second : clock.second;
            NSDate *candidate = [calendar dateFromComponents:moment];
            if (candidate && [candidate compare:after] == NSOrderedDescending)
                return candidate;
            continue;
        }
        NSDateComponents *moment = [[NSDateComponents alloc] init];
        moment.era = day.era;
        moment.year = day.year;
        moment.month = day.month;
        moment.day = day.day;
        for (NSUInteger hour = 0; hour < hourCount; hour++)
            for (NSUInteger minute = 0; minute < minuteCount; minute++) {
                moment.hour = hours[hour];
                moment.minute = minutes[minute];
                moment.second = second;
                NSDate *candidate = [calendar dateFromComponents:moment];
                if (!candidate || [candidate compare:after] != NSOrderedDescending)
                    continue;
                NSDateComponents *landed = [calendar components:NSDayCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit
                                                               | NSSecondCalendarUnit fromDate:candidate];
                if (landed.day == moment.day && landed.hour == moment.hour && landed.minute == moment.minute
                    && landed.second == moment.second)
                    return candidate;
            }
    }
    return nil;
}

@implementation UNNotificationTrigger {
@private
    BOOL _repeats;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initCharonWithRepeats:(BOOL)repeats
{
    if ((self = [super init]))
        _repeats = repeats;
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self initCharonWithRepeats:[coder decodeBoolForKey:@"repeats"]];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeBool:_repeats forKey:@"repeats"];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (BOOL)repeats
{
    return _repeats;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    return [object isKindOfClass:[self class]] && [object repeats] == _repeats;
}

- (NSUInteger)hash
{
    return (NSUInteger)_repeats;
}

@end

@implementation UNTimeIntervalNotificationTrigger {
@private
    NSTimeInterval _timeInterval;
}

+ (instancetype)triggerWithTimeInterval:(NSTimeInterval)timeInterval repeats:(BOOL)repeats
{
    return [[self alloc] initCharonWithTimeInterval:timeInterval repeats:repeats];
}

- (instancetype)initCharonWithTimeInterval:(NSTimeInterval)timeInterval repeats:(BOOL)repeats
{
    NSAssert(!repeats || timeInterval >= 60, @"time interval must be at least 60 if repeating");
    NSAssert(timeInterval > 0, @"time interval must be greater than 0");
    if ((self = [super initCharonWithRepeats:repeats]))
        _timeInterval = timeInterval;
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder]))
        _timeInterval = [coder decodeDoubleForKey:@"timeInterval"];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeDouble:_timeInterval forKey:@"timeInterval"];
}

- (NSTimeInterval)timeInterval
{
    return _timeInterval;
}

- (NSDate *)nextTriggerDate
{
    NSDate *now = [NSDate date];
    return [self nextTriggerDateAfterDate:now withRequestedDate:now];
}

- (NSDate *)nextTriggerDateAfterDate:(NSDate *)date withRequestedDate:(NSDate *)requestedDate
{
    NSAssert(date != nil, @"date must not be nil");
    NSAssert(requestedDate != nil, @"requestedDate must not be nil");
    NSTimeInterval requested = requestedDate.timeIntervalSinceReferenceDate, after = date.timeIntervalSinceReferenceDate;
    NSTimeInterval first = requested + _timeInterval;
    if (after < first)
        return [NSDate dateWithTimeIntervalSinceReferenceDate:first];
    if (!self.repeats)
        return nil;
    double passed = floor((after - requested) / _timeInterval) + 1;
    return [NSDate dateWithTimeIntervalSinceReferenceDate:requested + passed * _timeInterval];
}

- (BOOL)isEqual:(id)object
{
    return [super isEqual:object] && [object timeInterval] == _timeInterval;
}

- (NSUInteger)hash
{
    return [super hash] ^ (NSUInteger)_timeInterval;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; repeats: %@, timeInterval: %lf>", [self class], self,
                                      self.repeats ? @"YES" : @"NO", _timeInterval];
}

@end

@implementation UNCalendarNotificationTrigger {
@private
    NSDateComponents *_dateComponents;
}

+ (instancetype)triggerWithDateMatchingComponents:(NSDateComponents *)dateComponents repeats:(BOOL)repeats
{
    return [[self alloc] initCharonWithDateComponents:dateComponents repeats:repeats];
}

- (instancetype)initCharonWithDateComponents:(NSDateComponents *)dateComponents repeats:(BOOL)repeats
{
    if ((self = [super initCharonWithRepeats:repeats]))
        _dateComponents = [dateComponents copy];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder]))
        _dateComponents = [coder decodeObjectOfClass:[NSDateComponents class] forKey:@"matchingDateComponents"];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_dateComponents forKey:@"matchingDateComponents"];
}

- (NSDateComponents *)dateComponents
{
    return _dateComponents;
}

- (NSDate *)nextTriggerDate
{
    NSDate *now = [NSDate date];
    return [self nextTriggerDateAfterDate:now withRequestedDate:now];
}

- (NSDate *)nextTriggerDateAfterDate:(NSDate *)afterDate withRequestedDate:(NSDate *)requestedDate
{
    NSAssert(afterDate != nil, @"afterDate must not be nil");
    NSAssert(requestedDate != nil, @"requestedDate must not be nil");
    if (self.repeats)
        return charon_next_date_matching(nil, _dateComponents, afterDate);
    NSDate *once = charon_next_date_matching(nil, _dateComponents, requestedDate);
    return [once compare:afterDate] == NSOrderedDescending ? once : nil;
}

- (BOOL)isEqual:(id)object
{
    return [super isEqual:object] && [[object dateComponents] isEqual:_dateComponents];
}

- (NSUInteger)hash
{
    return [super hash] ^ _dateComponents.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; dateComponents: %@, repeats: %@>", [self class], self, _dateComponents,
                                      self.repeats ? @"YES" : @"NO"];
}

@end
