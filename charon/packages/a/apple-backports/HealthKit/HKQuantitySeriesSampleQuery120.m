#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"

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
    self = [super initWithCharonSampleType:quantitySample.sampleType];
    if (self) {
        _sampleUUID = quantitySample.UUID;
        _sampleType = quantitySample.sampleType;
        _quantityHandler = [quantityHandler copy];
    }
    return self;
}

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
