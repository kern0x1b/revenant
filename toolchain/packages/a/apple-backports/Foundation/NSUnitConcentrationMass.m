#import <Foundation/Foundation.h>
#import "CharonDimension.h"

@implementation NSUnitConcentrationMass

+ (instancetype)baseUnit
{
    return [self gramsPerLiter];
}

+ (NSUnitConcentrationMass *)gramsPerLiter
{
    static NSUnitConcentrationMass *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitConcentrationMass alloc] initWithSymbol:@"g/L" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1]];
    });
    return unit;
}

+ (NSUnitConcentrationMass *)milligramsPerDeciliter
{
    static NSUnitConcentrationMass *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitConcentrationMass alloc] initWithSpecifier:4609 symbol:@"mg/dL" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.01]];
    });
    return unit;
}

+ (NSUnitConcentrationMass *)millimolesPerLiterWithGramsPerMole:(double)gramsPerMole
{
    return [[NSUnitConcentrationMass alloc] initWithSpecifier:4610 symbol:@"mmol/L"
                                                    converter:[[NSUnitConverterLinear alloc] initWithCoefficient:gramsPerMole * 0.001]];
}

@end
