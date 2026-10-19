#import <Foundation/Foundation.h>

#import "CharonUnitFormat.h"

/* NSMassFormatter, iOS 8.0, the class whole from the 26.2 header: the number formatter and the
   unit style that say how a mass is written, the flag that says a mass is a person's mass, the
   four methods that write one, and the method that reads one back and is documented never to.

   The measurements are the system's own, held against it by tests/backports/host/unitformat, and
   what the release can and cannot be asked for is written down in
   facts/Foundation/NSUnitFormat.md: the release has no NSMassFormatter and no CLDR unit-name
   table, but it has its own NSNumberFormatter, which writes the number, and its own locale, which
   answers under NSLocaleMeasurementSystem which system of units a mass is written in. */

@implementation NSMassFormatter {
    NSNumberFormatter *_numbers;
    NSFormattingUnitStyle _unitStyle;
    BOOL _forPersonMassUse;
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
    NSMassFormatter *copy = [[[self class] allocWithZone:zone] init];
    copy->_numbers = [_numbers copy];
    copy->_unitStyle = _unitStyle;
    copy->_forPersonMassUse = _forPersonMassUse;
    return copy;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (!self)
        return nil;
    _numbers = [[coder decodeObjectForKey:@"NS.numbers"] copy];
    _unitStyle = (NSFormattingUnitStyle)[coder decodeIntegerForKey:@"NS.unitStyle"];
    _forPersonMassUse = [coder decodeBoolForKey:@"NS.forPersonMassUse"];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_numbers forKey:@"NS.numbers"];
    [coder encodeInteger:(NSInteger)_unitStyle forKey:@"NS.unitStyle"];
    [coder encodeBool:_forPersonMassUse forKey:@"NS.forPersonMassUse"];
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

- (BOOL)isForPersonMassUse
{
    return _forPersonMassUse;
}

- (void)setForPersonMassUse:(BOOL)forPersonMassUse
{
    _forPersonMassUse = forPersonMassUse;
}

- (NSString *)stringFromValue:(double)value unit:(NSMassFormatterUnit)unit
{
    if (unit == NSMassFormatterUnitStone)
        return charon_unit_stone(charon_unit_system([NSLocale currentLocale]), value, _unitStyle, self.numberFormatter);
    return charon_unit_given(@"mass", charon_unit_system([NSLocale currentLocale]), value, unit, _unitStyle, self.numberFormatter);
}

- (NSString *)stringFromKilograms:(double)numberInKilograms
{
    CharonUnitSystem system = charon_unit_system([NSLocale currentLocale]);
    double inUnit = 0;
    NSInteger unit = charon_unit_chosen(@"mass", system, NO, numberInKilograms, &inUnit);
    return charon_unit_written(@"mass", system, NO, numberInKilograms, unit, _unitStyle, self.numberFormatter);
}

- (NSString *)unitStringFromValue:(double)value unit:(NSMassFormatterUnit)unit
{
    return charon_unit_name(@"mass", charon_unit_system([NSLocale currentLocale]), unit, _unitStyle, value);
}

- (NSString *)unitStringFromKilograms:(double)numberInKilograms usedUnit:(NSMassFormatterUnit *)unitp
{
    CharonUnitSystem system = charon_unit_system([NSLocale currentLocale]);
    double inUnit = 0;
    NSInteger unit = charon_unit_chosen(@"mass", system, NO, numberInKilograms, &inUnit);
    if (unitp)
        *unitp = (NSMassFormatterUnit)unit;
    return charon_unit_name(@"mass", system, unit, _unitStyle, inUnit);
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
