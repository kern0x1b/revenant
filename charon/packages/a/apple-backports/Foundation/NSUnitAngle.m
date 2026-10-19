#import <Foundation/Foundation.h>
#import "CharonDimension.h"

@implementation NSUnitAngle

+ (instancetype)baseUnit
{
    return [self degrees];
}

+ (NSUnitAngle *)degrees
{
    static NSUnitAngle *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitAngle alloc] initWithSpecifier:256 symbol:@"°" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1]];
    });
    return unit;
}

+ (NSUnitAngle *)arcMinutes
{
    static NSUnitAngle *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitAngle alloc] initWithSpecifier:257 symbol:@"ʹ" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.016667]];
    });
    return unit;
}

+ (NSUnitAngle *)arcSeconds
{
    static NSUnitAngle *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitAngle alloc] initWithSpecifier:258 symbol:@"ʺ" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.00027778]];
    });
    return unit;
}

+ (NSUnitAngle *)radians
{
    static NSUnitAngle *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitAngle alloc] initWithSpecifier:259 symbol:@"rad" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:57.29577951308232]];
    });
    return unit;
}

+ (NSUnitAngle *)gradians
{
    static NSUnitAngle *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitAngle alloc] initWithSymbol:@"grad" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.9]];
    });
    return unit;
}

+ (NSUnitAngle *)revolutions
{
    static NSUnitAngle *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitAngle alloc] initWithSpecifier:260 symbol:@"rev" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:360]];
    });
    return unit;
}

@end
