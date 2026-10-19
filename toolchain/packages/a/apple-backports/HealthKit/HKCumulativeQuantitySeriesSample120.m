#import <HealthKit/HealthKit.h>

#import "RevenantHKStore.h"

@interface HKCumulativeQuantitySample (RevenantIOS120Internal)
- (instancetype)revenant_initWithCumulativeType:(HKQuantityType *)quantityType
                                          sum:(HKQuantity *)sum
                                     startDate:(NSDate *)startDate
                                       endDate:(NSDate *)endDate;
@end

@interface HKCumulativeQuantitySeriesSample (RevenantHKStorable) <RevenantHKStorable>
@end

@implementation HKCumulativeQuantitySeriesSample {
    HKQuantity *_sum;
}

+ (instancetype)revenant_seriesWithType:(HKQuantityType *)quantityType
                                 sum:(HKQuantity *)sum
                            startDate:(NSDate *)startDate
                              endDate:(NSDate *)endDate
{
    HKCumulativeQuantitySeriesSample *sample =
        (HKCumulativeQuantitySeriesSample *)[[self alloc] revenant_initWithCumulativeType:quantityType
                                                                                     sum:sum
                                                                                startDate:startDate
                                                                                  endDate:endDate];
    if (sample)
        sample->_sum = [sum copy];
    return sample;
}

- (HKQuantity *)sum
{
    return _sum;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    HKCumulativeQuantitySeriesSample *sample = [super initWithCoder:coder];
    if (sample)
        sample->_sum = [[coder decodeObjectOfClass:[HKQuantity class] forKey:@"sum"] copy];
    return sample;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_sum forKey:@"sum"];
}

- (NSInteger)revenant_storeKind
{
    return 6;
}

@end

@implementation HKCumulativeQuantitySeriesSample (RevenantHKStorable)
@end
