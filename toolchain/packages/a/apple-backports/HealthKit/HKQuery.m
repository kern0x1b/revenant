#import <HealthKit/HealthKit.h>

#import "RevenantHKStore.h"

static NSString *RevenantHKOperatorSpelling(NSPredicateOperatorType type)
{
    switch (type) {
    case NSEqualToPredicateOperatorType:
        return @"==";
    case NSNotEqualToPredicateOperatorType:
        return @"!=";
    case NSLessThanPredicateOperatorType:
        return @"<";
    case NSLessThanOrEqualToPredicateOperatorType:
        return @"<=";
    case NSGreaterThanPredicateOperatorType:
        return @">";
    case NSGreaterThanOrEqualToPredicateOperatorType:
        return @">=";
    default:
        [NSException raise:NSInvalidArgumentException format:@"%ld is not a comparison operator.", (long)type];
        return @"==";
    }
}

@interface HKQuery (RevenantHKRunnable) <RevenantHKRunnableQuery>
@end

@implementation HKQuery {
    HKObjectType *_objectType;
    NSPredicate *_predicate;
    dispatch_queue_t _revenantQueue;
    BOOL _revenantExecuted;
}

+ (BOOL)supportsSecureCoding
{
    return NO;
}

- (instancetype)init
{
    return [super init];
}

- (nullable HKSampleType *)sampleType
{
    return [_objectType isKindOfClass:[HKSampleType class]] ? (HKSampleType *)_objectType : nil;
}

- (NSPredicate *)predicate
{
    return _predicate;
}

- (void)revenant_setPredicate:(nullable NSPredicate *)predicate
{
    _predicate = predicate;
}

- (instancetype)initWithRevenantObjectType:(nullable HKObjectType *)objectType
{
    self = [super init];
    if (self)
        _objectType = (HKObjectType *)[objectType copy];
    return self;
}

- (instancetype)initWithRevenantSampleType:(nullable HKSampleType *)sampleType
{
    return [self initWithRevenantObjectType:sampleType];
}

- (void)revenant_perform:(dispatch_block_t)block
{
    dispatch_async(_revenantQueue ?: dispatch_get_main_queue(), block);
}

- (void)revenant_setQueue:(dispatch_queue_t)queue
{
    _revenantQueue = queue;
}

- (void)revenant_setHasBeenExecuted:(BOOL)executed
{
    _revenantExecuted = executed;
}

- (BOOL)revenant_hasBeenExecuted
{
    return _revenantExecuted;
}

- (nullable NSPredicate *)revenant_predicate
{
    return _predicate;
}

- (nullable HKObjectType *)revenant_objectType
{
    return _objectType;
}

#pragma mark - The predicates of the header

+ (NSPredicate *)predicateForObjectWithUUID:(NSUUID *)uuid
{
    if (!uuid)
        return nil;
    return [NSPredicate predicateWithFormat:@"%K == %@", HKPredicateKeyPathUUID, uuid];
}

+ (NSPredicate *)predicateForObjectsWithUUIDs:(NSSet<NSUUID *> *)uuids
{
    return [NSPredicate predicateWithFormat:@"%K IN %@", HKPredicateKeyPathUUID, uuids];
}

+ (NSPredicate *)predicateForObjectsFromSource:(HKSource *)source
{
    if (!source)
        return nil;
    return [NSPredicate predicateWithFormat:@"%K == %@", HKPredicateKeyPathSource, source];
}

+ (NSPredicate *)predicateForObjectsFromSources:(NSSet<HKSource *> *)sources
{
    return [NSPredicate predicateWithFormat:@"%K IN %@", HKPredicateKeyPathSource, sources];
}

+ (NSPredicate *)predicateForObjectsWithMetadataKey:(NSString *)key
{
    if (!key)
        return nil;
    return [NSPredicate predicateWithFormat:@"%K.%K != nil", HKPredicateKeyPathMetadata, key];
}

+ (NSPredicate *)predicateForObjectsWithMetadataKey:(NSString *)key allowedValues:(NSSet *)allowedValues
{
    if (!key)
        return nil;
    return [NSPredicate predicateWithFormat:@"%K.%K IN %@", HKPredicateKeyPathMetadata, key, allowedValues];
}

+ (NSPredicate *)predicateForObjectsWithMetadataKey:(NSString *)key operatorType:(NSPredicateOperatorType)type value:(id)value
{
    if (!key)
        return nil;
    return [NSPredicate predicateWithFormat:@"%K.%K %@ %@", HKPredicateKeyPathMetadata, key,
                                         RevenantHKOperatorSpelling(type), value];
}

+ (NSPredicate *)predicateForObjectsWithNoCorrelation
{
    return [NSPredicate predicateWithFormat:@"%K == nil", HKPredicateKeyPathCorrelation];
}

+ (NSPredicate *)predicateForObjectsFromWorkout:(HKWorkout *)workout
{
    if (!workout)
        return nil;
    return [NSPredicate predicateWithFormat:@"%K == %@", HKPredicateKeyPathWorkout, workout];
}

+ (NSPredicate *)predicateForQuantitySamplesWithOperatorType:(NSPredicateOperatorType)type quantity:(HKQuantity *)quantity
{
    if (!quantity)
        return nil;
    return [NSPredicate predicateWithFormat:@"%K %@ %@", HKPredicateKeyPathQuantity,
                                         RevenantHKOperatorSpelling(type), quantity];
}

+ (NSPredicate *)predicateForCategorySamplesWithOperatorType:(NSPredicateOperatorType)type value:(NSInteger)value
{
    return [NSPredicate predicateWithFormat:@"%K %@ %d", HKPredicateKeyPathCategoryValue,
                                         RevenantHKOperatorSpelling(type), (int)value];
}

+ (NSPredicate *)predicateForCategorySamplesEqualToValues:(NSSet<NSNumber *> *)values
{
    return [NSPredicate predicateWithFormat:@"%K IN %@", HKPredicateKeyPathCategoryValue, values];
}

+ (NSPredicate *)predicateForSamplesWithStartDate:(NSDate *)startDate endDate:(NSDate *)endDate options:(HKQueryOptions)options
{
    if (!startDate && !endDate)
        return nil;
    NSMutableArray *parts = [NSMutableArray array];
    if (startDate)
        [parts addObject:[NSPredicate predicateWithFormat:@"%K >= %@", HKPredicateKeyPathStartDate, startDate]];
    if (endDate)
        [parts addObject:[NSPredicate predicateWithFormat:@"%K <= %@", HKPredicateKeyPathEndDate, endDate]];
    if (options & HKQueryOptionStrictStartDate)
        [parts addObject:[NSPredicate predicateWithFormat:@"%K < %@", HKPredicateKeyPathEndDate, endDate]];
    if (options & HKQueryOptionStrictEndDate)
        [parts addObject:[NSPredicate predicateWithFormat:@"%K > %@", HKPredicateKeyPathStartDate, startDate]];
    if (!parts.count)
        return nil;
    return parts.count == 1 ? parts[0] : [NSCompoundPredicate andPredicateWithSubpredicates:parts];
}

+ (NSPredicate *)predicateForWorkoutsWithWorkoutActivityType:(HKWorkoutActivityType)type
{
    return [NSPredicate predicateWithFormat:@"%K == %d", HKPredicateKeyPathWorkoutType, (int)type];
}

+ (NSPredicate *)predicateForWorkoutsWithOperatorType:(NSPredicateOperatorType)type duration:(NSTimeInterval)duration
{
    return [NSPredicate predicateWithFormat:@"%K %@ %f", HKPredicateKeyPathWorkoutDuration,
                                         RevenantHKOperatorSpelling(type), duration];
}

+ (NSPredicate *)predicateForWorkoutsWithOperatorType:(NSPredicateOperatorType)type totalDistance:(HKQuantity *)distance
{
    if (!distance)
        return nil;
    return [NSPredicate predicateWithFormat:@"%K %@ %@", HKPredicateKeyPathWorkoutTotalDistance,
                                         RevenantHKOperatorSpelling(type), distance];
}

+ (NSPredicate *)predicateForWorkoutsWithOperatorType:(NSPredicateOperatorType)type totalEnergyBurned:(HKQuantity *)energy
{
    if (!energy)
        return nil;
    return [NSPredicate predicateWithFormat:@"%K %@ %@", HKPredicateKeyPathWorkoutTotalEnergyBurned,
                                         RevenantHKOperatorSpelling(type), energy];
}

- (void)revenant_run
{
    [NSException raise:NSInvalidArgumentException
                format:@"An %@ is a request and not a query: execute one of its subclasses.", NSStringFromClass(self.class)];
}

- (void)revenant_stop
{
}

@end

@implementation HKQuery (RevenantHKRunnable)
@end
