#import <Foundation/Foundation.h>
#import "CharonDimension.h"

@implementation NSUnitMass

+ (instancetype)baseUnit
{
    return [self kilograms];
}

+ (NSUnitMass *)kilograms
{
    static NSUnitMass *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitMass alloc] initWithSpecifier:1537 symbol:@"kg" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1]];
    });
    return unit;
}

+ (NSUnitMass *)grams
{
    static NSUnitMass *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitMass alloc] initWithSpecifier:1536 symbol:@"g" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.001]];
    });
    return unit;
}

+ (NSUnitMass *)decigrams
{
    static NSUnitMass *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitMass alloc] initWithSymbol:@"dg" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.0001]];
    });
    return unit;
}

+ (NSUnitMass *)centigrams
{
    static NSUnitMass *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitMass alloc] initWithSymbol:@"cg" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-05]];
    });
    return unit;
}

+ (NSUnitMass *)milligrams
{
    static NSUnitMass *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitMass alloc] initWithSpecifier:1542 symbol:@"mg" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-06]];
    });
    return unit;
}

+ (NSUnitMass *)micrograms
{
    static NSUnitMass *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitMass alloc] initWithSpecifier:1541 symbol:@"µg" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-09]];
    });
    return unit;
}

+ (NSUnitMass *)nanograms
{
    static NSUnitMass *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitMass alloc] initWithSymbol:@"ng" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-12]];
    });
    return unit;
}

+ (NSUnitMass *)picograms
{
    static NSUnitMass *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitMass alloc] initWithSymbol:@"pg" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-15]];
    });
    return unit;
}

+ (NSUnitMass *)ounces
{
    static NSUnitMass *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitMass alloc] initWithSpecifier:1538 symbol:@"oz" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.0283495]];
    });
    return unit;
}

+ (NSUnitMass *)poundsMass
{
    static NSUnitMass *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitMass alloc] initWithSpecifier:1539 symbol:@"lb" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.453592]];
    });
    return unit;
}

+ (NSUnitMass *)stones
{
    static NSUnitMass *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitMass alloc] initWithSpecifier:1540 symbol:@"st" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:6.35029]];
    });
    return unit;
}

+ (NSUnitMass *)metricTons
{
    static NSUnitMass *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitMass alloc] initWithSpecifier:1543 symbol:@"t" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000]];
    });
    return unit;
}

+ (NSUnitMass *)shortTons
{
    static NSUnitMass *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitMass alloc] initWithSpecifier:1544 symbol:@"ton" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:907.185]];
    });
    return unit;
}

+ (NSUnitMass *)carats
{
    static NSUnitMass *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitMass alloc] initWithSpecifier:1545 symbol:@"ct" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.0002]];
    });
    return unit;
}

+ (NSUnitMass *)ouncesTroy
{
    static NSUnitMass *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitMass alloc] initWithSpecifier:1546 symbol:@"oz t" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.03110348]];
    });
    return unit;
}

+ (NSUnitMass *)slugs
{
    static NSUnitMass *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitMass alloc] initWithSymbol:@"slug" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:14.5939]];
    });
    return unit;
}

@end
