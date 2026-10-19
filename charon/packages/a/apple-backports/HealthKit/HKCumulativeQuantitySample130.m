// HKCumulativeQuantitySample of iOS 13.0: a quantity sample whose value is the running total over a
// period, so it carries a sum as well as its own dates.
//
// One object per release: this file is of 13.0 alone.
//
// The header's whole surface is one readonly property, sumQuantity, over the 8.0 class's own type and
// dates. The header declares no initialiser, and the host answers NO for
// -initWithType:quantity:startDate:endDate: on this class, so the sample is made the way this library
// makes its other samples - through the superclass's own factory - and the sum is given to this class's
// own initialiser, which is this library's and is not in the library's public surface.
//
// A header and an image disagreement, recorded rather than resolved silently: the 26.2 header marks this
// class API_AVAILABLE(ios(13.0)) and the arm64 image of 12.0 does not carry its name at all (0
// occurrences, by exact string count, with startDate and endDate at 2 in the same image as the control) -
// while that image does carry HKCumulativeQuantitySeriesSample, the 12.0 subclass of this class, as a
// real class, with _OBJC_CLASS_$_ and _OBJC_METACLASS_$_ entries. So at 12.0 this class was either
// private or unnamed, and Apple documented it at 13.0. The header decides which group a member is in, so
// this one is of 13.0 and the subclass that needs it is of 12.0.
//
// HKCumulativeQuantitySeriesSample, the subclass, is not in this file: it is of 12.0, and this file is of
// 13.0.

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

// This class is one the store keeps, so it adopts the protocol the store's gate tests for. The row's own
// facts, the archive and the class method that reads one back are inherited from HKObject.
@interface HKCumulativeQuantitySample (CharonHKStorable) <CharonHKStorable>
@end

@implementation HKCumulativeQuantitySample {
    HKQuantity *_sumQuantity;
}

// The initialiser the header leaves out. The sum is this class's own fact and there is no public way to
// give one, so this is how a caller of this library makes one: [self alloc] is already this class, and
// the superclass's own path lays down the type and the two dates that every sample of this library is
// built with, so there is no second way to make a sample here. A subclass cannot change its class
// through [super -init...], which is why this is a class method and the sum is set on what it returns.
+ (instancetype)charon_cumulativeWithType:(HKQuantityType *)quantityType
                                     sum:(HKQuantity *)sum
                                startDate:(NSDate *)startDate
                                  endDate:(NSDate *)endDate
{
    return [[self alloc] charon_initWithCumulativeType:quantityType sum:sum startDate:startDate endDate:endDate];
}

// The same path as an instance initialiser, so a subclass of this class gets the type, the two dates and
// the running total through it and adds only what is its own. [self alloc] in a subclass is that subclass.
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

// The store's row facts. Kind 5 is this class: it is a quantity sample and not one, so the table needs a
// case of its own to read one back as this class rather than as its superclass.
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
