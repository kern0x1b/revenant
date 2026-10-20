#import <HealthKit/HealthKit.h>

#import "RevenantHKStore.h"

#pragma mark - HKActivitySummaryQuery

@implementation HKActivitySummaryQuery {
    void (^_revenantResultsHandler)(HKActivitySummaryQuery *query, NSArray<HKActivitySummary *> *_Nullable summaries,
                                   NSError *_Nullable error);
}

- (instancetype)initWithPredicate:(nullable NSPredicate *)predicate
                   resultsHandler:(void (^)(HKActivitySummaryQuery *query, NSArray<HKActivitySummary *> *_Nullable activitySummaries,
                                            NSError *_Nullable error))handler
{
    HKActivitySummaryQuery *query = [super initWithRevenantObjectType:[HKObjectType activitySummaryType]];
    if (query) {
        [query revenant_setPredicate:predicate];
        query->_revenantResultsHandler = [handler copy];
        query.revenant_stopsAfterResults = YES;
    }
    return query;
}

- (nullable void (^)(HKActivitySummaryQuery *, NSArray<HKActivitySummary *> *_Nullable, NSError *_Nullable))updateHandler
{
    return self.revenant_updateHandlerForSummaries;
}

- (void)setUpdateHandler:(nullable void (^)(HKActivitySummaryQuery *, NSArray<HKActivitySummary *> *_Nullable,
                                            NSError *_Nullable))updateHandler
{
    if (self.revenant_hasBeenExecuted) {
        [NSException raise:NSInvalidArgumentException
                    format:@"The updateHandler of an HKActivitySummaryQuery may not be modified once the query has been executed."];
        return;
    }
    self.revenant_updateHandlerForSummaries = updateHandler;
}

- (void)revenant_run
{
    RevenantHKStore *store = [RevenantHKStore sharedStore];
    NSArray<HKActivitySummary *> *summaries = [store activitySummariesMatching:self.revenant_predicate error:NULL];
    if (!summaries.count)
        revenant_hk_say_once(@"activity-summary-empty",
                           @"HealthKit: an activity summary query answers an empty array. The rings are counted by the phone and "
                           @"recorded by the Activity application, and this release has no Activity application and no health store of "
                           @"Apple's, so the table of the summaries this library keeps is empty. A query is asked of the store and the "
                           @"store has none to give.");
    [self revenant_perform:^{
        if (self->_revenantResultsHandler)
            self->_revenantResultsHandler(self, summaries, nil);
    }];
}

- (void)revenant_stop
{
    _revenantResultsHandler = nil;
    self.revenant_updateHandlerForSummaries = nil;
}

@end

#pragma mark - HKObjectType

@implementation HKObjectType (RevenantIOS93)

+ (HKActivitySummaryType *)activitySummaryType
{
    static HKActivitySummaryType *type;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        type = [HKActivitySummaryType revenant_typeWithIdentifier:@"HKActivitySummaryType"];
    });
    return type;
}

@end

#pragma mark - HKQuery

@implementation HKQuery (RevenantIOS93)

- (nullable HKObjectType *)objectType
{
    return self.revenant_objectType;
}

+ (NSPredicate *)predicateForActivitySummaryWithDateComponents:(NSDateComponents *)dateComponents
{
    if (![dateComponents isKindOfClass:[NSDateComponents class]])
        return nil;
    return [NSPredicate predicateWithFormat:@"%K == %@", HKPredicateKeyPathDateComponents, dateComponents];
}

+ (NSPredicate *)predicateForActivitySummariesBetweenStartDateComponents:(NSDateComponents *)start
                                               endDateComponents:(NSDateComponents *)end
{
    if (![start isKindOfClass:[NSDateComponents class]] || ![end isKindOfClass:[NSDateComponents class]])
        return nil;
    return [NSPredicate predicateWithFormat:@"%K >= %@ AND %K <= %@", HKPredicateKeyPathDateComponents, start,
                                         HKPredicateKeyPathDateComponents, end];
}

@end
