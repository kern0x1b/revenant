#import <Foundation/Foundation.h>
#import "CharonDimension.h"

@implementation NSUnitElectricResistance

+ (instancetype)baseUnit
{
    return [self ohms];
}

+ (NSUnitElectricResistance *)megaohms
{
    static NSUnitElectricResistance *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitElectricResistance alloc] initWithSymbol:@"MΩ" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000000]];
    });
    return unit;
}

+ (NSUnitElectricResistance *)kiloohms
{
    static NSUnitElectricResistance *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitElectricResistance alloc] initWithSymbol:@"kΩ" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000]];
    });
    return unit;
}

+ (NSUnitElectricResistance *)ohms
{
    static NSUnitElectricResistance *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitElectricResistance alloc] initWithSpecifier:3842 symbol:@"Ω" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1]];
    });
    return unit;
}

+ (NSUnitElectricResistance *)milliohms
{
    static NSUnitElectricResistance *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitElectricResistance alloc] initWithSymbol:@"mΩ" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.001]];
    });
    return unit;
}

+ (NSUnitElectricResistance *)microohms
{
    static NSUnitElectricResistance *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitElectricResistance alloc] initWithSymbol:@"µΩ" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-06]];
    });
    return unit;
}

@end
