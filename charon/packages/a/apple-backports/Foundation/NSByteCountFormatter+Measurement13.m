#import <Foundation/Foundation.h>
#include <math.h>

static NSUnitInformationStorage *charon_unit(BOOL binary, NSUInteger index)
{
    switch (index) {
    case 0: return [NSUnitInformationStorage bytes];
    case 1: return binary ? [NSUnitInformationStorage kibibytes] : [NSUnitInformationStorage kilobytes];
    case 2: return binary ? [NSUnitInformationStorage mebibytes] : [NSUnitInformationStorage megabytes];
    case 3: return binary ? [NSUnitInformationStorage gibibytes] : [NSUnitInformationStorage gigabytes];
    case 4: return binary ? [NSUnitInformationStorage tebibytes] : [NSUnitInformationStorage terabytes];
    case 5: return binary ? [NSUnitInformationStorage pebibytes] : [NSUnitInformationStorage petabytes];
    case 6: return binary ? [NSUnitInformationStorage exbibytes] : [NSUnitInformationStorage exabytes];
    case 7: return binary ? [NSUnitInformationStorage zebibytes] : [NSUnitInformationStorage zettabytes];
    default: return binary ? [NSUnitInformationStorage yobibytes] : [NSUnitInformationStorage yottabytes];
    }
}

static NSString *charon_byte_units[] = {@"bytes", @"KB", @"MB", @"GB", @"TB", @"PB", @"EB", @"ZB", @"YB"};

static NSString *charon_whole(NSNumberFormatter *number, double value, BOOL integer)
{
    if (fabs(value) < 9007199254740992.0)
        return [number stringFromNumber:@(value)];
    char buffer[64];
    BOOL exact = integer && fabs(value) < 9223372036854775808.0;
    int limit = 17;
    for (int precision = 1; precision <= limit; precision++) {
        snprintf(buffer, sizeof buffer, "%.*e", precision - 1, fabs(value));
        if (strtod(buffer, NULL) == fabs(value))
            break;
    }
    NSString *text = @(buffer);
    NSRange e = [text rangeOfString:@"e"];
    NSInteger exponent = [[text substringFromIndex:e.location + 1] integerValue];
    NSString *digits = [[text substringToIndex:e.location] stringByReplacingOccurrencesOfString:@"." withString:@""];
    if (exact || (NSInteger)digits.length > exponent + 1) {
        snprintf(buffer, sizeof buffer, "%.0f", fabs(value));
        digits = @(buffer);
    } else {
        digits = [digits stringByPaddingToLength:(NSUInteger)exponent + 1 withString:@"0" startingAtIndex:0];
    }
    NSUInteger size = number.groupingSize ?: 3;
    NSMutableString *grouped = [NSMutableString string];
    for (NSUInteger position = 0; position < digits.length; position++) {
        if (position && number.usesGroupingSeparator && (digits.length - position) % size == 0)
            [grouped appendString:number.groupingSeparator ?: @","];
        [grouped appendString:[digits substringWithRange:NSMakeRange(position, 1)]];
    }
    return value < 0 ? [@"-" stringByAppendingString:grouped] : grouped;
}

static NSString *charon_big_count(NSByteCountFormatter *formatter, NSMeasurement *measurement, double bytes)
{
    BOOL binary = formatter.countStyle == NSByteCountFormatterCountStyleMemory || formatter.countStyle == NSByteCountFormatterCountStyleBinary;
    double base = binary ? 1024 : 1000;
    NSByteCountFormatterUnits allowed = formatter.allowedUnits;
    NSUInteger mask = (allowed == NSByteCountFormatterUseDefault || allowed == 0) ? 0x1FF : (NSUInteger)allowed;
    NSUInteger unit = NSNotFound;
    double magnitude = fabs(bytes);
    for (NSUInteger index = 0; index < 9; index++) {
        if (!(mask & (1u << index)))
            continue;
        if (unit == NSNotFound || magnitude >= pow(base, (double)index))
            unit = index;
    }
    if (unit == NSNotFound)
        unit = 8;
    double scaled = [[measurement measurementByConvertingToUnit:charon_unit(binary, unit)] doubleValue];
    if (!formatter.isAdaptive && unit < 8 && fabs(scaled) >= base - 0.5 && fabs(scaled) < base) {
        for (NSUInteger next = unit + 1; next < 9; next++) {
            if (mask & (1u << next)) {
                unit = next;
                scaled = [[measurement measurementByConvertingToUnit:charon_unit(binary, unit)] doubleValue];
                break;
            }
        }
    }
    NSNumberFormatter *number = [[NSNumberFormatter alloc] init];
    number.numberStyle = NSNumberFormatterDecimalStyle;
    number.roundingMode = NSNumberFormatterRoundHalfUp;
    NSUInteger digits;
    double shown = fabs(scaled);
    if (formatter.isAdaptive) {
        digits = unit >= 3 ? 2 : (unit == 2 ? 1 : 0);
        number.maximumFractionDigits = digits;
        number.minimumFractionDigits = formatter.zeroPadsFractionDigits ? digits : 0;
    } else if (shown > 0 && shown < 1) {
        number.usesSignificantDigits = YES;
        number.maximumSignificantDigits = 3;
        number.minimumSignificantDigits = formatter.zeroPadsFractionDigits ? 3 : 1;
    } else {
        digits = shown < 10 ? 2 : (shown < 100 ? 1 : 0);
        number.maximumFractionDigits = digits;
        number.minimumFractionDigits = formatter.zeroPadsFractionDigits ? digits : 0;
    }
    NSString *count = number.maximumFractionDigits == 0 && !number.usesSignificantDigits ? charon_whole(number, scaled, unit == 0) : [number stringFromNumber:@(scaled)];
    BOOL includesCount = formatter.includesCount, includesUnit = formatter.includesUnit;
    if (!includesCount && !includesUnit)
        includesCount = includesUnit = YES;
    NSMutableString *text = [NSMutableString string];
    if (includesCount)
        [text appendString:count];
    if (includesUnit) {
        if (text.length)
            [text appendString:@" "];
        [text appendString:charon_byte_units[unit]];
    }
    if (formatter.includesActualByteCount && includesCount && includesUnit && unit > 0) {
        number.usesSignificantDigits = NO;
        number.maximumFractionDigits = 0;
        number.minimumFractionDigits = 0;
        [text appendFormat:@" (%@ bytes)", charon_whole(number, bytes, YES)];
    }
    return text;
}

@implementation NSByteCountFormatter (CharonMeasurement)

+ (NSString *)stringFromMeasurement:(NSMeasurement *)measurement countStyle:(NSByteCountFormatterCountStyle)countStyle
{
    NSByteCountFormatter *formatter = [[NSByteCountFormatter alloc] init];
    formatter.countStyle = countStyle;
    return [formatter stringFromMeasurement:measurement];
}

- (NSString *)stringFromMeasurement:(NSMeasurement *)measurement
{
    NSUnit *unit = measurement.unit;
    if (![unit isKindOfClass:[NSUnitInformationStorage class]])
        [NSException raise:NSInvalidArgumentException format:@"NSByteCountFormatter only supports measurements of dimension NSUnitInformationStorage -- got invalid unit '%@'", unit ? NSStringFromClass([unit class]) : @"(null)"];
    double bytes = [[measurement measurementByConvertingToUnit:[NSUnitInformationStorage bytes]] doubleValue];
    if (isnan(bytes) || isinf(bytes)) {
        NSString *count = isnan(bytes) ? @"NaN" : (bytes < 0 ? @"-∞" : @"+∞");
        BOOL includesCount = self.includesCount, includesUnit = self.includesUnit;
        if (!includesCount && !includesUnit)
            includesCount = includesUnit = YES;
        NSMutableString *text = [NSMutableString string];
        if (includesCount)
            [text appendString:count];
        if (includesUnit)
            [text appendFormat:@"%@bytes", text.length ? @" " : @""];
        return text;
    }
    if (fabs(bytes) < 9007199254740992.0)
    {
        BOOL smallCount = fabs(bytes) < 1000 && (self.allowedUnits == NSByteCountFormatterUseDefault || (self.allowedUnits & NSByteCountFormatterUseBytes));
        NSString *text = [self stringFromByteCount:(long long)bytes];
        NSString *decimal = [NSRegularExpression escapedPatternForString:[[NSLocale currentLocale] objectForKey:NSLocaleDecimalSeparator] ?: @"."];
        NSRegularExpression *padded = [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"(^|[^0-9.,])([0-9]+)%@0+( bytes%@)", decimal, smallCount ? @"|$" : @""] options:0 error:NULL];
        return [padded stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@"$1$2$3"];
    }
    return charon_big_count(self, measurement, bytes);
}

@end
