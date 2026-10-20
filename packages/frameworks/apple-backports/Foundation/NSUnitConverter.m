#import <Foundation/Foundation.h>

@implementation NSUnitConverter

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (double)baseUnitValueFromValue:(double)value
{
    return value;
}

- (double)valueFromBaseUnitValue:(double)baseUnitValue
{
    return baseUnitValue;
}

@end
