#import <Foundation/Foundation.h>
#import "CharonDimension.h"

@implementation NSUnitPower

+ (instancetype)baseUnit
{
    return [self watts];
}

+ (NSUnitPower *)terawatts
{
    static NSUnitPower *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitPower alloc] initWithSymbol:@"TW" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000000000000]];
    });
    return unit;
}

+ (NSUnitPower *)gigawatts
{
    static NSUnitPower *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitPower alloc] initWithSpecifier:1797 symbol:@"GW" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000000000]];
    });
    return unit;
}

+ (NSUnitPower *)megawatts
{
    static NSUnitPower *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitPower alloc] initWithSpecifier:1796 symbol:@"MW" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000000]];
    });
    return unit;
}

+ (NSUnitPower *)kilowatts
{
    static NSUnitPower *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitPower alloc] initWithSpecifier:1793 symbol:@"kW" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000]];
    });
    return unit;
}

+ (NSUnitPower *)watts
{
    static NSUnitPower *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitPower alloc] initWithSpecifier:1792 symbol:@"W" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1]];
    });
    return unit;
}

+ (NSUnitPower *)milliwatts
{
    static NSUnitPower *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitPower alloc] initWithSpecifier:1795 symbol:@"mW" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.001]];
    });
    return unit;
}

+ (NSUnitPower *)microwatts
{
    static NSUnitPower *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitPower alloc] initWithSymbol:@"µW" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-06]];
    });
    return unit;
}

+ (NSUnitPower *)nanowatts
{
    static NSUnitPower *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitPower alloc] initWithSymbol:@"nW" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-09]];
    });
    return unit;
}

+ (NSUnitPower *)picowatts
{
    static NSUnitPower *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitPower alloc] initWithSymbol:@"pW" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-12]];
    });
    return unit;
}

+ (NSUnitPower *)femtowatts
{
    static NSUnitPower *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitPower alloc] initWithSymbol:@"fW" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-15]];
    });
    return unit;
}

+ (NSUnitPower *)horsepower
{
    static NSUnitPower *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitPower alloc] initWithSpecifier:1794 symbol:@"hp" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:745.7]];
    });
    return unit;
}

@end
