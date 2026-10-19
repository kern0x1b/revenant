#import <Foundation/Foundation.h>
#import "CharonDimension.h"

@implementation NSUnitPressure

+ (instancetype)baseUnit
{
    return [self newtonsPerMetersSquared];
}

+ (NSUnitPressure *)newtonsPerMetersSquared
{
    static NSUnitPressure *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitPressure alloc] initWithSymbol:@"N/m²" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1]];
    });
    return unit;
}

+ (NSUnitPressure *)gigapascals
{
    static NSUnitPressure *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitPressure alloc] initWithSymbol:@"GPa" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000000000]];
    });
    return unit;
}

+ (NSUnitPressure *)megapascals
{
    static NSUnitPressure *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitPressure alloc] initWithSymbol:@"MPa" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000000]];
    });
    return unit;
}

+ (NSUnitPressure *)kilopascals
{
    static NSUnitPressure *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitPressure alloc] initWithSymbol:@"kPa" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000]];
    });
    return unit;
}

+ (NSUnitPressure *)hectopascals
{
    static NSUnitPressure *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitPressure alloc] initWithSpecifier:2048 symbol:@"hPa" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:100]];
    });
    return unit;
}

+ (NSUnitPressure *)inchesOfMercury
{
    static NSUnitPressure *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitPressure alloc] initWithSpecifier:2049 symbol:@"inHg" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:3386.39]];
    });
    return unit;
}

+ (NSUnitPressure *)bars
{
    static NSUnitPressure *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitPressure alloc] initWithSymbol:@"bar" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:100000]];
    });
    return unit;
}

+ (NSUnitPressure *)millibars
{
    static NSUnitPressure *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitPressure alloc] initWithSpecifier:2050 symbol:@"mbar" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:100]];
    });
    return unit;
}

+ (NSUnitPressure *)millimetersOfMercury
{
    static NSUnitPressure *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitPressure alloc] initWithSpecifier:2051 symbol:@"mmHg" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:133.322]];
    });
    return unit;
}

+ (NSUnitPressure *)poundsForcePerSquareInch
{
    static NSUnitPressure *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitPressure alloc] initWithSpecifier:2052 symbol:@"psi" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:6894.76]];
    });
    return unit;
}

@end
