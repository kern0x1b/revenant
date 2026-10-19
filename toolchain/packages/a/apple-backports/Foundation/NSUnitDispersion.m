#import <Foundation/Foundation.h>
#import "CharonDimension.h"

@implementation NSUnitDispersion

+ (instancetype)baseUnit
{
    return [self partsPerMillion];
}

+ (NSUnitDispersion *)partsPerMillion
{
    static NSUnitDispersion *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitDispersion alloc] initWithSpecifier:4611 symbol:@"ppm" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1]];
    });
    return unit;
}

@end
