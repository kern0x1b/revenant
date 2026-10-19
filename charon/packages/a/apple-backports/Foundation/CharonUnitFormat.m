#import <Foundation/Foundation.h>
#include <math.h>

#import "CharonUnitFormat.h"

/* Every figure below is measured from the host's own Foundation by tests/backports/host/unitformat,
   which runs the system and the port in one process and compares two answers for one input. The
   factors are the system's own and not the exact factors of the units: it writes a yard in 1.0936
   of a metre, a foot in 3.28084 and a mile in 0.00062137, and the thresholds are the reciprocals of
   those figures to the last bit, each one found by bisecting the value the system switches at. The
   names are the system's English ones. The CLDR table they come from arrived in the ICU of iOS 8.0
   (icudt57) and no release below iOS 8.0 carries it, which is measured over the whole cache ladder
   in facts/Foundation/NSUnitFormat.md, so the release cannot be asked for the name of a unit in a
   language of its own. */

static const CharonUnitName charon_length_names[] = {
    {8, "mm", "mm", "millimeter", "millimeters"},
    {9, "cm", "cm", "centimeter", "centimeters"},
    {11, "m", "m", "meter", "meters"},
    {14, "km", "km", "kilometer", "kilometers"},
    {1281, "\u2033", "in", "inch", "inches"},
    {1282, "\u2032", "ft", "foot", "feet"},
    {1283, "yd", "yd", "yard", "yards"},
    {1284, "mi", "mi", "mile", "miles"},
};

/* The four length units the U.K. and the metric spell with a "metre", where the U.S. spells them with a
   "meter" (measured: en_US writes "millimeters", "centimeters" and "meters", and en_GB, en_AU and
   en_001 - the U.K. and the metric - write "millimetres", "centimetres" and "metres"). The symbol and
   the medium name are the same in both, so only the long style differs. */
static const CharonUnitName charon_length_names_metre[] = {
    {8, "mm", "mm", "millimetre", "millimetres"},
    {9, "cm", "cm", "centimetre", "centimetres"},
    {11, "m", "m", "metre", "metres"},
    {14, "km", "km", "kilometre", "kilometres"},
    {1281, "\u2033", "in", "inch", "inches"},
    {1282, "\u2032", "ft", "foot", "feet"},
    {1283, "yd", "yd", "yard", "yards"},
    {1284, "mi", "mi", "mile", "miles"},
};

static const CharonUnitName charon_mass_names[] = {
    {11, "g", "g", "gram", "grams"},
    {14, "kg", "kg", "kilogram", "kilograms"},
    {1537, "oz", "oz", "ounce", "ounces"},
    {1538, "lb", "lb", "pound", "pounds"},
    {1539, "st", "st", "stone", "stones"},
};

static const CharonUnitName charon_energy_names[] = {
    {11, "J", "J", "joule", "joules"},
    {14, "kJ", "kJ", "kilojoule", "kilojoules"},
    {1793, "cal", "cal", "calorie", "calories"},
    {1794, "kcal", "kcal", "kilocalorie", "kilocalories"},
};

/* The unit a value is written in, largest first, the smallest last as the fallback every value that
   reaches no one falls back to. The threshold of a unit is the smallest value of the base the
   system writes it from; the fallback's is below every value. Zero and the values below zero are
   the system's own answers, measured over ten decades in both directions: zero is the largest unit
   of a mass and of an energy and the smallest of a metric length but the yard of a U.S. one, and a
   value below zero is the largest unit of every table. */
static const CharonUnitChoice charon_length_us[] = {
    {1284, 1609.3470878864448, 0.00062137},
    {1283, 0.91441111923921015, 1.0936},
    {1282, 0.30479999024640036, 3.28084},
    {1281, -1, 39.3701},
};

static const CharonUnitChoice charon_length_metric[] = {
    {14, 1000.0000000000001, 0.001},
    {11, 1.0000000000000002, 1},
    {9, 0.010000000000000002, 100},
    {8, -1, 1000},
};

/* A metric table switches strictly above its threshold and a U.S. one at it, so a threshold of a
   table that switches above is stored one double past the value the system switches at: a metre is
   written "1,000 mm" and a thousand joules "1,000 J", where a foot at its own threshold is written
   "1 foot". The U.S. kilocalorie is the one U.S. threshold above its value, 4184 joules being
   exactly one kilocalorie and the system still writing "1,000 cal". */
static const CharonUnitChoice charon_energy_us[] = {
    {1794, 4184.0000000000009, 1.0 / 4184.0},
    {1793, -1, 1.0 / 4.184},
};

static const CharonUnitChoice charon_energy_metric[] = {
    {14, 1000.0000000000001, 0.001},
    {11, -1, 1},
};

static const CharonUnitChoice charon_mass_us[] = {
    {1538, 0.4535923700100355, 2.2046226218},
    {1537, -1, 35.2739619},
};

/* The U.K. writes a mass in grams and kilograms, and so does the metric; the two tables of a mass
   differ in nothing at all, measured over ten decades in both directions. */
static const CharonUnitChoice charon_mass_metric[] = {
    {14, 1.0000000000000002, 1},
    {11, -1, 1000},
};

static const CharonUnitDimension charon_length_us_dimension = {charon_length_names, 8, charon_length_us, 4, 1283, 1284};
static const CharonUnitDimension charon_length_metric_dimension = {charon_length_names_metre, 8, charon_length_metric, 4, 8, 14};
static const CharonUnitDimension charon_mass_us_dimension = {charon_mass_names, 5, charon_mass_us, 2, 1538, 1538};
static const CharonUnitDimension charon_mass_metric_dimension = {charon_mass_names, 5, charon_mass_metric, 2, 14, 14};
static const CharonUnitDimension charon_energy_us_dimension = {charon_energy_names, 4, charon_energy_us, 2, 1794, 1794};
static const CharonUnitDimension charon_energy_metric_dimension = {charon_energy_names, 4, charon_energy_metric, 2, 14, 14};

static const CharonUnitDimension *charon_dimension(NSString *dimension, CharonUnitSystem system)
{
    BOOL us = system == CharonUnitSystemUnitedStates;
    if ([dimension isEqualToString:@"length"])
        return us ? &charon_length_us_dimension : &charon_length_metric_dimension;
    if ([dimension isEqualToString:@"mass"])
        return us ? &charon_mass_us_dimension : &charon_mass_metric_dimension;
    return us ? &charon_energy_us_dimension : &charon_energy_metric_dimension;
}

static const CharonUnitName *charon_unit_entry(NSString *dimension, CharonUnitSystem system, NSInteger unit)
{
    const CharonUnitDimension *table = charon_dimension(dimension, system);
    for (NSUInteger index = 0; index < table->knownCount; index++)
        if (table->known[index].unit == unit)
            return &table->known[index];
    return NULL;
}

CharonUnitSystem charon_unit_system(NSLocale *locale)
{
    NSString *system = [[locale objectForKey:NSLocaleMeasurementSystem] description];
    if ([system isEqualToString:@"U.S."])
        return CharonUnitSystemUnitedStates;
    if ([system isEqualToString:@"U.K."])
        return CharonUnitSystemUnitedKingdom;
    return CharonUnitSystemMetric;
}

double charon_unit_factor(NSString *dimension, CharonUnitSystem system, NSInteger unit)
{
    const CharonUnitDimension *table = charon_dimension(dimension, system);
    for (NSUInteger index = 0; index < table->choiceCount; index++)
        if (table->choices[index].unit == unit)
            return table->choices[index].factor;
    return 0;
}

NSInteger charon_unit_chosen(NSString *dimension, CharonUnitSystem system, BOOL person, double base, double *chosen)
{
    const CharonUnitDimension *table = charon_dimension(dimension, system);

    /* A person's height is written in feet and inches in the U.S. and the U.K., where the unit the
       formatter reports is the foot whatever the height, and in centimetres anywhere metric, where
       it is the centimetre. The other two properties name a use the system writes no differently
       for the unit: measured over ten decades in both directions, a person's mass and a food energy
       are written in the units any other mass and any other energy are. */
    if (person && [dimension isEqualToString:@"length"]) {
        NSInteger unit = system == CharonUnitSystemMetric ? 9 : 1282; /* the U.K. reports the foot too */
        if (chosen)
            *chosen = base * charon_unit_factor(dimension, system, unit);
        return unit;
    }
    if (base == 0 || base < 0) {
        NSInteger unit = base == 0 ? table->zero : table->negative;
        if (chosen)
            *chosen = base * charon_unit_factor(dimension, system, unit);
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

/* Whether the formatter writes this value as one. The plural is decided on the number that is
   written, not on the value itself: 0.3048 metres is 1.000000032 feet and the system writes
   "1 foot", while 0.0254 metres is 1.000001 inches and it writes "1.000001 inches". So the value
   is rounded to the digits the number formatter keeps before it is compared with one. */
static BOOL charon_unit_writes_one(double value, NSNumberFormatter *numbers)
{
    if (!numbers)
        return fabs(value) == 1;
    NSUInteger digits = numbers.maximumFractionDigits;
    if (digits > 17)
        digits = 17;
    double scale = pow(10.0, (double)digits);
    /* Away from zero at the last digit the formatter keeps, which is the mode it writes in unless
       the caller changed it, and the comparison is then on the number that is written. */
    double rounded = (value < 0 ? -floor(-value * scale + 0.5) : floor(value * scale + 0.5)) / scale;
    return rounded == 1 || rounded == -1;
}

/* The name of a unit as the system writes it beside a number, which is the long style's plural on
   the written number. */
NSString *charon_unit_written_name(NSString *dimension, CharonUnitSystem system, NSInteger unit,
                                   NSFormattingUnitStyle style, double value, NSNumberFormatter *numbers)
{
    const CharonUnitName *entry = charon_unit_entry(dimension, system, unit);
    if (!entry)
        return charon_unit_unknown_written(system, style, value);
    if (style == NSFormattingUnitStyleShort)
        return charon_unit_written_short(dimension, system, unit);
    if (style == NSFormattingUnitStyleMedium)
        return [NSString stringWithUTF8String:entry->mediumName];
    /* The stone is the one unit whose written plural the U.S. has and the U.K. and the metric do
       not: the U.S. writes "0 stones" and they write "0 stone". */
    if (unit == 1539 && system != CharonUnitSystemUnitedStates)
        return [NSString stringWithUTF8String:entry->one];
    return [NSString stringWithUTF8String:charon_unit_writes_one(value, numbers) ? entry->one : entry->other];
}

/* What the system answers for a unit that is not one. A unit value outside the enumeration is a
   programming error and the system's own name lookup for it comes back unresolved, and the system
   writes the key of that lookup out rather than refusing (measured, in English, and the same shape in
   every locale with the plural category the locale's own rules give it):

   | style | one | any other value |
   | --- | --- | --- |
   | short | `(null)_NARROW_ONE_UNKNOWN` | `(null)_NARROW_OTHER_UNKNOWN` |
   | medium | `(null)_SHORT_ONE_UNKNOWN` | `(null)_SHORT_OTHER_UNKNOWN` |
   | long | `(null)_WIDE_ONE_UNKNOWN` | `(null)_WIDE_OTHER_UNKNOWN` |

   and a value written with one is written with the name of the gram-force - "0Gs", "1G", "-1G" in the
   short style where the suffix is there for every value but one, "0 G" in the medium and "0 g-force"
   in the long. The key and the fallback are reproduced; in a locale that writes its own names the
   system answers that locale's instead, which is the limit named in facts/Foundation/NSUnitFormat.md. */
NSString *charon_unit_unknown_name(NSFormattingUnitStyle style, double value)
{
    NSString *width = style == NSFormattingUnitStyleShort ? @"NARROW" : style == NSFormattingUnitStyleMedium ? @"SHORT" : @"WIDE";
    NSString *plural = fabs(value) == 1 ? @"ONE" : @"OTHER";
    return [NSString stringWithFormat:@"(null)_%@_%@_UNKNOWN", width, plural];
}

NSString *charon_unit_unknown_written(CharonUnitSystem system, NSFormattingUnitStyle style, double value)
{
    if (style == NSFormattingUnitStyleShort) {
        /* The plural suffix of the narrow form is the locale's own plural data and not the port's:
           en_US writes "0Gs" and en_CA with it, and en_GB, en_AU, en_001 and de_DE write "0G". The
           U.S. form is carried and the rest is named in facts/Foundation/NSUnitFormat.md. */
        BOOL suffix = system == CharonUnitSystemUnitedStates && fabs(value) != 1;
        return suffix ? @"Gs" : @"G";
    }
    if (style == NSFormattingUnitStyleMedium)
        return @"G";
    return @"g-force";
}

NSString *charon_unit_name(NSString *dimension, CharonUnitSystem system, NSInteger unit, NSFormattingUnitStyle style, double value)
{
    /* A name on its own is the American spelling of a length unit in every locale, and the written
       form is the locale's own: en_GB answers "millimeters" here and writes "0 millimetres". The
       symbol and the medium name are the same either way, so the table asked for is the one of the
       system below only for the long style of a written form. */
    if (style == NSFormattingUnitStyleLong && [dimension isEqualToString:@"length"] && unit <= 14) {
        const CharonUnitDimension *table = charon_dimension(dimension, CharonUnitSystemUnitedStates);
        for (NSUInteger index = 0; index < table->knownCount; index++)
            if (table->known[index].unit == unit)
                return [NSString stringWithUTF8String:fabs(value) == 1 ? table->known[index].one : table->known[index].other];
    }
    const CharonUnitName *entry = charon_unit_entry(dimension, system, unit);
    if (!entry)
        return charon_unit_unknown_name(style, value);
    if (style == NSFormattingUnitStyleShort)
        return [NSString stringWithUTF8String:entry->shortName];
    if (style == NSFormattingUnitStyleMedium)
        return [NSString stringWithUTF8String:entry->mediumName];
    /* The long style is the only one with a plural, and it takes it on the value: one is the
       singular and everything else - zero, a fraction, a negative - the plural. The stone is the
       one unit whose name has no plural at all: the system answers "stone" for one and for two. */
    if (unit == 1539)
        return [NSString stringWithUTF8String:entry->one];
    return [NSString stringWithUTF8String:fabs(value) == 1 ? entry->one : entry->other];
}

NSString *charon_unit_written_short(NSString *dimension, CharonUnitSystem system, NSInteger unit)
{
    /* The one short name that is not the symbol: a value and a pound written together in the U.S.
       are "# lb", and the U.K. and the metric write "1 lb". */
    if ([dimension isEqualToString:@"mass"] && unit == 1538 && system == CharonUnitSystemUnitedStates)
        return @"#";
    return charon_unit_name(dimension, system, unit, NSFormattingUnitStyleShort, 2);
}

NSString *charon_unit_food_name(NSInteger unit, NSFormattingUnitStyle style, double value, BOOL written,
                                 NSNumberFormatter *numbers)
{
    if (unit != 1794)
        return nil;
    if (style == NSFormattingUnitStyleShort)
        return written ? @"Cal" : @"C";
    if (style == NSFormattingUnitStyleMedium)
        return @"Cal";
    /* A name on its own is always the plural, "Calories"; a value written beside a name is singular
       for one, "1 Calorie", and the plural for every other value. */
    if (!written)
        return @"Calories";
    return charon_unit_writes_one(value, numbers) ? @"Calorie" : @"Calories";
}

/* The number the system writes, which is not the caller's formatter applied to the value: it is the
   value written as a plain decimal with the caller's own digits, grouping and sign, and then the mark
   of the caller's number style put on that. Measured over every style the header names, with the
   caller asking for five fraction digits and no grouping:

   | style | the formatter alone, on 1350.0492 | through the formatter |
   | --- | --- | --- |
   | none, decimal | `1350.0492` | `1350.0492yd` |
   | currency | `$1,350.05` | `\u00a41350.0492yd` |
   | percent | `135004.92000%` | `1350.0492%yd` |
   | scientific | `1.35005E3` | `1.35005E3yd` |
   | spell out | `one thousand three hundred fifty point zero four nine two` | the same, spelled |
   | ordinal | `1,350th` | `1,350thyd` |

   So the decimal is the system's own and the mark is the style's, and the percent style does not
   multiply by a hundred and the currency style writes the generic sign "\u00a4" and not the symbol
   the caller's code carries. The spell-out, ordinal and scientific forms are the release's own
   transformations of the decimal text, which is why they are asked of a copy of the caller's own
   number formatter rather than assembled here. The caller never sees its formatter changed. */
NSString *charon_unit_number(double value, NSNumberFormatter *numbers)
{
    if (!numbers)
        return [NSString stringWithFormat:@"%g", value];
    NSNumberFormatter *plain = [numbers copy];
    plain.numberStyle = NSNumberFormatterDecimalStyle;
    NSString *decimal = [plain stringFromNumber:@(value)];
    switch (numbers.numberStyle) {
        case NSNumberFormatterCurrencyStyle: {
            /* The generic sign takes the place the currency's own would, which is inside the pattern,
               so a pattern that carries no currency is written with no sign at all and a negative one
               is "-<sign>0.77" where the currency's own would be "-$0.77". The copy keeps the
               caller's digits and grouping, which is why the value is not the two digits a currency
               formatter asks for. */
            NSNumberFormatter *mark = [numbers copy];
            mark.currencySymbol = @"\u00a4";
            return [mark stringFromNumber:@(value)];
        }
        case NSNumberFormatterPercentStyle:
            return [decimal stringByAppendingString:@"%"];
        case NSNumberFormatterScientificStyle:
        case NSNumberFormatterSpellOutStyle:
        case NSNumberFormatterOrdinalStyle: {
            /* These three are the release's own transformations, asked of a copy of the caller's own
               formatter so the digits are the caller's: the value at full precision for the
               scientific and the spelled form (0.0393701 metres is "zero point zero three nine three
               seven zero one", every digit of it and not the five the caller keeps) and the value
               rounded for the ordinal, which carries no fraction at all. */
            NSNumberFormatter *mark = [numbers copy];
            mark.numberStyle = numbers.numberStyle;
            if (numbers.numberStyle != NSNumberFormatterOrdinalStyle)
                return [mark stringFromNumber:@(value)];
            /* The number and the suffix are two different numbers: the number is the value rounded to
               the even one where it is a half (2.5 metres is "2nd m" and 1.5 is "2st m"), and the
               suffix is the one of the value cut off at the point (1.64 feet is "2st", 3.83 is "4rd",
               1234.5 metres is "1,350th" and a million is "621st"). */
            /* The number of an ordinal is grouped whatever the caller asked for (1,094rd where a
               decimal of the same value is 1094), and the suffix is what the release's own ordinal
               leaves after the number it puts to the value cut off at the point - the sign of which is
               the ordinal's own, U+2212, and not the decimal's. */
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

BOOL charon_unit_joins_with_space(NSFormattingUnitStyle style)
{
    return style != NSFormattingUnitStyleShort;
}

static NSString *charon_unit_pair(NSString *first, NSString *firstName, NSString *second, NSString *secondName, NSFormattingUnitStyle style)
{
    NSString *joined = charon_unit_joins_with_space(style) ? [NSString stringWithFormat:@"%@ %@", first, firstName]
                                                          : [NSString stringWithFormat:@"%@%@", first, firstName];
    /* Two units are separated by a space in the short style and by a comma and a space in the
       other two: "0' 0"", "0 ft, 0 in", "0 stones, 7 pounds". */
    NSString *between = charon_unit_joins_with_space(style) ? @", " : @" ";
    NSString *rest = charon_unit_joins_with_space(style) ? [NSString stringWithFormat:@"%@ %@", second, secondName]
                                                         : [NSString stringWithFormat:@"%@%@", second, secondName];
    return [NSString stringWithFormat:@"%@%@%@", joined, between, rest];
}

/* The written form of a value that is already counted in the unit: -stringFromValue:unit: is given
   a number of that unit and writes it as it stands, without rescaling it. */
NSString *charon_unit_given(NSString *dimension, CharonUnitSystem system, double inUnit, NSInteger unit,
                            NSFormattingUnitStyle style, NSNumberFormatter *numbers)
{
    NSString *name = charon_unit_entry(dimension, system, unit)
                         ? charon_unit_written_name(dimension, system, unit, style, inUnit, numbers)
                         : charon_unit_unknown_written(system, style, inUnit);
    if (!name)
        return nil;
    NSString *number = charon_unit_number(inUnit, numbers);
    return charon_unit_joins_with_space(style) ? [NSString stringWithFormat:@"%@ %@", number, name]
                                               : [NSString stringWithFormat:@"%@%@", number, name];
}

NSString *charon_unit_string(NSString *dimension, CharonUnitSystem system, double base, NSInteger unit,
                             NSFormattingUnitStyle style, NSNumberFormatter *numbers)
{
    double inUnit = base * charon_unit_factor(dimension, system, unit);
    NSString *name = charon_unit_entry(dimension, system, unit)
                         ? charon_unit_written_name(dimension, system, unit, style, inUnit, numbers)
                         : charon_unit_unknown_written(system, style, inUnit);
    if (!name)
        return nil;
    NSString *number = charon_unit_number(inUnit, numbers);
    return charon_unit_joins_with_space(style) ? [NSString stringWithFormat:@"%@ %@", number, name]
                                               : [NSString stringWithFormat:@"%@%@", number, name];
}

NSString *charon_unit_stone(CharonUnitSystem system, double stones, NSFormattingUnitStyle style, NSNumberFormatter *numbers)
{
    if (stones < 0) {
        /* Below zero the system writes the value in stones and nothing else. */
        return charon_unit_given(@"mass", system, stones, 1539, style, numbers);
    }
    double whole = floor(stones);
    double pounds = (stones - whole) * 14;
    if (pounds == 0)
        return charon_unit_given(@"mass", system, stones, 1539, style, numbers);
    return charon_unit_pair(charon_unit_number(whole, numbers),
                            charon_unit_written_name(@"mass", system, 1539, style, whole, numbers),
                            charon_unit_number(pounds, numbers),
                            charon_unit_written_name(@"mass", system, 1538, style, pounds, numbers), style);
}

NSString *charon_unit_person_height(CharonUnitSystem system, double metres, NSFormattingUnitStyle style, NSNumberFormatter *numbers)
{
    /* The U.K. writes a person's height in centimetres as the metric does, and answers the foot to
       -unitStringFromMeters:usedUnit: and to the name beside it either way (measured for en_GB at every
       style and every height), so the two-unit form is the U.S.'s alone. */
    if (system != CharonUnitSystemUnitedStates) {
        /* The centimetre, at any height: the system neither steps down to the millimetre nor up to
           the metre for a person, and a hundredth of a metre is one. */
        return charon_unit_given(@"length", system, metres * 100, 9, style, numbers);
    }
    /* The feet are the whole number of them, rounded towards minus infinity, so a height below zero
       carries the sign on the feet and the inches over twelve are the rest of it: a metre below zero
       is "-4 ft, 8.63 in" and not "-3 ft, 3.37 in". The factor is the system's own, the one its own
       foot threshold is the reciprocal of. */
    double inFeet = metres * charon_unit_factor(@"length", system, 1282);
    double whole = floor(inFeet);
    double inches = (inFeet - whole) * 12;
    return charon_unit_pair(charon_unit_number(whole, numbers),
                            charon_unit_written_name(@"length", system, 1282, style, whole, numbers),
                            [numbers stringFromNumber:@(inches)],
                            charon_unit_written_name(@"length", system, 1281, style, inches, numbers), style);
}

NSString *charon_unit_written(NSString *dimension, CharonUnitSystem system, BOOL person, double base, NSInteger unit,
                              NSFormattingUnitStyle style, NSNumberFormatter *numbers)
{
    if (person && [dimension isEqualToString:@"length"])
        return charon_unit_person_height(system, base, style, numbers);
    (void)person;
    if ([dimension isEqualToString:@"mass"] && unit == 1539)
        return charon_unit_stone(system, base, style, numbers);
    return charon_unit_string(dimension, system, base, unit, style, numbers);
}
