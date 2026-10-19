#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"

@interface HKCumulativeQuantitySample (CharonIOS130Internal)
- (instancetype)charon_initWithCumulativeType:(HKQuantityType *)quantityType
                                          sum:(HKQuantity *)sum
                                     startDate:(NSDate *)startDate
                                       endDate:(NSDate *)endDate;
@end

@interface HKSample (CharonIOS130Internal)
@property (readonly, copy) HKSampleType *sampleType;
- (instancetype)charon_initWithType:(HKSampleType *)sampleType
                            metadata:(nullable NSDictionary *)metadata
                           startDate:(NSDate *)startDate
                             endDate:(NSDate *)endDate;
@end

@interface HKCumulativeQuantitySample (CharonHKStorable) <CharonHKStorable>
@end

@implementation HKCumulativeQuantitySample {
    HKQuantity *_sumQuantity;
}

+ (instancetype)charon_cumulativeWithType:(HKQuantityType *)quantityType
                                     sum:(HKQuantity *)sum
                                startDate:(NSDate *)startDate
                                  endDate:(NSDate *)endDate
{
    return [[self alloc] charon_initWithCumulativeType:quantityType sum:sum startDate:startDate endDate:endDate];
}

- (instancetype)charon_initWithCumulativeType:(HKQuantityType *)quantityType
                                          sum:(HKQuantity *)sum
                                     startDate:(NSDate *)startDate
                                       endDate:(NSDate *)endDate
{
    HKCumulativeQuantitySample *sample =
        (HKCumulativeQuantitySample *)[self charon_initWithType:quantityType
                                                      metadata:nil
                                                     startDate:startDate
                                                       endDate:endDate];
    if (sample)
        sample->_sumQuantity = [sum copy];
    return sample;
}

- (HKQuantity *)sumQuantity
{
    return _sumQuantity;
}

- (NSString *)charon_storeTypeIdentifier
{
    return [(HKSample *)self sampleType].identifier ?: @"";
}

- (NSInteger)charon_storeKind
{
    return 1;
}

@end

@implementation HKCumulativeQuantitySample (CharonHKStorable)
@end
