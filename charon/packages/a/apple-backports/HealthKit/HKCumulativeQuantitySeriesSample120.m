// HKCumulativeQuantitySeriesSample of iOS 12.0: the cumulative sample of a series, which carries its own
// sum over the period the series covers.
//
// One object per release: this file is of 12.0 alone. Its superclass, HKCumulativeQuantitySample, is of
// 13.0 and lives in HKCumulativeQuantitySample130.m; a 12.0 member whose superclass is of 13.0 is
// possible because this class is in the 12.0 image and that one is not - see the facts.
//
// The header's whole surface is one readonly property, sum, over the superclass's own sumQuantity. There
// is no availability line of its own on the class in the 26.2 header, so the property inherits the class's,
// which the image places at 12.0: by substring count with a boundary, the class's name is 7 in the arm64
// image of 12.0 and 0 in the armv7 image of 8.0, with sumQuantity at 4 in both as the control, and the
// class is there as a real class (_OBJC_CLASS_$_ and _OBJC_METACLASS_$_ entries). The superclass's own
// name is 0 in the same 12.0 image, which is the disagreement recorded for the 13.0 class.

#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"

// The superclass lays down the type, the two dates and the running total, and does it on [self alloc],
// so this class gets all of it and adds its own sum. The name is this library's, and is the same one the
// 13.0 class carries as a class method - called here on the instance [self alloc] has made, which is
// this class, so the superclass's path runs and this class's own fact is set on what it returns.
@interface HKCumulativeQuantitySample (CharonIOS120Internal)
- (instancetype)charon_initWithCumulativeType:(HKQuantityType *)quantityType
                                          sum:(HKQuantity *)sum
                                     startDate:(NSDate *)startDate
                                       endDate:(NSDate *)endDate;
@end

// This class is one the store keeps, so it adopts the protocol the store's gate tests for; the row's own
// facts, the archive and the class method that reads one back are inherited from HKObject.
@interface HKCumulativeQuantitySeriesSample (CharonHKStorable) <CharonHKStorable>
@end

@implementation HKCumulativeQuantitySeriesSample {
    HKQuantity *_sum;
}

// The initialiser the header leaves out, as its superclass's is: [self alloc] is already this class, the
// superclass's own path lays down the type, the two dates and the running total, and this class's own sum
// is set on what it returns.
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

// This class's own half of the archive, which it did not have: the superclass's coder lays down the type,
// the two dates and the running total, and without this the series' own sum was lost, so a sample read
// back from the store came as a cumulative sample with no sum - the one fact that makes it a series'.
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

// The store's row facts. Kind 6 is this class, beside kind 5 for its superclass: the table names a class
// per kind, and this one is not its superclass.
- (NSInteger)charon_storeKind
{
    return 6;
}

@end

@implementation HKCumulativeQuantitySeriesSample (CharonHKStorable)
@end
