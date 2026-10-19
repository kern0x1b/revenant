#import <Foundation/Foundation.h>

#import "RevenantUnitFormat.h"

@implementation NSLengthFormatter {
    NSNumberFormatter *_numbers;
    NSFormattingUnitStyle _unitStyle;
    BOOL _forPersonHeightUse;
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
    NSLengthFormatter *copy = [[[self class] allocWithZone:zone] init];
    copy->_numbers = [_numbers copy];
    copy->_unitStyle = _unitStyle;
    copy->_forPersonHeightUse = _forPersonHeightUse;
    return copy;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (!self)
        return nil;
    _numbers = [[coder decodeObjectForKey:@"NS.numbers"] copy];
    _unitStyle = (NSFormattingUnitStyle)[coder decodeIntegerForKey:@"NS.unitStyle"];
    _forPersonHeightUse = [coder decodeBoolForKey:@"NS.forPersonHeightUse"];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_numbers forKey:@"NS.numbers"];
    [coder encodeInteger:(NSInteger)_unitStyle forKey:@"NS.unitStyle"];
    [coder encodeBool:_forPersonHeightUse forKey:@"NS.forPersonHeightUse"];
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

- (BOOL)isForPersonHeightUse
{
    return _forPersonHeightUse;
}

- (void)setForPersonHeightUse:(BOOL)forPersonHeightUse
{
    _forPersonHeightUse = forPersonHeightUse;
}

- (NSString *)stringFromValue:(double)value unit:(NSLengthFormatterUnit)unit
{
    return revenant_unit_given(@"length", revenant_unit_system([NSLocale currentLocale]), value, unit, _unitStyle, self.numberFormatter);
}

- (NSString *)stringFromMeters:(double)numberInMeters
{
    RevenantUnitSystem system = revenant_unit_system([NSLocale currentLocale]);
    double inUnit = 0;
    NSInteger unit = revenant_unit_chosen(@"length", system, _forPersonHeightUse, numberInMeters, &inUnit);
    return revenant_unit_written(@"length", system, _forPersonHeightUse, numberInMeters, unit, _unitStyle, self.numberFormatter);
}

- (NSString *)unitStringFromValue:(double)value unit:(NSLengthFormatterUnit)unit
{
    return revenant_unit_name(@"length", revenant_unit_system([NSLocale currentLocale]), unit, _unitStyle, value);
}

- (NSString *)unitStringFromMeters:(double)numberInMeters usedUnit:(NSLengthFormatterUnit *)unitp
{
    RevenantUnitSystem system = revenant_unit_system([NSLocale currentLocale]);
    double inUnit = 0;
    NSInteger unit = revenant_unit_chosen(@"length", system, _forPersonHeightUse, numberInMeters, &inUnit);
    if (unitp)
        *unitp = (NSLengthFormatterUnit)unit;
    if (_forPersonHeightUse && system != RevenantUnitSystemMetric && _unitStyle != NSFormattingUnitStyleShort
        && _unitStyle != NSFormattingUnitStyleMedium)
        return revenant_unit_name(@"length", system, unit, _unitStyle, 2);
    return revenant_unit_name(@"length", system, unit, _unitStyle, inUnit);
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
