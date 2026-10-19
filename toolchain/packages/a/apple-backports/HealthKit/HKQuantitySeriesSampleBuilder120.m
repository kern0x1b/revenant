#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"

@interface HKHealthStore (CharonIOS120Internal)
- (void)saveObjects:(NSArray<HKObject *> *)objects withCompletion:(void (^)(BOOL success, NSError *_Nullable error))completion;
@end

@interface HKQuantity (CharonIOS120Internal)
- (HKUnit *)charon_unit;
@end

@implementation HKQuantitySeriesSampleBuilder {
    HKHealthStore *_healthStore;
    HKQuantityType *_quantityType;
    NSDate *_startDate;
    HKDevice *_device;
    NSMutableArray<NSArray *> *_inserted;
    BOOL _finished;
    BOOL _discarded;
}
CHARON_HEALTHKIT_UNCREATABLE_INIT

- (instancetype)initWithHealthStore:(HKHealthStore *)healthStore
                       quantityType:(HKQuantityType *)quantityType
                          startDate:(NSDate *)startDate
                             device:(nullable HKDevice *)device
{
    self = [super init];
    if (self) {
        _healthStore = healthStore;
        _quantityType = quantityType;
        _startDate = [startDate copy];
        _device = device;
        _inserted = [NSMutableArray array];
    }
    return self;
}

#pragma mark - the header's readonly state

- (HKQuantityType *)quantityType
{
    return _quantityType;
}

- (NSDate *)startDate
{
    return _startDate;
}

- (nullable HKDevice *)device
{
    return _device;
}

#pragma mark - inserting

- (BOOL)insertQuantity:(HKQuantity *)quantity
                  date:(NSDate *)date
                 error:(NSError **)error
{
    if (_discarded)
        [NSException raise:NSGenericException
                    format:@"HKQuantitySeriesSampleBuilder already discarded."];
    if (_finished) {
        [self charon_fail:error
                  reason:@"Quantity series sample builder already finished"
                    code:3];
        return NO;
    }
    if (!quantity || ![_quantityType isCompatibleWithUnit:[quantity charon_unit]]) {
        [self charon_fail:error
                  reason:[NSString stringWithFormat:@"Quantity (%@) does not have a unit compatible with "
                                                     "quantity series builder quantity type %@",
                                                     [self charon_describe:quantity], _quantityType.identifier]
                    code:3];
        return NO;
    }
    if ([date compare:_startDate] == NSOrderedAscending) {
        [self charon_fail:error
                  reason:[NSString stringWithFormat:@"Date interval (Start Date %@) is before builder's "
                                                     "start date %@", date, _startDate]
                    code:3];
        return NO;
    }
    [_inserted addObject:@[ quantity, [date copy] ]];
    return YES;
}

#pragma mark - finishing, and discarding

- (void)finishSeriesWithMetadata:(nullable NSDictionary<NSString *, id> *)metadata
                      completion:(void (^)(NSArray<HKQuantitySample *> *_Nullable, NSError *_Nullable))completion
{
    if (_discarded)
        [NSException raise:NSGenericException
                    format:@"HKQuantitySeriesSampleBuilder already discarded."];
    if (_finished) {
        if (completion)
            completion(nil, [self charon_errorWithReason:@"Quantity series sample builder already finished" code:3]);
        return;
    }

    NSMutableArray<HKQuantitySample *> *samples = [NSMutableArray array];
    for (NSArray *pair in _inserted) {
        HKQuantitySample *sample = [HKQuantitySample quantitySampleWithType:_quantityType
                                                                  quantity:pair[0]
                                                                 startDate:_startDate
                                                                   endDate:pair[1]
                                                                    device:_device
                                                                  metadata:metadata];
        if (sample)
            [samples addObject:sample];
    }
    if (!samples.count) {
        if (completion)
            completion(nil, [self charon_errorWithReason:@"Quantity series sample builder has nothing inserted" code:3]);
        return;
    }

    _finished = YES;
    [_healthStore saveObjects:samples withCompletion:^(BOOL success, NSError *_Nullable error) {
        if (completion)
            completion(success ? samples : nil,
                       success ? nil : (error ?: [self charon_errorWithReason:@"Quantity series samples could not be saved" code:0]));
    }];
}

- (void)discard
{
    _discarded = YES;
    _finished = YES;
    [_inserted removeAllObjects];
}

#pragma mark - what the refusals say

- (void)charon_fail:(NSError **)error reason:(NSString *)reason code:(NSInteger)code
{
    if (error)
        *error = [self charon_errorWithReason:reason code:code];
}

- (NSError *)charon_errorWithReason:(NSString *)reason code:(NSInteger)code
{
    return [NSError errorWithDomain:HKErrorDomain code:code userInfo:@{
        NSLocalizedDescriptionKey: reason
    }];
}

- (NSString *)charon_describe:(HKQuantity *)quantity
{
    if (!quantity)
        return @"nil";
    HKUnit *unit = [quantity charon_unit];
    return [NSString stringWithFormat:@"%g %@", [quantity doubleValueForUnit:unit], unit.unitString];
}

@end
