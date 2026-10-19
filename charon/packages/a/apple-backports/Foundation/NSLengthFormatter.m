#import <Foundation/Foundation.h>

#import "CharonUnitFormat.h"

/* NSLengthFormatter, iOS 8.0, the class whole from the 26.2 header: the number formatter and the
   unit style that say how a length is written, the flag that says a length is a person's height,
   the four methods that write one, and the method that reads one back and is documented never to.

   Every rule in the file is measured against the system's own NSLengthFormatter by
   tests/backports/host/unitformat, which runs the two in one process over the same inputs and
   compares two answers for one input. The release cannot be asked for its own answers: it has no
   NSLengthFormatter, and the CLDR table its unit names come from arrived in the ICU of iOS 8.0,
   above every release the port carries (measured over the whole cache ladder and written down in
   facts/Foundation/NSUnitFormat.md). What the port does ask of the release is real: the number
   is written through the release's own NSNumberFormatter, so the digits, the grouping and the
   decimal mark are the locale's, and the system of units is read from the release's own locale
   under NSLocaleMeasurementSystem, which answers "U.S.", "U.K." or "Metric". */

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
    /* A decimal formatter of the current locale, built on first use and kept: the system answers
       one that was never set, and the same one every time. */
    if (!_numbers) {
        _numbers = [[NSNumberFormatter alloc] init];
        _numbers.numberStyle = NSNumberFormatterDecimalStyle;
    }
    return _numbers;
}

- (void)setNumberFormatter:(NSNumberFormatter *)formatter
{
    /* nil is the default: a decimal formatter is built again on next use, and the system answers
       a non-nil one after nil was set. */
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
    /* The value is written in the unit it is given and is never rescaled, so the figure it is
       written with is the one of the metre. */
    return charon_unit_given(@"length", charon_unit_system([NSLocale currentLocale]), value, unit, _unitStyle, self.numberFormatter);
}

- (NSString *)stringFromMeters:(double)numberInMeters
{
    CharonUnitSystem system = charon_unit_system([NSLocale currentLocale]);
    double inUnit = 0;
    NSInteger unit = charon_unit_chosen(@"length", system, _forPersonHeightUse, numberInMeters, &inUnit);
    return charon_unit_written(@"length", system, _forPersonHeightUse, numberInMeters, unit, _unitStyle, self.numberFormatter);
}

- (NSString *)unitStringFromValue:(double)value unit:(NSLengthFormatterUnit)unit
{
    return charon_unit_name(@"length", charon_unit_system([NSLocale currentLocale]), unit, _unitStyle, value);
}

- (NSString *)unitStringFromMeters:(double)numberInMeters usedUnit:(NSLengthFormatterUnit *)unitp
{
    CharonUnitSystem system = charon_unit_system([NSLocale currentLocale]);
    double inUnit = 0;
    NSInteger unit = charon_unit_chosen(@"length", system, _forPersonHeightUse, numberInMeters, &inUnit);
    if (unitp)
        *unitp = (NSLengthFormatterUnit)unit;
    /* The name of the unit the value is written in, and for a person's height the plural of the
       foot whatever the height: the system answers "feet" for a height of one foot. */
    if (_forPersonHeightUse && system != CharonUnitSystemMetric && _unitStyle != NSFormattingUnitStyleShort
        && _unitStyle != NSFormattingUnitStyleMedium)
        return charon_unit_name(@"length", system, unit, _unitStyle, 2);
    return charon_unit_name(@"length", system, unit, _unitStyle, inUnit);
}

- (BOOL)getObjectValue:(id *)obj forString:(NSString *)string errorDescription:(NSString **)error
{
    /* The header says this returns NO and the system writes neither the object nor the error,
       measured for a string it wrote, for an empty one and for one it could not have written. */
    if (obj)
        *obj = nil;
    if (error)
        *error = nil;
    return NO;
}

@end
