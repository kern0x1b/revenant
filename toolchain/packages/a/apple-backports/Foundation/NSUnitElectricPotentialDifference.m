#import <Foundation/Foundation.h>
#import "CharonDimension.h"

@implementation NSUnitElectricPotentialDifference

+ (instancetype)baseUnit
{
    return [self volts];
}

+ (NSUnitElectricPotentialDifference *)megavolts
{
    static NSUnitElectricPotentialDifference *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitElectricPotentialDifference alloc] initWithSymbol:@"MV" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000000]];
    });
    return unit;
}

+ (NSUnitElectricPotentialDifference *)kilovolts
{
    static NSUnitElectricPotentialDifference *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitElectricPotentialDifference alloc] initWithSymbol:@"kV" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000]];
    });
    return unit;
}

+ (NSUnitElectricPotentialDifference *)volts
{
    static NSUnitElectricPotentialDifference *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitElectricPotentialDifference alloc] initWithSpecifier:3843 symbol:@"V" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1]];
    });
    return unit;
}

+ (NSUnitElectricPotentialDifference *)millivolts
{
    static NSUnitElectricPotentialDifference *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitElectricPotentialDifference alloc] initWithSymbol:@"mV" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.001]];
    });
    return unit;
}

+ (NSUnitElectricPotentialDifference *)microvolts
{
    static NSUnitElectricPotentialDifference *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitElectricPotentialDifference alloc] initWithSymbol:@"µV" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-06]];
    });
    return unit;
}

@end
