// The six query subclasses of iOS 8, and the two result classes: what a query is asked and how the
// store answers it.
//
// Every query is answered out of the store, in the order its handler expects: a sample query delivers
// its results in batches with the handler's final flag set, a statistics query delivers one
// statistics object, a statistics collection delivers its first statistics and then each interval's,
// a source query delivers the sources, an observer query is answered when the store changes, and an
// anchored query delivers the objects that changed and the anchor past them.

#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"

#pragma mark - HKSampleQuery

@implementation HKSampleQuery {
    NSUInteger _limit;
    NSArray<NSSortDescriptor *> *_sortDescriptors;
    void (^_resultsHandler)(HKSampleQuery *, NSArray<HKSample *> *, NSError *);
}

- (instancetype)initWithSampleType:(HKSampleType *)sampleType
                         predicate:(nullable NSPredicate *)predicate
                             limit:(NSUInteger)limit
                  sortDescriptors:(nullable NSArray<NSSortDescriptor *> *)sortDescriptors
                     resultsHandler:(void (^)(HKSampleQuery *query, NSArray<HKSample *> *_Nullable results, NSError *_Nullable error))resultsHandler
{
    self = [super initWithCharonSampleType:sampleType];
    if (self) {
        [self charon_setPredicate:predicate];
        _limit = limit;
        _sortDescriptors = [sortDescriptors copy];
        _resultsHandler = [resultsHandler copy];
    }
    return self;
}

// The handler is called once, when the query has finished, with the results or with the error, as the SDK's HKSampleQuery.h
// documents; a query that failed has no results, so they are nil.
- (void)charon_run
{
    CharonHKStore *store = [CharonHKStore sharedStore];
    NSError *error = nil;
    NSArray *found = [store objectsOfType:self.sampleType
                                 predicate:self.charon_predicate
                                 startDate:nil
                                   endDate:nil
                         strictStartDate:NO
                           strictEndDate:NO
                                  limit:_limit
                          sortDescriptors:_sortDescriptors
                            fromSequence:0
                                   error:&error];
    [self charon_perform:^{
        if (self->_resultsHandler)
            self->_resultsHandler(self, found, error);
    }];
}

@end

#pragma mark - HKStatisticsQuery

@implementation HKStatisticsQuery {
    HKStatisticsOptions _options;
    void (^_completionHandler)(HKStatistics *_Nullable, NSError *_Nullable);
}

- (instancetype)initWithQuantityType:(HKQuantityType *)quantityType
                quantitySamplePredicate:(nullable NSPredicate *)quantitySamplePredicate
                             options:(HKStatisticsOptions)options
                    completionHandler:(void (^)(HKStatistics *_Nullable result, NSError *_Nullable error))completionHandler
{
    self = [super initWithCharonSampleType:quantityType];
    if (self) {
        [self charon_setPredicate:quantitySamplePredicate];
        _options = options;
        _completionHandler = [completionHandler copy];
    }
    return self;
}

- (void)charon_run
{
    CharonHKStore *store = [CharonHKStore sharedStore];
    NSError *error = nil;
    NSArray<HKQuantitySample *> *found = [store objectsOfType:self.sampleType
                                                    predicate:self.charon_predicate
                                                    startDate:nil
                                                      endDate:nil
                                            strictStartDate:NO
                                              strictEndDate:NO
                                                     limit:0
                                             sortDescriptors:nil
                                               fromSequence:0
                                                      error:&error];
    if (!found) {
        [self charon_perform:^{
            if (self->_completionHandler)
                self->_completionHandler(nil, error);
        }];
        return;
    }
    HKStatistics *statistics = [HKStatistics charon_statisticsForSamples:found options:self->_options];
    [self charon_perform:^{
        if (self->_completionHandler)
            self->_completionHandler(statistics, nil);
    }];
}

@end

#pragma mark - HKStatisticsCollectionQuery

@implementation HKStatisticsCollectionQuery {
    HKStatisticsOptions _options;
    NSDateComponents *_intervalComponents;
    NSDate *_anchorDate;
    HKStatisticsCollection *_statisticsCollection;
    NSDate *_lastAnchor;
    void (^_initialResultsHandler)(HKStatisticsCollection *_Nullable, NSError *_Nullable);
    void (^_statisticsUpdateHandler)(HKStatisticsCollection *_Nullable, NSError *_Nullable);
}

// The form of iOS 8.0: a type, a predicate, the options, the anchor and the interval, and the handler
// set on the property afterwards. -init is NS_UNAVAILABLE on this class, so these two are the only
// ways the release makes one, and the one below is this one with the handler in the same call.
- (instancetype)initWithQuantityType:(HKQuantityType *)quantityType
                quantitySamplePredicate:(nullable NSPredicate *)quantitySamplePredicate
                             options:(HKStatisticsOptions)options
                          anchorDate:(NSDate *)anchorDate
                  intervalComponents:(NSDateComponents *)intervalComponents
{
    self = [super initWithCharonSampleType:quantityType];
    if (self) {
        [self charon_setPredicate:quantitySamplePredicate];
        _options = options;
        _anchorDate = [anchorDate copy];
        _intervalComponents = [HKStatisticsCollection charon_normalizedIntervalComponents:intervalComponents];
    }
    return self;
}


- (NSDate *)anchorDate
{
    return _anchorDate;
}

- (NSDateComponents *)intervalComponents
{
    return _intervalComponents;
}

- (nullable HKStatisticsCollection *)charon_statisticsCollection
{
    return _statisticsCollection;
}

- (void)charon_setStatisticsCollection:(nullable HKStatisticsCollection *)statisticsCollection
{
    _statisticsCollection = statisticsCollection;
}

// Apple's own private member: no SDK header of 16.4 or 26.2 declares -lastAnchor on
// HKStatisticsCollectionQuery, so the port answers it under its own name and the public-shaped getter
// is not in the method list of the exported class.
- (nullable NSDate *)charon_lastAnchor
{
    return _lastAnchor;
}

- (void)charon_setLastAnchor:(nullable NSDate *)lastAnchor
{
    _lastAnchor = [lastAnchor copy];
}

- (nullable void (^)(HKStatisticsCollection *, NSError *))initialResultsHandler
{
    return _initialResultsHandler;
}

- (void)setInitialResultsHandler:(void (^)(HKStatisticsCollection *, NSError *))initialResultsHandler
{
    _initialResultsHandler = [initialResultsHandler copy];
}

- (nullable void (^)(HKStatisticsCollection *, NSError *))statisticsUpdateHandler
{
    return _statisticsUpdateHandler;
}

- (void)setStatisticsUpdateHandler:(void (^)(HKStatisticsCollection *, NSError *))statisticsUpdateHandler
{
    _statisticsUpdateHandler = [statisticsUpdateHandler copy];
}

// The intervals of a collection, from its anchor to the end of what the store holds, and the
// statistics of each. A collection with no anchor runs from the first sample the store has.
- (void)charon_run
{
    CharonHKStore *store = [CharonHKStore sharedStore];
    NSError *error = nil;
    NSArray<HKQuantitySample *> *found = [store objectsOfType:self.sampleType
                                                    predicate:self.charon_predicate
                                                    startDate:nil
                                                      endDate:nil
                                            strictStartDate:NO
                                              strictEndDate:NO
                                                     limit:0
                                             sortDescriptors:nil
                                               fromSequence:0
                                                      error:&error];
    if (!found) {
        [self charon_perform:^{
            if (self->_initialResultsHandler)
                self->_initialResultsHandler(nil, error);
        }];
        return;
    }
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *first = found.firstObject.startDate;
    NSDate *last = found.lastObject.endDate;
    NSDate *anchor = _anchorDate ?: first;
    HKStatisticsCollection *collection = [HKStatisticsCollection charon_collectionWithAnchorDate:anchor
                                                                                        options:_options
                                                                            intervalComponents:_intervalComponents
                                                                                          samples:found
                                                                                          calendar:calendar];
    _statisticsCollection = collection;
    [self charon_perform:^{
        if (self->_initialResultsHandler)
            self->_initialResultsHandler(collection, nil);
    }];
}

@end

#pragma mark - HKSourceQuery

@implementation HKSourceQuery {
    void (^_completionHandler)(NSArray<HKSource *> *, NSError *_Nullable);
}

- (instancetype)initWithSampleType:(HKSampleType *)sampleType
                    samplePredicate:(nullable NSPredicate *)predicate
                  completionHandler:(void (^)(NSArray<HKSource *> *sources, NSError *_Nullable error))completionHandler
{
    self = [super initWithCharonSampleType:sampleType];
    if (self) {
        [self charon_setPredicate:predicate];
        _completionHandler = [completionHandler copy];
    }
    return self;
}

- (void)charon_run
{
    CharonHKStore *store = [CharonHKStore sharedStore];
    NSArray<HKSource *> *sources = self.sampleType ? [store sourcesForType:self.sampleType] : [store allSources];
    NSMutableArray *found = [NSMutableArray array];
    for (HKSource *source in sources) {
        NSPredicate *wanted = self.charon_predicate;
        if (wanted && ![wanted evaluateWithObject:source])
            continue;
        [found addObject:source];
    }
    [self charon_perform:^{
        if (self->_completionHandler)
            self->_completionHandler(found, nil);
    }];
}

@end

#pragma mark - HKCorrelationQuery

@implementation HKCorrelationQuery {
    HKCorrelationType *_correlationType;
    NSArray<NSPredicate *> *_samplePredicates;
    void (^_resultsHandler)(NSArray<HKCorrelation *> *, NSError *_Nullable);
}

- (instancetype)initWithType:(HKCorrelationType *)correlationType
                   predicate:(nullable NSPredicate *)predicate
            samplePredicates:(nullable NSArray<NSPredicate *> *)samplePredicates
                 completion:(void (^)(NSArray<HKCorrelation *> *_Nullable results, NSError *_Nullable error))completion
{
    self = [super initWithCharonSampleType:correlationType];
    if (self) {
        _correlationType = correlationType;
        _samplePredicates = [samplePredicates copy];
        _resultsHandler = [completion copy];
        [self charon_setPredicate:predicate];
        (void)samplePredicates;
    }
    return self;
}

- (HKCorrelationType *)correlationType
{
    return _correlationType;
}

- (NSArray<NSPredicate *> *)samplePredicates
{
    return _samplePredicates;
}

- (void)charon_run
{
    CharonHKStore *store = [CharonHKStore sharedStore];
    NSError *error = nil;
    NSArray<HKCorrelation *> *found = [store objectsOfType:self.sampleType
                                                 predicate:self.charon_predicate
                                                 startDate:nil
                                                   endDate:nil
                                         strictStartDate:NO
                                           strictEndDate:NO
                                                  limit:0
                                          sortDescriptors:nil
                                            fromSequence:0
                                                   error:&error];
    if (!found) {
        [self charon_perform:^{
            if (self->_resultsHandler)
                self->_resultsHandler(@[], error);
        }];
        return;
    }
    [self charon_perform:^{
        if (self->_resultsHandler)
            self->_resultsHandler(found, nil);
    }];
}

@end

#pragma mark - HKObserverQuery

@implementation HKObserverQuery {
    void (^_updateHandler)(HKObserverQuery *, HKQueryAnchor *_Nullable, void (^_Nullable)(void), NSError *_Nullable);
    HKQueryAnchor *_anchor;
}

- (instancetype)initWithSampleType:(HKSampleType *)sampleType
                        predicate:(nullable NSPredicate *)predicate
                    updateHandler:(void (^)(HKObserverQuery *query, HKQueryAnchor *_Nullable anchor,
                                            void (^_Nullable completion)(void), NSError *_Nullable error))updateHandler
{
    self = [super initWithCharonSampleType:sampleType];
    if (self) {
        [self charon_setPredicate:predicate];
        _updateHandler = [updateHandler copy];
    }
    return self;
}

- (void)charon_run
{
    // An observer query is answered when the store changes, not at once: the release answers its
    // handler from the notification the health daemon posts, and this store's own write is what
    // posts it. The anchor it is answered with is the sequence the store has reached.
    CharonHKStore *store = [CharonHKStore sharedStore];
    _anchor = [HKQueryAnchor charon_anchorWithSequence:store.highestSequence];
    [store addObserver:self forTypes:self.sampleType ? [NSSet setWithObject:self.sampleType] : nil];
}

- (void)charon_stop
{
    [[CharonHKStore sharedStore] removeObserver:self];
}

// The handler is called with the anchor the store's own write sequence has reached, and with a
// completion the application calls when it has caught up. The change this is reporting is written before
// the handler is called, so this store has nothing outstanding by the time the handler returns, and the
// completion is therefore called when it does: an application that called it itself inside the handler
// has already said so and is not called a second time, and one that never calls it has still been told
// that there is nothing left to wait for. The completion is not a way to stop the next change from
// coming - that is -stopQuery: - and the handler is told of every change while the query runs.
- (void)charon_storeDidChange:(NSArray<NSUUID *> *)identifiers
{
    CharonHKStore *store = [CharonHKStore sharedStore];
    NSInteger sequence = store.highestSequence;
    HKQueryAnchor *anchor = [HKQueryAnchor charon_anchorWithSequence:sequence];
    _anchor = anchor;
    [self charon_perform:^{
        if (!self->_updateHandler)
            return;
        __block BOOL caughtUp = NO;
        void (^completion)(void) = ^{
            caughtUp = YES;
        };
        self->_updateHandler(self, anchor, completion, nil);
        if (!caughtUp)
            completion();
    }];
}

@end

#pragma mark - HKAnchoredObjectQuery

@interface HKAnchoredObjectQuery ()
@property (nonatomic) NSUInteger charon_limit;
@end

@implementation HKAnchoredObjectQuery {
    HKQueryAnchor *_anchor;
    void (^_resultsHandler)(HKAnchoredObjectQuery *query, NSArray<HKSample *> *_Nullable results, NSUInteger newAnchor,
                            NSError *_Nullable error);
    // The handler of the initialiser of iOS 9.0, which is a different selector and a different shape
    // from the one of iOS 8.0: an object anchor in, the deletions as objects out.
    void (^_charonResultsHandler9)(HKAnchoredObjectQuery *query, NSArray<HKSample *> *_Nullable sampleObjects,
                                   NSArray<HKDeletedObject *> *_Nullable deletedObjects, HKQueryAnchor *_Nullable newAnchor,
                                   NSError *_Nullable error);
}
@synthesize charon_limit = _charonLimit;

// The form of iOS 8.0, whose anchor is the integer an earlier query answered with rather than an
// object, and whose handler is told the new anchor as that same integer. iOS 9.0 made the anchor an
// object and the handler take the deletions as HKDeletedObject instances, and +[HKQueryAnchor
// anchorFromValue:] is how an integer of this form is carried across to that one.
- (instancetype)initWithType:(HKSampleType *)type
                   predicate:(nullable NSPredicate *)predicate
                      anchor:(NSUInteger)anchor
                       limit:(NSUInteger)limit
           completionHandler:(void (^)(HKAnchoredObjectQuery *query, NSArray<HKSample *> *_Nullable results,
                                       NSUInteger newAnchor, NSError *_Nullable error))completionHandler
{
    HKAnchoredObjectQuery *fresh = [super initWithCharonObjectType:type];
    if (fresh) {
        [fresh charon_setPredicate:predicate];
        fresh->_anchor = [HKQueryAnchor anchorFromValue:anchor];
        fresh.charon_limit = limit;
        fresh->_resultsHandler = [completionHandler copy];
        fresh.charon_stopsAfterResults = YES;
    }
    return fresh;
}

// The form of iOS 9.0, with an object anchor and a handler that takes the deletions as the deleted
// objects themselves. With no update handler set the query answers once and stops itself, which is
// what the header says it does; with one it keeps running and is told of every change the store makes.
- (void)charon_setResultsHandler:(void (^)(HKAnchoredObjectQuery *query, NSArray<HKSample *> *_Nullable sampleObjects,
                                           NSArray<HKDeletedObject *> *_Nullable deletedObjects, HKQueryAnchor *_Nullable newAnchor,
                                           NSError *_Nullable error))handler
{
    _resultsHandler = nil;
    _charonResultsHandler9 = [handler copy];
}

// The form of iOS 9.0: with an update handler the query keeps running and is answered with every
// change the store makes while it runs, and with none it answers once and stops itself. That is the
// difference the header draws between the two initialisers, and it is what the store is asked for.
- (void)charon_storeDidChange:(NSArray<NSUUID *> *)identifiers
{
    void (^update)(HKAnchoredObjectQuery *, NSArray<HKSample *> *_Nullable, NSArray<HKDeletedObject *> *_Nullable,
                   HKQueryAnchor *_Nullable, NSError *_Nullable) = self.charon_updateHandler;
    if (!update)
        return;
    CharonHKStore *store = [CharonHKStore sharedStore];
    NSError *error = nil;
    NSArray *added = [store objectsWithUUIDs:identifiers ofType:self.sampleType error:&error];
    if (!added)
        return;
    HKQueryAnchor *anchor = [HKQueryAnchor charon_anchorWithSequence:store.highestSequence];
    [self charon_perform:^{
        update(self, added, nil, anchor, nil);
    }];
}

- (void)charon_run
{
    CharonHKStore *store = [CharonHKStore sharedStore];
    NSError *error = nil;
    NSInteger from = _anchor ? _anchor.charon_sequence : 0;
    NSArray *added = [store objectsOfType:self.sampleType
                                predicate:self.charon_predicate
                                startDate:nil
                                  endDate:nil
                        strictStartDate:NO
                          strictEndDate:NO
                                 limit:self.charon_limit
                         sortDescriptors:nil
                           fromSequence:from
                                  error:&error];
    if (!added) {
        [self charon_perform:^{
            if (self->_resultsHandler)
                self->_resultsHandler(self, @[], 0, error);
            else if (self->_charonResultsHandler9)
                self->_charonResultsHandler9(self, @[], @[], nil, error);
        }];
        return;
    }
    NSArray *deleted = [store deletedObjectsSinceSequence:from];
    HKQueryAnchor *anchor = [HKQueryAnchor charon_anchorWithSequence:store.highestSequence];
    [self charon_perform:^{
        if (self->_resultsHandler) {
            self->_resultsHandler(self, added, (NSUInteger)deleted.count, error);
        } else if (self->_charonResultsHandler9) {
            self->_charonResultsHandler9(self, added, deleted, anchor, error);
        }
    }];
}

- (void)charon_stop
{
    _charonResultsHandler9 = nil;
    _resultsHandler = nil;
}

@end
