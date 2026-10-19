#import <Foundation/Foundation.h>
#import "CharonDimension.h"

@implementation NSUnitArea

+ (instancetype)baseUnit
{
    return [self squareMeters];
}

+ (NSUnitArea *)squareMegameters
{
    static NSUnitArea *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitArea alloc] initWithSymbol:@"Mm²" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000000000000]];
    });
    return unit;
}

+ (NSUnitArea *)squareKilometers
{
    static NSUnitArea *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitArea alloc] initWithSpecifier:513 symbol:@"km²" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000000]];
    });
    return unit;
}

+ (NSUnitArea *)squareMeters
{
    static NSUnitArea *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitArea alloc] initWithSpecifier:512 symbol:@"m²" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1]];
    });
    return unit;
}

+ (NSUnitArea *)squareCentimeters
{
    static NSUnitArea *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitArea alloc] initWithSpecifier:518 symbol:@"cm²" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.0001]];
    });
    return unit;
}

+ (NSUnitArea *)squareMillimeters
{
    static NSUnitArea *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitArea alloc] initWithSymbol:@"mm²" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-06]];
    });
    return unit;
}

+ (NSUnitArea *)squareMicrometers
{
    static NSUnitArea *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitArea alloc] initWithSymbol:@"µm²" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-12]];
    });
    return unit;
}

+ (NSUnitArea *)squareNanometers
{
    static NSUnitArea *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitArea alloc] initWithSymbol:@"nm²" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-18]];
    });
    return unit;
}

+ (NSUnitArea *)squareInches
{
    static NSUnitArea *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitArea alloc] initWithSpecifier:519 symbol:@"in²" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.00064516]];
    });
    return unit;
}

+ (NSUnitArea *)squareFeet
{
    static NSUnitArea *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitArea alloc] initWithSpecifier:514 symbol:@"ft²" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.09290304]];
    });
    return unit;
}

+ (NSUnitArea *)squareYards
{
    static NSUnitArea *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitArea alloc] initWithSpecifier:520 symbol:@"yd²" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.83612736]];
    });
    return unit;
}

+ (NSUnitArea *)squareMiles
{
    static NSUnitArea *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitArea alloc] initWithSpecifier:515 symbol:@"mi²" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:2589988.110336]];
    });
    return unit;
}

+ (NSUnitArea *)acres
{
    static NSUnitArea *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitArea alloc] initWithSpecifier:516 symbol:@"ac" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:4046.8564224]];
    });
    return unit;
}

+ (NSUnitArea *)ares
{
    static NSUnitArea *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitArea alloc] initWithSymbol:@"a" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:100]];
    });
    return unit;
}

+ (NSUnitArea *)hectares
{
    static NSUnitArea *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitArea alloc] initWithSpecifier:517 symbol:@"ha" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:10000]];
    });
    return unit;
}

@end
