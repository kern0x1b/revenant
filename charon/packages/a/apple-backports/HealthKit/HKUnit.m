// HKUnit: what a quantity is counted in, and the arithmetic between units of one dimension.
//
// A unit here is a product of powers of the base units of its dimensions, a factor for the whole
// product, and the additive offset that only a temperature has: a value in the unit comes to a value
// in the base as (value + offset) * factor. So m/s is {m: 1, s: -1}, kg/m·s^2 is {kg: 1, m: -1,
// s: -2}, and degF is 5/9 with an offset of 459.67, which is what makes it a temperature.
//
// Every string, every factor and the spelling of every product in this file is what the host's own
// HealthKit answers, read by tests/backports/host/healthkit/run.sh, which asks the system and this
// code the same questions in one process and fails on any difference. That is where these come from:
//   - the micro prefix is `mc`, not `u` and not U+03BC: the host raises "Unable to parse
//     factorization string" for `ug` and for `μg` alike, and `+gramUnitWithMetricPrefix:
//     HKMetricPrefixMicro` answers `mcg`.
//   - a prefix is put in front of the base unit's own name, so a milli-pascal is `mPa` and a
//     mega-litre is `ML`, and the thirteen prefixes are the header's own cases.
//   - `%` is not a dimension of its own: the host answers one for the conversion of a percent into a
//     count. `count` is the base of both.
//   - `IU` is a dimension of its own, and a molar unit is its own base with the molar mass as its
//     factor: `mol<12>` is 12 g a mole, `mmol<12>` is 0.012 g, and the two are compatible, which the
//     host confirms by answering six for one `mol<12>` in `mol<2>`.
//   - a product is written with U+00B7 between its factors, a power with `^`, and a quotient with a
//     solidus and no parentheses: `m·s`, `m^2`, `kg/m·s^2`, `mL/min·kg`, `1/s`. A `*` is read as the
//     same separator a string is written with, and at most one solidus is read: `J/m/kg/s` raises.
//   - a string the host cannot parse raises rather than answering nil, which is what its nonnull
//     return and its own "Unable to parse factorization string" say. So does an empty one.
//   - the litre's own name is the one letter whose case does not matter: `ml` and `ML` and `mL` are
//     the millilitre, the megalitre and the millilitre, and `kg` and `Kg` and `KG` are the kilogram and
//     two strings the host raises for.
//   - `kWh` is not a unit: the host raises for it, and no factory method of the header makes one.
//
// The factors are the international ones behind the names: the inch as 0.0254 m, the foot as 0.3048 m,
// the mile as 1609.344 m, the avoirdupois pound as 453.59237 g, the stone as 6350.29318 g, the US
// fluid ounce as 0.0295735295625 L and the imperial one as 0.0284130625 L, the US cup as half a US
// pint and the imperial cup as half an imperial pint, the millimetre of mercury as 133.322387415 Pa,
// the centimetre of water as 98.0665 Pa, the standard atmosphere as 101325 Pa, the thermochemical
// calorie as 4.184 J and the large one as 4184 J.

#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"
#import "CharonHKTypes.h"

// Every dimension the units of this framework has, and the unit it is expressed in. A unit of another
// dimension is not compatible with it, and a count is a count whatever the caller calls it.
enum {
    CharonHKDimensionMass = 0,          // gram
    CharonHKDimensionLength,           // metre
    CharonHKDimensionVolume,           // litre
    CharonHKDimensionPressure,         // pascal
    CharonHKDimensionTime,             // second
    CharonHKDimensionEnergy,           // joule
    CharonHKDimensionTemperature,      // kelvin
    CharonHKDimensionConductance,      // siemens
    CharonHKDimensionCount,            // a dimensionless count, which a percent is too
    CharonHKDimensionMoles,            // a mole, whose molar mass is the factor of the unit
    CharonHKDimensionInternationalUnit, // the international unit of a pharmacology
    CharonHKDimensionSoundLevel,       // a weighted sound pressure level, a level and not a pressure
    CharonHKDimensionFrequency,         // a frequency
    CharonHKDimensionHearingLevel,      // a hearing level
    CharonHKDimensionPotential,         // an electric potential difference
    CharonHKDimensionPower,             // a power
    CharonHKDimensionEffortScore,       // the score an effort is measured in
    CharonHKDimensionCountOfDimensions,
};

// The middle dot a product is written with, and the carets and solidus the rest.
static NSString *const CharonHKMultiply = @"·";  // U+00B7
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

// The thirteen prefixes of the header's own enum, in its order, spelled the way the host spells them.
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

// The power of ten a prefix stands for, which is what the header's own comment gives for each.
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

// One unit of the header's own: the string it writes, the dimension it is of and the factor it is
// worth in that dimension's base. Read off the factory methods of HKUnit.h and the comments beside
// them, and held to the host's own answers by tests/backports/host/healthkit.
typedef struct {
    __unsafe_unretained NSString *string;
    NSInteger dimension;
    double factor;
    double offset;
} CharonHKUnitEntry;

static const CharonHKUnitEntry CharonHKUnitTable[] = {
    // mass, in grams
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
    // length, in metres
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
    // volume, in litres
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
    // pressure, in pascals
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
    // time, in seconds
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
    // energy, in joules
    {@"J", CharonHKDimensionEnergy, 1.0, 0.0},
    {@"kJ", CharonHKDimensionEnergy, 1000.0, 0.0},
    {@"MJ", CharonHKDimensionEnergy, 1e6, 0.0},
    {@"cal", CharonHKDimensionEnergy, 4.184, 0.0},
    {@"kcal", CharonHKDimensionEnergy, 4184.0, 0.0},
    {@"Cal", CharonHKDimensionEnergy, 4184.0, 0.0},
    // temperature, in kelvin
    {@"K", CharonHKDimensionTemperature, 1.0, 0.0},
    {@"degC", CharonHKDimensionTemperature, 1.0, 273.15},
    {@"degF", CharonHKDimensionTemperature, 5.0 / 9.0, 459.67},
    // conductance, in siemens
    {@"S", CharonHKDimensionConductance, 1.0, 0.0},
    {@"kS", CharonHKDimensionConductance, 1e3, 0.0},
    {@"MS", CharonHKDimensionConductance, 1e6, 0.0},
    {@"mS", CharonHKDimensionConductance, 1e-3, 0.0},
    {@"mcS", CharonHKDimensionConductance, 1e-6, 0.0},
    {@"nS", CharonHKDimensionConductance, 1e-9, 0.0},
    {@"pS", CharonHKDimensionConductance, 1e-12, 0.0},
    // dimensionless: a count, and a percent, which is a count
    {@"count", CharonHKDimensionCount, 1.0, 0.0},
    {@"%", CharonHKDimensionCount, 1.0, 0.0},
    // the international unit of a pharmacology, and a weighted sound pressure level
    {@"IU", CharonHKDimensionInternationalUnit, 1.0, 0.0},
    {@"dBASPL", CharonHKDimensionSoundLevel, 1.0, 0.0},
    // and the ones the header adds in the releases after iOS 8, which the SDK's own table of the
    // quantity types already names: a frequency, a hearing level, an electric potential difference
    // and a power are each a dimension of their own, which the host confirms - none of them converts
    // to a count. They are here because a type is counted in one of them and a type that accepts no
    // unit accepts nothing.
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
    // and the score a workout's effort is measured in, which the host keeps as a dimension of its own
    // - it is not a count and does not convert to one
    {@"appleEffortScore", CharonHKDimensionEffortScore, 1.0, 0.0},
    // the prefixed names the header's factories make, the ones a caller can ask for by name
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
// The port's own storage, under the prefix the rest of this library uses, so that no selector the
// SDK's headers do not declare is exported on HKUnit itself: -charon_scale, -charon_offset,
// -charon_bases, -charon_powers and -charon_names, with their five setters.
//
// charon_scale is the factor of the whole product, so that a value in this unit times it, plus the
// offset, is the value in the base of every dimension the unit carries, and charon_offset is the
// additive one only a temperature has.
@property (readwrite) double charon_scale;
@property (readwrite) double charon_offset;
// The dimensions the unit has, each named by the base unit of that dimension, so that two units of one
// dimension compare equal and a unit of a product does not.
@property (readwrite, copy) NSArray<NSString *> *charon_bases;
@property (readwrite, copy) NSDictionary<NSString *, NSNumber *> *charon_powers;
// The name each dimension is written with, which is not always its base: a minute is `min` and not
// `s`, a milligram is `mg` and not `g`, so a product of a minute and a kilogram writes the two names
// and not the two bases. The host keeps the same - `count/min` and `mg/dL` come back as they went in.
@property (readwrite, copy) NSDictionary<NSString *, NSString *> *charon_names;
@end

@implementation HKUnit
// The strict check the build runs asks for every property a class extension redeclares to be
// synthesized explicitly, so that a property and the ivar behind it cannot drift apart by accident.
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

// The one place a unit is made: the string it writes, the factor of the whole product, the offset only
// a temperature has, and the dimensions it carries with the power of each.
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

// The null unit: a unit of no dimension, which the host writes as `()` and which -isNull answers YES
// of, and which no factory method of the header makes.
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
    // The litre is the one unit whose name does not keep its case: the host reads `ml`, `ML` and
    // `mL` as three different units and raises for `kg`, so the case that does not matter is the one
    // letter of the litre.
    if ([string rangeOfString:@"l"].location != NSNotFound) {
        NSString *spelled = [string stringByReplacingOccurrencesOfString:@"l" withString:@"L"];
        if (![spelled isEqualToString:string])
            return [self charon_namedUnit:spelled];
    }
    return nil;
}

// The unit of a dimension with a metric prefix in front of the base unit's own name, which is every
// prefixed factory method of the header: gramUnitWithMetricPrefix:, meterUnitWithMetricPrefix:,
// literUnitWithMetricPrefix:, pascalUnitWithMetricPrefix:, secondUnitWithMetricPrefix:,
// jouleUnitWithMetricPrefix: and siemenUnitWithMetricPrefix:.
+ (instancetype)charon_prefixedUnitForDimension:(NSInteger)dimension prefix:(HKMetricPrefix)prefix
{
    double factor = 1.0;
    if (!CharonHKPrefixFactor(prefix, &factor) || dimension < 0 ||
        (NSUInteger)dimension >= CharonHKDimensionCountOfDimensions)
        return nil;
    NSString *name = [CharonHKPrefixName(prefix) stringByAppendingString:CharonHKBaseUnit(dimension)];
    return [self charon_unitOfDimension:dimension string:name factor:factor offset:0.0];
}

// A molar unit, which is a mole with the molar mass as its factor: the header spells it mol<double>,
// and the host writes mol<12> for a molar mass of 12 and mmol<12> for the milli of one. Two molar
// units of different masses are compatible, and one of them is that many grams.
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

// A string that is not a unit is refused the way the host refuses one, with the same words, rather
// than answered nil: the host's return is nonnull and a nil from it would be a unit of nothing.
+ (void)charon_refuseFactorization:(NSString *)string
{
    [NSException raise:NSInvalidArgumentException format:@"Unable to parse factorization string %@", string];
}

+ (instancetype)unitFromString:(NSString *)string
{
    if (![string isKindOfClass:[NSString class]])
        [self charon_refuseFactorization:string];
    // The empty string is the null unit and not a refusal: the host answers a unit for it, whose
    // unitString is the two parentheses of a product with no factor in it and whose -isNull is YES.
    if (!string.length)
        return [self charon_nullUnit];
    HKUnit *named = [self charon_namedUnit:string];
    if (named)
        return named;
    // A molar unit carries its molar mass in its own name, so it is read out of that name rather
    // than out of the table, which holds no row for it: the table has one row per name it knows and
    // this is a name per molar mass.
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

// A string that is a product of the units above: m/s, kg/m·s^2, kcal/(kg*hr) and everything else the
// header and the type table write that way. The middle dot separates the factors of a product and the
// solidus separates a numerator from a denominator, and neither a string that names nothing the table
// holds nor one that does not parse is a unit.
+ (instancetype)charon_unitFromString:(NSString *)string
{
    NSString *written = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSArray *halves = [written componentsSeparatedByString:CharonHKDivide];
    // At most one solidus: the host reads `J/m/kg/s` as three divisions and refuses it, and so does
    // this, because a unit of a quotient of a quotient is written with parentheses the host does not
    // read either.
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

// A list of factors, separated by the middle dot or written in parentheses, turned into a unit; sign is
// the power the whole list carries, so a denominator's factors come out inverted.
+ (instancetype)charon_factors:(NSString *)string sign:(NSInteger)sign
{
    NSString *written = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ([written hasPrefix:@"("] && [written hasSuffix:@")"])
        written = [written substringWithRange:NSMakeRange(1, written.length - 2)];
    // A product is written with the middle dot and read with either it or a solidus-shaped `*`: the
    // host reads `m*s` as `m·s`.
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

// The string of a product, which is what the host writes: the factors with a positive power joined by
// the middle dot, a solidus, and the ones with a negative power joined the same way, and a caret and a
// number for a power that is not one. The host writes no parentheses, so `kg/m·s^2` is a kilogram
// divided by a metre second squared and is what `kg` over `m·s` over `s` comes out as.
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
    // A product carries no offset. The host makes no exception of a temperature: it writes
    // `degC·m` for a degree Celsius times a metre, `1/degC` for its reciprocal and `degC^2` for a
    // degree Celsius times itself, and `(degC·m)/degC` comes back as `m` - the two temperatures cancel
    // and the offset does not survive into the product at all. So the product's offset is zero and
    // nothing is refused.
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
            // The name a dimension is written with is the one it was last introduced under, which is
            // what the host writes too: a minute divided by a kilogram writes `min` and `kg`.
            names[base] = ((HKUnit *)unit).charon_names[base] ?: _names[base];
            if (![bases containsObject:base])
                [bases addObject:base];
        }
    }
    // The product of nothing is the null unit, and so is anything else with no factor in it: the
    // host's reciprocal of its `()` is `()` and not `1`.
    if (!bases.count)
        return [HKUnit charon_nullUnit];
    // The bases are written in the order the two units were given in, which is the order the host
    // writes them in and the one `mL/min·kg` and `kcal/hr·kg` show.
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
    // A reciprocal carries no offset either, for the same reason and by the same measurement. The
    // reciprocal of the null unit is the null unit: the host answers `()` for both.
    if (!_bases.count)
        return [HKUnit charon_nullUnit];
    NSMutableDictionary *powers = [NSMutableDictionary dictionary];
    for (NSString *base in _bases)
        powers[base] = @(-[_powers[base] integerValue]);
    // The inverted powers already write the solidus and the one: the reciprocal of a gram is `1/g`, not
    // `1/1/g`, so the string is the one for the inverted dimensions and nothing is put in front of it.
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
    // The product of nothing is the null unit, and so is anything else with no factor in it: the
    // host's reciprocal of its `()` is `()` and not `1`.
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
    // The offset is not part of it: a degree Celsius and a kelvin are one dimension, and the offset is
    // what converts between them. Only the dimensions and their powers decide, which is what the host
    // does as well - it answers a Celsius compatible with a kelvin.
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

// What HKQuantity asks of a unit: the value in the receiver, brought to the base of the dimension and
// then to the unit asked for.
- (double)charon_value:(double)value inUnit:(HKUnit *)unit
{
    double base = (value + _offset) * _scale;
    return base / (unit.charon_scale == 0.0 ? 1.0 : unit.charon_scale) - unit.charon_offset;
}

#pragma mark The factory methods of the header

// +[HKUnit kilojoulesUnit] and +[HKUnit milliseconds] are not here: no SDK header of 16.4 or 26.2
// declares either, though the HealthKit image of the armv7 shared cache of 8.0 carries both. They are
// Apple's own, and this port does not answer a member of Apple's under a public-shaped name. The two
// units are in the table and +[HKUnit unitFromString:] reads them, which is where a caller of this
// library meets them.

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

// The unit a quantity type is counted in, as the SDK's own table of the type's unit names it. A type
// whose documented unit is one this class cannot make is one it refuses a unit for, once, in the log.
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
        // A string the SDK names for a type and no unit can be made of: the reader refuses it, which
        // is the refusal this method exists to turn into an answer.
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
