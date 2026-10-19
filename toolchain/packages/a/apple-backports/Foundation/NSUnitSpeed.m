#import <Foundation/Foundation.h>
#import "CharonDimension.h"

@implementation NSUnitSpeed

+ (instancetype)baseUnit
{
    return [self metersPerSecond];
}

+ (NSUnitSpeed *)metersPerSecond
{
    static NSUnitSpeed *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitSpeed alloc] initWithSpecifier:2304 symbol:@"m/s" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1]];
    });
    return unit;
}

+ (NSUnitSpeed *)kilometersPerHour
{
    static NSUnitSpeed *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitSpeed alloc] initWithSpecifier:2305 symbol:@"km/h" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.277778]];
    });
    return unit;
}

+ (NSUnitSpeed *)milesPerHour
{
    static NSUnitSpeed *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitSpeed alloc] initWithSpecifier:2306 symbol:@"mph" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.44704]];
    });
    return unit;
}

+ (NSUnitSpeed *)knots
{
    static NSUnitSpeed *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitSpeed alloc] initWithSpecifier:2307 symbol:@"kn" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.514444]];
    });
    return unit;
}

@end
