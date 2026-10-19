#import <Foundation/Foundation.h>
#import "CharonDimension.h"

@implementation NSUnitAcceleration

+ (instancetype)baseUnit
{
    return [self metersPerSecondSquared];
}

+ (NSUnitAcceleration *)metersPerSecondSquared
{
    static NSUnitAcceleration *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitAcceleration alloc] initWithSpecifier:1 symbol:@"m/s²" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1]];
    });
    return unit;
}

+ (NSUnitAcceleration *)gravity
{
    static NSUnitAcceleration *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitAcceleration alloc] initWithSpecifier:0 symbol:@"g" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:9.81]];
    });
    return unit;
}

@end
