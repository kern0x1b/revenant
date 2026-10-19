#import <HealthKit/HealthKit.h>

#import "RevenantHKStore.h"
#import "RevenantHKTypes.h"

enum {
    RevenantHKDimensionMass = 0,
    RevenantHKDimensionLength,
    RevenantHKDimensionVolume,
    RevenantHKDimensionPressure,
    RevenantHKDimensionTime,
    RevenantHKDimensionEnergy,
    RevenantHKDimensionTemperature,
    RevenantHKDimensionConductance,
    RevenantHKDimensionCount,
    RevenantHKDimensionMoles,
    RevenantHKDimensionInternationalUnit,
    RevenantHKDimensionSoundLevel,
    RevenantHKDimensionFrequency,
    RevenantHKDimensionHearingLevel,
    RevenantHKDimensionPotential,
    RevenantHKDimensionPower,
    RevenantHKDimensionEffortScore,
    RevenantHKDimensionCountOfDimensions,
};

static NSString *const RevenantHKMultiply = @"·";
static NSString *const RevenantHKDivide = @"/";
static NSString *const RevenantHKPower = @"^";

static NSString *RevenantHKBaseUnit(NSInteger dimension)
{
    switch (dimension) {
    case RevenantHKDimensionMass:
        return @"g";
    case RevenantHKDimensionLength:
        return @"m";
    case RevenantHKDimensionVolume:
        return @"L";
    case RevenantHKDimensionPressure:
        return @"Pa";
    case RevenantHKDimensionTime:
        return @"s";
    case RevenantHKDimensionEnergy:
        return @"J";
    case RevenantHKDimensionTemperature:
        return @"K";
    case RevenantHKDimensionConductance:
        return @"S";
    case RevenantHKDimensionMoles:
        return @"mol";
    case RevenantHKDimensionInternationalUnit:
        return @"IU";
    case RevenantHKDimensionSoundLevel:
        return @"dBASPL";
    case RevenantHKDimensionFrequency:
        return @"Hz";
    case RevenantHKDimensionHearingLevel:
        return @"dBHL";
    case RevenantHKDimensionPotential:
        return @"V";
    case RevenantHKDimensionPower:
        return @"W";
    case RevenantHKDimensionEffortScore:
        return @"appleEffortScore";
    default:
        return @"count";
    }
}

static NSString *RevenantHKPrefixName(HKMetricPrefix prefix)
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

static BOOL RevenantHKPrefixFactor(HKMetricPrefix prefix, double *factor)
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
} RevenantHKUnitEntry;

static const RevenantHKUnitEntry RevenantHKUnitTable[] = {
    {@"g", RevenantHKDimensionMass, 1.0, 0.0},
    {@"kg", RevenantHKDimensionMass, 1000.0, 0.0},
    {@"mg", RevenantHKDimensionMass, 1e-3, 0.0},
    {@"mcg", RevenantHKDimensionMass, 1e-6, 0.0},
    {@"ng", RevenantHKDimensionMass, 1e-9, 0.0},
    {@"pg", RevenantHKDimensionMass, 1e-12, 0.0},
    {@"fg", RevenantHKDimensionMass, 1e-15, 0.0},
    {@"oz", RevenantHKDimensionMass, 28.349523125, 0.0},
    {@"lb", RevenantHKDimensionMass, 453.59237, 0.0},
    {@"st", RevenantHKDimensionMass, 6350.29318, 0.0},
    {@"m", RevenantHKDimensionLength, 1.0, 0.0},
    {@"km", RevenantHKDimensionLength, 1000.0, 0.0},
    {@"cm", RevenantHKDimensionLength, 1e-2, 0.0},
    {@"mm", RevenantHKDimensionLength, 1e-3, 0.0},
    {@"mcm", RevenantHKDimensionLength, 1e-6, 0.0},
    {@"nm", RevenantHKDimensionLength, 1e-9, 0.0},
    {@"in", RevenantHKDimensionLength, 0.0254, 0.0},
    {@"ft", RevenantHKDimensionLength, 0.3048, 0.0},
    {@"yd", RevenantHKDimensionLength, 0.9144, 0.0},
    {@"mi", RevenantHKDimensionLength, 1609.344, 0.0},
    {@"L", RevenantHKDimensionVolume, 1.0, 0.0},
    {@"mL", RevenantHKDimensionVolume, 1e-3, 0.0},
    {@"mcL", RevenantHKDimensionVolume, 1e-6, 0.0},
    {@"nL", RevenantHKDimensionVolume, 1e-9, 0.0},
    {@"pL", RevenantHKDimensionVolume, 1e-12, 0.0},
    {@"fL", RevenantHKDimensionVolume, 1e-15, 0.0},
    {@"dL", RevenantHKDimensionVolume, 1e-1, 0.0},
    {@"cL", RevenantHKDimensionVolume, 1e-2, 0.0},
    {@"daL", RevenantHKDimensionVolume, 10.0, 0.0},
    {@"hL", RevenantHKDimensionVolume, 100.0, 0.0},
    {@"fl_oz_us", RevenantHKDimensionVolume, 0.0295735295625, 0.0},
    {@"pt_us", RevenantHKDimensionVolume, 0.473176473, 0.0},
    {@"cup_us", RevenantHKDimensionVolume, 0.2365882365, 0.0},
    {@"fl_oz_imp", RevenantHKDimensionVolume, 0.0284130625, 0.0},
    {@"pt_imp", RevenantHKDimensionVolume, 0.56826125, 0.0},
    {@"cup_imp", RevenantHKDimensionVolume, 0.284130625, 0.0},
    {@"Pa", RevenantHKDimensionPressure, 1.0, 0.0},
    {@"kPa", RevenantHKDimensionPressure, 1000.0, 0.0},
    {@"hPa", RevenantHKDimensionPressure, 100.0, 0.0},
    {@"daPa", RevenantHKDimensionPressure, 10.0, 0.0},
    {@"MPa", RevenantHKDimensionPressure, 1e6, 0.0},
    {@"mPa", RevenantHKDimensionPressure, 1e-3, 0.0},
    {@"mcPa", RevenantHKDimensionPressure, 1e-6, 0.0},
    {@"nPa", RevenantHKDimensionPressure, 1e-9, 0.0},
    {@"pPa", RevenantHKDimensionPressure, 1e-12, 0.0},
    {@"mmHg", RevenantHKDimensionPressure, 133.32236842105263, 0.0},
    {@"cmAq", RevenantHKDimensionPressure, 98.06649606299213, 0.0},
    {@"atm", RevenantHKDimensionPressure, 101325.0, 0.0},
    {@"inHg", RevenantHKDimensionPressure, 3386.38816, 0.0},
    {@"s", RevenantHKDimensionTime, 1.0, 0.0},
    {@"ks", RevenantHKDimensionTime, 1e3, 0.0},
    {@"Ms", RevenantHKDimensionTime, 1e6, 0.0},
    {@"ms", RevenantHKDimensionTime, 1e-3, 0.0},
    {@"mcs", RevenantHKDimensionTime, 1e-6, 0.0},
    {@"ns", RevenantHKDimensionTime, 1e-9, 0.0},
    {@"ps", RevenantHKDimensionTime, 1e-12, 0.0},
    {@"min", RevenantHKDimensionTime, 60.0, 0.0},
    {@"hr", RevenantHKDimensionTime, 3600.0, 0.0},
    {@"d", RevenantHKDimensionTime, 86400.0, 0.0},
    {@"J", RevenantHKDimensionEnergy, 1.0, 0.0},
    {@"kJ", RevenantHKDimensionEnergy, 1000.0, 0.0},
    {@"MJ", RevenantHKDimensionEnergy, 1e6, 0.0},
    {@"cal", RevenantHKDimensionEnergy, 4.184, 0.0},
    {@"kcal", RevenantHKDimensionEnergy, 4184.0, 0.0},
    {@"Cal", RevenantHKDimensionEnergy, 4184.0, 0.0},
    {@"K", RevenantHKDimensionTemperature, 1.0, 0.0},
    {@"degC", RevenantHKDimensionTemperature, 1.0, 273.15},
    {@"degF", RevenantHKDimensionTemperature, 5.0 / 9.0, 459.67},
    {@"S", RevenantHKDimensionConductance, 1.0, 0.0},
    {@"kS", RevenantHKDimensionConductance, 1e3, 0.0},
    {@"MS", RevenantHKDimensionConductance, 1e6, 0.0},
    {@"mS", RevenantHKDimensionConductance, 1e-3, 0.0},
    {@"mcS", RevenantHKDimensionConductance, 1e-6, 0.0},
    {@"nS", RevenantHKDimensionConductance, 1e-9, 0.0},
    {@"pS", RevenantHKDimensionConductance, 1e-12, 0.0},
    {@"count", RevenantHKDimensionCount, 1.0, 0.0},
    {@"%", RevenantHKDimensionCount, 1.0, 0.0},
    {@"IU", RevenantHKDimensionInternationalUnit, 1.0, 0.0},
    {@"dBASPL", RevenantHKDimensionSoundLevel, 1.0, 0.0},
    {@"Hz", RevenantHKDimensionFrequency, 1.0, 0.0},
    {@"kHz", RevenantHKDimensionFrequency, 1e3, 0.0},
    {@"MHz", RevenantHKDimensionFrequency, 1e6, 0.0},
    {@"GHz", RevenantHKDimensionFrequency, 1e9, 0.0},
    {@"dBHL", RevenantHKDimensionHearingLevel, 1.0, 0.0},
    {@"V", RevenantHKDimensionPotential, 1.0, 0.0},
    {@"mV", RevenantHKDimensionPotential, 1e-3, 0.0},
    {@"kV", RevenantHKDimensionPotential, 1e3, 0.0},
    {@"W", RevenantHKDimensionPower, 1.0, 0.0},
    {@"mW", RevenantHKDimensionPower, 1e-3, 0.0},
    {@"kW", RevenantHKDimensionPower, 1e3, 0.0},
    {@"MW", RevenantHKDimensionPower, 1e6, 0.0},
    {@"appleEffortScore", RevenantHKDimensionEffortScore, 1.0, 0.0},
    {@"hg", RevenantHKDimensionMass, 100.0, 0.0},         {@"dag", RevenantHKDimensionMass, 10.0, 0.0},
    {@"dg", RevenantHKDimensionMass, 1e-1, 0.0},          {@"cg", RevenantHKDimensionMass, 1e-2, 0.0},
    {@"Mg", RevenantHKDimensionMass, 1e6, 0.0},           {@"Gg", RevenantHKDimensionMass, 1e9, 0.0},
    {@"Tg", RevenantHKDimensionMass, 1e12, 0.0},
    {@"hm", RevenantHKDimensionLength, 100.0, 0.0},       {@"dam", RevenantHKDimensionLength, 10.0, 0.0},
    {@"dm", RevenantHKDimensionLength, 1e-1, 0.0},        {@"Mm", RevenantHKDimensionLength, 1e6, 0.0},
    {@"Gm", RevenantHKDimensionLength, 1e9, 0.0},         {@"Tm", RevenantHKDimensionLength, 1e12, 0.0},
    {@"kL", RevenantHKDimensionVolume, 1e3, 0.0},         {@"ML", RevenantHKDimensionVolume, 1e6, 0.0},
    {@"GL", RevenantHKDimensionVolume, 1e9, 0.0},          {@"TL", RevenantHKDimensionVolume, 1e12, 0.0},
    {@"ks", RevenantHKDimensionTime, 1e3, 0.0},           {@"hm", RevenantHKDimensionTime, 100.0, 0.0},
    {@"dam", RevenantHKDimensionTime, 10.0, 0.0},         {@"ds", RevenantHKDimensionTime, 1e-1, 0.0},
    {@"cs", RevenantHKDimensionTime, 1e-2, 0.0},          {@"Gs", RevenantHKDimensionTime, 1e9, 0.0},
    {@"Ts", RevenantHKDimensionTime, 1e12, 0.0},
    {@"kJ", RevenantHKDimensionEnergy, 1e3, 0.0},         {@"GJ", RevenantHKDimensionEnergy, 1e9, 0.0},
    {@"TJ", RevenantHKDimensionEnergy, 1e12, 0.0},        {@"daJ", RevenantHKDimensionEnergy, 10.0, 0.0},
    {@"hJ", RevenantHKDimensionEnergy, 100.0, 0.0},       {@"dJ", RevenantHKDimensionEnergy, 1e-1, 0.0},
    {@"mJ", RevenantHKDimensionEnergy, 1e-3, 0.0},       {@"mcJ", RevenantHKDimensionEnergy, 1e-6, 0.0},
    {@"nJ", RevenantHKDimensionEnergy, 1e-9, 0.0},        {@"pJ", RevenantHKDimensionEnergy, 1e-12, 0.0},
    {@"GS", RevenantHKDimensionConductance, 1e9, 0.0},    {@"TS", RevenantHKDimensionConductance, 1e12, 0.0},
    {@"daS", RevenantHKDimensionConductance, 10.0, 0.0},  {@"hS", RevenantHKDimensionConductance, 100.0, 0.0},
    {@"dS", RevenantHKDimensionConductance, 1e-1, 0.0},   {@"cS", RevenantHKDimensionConductance, 1e-2, 0.0},
};
static const NSUInteger RevenantHKUnitTableCount = sizeof(RevenantHKUnitTable) / sizeof(RevenantHKUnitTable[0]);

#pragma mark - The unit

@interface HKUnit ()
@property (readwrite) double revenant_scale;
@property (readwrite) double revenant_offset;
@property (readwrite, copy) NSArray<NSString *> *revenant_bases;
@property (readwrite, copy) NSDictionary<NSString *, NSNumber *> *revenant_powers;
@property (readwrite, copy) NSDictionary<NSString *, NSString *> *revenant_names;
@end

@implementation HKUnit
@synthesize unitString = _unitString;
@synthesize revenant_scale = _scale;
@synthesize revenant_offset = _offset;
@synthesize revenant_bases = _bases;
@synthesize revenant_powers = _powers;
@synthesize revenant_names = _names;

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

+ (instancetype)revenant_unitWithString:(NSString *)string
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

+ (instancetype)revenant_unitOfDimension:(NSInteger)dimension string:(NSString *)string factor:(double)factor offset:(double)offset
{
    NSString *base = RevenantHKBaseUnit(dimension);
    return [self revenant_unitWithString:string
                                  scale:factor
                                 offset:offset
                                  bases:@[base]
                                 powers:@{base: @1}
                                  names:@{base: string}];
}

+ (instancetype)revenant_nullUnit
{
    return [self revenant_unitWithString:@"()" scale:1.0 offset:0.0 bases:@[] powers:@{} names:@{}];
}

+ (instancetype)revenant_namedUnit:(NSString *)string
{
    if (![string isKindOfClass:[NSString class]])
        return nil;
    for (NSUInteger index = 0; index < RevenantHKUnitTableCount; index++) {
        if ([RevenantHKUnitTable[index].string isEqualToString:string])
            return [self revenant_unitOfDimension:RevenantHKUnitTable[index].dimension
                                          string:string
                                         factor:RevenantHKUnitTable[index].factor
                                         offset:RevenantHKUnitTable[index].offset];
    }
    if ([string rangeOfString:@"l"].location != NSNotFound) {
        NSString *spelled = [string stringByReplacingOccurrencesOfString:@"l" withString:@"L"];
        if (![spelled isEqualToString:string])
            return [self revenant_namedUnit:spelled];
    }
    return nil;
}

+ (instancetype)revenant_prefixedUnitForDimension:(NSInteger)dimension prefix:(HKMetricPrefix)prefix
{
    double factor = 1.0;
    if (!RevenantHKPrefixFactor(prefix, &factor) || dimension < 0 ||
        (NSUInteger)dimension >= RevenantHKDimensionCountOfDimensions)
        return nil;
    NSString *name = [RevenantHKPrefixName(prefix) stringByAppendingString:RevenantHKBaseUnit(dimension)];
    return [self revenant_unitOfDimension:dimension string:name factor:factor offset:0.0];
}

+ (instancetype)revenant_moleUnitWithPrefix:(HKMetricPrefix)prefix molarMass:(double)gramsPerMole
{
    double factor = 1.0;
    if (!RevenantHKPrefixFactor(prefix, &factor))
        return nil;
    NSString *base = RevenantHKBaseUnit(RevenantHKDimensionMoles);
    NSString *written = [NSString stringWithFormat:@"%@%@<%g>", RevenantHKPrefixName(prefix), base, gramsPerMole];
    return [self revenant_unitWithString:written
                                  scale:factor * gramsPerMole
                                 offset:0.0
                                  bases:@[base]
                                 powers:@{base: @1}
                                  names:@{base: written}];
}

#pragma mark Reading a unit

+ (void)revenant_refuseFactorization:(NSString *)string
{
    [NSException raise:NSInvalidArgumentException format:@"Unable to parse factorization string %@", string];
}

+ (instancetype)unitFromString:(NSString *)string
{
    if (![string isKindOfClass:[NSString class]])
        [self revenant_refuseFactorization:string];
    if (!string.length)
        return [self revenant_nullUnit];
    HKUnit *named = [self revenant_namedUnit:string];
    if (named)
        return named;
    NSRange open = [string rangeOfString:@"<"];
    if (open.location != NSNotFound && [string hasSuffix:@">"] && open.location > 0) {
        NSString *head = [string substringToIndex:open.location];
        NSString *digits = [string substringWithRange:NSMakeRange(NSMaxRange(open), string.length - NSMaxRange(open) - 1)];
        double mass = [digits doubleValue];
        if (mass > 0.0 && digits.length) {
            for (NSInteger prefix = HKMetricPrefixNone; prefix <= HKMetricPrefixTera; prefix++) {
                NSString *spelled = [RevenantHKPrefixName((HKMetricPrefix)prefix) stringByAppendingString:@"mol"];
                if ([head isEqualToString:spelled])
                    return [self revenant_moleUnitWithPrefix:(HKMetricPrefix)prefix molarMass:mass];
            }
        }
        [self revenant_refuseFactorization:string];
    }
    return [self revenant_unitFromString:string];
}

+ (instancetype)revenant_unitFromString:(NSString *)string
{
    NSString *written = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSArray *halves = [written componentsSeparatedByString:RevenantHKDivide];
    if (halves.count > 2)
        [self revenant_refuseFactorization:string];
    HKUnit *numerator = [self revenant_factors:halves[0] sign:1];
    if (!numerator)
        [self revenant_refuseFactorization:string];
    if (halves.count == 1)
        return numerator;
    HKUnit *denominator = [self revenant_factors:halves[1] sign:-1];
    if (!denominator)
        [self revenant_refuseFactorization:string];
    return [numerator revenant_productWithUnit:denominator];
}

+ (instancetype)revenant_factors:(NSString *)string sign:(NSInteger)sign
{
    NSString *written = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ([written hasPrefix:@"("] && [written hasSuffix:@")"])
        written = [written substringWithRange:NSMakeRange(1, written.length - 2)];
    NSArray *parts = [written componentsSeparatedByCharactersInSet:
                          [NSCharacterSet characterSetWithCharactersInString:
                               [NSString stringWithFormat:@"%@*", RevenantHKMultiply]]];
    NSMutableArray *bases = [NSMutableArray array];
    NSMutableDictionary *powers = [NSMutableDictionary dictionary];
    NSMutableDictionary *names = [NSMutableDictionary dictionary];
    double scale = 1.0;
    for (NSString *part in parts) {
        NSString *name = [part stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (!name.length)
            return nil;
        HKUnit *one = [self revenant_namedUnit:name];
        if (!one)
            return nil;
        for (NSString *base in one.revenant_bases) {
            NSInteger power = [powers[base] integerValue] + [one.revenant_powers[base] integerValue] * sign;
            if (!power) {
                [powers removeObjectForKey:base];
                [names removeObjectForKey:base];
                [bases removeObject:base];
            } else {
                powers[base] = @(power);
                names[base] = one.revenant_names[base];
                if (![bases containsObject:base])
                    [bases addObject:base];
            }
        }
        scale *= sign > 0 ? one.revenant_scale : (one.revenant_scale == 0.0 ? 1.0 : 1.0 / one.revenant_scale);
    }
    if (!bases.count)
        return nil;
    HKUnit *made = [self revenant_unitWithString:written
                                        scale:scale
                                       offset:0.0
                                        bases:bases
                                       powers:powers
                                        names:names];
    return made;
}

static NSString *RevenantHKStringForDimensions(NSArray *bases, NSDictionary *powers, NSDictionary *names)
{
    NSMutableArray *numerator = [NSMutableArray array], *denominator = [NSMutableArray array];
    for (NSString *base in bases) {
        NSInteger power = [powers[base] integerValue];
        if (!power)
            continue;
        NSString *written = names[base] ?: base;
        NSString *name = labs(power) == 1 ? written
                                          : [NSString stringWithFormat:@"%@%@%ld", written, RevenantHKPower,
                                                                       (long)labs(power)];
        [power > 0 ? numerator : denominator addObject:name];
    }
    NSMutableString *written = [NSMutableString string];
    if (!numerator.count)
        [written appendString:@"1"];
    [written appendString:[numerator componentsJoinedByString:RevenantHKMultiply]];
    if (denominator.count) {
        [written appendString:RevenantHKDivide];
        [written appendString:[denominator componentsJoinedByString:RevenantHKMultiply]];
    }
    return written;
}

#pragma mark The arithmetic of the header

- (HKUnit *)revenant_productWithUnit:(HKUnit *)unit
{
    NSMutableDictionary *powers = [_powers mutableCopy];
    NSMutableDictionary *names = [_names mutableCopy];
    NSMutableArray *bases = [NSMutableArray arrayWithArray:_bases];
    for (NSString *base in ((HKUnit *)unit).revenant_bases) {
        NSInteger power = [powers[base] integerValue] + [((HKUnit *)unit).revenant_powers[base] integerValue];
        if (!power) {
            [powers removeObjectForKey:base];
            [names removeObjectForKey:base];
            [bases removeObject:base];
        } else {
            powers[base] = @(power);
            names[base] = ((HKUnit *)unit).revenant_names[base] ?: _names[base];
            if (![bases containsObject:base])
                [bases addObject:base];
        }
    }
    if (!bases.count)
        return [HKUnit revenant_nullUnit];
    return [HKUnit revenant_unitWithString:RevenantHKStringForDimensions(bases, powers, names)
                                   scale:_scale * ((HKUnit *)unit).revenant_scale
                                  offset:0.0
                                   bases:bases
                                  powers:powers
                                   names:names];
}

- (HKUnit *)unitMultipliedByUnit:(HKUnit *)unit
{
    return [self revenant_productWithUnit:unit];
}

- (HKUnit *)unitDividedByUnit:(HKUnit *)unit
{
    return [self revenant_productWithUnit:((HKUnit *)unit).revenant_reciprocal];
}

- (HKUnit *)revenant_reciprocal
{
    if (!_bases.count)
        return [HKUnit revenant_nullUnit];
    NSMutableDictionary *powers = [NSMutableDictionary dictionary];
    for (NSString *base in _bases)
        powers[base] = @(-[_powers[base] integerValue]);
    return [HKUnit revenant_unitWithString:RevenantHKStringForDimensions(_bases, powers, _names)
                                   scale:(_scale == 0.0 ? 1.0 : 1.0 / _scale)
                                  offset:0.0
                                   bases:_bases
                                  powers:powers
                                   names:_names];
}

- (HKUnit *)reciprocalUnit
{
    return [self revenant_reciprocal];
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
        return [HKUnit revenant_nullUnit];
    return [HKUnit revenant_unitWithString:RevenantHKStringForDimensions(bases, powers, names)
                                   scale:scale
                                  offset:0.0
                                   bases:bases
                                  powers:powers
                                   names:names];
}

#pragma mark Comparing units

- (BOOL)revenant_isCompatibleWithUnit:(HKUnit *)unit
{
    if (![unit isKindOfClass:[HKUnit class]])
        return NO;
    NSArray *mine = _bases, *theirs = ((HKUnit *)unit).revenant_bases;
    if (mine.count != theirs.count)
        return NO;
    for (NSUInteger index = 0; index < mine.count; index++) {
        if (![mine[index] isEqualToString:theirs[index]])
            return NO;
        if ([_powers[mine[index]] integerValue] != [((HKUnit *)unit).revenant_powers[theirs[index]] integerValue])
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
    return [_unitString isEqualToString:((HKUnit *)other).unitString] && [self revenant_isCompatibleWithUnit:other];
}

- (NSUInteger)hash
{
    return _unitString.hash;
}

- (NSString *)description
{
    return _unitString;
}

- (double)revenant_value:(double)value inUnit:(HKUnit *)unit
{
    double base = (value + _offset) * _scale;
    return base / (unit.revenant_scale == 0.0 ? 1.0 : unit.revenant_scale) - unit.revenant_offset;
}

#pragma mark The factory methods of the header

+ (instancetype)gramUnit
{
    return [self revenant_namedUnit:@"g"];
}

+ (instancetype)gramUnitWithMetricPrefix:(HKMetricPrefix)prefix
{
    return [self revenant_prefixedUnitForDimension:RevenantHKDimensionMass prefix:prefix];
}

+ (instancetype)ounceUnit
{
    return [self revenant_namedUnit:@"oz"];
}

+ (instancetype)poundUnit
{
    return [self revenant_namedUnit:@"lb"];
}

+ (instancetype)stoneUnit
{
    return [self revenant_namedUnit:@"st"];
}

+ (instancetype)moleUnitWithMetricPrefix:(HKMetricPrefix)prefix molarMass:(double)gramsPerMole
{
    if (gramsPerMole <= 0.0) {
        [NSException raise:NSInvalidArgumentException format:@"A molar mass must be positive, and %g is not.", gramsPerMole];
        return nil;
    }
    return [self revenant_moleUnitWithPrefix:prefix molarMass:gramsPerMole];
}

+ (instancetype)moleUnitWithMolarMass:(double)gramsPerMole
{
    return [self moleUnitWithMetricPrefix:HKMetricPrefixNone molarMass:gramsPerMole];
}

+ (instancetype)meterUnit
{
    return [self revenant_namedUnit:@"m"];
}

+ (instancetype)meterUnitWithMetricPrefix:(HKMetricPrefix)prefix
{
    return [self revenant_prefixedUnitForDimension:RevenantHKDimensionLength prefix:prefix];
}

+ (instancetype)inchUnit
{
    return [self revenant_namedUnit:@"in"];
}

+ (instancetype)footUnit
{
    return [self revenant_namedUnit:@"ft"];
}

+ (instancetype)yardUnit
{
    return [self revenant_namedUnit:@"yd"];
}

+ (instancetype)mileUnit
{
    return [self revenant_namedUnit:@"mi"];
}

+ (instancetype)literUnit
{
    return [self revenant_namedUnit:@"L"];
}

+ (instancetype)literUnitWithMetricPrefix:(HKMetricPrefix)prefix
{
    return [self revenant_prefixedUnitForDimension:RevenantHKDimensionVolume prefix:prefix];
}

+ (instancetype)fluidOunceUSUnit
{
    return [self revenant_namedUnit:@"fl_oz_us"];
}

+ (instancetype)fluidOunceImperialUnit
{
    return [self revenant_namedUnit:@"fl_oz_imp"];
}

+ (instancetype)pintUSUnit
{
    return [self revenant_namedUnit:@"pt_us"];
}

+ (instancetype)pintImperialUnit
{
    return [self revenant_namedUnit:@"pt_imp"];
}

+ (instancetype)cupUSUnit
{
    return [self revenant_namedUnit:@"cup_us"];
}

+ (instancetype)cupImperialUnit
{
    return [self revenant_namedUnit:@"cup_imp"];
}

+ (instancetype)pascalUnit
{
    return [self revenant_namedUnit:@"Pa"];
}

+ (instancetype)pascalUnitWithMetricPrefix:(HKMetricPrefix)prefix
{
    return [self revenant_prefixedUnitForDimension:RevenantHKDimensionPressure prefix:prefix];
}

+ (instancetype)millimeterOfMercuryUnit
{
    return [self revenant_namedUnit:@"mmHg"];
}

+ (instancetype)centimeterOfWaterUnit
{
    return [self revenant_namedUnit:@"cmAq"];
}

+ (instancetype)atmosphereUnit
{
    return [self revenant_namedUnit:@"atm"];
}

+ (instancetype)secondUnit
{
    return [self revenant_namedUnit:@"s"];
}

+ (instancetype)secondUnitWithMetricPrefix:(HKMetricPrefix)prefix
{
    return [self revenant_prefixedUnitForDimension:RevenantHKDimensionTime prefix:prefix];
}

+ (instancetype)minuteUnit
{
    return [self revenant_namedUnit:@"min"];
}

+ (instancetype)hourUnit
{
    return [self revenant_namedUnit:@"hr"];
}

+ (instancetype)dayUnit
{
    return [self revenant_namedUnit:@"d"];
}

+ (instancetype)jouleUnit
{
    return [self revenant_namedUnit:@"J"];
}

+ (instancetype)jouleUnitWithMetricPrefix:(HKMetricPrefix)prefix
{
    return [self revenant_prefixedUnitForDimension:RevenantHKDimensionEnergy prefix:prefix];
}

+ (instancetype)kilocalorieUnit
{
    return [self revenant_namedUnit:@"kcal"];
}

+ (instancetype)calorieUnit
{
    return [self revenant_namedUnit:@"cal"];
}

+ (instancetype)degreeCelsiusUnit
{
    return [self revenant_namedUnit:@"degC"];
}

+ (instancetype)degreeFahrenheitUnit
{
    return [self revenant_namedUnit:@"degF"];
}

+ (instancetype)kelvinUnit
{
    return [self revenant_namedUnit:@"K"];
}

+ (instancetype)siemenUnit
{
    return [self revenant_namedUnit:@"S"];
}

+ (instancetype)siemenUnitWithMetricPrefix:(HKMetricPrefix)prefix
{
    return [self revenant_prefixedUnitForDimension:RevenantHKDimensionConductance prefix:prefix];
}

+ (instancetype)countUnit
{
    return [self revenant_namedUnit:@"count"];
}

+ (instancetype)percentUnit
{
    return [self revenant_namedUnit:@"%"];
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
        return [self revenant_namedUnit:@"kJ"];
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

+ (nullable HKUnit *)revenant_canonicalUnitForType:(HKQuantityType *)type
{
    if (![type isKindOfClass:[HKQuantityType class]])
        return nil;
    const RevenantHKTypeEntry *entry = RevenantHKQuantityTypeEntry(type.identifier);
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
    revenant_hk_say_once([@"quantity-unit" stringByAppendingString:entry->identifier],
                       [NSString stringWithFormat:@"HealthKit: %@ is counted in '%s', which is not a unit this port can make, so it "
                                                      @"accepts none. The SDK names that string for the type, and no source this port can "
                                                      @"read names a unit for it.",
                                                      entry->identifier, entry->unit.UTF8String]);
    return nil;
}

@end
