#import <Foundation/Foundation.h>

#import "CharonUnitFormat.h"

/* NSEnergyFormatter, iOS 8.0, the class whole from the 26.2 header: the number formatter and the
   unit style that say how an energy is written, the flag that says an energy is a food energy,
   the four methods that write one, and the method that reads one back and is documented never to.

   The measurements are the system's own, held against it by tests/backports/host/unitformat, and
   what the release can and cannot be asked for is written down in
   facts/Foundation/NSUnitFormat.md. The one rule of this class that is its own is the flag: a
   kilocalorie of food energy is written "C", "Cal" or "Calories" where it is "kcal", "kcal" or
   "kilocalorie" otherwise, and the flag changes the name and nothing else - measured over ten
   decades in both directions, the unit a food energy is written in is the unit any other energy
   is written in. */

@implementation NSEnergyFormatter {
    NSNumberFormatter *_numbers;
    NSFormattingUnitStyle _unitStyle;
    BOOL _forFoodEnergyUse;
}

- (instancetype)init
{
    self = [super init];
    if (self)
        _unitStyle = NSFormattingUnitStyleMedium;
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    NSEnergyFormatter *copy = [[[self class] allocWithZone:zone] init];
    copy->_numbers = [_numbers copy];
    copy->_unitStyle = _unitStyle;
    copy->_forFoodEnergyUse = _forFoodEnergyUse;
    return copy;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (!self)
        return nil;
    _numbers = [[coder decodeObjectForKey:@"NS.numbers"] copy];
    _unitStyle = (NSFormattingUnitStyle)[coder decodeIntegerForKey:@"NS.unitStyle"];
    _forFoodEnergyUse = [coder decodeBoolForKey:@"NS.forFoodEnergyUse"];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_numbers forKey:@"NS.numbers"];
    [coder encodeInteger:(NSInteger)_unitStyle forKey:@"NS.unitStyle"];
    [coder encodeBool:_forFoodEnergyUse forKey:@"NS.forFoodEnergyUse"];
}

- (NSNumberFormatter *)numberFormatter
{
    if (!_numbers) {
        _numbers = [[NSNumberFormatter alloc] init];
        _numbers.numberStyle = NSNumberFormatterDecimalStyle;
    }
    return _numbers;
}

- (void)setNumberFormatter:(NSNumberFormatter *)formatter
{
    _numbers = [formatter copy];
}

- (NSFormattingUnitStyle)unitStyle
{
    return _unitStyle;
}

- (void)setUnitStyle:(NSFormattingUnitStyle)style
{
    _unitStyle = style;
}

- (BOOL)isForFoodEnergyUse
{
    return _forFoodEnergyUse;
}

- (void)setForFoodEnergyUse:(BOOL)forFoodEnergyUse
{
    _forFoodEnergyUse = forFoodEnergyUse;
}

/* The name of a unit, which for a kilocalorie of food energy is not the name of a kilocalorie: the
   flag writes "C" where a name is asked for and "Cal" where a value and a name are written
   together. */
- (NSString *)charon_nameOfUnit:(NSInteger)unit value:(double)value system:(CharonUnitSystem)system written:(BOOL)written
{
    NSNumberFormatter *numbers = self.numberFormatter;
    if (_forFoodEnergyUse) {
        NSString *food = charon_unit_food_name(unit, _unitStyle, value, written, numbers);
        if (food)
            return food;
    }
    return written && _unitStyle == NSFormattingUnitStyleShort ? charon_unit_written_short(@"energy", system, unit)
                                                               : charon_unit_name(@"energy", system, unit, _unitStyle, value);
}

- (NSString *)stringFromValue:(double)value unit:(NSEnergyFormatterUnit)unit
{
    CharonUnitSystem system = charon_unit_system([NSLocale currentLocale]);
    /* A kilocalorie of food energy has a name of its own, and every other unit is written as the
       shared machine writes it - including a unit outside the enumeration, which the system writes
       with the name of the gram-force. */
    NSString *food = _forFoodEnergyUse ? charon_unit_food_name(unit, _unitStyle, value, YES, self.numberFormatter) : nil;
    if (food) {
        NSString *number = charon_unit_number(value, self.numberFormatter);
        return charon_unit_joins_with_space(_unitStyle) ? [NSString stringWithFormat:@"%@ %@", number, food]
                                                        : [NSString stringWithFormat:@"%@%@", number, food];
    }
    return charon_unit_given(@"energy", system, value, unit, _unitStyle, self.numberFormatter);
}

- (NSString *)stringFromJoules:(double)numberInJoules
{
    CharonUnitSystem system = charon_unit_system([NSLocale currentLocale]);
    double inUnit = 0;
    NSInteger unit = charon_unit_chosen(@"energy", system, NO, numberInJoules, &inUnit);
    return charon_unit_written(@"energy", system, NO, numberInJoules, unit, _unitStyle, self.numberFormatter);
}

- (NSString *)unitStringFromValue:(double)value unit:(NSEnergyFormatterUnit)unit
{
    return [self charon_nameOfUnit:unit value:value system:charon_unit_system([NSLocale currentLocale]) written:NO];
}

- (NSString *)unitStringFromJoules:(double)numberInJoules usedUnit:(NSEnergyFormatterUnit *)unitp
{
    CharonUnitSystem system = charon_unit_system([NSLocale currentLocale]);
    double inUnit = 0;
    NSInteger unit = charon_unit_chosen(@"energy", system, NO, numberInJoules, &inUnit);
    if (unitp)
        *unitp = (NSEnergyFormatterUnit)unit;
    return [self charon_nameOfUnit:unit value:inUnit system:system written:NO];
}

- (BOOL)getObjectValue:(id *)obj forString:(NSString *)string errorDescription:(NSString **)error
{
    if (obj)
        *obj = nil;
    if (error)
        *error = nil;
    return NO;
}

@end
