#import <Foundation/Foundation.h>
#import "CharonDimension.h"

@implementation NSUnitElectricCurrent

+ (instancetype)baseUnit
{
    return [self amperes];
}

+ (NSUnitElectricCurrent *)megaamperes
{
    static NSUnitElectricCurrent *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitElectricCurrent alloc] initWithSymbol:@"MA" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000000]];
    });
    return unit;
}

+ (NSUnitElectricCurrent *)kiloamperes
{
    static NSUnitElectricCurrent *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitElectricCurrent alloc] initWithSymbol:@"kA" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000]];
    });
    return unit;
}

+ (NSUnitElectricCurrent *)amperes
{
    static NSUnitElectricCurrent *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitElectricCurrent alloc] initWithSpecifier:3840 symbol:@"A" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1]];
    });
    return unit;
}

+ (NSUnitElectricCurrent *)milliamperes
{
    static NSUnitElectricCurrent *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitElectricCurrent alloc] initWithSpecifier:3841 symbol:@"mA" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.001]];
    });
    return unit;
}

+ (NSUnitElectricCurrent *)microamperes
{
    static NSUnitElectricCurrent *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitElectricCurrent alloc] initWithSymbol:@"µA" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-06]];
    });
    return unit;
}

@end
