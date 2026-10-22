#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

#import "RevenantMeasurementData.h"
#import "RevenantUnitFormat.h"

#define REVENANT_PREFERENCE(dimension, us, uk, metric) {#dimension, {#us, #uk, #metric}}

typedef struct {
    const char *dimension;
    const char *selectors[3];
} RevenantMeasurementPreference;

typedef struct {
    const char *dimension;
    const char *family[8];
} RevenantMeasurementChain;

static const RevenantMeasurementPreference revenant_preferences[] = {
    REVENANT_PREFERENCE(NSUnitLength, miles, miles, kilometers),
    REVENANT_PREFERENCE(NSUnitMass, poundsMass, kilograms, kilograms),
    REVENANT_PREFERENCE(NSUnitVolume, gallons, liters, liters),
    REVENANT_PREFERENCE(NSUnitTemperature, fahrenheit, celsius, celsius),
    REVENANT_PREFERENCE(NSUnitSpeed, milesPerHour, milesPerHour, kilometersPerHour),
    REVENANT_PREFERENCE(NSUnitPressure, inchesOfMercury, millibars, hectopascals),
    REVENANT_PREFERENCE(NSUnitEnergy, kilocalories, kilocalories, kilocalories),
    REVENANT_PREFERENCE(NSUnitFuelEfficiency, milesPerGallon, milesPerImperialGallon, litersPer100Kilometers),
};

static const RevenantMeasurementChain revenant_chains[] = {
    {"NSUnitLength", {"millimeters", "meters", "kilometers", NULL}},
    {"NSUnitLength", {"inches", "feet", "yards", "miles", NULL}},
    {"NSUnitMass", {"grams", "kilograms", NULL}},
    {"NSUnitMass", {"ounces", "poundsMass", "shortTons", NULL}},
    {"NSUnitVolume", {"milliliters", "liters", "kiloliters", NULL}},
    {"NSUnitVolume", {"fluidOunces", "cups", "gallons", NULL}},
    {"NSUnitDuration", {"seconds", "minutes", "hours", NULL}},
    {"NSUnitInformationStorage", {"bytes", "kilobytes", "megabytes", "gigabytes", "terabytes", "petabytes", NULL}},
    {"NSUnitEnergy", {"joules", "kilojoules", NULL}},
    {"NSUnitEnergy", {"calories", "kilocalories", NULL}},
};

static NSUnit *revenant_named_unit(const char *dimension, const char *selector)
{
    Class cls = NSClassFromString([NSString stringWithUTF8String:dimension]);
    SEL name = NSSelectorFromString([NSString stringWithUTF8String:selector]);
    if (!cls || ![cls respondsToSelector:name])
        return nil;
    return ((NSUnit * (*)(id, SEL))objc_msgSend)(cls, name);
}

static const RevenantMeasurementDimension *revenant_dimension_of(NSUnit *unit)
{
    for (Class cls = [unit class]; cls && cls != [NSObject class]; cls = class_getSuperclass(cls)) {
        const char *name = class_getName(cls);
        for (size_t index = 0; index < revenant_measurement_dimension_count; index++) {
            if (strcmp(revenant_measurement_dimensions[index].dimension, name) == 0)
                return &revenant_measurement_dimensions[index];
        }
    }
    return NULL;
}

static BOOL revenant_close(double a, double b)
{
    return a == b || fabs(a - b) <= 1e-9 * MAX(1.0, MAX(fabs(a), fabs(b)));
}

static const RevenantMeasurementUnit *revenant_row_of(NSUnit *unit)
{
    const RevenantMeasurementDimension *dimension = revenant_dimension_of(unit);
    if (!dimension || ![unit isKindOfClass:[NSDimension class]])
        return NULL;
    NSDimension *base = [[unit class] baseUnit];
    NSString *symbol = unit.symbol;
    double zero = [[[[NSMeasurement alloc] initWithDoubleValue:0 unit:unit] measurementByConvertingToUnit:base] doubleValue];
    double one = [[[[NSMeasurement alloc] initWithDoubleValue:1 unit:unit] measurementByConvertingToUnit:base] doubleValue];
    for (size_t index = 0; index < dimension->count; index++) {
        const RevenantMeasurementUnit *row = &dimension->units[index];
        if ([symbol isEqualToString:[NSString stringWithUTF8String:row->symbol]] && revenant_close(row->base0, zero) && revenant_close(row->base1, one))
            return row;
    }
    return NULL;
}

static NSString *revenant_fill(const char *pattern, NSString *number)
{
    return [[NSString stringWithUTF8String:pattern] stringByReplacingOccurrencesOfString:@"{0}" withString:number];
}

@implementation NSMeasurementFormatter {
    NSMeasurementFormatterUnitOptions _unitOptions;
    NSFormattingUnitStyle _unitStyle;
    NSLocale *_locale;
    NSNumberFormatter *_numberFormatter;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)init
{
    if ((self = [super init]))
        _unitStyle = NSFormattingUnitStyleMedium;
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        _unitOptions = (NSMeasurementFormatterUnitOptions)[coder decodeIntegerForKey:@"NS.unitOptions"];
        _unitStyle = (NSFormattingUnitStyle)[coder decodeIntegerForKey:@"NS.unitStyle"];
        if (!_unitStyle)
            _unitStyle = NSFormattingUnitStyleMedium;
        _locale = [[coder decodeObjectOfClass:[NSLocale class] forKey:@"NS.locale"] copy];
        _numberFormatter = [[coder decodeObjectOfClass:[NSNumberFormatter class] forKey:@"NS.numberFormatter"] copy];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeInteger:(NSInteger)_unitOptions forKey:@"NS.unitOptions"];
    [coder encodeInteger:(NSInteger)_unitStyle forKey:@"NS.unitStyle"];
    [coder encodeObject:_locale forKey:@"NS.locale"];
    [coder encodeObject:_numberFormatter forKey:@"NS.numberFormatter"];
}

- (id)copyWithZone:(NSZone *)zone
{
    NSMeasurementFormatter *copy = [super copyWithZone:zone];
    copy->_unitOptions = _unitOptions;
    copy->_unitStyle = _unitStyle;
    copy->_locale = [_locale copy];
    copy->_numberFormatter = [_numberFormatter copy];
    return copy;
}

- (NSMeasurementFormatterUnitOptions)unitOptions
{
    return _unitOptions;
}

- (void)setUnitOptions:(NSMeasurementFormatterUnitOptions)unitOptions
{
    _unitOptions = unitOptions;
}

- (NSFormattingUnitStyle)unitStyle
{
    return _unitStyle;
}

- (void)setUnitStyle:(NSFormattingUnitStyle)unitStyle
{
    _unitStyle = unitStyle;
}

- (NSLocale *)locale
{
    return _locale ?: [NSLocale currentLocale];
}

- (void)setLocale:(NSLocale *)locale
{
    _locale = [locale copy];
    _numberFormatter.locale = self.locale;
}

- (NSNumberFormatter *)numberFormatter
{
    if (!_numberFormatter) {
        _numberFormatter = [[NSNumberFormatter alloc] init];
        _numberFormatter.numberStyle = NSNumberFormatterDecimalStyle;
        _numberFormatter.locale = self.locale;
    }
    return _numberFormatter;
}

- (void)setNumberFormatter:(NSNumberFormatter *)numberFormatter
{
    _numberFormatter = [numberFormatter copy];
}

- (NSUnit *)revenant_preferredUnitFor:(NSUnit *)unit system:(RevenantUnitSystem)system
{
    const RevenantMeasurementDimension *dimension = revenant_dimension_of(unit);
    if (!dimension)
        return nil;
    for (size_t index = 0; index < sizeof revenant_preferences / sizeof *revenant_preferences; index++) {
        if (strcmp(revenant_preferences[index].dimension, dimension->dimension) == 0)
            return revenant_named_unit(dimension->dimension, revenant_preferences[index].selectors[system]);
    }
    return nil;
}

- (NSMeasurement *)revenant_scaled:(NSMeasurement *)measurement within:(NSUnit *)anchor
{
    const RevenantMeasurementDimension *dimension = revenant_dimension_of(anchor);
    const RevenantMeasurementUnit *anchorRow = revenant_row_of(anchor);
    if (!dimension || !anchorRow)
        return measurement;
    for (size_t index = 0; index < sizeof revenant_chains / sizeof *revenant_chains; index++) {
        const RevenantMeasurementChain *chain = &revenant_chains[index];
        if (strcmp(chain->dimension, dimension->dimension) != 0)
            continue;
        NSMutableArray *units = [NSMutableArray array];
        BOOL member = NO;
        for (size_t at = 0; chain->family[at]; at++) {
            NSUnit *unit = revenant_named_unit(dimension->dimension, chain->family[at]);
            if (!unit)
                continue;
            [units addObject:unit];
            member = member || revenant_row_of(unit) == anchorRow;
        }
        if (!member)
            continue;
        NSMeasurement *chosen = nil;
        for (NSUnit *unit in units) {
            NSMeasurement *candidate = [measurement measurementByConvertingToUnit:unit];
            if (!chosen || fabs(candidate.doubleValue) >= 1.0)
                chosen = candidate;
            if (fabs(candidate.doubleValue) < 1.0 && chosen != candidate)
                break;
        }
        return chosen ?: measurement;
    }
    return measurement;
}

- (NSMeasurement *)revenant_displayed:(NSMeasurement *)measurement
{
    BOOL provided = (_unitOptions & NSMeasurementFormatterUnitOptionsProvidedUnit) != 0;
    BOOL natural = (_unitOptions & NSMeasurementFormatterUnitOptionsNaturalScale) != 0;
    NSUnit *unit = measurement.unit;
    if (!revenant_dimension_of(unit))
        return measurement;
    NSMeasurement *shown = measurement;
    if (!provided) {
        NSUnit *preferred = [self revenant_preferredUnitFor:unit system:revenant_unit_system(self.locale)];
        if (preferred && [measurement canBeConvertedToUnit:preferred])
            shown = [measurement measurementByConvertingToUnit:preferred];
    }
    if (natural)
        shown = [self revenant_scaled:shown within:shown.unit];
    return shown;
}

- (NSString *)stringFromMeasurement:(NSMeasurement *)measurement
{
    NSMeasurement *shown = [self revenant_displayed:measurement];
    NSNumberFormatter *numbers = self.numberFormatter;
    NSString *number = [numbers stringFromNumber:@(shown.doubleValue)];
    const RevenantMeasurementUnit *row = revenant_row_of(shown.unit);
    NSFormattingUnitStyle style = _unitStyle < NSFormattingUnitStyleShort || _unitStyle > NSFormattingUnitStyleLong ? NSFormattingUnitStyleMedium : _unitStyle;
    if (!row)
        return [NSString stringWithFormat:@"%@ %@", number, shown.unit.symbol];
    if ((_unitOptions & NSMeasurementFormatterUnitOptionsTemperatureWithoutUnit) && [shown.unit isKindOfClass:[NSUnitTemperature class]])
        return [number stringByAppendingString:@"°"];
    int variant = revenant_unit_system(self.locale) == RevenantUnitSystemUnitedKingdom ? 1 : 0;
    BOOL one = [number isEqualToString:[numbers stringFromNumber:@1]];
    return revenant_fill(row->patterns[variant][(style - NSFormattingUnitStyleShort) * 2 + (one ? 0 : 1)], number);
}

- (NSString *)stringFromUnit:(NSUnit *)unit
{
    const RevenantMeasurementUnit *row = revenant_row_of(unit);
    if (!row)
        return unit.symbol;
    NSFormattingUnitStyle style = _unitStyle < NSFormattingUnitStyleShort || _unitStyle > NSFormattingUnitStyleLong ? NSFormattingUnitStyleMedium : _unitStyle;
    int variant = revenant_unit_system(self.locale) == RevenantUnitSystemUnitedKingdom ? 1 : 0;
    return [NSString stringWithUTF8String:row->names[variant][style - NSFormattingUnitStyleShort]];
}

- (NSString *)stringForObjectValue:(id)object
{
    return [object isKindOfClass:[NSMeasurement class]] ? [self stringFromMeasurement:object] : nil;
}

- (BOOL)getObjectValue:(id *)object forString:(NSString *)string errorDescription:(NSString **)error
{
    if (error)
        *error = @"NSMeasurementFormatter cannot convert a string to a measurement";
    return NO;
}

@end
