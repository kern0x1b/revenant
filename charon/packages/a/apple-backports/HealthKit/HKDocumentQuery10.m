// The iOS 10.0 members of the classes of iOS 8.0 and 9.0, and the document query of that release.

#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"

#pragma mark - HKDocumentQuery

@implementation HKDocumentQuery {
    HKDocumentType *_documentType;
    NSPredicate *_predicate;
    NSUInteger _limit;
    NSArray<NSSortDescriptor *> *_sortDescriptors;
    BOOL _includeDocumentData;
    void (^_resultsHandler)(HKDocumentQuery *query, NSArray<HKDocumentSample *> *_Nullable results, NSError *_Nullable error);
}

- (instancetype)initWithDocumentType:(HKDocumentType *)documentType
                           predicate:(nullable NSPredicate *)predicate
                               limit:(NSUInteger)limit
                    sortDescriptors:(nullable NSArray<NSSortDescriptor *> *)sortDescriptors
                 includeDocumentData:(BOOL)includeDocumentData
                      resultsHandler:(void (^)(HKDocumentQuery *query, NSArray<HKDocumentSample *> *_Nullable results,
                                               NSError *_Nullable error))handler
{
    HKDocumentQuery *query = [super initWithCharonSampleType:documentType];
    if (query) {
        query->_documentType = documentType;
        [query charon_setPredicate:predicate];
        query->_limit = limit;
        query->_sortDescriptors = [sortDescriptors copy];
        query->_includeDocumentData = includeDocumentData;
        query->_resultsHandler = [handler copy];
        query.charon_stopsAfterResults = YES;
    }
    return query;
}

- (HKDocumentType *)documentType
{
    return _documentType;
}

- (NSUInteger)limit
{
    return _limit;
}

- (NSArray<NSSortDescriptor *> *)sortDescriptors
{
    return _sortDescriptors;
}

// Whether the documents themselves come back with the samples, which is what the header's flag asks
// for and what a caller that reads the data of each document needs.
- (BOOL)includeDocumentData
{
    return _includeDocumentData;
}

- (void)charon_run
{
    NSError *error = nil;
    NSArray<HKDocumentSample *> *found = [[CharonHKStore sharedStore] documentsOfType:_documentType
                                                                               predicate:self.charon_predicate
                                                                                  limit:_limit
                                                                          sortDescriptors:_sortDescriptors
                                                                      includeDocumentData:_includeDocumentData
                                                                                  error:&error];
    [self charon_perform:^{
        if (self->_resultsHandler)
            self->_resultsHandler(self, found ?: @[], error);
    }];
}

- (void)charon_stop
{
    _resultsHandler = nil;
}

@end

#pragma mark - The iOS 10.0 members of HKWorkout, HKWorkoutEvent and HKQuery

@implementation HKWorkout (CharonIOS100)

- (nullable HKQuantity *)totalSwimmingStrokeCount
{
    return [self charon_totalSwimmingStrokeCount];
}

// The release's own factory of 10.0: the form of 9.0 with the length of the swim added. The stroke
// count is kept as it is given and read back, and the duration is the one the factory is given.
+ (instancetype)workoutWithActivityType:(HKWorkoutActivityType)activityType
                              startDate:(NSDate *)startDate
                                endDate:(NSDate *)endDate
                         workoutEvents:(NSArray<HKWorkoutEvent *> *)workoutEvents
                    totalEnergyBurned:(nullable HKQuantity *)totalEnergyBurned
                      totalDistance:(nullable HKQuantity *)totalDistance
           totalSwimmingStrokeCount:(nullable HKQuantity *)totalSwimmingStrokeCount
                                device:(nullable HKDevice *)device
                              metadata:(nullable NSDictionary *)metadata
{
    HKWorkout *workout = [[HKWorkout alloc] charon_initWithType:[HKObjectType workoutType]
                                                       metadata:metadata
                                                      startDate:startDate
                                                        endDate:endDate
                                                       duration:[endDate timeIntervalSinceDate:startDate]];
    if (workout) {
        [workout charon_setWorkoutActivityType:activityType];
        [workout charon_setTotalEnergyBurned:totalEnergyBurned totalDistance:totalDistance];
        [workout charon_setTotalSwimmingStrokeCount:totalSwimmingStrokeCount];
        [workout charon_setWorkoutEvents:workoutEvents];
        [workout charon_setDevice:device];
    }
    return workout;
}

@end

@implementation HKWorkoutEvent (CharonIOS100)

+ (instancetype)workoutEventWithType:(HKWorkoutEventType)type
                                date:(NSDate *)date
                           metadata:(NSDictionary *)metadata
{
    HKWorkoutEvent *event = [[self alloc] charon_initWithType:type date:date];
    [event charon_setMetadata:metadata];
    return event;
}

- (nullable NSDictionary *)metadata
{
    return [self charon_storedMetadata];
}

@end

@implementation HKQuery (CharonIOS100)

// A predicate over the length of a swim, over the key path that names it.
+ (NSPredicate *)predicateForWorkoutsWithOperatorType:(NSPredicateOperatorType)type
                              totalSwimmingStrokeCount:(HKQuantity *)count
{
    if (![count isKindOfClass:[HKQuantity class]])
        return nil;
    return [NSPredicate predicateWithFormat:@"%K %@ %@", HKPredicateKeyPathWorkoutTotalSwimmingStrokeCount,
                                         [HKQuery charon_predicateOperatorSpellingFor:type], count];
}

@end
