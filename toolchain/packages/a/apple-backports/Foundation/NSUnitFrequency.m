#import <Foundation/Foundation.h>
#import "CharonDimension.h"

@implementation NSUnitFrequency

+ (instancetype)baseUnit
{
    return [self hertz];
}

+ (NSUnitFrequency *)terahertz
{
    static NSUnitFrequency *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitFrequency alloc] initWithSymbol:@"THz" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000000000000]];
    });
    return unit;
}

+ (NSUnitFrequency *)gigahertz
{
    static NSUnitFrequency *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitFrequency alloc] initWithSpecifier:4099 symbol:@"GHz" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000000000]];
    });
    return unit;
}

+ (NSUnitFrequency *)megahertz
{
    static NSUnitFrequency *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitFrequency alloc] initWithSpecifier:4098 symbol:@"MHz" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000000]];
    });
    return unit;
}

+ (NSUnitFrequency *)kilohertz
{
    static NSUnitFrequency *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitFrequency alloc] initWithSpecifier:4097 symbol:@"kHz" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000]];
    });
    return unit;
}

+ (NSUnitFrequency *)hertz
{
    static NSUnitFrequency *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitFrequency alloc] initWithSpecifier:4096 symbol:@"Hz" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1]];
    });
    return unit;
}

+ (NSUnitFrequency *)millihertz
{
    static NSUnitFrequency *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitFrequency alloc] initWithSymbol:@"mHz" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.001]];
    });
    return unit;
}

+ (NSUnitFrequency *)microhertz
{
    static NSUnitFrequency *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitFrequency alloc] initWithSymbol:@"µHz" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-06]];
    });
    return unit;
}

+ (NSUnitFrequency *)nanohertz
{
    static NSUnitFrequency *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitFrequency alloc] initWithSymbol:@"nHz" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-09]];
    });
    return unit;
}

+ (NSUnitFrequency *)framesPerSecond
{
    static NSUnitFrequency *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitFrequency alloc] initWithSymbol:@"fps" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1]];
    });
    return unit;
}

@end
