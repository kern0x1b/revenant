// HKQuantitySeriesSampleQuery of iOS 12.0: the quantities of one quantity sample, delivered one at a
// time and finished with a done.
//
// One object per release: this file is of 12.0 alone.
//
// The release's own surface of this class is one initialiser. The arm64 image of 12.0 carries
// -initWithSample:quantityHandler: and nothing else of the class: by string count
// -initWithQuantityType:predicate:quantityHandler:, -includeSample and
// -orderByQuantitySampleStartDate are each 0 there, and the 26.2 header marks all three 13.0. So the
// two properties are @dynamic and emit no accessor, the selector is not in the library, and
// -respondsToSelector: answers NO rather than an accessor that would answer NO for a value the header
// types as a BOOL and a caller would read as a class of 13.0 this library has. The 13.0 initialiser is
// not carried.
//
// The sample the query is made with is found by its own identity, which is what the header of the
// initialiser points a caller at the query for one quantity sample's quantities, which the header names
// as the predicate +[HKPredicates predicateForObjectWithUUID:]. This port asks its store by that same UUID, through the
// store's own -objectsWithUUIDs:ofType:error:, so the query reads the same SQLite file every other
// query of this library reads and there is no second way to reach it.

#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"

@implementation HKQuantitySeriesSampleQuery {
    // The sample the query is anchored to, and the handler it answers. The sample is held by identity -
    // its UUID - rather than strongly, because a query outlives the caller's variable and the store is
    // what owns the object; the handler is held strongly, as every query of this library holds its own.
    NSUUID *_sampleUUID;
    HKSampleType *_sampleType;
    void (^_quantityHandler)(HKQuantitySeriesSampleQuery *query, HKQuantity *_Nullable quantity,
                             NSDate *_Nullable date, BOOL done, NSError *_Nullable error);
    BOOL _stopped;
}

- (instancetype)initWithSample:(HKQuantitySample *)quantitySample
               quantityHandler:(void (^)(HKQuantitySeriesSampleQuery *query, HKQuantity *_Nullable quantity,
                                        NSDate *_Nullable date, BOOL done, NSError *_Nullable error))quantityHandler
{
    self = [super initWithCharonSampleType:quantitySample.sampleType];
    if (self) {
        _sampleUUID = quantitySample.UUID;
        _sampleType = quantitySample.sampleType;
        _quantityHandler = [quantityHandler copy];
    }
    return self;
}

// The 13.0 members of the class, named so that the compiler emits no accessor and the library carries no
// selector for either. The header of both is 13.0 and the image of 12.0 has neither.
@dynamic includeSample;
@dynamic orderByQuantitySampleStartDate;

- (void)charon_run
{
    if (_stopped || _sampleUUID == nil) {
        [self charon_deliverQuantity:nil date:nil done:YES error:nil];
        return;
    }
    CharonHKStore *store = [CharonHKStore sharedStore];
    NSError *error = nil;
    NSArray *found = [store objectsWithUUIDs:@[ _sampleUUID ] ofType:_sampleType error:&error];
    if (!found) {
        // The query's own answer when it cannot read: nothing, and the error, with the handler finished.
        [self charon_deliverQuantity:nil date:nil done:YES error:error];
        return;
    }
    for (HKSample *sample in found) {
        if (_stopped)
            return;
        if (![sample isKindOfClass:[HKQuantitySample class]])
            continue;
        HKQuantitySample *quantitySample = (HKQuantitySample *)sample;
        [self charon_deliverQuantity:quantitySample.quantity date:quantitySample.startDate done:NO error:nil];
    }
    [self charon_deliverQuantity:nil date:nil done:YES error:nil];
}

- (void)charon_stop
{
    _stopped = YES;
}

// One call of the handler. The header says the handler is called repeatedly with the quantity and a
// date, in ascending start-date order, until all are returned and done is YES - and that once done is
// YES, or the query is stopped, no more calls are made. So the done call is the last one, and a stopped
// query answers nothing further.
- (void)charon_deliverQuantity:(nullable HKQuantity *)quantity
                          date:(nullable NSDate *)date
                          done:(BOOL)done
                         error:(nullable NSError *)error
{
    if (_stopped || !_quantityHandler)
        return;
    __weak HKQuantitySeriesSampleQuery *weakSelf = self;
    [self charon_perform:^{
        HKQuantitySeriesSampleQuery *strongSelf = weakSelf;
        if (strongSelf && strongSelf->_quantityHandler)
            strongSelf->_quantityHandler(strongSelf, quantity, date, done, error);
    }];
}

@end
