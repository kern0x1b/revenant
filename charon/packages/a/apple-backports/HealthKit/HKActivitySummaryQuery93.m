// The query of iOS 9.3, its type, and the two predicates that ask for a day of the ring.
//
// The store keeps a table of the activity summaries the device recorded, one row per day, and reads
// it back through the same archive the class writes. Nothing writes to that table on this release:
// the rings are counted by the phone and recorded by the Activity application, and iOS 6.1.3 has no
// Activity application and no health store of Apple's, so a summary query answers an empty array. That
// is said once in the log rather than left to be discovered, and everything else here - the predicate
// the two factories build, the type, the class, the coding and the query's long-running form - is
// real and is asked for in the same shape the release is.

#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"

#pragma mark - HKActivitySummaryQuery

@implementation HKActivitySummaryQuery {
    void (^_charonResultsHandler)(HKActivitySummaryQuery *query, NSArray<HKActivitySummary *> *_Nullable summaries,
                                   NSError *_Nullable error);
}

- (instancetype)initWithPredicate:(nullable NSPredicate *)predicate
                   resultsHandler:(void (^)(HKActivitySummaryQuery *query, NSArray<HKActivitySummary *> *_Nullable activitySummaries,
                                            NSError *_Nullable error))handler
{
    HKActivitySummaryQuery *query = [super initWithCharonObjectType:[HKObjectType activitySummaryType]];
    if (query) {
        [query charon_setPredicate:predicate];
        query->_charonResultsHandler = [handler copy];
        query.charon_stopsAfterResults = YES;
    }
    return query;
}

- (nullable void (^)(HKActivitySummaryQuery *, NSArray<HKActivitySummary *> *_Nullable, NSError *_Nullable))updateHandler
{
    return self.charon_updateHandlerForSummaries;
}

- (void)setUpdateHandler:(nullable void (^)(HKActivitySummaryQuery *, NSArray<HKActivitySummary *> *_Nullable,
                                            NSError *_Nullable))updateHandler
{
    // The header forbids changing the property once the query has run.
    if (self.charon_hasBeenExecuted) {
        [NSException raise:NSInvalidArgumentException
                    format:@"The updateHandler of an HKActivitySummaryQuery may not be modified once the query has been executed."];
        return;
    }
    self.charon_updateHandlerForSummaries = updateHandler;
}

- (void)charon_run
{
    CharonHKStore *store = [CharonHKStore sharedStore];
    NSArray<HKActivitySummary *> *summaries = [store activitySummariesMatching:self.charon_predicate error:NULL];
    if (!summaries.count)
        charon_hk_say_once(@"activity-summary-empty",
                           @"HealthKit: an activity summary query answers an empty array. The rings are counted by the phone and "
                           @"recorded by the Activity application, and this release has no Activity application and no health store of "
                           @"Apple's, so the table of the summaries this library keeps is empty. A query is asked of the store and the "
                           @"store has none to give.");
    [self charon_perform:^{
        if (self->_charonResultsHandler)
            self->_charonResultsHandler(self, summaries, nil);
    }];
}

- (void)charon_stop
{
    _charonResultsHandler = nil;
    self.charon_updateHandlerForSummaries = nil;
}

@end

#pragma mark - HKObjectType

@implementation HKObjectType (CharonIOS93)

+ (HKActivitySummaryType *)activitySummaryType
{
    static HKActivitySummaryType *type;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        type = [HKActivitySummaryType charon_typeWithIdentifier:@"HKActivitySummaryType"];
    });
    return type;
}

@end

#pragma mark - HKQuery

@implementation HKQuery (CharonIOS93)

// The type a query is for, under the name iOS 9.3 gave it. -sampleType is the same object and the
// header deprecated it in favour of this in the same release.
- (nullable HKObjectType *)objectType
{
    return self.charon_objectType;
}

// A day of the ring, as the release builds the predicate: the year, the month and the day of the
// summary equal to the ones given, over the date components key path - whose value, "dateComponents",
// was read out of iOS 9.0's own image.
+ (NSPredicate *)predicateForActivitySummaryWithDateComponents:(NSDateComponents *)dateComponents
{
    if (![dateComponents isKindOfClass:[NSDateComponents class]])
        return nil;
    return [NSPredicate predicateWithFormat:@"%K == %@", HKPredicateKeyPathDateComponents, dateComponents];
}

// The summaries of the days between two, which is a pair of the above and a test each end.
+ (NSPredicate *)predicateForActivitySummariesBetweenStartDateComponents:(NSDateComponents *)start
                                               endDateComponents:(NSDateComponents *)end
{
    if (![start isKindOfClass:[NSDateComponents class]] || ![end isKindOfClass:[NSDateComponents class]])
        return nil;
    return [NSPredicate predicateWithFormat:@"%K >= %@ AND %K <= %@", HKPredicateKeyPathDateComponents, start,
                                         HKPredicateKeyPathDateComponents, end];
}

@end
