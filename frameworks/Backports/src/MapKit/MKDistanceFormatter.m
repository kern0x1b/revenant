#import <MapKit/MapKit.h>
#import <MapKit/MKDistanceFormatter.h>
#import <math.h>
#import "RevenantMapKit.h"

@implementation MKDistanceFormatter {
    MKDistanceFormatterUnits _units;
    MKDistanceFormatterUnitStyle _unitStyle;
    NSLocale *_locale;
}

@synthesize units = _units;
@synthesize unitStyle = _unitStyle;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _units = MKDistanceFormatterUnitsDefault;
        _unitStyle = MKDistanceFormatterUnitStyleDefault;
        _locale = nil;
    }
    return self;
}

- (NSLocale *)locale
{
    return _locale ?: [NSLocale currentLocale];
}

- (void)setLocale:(NSLocale *)locale
{
    _locale = locale;
}

- (MKDistanceFormatterUnits)revenant_resolvedUnits
{
    if (_units != MKDistanceFormatterUnitsDefault) {
        return _units;
    }
    BOOL metric = [[self locale] usesMetricSystem];
    return metric ? MKDistanceFormatterUnitsMetric : MKDistanceFormatterUnitsImperial;
}

- (NSString *)stringFromDistance:(CLLocationDistance)distance
{
    double metres = fabs((double)distance);
    BOOL metric = [self revenant_resolvedUnits] == MKDistanceFormatterUnitsMetric;
    BOOL yards = [self revenant_resolvedUnits] == MKDistanceFormatterUnitsImperialWithYards;
    double value;
    NSString *fullName, *pluralName, *shortName;
    if (metric) {
        if (metres < 1000.0) {
            value = metres;
            fullName = @"metre"; pluralName = @"metres"; shortName = @"m";
        } else {
            value = metres / 1000.0;
            fullName = @"kilometre"; pluralName = @"kilometres"; shortName = @"km";
        }
        NSUInteger count = (NSUInteger)llround(value);
        NSString *full, *abbreviated;
        if (metres < 1000.0) {
            full = [NSString stringWithFormat:@"%.0f %@", value, count == 1 ? fullName : pluralName];
            abbreviated = [NSString stringWithFormat:@"%.0f %@", value, shortName];
        } else {
            full = [NSString stringWithFormat:@"%.1f %@", value, count == 1 ? fullName : pluralName];
            abbreviated = [NSString stringWithFormat:@"%.1f %@", value, shortName];
        }
        if (_unitStyle == MKDistanceFormatterUnitStyleFull) {
            return full;
        }
        if (_unitStyle == MKDistanceFormatterUnitStyleAbbreviated) {
            return abbreviated;
        }
        return abbreviated;
    }
    double miles = metres / 1609.344;
    if (miles < 0.1) {
        if (yards) {
            value = metres / 0.9144;
            fullName = @"yard"; pluralName = @"yards"; shortName = @"yd";
        } else {
            value = metres / 0.3048;
            fullName = @"foot"; pluralName = @"feet"; shortName = @"ft";
        }
    } else {
        value = miles;
        fullName = @"mile"; pluralName = @"miles"; shortName = @"mi";
    }
    NSUInteger count = (NSUInteger)llround(value);
    NSString *full, *abbreviated;
    if (miles >= 10.0) {
        full = [NSString stringWithFormat:@"%.0f %@", value, count == 1 ? fullName : pluralName];
        abbreviated = full;
    } else {
        full = [NSString stringWithFormat:@"%.1f %@", value, count == 1 ? fullName : pluralName];
        abbreviated = full;
    }
    if (_unitStyle == MKDistanceFormatterUnitStyleFull) {
        return full;
    }
    if (_unitStyle == MKDistanceFormatterUnitStyleAbbreviated) {
        return abbreviated;
    }
    return abbreviated;
}

- (CLLocationDistance)distanceFromString:(NSString *)distance
{
    NSString *text = [distance stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (text.length == 0) {
        return -1.0;
    }
    NSScanner *scanner = [NSScanner scannerWithString:text];
    double value = 0.0;
    if (![scanner scanDouble:&value]) {
        return -1.0;
    }
    NSString *unit = [[text substringFromIndex:scanner.scanLocation]
                      stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    unit = [unit lowercaseString];
    if (unit.length == 0) {
        return (CLLocationDistance)value;
    }
    if ([unit hasPrefix:@"kilo"] || [unit isEqualToString:@"km"] || [unit isEqualToString:@"kilometre"] ||
        [unit isEqualToString:@"kilometres"] || [unit isEqualToString:@"kilometer"] || [unit isEqualToString:@"kilometers"]) {
        return (CLLocationDistance)value * 1000.0;
    }
    if ([unit hasPrefix:@"mi"] || [unit isEqualToString:@"mile"] || [unit isEqualToString:@"miles"]) {
        return (CLLocationDistance)value * 1609.344;
    }
    if ([unit hasPrefix:@"yd"] || [unit hasPrefix:@"yard"]) {
        return (CLLocationDistance)value * 0.9144;
    }
    if ([unit hasPrefix:@"f"] || [unit hasPrefix:@"foot"]) {
        return (CLLocationDistance)value * 0.3048;
    }
    if ([unit hasPrefix:@"m"]) {
        return (CLLocationDistance)value;
    }
    return -1.0;
}

@end
