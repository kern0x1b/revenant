#import <Foundation/Foundation.h>
#import "CharonDimension.h"

@implementation NSUnitIlluminance

+ (instancetype)baseUnit
{
    return [self lux];
}

+ (NSUnitIlluminance *)lux
{
    static NSUnitIlluminance *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitIlluminance alloc] initWithSpecifier:4352 symbol:@"lx" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1]];
    });
    return unit;
}

@end
