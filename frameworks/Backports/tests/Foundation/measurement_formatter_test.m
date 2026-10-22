#import "check.h"

static NSString *revenant_measure(NSString *locale, double value, NSUnit *unit, NSMeasurementFormatterUnitOptions options, NSFormattingUnitStyle style)
{
    NSMeasurementFormatter *formatter = [[NSMeasurementFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:locale];
    formatter.unitOptions = options;
    formatter.unitStyle = style;
    return [formatter stringFromMeasurement:[[NSMeasurement alloc] initWithDoubleValue:value unit:unit]];
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    NSMeasurementFormatterUnitOptions provided = NSMeasurementFormatterUnitOptionsProvidedUnit;
    NSMeasurementFormatterUnitOptions natural = NSMeasurementFormatterUnitOptionsNaturalScale;
    revenant_expect_string("a length converts to miles for en_US", revenant_measure(@"en_US", 1500, [NSUnitLength meters], 0, NSFormattingUnitStyleMedium), revenant_negative ? @"0.933 mi" : @"0.932 mi");
    revenant_expect_string("a mass converts to pounds for en_US", revenant_measure(@"en_US", 1, [NSUnitMass kilograms], 0, NSFormattingUnitStyleMedium), @"2.205 lb");
    revenant_expect_string("a temperature converts to Fahrenheit for en_US", revenant_measure(@"en_US", 1, [NSUnitTemperature celsius], 0, NSFormattingUnitStyleMedium), @"33.8°F");
    revenant_expect_string("a speed converts to miles per hour for en_GB", revenant_measure(@"en_GB", 1, [NSUnitSpeed metersPerSecond], 0, NSFormattingUnitStyleMedium), @"2.237 mph");
    revenant_expect_string("a mass stays in kilograms for en_GB", revenant_measure(@"en_GB", 1, [NSUnitMass kilograms], 0, NSFormattingUnitStyleMedium), @"1 kg");
    revenant_check([revenant_measure(@"fr_FR", 1500, [NSUnitLength meters], 0, NSFormattingUnitStyleMedium) hasPrefix:@"1,5"], "a length converts to kilometers for fr_FR with a decimal comma", revenant_measure(@"fr_FR", 1500, [NSUnitLength meters], 0, NSFormattingUnitStyleMedium));
    revenant_expect_string("the provided unit is kept", revenant_measure(@"en_US", 1500, [NSUnitLength meters], provided, NSFormattingUnitStyleMedium), @"1,500 m");
    revenant_expect_string("a long style names the unit in the singular", revenant_measure(@"en_US", 1, [NSUnitLength kilometers], provided, NSFormattingUnitStyleLong), @"1 kilometer");
    revenant_expect_string("a long style names the unit in the plural", revenant_measure(@"en_US", 2, [NSUnitLength kilometers], provided, NSFormattingUnitStyleLong), @"2 kilometers");
    revenant_expect_string("a short style closes up the symbol", revenant_measure(@"en_US", 5, [NSUnitLength kilometers], provided, NSFormattingUnitStyleShort), @"5km");
    revenant_expect_string("the natural scale picks kilometers", revenant_measure(@"en_US", 5000, [NSUnitLength meters], provided | natural, NSFormattingUnitStyleMedium), @"5 km");
    revenant_expect_string("the natural scale keeps meters below a kilometer", revenant_measure(@"en_US", 500, [NSUnitLength meters], provided | natural, NSFormattingUnitStyleMedium), @"500 m");
    revenant_expect_string("the natural scale picks hours", revenant_measure(@"en_US", 5000, [NSUnitDuration seconds], provided | natural, NSFormattingUnitStyleMedium), @"1.389 hr");
    revenant_expect_string("the natural scale picks gigabytes", revenant_measure(@"en_US", 5e9, [NSUnitInformationStorage bytes], provided | natural, NSFormattingUnitStyleMedium), @"5 GB");
    revenant_expect_string("a temperature can drop its unit", revenant_measure(@"en_US", 21, [NSUnitTemperature celsius], provided | NSMeasurementFormatterUnitOptionsTemperatureWithoutUnit, NSFormattingUnitStyleMedium), @"21°");
    NSMeasurementFormatter *formatter = [[NSMeasurementFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US"];
    formatter.unitStyle = NSFormattingUnitStyleLong;
    revenant_expect_string("a unit alone is named", [formatter stringFromUnit:[NSUnitLength kilometers]], @"kilometers");
    NSMeasurementFormatter *copy = [formatter copy];
    revenant_check(copy.unitStyle == NSFormattingUnitStyleLong && [copy.locale.localeIdentifier isEqualToString:@"en_US"], "a copy keeps the style and the locale", @"differs");
    return revenant_finish();
}
