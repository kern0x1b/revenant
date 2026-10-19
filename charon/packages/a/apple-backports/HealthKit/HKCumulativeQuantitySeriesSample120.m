#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"

@interface HKCumulativeQuantitySample (CharonIOS120Internal)
- (instancetype)charon_initWithCumulativeType:(HKQuantityType *)quantityType
                                          sum:(HKQuantity *)sum
                                     startDate:(NSDate *)startDate
                                       endDate:(NSDate *)endDate;
@end

@interface HKCumulativeQuantitySeriesSample (CharonHKStorable) <CharonHKStorable>
@end

@implementation HKCumulativeQuantitySeriesSample {
    HKQuantity *_sum;
}

+ (instancetype)charon_seriesWithType:(HKQuantityType *)quantityType
                                 sum:(HKQuantity *)sum
                            startDate:(NSDate *)startDate
                              endDate:(NSDate *)endDate
{
    HKCumulativeQuantitySeriesSample *sample =
        (HKCumulativeQuantitySeriesSample *)[[self alloc] charon_initWithCumulativeType:quantityType
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

- (NSInteger)charon_storeKind
{
    return 6;
}

@end

@implementation HKCumulativeQuantitySeriesSample (CharonHKStorable)
@end
