#import <HealthKit/HealthKit.h>

#import "RevenantHKStore.h"

@interface HKCumulativeQuantitySample (RevenantIOS130Internal)
- (instancetype)revenant_initWithCumulativeType:(HKQuantityType *)quantityType
                                          sum:(HKQuantity *)sum
                                     startDate:(NSDate *)startDate
                                       endDate:(NSDate *)endDate;
@end

@interface HKSample (RevenantIOS130Internal)
@property (readonly, copy) HKSampleType *sampleType;
- (instancetype)revenant_initWithType:(HKSampleType *)sampleType
                            metadata:(nullable NSDictionary *)metadata
                           startDate:(NSDate *)startDate
                             endDate:(NSDate *)endDate;
@end

@interface HKCumulativeQuantitySample (RevenantHKStorable) <RevenantHKStorable>
@end

@implementation HKCumulativeQuantitySample {
    HKQuantity *_sumQuantity;
}

+ (instancetype)revenant_cumulativeWithType:(HKQuantityType *)quantityType
                                     sum:(HKQuantity *)sum
                                startDate:(NSDate *)startDate
                                  endDate:(NSDate *)endDate
{
    return [[self alloc] revenant_initWithCumulativeType:quantityType sum:sum startDate:startDate endDate:endDate];
}

- (instancetype)revenant_initWithCumulativeType:(HKQuantityType *)quantityType
                                          sum:(HKQuantity *)sum
                                     startDate:(NSDate *)startDate
                                       endDate:(NSDate *)endDate
{
    HKCumulativeQuantitySample *sample =
        (HKCumulativeQuantitySample *)[self revenant_initWithType:quantityType
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

- (NSString *)revenant_storeTypeIdentifier
{
    return [(HKSample *)self sampleType].identifier ?: @"";
}

- (NSInteger)revenant_storeKind
{
    return 1;
}

@end

@implementation HKCumulativeQuantitySample (RevenantHKStorable)
@end
