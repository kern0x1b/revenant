#import <Foundation/Foundation.h>
#import "CharonDimension.h"

@implementation NSUnitTemperature

+ (instancetype)baseUnit
{
    return [self kelvin];
}

+ (NSUnitTemperature *)kelvin
{
    static NSUnitTemperature *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitTemperature alloc] initWithSpecifier:2562 symbol:@"K" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1]];
    });
    return unit;
}

+ (NSUnitTemperature *)celsius
{
    static NSUnitTemperature *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitTemperature alloc] initWithSpecifier:2560 symbol:@"°C" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1 constant:273.15]];
    });
    return unit;
}

+ (NSUnitTemperature *)fahrenheit
{
    static NSUnitTemperature *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitTemperature alloc] initWithSpecifier:2561 symbol:@"°F" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.55555555555556 constant:255.37222222222428]];
    });
    return unit;
}

@end
