#import <Foundation/Foundation.h>
#import "CharonDimension.h"

@implementation NSUnitVolume

+ (instancetype)baseUnit
{
    return [self liters];
}

+ (NSUnitVolume *)megaliters
{
    static NSUnitVolume *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitVolume alloc] initWithSpecifier:2823 symbol:@"ML" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000000]];
    });
    return unit;
}

+ (NSUnitVolume *)kiloliters
{
    static NSUnitVolume *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitVolume alloc] initWithSymbol:@"kL" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000]];
    });
    return unit;
}

+ (NSUnitVolume *)liters
{
    static NSUnitVolume *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitVolume alloc] initWithSpecifier:2816 symbol:@"L" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1]];
    });
    return unit;
}

+ (NSUnitVolume *)deciliters
{
    static NSUnitVolume *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitVolume alloc] initWithSpecifier:2821 symbol:@"dL" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.1]];
    });
    return unit;
}

+ (NSUnitVolume *)centiliters
{
    static NSUnitVolume *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitVolume alloc] initWithSpecifier:2820 symbol:@"cL" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.01]];
    });
    return unit;
}

+ (NSUnitVolume *)milliliters
{
    static NSUnitVolume *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitVolume alloc] initWithSpecifier:2819 symbol:@"mL" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.001]];
    });
    return unit;
}

+ (NSUnitVolume *)cubicKilometers
{
    static NSUnitVolume *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitVolume alloc] initWithSpecifier:2817 symbol:@"km³" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000000000000]];
    });
    return unit;
}

+ (NSUnitVolume *)cubicMeters
{
    static NSUnitVolume *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitVolume alloc] initWithSpecifier:2825 symbol:@"m³" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000]];
    });
    return unit;
}

+ (NSUnitVolume *)cubicDecimeters
{
    static NSUnitVolume *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitVolume alloc] initWithSymbol:@"dm³" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1]];
    });
    return unit;
}

+ (NSUnitVolume *)cubicCentimeters
{
    static NSUnitVolume *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitVolume alloc] initWithSpecifier:2824 symbol:@"cm³" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.001]];
    });
    return unit;
}

+ (NSUnitVolume *)cubicMillimeters
{
    static NSUnitVolume *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitVolume alloc] initWithSpecifier:2824 symbol:@"mm³" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-06]];
    });
    return unit;
}

+ (NSUnitVolume *)cubicInches
{
    static NSUnitVolume *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitVolume alloc] initWithSpecifier:2826 symbol:@"in³" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.0163871]];
    });
    return unit;
}

+ (NSUnitVolume *)cubicFeet
{
    static NSUnitVolume *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitVolume alloc] initWithSpecifier:2827 symbol:@"ft³" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:28.3168]];
    });
    return unit;
}

+ (NSUnitVolume *)cubicYards
{
    static NSUnitVolume *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitVolume alloc] initWithSpecifier:2828 symbol:@"yd³" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:764.555]];
    });
    return unit;
}

+ (NSUnitVolume *)cubicMiles
{
    static NSUnitVolume *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitVolume alloc] initWithSpecifier:2818 symbol:@"mi³" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:4168000000000]];
    });
    return unit;
}

+ (NSUnitVolume *)acreFeet
{
    static NSUnitVolume *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitVolume alloc] initWithSpecifier:2829 symbol:@"af" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1233000]];
    });
    return unit;
}

+ (NSUnitVolume *)bushels
{
    static NSUnitVolume *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitVolume alloc] initWithSpecifier:2830 symbol:@"bsh" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:35.2391]];
    });
    return unit;
}

+ (NSUnitVolume *)teaspoons
{
    static NSUnitVolume *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitVolume alloc] initWithSpecifier:2831 symbol:@"tsp" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.00492892]];
    });
    return unit;
}

+ (NSUnitVolume *)tablespoons
{
    static NSUnitVolume *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitVolume alloc] initWithSpecifier:2832 symbol:@"tbsp" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.0147868]];
    });
    return unit;
}

+ (NSUnitVolume *)fluidOunces
{
    static NSUnitVolume *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitVolume alloc] initWithSpecifier:2833 symbol:@"fl oz" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.0295735]];
    });
    return unit;
}

+ (NSUnitVolume *)cups
{
    static NSUnitVolume *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitVolume alloc] initWithSpecifier:2834 symbol:@"cup" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.24]];
    });
    return unit;
}

+ (NSUnitVolume *)pints
{
    static NSUnitVolume *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitVolume alloc] initWithSpecifier:2835 symbol:@"pt" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.473176]];
    });
    return unit;
}

+ (NSUnitVolume *)quarts
{
    static NSUnitVolume *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitVolume alloc] initWithSpecifier:2836 symbol:@"qt" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.946353]];
    });
    return unit;
}

+ (NSUnitVolume *)gallons
{
    static NSUnitVolume *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitVolume alloc] initWithSpecifier:2837 symbol:@"gal" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:3.78541]];
    });
    return unit;
}

+ (NSUnitVolume *)imperialTeaspoons
{
    static NSUnitVolume *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitVolume alloc] initWithSpecifier:2831 symbol:@"tsp" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.00591939]];
    });
    return unit;
}

+ (NSUnitVolume *)imperialTablespoons
{
    static NSUnitVolume *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitVolume alloc] initWithSpecifier:2832 symbol:@"tbsp" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.0177582]];
    });
    return unit;
}

+ (NSUnitVolume *)imperialFluidOunces
{
    static NSUnitVolume *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitVolume alloc] initWithSpecifier:2833 symbol:@"fl oz" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.0284131]];
    });
    return unit;
}

+ (NSUnitVolume *)imperialPints
{
    static NSUnitVolume *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitVolume alloc] initWithSpecifier:2835 symbol:@"pt" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.568261]];
    });
    return unit;
}

+ (NSUnitVolume *)imperialQuarts
{
    static NSUnitVolume *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitVolume alloc] initWithSpecifier:2836 symbol:@"qt" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1.13652]];
    });
    return unit;
}

+ (NSUnitVolume *)imperialGallons
{
    static NSUnitVolume *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitVolume alloc] initWithSpecifier:2840 symbol:@"gal" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:4.54609]];
    });
    return unit;
}

+ (NSUnitVolume *)metricCups
{
    static NSUnitVolume *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitVolume alloc] initWithSpecifier:2838 symbol:@"metric cup" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.25]];
    });
    return unit;
}

@end
