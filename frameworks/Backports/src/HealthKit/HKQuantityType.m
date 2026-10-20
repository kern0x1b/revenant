#import <HealthKit/HealthKit.h>

#import "RevenantHKStore.h"
#import "RevenantHKTypes.h"

@implementation HKQuantityType {
    NSString *_canonicalUnitString;
    RevenantHKAggregationStyle _aggregationStyle;
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
        _aggregationStyle = (RevenantHKAggregationStyle)[coder decodeIntForKey:@"aggregation"];
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

- (NSInteger)revenant_storeKind
{
    return RevenantHKTypeKindQuantity;
}

- (void)revenant_setCanonicalUnitString:(NSString *)unitString aggregationStyle:(NSInteger)aggregationStyle
{
    _canonicalUnitString = [unitString copy];
    _aggregationStyle = (RevenantHKAggregationStyle)aggregationStyle;
}

- (NSInteger)revenant_aggregationStyleValue
{
    return (NSInteger)_aggregationStyle;
}

- (NSString *)revenant_canonicalUnitString
{
    return _canonicalUnitString;
}

- (nullable HKUnit *)revenant_canonicalUnit
{
    return [HKUnit revenant_canonicalUnitForType:self];
}

#pragma mark The header

- (HKQuantityAggregationStyle)aggregationStyle
{
    switch (_aggregationStyle) {
    case RevenantHKAggregationCumulativeSum:
        return HKQuantityAggregationStyleCumulative;
    default:
        return HKQuantityAggregationStyleDiscreteArithmetic;
    }
}

- (BOOL)isCompatibleWithUnit:(HKUnit *)unit
{
    HKUnit *canonical = [self revenant_canonicalUnit];
    if (!canonical)
        return NO;
    return [canonical revenant_isCompatibleWithUnit:unit];
}

@end
