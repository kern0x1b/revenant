#import <Foundation/Foundation.h>
#import "CharonDimension.h"

@implementation NSUnitInformationStorage

+ (instancetype)baseUnit
{
    return [self bytes];
}

+ (NSUnitInformationStorage *)bits
{
    static NSUnitInformationStorage *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitInformationStorage alloc] initWithSpecifier:3584 symbol:@"bit" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0x1p-3]];
    });
    return unit;
}

+ (NSUnitInformationStorage *)nibbles
{
    static NSUnitInformationStorage *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitInformationStorage alloc] initWithSymbol:@"nibble" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0x1p-1]];
    });
    return unit;
}

+ (NSUnitInformationStorage *)bytes
{
    static NSUnitInformationStorage *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitInformationStorage alloc] initWithSpecifier:3585 symbol:@"B" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0x1p+0]];
    });
    return unit;
}

+ (NSUnitInformationStorage *)kilobits
{
    static NSUnitInformationStorage *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitInformationStorage alloc] initWithSpecifier:3588 symbol:@"kb" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0x1.f4p+6]];
    });
    return unit;
}

+ (NSUnitInformationStorage *)kilobytes
{
    static NSUnitInformationStorage *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitInformationStorage alloc] initWithSpecifier:3589 symbol:@"kB" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0x1.f4p+9]];
    });
    return unit;
}

+ (NSUnitInformationStorage *)kibibits
{
    static NSUnitInformationStorage *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitInformationStorage alloc] initWithSymbol:@"Kib" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0x1p+7]];
    });
    return unit;
}

+ (NSUnitInformationStorage *)kibibytes
{
    static NSUnitInformationStorage *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitInformationStorage alloc] initWithSymbol:@"KiB" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0x1p+10]];
    });
    return unit;
}

+ (NSUnitInformationStorage *)megabits
{
    static NSUnitInformationStorage *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitInformationStorage alloc] initWithSpecifier:3590 symbol:@"Mb" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0x1.e848p+16]];
    });
    return unit;
}

+ (NSUnitInformationStorage *)megabytes
{
    static NSUnitInformationStorage *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitInformationStorage alloc] initWithSpecifier:3591 symbol:@"MB" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0x1.e848p+19]];
    });
    return unit;
}

+ (NSUnitInformationStorage *)mebibits
{
    static NSUnitInformationStorage *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitInformationStorage alloc] initWithSymbol:@"Mib" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0x1p+17]];
    });
    return unit;
}

+ (NSUnitInformationStorage *)mebibytes
{
    static NSUnitInformationStorage *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitInformationStorage alloc] initWithSymbol:@"MiB" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0x1p+20]];
    });
    return unit;
}

+ (NSUnitInformationStorage *)gigabits
{
    static NSUnitInformationStorage *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitInformationStorage alloc] initWithSpecifier:3586 symbol:@"Gb" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0x1.dcd65p+26]];
    });
    return unit;
}

+ (NSUnitInformationStorage *)gigabytes
{
    static NSUnitInformationStorage *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitInformationStorage alloc] initWithSpecifier:3587 symbol:@"GB" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0x1.dcd65p+29]];
    });
    return unit;
}

+ (NSUnitInformationStorage *)gibibits
{
    static NSUnitInformationStorage *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitInformationStorage alloc] initWithSymbol:@"Gib" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0x1p+27]];
    });
    return unit;
}

+ (NSUnitInformationStorage *)gibibytes
{
    static NSUnitInformationStorage *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitInformationStorage alloc] initWithSymbol:@"GiB" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0x1p+30]];
    });
    return unit;
}

+ (NSUnitInformationStorage *)terabits
{
    static NSUnitInformationStorage *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitInformationStorage alloc] initWithSpecifier:3592 symbol:@"Tb" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0x1.d1a94a2p+36]];
    });
    return unit;
}

+ (NSUnitInformationStorage *)terabytes
{
    static NSUnitInformationStorage *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitInformationStorage alloc] initWithSpecifier:3593 symbol:@"TB" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0x1.d1a94a2p+39]];
    });
    return unit;
}

+ (NSUnitInformationStorage *)tebibits
{
    static NSUnitInformationStorage *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitInformationStorage alloc] initWithSymbol:@"Tib" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0x1p+37]];
    });
    return unit;
}

+ (NSUnitInformationStorage *)tebibytes
{
    static NSUnitInformationStorage *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitInformationStorage alloc] initWithSymbol:@"TiB" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0x1p+40]];
    });
    return unit;
}

+ (NSUnitInformationStorage *)petabits
{
    static NSUnitInformationStorage *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitInformationStorage alloc] initWithSymbol:@"Pb" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0x1.c6bf52634p+46]];
    });
    return unit;
}

+ (NSUnitInformationStorage *)petabytes
{
    static NSUnitInformationStorage *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitInformationStorage alloc] initWithSpecifier:3594 symbol:@"PB" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0x1.c6bf52634p+49]];
    });
    return unit;
}

+ (NSUnitInformationStorage *)pebibits
{
    static NSUnitInformationStorage *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitInformationStorage alloc] initWithSymbol:@"Pib" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0x1p+47]];
    });
    return unit;
}

+ (NSUnitInformationStorage *)pebibytes
{
    static NSUnitInformationStorage *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitInformationStorage alloc] initWithSymbol:@"PiB" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0x1p+50]];
    });
    return unit;
}

+ (NSUnitInformationStorage *)exabits
{
    static NSUnitInformationStorage *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitInformationStorage alloc] initWithSymbol:@"Eb" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0x1.bc16d674ec8p+56]];
    });
    return unit;
}

+ (NSUnitInformationStorage *)exabytes
{
    static NSUnitInformationStorage *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitInformationStorage alloc] initWithSymbol:@"EB" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0x1.bc16d674ec8p+59]];
    });
    return unit;
}

+ (NSUnitInformationStorage *)exbibits
{
    static NSUnitInformationStorage *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitInformationStorage alloc] initWithSymbol:@"Eib" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0x1p+57]];
    });
    return unit;
}

+ (NSUnitInformationStorage *)exbibytes
{
    static NSUnitInformationStorage *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitInformationStorage alloc] initWithSymbol:@"EiB" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0x1p+60]];
    });
    return unit;
}

+ (NSUnitInformationStorage *)zettabits
{
    static NSUnitInformationStorage *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitInformationStorage alloc] initWithSymbol:@"Zb" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0x1.b1ae4d6e2ef5p+66]];
    });
    return unit;
}

+ (NSUnitInformationStorage *)zettabytes
{
    static NSUnitInformationStorage *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitInformationStorage alloc] initWithSymbol:@"ZB" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0x1.b1ae4d6e2ef5p+69]];
    });
    return unit;
}

+ (NSUnitInformationStorage *)zebibits
{
    static NSUnitInformationStorage *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitInformationStorage alloc] initWithSymbol:@"Zib" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0x1p+67]];
    });
    return unit;
}

+ (NSUnitInformationStorage *)zebibytes
{
    static NSUnitInformationStorage *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitInformationStorage alloc] initWithSymbol:@"ZiB" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0x1p+70]];
    });
    return unit;
}

+ (NSUnitInformationStorage *)yottabits
{
    static NSUnitInformationStorage *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitInformationStorage alloc] initWithSymbol:@"Yb" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0x1.a784379d99db4p+76]];
    });
    return unit;
}

+ (NSUnitInformationStorage *)yottabytes
{
    static NSUnitInformationStorage *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitInformationStorage alloc] initWithSymbol:@"YB" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0x1.a784379d99db4p+79]];
    });
    return unit;
}

+ (NSUnitInformationStorage *)yobibits
{
    static NSUnitInformationStorage *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitInformationStorage alloc] initWithSymbol:@"Yib" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0x1p+77]];
    });
    return unit;
}

+ (NSUnitInformationStorage *)yobibytes
{
    static NSUnitInformationStorage *unit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unit = [[NSUnitInformationStorage alloc] initWithSymbol:@"YiB" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0x1p+80]];
    });
    return unit;
}

@end
