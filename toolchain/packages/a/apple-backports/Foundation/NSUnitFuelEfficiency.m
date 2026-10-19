#import <Foundation/Foundation.h>
#import "CharonDimension.h"

@implementation NSUnitFuelEfficiency

+ (instancetype)baseUnit
{
    return [self litersPer100Kilometers];
}

+ (NSUnitFuelEfficiency *)litersPer100Kilometers
{
    static NSUnitFuelEfficiency *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitFuelEfficiency alloc] initWithSpecifier:3330 symbol:@"L/100km" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1]];
    });
    return unit;
}

+ (NSUnitFuelEfficiency *)milesPerImperialGallon
{
    static NSUnitFuelEfficiency *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitFuelEfficiency alloc] initWithSpecifier:3331 symbol:@"mpg" converter:charon_reciprocal_converter(282.481)];
    });
    return unit;
}

+ (NSUnitFuelEfficiency *)milesPerGallon
{
    static NSUnitFuelEfficiency *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitFuelEfficiency alloc] initWithSpecifier:3329 symbol:@"mpg" converter:charon_reciprocal_converter(235.215)];
    });
    return unit;
}

@end
