#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, CharonUnitSystem) {
    CharonUnitSystemUnitedStates,
    CharonUnitSystemUnitedKingdom,
    CharonUnitSystemMetric
};

typedef struct {
    NSInteger unit;
    const char *shortName;
    const char *mediumName;
    const char *one;
    const char *other;
} CharonUnitName;

typedef struct {
    NSInteger unit;
    double threshold;
    double factor;
} CharonUnitChoice;

typedef struct {
    const CharonUnitName *known;
    NSUInteger knownCount;
    const CharonUnitChoice *choices;
    NSUInteger choiceCount;
    NSInteger zero;
    NSInteger negative;
} CharonUnitDimension;

CharonUnitSystem charon_unit_system(NSLocale *locale);

double charon_unit_factor(NSString *dimension, CharonUnitSystem system, NSInteger unit);

NSInteger charon_unit_chosen(NSString *dimension, CharonUnitSystem system, BOOL person, double base, double *chosen);

NSString *charon_unit_unknown_name(NSFormattingUnitStyle style, double value);

NSString *charon_unit_unknown_written(CharonUnitSystem system, NSFormattingUnitStyle style, double value);

NSString *charon_unit_name(NSString *dimension, CharonUnitSystem system, NSInteger unit, NSFormattingUnitStyle style, double value);

NSString *charon_unit_written_short(NSString *dimension, CharonUnitSystem system, NSInteger unit);

NSString *charon_unit_food_name(NSInteger unit, NSFormattingUnitStyle style, double value, BOOL written,
                                 NSNumberFormatter *numbers);

NSString *charon_unit_number(double value, NSNumberFormatter *numbers);

BOOL charon_unit_joins_with_space(NSFormattingUnitStyle style);

NSString *charon_unit_given(NSString *dimension, CharonUnitSystem system, double inUnit, NSInteger unit,
                            NSFormattingUnitStyle style, NSNumberFormatter *numbers);

NSString *charon_unit_string(NSString *dimension, CharonUnitSystem system, double base, NSInteger unit,
                             NSFormattingUnitStyle style, NSNumberFormatter *numbers);

NSString *charon_unit_stone(CharonUnitSystem system, double stones, NSFormattingUnitStyle style, NSNumberFormatter *numbers);

NSString *charon_unit_person_height(CharonUnitSystem system, double metres, NSFormattingUnitStyle style, NSNumberFormatter *numbers);

NSString *charon_unit_written(NSString *dimension, CharonUnitSystem system, BOOL person, double base, NSInteger unit,
                              NSFormattingUnitStyle style, NSNumberFormatter *numbers);
