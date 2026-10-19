// HKQuantityType: a type of HKQuantitySample, what it is counted in and how its values are added up.

#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"
#import "CharonHKTypes.h"

@implementation HKQuantityType {
    NSString *_canonicalUnitString;
    CharonHKAggregationStyle _aggregationStyle;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        _canonicalUnitString = [[coder decodeObjectOfClass:[NSString class] forKey:@"canonicalUnit"] copy];
        _aggregationStyle = (CharonHKAggregationStyle)[coder decodeIntForKey:@"aggregation"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_canonicalUnitString forKey:@"canonicalUnit"];
    [coder encodeInt:(NSInteger)_aggregationStyle forKey:@"aggregation"];
}

- (id)copyWithZone:(NSZone *)zone
{
    HKQuantityType *copy = [super copyWithZone:zone];
    if (copy) {
        copy->_canonicalUnitString = [_canonicalUnitString copy];
        copy->_aggregationStyle = _aggregationStyle;
    }
    return copy;
}

#pragma mark The store

- (NSInteger)charon_storeKind
{
    return CharonHKTypeKindQuantity;
}

- (void)charon_setCanonicalUnitString:(NSString *)unitString aggregationStyle:(NSInteger)aggregationStyle
{
    _canonicalUnitString = [unitString copy];
    _aggregationStyle = (CharonHKAggregationStyle)aggregationStyle;
}

- (NSInteger)charon_aggregationStyleValue
{
    return (NSInteger)_aggregationStyle;
}

- (NSString *)charon_canonicalUnitString
{
    return _canonicalUnitString;
}

- (nullable HKUnit *)charon_canonicalUnit
{
    return [HKUnit charon_canonicalUnitForType:self];
}

#pragma mark The header

- (HKQuantityAggregationStyle)aggregationStyle
{
    // The two cases HKQuantityAggregationStyle has: a cumulative type aggregates by summing its
    // values, and a discrete one arithmetically, which is what the SDK's own comment of each
    // quantity type says its aggregation is.
    switch (_aggregationStyle) {
    case CharonHKAggregationCumulativeSum:
        return HKQuantityAggregationStyleCumulative;
    default:
        return HKQuantityAggregationStyleDiscreteArithmetic;
    }
}

- (BOOL)isCompatibleWithUnit:(HKUnit *)unit
{
    HKUnit *canonical = [self charon_canonicalUnit];
    if (!canonical)
        return NO;
    return [canonical charon_isCompatibleWithUnit:unit];
}

@end
