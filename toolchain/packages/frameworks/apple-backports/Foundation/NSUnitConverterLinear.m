#import <Foundation/Foundation.h>

@implementation NSUnitConverterLinear

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoefficient:(double)coefficient
{
    return [self initWithCoefficient:coefficient constant:0];
}

- (instancetype)initWithCoefficient:(double)coefficient constant:(double)constant
{
    if ((self = [super init])) {
        _coefficient = coefficient;
        _constant = constant;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (!coder.allowsKeyedCoding) {
        [NSException raise:NSInvalidArgumentException format:@"NSUnitConverterLinear cannot be decoded by non-keyed archivers"];
        return nil;
    }
    return [self initWithCoefficient:[coder decodeDoubleForKey:@"NS.coefficient"] constant:[coder decodeDoubleForKey:@"NS.constant"]];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    if (!coder.allowsKeyedCoding) {
        [NSException raise:NSInvalidArgumentException format:@"NSUnitConverterLinear encoder does not allow non-keyed coding!"];
        return;
    }
    [coder encodeDouble:_coefficient forKey:@"NS.coefficient"];
    [coder encodeDouble:_constant forKey:@"NS.constant"];
}

- (double)coefficient
{
    return _coefficient;
}

- (double)constant
{
    return _constant;
}

- (double)baseUnitValueFromValue:(double)value
{
    return _coefficient * value + _constant;
}

- (double)valueFromBaseUnitValue:(double)baseUnitValue
{
    return (baseUnitValue + (-1 * _constant)) / _coefficient;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[NSUnitConverterLinear class]])
        return NO;
    NSUnitConverterLinear *other = object;
    return _coefficient == other.coefficient && _constant == other.constant;
}

- (NSString *)description
{
    return [[super description] stringByAppendingString:[NSString stringWithFormat:@" coefficient = %f, constant = %f", _coefficient, _constant]];
}

@end
