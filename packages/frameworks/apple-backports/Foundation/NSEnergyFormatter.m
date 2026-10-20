#import <Foundation/Foundation.h>

#import "RevenantUnitFormat.h"

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

- (NSString *)revenant_nameOfUnit:(NSInteger)unit value:(double)value system:(RevenantUnitSystem)system written:(BOOL)written
{
    NSNumberFormatter *numbers = self.numberFormatter;
    if (_forFoodEnergyUse) {
        NSString *food = revenant_unit_food_name(unit, _unitStyle, value, written, numbers);
        if (food)
            return food;
    }
    return written && _unitStyle == NSFormattingUnitStyleShort ? revenant_unit_written_short(@"energy", system, unit)
                                                               : revenant_unit_name(@"energy", system, unit, _unitStyle, value);
}

- (NSString *)stringFromValue:(double)value unit:(NSEnergyFormatterUnit)unit
{
    RevenantUnitSystem system = revenant_unit_system([NSLocale currentLocale]);
    NSString *food = _forFoodEnergyUse ? revenant_unit_food_name(unit, _unitStyle, value, YES, self.numberFormatter) : nil;
    if (food) {
        NSString *number = revenant_unit_number(value, self.numberFormatter);
        return revenant_unit_joins_with_space(_unitStyle) ? [NSString stringWithFormat:@"%@ %@", number, food]
                                                        : [NSString stringWithFormat:@"%@%@", number, food];
    }
    return revenant_unit_given(@"energy", system, value, unit, _unitStyle, self.numberFormatter);
}

- (NSString *)stringFromJoules:(double)numberInJoules
{
    RevenantUnitSystem system = revenant_unit_system([NSLocale currentLocale]);
    double inUnit = 0;
    NSInteger unit = revenant_unit_chosen(@"energy", system, NO, numberInJoules, &inUnit);
    return revenant_unit_written(@"energy", system, NO, numberInJoules, unit, _unitStyle, self.numberFormatter);
}

- (NSString *)unitStringFromValue:(double)value unit:(NSEnergyFormatterUnit)unit
{
    return [self revenant_nameOfUnit:unit value:value system:revenant_unit_system([NSLocale currentLocale]) written:NO];
}

- (NSString *)unitStringFromJoules:(double)numberInJoules usedUnit:(NSEnergyFormatterUnit *)unitp
{
    RevenantUnitSystem system = revenant_unit_system([NSLocale currentLocale]);
    double inUnit = 0;
    NSInteger unit = revenant_unit_chosen(@"energy", system, NO, numberInJoules, &inUnit);
    if (unitp)
        *unitp = (NSEnergyFormatterUnit)unit;
    return [self revenant_nameOfUnit:unit value:inUnit system:system written:NO];
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
