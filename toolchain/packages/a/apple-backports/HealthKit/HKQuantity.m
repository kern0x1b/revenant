#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"

@implementation HKQuantity {
    HKUnit *_unit;
    double _value;
}
CHARON_HEALTHKIT_UNCREATABLE_INIT

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (instancetype)quantityWithUnit:(HKUnit *)unit doubleValue:(double)value
{
    HKQuantity *quantity = [[HKQuantity alloc] charon_initWithUnit:unit value:value];
    return quantity;
}

- (instancetype)charon_initWithUnit:(HKUnit *)unit value:(double)value
{
    HKQuantity *fresh = [super init];
    if (fresh) {
        fresh->_unit = (HKUnit *)[unit copy];
        fresh->_value = value;
    }
    return fresh;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _unit = [[coder decodeObjectOfClass:[HKUnit class] forKey:@"unit"] copy];
        _value = [coder decodeDoubleForKey:@"value"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_unit forKey:@"unit"];
    [coder encodeDouble:_value forKey:@"value"];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [HKQuantity quantityWithUnit:_unit doubleValue:_value];
}

#pragma mark Reading a quantity

- (HKUnit *)charon_unit
{
    return _unit;
}

- (double)charon_rawValue
{
    return _value;
}

+ (instancetype)charon_quantityWithUnit:(HKUnit *)unit value:(double)value
{
    return [self quantityWithUnit:unit doubleValue:value];
}

- (double)doubleValueForUnit:(HKUnit *)unit
{
    if (![unit isKindOfClass:[HKUnit class]])
        [NSException raise:NSInvalidArgumentException format:@"%@ is not a unit.", unit];
    if (![_unit charon_isCompatibleWithUnit:unit]) {
        [NSException raise:NSInvalidArgumentException
                    format:@"The unit %@ is not of the same dimension as the unit %@ of this quantity.", unit.unitString,
                           _unit.unitString];
        return 0.0;
    }
    return [_unit charon_value:_value inUnit:unit];
}

- (BOOL)isCompatibleWithUnit:(HKUnit *)unit
{
    if (![unit isKindOfClass:[HKUnit class]])
        return NO;
    return [_unit charon_isCompatibleWithUnit:unit];
}

- (NSComparisonResult)compare:(HKQuantity *)quantity
{
    if (![quantity isKindOfClass:[HKQuantity class]])
        return NSOrderedSame;
    if (![_unit charon_isCompatibleWithUnit:((HKQuantity *)quantity).charon_unit]) {
        [NSException raise:NSInvalidArgumentException
                    format:@"The unit %@ of the given quantity is not of the same dimension as the unit %@ of this one.",
                           ((HKQuantity *)quantity).charon_unit.unitString, _unit.unitString];
        return NSOrderedSame;
    }
    double mine = [_unit charon_value:_value inUnit:_unit];
    double theirs = [((HKQuantity *)quantity).charon_unit charon_value:((HKQuantity *)quantity).charon_rawValue
                                                                inUnit:_unit];
    if (mine < theirs)
        return NSOrderedAscending;
    return mine > theirs ? NSOrderedDescending : NSOrderedSame;
}

- (BOOL)isEqual:(id)other
{
    if (self == other)
        return YES;
    if (![other isKindOfClass:[HKQuantity class]])
        return NO;
    if (![_unit charon_isCompatibleWithUnit:((HKQuantity *)other).charon_unit])
        return NO;
    return [self compare:other] == NSOrderedSame;
}

- (NSUInteger)hash
{
    return [@([self doubleValueForUnit:_unit]) hash];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%g %@", _value, _unit.unitString];
}

@end
