#import <Foundation/Foundation.h>
#import "CharonDimension.h"

@implementation NSUnitDuration

+ (instancetype)baseUnit
{
    return [self seconds];
}

+ (NSUnitDuration *)hours
{
    static NSUnitDuration *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitDuration alloc] initWithSpecifier:1028 symbol:@"hr" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:3600]];
    });
    return unit;
}

+ (NSUnitDuration *)minutes
{
    static NSUnitDuration *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitDuration alloc] initWithSpecifier:1029 symbol:@"min" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:60]];
    });
    return unit;
}

+ (NSUnitDuration *)seconds
{
    static NSUnitDuration *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitDuration alloc] initWithSpecifier:1030 symbol:@"s" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1]];
    });
    return unit;
}

+ (NSUnitDuration *)milliseconds
{
    static NSUnitDuration *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitDuration alloc] initWithSymbol:@"ms" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.001]];
    });
    return unit;
}

+ (NSUnitDuration *)microseconds
{
    static NSUnitDuration *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitDuration alloc] initWithSymbol:@"µs" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-06]];
    });
    return unit;
}

+ (NSUnitDuration *)nanoseconds
{
    static NSUnitDuration *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitDuration alloc] initWithSymbol:@"ns" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-09]];
    });
    return unit;
}

+ (NSUnitDuration *)picoseconds
{
    static NSUnitDuration *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitDuration alloc] initWithSymbol:@"ps" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-12]];
    });
    return unit;
}

@end
