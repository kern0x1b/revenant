#import <HealthKit/HealthKit.h>

#import "RevenantHKStore.h"

@implementation HKQuantitySeriesSampleQuery {
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
    self = [super initWithRevenantSampleType:quantitySample.sampleType];
    if (self) {
        _sampleUUID = quantitySample.UUID;
        _sampleType = quantitySample.sampleType;
        _quantityHandler = [quantityHandler copy];
    }
    return self;
}

@dynamic includeSample;
@dynamic orderByQuantitySampleStartDate;

- (void)revenant_run
{
    if (_stopped || _sampleUUID == nil) {
        [self revenant_deliverQuantity:nil date:nil done:YES error:nil];
        return;
    }
    RevenantHKStore *store = [RevenantHKStore sharedStore];
    NSError *error = nil;
    NSArray *found = [store objectsWithUUIDs:@[ _sampleUUID ] ofType:_sampleType error:&error];
    if (!found) {
        [self revenant_deliverQuantity:nil date:nil done:YES error:error];
        return;
    }
    for (HKSample *sample in found) {
        if (_stopped)
            return;
        if (![sample isKindOfClass:[HKQuantitySample class]])
            continue;
        HKQuantitySample *quantitySample = (HKQuantitySample *)sample;
        [self revenant_deliverQuantity:quantitySample.quantity date:quantitySample.startDate done:NO error:nil];
    }
    [self revenant_deliverQuantity:nil date:nil done:YES error:nil];
}

- (void)revenant_stop
{
    _stopped = YES;
}

- (void)revenant_deliverQuantity:(nullable HKQuantity *)quantity
                          date:(nullable NSDate *)date
                          done:(BOOL)done
                         error:(nullable NSError *)error
{
    if (_stopped || !_quantityHandler)
        return;
    __weak HKQuantitySeriesSampleQuery *weakSelf = self;
    [self revenant_perform:^{
        HKQuantitySeriesSampleQuery *strongSelf = weakSelf;
        if (strongSelf && strongSelf->_quantityHandler)
            strongSelf->_quantityHandler(strongSelf, quantity, date, done, error);
    }];
}

@end
