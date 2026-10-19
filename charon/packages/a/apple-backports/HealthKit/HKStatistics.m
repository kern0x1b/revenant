// HKStatistics, HKStatisticsCollection and HKQueryAnchor: what a query of a quantity type is
// answered with, and how far a query has been answered.
//
// A statistics object is computed from the samples it was given, not filled in: the sum, the minimum,
// the maximum and the mean are taken in one unit - the type's own - so that the answers do not depend
// on the unit each sample was saved in, and the quantity that is handed back carries that unit for
// the caller to convert. The per-source answers are computed over the samples of that source alone,
// which is what HKStatisticsOptionSeparateBySource asks for, and what the four per-source readers
// below answer under the port's own names.

#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"

#pragma mark - HKStatistics

@implementation HKStatistics {
    HKQuantityType *_quantityType;
    NSUInteger _dataCount;
    HKQuantity *_sumQuantity;
    HKQuantity *_minimumQuantity;
    HKQuantity *_maximumQuantity;
    HKQuantity *_averageQuantity;
    // bundle identifier -> the four quantities of that source's own samples
    NSMutableDictionary<NSString *, NSDictionary *> *_bySource;
    // bundle identifier -> the HKSource it came from, so that -sources and the per-source answers
    // agree on which sources there are
    NSMutableDictionary<NSString *, HKSource *> *_sourcesByIdentifier;
    // The most recent sample's own quantity and the interval it covers, overall and per source. The four
    // most-recent members of 12.0 ask for a sample rather than an aggregate, and a statistics built by
    // this library keeps aggregates only - so the most recent one is kept as it is passed, which is the
    // only moment the sample's own interval is in hand.
    HKQuantity *_mostRecentQuantity;
    NSDateInterval *_mostRecentInterval;
    NSMutableDictionary<NSString *, NSArray *> *_mostRecentBySource;
}
CHARON_HEALTHKIT_UNCREATABLE_INIT

// The bare allocation both factories and -copyWithZone: build through. The header closes off -init, and
// the raise above is what -init does on the host, so the port's own path is this one.
- (instancetype)charon_init
{
    return [super init];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (instancetype)charon_statisticsForSamples:(NSArray *)samples options:(HKStatisticsOptions)options
{
    HKStatistics *statistics = [[HKStatistics alloc] charon_init];
    statistics->_bySource = [NSMutableDictionary dictionary];
    statistics->_sourcesByIdentifier = [NSMutableDictionary dictionary];
    statistics->_mostRecentBySource = [NSMutableDictionary dictionary];
    statistics->_quantityType = [samples.firstObject isKindOfClass:[HKQuantitySample class]]
                                    ? [(HKQuantitySample *)samples.firstObject quantityType]
                                    : nil;
    if (!statistics->_quantityType) {
        statistics->_dataCount = 0;
        return statistics;
    }
    // The unit every aggregate is taken in: the type's own, read from the SDK's own table of it. A
    // type the SDK counts in a unit this port cannot make has no aggregate, and says so once, in
    // the log, rather than counting its samples in a unit nobody asked for.
    HKUnit *unit = [HKUnit charon_canonicalUnitForType:statistics->_quantityType];
    if (!unit)
        return statistics;

    // One pass over the samples, keeping the whole set and the set of each source.
    NSMutableArray<HKQuantity *> *all = [NSMutableArray array];
    NSMutableDictionary<NSString *, NSMutableArray<HKQuantity *> *> *perSource = [NSMutableDictionary dictionary];
    for (id sample in samples) {
        HKQuantity *quantity = [sample quantity];
        if (![quantity isKindOfClass:[HKQuantity class]])
            continue;
        double value = [quantity doubleValueForUnit:unit];
        HKQuantity *inUnit = [HKQuantity quantityWithUnit:unit doubleValue:value];
        [all addObject:inUnit];
        NSString *key = [(HKObject *)sample source].bundleIdentifier ?: @"";
        NSMutableArray *group = perSource[key];
        if (!group)
            perSource[key] = group = [NSMutableArray array];
        [group addObject:inUnit];
        statistics->_sourcesByIdentifier[key] = [(HKObject *)sample source];

        // The most recent is the one whose interval starts last. A sample of zero length is still a
        // sample, and two that start together keep the first, so the comparison is strict.
        NSDateInterval *interval = [[NSDateInterval alloc] initWithStartDate:[(HKSample *)sample startDate]
                                                                  endDate:[(HKSample *)sample endDate]];
        if (!statistics->_mostRecentInterval ||
            [interval.startDate compare:statistics->_mostRecentInterval.startDate] == NSOrderedDescending) {
            statistics->_mostRecentQuantity = quantity;
            statistics->_mostRecentInterval = interval;
        }
        NSArray *best = statistics->_mostRecentBySource[key];
        if (!best || [interval.startDate compare:[(NSDateInterval *)best[1] startDate]] == NSOrderedDescending)
            statistics->_mostRecentBySource[key] = @[ quantity, interval ];
    }

    statistics->_dataCount = all.count;
    if (all.count) {
        if (options & HKStatisticsOptionCumulativeSum)
            statistics->_sumQuantity = [HKStatistics charon_sumOf:all unit:unit];
        if (options & HKStatisticsOptionDiscreteMin)
            statistics->_minimumQuantity = [HKStatistics charon_extremeOf:all unit:unit wantMinimum:YES];
        if (options & HKStatisticsOptionDiscreteMax)
            statistics->_maximumQuantity = [HKStatistics charon_extremeOf:all unit:unit wantMinimum:NO];
        if (options & HKStatisticsOptionDiscreteAverage)
            statistics->_averageQuantity = [HKStatistics charon_averageOf:all unit:unit];
    }
    if (options & HKStatisticsOptionSeparateBySource) {
        for (NSString *key in perSource)
            statistics->_bySource[key] = [HKStatistics charon_fourOf:perSource[key] unit:unit options:options];
    }
    return statistics;
}

// The four quantities of a set of samples of one source, each only when the caller asked for the
// option that produces it, so that a statistics answer never carries a value the caller did not ask
// to compute.
+ (NSDictionary *)charon_fourOf:(NSArray<HKQuantity *> *)samples unit:(HKUnit *)unit options:(HKStatisticsOptions)options
{
    NSMutableDictionary *four = [NSMutableDictionary dictionary];
    if (options & HKStatisticsOptionCumulativeSum)
        four[@"sum"] = [HKStatistics charon_sumOf:samples unit:unit];
    if (options & HKStatisticsOptionDiscreteMin)
        four[@"min"] = [HKStatistics charon_extremeOf:samples unit:unit wantMinimum:YES];
    if (options & HKStatisticsOptionDiscreteMax)
        four[@"max"] = [HKStatistics charon_extremeOf:samples unit:unit wantMinimum:NO];
    if (options & HKStatisticsOptionDiscreteAverage)
        four[@"average"] = [HKStatistics charon_averageOf:samples unit:unit];
    return four;
}

+ (HKQuantity *)charon_sumOf:(NSArray<HKQuantity *> *)samples unit:(HKUnit *)unit
{
    double total = 0.0;
    for (HKQuantity *quantity in samples)
        total += [quantity doubleValueForUnit:unit];
    return [HKQuantity quantityWithUnit:unit doubleValue:total];
}

+ (HKQuantity *)charon_extremeOf:(NSArray<HKQuantity *> *)samples unit:(HKUnit *)unit wantMinimum:(BOOL)minimum
{
    double best = 0.0;
    BOOL first = YES;
    for (HKQuantity *quantity in samples) {
        double value = [quantity doubleValueForUnit:unit];
        if (first) {
            best = value;
            first = NO;
            continue;
        }
        if (minimum ? value < best : value > best)
            best = value;
    }
    return first ? nil : [HKQuantity quantityWithUnit:unit doubleValue:best];
}

+ (HKQuantity *)charon_averageOf:(NSArray<HKQuantity *> *)samples unit:(HKUnit *)unit
{
    if (!samples.count)
        return nil;
    double total = 0.0;
    for (HKQuantity *quantity in samples)
        total += [quantity doubleValueForUnit:unit];
    return [HKQuantity quantityWithUnit:unit doubleValue:total / (double)samples.count];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _quantityType = [[coder decodeObjectOfClass:[HKQuantityType class] forKey:@"quantityType"] copy];
        _dataCount = (NSUInteger)[coder decodeIntForKey:@"dataCount"];
        _sumQuantity = [[coder decodeObjectOfClass:[HKQuantity class] forKey:@"sum"] copy];
        _minimumQuantity = [[coder decodeObjectOfClass:[HKQuantity class] forKey:@"minimum"] copy];
        _maximumQuantity = [[coder decodeObjectOfClass:[HKQuantity class] forKey:@"maximum"] copy];
        _averageQuantity = [[coder decodeObjectOfClass:[HKQuantity class] forKey:@"average"] copy];
        NSSet *classes = [NSSet setWithObjects:[NSDictionary class], [NSString class], [HKQuantity class], [HKSource class], nil];
        _bySource = [NSMutableDictionary dictionary];
        _sourcesByIdentifier = [NSMutableDictionary dictionary];
        NSDictionary *stored = [coder decodeObjectOfClasses:classes forKey:@"bySource"];
        if (stored)
            [_bySource addEntriesFromDictionary:stored];
        NSDictionary *sources = [coder decodeObjectOfClasses:classes forKey:@"sources"];
        if (sources)
            [_sourcesByIdentifier addEntriesFromDictionary:sources];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_quantityType forKey:@"quantityType"];
    [coder encodeInt:(NSInteger)_dataCount forKey:@"dataCount"];
    [coder encodeObject:_sumQuantity forKey:@"sum"];
    [coder encodeObject:_minimumQuantity forKey:@"minimum"];
    [coder encodeObject:_maximumQuantity forKey:@"maximum"];
    [coder encodeObject:_averageQuantity forKey:@"average"];
    [coder encodeObject:_bySource forKey:@"bySource"];
    [coder encodeObject:_sourcesByIdentifier forKey:@"sources"];
}

- (id)copyWithZone:(NSZone *)zone
{
    HKStatistics *copy = [[HKStatistics alloc] charon_init];
    copy->_quantityType = [_quantityType copy];
    copy->_dataCount = _dataCount;
    copy->_sumQuantity = [_sumQuantity copy];
    copy->_minimumQuantity = [_minimumQuantity copy];
    copy->_maximumQuantity = [_maximumQuantity copy];
    copy->_averageQuantity = [_averageQuantity copy];
    copy->_bySource = [_bySource mutableCopy];
    copy->_sourcesByIdentifier = [_sourcesByIdentifier mutableCopy];
    return copy;
}

- (HKQuantityType *)quantityType
{
    return _quantityType;
}

// No SDK header declares -dataCount on HKStatistics, in 26.2 or in 16.4, and the 8.0 image has no
// such selector: it is Apple's own private member and this port does not answer it. The count is kept
// in the archive and the port's own caller reads it through -charon_count.
- (NSUInteger)charon_count
{
    return _dataCount;
}

- (nullable HKQuantity *)sumQuantity
{
    return _sumQuantity;
}

- (nullable HKQuantity *)minimumQuantity
{
    return _minimumQuantity;
}

- (nullable HKQuantity *)maximumQuantity
{
    return _maximumQuantity;
}

- (nullable HKQuantity *)averageQuantity
{
    return _averageQuantity;
}

// The sources the samples this was computed from came from, in the order the dictionary holds them.
- (nullable NSSet<HKSource *> *)sources
{
    return _sourcesByIdentifier.count ? [NSSet setWithArray:_sourcesByIdentifier.allValues] : nil;
}

- (nullable HKQuantity *)sumQuantityForSource:(HKSource *)source
{
    return _bySource[source.bundleIdentifier ?: @""][@"sum"];
}

- (nullable HKQuantity *)minimumQuantityForSource:(HKSource *)source
{
    return _bySource[source.bundleIdentifier ?: @""][@"min"];
}

- (nullable HKQuantity *)maximumQuantityForSource:(HKSource *)source
{
    return _bySource[source.bundleIdentifier ?: @""][@"max"];
}

- (nullable HKQuantity *)averageQuantityForSource:(HKSource *)source
{
    return _bySource[source.bundleIdentifier ?: @""][@"average"];
}

// What the port's own caller asks the per-source answers for, under the prefix: no SDK header declares
// the four *QuantityBySource readers, so the port does not answer them under their own names.
- (nullable NSArray<HKQuantity *> *)charon_valuesForKey:(NSString *)key
{
    NSMutableArray *values = [NSMutableArray array];
    for (NSDictionary *four in _bySource.allValues) {
        HKQuantity *quantity = four[key];
        if (quantity)
            [values addObject:quantity];
    }
    return values.count ? values : nil;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"HKStatistics %@ over %lu samples", _quantityType.identifier,
                                      (unsigned long)_dataCount];
}

// The four most-recent members of iOS 12.0. A statistics answers these whether or not it was asked for
// them, because the header gives them no option - the option that goes with them, HKStatisticsOption-
// MostRecent, is of 13.0 and is not carried, and the 12.0 image has neither it nor any 16.0 member of
// this class.

- (nullable HKQuantity *)mostRecentQuantity
{
    return _mostRecentQuantity;
}

- (nullable HKQuantity *)mostRecentQuantityForSource:(HKSource *)source
{
    return [[_mostRecentBySource objectForKey:source.bundleIdentifier ?: @""] objectAtIndex:0];
}

- (nullable NSDateInterval *)mostRecentQuantityDateInterval
{
    return _mostRecentInterval;
}

- (nullable NSDateInterval *)mostRecentQuantityDateIntervalForSource:(HKSource *)source
{
    return [[_mostRecentBySource objectForKey:source.bundleIdentifier ?: @""] objectAtIndex:1];
}
@end

#pragma mark - HKStatisticsCollection

@implementation HKStatisticsCollection {
    NSDate *_anchorDate;
    NSDateComponents *_intervalComponents;
    HKStatisticsOptions _options;
    NSCalendar *_calendar;
    NSArray<NSDate *> *_boundaries;
    NSMutableArray<NSMutableArray *> *_groups;
}
CHARON_HEALTHKIT_UNCREATABLE_INIT

// The bare allocation both factories and -copyWithZone: build through, as HKStatistics has above.
- (instancetype)charon_init
{
    return [super init];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (instancetype)charon_collectionWithAnchorDate:(NSDate *)anchorDate
                                       options:(HKStatisticsOptions)options
                            intervalComponents:(NSDateComponents *)intervalComponents
                                      samples:(NSArray *)samples
                                      calendar:(NSCalendar *)calendar
{
    HKStatisticsCollection *collection = [[HKStatisticsCollection alloc] charon_init];
    collection->_anchorDate = [anchorDate copy];
    collection->_intervalComponents = [intervalComponents copy];
    collection->_options = options;
    collection->_calendar = [calendar copy];
    collection->_groups = [NSMutableArray array];
    // The boundaries are the anchor advanced by the interval until the last sample is not before it,
    // and one more past that: the collection has one statistics per interval it spans, and the
    // interval a sample falls in is the one whose two dates hold it.
    NSDate *last = [(HKSample *)samples.lastObject endDate] ?: anchorDate;
    NSMutableArray<NSDate *> *boundaries = [NSMutableArray arrayWithObject:anchorDate];
    NSDate *boundary = anchorDate;
    NSUInteger guard = 0;
    while ([boundary compare:last] == NSOrderedAscending && guard++ < 1000000) {
        NSDate *next = [calendar dateByAddingComponents:intervalComponents toDate:boundary options:0];
        if (!next || [next compare:boundary] != NSOrderedDescending)
            break;
        [boundaries addObject:next];
        boundary = next;
    }
    if (![boundaries.lastObject isEqual:boundary])
        [boundaries addObject:boundary];
    collection->_boundaries = boundaries;
    for (NSUInteger index = 0; index + 1 < boundaries.count; index++)
        [collection->_groups addObject:[NSMutableArray array]];
    for (id sample in samples) {
        NSUInteger index = [collection charon_intervalForDate:[(HKSample *)sample startDate]];
        if (index < collection->_groups.count)
            [collection->_groups[index] addObject:sample];
    }
    return collection;
}

// The interval a date falls in, by comparing it with the boundaries the collection holds.
- (NSUInteger)charon_intervalForDate:(NSDate *)date
{
    for (NSUInteger index = 0; index + 1 < _boundaries.count; index++) {
        if ([date compare:_boundaries[index + 1]] == NSOrderedAscending)
            return index;
    }
    return _boundaries.count ? _boundaries.count - 1 : 0;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _anchorDate = [[coder decodeObjectOfClass:[NSDate class] forKey:@"anchorDate"] copy];
        _intervalComponents = [[coder decodeObjectOfClass:[NSDateComponents class] forKey:@"interval"] copy];
        _options = (HKStatisticsOptions)[coder decodeIntForKey:@"options"];
        _calendar = [NSCalendar currentCalendar];
        _boundaries = @[];
        _groups = [NSMutableArray array];
        NSArray *boundaries = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class], [NSDate class], nil]
                                                  forKey:@"boundaries"];
        if (boundaries)
            _boundaries = boundaries;
        for (NSUInteger index = 0; index < _boundaries.count; index++)
            [_groups addObject:[NSMutableArray array]];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_anchorDate forKey:@"anchorDate"];
    [coder encodeObject:_intervalComponents forKey:@"interval"];
    [coder encodeInt:(NSInteger)_options forKey:@"options"];
    [coder encodeObject:_boundaries forKey:@"boundaries"];
}

- (id)copyWithZone:(NSZone *)zone
{
    HKStatisticsCollection *copy = [[HKStatisticsCollection alloc] charon_init];
    copy->_anchorDate = [_anchorDate copy];
    copy->_intervalComponents = [_intervalComponents copy];
    copy->_options = _options;
    copy->_calendar = [_calendar copy];
    copy->_boundaries = [_boundaries copy];
    copy->_groups = [_groups mutableCopy];
    return copy;
}

- (NSDate *)anchorDate
{
    return _anchorDate;
}

- (NSDateComponents *)intervalComponents
{
    return _intervalComponents;
}

// No SDK header declares -intervalComponentsSinceAnchor on HKStatisticsCollection, in 26.2 or in 16.4,
// and the 8.0 image has no such selector: it is Apple's own, and this port does not answer it. The
// interval is -intervalComponents, and the port's own anchor arithmetic reads the same storage.
// The statistics of the interval a date falls in. An interval the store holds no sample of is an
// interval all the same, and its statistics are an object with a count of zero and no quantity, which
// is what the release answers for an interval nothing was saved in.
- (nullable HKStatistics *)statisticsForDate:(NSDate *)date
{
    NSUInteger index = [self charon_intervalForDate:date];
    if (index >= _groups.count)
        return nil;
    return [HKStatistics charon_statisticsForSamples:_groups[index] options:_options];
}

// Every interval's statistics, in the order the collection holds them. An interval the store holds no
// sample of is an interval all the same and its statistics are an object with a count of zero, so the
// array has one entry per interval and not one per interval that has something in it.
- (NSArray<HKStatistics *> *)statistics
{
    NSMutableArray *all = [NSMutableArray arrayWithCapacity:_groups.count];
    for (NSArray *group in _groups)
        [all addObject:[HKStatistics charon_statisticsForSamples:group options:_options]];
    return all;
}

// The sources the samples behind the intervals came from, over the whole collection, in the order the
// store met them.
- (NSSet<HKSource *> *)sources
{
    NSMutableSet *found = [NSMutableSet set];
    for (NSArray *group in _groups)
        for (id sample in group)
            [found addObject:[(HKObject *)sample source]];
    return found;
}

// A query's interval as the release keeps it: every component that was left unset reads as 0 rather
// than as NSDateComponentUndefined, which is what the host's own HKStatisticsCollectionQuery answers
// for a components object the caller set one field of. Measured by tests/backports/host/healthkit.
+ (NSDateComponents *)charon_normalizedIntervalComponents:(nullable NSDateComponents *)components
{
    if (!components)
        return nil;
    NSDateComponents *normal = [components copy];
    // Through the component's own accessor and not -valueForKey:. NSDateComponents holds each component
    // as an NSNumber and -valueForKey: never returns NSDateComponentUndefined, which is an NSDateComponent
    // enum in NSCalendar.h and not a key: read this way every comparison was false, nothing was set, and
    // the host's own 0 never arrived - which is the difference the differential reported.
    if ([normal era] == NSDateComponentUndefined)
        [normal setEra:0];
    if ([normal year] == NSDateComponentUndefined)
        [normal setYear:0];
    if ([normal month] == NSDateComponentUndefined)
        [normal setMonth:0];
    if ([normal day] == NSDateComponentUndefined)
        [normal setDay:0];
    if ([normal hour] == NSDateComponentUndefined)
        [normal setHour:0];
    if ([normal minute] == NSDateComponentUndefined)
        [normal setMinute:0];
    if ([normal second] == NSDateComponentUndefined)
        [normal setSecond:0];
    if ([normal weekday] == NSDateComponentUndefined)
        [normal setWeekday:0];
    if ([normal weekdayOrdinal] == NSDateComponentUndefined)
        [normal setWeekdayOrdinal:0];
    if ([normal quarter] == NSDateComponentUndefined)
        [normal setQuarter:0];
    if ([normal weekOfMonth] == NSDateComponentUndefined)
        [normal setWeekOfMonth:0];
    if ([normal weekOfYear] == NSDateComponentUndefined)
        [normal setWeekOfYear:0];
    if ([normal yearForWeekOfYear] == NSDateComponentUndefined)
        [normal setYearForWeekOfYear:0];
    return normal;
}

- (void)enumerateStatisticsFromDate:(NSDate *)startDate
                             toDate:(NSDate *)endDate
                           withBlock:(void (^)(HKStatistics *result, BOOL *stop))block
{
    for (NSUInteger index = 0; index + 1 < _boundaries.count; index++) {
        NSDate *from = _boundaries[index], *to = _boundaries[index + 1];
        if (startDate && [to compare:startDate] == NSOrderedAscending)
            continue;
        if (endDate && [from compare:endDate] == NSOrderedDescending)
            break;
        BOOL stop = NO;
        block([HKStatistics charon_statisticsForSamples:_groups[index] options:_options], &stop);
        if (stop)
            return;
    }
}

- (BOOL)isEqual:(id)other
{
    if (self == other)
        return YES;
    if (![other isKindOfClass:[HKStatisticsCollection class]])
        return NO;
    HKStatisticsCollection *that = other;
    return [_anchorDate isEqualToDate:that->_anchorDate] && _boundaries.count == that->_boundaries.count;
}

- (NSUInteger)hash
{
    return _anchorDate.hash ^ _boundaries.count;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"HKStatisticsCollection anchored at %@ over %lu intervals", _anchorDate,
                                      (unsigned long)_boundaries.count];
}

@end