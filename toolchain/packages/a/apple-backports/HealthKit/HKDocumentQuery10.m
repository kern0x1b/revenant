#import <HealthKit/HealthKit.h>

#import "RevenantHKStore.h"

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
    HKDocumentQuery *query = [super initWithRevenantSampleType:documentType];
    if (query) {
        query->_documentType = documentType;
        [query revenant_setPredicate:predicate];
        query->_limit = limit;
        query->_sortDescriptors = [sortDescriptors copy];
        query->_includeDocumentData = includeDocumentData;
        query->_resultsHandler = [handler copy];
        query.revenant_stopsAfterResults = YES;
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

- (BOOL)includeDocumentData
{
    return _includeDocumentData;
}

- (void)revenant_run
{
    NSError *error = nil;
    NSArray<HKDocumentSample *> *found = [[RevenantHKStore sharedStore] documentsOfType:_documentType
                                                                               predicate:self.revenant_predicate
                                                                                  limit:_limit
                                                                          sortDescriptors:_sortDescriptors
                                                                      includeDocumentData:_includeDocumentData
                                                                                  error:&error];
    [self revenant_perform:^{
        if (self->_resultsHandler)
            self->_resultsHandler(self, found ?: @[], error);
    }];
}

- (void)revenant_stop
{
    _resultsHandler = nil;
}

@end

#pragma mark - The iOS 10.0 members of HKWorkout, HKWorkoutEvent and HKQuery

@implementation HKWorkout (RevenantIOS100)

- (nullable HKQuantity *)totalSwimmingStrokeCount
{
    return [self revenant_totalSwimmingStrokeCount];
}

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
    HKWorkout *workout = [[HKWorkout alloc] revenant_initWithType:[HKObjectType workoutType]
                                                       metadata:metadata
                                                      startDate:startDate
                                                        endDate:endDate
                                                       duration:[endDate timeIntervalSinceDate:startDate]];
    if (workout) {
        [workout revenant_setWorkoutActivityType:activityType];
        [workout revenant_setTotalEnergyBurned:totalEnergyBurned totalDistance:totalDistance];
        [workout revenant_setTotalSwimmingStrokeCount:totalSwimmingStrokeCount];
        [workout revenant_setWorkoutEvents:workoutEvents];
        [workout revenant_setDevice:device];
    }
    return workout;
}

@end

@implementation HKWorkoutEvent (RevenantIOS100)

+ (instancetype)workoutEventWithType:(HKWorkoutEventType)type
                                date:(NSDate *)date
                           metadata:(NSDictionary *)metadata
{
    HKWorkoutEvent *event = [[self alloc] revenant_initWithType:type date:date];
    [event revenant_setMetadata:metadata];
    return event;
}

- (nullable NSDictionary *)metadata
{
    return [self revenant_storedMetadata];
}

@end

@implementation HKQuery (RevenantIOS100)

+ (NSPredicate *)predicateForWorkoutsWithOperatorType:(NSPredicateOperatorType)type
                              totalSwimmingStrokeCount:(HKQuantity *)count
{
    if (![count isKindOfClass:[HKQuantity class]])
        return nil;
    return [NSPredicate predicateWithFormat:@"%K %@ %@", HKPredicateKeyPathWorkoutTotalSwimmingStrokeCount,
                                         [HKQuery revenant_predicateOperatorSpellingFor:type], count];
}

@end
