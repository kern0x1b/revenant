// HKQuantitySeriesSampleBuilder of iOS 12.0: a series of quantity samples, built one quantity at a
// time and handed over when the series is finished.
//
// One object per release: this file is of 12.0 alone.
//
// The contract is the host's own, read off it. A quantity of a unit the series' type does not accept is
// refused with com.apple.healthkit 3 and a wording that names both the quantity's unit and the type;
// a date before the builder's own start is refused the same way with a wording that names both dates; a
// builder that has been finished refuses the next insert the same way again. A builder that has been
// DISCARDED does not answer an error at all - it raises, and the exception is NSGenericException with
// the text "HKQuantitySeriesSampleBuilder already discarded." - which is a different kind of answer
// from a finished one and is why this port raises there and returns an error everywhere else.
//
// The release's own spelling of the insert is -insertQuantity:date:error:, which answers a BOOL and
// writes an NSError, and the arm64 image of 12.0 carries exactly one insert spelling and it is that
// one. The two forms the 26.2 header puts beside it - insertQuantity:dateInterval:completion: and the
// -initWithHealthStore:quantityType:startDate:device:error: initialiser - are of 13.0, and the image
// carries neither: by string count, insertQuantity:date:error: is 1 in the image of 12.0 and both
// insertQuantity:dateInterval:error: and insertQuantity:dateInterval:completion: are 0, so that one
// spelling is the image's whole insert surface. Of the two finishes the image carries only
// -finishSeriesWithMetadata:completion: while the header gives that form and
// -finishSeriesWithMetadata:endDate:completion: both at the class's own level. The disagreement is
// recorded in facts/HealthKit/HealthKit.md, and the form the 12.0 image does not carry is not carried
// here.
//
// What -finishSeriesWithMetadata:completion: returns for a series is **not measured**: on this machine
// the host's HealthKit has no entitlement and answers the finish with samples nil and com.apple.healthkit
// 1, "Health data is unavailable on this device", having refused nothing before it. The shape of the
// samples is therefore this port's own reading of the header - one quantity sample per inserted
// quantity, from the builder's start date to the date that quantity was inserted at - and the device
// test is what would settle it.

#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"

@interface HKHealthStore (CharonIOS120Internal)
- (void)saveObjects:(NSArray<HKObject *> *)objects withCompletion:(void (^)(BOOL success, NSError *_Nullable error))completion;
@end

// The header gives HKQuantity no -unit at all, so the unit a quantity is in is this library's own
// accessor, and that is what the refusal's wording is written from.
@interface HKQuantity (CharonIOS120Internal)
- (HKUnit *)charon_unit;
@end

@implementation HKQuantitySeriesSampleBuilder {
    HKHealthStore *_healthStore;
    HKQuantityType *_quantityType;
    NSDate *_startDate;
    HKDevice *_device;
    // Each quantity with the date it was inserted at, in the order it was inserted. The header says
    // quantities may be inserted in any order and are sorted by the start of their date interval when the
    // series is finished, so the order is the caller's and this keeps it.
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
    // A discarded builder is not a builder that answers: the host raises, and its text is its own.
    if (_discarded)
        [NSException raise:NSGenericException
                    format:@"HKQuantitySeriesSampleBuilder already discarded."];
    if (_finished) {
        [self charon_fail:error
                  reason:@"Quantity series sample builder already finished"
                    code:3];
        return NO;
    }
    // The unit is checked with the header's own -[HKQuantityType isCompatibleWithUnit:], which is what
    // the header of this method points a caller at, and the refusal names the unit and the type, because
    // that is what the host's own refusal does and a caller needs both to know what was wrong.
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

    // One sample per inserted quantity, from the builder's start date to the date that quantity was
    // inserted at, in the order it was inserted. That is the header's own reading of a series built one
    // quantity at a time and is this port's, because the host could not be asked for the shape.
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

    // The header says the samples are the ones that were inserted, and that the receiver is invalid
    // afterwards, so the builder is finished whether or not the store took them.
    _finished = YES;
    [_healthStore saveObjects:samples withCompletion:^(BOOL success, NSError *_Nullable error) {
        if (completion)
            completion(success ? samples : nil,
                       success ? nil : (error ?: [self charon_errorWithReason:@"Quantity series samples could not be saved" code:0]));
    }];
}

- (void)discard
{
    // The header's own words: everything inserted is discarded and the series is invalid, which is what
    // the host answers by raising on the next use.
    _discarded = YES;
    _finished = YES;
    [_inserted removeAllObjects];
}

#pragma mark - what the refusals say

// The host's refusals here are all com.apple.healthkit 3, so a caller switching on the code reads the
// same thing it would from the real framework.
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

// A quantity as the host's own refusal writes it: the value and the unit, as the unit spells itself.
- (NSString *)charon_describe:(HKQuantity *)quantity
{
    if (!quantity)
        return @"nil";
    HKUnit *unit = [quantity charon_unit];
    return [NSString stringWithFormat:@"%g %@", [quantity doubleValueForUnit:unit], unit.unitString];
}

@end
