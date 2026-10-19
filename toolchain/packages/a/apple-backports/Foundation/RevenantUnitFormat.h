#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, RevenantUnitSystem) {
    RevenantUnitSystemUnitedStates,
    RevenantUnitSystemUnitedKingdom,
    RevenantUnitSystemMetric
};

typedef struct {
    NSInteger unit;
    const char *shortName;
    const char *mediumName;
    const char *one;
    const char *other;
} RevenantUnitName;

typedef struct {
    NSInteger unit;
    double threshold;
    double factor;
} RevenantUnitChoice;

typedef struct {
    const RevenantUnitName *known;
    NSUInteger knownCount;
    const RevenantUnitChoice *choices;
    NSUInteger choiceCount;
    NSInteger zero;
    NSInteger negative;
} RevenantUnitDimension;

RevenantUnitSystem revenant_unit_system(NSLocale *locale);

double revenant_unit_factor(NSString *dimension, RevenantUnitSystem system, NSInteger unit);

NSInteger revenant_unit_chosen(NSString *dimension, RevenantUnitSystem system, BOOL person, double base, double *chosen);

NSString *revenant_unit_unknown_name(NSFormattingUnitStyle style, double value);

NSString *revenant_unit_unknown_written(RevenantUnitSystem system, NSFormattingUnitStyle style, double value);

NSString *revenant_unit_name(NSString *dimension, RevenantUnitSystem system, NSInteger unit, NSFormattingUnitStyle style, double value);

NSString *revenant_unit_written_short(NSString *dimension, RevenantUnitSystem system, NSInteger unit);

NSString *revenant_unit_food_name(NSInteger unit, NSFormattingUnitStyle style, double value, BOOL written,
                                 NSNumberFormatter *numbers);

NSString *revenant_unit_number(double value, NSNumberFormatter *numbers);

BOOL revenant_unit_joins_with_space(NSFormattingUnitStyle style);

NSString *revenant_unit_given(NSString *dimension, RevenantUnitSystem system, double inUnit, NSInteger unit,
                            NSFormattingUnitStyle style, NSNumberFormatter *numbers);

NSString *revenant_unit_string(NSString *dimension, RevenantUnitSystem system, double base, NSInteger unit,
                             NSFormattingUnitStyle style, NSNumberFormatter *numbers);

NSString *revenant_unit_stone(RevenantUnitSystem system, double stones, NSFormattingUnitStyle style, NSNumberFormatter *numbers);

NSString *revenant_unit_person_height(RevenantUnitSystem system, double metres, NSFormattingUnitStyle style, NSNumberFormatter *numbers);

NSString *revenant_unit_written(NSString *dimension, RevenantUnitSystem system, BOOL person, double base, NSInteger unit,
                              NSFormattingUnitStyle style, NSNumberFormatter *numbers);
