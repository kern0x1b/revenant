#import <Foundation/Foundation.h>

/* The three measurement formatters of iOS 8.0 - NSLengthFormatter, NSMassFormatter and
   NSEnergyFormatter - are one machine with three sets of numbers, so what they share lives here:
   the names of a unit in the three unit styles, the figure the system converts with, which unit it
   writes a value in, the two forms it writes a stone and a person's height in, and the writing of
   the two together.

   Every number and every name in CharonUnitFormat.m is measured, not taken from the CLDR: the
   system itself is asked, through tests/backports/host/unitformat, which puts the port and the
   system in one process over the same inputs. What the release cannot be asked is its own, because
   the CLDR table its unit names come from arrived in the ICU of iOS 8.0 and every release the port
   carries is below it - measured over the whole cache ladder and written down in
   facts/Foundation/NSUnitFormat.md. What the port does ask of the release is real: the number is
   written through the release's own NSNumberFormatter, so the digits, the grouping and the decimal
   mark are the locale's, and the system of units is read from the release's own locale under
   NSLocaleMeasurementSystem, which answers "U.S.", "U.K." or "Metric". */

/* The three answers NSLocaleMeasurementSystem gives, read from the release's own locale, which has
   carried the key since before iOS 5. NSLocale's own -usesMetricSystem is iOS 10. */
typedef NS_ENUM(NSInteger, CharonUnitSystem) {
    CharonUnitSystemUnitedStates,
    CharonUnitSystemUnitedKingdom,
    CharonUnitSystemMetric
};

typedef struct {
    NSInteger unit;         /* the NSxxxFormatterUnit value the SDK gives the unit */
    const char *shortName;  /* NSFormattingUnitStyleShort */
    const char *mediumName; /* NSFormattingUnitStyleMedium */
    const char *one;        /* NSFormattingUnitStyleLong, singular */
    const char *other;      /* NSFormattingUnitStyleLong, plural */
} CharonUnitName;

/* One step of the choice the system makes for a value: the unit it writes, the smallest base value
   it writes it from, and the figure it converts with. A threshold below zero is the unit every
   smaller value falls back to, which is the smallest of the table. */
typedef struct {
    NSInteger unit;
    double threshold;
    double factor;
} CharonUnitChoice;

typedef struct {
    const CharonUnitName *known;
    NSUInteger knownCount;
    const CharonUnitChoice *choices; /* largest unit first, the fallback last */
    NSUInteger choiceCount;
    NSInteger zero;                  /* the unit a value of exactly zero is written in */
    NSInteger negative;              /* the unit any value below zero is written in */
} CharonUnitDimension;

CharonUnitSystem charon_unit_system(NSLocale *locale);

/* The figure one base unit - a metre, a kilogram, a joule - counts in the unit, which is the
   system's own and not the exact factor of the unit: it writes a yard in 1.0936 of a metre, so
   the switch from feet to yards is at 1/1.0936 metres and not at 0.9144. */
double charon_unit_factor(NSString *dimension, CharonUnitSystem system, NSInteger unit);

/* The unit a value of this base is written in, and that value. `person` selects the table the
   forPersonHeightUse property asks for: a person's height is feet and inches in the U.S. and the
   U.K. and centimetres anywhere metric. */
NSInteger charon_unit_chosen(NSString *dimension, CharonUnitSystem system, BOOL person, double base, double *chosen);

/* The name of a unit the dimension does not have, which is the key the system's own lookup comes back
   with: "(null)_WIDE_OTHER_UNKNOWN" and its five siblings, one for each width and the plural. */
NSString *charon_unit_unknown_name(NSFormattingUnitStyle style, double value);

/* And the name it writes beside a value with one: the gram-force, "G", "Gs", " G" or " g-force". */
NSString *charon_unit_unknown_written(CharonUnitSystem system, NSFormattingUnitStyle style, double value);

/* The name of one unit in one style, which is what -unitStringFromValue:unit: answers: the long
   style is plural on the value, one the singular and zero, a fraction and a negative the plural,
   except for the stone, whose name is always the singular. Answers nil for a unit the dimension
   does not have, which is how an NSxxxFormatterUnit value outside the enumeration is answered. */

/* The name as a value and a name are written together, which is the long style's plural on the
   number the number formatter writes rather than on the value itself, and the short style's
   written symbol. */
NSString *charon_unit_name(NSString *dimension, CharonUnitSystem system, NSInteger unit, NSFormattingUnitStyle style, double value);

/* The short name as a value and a name are written together, which is the symbol for every unit
   except the U.S. pound, which is written "#". */
NSString *charon_unit_written_short(NSString *dimension, CharonUnitSystem system, NSInteger unit);

/* The name a forXxxUse property changes: a kilocalorie of food energy is "C" as a name and "Cal"
   as a written value, where it is "kcal" and "kcal" otherwise. */
NSString *charon_unit_food_name(NSInteger unit, NSFormattingUnitStyle style, double value, BOOL written,
                                 NSNumberFormatter *numbers);

/* The number as the system writes it: the value as a plain decimal with the caller's own digits,
   grouping and sign, and then the mark of the caller's number style. The caller's formatter is not
   the one the value goes through, which is the one measured way it is not taken from the caller. */
NSString *charon_unit_number(double value, NSNumberFormatter *numbers);

/* Whether the system writes the number and the name with a space between them. The short style does
   not; the two forms that write two units - a stone, a person's height - separate them with a
   space in the short style and with a comma and a space in the other two. */
BOOL charon_unit_joins_with_space(NSFormattingUnitStyle style);

/* The written form of a value that is already counted in the unit, which is what
   -stringFromValue:unit: is given: it never rescales the value it is handed. */
NSString *charon_unit_given(NSString *dimension, CharonUnitSystem system, double inUnit, NSInteger unit,
                            NSFormattingUnitStyle style, NSNumberFormatter *numbers);

/* The written form of a value in a unit, rescaled out of the base unit. */
NSString *charon_unit_string(NSString *dimension, CharonUnitSystem system, double base, NSInteger unit,
                             NSFormattingUnitStyle style, NSNumberFormatter *numbers);

/* The written form of a stone: the whole stones and, where the value is not a whole number of them
   and is not below zero, the pounds over fourteen. The U.K. and the metric write a stone this way
   too; below zero the system writes the value in stones and nothing else. */
NSString *charon_unit_stone(CharonUnitSystem system, double stones, NSFormattingUnitStyle style, NSNumberFormatter *numbers);

/* The written form of a person's height in the U.S. and the U.K.: the feet, the whole number of
   them rounded towards minus infinity so that a height below zero carries the sign on the feet, and
   the inches over twelve. The metric writes a person's height in centimetres, at any height, which
 * is the ordinary written form of the centimetre. */
NSString *charon_unit_person_height(CharonUnitSystem system, double metres, NSFormattingUnitStyle style, NSNumberFormatter *numbers);

/* The written form of any value, which is a stone and a person's height in the two forms above and
   a single unit in every other case. */
NSString *charon_unit_written(NSString *dimension, CharonUnitSystem system, BOOL person, double base, NSInteger unit,
                              NSFormattingUnitStyle style, NSNumberFormatter *numbers);
