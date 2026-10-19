#import <Foundation/Foundation.h>
#import "CharonDimension.h"

static Class charon_dimension_kind(NSUnit *unit)
{
    if (![unit isKindOfClass:[NSDimension class]])
        return Nil;
    Class kind = [unit class];
    while (kind && class_getSuperclass(kind) != [NSDimension class])
        kind = class_getSuperclass(kind);
    return kind;
}

@implementation NSMeasurement

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithDoubleValue:(double)doubleValue unit:(NSUnit *)unit
{
    if (![unit isKindOfClass:[NSUnit class]]) {
        [NSException raise:NSInvalidArgumentException format:@"Must pass in an NSUnit object!"];
        return nil;
    }
    if ((self = [super init])) {
        _doubleValue = doubleValue;
        _unit = [unit copy];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (!coder.allowsKeyedCoding) {
        [NSException raise:NSInvalidArgumentException format:@"NSMeasurement cannot be decoded by non-keyed archivers"];
        return nil;
    }
    double value = [coder decodeDoubleForKey:@"NS.value"];
    NSUnit *unit = [coder decodeObjectOfClass:[NSUnit class] forKey:@"NS.unit"];
    if (!unit) {
        [coder failWithError:[NSError errorWithDomain:NSCocoaErrorDomain code:NSCoderReadCorruptError
                                             userInfo:@{NSLocalizedDescriptionKey: @"Unit class object has been corrupted!"}]];
        return nil;
    }
    return [self initWithDoubleValue:value unit:unit];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    if (!coder.allowsKeyedCoding) {
        [NSException raise:NSInvalidArgumentException format:@"NSMeasurement cannot be encoded by non-keyed archivers"];
        return;
    }
    [coder encodeDouble:_doubleValue forKey:@"NS.value"];
    [coder encodeObject:_unit forKey:@"NS.unit"];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (NSUnit *)unit
{
    return _unit;
}

- (double)doubleValue
{
    return _doubleValue;
}

- (BOOL)canBeConvertedToUnit:(NSUnit *)unit
{
    Class mine = charon_dimension_kind(_unit), theirs = charon_dimension_kind(unit);
    if (mine || theirs)
        return mine == theirs;
    return [_unit class] == [unit class];
}

- (NSMeasurement *)measurementByConvertingToUnit:(NSUnit *)unit
{
    if (![self canBeConvertedToUnit:unit]) {
        [NSException raise:NSInvalidArgumentException format:@"Cannot convert measurements of differing unit types! self: %@ unit: %@",
                                                            [_unit class], [unit class]];
        return nil;
    }
    if ([_unit isEqual:unit])
        return [[NSMeasurement alloc] initWithDoubleValue:_doubleValue unit:unit];
    if (!charon_dimension_kind(_unit)) {
        [NSException raise:NSInvalidArgumentException format:@"Cannot convert differing units that are non-dimensional! lhs: %@ rhs: %@",
                                                            [_unit class], [unit class]];
        return nil;
    }
    double base = [[(NSDimension *)_unit converter] baseUnitValueFromValue:_doubleValue];
    return [[NSMeasurement alloc] initWithDoubleValue:[[(NSDimension *)unit converter] valueFromBaseUnitValue:base] unit:unit];
}

- (NSMeasurement *)charon_combineWith:(NSMeasurement *)measurement sign:(double)sign verb:(NSString *)verb
{
    if ([_unit isEqual:measurement.unit])
        return [[NSMeasurement alloc] initWithDoubleValue:_doubleValue + sign * measurement.doubleValue unit:_unit];
    if (!charon_dimension_kind(_unit)) {
        [NSException raise:NSInvalidArgumentException format:@"Cannot %@ differing units that are non-dimensional! lhs: %@ rhs: %@",
                                                            verb, [_unit class], [measurement.unit class]];
        return nil;
    }
    if (![self canBeConvertedToUnit:measurement.unit]) {
        [NSException raise:NSInvalidArgumentException format:@"Cannot %@ measurements of differing unit types! lhs: %@ rhs: %@",
                                                            verb, [_unit class], [measurement.unit class]];
        return nil;
    }
    NSDimension *base = [[(NSDimension *)_unit class] baseUnit];
    double value = [self measurementByConvertingToUnit:base].doubleValue
                 + sign * [measurement measurementByConvertingToUnit:base].doubleValue;
    return [[NSMeasurement alloc] initWithDoubleValue:value unit:base];
}

- (NSMeasurement *)measurementByAddingMeasurement:(NSMeasurement *)measurement
{
    return [self charon_combineWith:measurement sign:1 verb:@"add"];
}

- (NSMeasurement *)measurementBySubtractingMeasurement:(NSMeasurement *)measurement
{
    return [self charon_combineWith:measurement sign:-1 verb:@"subtract"];
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[NSMeasurement class]])
        return NO;
    NSMeasurement *other = object;
    return _doubleValue == other.doubleValue && [_unit isEqual:other.unit];
}

- (NSUInteger)hash
{
    return [@(_doubleValue) hash] ^ _unit.hash;
}

- (NSString *)description
{
    return [[super description] stringByAppendingString:[NSString stringWithFormat:@" value: %f unit: %@", _doubleValue, _unit.symbol]];
}

@end
