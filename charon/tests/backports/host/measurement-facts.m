// measurement-facts.m - what the host's own NSMeasurementFormatter answers, step by step. The four
// documented defaults, what -stringFromUnit: says over a spread of locales and of unit systems, and
// whether -numberFormatter is there and whether setting it changes either string.
//
// The units are named by the host's own classes, because the port's units carry the same symbols; the
// pairing between the two is in facts/Foundation/NSMeasurementFormatter.md, and the port's own unit
// symbols are what this program's output is compared against in the differential.
#import <Foundation/Foundation.h>

static void P(NSString *f, ...) NS_FORMAT_FUNCTION(1, 2);
static void P(NSString *f, ...)
{
    va_list a;
    va_start(a, f);
    NSString *s = [[NSString alloc] initWithFormat:f arguments:a];
    va_end(a);
    printf("%s\n", s.UTF8String);
}

static NSArray *units(void)
{
    // one of each kind, and the two that format differently between locales
    return @[ [NSUnitLength kilometers], [NSUnitLength meters], [NSUnitLength feet], [NSUnitLength inches],
              [NSUnitLength miles], [NSUnitMass kilograms], [NSUnitMass grams], [NSUnitMass poundsMass],
              [NSUnitMass ounces], [NSUnitEnergy kilocalories], [NSUnitEnergy calories],
              [NSUnitEnergy joules], [NSUnitSpeed kilometersPerHour], [NSUnitSpeed milesPerHour],
              [NSUnitTemperature celsius], [NSUnitTemperature fahrenheit],
              [NSUnitVolume liters], [NSUnitVolume cups], [NSUnitVolume teaspoons] ];
}

int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        int step = argc > 1 ? atoi(argv[1]) : 0;
        NSMeasurementFormatter *formatter = [[NSMeasurementFormatter alloc] init];

        if (step == 0) {  // the four documented defaults
            P(@"unitOptions   = %lu (empty is %d)", (unsigned long)formatter.unitOptions,
              formatter.unitOptions == 0);
            P(@"unitStyle     = %ld, and NSFormattingUnitStyleMedium is %ld",
              (long)formatter.unitStyle, (long)NSFormattingUnitStyleMedium);
            P(@"locale        = %@, and the current locale is %@", formatter.locale.localeIdentifier,
              [NSLocale currentLocale].localeIdentifier);
            P(@"numberFormatter = %@", formatter.numberFormatter ? @"an object" : @"(nil)");
            P(@"is the locale the current one: %d",
              (int)[formatter.locale isEqual:[NSLocale currentLocale]]);
            P(@"the unit options' three cases: ProvidedUnit=%lu NaturalScale=%lu TemperatureWithoutUnit=%lu",
              (unsigned long)NSMeasurementFormatterUnitOptionsProvidedUnit,
              (unsigned long)NSMeasurementFormatterUnitOptionsNaturalScale,
              (unsigned long)NSMeasurementFormatterUnitOptionsTemperatureWithoutUnit);
            P(@"the unit styles: Short=%ld Medium=%ld Long=%ld", (long)NSFormattingUnitStyleShort,
              (long)NSFormattingUnitStyleMedium, (long)NSFormattingUnitStyleLong);
            P(@"describes |%@|", formatter.description);
            return 0;
        }

        if (step == 1) {  // stringFromUnit: over the units, in the current locale
            for (NSUnit *unit in units())
                P(@"%-6s -> |%@|", unit.symbol.UTF8String, [formatter stringFromUnit:unit]);
            return 0;
        }

        if (step == 2) {  // and over six locales, the ones that differ most
            NSArray *locales = @[ @"en_US", @"en_GB", @"fr_FR", @"de_DE", @"ja_JP", @"ar_EG", @"hi_IN" ];
            for (NSString *identifier in locales) {
                formatter.locale = [NSLocale localeWithLocaleIdentifier:identifier];
                P(@"%s", [identifier UTF8String]);
                for (NSUnit *unit in units())
                    P(@"  %-6s |%@|", unit.symbol.UTF8String, [formatter stringFromUnit:unit]);
            }
            return 0;
        }

        if (step == 3) {  // numberFormatter: is it there, and does setting it change the strings
            P(@"a fresh one: numberFormatter = %@", formatter.numberFormatter ? @"an object" : @"(nil)");
            NSString *beforeUnit = [formatter stringFromUnit:[NSUnitLength kilometers]];
            NSMeasurement *measurement = [[NSMeasurement alloc] initWithDoubleValue:1234.5 unit:[NSUnitLength meters]];
            NSString *beforeMeasurement = [formatter stringFromMeasurement:measurement];
            P(@"  km -> |%@|, 1234.5 m -> |%@|", beforeUnit, beforeMeasurement);
            NSNumberFormatter *numbers = [[NSNumberFormatter alloc] init];
            numbers.numberStyle = NSNumberFormatterDecimalStyle;
            numbers.minimumFractionDigits = 3;
            numbers.maximumFractionDigits = 3;
            numbers.usesGroupingSeparator = YES;
            formatter.numberFormatter = numbers;
            P(@"set to a number formatter with 3 fraction digits and grouping:");
            P(@"  numberFormatter = %@", formatter.numberFormatter ? @"an object" : @"(nil)");
            P(@"  km -> |%@| (before |%@|)", [formatter stringFromUnit:[NSUnitLength kilometers]],
              beforeUnit);
            P(@"  1234.5 m -> |%@| (before |%@|)", [formatter stringFromMeasurement:measurement],
              beforeMeasurement);
            formatter.numberFormatter = nil;
            P(@"back to nil: km -> |%@|", [formatter stringFromUnit:[NSUnitLength kilometers]]);
            P(@"  1234.5 m -> |%@|", [formatter stringFromMeasurement:measurement]);
            return 0;
        }

        if (step == 4) {  // the three unit options, on the units they are about
            NSString *identifier = (argc > 2) ? [NSString stringWithUTF8String:argv[2]] : @"en_US";
            formatter.locale = [NSLocale localeWithLocaleIdentifier:identifier];
            NSUnit *km = [NSUnitLength kilometers];
            NSUnit *m = [NSUnitLength meters];
            NSUnit *fahrenheit = [NSUnitTemperature fahrenheit];
            NSString *const names[] = { @"empty", @"ProvidedUnit", @"NaturalScale", @"both", @"Temperature" };
            NSUInteger const values[] = { 0, NSMeasurementFormatterUnitOptionsProvidedUnit,
                                          NSMeasurementFormatterUnitOptionsNaturalScale,
                                          NSMeasurementFormatterUnitOptionsProvidedUnit | NSMeasurementFormatterUnitOptionsNaturalScale,
                                          NSMeasurementFormatterUnitOptionsTemperatureWithoutUnit };
            P(@"%s", [identifier UTF8String]);
            for (unsigned i = 0; i < 5; i++) {
                formatter.unitOptions = values[i];
                P(@"  %-13s km |%@|  m |%@|  12000 |%@|  90°F |%@|", [names[i] UTF8String],
                  [formatter stringFromUnit:km], [formatter stringFromUnit:m],
                  [formatter stringFromMeasurement:[[NSMeasurement alloc] initWithDoubleValue:12000 unit:m]],
                  [formatter stringFromMeasurement:[[NSMeasurement alloc] initWithDoubleValue:90 unit:fahrenheit]]);
            }
            formatter.unitOptions = 0;
            return 0;
        }

        if (step == 5) {  // the copy, the equality and the archive, of a value class
            NSMeasurementFormatter *other = [[NSMeasurementFormatter alloc] init];
            other.unitStyle = NSFormattingUnitStyleLong;
            other.unitOptions = NSMeasurementFormatterUnitOptionsNaturalScale;
            other.locale = [NSLocale localeWithLocaleIdentifier:@"fr_FR"];
            formatter.unitStyle = NSFormattingUnitStyleLong;
            formatter.unitOptions = NSMeasurementFormatterUnitOptionsNaturalScale;
            formatter.locale = [NSLocale localeWithLocaleIdentifier:@"fr_FR"];
            P(@"two built the same way: isEqual = %d, hash %lu vs %lu", (int)[formatter isEqual:other],
              (unsigned long)formatter.hash, (unsigned long)other.hash);
            NSMeasurementFormatter *copied = [formatter copy];
            P(@"a copy: isEqual = %d, locale %@, style %ld, options %lu", (int)[copied isEqual:formatter],
              [copied.locale.localeIdentifier UTF8String], (long)copied.unitStyle,
              (unsigned long)copied.unitOptions);
            P(@"+supportsSecureCoding = %d", (int)[NSMeasurementFormatter supportsSecureCoding]);
            NSMutableData *data = [NSMutableData data];
            NSKeyedArchiver *a = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
            [a encodeObject:formatter forKey:NSKeyedArchiveRootObjectKey];
            [a finishEncoding];
            P(@"%lu bytes", (unsigned long)data.length);
            NSKeyedUnarchiver *u = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
            u.requiresSecureCoding = NO;
            NSMeasurementFormatter *back = [u decodeObjectOfClass:[NSMeasurementFormatter class]
                                             forKey:NSKeyedArchiveRootObjectKey];
            [u finishDecoding];
            P(@"read back: locale %@ style %ld options %lu, isEqual = %d",
              [back.locale.localeIdentifier UTF8String], (long)back.unitStyle, (unsigned long)back.unitOptions,
              (int)[back isEqual:formatter]);
            P(@"  km -> |%@|", [back stringFromUnit:[NSUnitLength kilometers]]);
            return 0;
        }
    }
    return 0;
}
