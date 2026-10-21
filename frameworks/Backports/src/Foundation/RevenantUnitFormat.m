#import <Foundation/Foundation.h>
#include <math.h>

#import "RevenantUnitFormat.h"

static const RevenantUnitName revenant_length_names[] = {
    {8, "mm", "mm", "millimeter", "millimeters"},
    {9, "cm", "cm", "centimeter", "centimeters"},
    {11, "m", "m", "meter", "meters"},
    {14, "km", "km", "kilometer", "kilometers"},
    {1281, "\u2033", "in", "inch", "inches"},
    {1282, "\u2032", "ft", "foot", "feet"},
    {1283, "yd", "yd", "yard", "yards"},
    {1284, "mi", "mi", "mile", "miles"},
};

static const RevenantUnitName revenant_length_names_metre[] = {
    {8, "mm", "mm", "millimetre", "millimetres"},
    {9, "cm", "cm", "centimetre", "centimetres"},
    {11, "m", "m", "metre", "metres"},
    {14, "km", "km", "kilometre", "kilometres"},
    {1281, "\u2033", "in", "inch", "inches"},
    {1282, "\u2032", "ft", "foot", "feet"},
    {1283, "yd", "yd", "yard", "yards"},
    {1284, "mi", "mi", "mile", "miles"},
};

static const RevenantUnitName revenant_mass_names[] = {
    {11, "g", "g", "gram", "grams"},
    {14, "kg", "kg", "kilogram", "kilograms"},
    {1537, "oz", "oz", "ounce", "ounces"},
    {1538, "lb", "lb", "pound", "pounds"},
    {1539, "st", "st", "stone", "stones"},
};

static const RevenantUnitName revenant_energy_names[] = {
    {11, "J", "J", "joule", "joules"},
    {14, "kJ", "kJ", "kilojoule", "kilojoules"},
    {1793, "cal", "cal", "calorie", "calories"},
    {1794, "kcal", "kcal", "kilocalorie", "kilocalories"},
};

static const RevenantUnitChoice revenant_length_us[] = {
    {1284, 1609.3470878864448, 0.00062137},
    {1283, 0.91441111923921015, 1.0936},
    {1282, 0.30479999024640036, 3.28084},
    {1281, -1, 39.3701},
};

static const RevenantUnitChoice revenant_length_metric[] = {
    {14, 1000.0000000000001, 0.001},
    {11, 1.0000000000000002, 1},
    {9, 0.010000000000000002, 100},
    {8, -1, 1000},
};

static const RevenantUnitChoice revenant_energy_us[] = {
    {1794, 4184.0000000000009, 1.0 / 4184.0},
    {1793, -1, 1.0 / 4.184},
};

static const RevenantUnitChoice revenant_energy_metric[] = {
    {14, 1000.0000000000001, 0.001},
    {11, -1, 1},
};

static const RevenantUnitChoice revenant_mass_us[] = {
    {1538, 0.4535923700100355, 2.2046226218},
    {1537, -1, 35.2739619},
};

static const RevenantUnitChoice revenant_mass_metric[] = {
    {14, 1.0000000000000002, 1},
    {11, -1, 1000},
};

static const RevenantUnitDimension revenant_length_us_dimension = {revenant_length_names, 8, revenant_length_us, 4, 1283, 1284};
static const RevenantUnitDimension revenant_length_metric_dimension = {revenant_length_names_metre, 8, revenant_length_metric, 4, 8, 14};
static const RevenantUnitDimension revenant_mass_us_dimension = {revenant_mass_names, 5, revenant_mass_us, 2, 1538, 1538};
static const RevenantUnitDimension revenant_mass_metric_dimension = {revenant_mass_names, 5, revenant_mass_metric, 2, 14, 14};
static const RevenantUnitDimension revenant_energy_us_dimension = {revenant_energy_names, 4, revenant_energy_us, 2, 1794, 1794};
static const RevenantUnitDimension revenant_energy_metric_dimension = {revenant_energy_names, 4, revenant_energy_metric, 2, 14, 14};

static const RevenantUnitDimension *revenant_dimension(NSString *dimension, RevenantUnitSystem system)
{
    BOOL us = system == RevenantUnitSystemUnitedStates;
    if ([dimension isEqualToString:@"length"])
        return us ? &revenant_length_us_dimension : &revenant_length_metric_dimension;
    if ([dimension isEqualToString:@"mass"])
        return us ? &revenant_mass_us_dimension : &revenant_mass_metric_dimension;
    return us ? &revenant_energy_us_dimension : &revenant_energy_metric_dimension;
}

static const RevenantUnitName *revenant_unit_entry(NSString *dimension, RevenantUnitSystem system, NSInteger unit)
{
    const RevenantUnitDimension *table = revenant_dimension(dimension, system);
    for (NSUInteger index = 0; index < table->knownCount; index++)
        if (table->known[index].unit == unit)
            return &table->known[index];
    return NULL;
}

RevenantUnitSystem revenant_unit_system(NSLocale *locale)
{
    NSString *system = [[locale objectForKey:NSLocaleMeasurementSystem] description];
    if ([system isEqualToString:@"U.S."])
        return RevenantUnitSystemUnitedStates;
    if ([system isEqualToString:@"U.K."])
        return RevenantUnitSystemUnitedKingdom;
    return RevenantUnitSystemMetric;
}

double revenant_unit_factor(NSString *dimension, RevenantUnitSystem system, NSInteger unit)
{
    const RevenantUnitDimension *table = revenant_dimension(dimension, system);
    for (NSUInteger index = 0; index < table->choiceCount; index++)
        if (table->choices[index].unit == unit)
            return table->choices[index].factor;
    return 0;
}

NSInteger revenant_unit_chosen(NSString *dimension, RevenantUnitSystem system, BOOL person, double base, double *chosen)
{
    const RevenantUnitDimension *table = revenant_dimension(dimension, system);

    if (person && [dimension isEqualToString:@"length"]) {
        NSInteger unit = system == RevenantUnitSystemMetric ? 9 : 1282;
        if (chosen)
            *chosen = base * revenant_unit_factor(dimension, system, unit);
        return unit;
    }
    if (base == 0 || base < 0) {
        NSInteger unit = base == 0 ? table->zero : table->negative;
        if (chosen)
            *chosen = base * revenant_unit_factor(dimension, system, unit);
        return unit;
    }
    for (NSUInteger index = 0; index < table->choiceCount; index++)
        if (base >= table->choices[index].threshold) {
            if (chosen)
                *chosen = base * table->choices[index].factor;
            return table->choices[index].unit;
        }
    return table->choices[table->choiceCount - 1].unit;
}

static BOOL revenant_unit_writes_one(double value, NSNumberFormatter *numbers)
{
    if (!numbers)
        return fabs(value) == 1;
    NSUInteger digits = numbers.maximumFractionDigits;
    if (digits > 17)
        digits = 17;
    double scale = pow(10.0, (double)digits);
    double rounded = (value < 0 ? -floor(-value * scale + 0.5) : floor(value * scale + 0.5)) / scale;
    return rounded == 1 || rounded == -1;
}

NSString *revenant_unit_written_name(NSString *dimension, RevenantUnitSystem system, NSInteger unit,
                                   NSFormattingUnitStyle style, double value, NSNumberFormatter *numbers)
{
    const RevenantUnitName *entry = revenant_unit_entry(dimension, system, unit);
    if (!entry)
        return revenant_unit_unknown_written(system, style, value);
    if (style == NSFormattingUnitStyleShort)
        return revenant_unit_written_short(dimension, system, unit);
    if (style == NSFormattingUnitStyleMedium)
        return [NSString stringWithUTF8String:entry->mediumName];
    if (unit == 1539 && system != RevenantUnitSystemUnitedStates)
        return [NSString stringWithUTF8String:entry->one];
    return [NSString stringWithUTF8String:revenant_unit_writes_one(value, numbers) ? entry->one : entry->other];
}

NSString *revenant_unit_unknown_name(NSFormattingUnitStyle style, double value)
{
    NSString *width = style == NSFormattingUnitStyleShort ? @"NARROW" : style == NSFormattingUnitStyleMedium ? @"SHORT" : @"WIDE";
    NSString *plural = fabs(value) == 1 ? @"ONE" : @"OTHER";
    return [NSString stringWithFormat:@"(null)_%@_%@_UNKNOWN", width, plural];
}

NSString *revenant_unit_unknown_written(RevenantUnitSystem system, NSFormattingUnitStyle style, double value)
{
    if (style == NSFormattingUnitStyleShort) {
        BOOL suffix = system == RevenantUnitSystemUnitedStates && fabs(value) != 1;
        return suffix ? @"Gs" : @"G";
    }
    if (style == NSFormattingUnitStyleMedium)
        return @"G";
    return @"g-force";
}

NSString *revenant_unit_name(NSString *dimension, RevenantUnitSystem system, NSInteger unit, NSFormattingUnitStyle style, double value)
{
    if (style == NSFormattingUnitStyleLong && [dimension isEqualToString:@"length"] && unit <= 14) {
        const RevenantUnitDimension *table = revenant_dimension(dimension, RevenantUnitSystemUnitedStates);
        for (NSUInteger index = 0; index < table->knownCount; index++)
            if (table->known[index].unit == unit)
                return [NSString stringWithUTF8String:fabs(value) == 1 ? table->known[index].one : table->known[index].other];
    }
    const RevenantUnitName *entry = revenant_unit_entry(dimension, system, unit);
    if (!entry)
        return revenant_unit_unknown_name(style, value);
    if (style == NSFormattingUnitStyleShort)
        return [NSString stringWithUTF8String:entry->shortName];
    if (style == NSFormattingUnitStyleMedium)
        return [NSString stringWithUTF8String:entry->mediumName];
    if (unit == 1539)
        return [NSString stringWithUTF8String:entry->one];
    return [NSString stringWithUTF8String:fabs(value) == 1 ? entry->one : entry->other];
}

NSString *revenant_unit_written_short(NSString *dimension, RevenantUnitSystem system, NSInteger unit)
{
    if ([dimension isEqualToString:@"mass"] && unit == 1538 && system == RevenantUnitSystemUnitedStates)
        return @"#";
    return revenant_unit_name(dimension, system, unit, NSFormattingUnitStyleShort, 2);
}

NSString *revenant_unit_food_name(NSInteger unit, NSFormattingUnitStyle style, double value, BOOL written,
                                 NSNumberFormatter *numbers)
{
    if (unit != 1794)
        return nil;
    if (style == NSFormattingUnitStyleShort)
        return written ? @"Cal" : @"C";
    if (style == NSFormattingUnitStyleMedium)
        return @"Cal";
    if (!written)
        return @"Calories";
    return revenant_unit_writes_one(value, numbers) ? @"Calorie" : @"Calories";
}

NSString *revenant_unit_number(double value, NSNumberFormatter *numbers)
{
    if (!numbers)
        return [NSString stringWithFormat:@"%g", value];
    NSNumberFormatter *plain = [numbers copy];
    plain.numberStyle = NSNumberFormatterDecimalStyle;
    NSString *decimal = [plain stringFromNumber:@(value)];
    switch (numbers.numberStyle) {
        case NSNumberFormatterCurrencyStyle: {
            NSNumberFormatter *mark = [numbers copy];
            mark.currencySymbol = @"\u00a4";
            return [mark stringFromNumber:@(value)];
        }
        case NSNumberFormatterPercentStyle:
            return [decimal stringByAppendingString:@"%"];
        case NSNumberFormatterScientificStyle:
        case NSNumberFormatterSpellOutStyle:
        case NSNumberFormatterOrdinalStyle: {
            NSNumberFormatter *mark = [numbers copy];
            mark.numberStyle = numbers.numberStyle;
            if (numbers.numberStyle != NSNumberFormatterOrdinalStyle)
                return [mark stringFromNumber:@(value)];
            NSNumberFormatter *grouped = [plain copy];
            grouped.usesGroupingSeparator = YES;
            NSString *number = [grouped stringFromNumber:@(nearbyint(value))];
            NSString *whole = [grouped stringFromNumber:@((double)(long long)value)];
            NSString *marked = [[mark stringFromNumber:@((double)(long long)value)]
                stringByReplacingOccurrencesOfString:@"\u2212" withString:@"-"];
            NSString *suffix = @"";
            if ([marked hasPrefix:whole])
                suffix = [marked substringFromIndex:whole.length];
            return [number stringByAppendingString:suffix];
        }
        default:
            return decimal;
    }
}

BOOL revenant_unit_joins_with_space(NSFormattingUnitStyle style)
{
    return style != NSFormattingUnitStyleShort;
}

static NSString *revenant_unit_pair(NSString *first, NSString *firstName, NSString *second, NSString *secondName, NSFormattingUnitStyle style)
{
    NSString *joined = revenant_unit_joins_with_space(style) ? [NSString stringWithFormat:@"%@ %@", first, firstName]
                                                          : [NSString stringWithFormat:@"%@%@", first, firstName];
    NSString *between = revenant_unit_joins_with_space(style) ? @", " : @" ";
    NSString *rest = revenant_unit_joins_with_space(style) ? [NSString stringWithFormat:@"%@ %@", second, secondName]
                                                         : [NSString stringWithFormat:@"%@%@", second, secondName];
    return [NSString stringWithFormat:@"%@%@%@", joined, between, rest];
}

NSString *revenant_unit_given(NSString *dimension, RevenantUnitSystem system, double inUnit, NSInteger unit,
                            NSFormattingUnitStyle style, NSNumberFormatter *numbers)
{
    NSString *name = revenant_unit_entry(dimension, system, unit)
                         ? revenant_unit_written_name(dimension, system, unit, style, inUnit, numbers)
                         : revenant_unit_unknown_written(system, style, inUnit);
    if (!name)
        return nil;
    NSString *number = revenant_unit_number(inUnit, numbers);
    return revenant_unit_joins_with_space(style) ? [NSString stringWithFormat:@"%@ %@", number, name]
                                               : [NSString stringWithFormat:@"%@%@", number, name];
}

NSString *revenant_unit_string(NSString *dimension, RevenantUnitSystem system, double base, NSInteger unit,
                             NSFormattingUnitStyle style, NSNumberFormatter *numbers)
{
    double inUnit = base * revenant_unit_factor(dimension, system, unit);
    NSString *name = revenant_unit_entry(dimension, system, unit)
                         ? revenant_unit_written_name(dimension, system, unit, style, inUnit, numbers)
                         : revenant_unit_unknown_written(system, style, inUnit);
    if (!name)
        return nil;
    NSString *number = revenant_unit_number(inUnit, numbers);
    return revenant_unit_joins_with_space(style) ? [NSString stringWithFormat:@"%@ %@", number, name]
                                               : [NSString stringWithFormat:@"%@%@", number, name];
}

NSString *revenant_unit_stone(RevenantUnitSystem system, double stones, NSFormattingUnitStyle style, NSNumberFormatter *numbers)
{
    if (stones < 0) {
        return revenant_unit_given(@"mass", system, stones, 1539, style, numbers);
    }
    double whole = floor(stones);
    double pounds = (stones - whole) * 14;
    if (pounds == 0)
        return revenant_unit_given(@"mass", system, stones, 1539, style, numbers);
    return revenant_unit_pair(revenant_unit_number(whole, numbers),
                            revenant_unit_written_name(@"mass", system, 1539, style, whole, numbers),
                            revenant_unit_number(pounds, numbers),
                            revenant_unit_written_name(@"mass", system, 1538, style, pounds, numbers), style);
}

NSString *revenant_unit_person_height(RevenantUnitSystem system, double metres, NSFormattingUnitStyle style, NSNumberFormatter *numbers)
{
    if (system != RevenantUnitSystemUnitedStates) {
        return revenant_unit_given(@"length", system, metres * 100, 9, style, numbers);
    }
    double inFeet = metres * revenant_unit_factor(@"length", system, 1282);
    double whole = floor(inFeet);
    double inches = (inFeet - whole) * 12;
    return revenant_unit_pair(revenant_unit_number(whole, numbers),
                            revenant_unit_written_name(@"length", system, 1282, style, whole, numbers),
                            [numbers stringFromNumber:@(inches)],
                            revenant_unit_written_name(@"length", system, 1281, style, inches, numbers), style);
}

NSString *revenant_unit_written(NSString *dimension, RevenantUnitSystem system, BOOL person, double base, NSInteger unit,
                              NSFormattingUnitStyle style, NSNumberFormatter *numbers)
{
    if (person && [dimension isEqualToString:@"length"])
        return revenant_unit_person_height(system, base, style, numbers);
    (void)person;
    if ([dimension isEqualToString:@"mass"] && unit == 1539)
        return revenant_unit_stone(system, base, style, numbers);
    return revenant_unit_string(dimension, system, base, unit, style, numbers);
}
