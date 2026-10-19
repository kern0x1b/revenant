#import <Foundation/Foundation.h>
#import "CharonDimension.h"

@implementation NSUnitLength

+ (instancetype)baseUnit
{
    return [self meters];
}

+ (NSUnitLength *)megameters
{
    static NSUnitLength *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitLength alloc] initWithSymbol:@"Mm" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000000]];
    });
    return unit;
}

+ (NSUnitLength *)kilometers
{
    static NSUnitLength *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitLength alloc] initWithSpecifier:1282 symbol:@"km" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000]];
    });
    return unit;
}

+ (NSUnitLength *)hectometers
{
    static NSUnitLength *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitLength alloc] initWithSymbol:@"hm" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:100]];
    });
    return unit;
}

+ (NSUnitLength *)decameters
{
    static NSUnitLength *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitLength alloc] initWithSymbol:@"dam" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:10]];
    });
    return unit;
}

+ (NSUnitLength *)meters
{
    static NSUnitLength *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitLength alloc] initWithSpecifier:1280 symbol:@"m" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1]];
    });
    return unit;
}

+ (NSUnitLength *)decimeters
{
    static NSUnitLength *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitLength alloc] initWithSpecifier:1290 symbol:@"dm" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.1]];
    });
    return unit;
}

+ (NSUnitLength *)centimeters
{
    static NSUnitLength *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitLength alloc] initWithSpecifier:1281 symbol:@"cm" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.01]];
    });
    return unit;
}

+ (NSUnitLength *)millimeters
{
    static NSUnitLength *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitLength alloc] initWithSpecifier:1283 symbol:@"mm" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.001]];
    });
    return unit;
}

+ (NSUnitLength *)micrometers
{
    static NSUnitLength *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitLength alloc] initWithSpecifier:1291 symbol:@"µm" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-06]];
    });
    return unit;
}

+ (NSUnitLength *)nanometers
{
    static NSUnitLength *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitLength alloc] initWithSpecifier:1292 symbol:@"nm" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-09]];
    });
    return unit;
}

+ (NSUnitLength *)picometers
{
    static NSUnitLength *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitLength alloc] initWithSpecifier:1284 symbol:@"pm" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-12]];
    });
    return unit;
}

+ (NSUnitLength *)inches
{
    static NSUnitLength *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitLength alloc] initWithSpecifier:1286 symbol:@"in" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.0254]];
    });
    return unit;
}

+ (NSUnitLength *)feet
{
    static NSUnitLength *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitLength alloc] initWithSpecifier:1285 symbol:@"ft" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.3048]];
    });
    return unit;
}

+ (NSUnitLength *)yards
{
    static NSUnitLength *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitLength alloc] initWithSpecifier:1288 symbol:@"yd" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.9144]];
    });
    return unit;
}

+ (NSUnitLength *)miles
{
    static NSUnitLength *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitLength alloc] initWithSpecifier:1287 symbol:@"mi" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1609.344]];
    });
    return unit;
}

+ (NSUnitLength *)scandinavianMiles
{
    static NSUnitLength *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitLength alloc] initWithSpecifier:1298 symbol:@"smi" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:10000]];
    });
    return unit;
}

+ (NSUnitLength *)lightyears
{
    static NSUnitLength *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitLength alloc] initWithSpecifier:1289 symbol:@"ly" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:9460730472580800]];
    });
    return unit;
}

+ (NSUnitLength *)nauticalMiles
{
    static NSUnitLength *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitLength alloc] initWithSpecifier:1293 symbol:@"NM" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1852]];
    });
    return unit;
}

+ (NSUnitLength *)fathoms
{
    static NSUnitLength *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitLength alloc] initWithSpecifier:1294 symbol:@"ftm" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1.8288]];
    });
    return unit;
}

+ (NSUnitLength *)furlongs
{
    static NSUnitLength *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitLength alloc] initWithSpecifier:1295 symbol:@"fur" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:201.168]];
    });
    return unit;
}

+ (NSUnitLength *)astronomicalUnits
{
    static NSUnitLength *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitLength alloc] initWithSpecifier:1296 symbol:@"ua" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:149597870700]];
    });
    return unit;
}

+ (NSUnitLength *)parsecs
{
    static NSUnitLength *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitLength alloc] initWithSpecifier:1297 symbol:@"pc" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:3.085677581491367e+16]];
    });
    return unit;
}

@end
