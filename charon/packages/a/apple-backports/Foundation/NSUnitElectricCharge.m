#import <Foundation/Foundation.h>
#import "CharonDimension.h"

@implementation NSUnitElectricCharge

+ (instancetype)baseUnit
{
    return [self coulombs];
}

+ (NSUnitElectricCharge *)coulombs
{
    static NSUnitElectricCharge *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitElectricCharge alloc] initWithSymbol:@"C" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1]];
    });
    return unit;
}

+ (NSUnitElectricCharge *)megaampereHours
{
    static NSUnitElectricCharge *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitElectricCharge alloc] initWithSymbol:@"MAh" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:3600000000]];
    });
    return unit;
}

+ (NSUnitElectricCharge *)kiloampereHours
{
    static NSUnitElectricCharge *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitElectricCharge alloc] initWithSymbol:@"kAh" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:3600000]];
    });
    return unit;
}

+ (NSUnitElectricCharge *)ampereHours
{
    static NSUnitElectricCharge *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitElectricCharge alloc] initWithSymbol:@"Ah" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:3600]];
    });
    return unit;
}

+ (NSUnitElectricCharge *)milliampereHours
{
    static NSUnitElectricCharge *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitElectricCharge alloc] initWithSymbol:@"mAh" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:3.6]];
    });
    return unit;
}

+ (NSUnitElectricCharge *)microampereHours
{
    static NSUnitElectricCharge *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitElectricCharge alloc] initWithSymbol:@"µAh" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.0036]];
    });
    return unit;
}

@end
