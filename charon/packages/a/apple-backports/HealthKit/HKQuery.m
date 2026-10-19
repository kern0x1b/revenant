// HKQuery: what every query of this framework is asked, and the predicates one builds to ask it.
//
// The predicates are the release's own: a real NSPredicate over a real key path, which the store
// then hands to the release's own NSPredicate to decide over the objects it read back. Every key
// path here is one of the HKPredicateKeyPath constants, whose values were read out of iOS 8.0's own
// image, and every one of them is a path a sample of this framework answers: UUID, startDate,
// endDate, source, metadata, value, quantity and - through the correlation a sample belongs to -
// correlation.source, correlation.UUID, correlation.metadata and correlation.workout.

#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"

// The four operators of HKComparisonOperator as NSPredicate spells them. An operator the header does
// not name raises, as the release raises for a comparison it cannot make.
static NSString *CharonHKOperatorSpelling(NSPredicateOperatorType type)
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

// Every query of this library is answered by the store through -charon_run, and the store's
// -executeQuery: asks each one whether it conforms to <CharonHKRunnableQuery> before running it. No
// class adopted that protocol, so -executeQuery: raised "is not a query this store can execute" for
// every query this port has, and the six of 8.0 to 11.0 were never executed by anything that checked.
// The base class adopts it once, here, and every subclass inherits the conformance: the members are the
// four the protocol names, and HKQuery implements all four.
@interface HKQuery (CharonHKRunnable) <CharonHKRunnableQuery>
@end

@implementation HKQuery {
    HKObjectType *_objectType;
    NSPredicate *_predicate;
    dispatch_queue_t _charonQueue;
    BOOL _charonExecuted;
}

+ (BOOL)supportsSecureCoding
{
    return NO;
}

- (instancetype)init
{
    return [super init];
}

// The type of the samples a query is for. It is not always one: an activity summary query's type is
// not a sample type, which is what iOS 9.3 deprecated this name for and gave -objectType instead, and
// the release answers nil here for such a query.
- (nullable HKSampleType *)sampleType
{
    return [_objectType isKindOfClass:[HKSampleType class]] ? (HKSampleType *)_objectType : nil;
}

- (NSPredicate *)predicate
{
    return _predicate;
}

// The header declares -predicate strong and not copy, and a copied HealthKit predicate does not
// evaluate as the one it was copied from: the measured answer for the port's copy was NO where the
// host's own predicate gave YES for the same object. It is held as given, which is what the header says.
- (void)charon_setPredicate:(nullable NSPredicate *)predicate
{
    _predicate = predicate;
}

// -init is NS_UNAVAILABLE on this class, so the allocation is the port's own, and the name is in the
// init family so that a subclass may write `self = [super initWithCharonObjectType:...]` and set its
// own ivars after. It is an instance method rather than a class method because a category's class
// method is not visible through a subclass type and a class extension declared in a header is visible
// only to the one file that implements this class, so neither would reach the five subclass files that
// call it.
//
// An initialiser that wrote `self = [super initWithCharonObjectType:...]` before this existed was left
// as the bare allocation, with no type, no predicate and no handler.
- (instancetype)initWithCharonObjectType:(nullable HKObjectType *)objectType
{
    self = [super init];
    if (self)
        _objectType = (HKObjectType *)[objectType copy];
    return self;
}

- (instancetype)initWithCharonSampleType:(nullable HKSampleType *)sampleType
{
    return [self initWithCharonObjectType:sampleType];
}

// Where a query's handlers are called. The release delivers them on the queue the caller chose with
// the private -setClientQueue:, and on the main queue where it chose none; the header says a handler
// is called on an arbitrary background queue, so the main queue is what this port uses, being the one
// queue a caller can rely on being the one it drew its own handlers in.
- (void)charon_perform:(dispatch_block_t)block
{
    dispatch_async(_charonQueue ?: dispatch_get_main_queue(), block);
}

- (void)charon_setQueue:(dispatch_queue_t)queue
{
    _charonQueue = queue;
}

- (void)charon_setHasBeenExecuted:(BOOL)executed
{
    _charonExecuted = executed;
}

- (BOOL)charon_hasBeenExecuted
{
    return _charonExecuted;
}

// Where a query's handlers are called. The release delivers them on a queue the caller chose with the
// private -setClientQueue:, and on the main queue where it chose none; the header says a handler is
// called on an arbitrary background queue, so the main queue is what this port uses, as it is the one
// queue a caller can rely on being the one it drew its own handlers in.
- (nullable NSPredicate *)charon_predicate
{
    return _predicate;
}

- (nullable HKObjectType *)charon_objectType
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
                                         CharonHKOperatorSpelling(type), value];
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
                                         CharonHKOperatorSpelling(type), quantity];
}

+ (NSPredicate *)predicateForCategorySamplesWithOperatorType:(NSPredicateOperatorType)type value:(NSInteger)value
{
    return [NSPredicate predicateWithFormat:@"%K %@ %d", HKPredicateKeyPathCategoryValue,
                                         CharonHKOperatorSpelling(type), (int)value];
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
                                         CharonHKOperatorSpelling(type), duration];
}

+ (NSPredicate *)predicateForWorkoutsWithOperatorType:(NSPredicateOperatorType)type totalDistance:(HKQuantity *)distance
{
    if (!distance)
        return nil;
    return [NSPredicate predicateWithFormat:@"%K %@ %@", HKPredicateKeyPathWorkoutTotalDistance,
                                         CharonHKOperatorSpelling(type), distance];
}

+ (NSPredicate *)predicateForWorkoutsWithOperatorType:(NSPredicateOperatorType)type totalEnergyBurned:(HKQuantity *)energy
{
    if (!energy)
        return nil;
    return [NSPredicate predicateWithFormat:@"%K %@ %@", HKPredicateKeyPathWorkoutTotalEnergyBurned,
                                         CharonHKOperatorSpelling(type), energy];
}

// The base class has no store of its own to run against: a query is a request, and only a subclass
// knows what to ask the store for. HKHealthStore refuses a query of the base class as the release
// refuses to execute one it has no results for.
- (void)charon_run
{
    [NSException raise:NSInvalidArgumentException
                format:@"An %@ is a request and not a query: execute one of its subclasses.", NSStringFromClass(self.class)];
}

- (void)charon_stop
{
}

@end

@implementation HKQuery (CharonHKRunnable)
@end
