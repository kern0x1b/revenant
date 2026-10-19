#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"
#import "CharonHKTypes.h"

enum {
    CharonHKDimensionMass = 0,
    CharonHKDimensionLength,
    CharonHKDimensionVolume,
    CharonHKDimensionPressure,
    CharonHKDimensionTime,
    CharonHKDimensionEnergy,
    CharonHKDimensionTemperature,
    CharonHKDimensionConductance,
    CharonHKDimensionCount,
    CharonHKDimensionMoles,
    CharonHKDimensionInternationalUnit,
    CharonHKDimensionSoundLevel,
    CharonHKDimensionFrequency,
    CharonHKDimensionHearingLevel,
    CharonHKDimensionPotential,
    CharonHKDimensionPower,
    CharonHKDimensionEffortScore,
    CharonHKDimensionCountOfDimensions,
};

static NSString *const CharonHKMultiply = @"·";
static NSString *const CharonHKDivide = @"/";
static NSString *const CharonHKPower = @"^";

static NSString *CharonHKBaseUnit(NSInteger dimension)
{
    switch (dimension) {
    case CharonHKDimensionMass:
        return @"g";
    case CharonHKDimensionLength:
        return @"m";
    case CharonHKDimensionVolume:
        return @"L";
    case CharonHKDimensionPressure:
        return @"Pa";
    case CharonHKDimensionTime:
        return @"s";
    case CharonHKDimensionEnergy:
        return @"J";
    case CharonHKDimensionTemperature:
        return @"K";
    case CharonHKDimensionConductance:
        return @"S";
    case CharonHKDimensionMoles:
        return @"mol";
    case CharonHKDimensionInternationalUnit:
        return @"IU";
    case CharonHKDimensionSoundLevel:
        return @"dBASPL";
    case CharonHKDimensionFrequency:
        return @"Hz";
    case CharonHKDimensionHearingLevel:
        return @"dBHL";
    case CharonHKDimensionPotential:
        return @"V";
    case CharonHKDimensionPower:
        return @"W";
    case CharonHKDimensionEffortScore:
        return @"appleEffortScore";
    default:
        return @"count";
    }
}

static NSString *CharonHKPrefixName(HKMetricPrefix prefix)
{
    switch (prefix) {
    case HKMetricPrefixFemto:
        return @"f";
    case HKMetricPrefixPico:
        return @"p";
    case HKMetricPrefixNano:
        return @"n";
    case HKMetricPrefixMicro:
        return @"mc";
    case HKMetricPrefixMilli:
        return @"m";
    case HKMetricPrefixCenti:
        return @"c";
    case HKMetricPrefixDeci:
        return @"d";
    case HKMetricPrefixDeca:
        return @"da";
    case HKMetricPrefixHecto:
        return @"h";
    case HKMetricPrefixKilo:
        return @"k";
    case HKMetricPrefixMega:
        return @"M";
    case HKMetricPrefixGiga:
        return @"G";
    case HKMetricPrefixTera:
        return @"T";
    case HKMetricPrefixNone:
    default:
        return @"";
    }
}

static BOOL CharonHKPrefixFactor(HKMetricPrefix prefix, double *factor)
{
    switch (prefix) {
    case HKMetricPrefixFemto:
        *factor = 1e-15;
        return YES;
    case HKMetricPrefixPico:
        *factor = 1e-12;
        return YES;
    case HKMetricPrefixNano:
        *factor = 1e-9;
        return YES;
    case HKMetricPrefixMicro:
        *factor = 1e-6;
        return YES;
    case HKMetricPrefixMilli:
        *factor = 1e-3;
        return YES;
    case HKMetricPrefixCenti:
        *factor = 1e-2;
        return YES;
    case HKMetricPrefixDeci:
        *factor = 1e-1;
        return YES;
    case HKMetricPrefixDeca:
        *factor = 10.0;
        return YES;
    case HKMetricPrefixHecto:
        *factor = 100.0;
        return YES;
    case HKMetricPrefixKilo:
        *factor = 1e3;
        return YES;
    case HKMetricPrefixMega:
        *factor = 1e6;
        return YES;
    case HKMetricPrefixGiga:
        *factor = 1e9;
        return YES;
    case HKMetricPrefixTera:
        *factor = 1e12;
        return YES;
    case HKMetricPrefixNone:
    default:
        *factor = 1.0;
        return YES;
    }
}

#pragma mark - The table of units

typedef struct {
    __unsafe_unretained NSString *string;
    NSInteger dimension;
    double factor;
    double offset;
} CharonHKUnitEntry;

static const CharonHKUnitEntry CharonHKUnitTable[] = {
    {@"g", CharonHKDimensionMass, 1.0, 0.0},
    {@"kg", CharonHKDimensionMass, 1000.0, 0.0},
    {@"mg", CharonHKDimensionMass, 1e-3, 0.0},
    {@"mcg", CharonHKDimensionMass, 1e-6, 0.0},
    {@"ng", CharonHKDimensionMass, 1e-9, 0.0},
    {@"pg", CharonHKDimensionMass, 1e-12, 0.0},
    {@"fg", CharonHKDimensionMass, 1e-15, 0.0},
    {@"oz", CharonHKDimensionMass, 28.349523125, 0.0},
    {@"lb", CharonHKDimensionMass, 453.59237, 0.0},
    {@"st", CharonHKDimensionMass, 6350.29318, 0.0},
    {@"m", CharonHKDimensionLength, 1.0, 0.0},
    {@"km", CharonHKDimensionLength, 1000.0, 0.0},
    {@"cm", CharonHKDimensionLength, 1e-2, 0.0},
    {@"mm", CharonHKDimensionLength, 1e-3, 0.0},
    {@"mcm", CharonHKDimensionLength, 1e-6, 0.0},
    {@"nm", CharonHKDimensionLength, 1e-9, 0.0},
    {@"in", CharonHKDimensionLength, 0.0254, 0.0},
    {@"ft", CharonHKDimensionLength, 0.3048, 0.0},
    {@"yd", CharonHKDimensionLength, 0.9144, 0.0},
    {@"mi", CharonHKDimensionLength, 1609.344, 0.0},
    {@"L", CharonHKDimensionVolume, 1.0, 0.0},
    {@"mL", CharonHKDimensionVolume, 1e-3, 0.0},
    {@"mcL", CharonHKDimensionVolume, 1e-6, 0.0},
    {@"nL", CharonHKDimensionVolume, 1e-9, 0.0},
    {@"pL", CharonHKDimensionVolume, 1e-12, 0.0},
    {@"fL", CharonHKDimensionVolume, 1e-15, 0.0},
    {@"dL", CharonHKDimensionVolume, 1e-1, 0.0},
    {@"cL", CharonHKDimensionVolume, 1e-2, 0.0},
    {@"daL", CharonHKDimensionVolume, 10.0, 0.0},
    {@"hL", CharonHKDimensionVolume, 100.0, 0.0},
    {@"fl_oz_us", CharonHKDimensionVolume, 0.0295735295625, 0.0},
    {@"pt_us", CharonHKDimensionVolume, 0.473176473, 0.0},
    {@"cup_us", CharonHKDimensionVolume, 0.2365882365, 0.0},
    {@"fl_oz_imp", CharonHKDimensionVolume, 0.0284130625, 0.0},
    {@"pt_imp", CharonHKDimensionVolume, 0.56826125, 0.0},
    {@"cup_imp", CharonHKDimensionVolume, 0.284130625, 0.0},
    {@"Pa", CharonHKDimensionPressure, 1.0, 0.0},
    {@"kPa", CharonHKDimensionPressure, 1000.0, 0.0},
    {@"hPa", CharonHKDimensionPressure, 100.0, 0.0},
    {@"daPa", CharonHKDimensionPressure, 10.0, 0.0},
    {@"MPa", CharonHKDimensionPressure, 1e6, 0.0},
    {@"mPa", CharonHKDimensionPressure, 1e-3, 0.0},
    {@"mcPa", CharonHKDimensionPressure, 1e-6, 0.0},
    {@"nPa", CharonHKDimensionPressure, 1e-9, 0.0},
    {@"pPa", CharonHKDimensionPressure, 1e-12, 0.0},
    {@"mmHg", CharonHKDimensionPressure, 133.32236842105263, 0.0},
    {@"cmAq", CharonHKDimensionPressure, 98.06649606299213, 0.0},
    {@"atm", CharonHKDimensionPressure, 101325.0, 0.0},
    {@"inHg", CharonHKDimensionPressure, 3386.38816, 0.0},
    {@"s", CharonHKDimensionTime, 1.0, 0.0},
    {@"ks", CharonHKDimensionTime, 1e3, 0.0},
    {@"Ms", CharonHKDimensionTime, 1e6, 0.0},
    {@"ms", CharonHKDimensionTime, 1e-3, 0.0},
    {@"mcs", CharonHKDimensionTime, 1e-6, 0.0},
    {@"ns", CharonHKDimensionTime, 1e-9, 0.0},
    {@"ps", CharonHKDimensionTime, 1e-12, 0.0},
    {@"min", CharonHKDimensionTime, 60.0, 0.0},
    {@"hr", CharonHKDimensionTime, 3600.0, 0.0},
    {@"d", CharonHKDimensionTime, 86400.0, 0.0},
    {@"J", CharonHKDimensionEnergy, 1.0, 0.0},
    {@"kJ", CharonHKDimensionEnergy, 1000.0, 0.0},
    {@"MJ", CharonHKDimensionEnergy, 1e6, 0.0},
    {@"cal", CharonHKDimensionEnergy, 4.184, 0.0},
    {@"kcal", CharonHKDimensionEnergy, 4184.0, 0.0},
    {@"Cal", CharonHKDimensionEnergy, 4184.0, 0.0},
    {@"K", CharonHKDimensionTemperature, 1.0, 0.0},
    {@"degC", CharonHKDimensionTemperature, 1.0, 273.15},
    {@"degF", CharonHKDimensionTemperature, 5.0 / 9.0, 459.67},
    {@"S", CharonHKDimensionConductance, 1.0, 0.0},
    {@"kS", CharonHKDimensionConductance, 1e3, 0.0},
    {@"MS", CharonHKDimensionConductance, 1e6, 0.0},
    {@"mS", CharonHKDimensionConductance, 1e-3, 0.0},
    {@"mcS", CharonHKDimensionConductance, 1e-6, 0.0},
    {@"nS", CharonHKDimensionConductance, 1e-9, 0.0},
    {@"pS", CharonHKDimensionConductance, 1e-12, 0.0},
    {@"count", CharonHKDimensionCount, 1.0, 0.0},
    {@"%", CharonHKDimensionCount, 1.0, 0.0},
    {@"IU", CharonHKDimensionInternationalUnit, 1.0, 0.0},
    {@"dBASPL", CharonHKDimensionSoundLevel, 1.0, 0.0},
    {@"Hz", CharonHKDimensionFrequency, 1.0, 0.0},
    {@"kHz", CharonHKDimensionFrequency, 1e3, 0.0},
    {@"MHz", CharonHKDimensionFrequency, 1e6, 0.0},
    {@"GHz", CharonHKDimensionFrequency, 1e9, 0.0},
    {@"dBHL", CharonHKDimensionHearingLevel, 1.0, 0.0},
    {@"V", CharonHKDimensionPotential, 1.0, 0.0},
    {@"mV", CharonHKDimensionPotential, 1e-3, 0.0},
    {@"kV", CharonHKDimensionPotential, 1e3, 0.0},
    {@"W", CharonHKDimensionPower, 1.0, 0.0},
    {@"mW", CharonHKDimensionPower, 1e-3, 0.0},
    {@"kW", CharonHKDimensionPower, 1e3, 0.0},
    {@"MW", CharonHKDimensionPower, 1e6, 0.0},
    {@"appleEffortScore", CharonHKDimensionEffortScore, 1.0, 0.0},
    {@"hg", CharonHKDimensionMass, 100.0, 0.0},         {@"dag", CharonHKDimensionMass, 10.0, 0.0},
    {@"dg", CharonHKDimensionMass, 1e-1, 0.0},          {@"cg", CharonHKDimensionMass, 1e-2, 0.0},
    {@"Mg", CharonHKDimensionMass, 1e6, 0.0},           {@"Gg", CharonHKDimensionMass, 1e9, 0.0},
    {@"Tg", CharonHKDimensionMass, 1e12, 0.0},
    {@"hm", CharonHKDimensionLength, 100.0, 0.0},       {@"dam", CharonHKDimensionLength, 10.0, 0.0},
    {@"dm", CharonHKDimensionLength, 1e-1, 0.0},        {@"Mm", CharonHKDimensionLength, 1e6, 0.0},
    {@"Gm", CharonHKDimensionLength, 1e9, 0.0},         {@"Tm", CharonHKDimensionLength, 1e12, 0.0},
    {@"kL", CharonHKDimensionVolume, 1e3, 0.0},         {@"ML", CharonHKDimensionVolume, 1e6, 0.0},
    {@"GL", CharonHKDimensionVolume, 1e9, 0.0},          {@"TL", CharonHKDimensionVolume, 1e12, 0.0},
    {@"ks", CharonHKDimensionTime, 1e3, 0.0},           {@"hm", CharonHKDimensionTime, 100.0, 0.0},
    {@"dam", CharonHKDimensionTime, 10.0, 0.0},         {@"ds", CharonHKDimensionTime, 1e-1, 0.0},
    {@"cs", CharonHKDimensionTime, 1e-2, 0.0},          {@"Gs", CharonHKDimensionTime, 1e9, 0.0},
    {@"Ts", CharonHKDimensionTime, 1e12, 0.0},
    {@"kJ", CharonHKDimensionEnergy, 1e3, 0.0},         {@"GJ", CharonHKDimensionEnergy, 1e9, 0.0},
    {@"TJ", CharonHKDimensionEnergy, 1e12, 0.0},        {@"daJ", CharonHKDimensionEnergy, 10.0, 0.0},
    {@"hJ", CharonHKDimensionEnergy, 100.0, 0.0},       {@"dJ", CharonHKDimensionEnergy, 1e-1, 0.0},
    {@"mJ", CharonHKDimensionEnergy, 1e-3, 0.0},       {@"mcJ", CharonHKDimensionEnergy, 1e-6, 0.0},
    {@"nJ", CharonHKDimensionEnergy, 1e-9, 0.0},        {@"pJ", CharonHKDimensionEnergy, 1e-12, 0.0},
    {@"GS", CharonHKDimensionConductance, 1e9, 0.0},    {@"TS", CharonHKDimensionConductance, 1e12, 0.0},
    {@"daS", CharonHKDimensionConductance, 10.0, 0.0},  {@"hS", CharonHKDimensionConductance, 100.0, 0.0},
    {@"dS", CharonHKDimensionConductance, 1e-1, 0.0},   {@"cS", CharonHKDimensionConductance, 1e-2, 0.0},
};
static const NSUInteger CharonHKUnitTableCount = sizeof(CharonHKUnitTable) / sizeof(CharonHKUnitTable[0]);

#pragma mark - The unit

@interface HKUnit ()
@property (readwrite) double charon_scale;
@property (readwrite) double charon_offset;
@property (readwrite, copy) NSArray<NSString *> *charon_bases;
@property (readwrite, copy) NSDictionary<NSString *, NSNumber *> *charon_powers;
@property (readwrite, copy) NSDictionary<NSString *, NSString *> *charon_names;
@end

@implementation HKUnit
@synthesize unitString = _unitString;
@synthesize charon_scale = _scale;
@synthesize charon_offset = _offset;
@synthesize charon_bases = _bases;
@synthesize charon_powers = _powers;
@synthesize charon_names = _names;

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _unitString = [[coder decodeObjectOfClass:[NSString class] forKey:@"unitString"] copy] ?: @"";
        _scale = [coder decodeDoubleForKey:@"scale"];
        _offset = [coder decodeDoubleForKey:@"offset"];
        _bases = [[coder decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class], [NSString class], nil]
                                       forKey:@"bases"] copy] ?: @[];
        _powers = [[coder decodeObjectOfClasses:[NSSet setWithObjects:[NSDictionary class], [NSString class], [NSNumber class], nil]
                                        forKey:@"powers"] copy] ?: @{};
        _names = [[coder decodeObjectOfClasses:[NSSet setWithObjects:[NSDictionary class], [NSString class], nil]
                                       forKey:@"names"] copy] ?: @{};
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_unitString forKey:@"unitString"];
    [coder encodeDouble:_scale forKey:@"scale"];
    [coder encodeDouble:_offset forKey:@"offset"];
    [coder encodeObject:_bases forKey:@"bases"];
    [coder encodeObject:_powers forKey:@"powers"];
    [coder encodeObject:_names forKey:@"names"];
}

- (id)copyWithZone:(NSZone *)zone
{
    HKUnit *copy = [[HKUnit alloc] init];
    copy->_unitString = [_unitString copy];
    copy->_scale = _scale;
    copy->_offset = _offset;
    copy->_bases = [_bases copy];
    copy->_powers = [_powers copy];
    copy->_names = [_names copy];
    return copy;
}

- (instancetype)init
{
    return [super init];
}

#pragma mark Building a unit

+ (instancetype)charon_unitWithString:(NSString *)string
                                 scale:(double)scale
                                offset:(double)offset
                                 bases:(NSArray *)bases
                                powers:(NSDictionary *)powers
                                 names:(NSDictionary *)names
{
    HKUnit *unit = [[HKUnit alloc] init];
    unit->_unitString = [string copy] ?: @"";
    unit->_scale = scale;
    unit->_offset = offset;
    unit->_bases = [bases copy];
    unit->_powers = [powers copy];
    unit->_names = [names copy];
    return unit;
}

+ (instancetype)charon_unitOfDimension:(NSInteger)dimension string:(NSString *)string factor:(double)factor offset:(double)offset
{
    NSString *base = CharonHKBaseUnit(dimension);
    return [self charon_unitWithString:string
                                  scale:factor
                                 offset:offset
                                  bases:@[base]
                                 powers:@{base: @1}
                                  names:@{base: string}];
}

+ (instancetype)charon_nullUnit
{
    return [self charon_unitWithString:@"()" scale:1.0 offset:0.0 bases:@[] powers:@{} names:@{}];
}

+ (instancetype)charon_namedUnit:(NSString *)string
{
    if (![string isKindOfClass:[NSString class]])
        return nil;
    for (NSUInteger index = 0; index < CharonHKUnitTableCount; index++) {
        if ([CharonHKUnitTable[index].string isEqualToString:string])
            return [self charon_unitOfDimension:CharonHKUnitTable[index].dimension
                                          string:string
                                         factor:CharonHKUnitTable[index].factor
                                         offset:CharonHKUnitTable[index].offset];
    }
    if ([string rangeOfString:@"l"].location != NSNotFound) {
        NSString *spelled = [string stringByReplacingOccurrencesOfString:@"l" withString:@"L"];
        if (![spelled isEqualToString:string])
            return [self charon_namedUnit:spelled];
    }
    return nil;
}

+ (instancetype)charon_prefixedUnitForDimension:(NSInteger)dimension prefix:(HKMetricPrefix)prefix
{
    double factor = 1.0;
    if (!CharonHKPrefixFactor(prefix, &factor) || dimension < 0 ||
        (NSUInteger)dimension >= CharonHKDimensionCountOfDimensions)
        return nil;
    NSString *name = [CharonHKPrefixName(prefix) stringByAppendingString:CharonHKBaseUnit(dimension)];
    return [self charon_unitOfDimension:dimension string:name factor:factor offset:0.0];
}

+ (instancetype)charon_moleUnitWithPrefix:(HKMetricPrefix)prefix molarMass:(double)gramsPerMole
{
    double factor = 1.0;
    if (!CharonHKPrefixFactor(prefix, &factor))
        return nil;
    NSString *base = CharonHKBaseUnit(CharonHKDimensionMoles);
    NSString *written = [NSString stringWithFormat:@"%@%@<%g>", CharonHKPrefixName(prefix), base, gramsPerMole];
    return [self charon_unitWithString:written
                                  scale:factor * gramsPerMole
                                 offset:0.0
                                  bases:@[base]
                                 powers:@{base: @1}
                                  names:@{base: written}];
}

#pragma mark Reading a unit

+ (void)charon_refuseFactorization:(NSString *)string
{
    [NSException raise:NSInvalidArgumentException format:@"Unable to parse factorization string %@", string];
}

+ (instancetype)unitFromString:(NSString *)string
{
    if (![string isKindOfClass:[NSString class]])
        [self charon_refuseFactorization:string];
    if (!string.length)
        return [self charon_nullUnit];
    HKUnit *named = [self charon_namedUnit:string];
    if (named)
        return named;
    NSRange open = [string rangeOfString:@"<"];
    if (open.location != NSNotFound && [string hasSuffix:@">"] && open.location > 0) {
        NSString *head = [string substringToIndex:open.location];
        NSString *digits = [string substringWithRange:NSMakeRange(NSMaxRange(open), string.length - NSMaxRange(open) - 1)];
        double mass = [digits doubleValue];
        if (mass > 0.0 && digits.length) {
            for (NSInteger prefix = HKMetricPrefixNone; prefix <= HKMetricPrefixTera; prefix++) {
                NSString *spelled = [CharonHKPrefixName((HKMetricPrefix)prefix) stringByAppendingString:@"mol"];
                if ([head isEqualToString:spelled])
                    return [self charon_moleUnitWithPrefix:(HKMetricPrefix)prefix molarMass:mass];
            }
        }
        [self charon_refuseFactorization:string];
    }
    return [self charon_unitFromString:string];
}

+ (instancetype)charon_unitFromString:(NSString *)string
{
    NSString *written = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSArray *halves = [written componentsSeparatedByString:CharonHKDivide];
    if (halves.count > 2)
        [self charon_refuseFactorization:string];
    HKUnit *numerator = [self charon_factors:halves[0] sign:1];
    if (!numerator)
        [self charon_refuseFactorization:string];
    if (halves.count == 1)
        return numerator;
    HKUnit *denominator = [self charon_factors:halves[1] sign:-1];
    if (!denominator)
        [self charon_refuseFactorization:string];
    return [numerator charon_productWithUnit:denominator];
}

+ (instancetype)charon_factors:(NSString *)string sign:(NSInteger)sign
{
    NSString *written = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ([written hasPrefix:@"("] && [written hasSuffix:@")"])
        written = [written substringWithRange:NSMakeRange(1, written.length - 2)];
    NSArray *parts = [written componentsSeparatedByCharactersInSet:
                          [NSCharacterSet characterSetWithCharactersInString:
                               [NSString stringWithFormat:@"%@*", CharonHKMultiply]]];
    NSMutableArray *bases = [NSMutableArray array];
    NSMutableDictionary *powers = [NSMutableDictionary dictionary];
    NSMutableDictionary *names = [NSMutableDictionary dictionary];
    double scale = 1.0;
    for (NSString *part in parts) {
        NSString *name = [part stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (!name.length)
            return nil;
        HKUnit *one = [self charon_namedUnit:name];
        if (!one)
            return nil;
        for (NSString *base in one.charon_bases) {
            NSInteger power = [powers[base] integerValue] + [one.charon_powers[base] integerValue] * sign;
            if (!power) {
                [powers removeObjectForKey:base];
                [names removeObjectForKey:base];
                [bases removeObject:base];
            } else {
                powers[base] = @(power);
                names[base] = one.charon_names[base];
                if (![bases containsObject:base])
                    [bases addObject:base];
            }
        }
        scale *= sign > 0 ? one.charon_scale : (one.charon_scale == 0.0 ? 1.0 : 1.0 / one.charon_scale);
    }
    if (!bases.count)
        return nil;
    HKUnit *made = [self charon_unitWithString:written
                                        scale:scale
                                       offset:0.0
                                        bases:bases
                                       powers:powers
                                        names:names];
    return made;
}

static NSString *CharonHKStringForDimensions(NSArray *bases, NSDictionary *powers, NSDictionary *names)
{
    NSMutableArray *numerator = [NSMutableArray array], *denominator = [NSMutableArray array];
    for (NSString *base in bases) {
        NSInteger power = [powers[base] integerValue];
        if (!power)
            continue;
        NSString *written = names[base] ?: base;
        NSString *name = labs(power) == 1 ? written
                                          : [NSString stringWithFormat:@"%@%@%ld", written, CharonHKPower,
                                                                       (long)labs(power)];
        [power > 0 ? numerator : denominator addObject:name];
    }
    NSMutableString *written = [NSMutableString string];
    if (!numerator.count)
        [written appendString:@"1"];
    [written appendString:[numerator componentsJoinedByString:CharonHKMultiply]];
    if (denominator.count) {
        [written appendString:CharonHKDivide];
        [written appendString:[denominator componentsJoinedByString:CharonHKMultiply]];
    }
    return written;
}

#pragma mark The arithmetic of the header

- (HKUnit *)charon_productWithUnit:(HKUnit *)unit
{
    NSMutableDictionary *powers = [_powers mutableCopy];
    NSMutableDictionary *names = [_names mutableCopy];
    NSMutableArray *bases = [NSMutableArray arrayWithArray:_bases];
    for (NSString *base in ((HKUnit *)unit).charon_bases) {
        NSInteger power = [powers[base] integerValue] + [((HKUnit *)unit).charon_powers[base] integerValue];
        if (!power) {
            [powers removeObjectForKey:base];
            [names removeObjectForKey:base];
            [bases removeObject:base];
        } else {
            powers[base] = @(power);
            names[base] = ((HKUnit *)unit).charon_names[base] ?: _names[base];
            if (![bases containsObject:base])
                [bases addObject:base];
        }
    }
    if (!bases.count)
        return [HKUnit charon_nullUnit];
    return [HKUnit charon_unitWithString:CharonHKStringForDimensions(bases, powers, names)
                                   scale:_scale * ((HKUnit *)unit).charon_scale
                                  offset:0.0
                                   bases:bases
                                  powers:powers
                                   names:names];
}

- (HKUnit *)unitMultipliedByUnit:(HKUnit *)unit
{
    return [self charon_productWithUnit:unit];
}

- (HKUnit *)unitDividedByUnit:(HKUnit *)unit
{
    return [self charon_productWithUnit:((HKUnit *)unit).charon_reciprocal];
}

- (HKUnit *)charon_reciprocal
{
    if (!_bases.count)
        return [HKUnit charon_nullUnit];
    NSMutableDictionary *powers = [NSMutableDictionary dictionary];
    for (NSString *base in _bases)
        powers[base] = @(-[_powers[base] integerValue]);
    return [HKUnit charon_unitWithString:CharonHKStringForDimensions(_bases, powers, _names)
                                   scale:(_scale == 0.0 ? 1.0 : 1.0 / _scale)
                                  offset:0.0
                                   bases:_bases
                                  powers:powers
                                   names:_names];
}

- (HKUnit *)reciprocalUnit
{
    return [self charon_reciprocal];
}

- (HKUnit *)unitRaisedToPower:(NSInteger)power
{
    NSMutableDictionary *powers = [NSMutableDictionary dictionary];
    NSMutableDictionary *names = [NSMutableDictionary dictionary];
    NSMutableArray *bases = [NSMutableArray array];
    double scale = 1.0;
    for (NSString *base in _bases) {
        NSInteger raised = [_powers[base] integerValue] * power;
        if (!raised)
            continue;
        powers[base] = @(raised);
        names[base] = _names[base];
        [bases addObject:base];
        for (NSInteger step = 0; step < labs(raised); step++)
            scale *= raised > 0 ? _scale : (_scale == 0.0 ? 1.0 : 1.0 / _scale);
    }
    if (!bases.count)
        return [HKUnit charon_nullUnit];
    return [HKUnit charon_unitWithString:CharonHKStringForDimensions(bases, powers, names)
                                   scale:scale
                                  offset:0.0
                                   bases:bases
                                  powers:powers
                                   names:names];
}

#pragma mark Comparing units

- (BOOL)charon_isCompatibleWithUnit:(HKUnit *)unit
{
    if (![unit isKindOfClass:[HKUnit class]])
        return NO;
    NSArray *mine = _bases, *theirs = ((HKUnit *)unit).charon_bases;
    if (mine.count != theirs.count)
        return NO;
    for (NSUInteger index = 0; index < mine.count; index++) {
        if (![mine[index] isEqualToString:theirs[index]])
            return NO;
        if ([_powers[mine[index]] integerValue] != [((HKUnit *)unit).charon_powers[theirs[index]] integerValue])
            return NO;
    }
    return YES;
}

- (BOOL)isEqual:(id)other
{
    if (self == other)
        return YES;
    if (![other isKindOfClass:[HKUnit class]])
        return NO;
    return [_unitString isEqualToString:((HKUnit *)other).unitString] && [self charon_isCompatibleWithUnit:other];
}

- (NSUInteger)hash
{
    return _unitString.hash;
}

- (NSString *)description
{
    return _unitString;
}

- (double)charon_value:(double)value inUnit:(HKUnit *)unit
{
    double base = (value + _offset) * _scale;
    return base / (unit.charon_scale == 0.0 ? 1.0 : unit.charon_scale) - unit.charon_offset;
}

#pragma mark The factory methods of the header

+ (instancetype)gramUnit
{
    return [self charon_namedUnit:@"g"];
}

+ (instancetype)gramUnitWithMetricPrefix:(HKMetricPrefix)prefix
{
    return [self charon_prefixedUnitForDimension:CharonHKDimensionMass prefix:prefix];
}

+ (instancetype)ounceUnit
{
    return [self charon_namedUnit:@"oz"];
}

+ (instancetype)poundUnit
{
    return [self charon_namedUnit:@"lb"];
}

+ (instancetype)stoneUnit
{
    return [self charon_namedUnit:@"st"];
}

+ (instancetype)moleUnitWithMetricPrefix:(HKMetricPrefix)prefix molarMass:(double)gramsPerMole
{
    if (gramsPerMole <= 0.0) {
        [NSException raise:NSInvalidArgumentException format:@"A molar mass must be positive, and %g is not.", gramsPerMole];
        return nil;
    }
    return [self charon_moleUnitWithPrefix:prefix molarMass:gramsPerMole];
}

+ (instancetype)moleUnitWithMolarMass:(double)gramsPerMole
{
    return [self moleUnitWithMetricPrefix:HKMetricPrefixNone molarMass:gramsPerMole];
}

+ (instancetype)meterUnit
{
    return [self charon_namedUnit:@"m"];
}

+ (instancetype)meterUnitWithMetricPrefix:(HKMetricPrefix)prefix
{
    return [self charon_prefixedUnitForDimension:CharonHKDimensionLength prefix:prefix];
}

+ (instancetype)inchUnit
{
    return [self charon_namedUnit:@"in"];
}

+ (instancetype)footUnit
{
    return [self charon_namedUnit:@"ft"];
}

+ (instancetype)yardUnit
{
    return [self charon_namedUnit:@"yd"];
}

+ (instancetype)mileUnit
{
    return [self charon_namedUnit:@"mi"];
}

+ (instancetype)literUnit
{
    return [self charon_namedUnit:@"L"];
}

+ (instancetype)literUnitWithMetricPrefix:(HKMetricPrefix)prefix
{
    return [self charon_prefixedUnitForDimension:CharonHKDimensionVolume prefix:prefix];
}

+ (instancetype)fluidOunceUSUnit
{
    return [self charon_namedUnit:@"fl_oz_us"];
}

+ (instancetype)fluidOunceImperialUnit
{
    return [self charon_namedUnit:@"fl_oz_imp"];
}

+ (instancetype)pintUSUnit
{
    return [self charon_namedUnit:@"pt_us"];
}

+ (instancetype)pintImperialUnit
{
    return [self charon_namedUnit:@"pt_imp"];
}

+ (instancetype)cupUSUnit
{
    return [self charon_namedUnit:@"cup_us"];
}

+ (instancetype)cupImperialUnit
{
    return [self charon_namedUnit:@"cup_imp"];
}

+ (instancetype)pascalUnit
{
    return [self charon_namedUnit:@"Pa"];
}

+ (instancetype)pascalUnitWithMetricPrefix:(HKMetricPrefix)prefix
{
    return [self charon_prefixedUnitForDimension:CharonHKDimensionPressure prefix:prefix];
}

+ (instancetype)millimeterOfMercuryUnit
{
    return [self charon_namedUnit:@"mmHg"];
}

+ (instancetype)centimeterOfWaterUnit
{
    return [self charon_namedUnit:@"cmAq"];
}

+ (instancetype)atmosphereUnit
{
    return [self charon_namedUnit:@"atm"];
}

+ (instancetype)secondUnit
{
    return [self charon_namedUnit:@"s"];
}

+ (instancetype)secondUnitWithMetricPrefix:(HKMetricPrefix)prefix
{
    return [self charon_prefixedUnitForDimension:CharonHKDimensionTime prefix:prefix];
}

+ (instancetype)minuteUnit
{
    return [self charon_namedUnit:@"min"];
}

+ (instancetype)hourUnit
{
    return [self charon_namedUnit:@"hr"];
}

+ (instancetype)dayUnit
{
    return [self charon_namedUnit:@"d"];
}

+ (instancetype)jouleUnit
{
    return [self charon_namedUnit:@"J"];
}

+ (instancetype)jouleUnitWithMetricPrefix:(HKMetricPrefix)prefix
{
    return [self charon_prefixedUnitForDimension:CharonHKDimensionEnergy prefix:prefix];
}

+ (instancetype)kilocalorieUnit
{
    return [self charon_namedUnit:@"kcal"];
}

+ (instancetype)calorieUnit
{
    return [self charon_namedUnit:@"cal"];
}

+ (instancetype)degreeCelsiusUnit
{
    return [self charon_namedUnit:@"degC"];
}

+ (instancetype)degreeFahrenheitUnit
{
    return [self charon_namedUnit:@"degF"];
}

+ (instancetype)kelvinUnit
{
    return [self charon_namedUnit:@"K"];
}

+ (instancetype)siemenUnit
{
    return [self charon_namedUnit:@"S"];
}

+ (instancetype)siemenUnitWithMetricPrefix:(HKMetricPrefix)prefix
{
    return [self charon_prefixedUnitForDimension:CharonHKDimensionConductance prefix:prefix];
}

+ (instancetype)countUnit
{
    return [self charon_namedUnit:@"count"];
}

+ (instancetype)percentUnit
{
    return [self charon_namedUnit:@"%"];
}

+ (instancetype)unitFromMassFormatterUnit:(NSMassFormatterUnit)massFormatterUnit
{
    switch (massFormatterUnit) {
    case NSMassFormatterUnitGram:
        return [self gramUnit];
    case NSMassFormatterUnitKilogram:
        return [self gramUnitWithMetricPrefix:HKMetricPrefixKilo];
    case NSMassFormatterUnitPound:
        return [self poundUnit];
    case NSMassFormatterUnitOunce:
        return [self ounceUnit];
    case NSMassFormatterUnitStone:
        return [self stoneUnit];
    default:
        return nil;
    }
}

+ (NSMassFormatterUnit)massFormatterUnitFromUnit:(HKUnit *)unit
{
    NSString *string = unit.unitString;
    if ([string isEqualToString:@"g"])
        return NSMassFormatterUnitGram;
    if ([string isEqualToString:@"kg"])
        return NSMassFormatterUnitKilogram;
    if ([string isEqualToString:@"lb"])
        return NSMassFormatterUnitPound;
    if ([string isEqualToString:@"oz"])
        return NSMassFormatterUnitOunce;
    if ([string isEqualToString:@"st"])
        return NSMassFormatterUnitStone;
    return NSMassFormatterUnitGram;
}

+ (instancetype)unitFromLengthFormatterUnit:(NSLengthFormatterUnit)lengthFormatterUnit
{
    switch (lengthFormatterUnit) {
    case NSLengthFormatterUnitMeter:
        return [self meterUnit];
    case NSLengthFormatterUnitKilometer:
        return [self meterUnitWithMetricPrefix:HKMetricPrefixKilo];
    case NSLengthFormatterUnitCentimeter:
        return [self meterUnitWithMetricPrefix:HKMetricPrefixCenti];
    case NSLengthFormatterUnitMillimeter:
        return [self meterUnitWithMetricPrefix:HKMetricPrefixMilli];
    case NSLengthFormatterUnitInch:
        return [self inchUnit];
    case NSLengthFormatterUnitFoot:
        return [self footUnit];
    case NSLengthFormatterUnitYard:
        return [self yardUnit];
    case NSLengthFormatterUnitMile:
        return [self mileUnit];
    default:
        return nil;
    }
}

+ (NSLengthFormatterUnit)lengthFormatterUnitFromUnit:(HKUnit *)unit
{
    NSString *string = unit.unitString;
    if ([string isEqualToString:@"m"])
        return NSLengthFormatterUnitMeter;
    if ([string isEqualToString:@"km"])
        return NSLengthFormatterUnitKilometer;
    if ([string isEqualToString:@"cm"])
        return NSLengthFormatterUnitCentimeter;
    if ([string isEqualToString:@"mm"])
        return NSLengthFormatterUnitMillimeter;
    if ([string isEqualToString:@"in"])
        return NSLengthFormatterUnitInch;
    if ([string isEqualToString:@"ft"])
        return NSLengthFormatterUnitFoot;
    if ([string isEqualToString:@"yd"])
        return NSLengthFormatterUnitYard;
    if ([string isEqualToString:@"mi"])
        return NSLengthFormatterUnitMile;
    return NSLengthFormatterUnitMeter;
}

+ (instancetype)unitFromEnergyFormatterUnit:(NSEnergyFormatterUnit)energyFormatterUnit
{
    switch (energyFormatterUnit) {
    case NSEnergyFormatterUnitJoule:
        return [self jouleUnit];
    case NSEnergyFormatterUnitKilojoule:
        return [self charon_namedUnit:@"kJ"];
    case NSEnergyFormatterUnitCalorie:
        return [self smallCalorieUnit];
    case NSEnergyFormatterUnitKilocalorie:
        return [self kilocalorieUnit];
    default:
        return nil;
    }
}

+ (NSEnergyFormatterUnit)energyFormatterUnitFromUnit:(HKUnit *)unit
{
    NSString *string = unit.unitString;
    if ([string isEqualToString:@"J"])
        return NSEnergyFormatterUnitJoule;
    if ([string isEqualToString:@"kJ"])
        return NSEnergyFormatterUnitKilojoule;
    if ([string isEqualToString:@"cal"])
        return NSEnergyFormatterUnitCalorie;
    if ([string isEqualToString:@"kcal"])
        return NSEnergyFormatterUnitKilocalorie;
    return NSEnergyFormatterUnitJoule;
}

- (BOOL)isNull
{
    return !_bases.count;
}

+ (nullable HKUnit *)charon_canonicalUnitForType:(HKQuantityType *)type
{
    if (![type isKindOfClass:[HKQuantityType class]])
        return nil;
    const CharonHKTypeEntry *entry = CharonHKQuantityTypeEntry(type.identifier);
    if (!entry)
        return nil;
    HKUnit *unit = nil;
    @try {
        unit = [HKUnit unitFromString:entry->unit];
    } @catch (NSException *exception) {
        unit = nil;
    }
    if (unit)
        return unit;
    charon_hk_say_once([@"quantity-unit" stringByAppendingString:entry->identifier],
                       [NSString stringWithFormat:@"HealthKit: %@ is counted in '%s', which is not a unit this port can make, so it "
                                                      @"accepts none. The SDK names that string for the type, and no source this port can "
                                                      @"read names a unit for it.",
                                                      entry->identifier, entry->unit.UTF8String]);
    return nil;
}

@end
