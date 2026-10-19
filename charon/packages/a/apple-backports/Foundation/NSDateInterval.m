#import <Foundation/Foundation.h>

@implementation NSDateInterval {
@private
    NSDate *_startDate;
    NSTimeInterval _duration;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)init
{
    return [self initWithStartDate:[NSDate date] duration:0];
}

- (instancetype)initWithStartDate:(NSDate *)startDate duration:(NSTimeInterval)duration
{
    if (!startDate)
        [NSException raise:NSInvalidArgumentException format:@"Start date is nil!"];
    if (duration < 0)
        [NSException raise:NSInvalidArgumentException format:@"Duration is less than 0!"];
    if ((self = [super init])) {
        _startDate = [startDate copy];
        _duration = duration;
    }
    return self;
}

- (instancetype)initWithStartDate:(NSDate *)startDate endDate:(NSDate *)endDate
{
    if (!startDate)
        [NSException raise:NSInvalidArgumentException format:@"Start date is nil!"];
    if (!endDate)
        [NSException raise:NSInvalidArgumentException format:@"End date is nil!"];
    if ([startDate compare:endDate] == NSOrderedDescending)
        [NSException raise:NSGenericException format:@"Start date cannot be later in time than end date!"];
    return [self initWithStartDate:startDate duration:[endDate timeIntervalSinceDate:startDate]];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (!coder.allowsKeyedCoding) {
        [NSException raise:NSInvalidArgumentException format:@"NSDateInterval cannot be decoded by non-keyed archivers"];
        return nil;
    }
    NSDate *start = [coder decodeObjectOfClass:[NSDate class] forKey:@"NS.startDate"];
    if (!start) {
        [coder failWithError:[NSError errorWithDomain:NSCocoaErrorDomain code:NSCoderValueNotFoundError userInfo:nil]];
        return nil;
    }
    NSTimeInterval duration = [coder decodeDoubleForKey:@"NS.duration"];
    if ([coder containsValueForKey:@"NS.duration"])
        return [self initWithStartDate:start duration:duration];
    NSDate *end = [coder decodeObjectOfClass:[NSDate class] forKey:@"NS.endDate"];
    if (coder.error) {
        [coder failWithError:[NSError errorWithDomain:NSCocoaErrorDomain code:NSCoderValueNotFoundError userInfo:nil]];
        return nil;
    }
    return end ? [self initWithStartDate:start endDate:end] : [self initWithStartDate:start duration:duration];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    if (!coder.allowsKeyedCoding) {
        [NSException raise:NSInvalidArgumentException format:@"Encoder does not allow keyed coding!"];
        return;
    }
    [coder encodeObject:self.startDate forKey:@"NS.startDate"];
    [coder encodeObject:self.endDate forKey:@"NS.endDate"];
    [coder encodeDouble:_duration forKey:@"NS.duration"];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (NSDate *)startDate
{
    return _startDate;
}

- (NSDate *)endDate
{
    return [_startDate dateByAddingTimeInterval:_duration];
}

- (NSTimeInterval)duration
{
    return _duration;
}

- (NSComparisonResult)compare:(NSDateInterval *)dateInterval
{
    NSComparisonResult order = [_startDate compare:dateInterval.startDate];
    if (order != NSOrderedSame)
        return order;
    NSTimeInterval other = dateInterval.duration;
    if (_duration < other)
        return NSOrderedAscending;
    return _duration > other ? NSOrderedDescending : NSOrderedSame;
}

- (BOOL)isEqualToDateInterval:(NSDateInterval *)dateInterval
{
    return [_startDate isEqualToDate:dateInterval.startDate] && _duration == dateInterval.duration;
}

- (BOOL)containsDate:(NSDate *)date
{
    if (!date)
        return NO;
    NSTimeInterval when = date.timeIntervalSinceReferenceDate;
    return when >= self.startDate.timeIntervalSinceReferenceDate && when <= self.endDate.timeIntervalSinceReferenceDate;
}

- (BOOL)intersectsDateInterval:(NSDateInterval *)dateInterval
{
    if (!dateInterval)
        return NO;
    return [self containsDate:dateInterval.startDate] || [self containsDate:dateInterval.endDate]
        || [dateInterval containsDate:_startDate] || [dateInterval containsDate:self.endDate];
}

- (NSDateInterval *)intersectionWithDateInterval:(NSDateInterval *)dateInterval
{
    if (!dateInterval)
        return nil;
    if (![self intersectsDateInterval:dateInterval])
        return nil;
    if ([self isEqualToDateInterval:dateInterval])
        return [[NSDateInterval alloc] initWithStartDate:_startDate endDate:self.endDate];
    NSTimeInterval start = MAX(_startDate.timeIntervalSinceReferenceDate, dateInterval.startDate.timeIntervalSinceReferenceDate);
    NSTimeInterval end = MIN(self.endDate.timeIntervalSinceReferenceDate, dateInterval.endDate.timeIntervalSinceReferenceDate);
    return [[NSDateInterval alloc] initWithStartDate:[NSDate dateWithTimeIntervalSinceReferenceDate:start]
                                            endDate:[NSDate dateWithTimeIntervalSinceReferenceDate:end]];
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[NSDateInterval class]])
        return NO;
    return [self isEqualToDateInterval:object];
}

- (NSUInteger)hash
{
    return self.startDate.hash ^ self.endDate.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ (Start Date) %@ + (Duration) %f seconds = (End Date) %@",
                                      [super description], self.startDate, _duration, self.endDate];
}

@end
