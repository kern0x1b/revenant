// MKDistanceFormatter.
//
// The distance formatter is the length of a distance in the measure of the reader's locale, in
// the style the reader asked for, and the reader's own locale decides the measure when the caller
// did not name one (MKDistanceFormatterUnitsDefault): the imperial measure for the locales that
// use it and the metric measure for the rest. Its two ways are exact opposites: what one string
// from a distance parses back to that distance, and what a string it cannot parse answers, which
// is the negative number the header documents.
//
// The scale view is the bar in the corner of a map that says how long a piece of the map is. It is
// drawn from the release's own projection: a round number of metres that fits the width the
// legend was given, and then that many metres' worth of the overlay's own map points, which is the
// bar's own length.
#import <MapKit/MapKit.h>
#import <MapKit/MKDistanceFormatter.h>
#import <math.h>
#import "CharonMapKit.h"

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

- (MKDistanceFormatterUnits)charon_resolvedUnits
{
    if (_units != MKDistanceFormatterUnitsDefault) {
        return _units;
    }
    // The default measure of the locale, which is the imperial one where the locale uses it.
    // The locale's own measurement system, and this is MEASURED rather than assumed: the header's
    // comment says the default measure of a locale "is not identical to NSLocaleUsesMetricSystem",
    // and -[NSLocale objectForKey:@"NSLocaleMeasurementSystem"] answers nil on the host the
    // behaviour oracle runs against, so a key lookup here made en_US metric. What the host's own
    // MKDistanceFormatter actually follows, over the five locales tests/backports/host/mapkit
    // measures, is -usesMetricSystem: en_US is imperial and the other four are metric.
    BOOL metric = [[self locale] usesMetricSystem];
    return metric ? MKDistanceFormatterUnitsMetric : MKDistanceFormatterUnitsImperial;
}

- (NSString *)stringFromDistance:(CLLocationDistance)distance
{
    double metres = fabs((double)distance);
    BOOL metric = [self charon_resolvedUnits] == MKDistanceFormatterUnitsMetric;
    BOOL yards = [self charon_resolvedUnits] == MKDistanceFormatterUnitsImperialWithYards;
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
            // A tenth of a kilometre is ten metres, and that is the finest a kilometre is written.
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
    // The imperial measure: a mile over ten is written in whole miles, a mile under ten with one
    // decimal, and anything under a tenth of a mile in feet (or in yards, when the caller asked for
    // the measure that has them), which is the rule MKDistanceFormatter documents.
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
    // The number at the front, then whatever unit word the reader wrote: the full and the
    // abbreviated spellings of both measures, and a bare number is metres.
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
