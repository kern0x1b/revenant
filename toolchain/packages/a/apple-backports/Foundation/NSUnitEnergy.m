#import <Foundation/Foundation.h>
#import "CharonDimension.h"

@implementation NSUnitEnergy

+ (instancetype)baseUnit
{
    return [self joules];
}

+ (NSUnitEnergy *)kilojoules
{
    static NSUnitEnergy *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitEnergy alloc] initWithSpecifier:3076 symbol:@"kJ" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000]];
    });
    return unit;
}

+ (NSUnitEnergy *)joules
{
    static NSUnitEnergy *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitEnergy alloc] initWithSpecifier:3074 symbol:@"J" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1]];
    });
    return unit;
}

+ (NSUnitEnergy *)kilocalories
{
    static NSUnitEnergy *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitEnergy alloc] initWithSpecifier:3075 symbol:@"kCal" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:4184]];
    });
    return unit;
}

+ (NSUnitEnergy *)calories
{
    static NSUnitEnergy *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitEnergy alloc] initWithSpecifier:3072 symbol:@"cal" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:4.184]];
    });
    return unit;
}

+ (NSUnitEnergy *)kilowattHours
{
    static NSUnitEnergy *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitEnergy alloc] initWithSpecifier:3077 symbol:@"kWh" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:3600000]];
    });
    return unit;
}

@end
