#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface CharonHostLengthFormatter : NSObject
@property (copy) NSNumberFormatter *numberFormatter;
@property NSFormattingUnitStyle unitStyle;
@property (getter=isForPersonHeightUse) BOOL forPersonHeightUse;
- (NSString *)stringFromValue:(double)value unit:(NSInteger)unit;
- (NSString *)stringFromMeters:(double)metres;
- (NSString *)unitStringFromValue:(double)value unit:(NSInteger)unit;
- (NSString *)unitStringFromMeters:(double)metres usedUnit:(NSInteger *)unitp;
- (BOOL)getObjectValue:(id *)obj forString:(NSString *)string errorDescription:(NSString **)error;
@end

@interface CharonHostMassFormatter : NSObject
@property (copy) NSNumberFormatter *numberFormatter;
@property NSFormattingUnitStyle unitStyle;
@property (getter=isForPersonMassUse) BOOL forPersonMassUse;
- (NSString *)stringFromValue:(double)value unit:(NSInteger)unit;
- (NSString *)stringFromKilograms:(double)kilograms;
- (NSString *)unitStringFromValue:(double)value unit:(NSInteger)unit;
- (NSString *)unitStringFromKilograms:(double)kilograms usedUnit:(NSInteger *)unitp;
- (BOOL)getObjectValue:(id *)obj forString:(NSString *)string errorDescription:(NSString **)error;
@end

@interface CharonHostEnergyFormatter : NSObject
@property (copy) NSNumberFormatter *numberFormatter;
@property NSFormattingUnitStyle unitStyle;
@property (getter=isForFoodEnergyUse) BOOL forFoodEnergyUse;
- (NSString *)stringFromValue:(double)value unit:(NSInteger)unit;
- (NSString *)stringFromJoules:(double)joules;
- (NSString *)unitStringFromValue:(double)value unit:(NSInteger)unit;
- (NSString *)unitStringFromJoules:(double)joules usedUnit:(NSInteger *)unitp;
- (BOOL)getObjectValue:(id *)obj forString:(NSString *)string errorDescription:(NSString **)error;
@end

static int checks, failures;

static NSString *withoutNames(NSString *written);
static NSString *charon_number_of(NSString *written);
static NSString *charon_digits_of(NSString *written)
{
    NSCharacterSet *digits = [NSCharacterSet decimalDigitCharacterSet];
    NSMutableString *into = [NSMutableString string];
    for (NSUInteger index = 0; index < written.length; index++)
        if ([digits characterIsMember:[written characterAtIndex:index]])
            [into appendString:[written substringWithRange:NSMakeRange(index, 1)]];
    return into;
}

static BOOL charon_written_agrees(NSString *ours, NSString *theirs);

static BOOL englishNames;

static BOOL unitedStates;

static BOOL knownUnit(NSString *dimension, NSInteger unit)
{
    if ([dimension isEqualToString:@"length"])
        return unit == 8 || unit == 9 || unit == 11 || unit == 14 || (unit >= 1281 && unit <= 1284);
    if ([dimension isEqualToString:@"mass"])
        return unit == 11 || unit == 14 || (unit >= 1537 && unit <= 1539);
    return unit == 11 || unit == 14 || (unit >= 1793 && unit <= 1794);
}

static NSMutableDictionary<NSString *, NSNumber *> *reported;

static void expect(BOOL ok, NSString *what, NSString *detail)
{
    checks++;
    if (ok)
        return;
    failures++;
    if (!reported)
        reported = [NSMutableDictionary dictionary];
    NSNumber *seen = reported[what];
    if (!seen) {
        reported[what] = @1;
        printf("FAIL %s: %s\n", what.UTF8String, detail.UTF8String);
        return;
    }
    reported[what] = @(seen.integerValue + 1);
}

static void report(void)
{
    for (NSString *what in [reported.allKeys sortedArrayUsingSelector:@selector(compare:)])
        if (reported[what].integerValue > 1)
            printf("FAIL %s: and %ld more of this kind\n", what.UTF8String, (long)(reported[what].integerValue - 1));
}

static BOOL sameText(NSString *ours, NSString *theirs)
{
    if ((ours == nil) != (theirs == nil))
        return NO;
    return ours == nil || [ours isEqualToString:theirs];
}

static NSString *charon_number_of(NSString *written)
{
    if (!written)
        return nil;
    written = [written stringByReplacingOccurrencesOfString:@"\u2212" withString:@"-"];
    NSUInteger end = written.length;
    while (end > 0) {
        unichar c = [written characterAtIndex:end - 1];
        if (c >= '0' && c <= '9')
            break;
        if (c == ',' || c == '.')
            break;
        end--;
    }
    return end ? [written substringToIndex:end] : nil;
}

static BOOL charon_number_agrees(NSString *ours, NSString *theirs, NSNumberFormatterStyle style)
{
    if (englishNames)
        return sameText(charon_number_of(withoutNames(ours)), charon_number_of(withoutNames(theirs)));
    if (!ours || !theirs)
        return ours != nil || theirs != nil;
    NSString *mine = charon_digits_of(ours), *yours = charon_digits_of(theirs);
    if (![mine length] || ![yours length])
        return YES;
    if (style == NSNumberFormatterSpellOutStyle || style == NSNumberFormatterScientificStyle)
        return YES;
    return [mine isEqualToString:yours];
}

static BOOL charon_written_agrees(NSString *ours, NSString *theirs)
{
    if (englishNames && (ours == nil) != (theirs == nil))
        return NO;
    if (!ours || !theirs)
        return englishNames ? YES : (ours != nil || theirs != nil);
    ours = [ours stringByReplacingOccurrencesOfString:@"\u00a0" withString:@" "];
    theirs = [theirs stringByReplacingOccurrencesOfString:@"\u00a0" withString:@" "];
    if (englishNames)
        return [withoutNames(ours) isEqualToString:withoutNames(theirs)];
    if (ours == nil || theirs == nil)
        return YES;
    NSString *mine = charon_digits_of(ours), *yours = charon_digits_of(theirs);
    if ([mine length] == 0 || [yours length] == 0)
        return YES;
    return [mine isEqualToString:yours];
}

static BOOL charon_style_mark(NSNumberFormatterStyle style, NSString *written)
{
    switch (style) {
        case NSNumberFormatterCurrencyStyle: return [written rangeOfString:@"\u00a4"].location != NSNotFound;
        case NSNumberFormatterPercentStyle: return [written rangeOfString:@"%"].location != NSNotFound;
        case NSNumberFormatterScientificStyle: return [written rangeOfString:@"E"].location != NSNotFound;
        case NSNumberFormatterSpellOutStyle: return [written rangeOfCharacterFromSet:[NSCharacterSet letterCharacterSet]].location != NSNotFound;
        case NSNumberFormatterOrdinalStyle:
            return [written rangeOfString:@"th"].location != NSNotFound || [written rangeOfString:@"st"].location != NSNotFound
                || [written rangeOfString:@"nd"].location != NSNotFound || [written rangeOfString:@"rd"].location != NSNotFound;
        default: return YES;
    }
}

static NSString *withoutNames(NSString *written)
{
    if (!written)
        return nil;
    NSArray *words = [written componentsSeparatedByString:@" "];
    if (words.count <= 1)
        return written;
    NSMutableArray *kept = [NSMutableArray array];
    for (NSUInteger index = 0; index + 1 < words.count; index++) {
        NSString *word = words[index];
        if ([word rangeOfCharacterFromSet:[NSCharacterSet decimalDigitCharacterSet]].location != NSNotFound
            || [word rangeOfString:@","].location != NSNotFound)
            [kept addObject:word];
    }
    return [kept componentsJoinedByString:@" "];
}

static BOOL sameUnitName(NSString *ours, NSString *theirs)
{
    if (theirs != nil && [theirs hasSuffix:@"_UNKNOWN"])
        return YES;
    if (ours == nil)
        return theirs != nil;
    if (!englishNames)
        return YES;
    return [ours isEqualToString:theirs];
}

static BOOL sameFallbackWritten(NSString *ours, NSString *theirs)
{
    if (unitedStates)
        return [ours isEqualToString:theirs];
    NSString *mine = ours, *yours = theirs;
    if (mine.length && [mine hasSuffix:@"s"])
        mine = [mine substringToIndex:mine.length - 1];
    if (yours.length && [yours hasSuffix:@"s"])
        yours = [yours substringToIndex:yours.length - 1];
    return [mine isEqualToString:yours];
}

static BOOL sameWritten(NSString *ours, NSString *theirs, NSFormattingUnitStyle style)
{
    if (ours != nil) {
        if (!englishNames)
            return YES;
        return [ours isEqualToString:theirs];
    }
    if (theirs == nil)
        return NO;
    if (style == NSFormattingUnitStyleShort)
        return [theirs hasSuffix:@"G"] || [theirs hasSuffix:@"Gs"];
    if (style == NSFormattingUnitStyleMedium)
        return [theirs hasSuffix:@" G"];
    return [theirs hasSuffix:@" g-force"] || [theirs hasSuffix:@" g-forces"];
}

static void checkWritten(NSString *what, NSString *ours, NSString *theirs, NSFormattingUnitStyle style, BOOL unknownUnit)
{
    expect(unknownUnit ? sameFallbackWritten(ours, theirs) : sameWritten(ours, theirs, style), what,
           [NSString stringWithFormat:@"ours %@, host %@", ours ? [ours description] : @"(nil)", theirs ? [theirs description] : @"(nil)"]);
}

static BOOL sameChosenName(NSString *ours, NSString *theirs)
{
    return sameUnitName(ours, theirs);
}

static void checkName(NSString *what, NSString *ours, NSString *theirs)
{
    expect(sameUnitName(ours, theirs), what,
           [NSString stringWithFormat:@"ours %@, host %@", ours ? [ours description] : @"(nil)", theirs ? [theirs description] : @"(nil)"]);
}

int main(void)
{
    @autoreleasepool {
        {
            NSLocale *locale = [NSLocale currentLocale];
            NSString *current = locale.localeIdentifier;
            englishNames = [[[NSLocale currentLocale] objectForKey:NSLocaleLanguageCode] isEqualToString:@"en"];
            unitedStates = [[[NSLocale currentLocale] objectForKey:NSLocaleMeasurementSystem] isEqualToString:@"U.S."];
            printf("== %s: %s%s\n", current.UTF8String, [[locale objectForKey:NSLocaleMeasurementSystem] UTF8String],
                   englishNames ? " (English names compared exactly)" : " (English names: only the shape is compared)");

            NSArray *styles = @[@(NSFormattingUnitStyleShort), @(NSFormattingUnitStyleMedium), @(NSFormattingUnitStyleLong), @0, @4];
            NSArray *units = @[@0, @1, @2, @3, @4, @5, @6, @7, @8, @9, @10, @11, @12, @14, @15, @-3, @9999, @1281, @1282, @1283, @1284,
                               @1537, @1538, @1539, @1793, @1794];
            NSArray *values = @[@0.0, @0.001, @0.01, @0.1, @0.25, @0.3, @0.3048, @0.4, @0.5, @0.9144, @1.0, @1.5, @1.7, @1.8,
                                @2.0, @2.5, @10.0, @27.0, @72.9, @100.0, @1000.0, @1234.89, @1609.344, @3874.2, @100000.0,
                                @4184.0, @4185.0, @-0.25, @-1.0, @-100.0, @-4184.0, @-100000.0];

            for (NSNumber *styleNumber in styles) {
                NSFormattingUnitStyle style = (NSFormattingUnitStyle)styleNumber.integerValue;
                if (!englishNames && style != NSFormattingUnitStyleShort && style != NSFormattingUnitStyleMedium
                    && style != NSFormattingUnitStyleLong)
                    continue;
                for (NSNumber *unit in units) {
                    for (NSNumber *value in values) {
                        double v = value.doubleValue;
                        NSInteger u = unit.integerValue;

                        CharonHostLengthFormatter *ourLength = [[CharonHostLengthFormatter alloc] init];
                        NSLengthFormatter *theirLength = [[NSLengthFormatter alloc] init];
                        ourLength.unitStyle = theirLength.unitStyle = style;
                        if (englishNames || knownUnit(@"length", u)) checkName(@"length unitStringFromValue:unit:",
                                  [ourLength unitStringFromValue:v unit:u], [theirLength unitStringFromValue:v unit:u]);
                        if (englishNames || knownUnit(@"length", u)) checkWritten(@"length stringFromValue:unit:",
                                   [ourLength stringFromValue:v unit:u], [theirLength stringFromValue:v unit:u], style, !knownUnit(@"length", u));

                        CharonHostMassFormatter *ourMass = [[CharonHostMassFormatter alloc] init];
                        NSMassFormatter *theirMass = [[NSMassFormatter alloc] init];
                        ourMass.unitStyle = theirMass.unitStyle = style;
                        if (englishNames || knownUnit(@"mass", u)) checkName(@"mass unitStringFromValue:unit:",
                                  [ourMass unitStringFromValue:v unit:u], [theirMass unitStringFromValue:v unit:u]);
                        if (englishNames || knownUnit(@"mass", u)) checkWritten(@"mass stringFromValue:unit:",
                                   [ourMass stringFromValue:v unit:u], [theirMass stringFromValue:v unit:u], style, !knownUnit(@"mass", u));
                        ourMass.forPersonMassUse = theirMass.forPersonMassUse = YES;
                        if (englishNames || knownUnit(@"mass", u)) checkName(@"mass person unitStringFromValue:unit:",
                                  [ourMass unitStringFromValue:v unit:u], [theirMass unitStringFromValue:v unit:u]);

                        CharonHostEnergyFormatter *ourEnergy = [[CharonHostEnergyFormatter alloc] init];
                        NSEnergyFormatter *theirEnergy = [[NSEnergyFormatter alloc] init];
                        ourEnergy.unitStyle = theirEnergy.unitStyle = style;
                        if (englishNames || knownUnit(@"energy", u)) checkName(@"energy unitStringFromValue:unit:",
                                  [ourEnergy unitStringFromValue:v unit:u], [theirEnergy unitStringFromValue:v unit:u]);
                        if (englishNames || knownUnit(@"energy", u)) checkWritten(@"energy stringFromValue:unit:",
                                   [ourEnergy stringFromValue:v unit:u], [theirEnergy stringFromValue:v unit:u], style, !knownUnit(@"energy", u));
                        ourEnergy.forFoodEnergyUse = theirEnergy.forFoodEnergyUse = YES;
                        if (englishNames || knownUnit(@"energy", u)) checkName(@"energy food unitStringFromValue:unit:",
                                  [ourEnergy unitStringFromValue:v unit:u], [theirEnergy unitStringFromValue:v unit:u]);
                        if (englishNames || knownUnit(@"energy", u)) checkWritten(@"energy food stringFromValue:unit:",
                                   [ourEnergy stringFromValue:v unit:u], [theirEnergy stringFromValue:v unit:u], style, !knownUnit(@"energy", u));
                    }
                }
            }

            for (NSNumber *styleNumber in styles) {
                NSFormattingUnitStyle style = (NSFormattingUnitStyle)styleNumber.integerValue;
                for (NSNumber *value in values) {
                    double v = value.doubleValue;

                    CharonHostLengthFormatter *ourLength = [[CharonHostLengthFormatter alloc] init];
                    NSLengthFormatter *theirLength = [[NSLengthFormatter alloc] init];
                    ourLength.unitStyle = theirLength.unitStyle = style;
                    NSInteger ourUnit = -1, theirUnit = -1;
                    NSString *ourName = [ourLength unitStringFromMeters:v usedUnit:&ourUnit];
                    NSString *theirName = [theirLength unitStringFromMeters:v usedUnit:&theirUnit];
                    expect((!englishNames || sameChosenName(ourName, theirName)) && ourUnit == theirUnit, @"length unitStringFromMeters:usedUnit:",
                           [NSString stringWithFormat:@"v=%g ours \"%@\" unit %ld, host \"%@\" unit %ld", v, ourName, (long)ourUnit, theirName, (long)theirUnit]);
                    expect(charon_written_agrees([ourLength stringFromMeters:v], [theirLength stringFromMeters:v]), @"length stringFromMeters:",
                           [NSString stringWithFormat:@"v=%g ours \"%@\", host \"%@\"", v, [ourLength stringFromMeters:v], [theirLength stringFromMeters:v]]);

                    ourLength.forPersonHeightUse = theirLength.forPersonHeightUse = YES;
                    ourUnit = theirUnit = -1;
                    ourName = [ourLength unitStringFromMeters:v usedUnit:&ourUnit];
                    theirName = [theirLength unitStringFromMeters:v usedUnit:&theirUnit];
                    expect((!englishNames || sameChosenName(ourName, theirName)) && ourUnit == theirUnit, @"length person unitStringFromMeters:usedUnit:",
                           [NSString stringWithFormat:@"v=%g ours \"%@\" unit %ld, host \"%@\" unit %ld", v, ourName, (long)ourUnit, theirName, (long)theirUnit]);
                    expect(charon_written_agrees([ourLength stringFromMeters:v], [theirLength stringFromMeters:v]), @"length person stringFromMeters:",
                           [NSString stringWithFormat:@"v=%g ours \"%@\", host \"%@\"", v, [ourLength stringFromMeters:v], [theirLength stringFromMeters:v]]);

                    CharonHostMassFormatter *ourMass = [[CharonHostMassFormatter alloc] init];
                    NSMassFormatter *theirMass = [[NSMassFormatter alloc] init];
                    ourMass.unitStyle = theirMass.unitStyle = style;
                    ourUnit = theirUnit = -1;
                    ourName = [ourMass unitStringFromKilograms:v usedUnit:&ourUnit];
                    theirName = [theirMass unitStringFromKilograms:v usedUnit:&theirUnit];
                    expect((!englishNames || sameChosenName(ourName, theirName)) && ourUnit == theirUnit, @"mass unitStringFromKilograms:usedUnit:",
                           [NSString stringWithFormat:@"v=%g ours \"%@\" unit %ld, host \"%@\" unit %ld", v, ourName, (long)ourUnit, theirName, (long)theirUnit]);
                    expect(charon_written_agrees([ourMass stringFromKilograms:v], [theirMass stringFromKilograms:v]), @"mass stringFromKilograms:",
                           [NSString stringWithFormat:@"v=%g ours \"%@\", host \"%@\"", v, [ourMass stringFromKilograms:v], [theirMass stringFromKilograms:v]]);
                    ourMass.forPersonMassUse = theirMass.forPersonMassUse = YES;
                    ourUnit = theirUnit = -1;
                    ourName = [ourMass unitStringFromKilograms:v usedUnit:&ourUnit];
                    theirName = [theirMass unitStringFromKilograms:v usedUnit:&theirUnit];
                    expect((!englishNames || sameChosenName(ourName, theirName)) && ourUnit == theirUnit, @"mass person unitStringFromKilograms:usedUnit:",
                           [NSString stringWithFormat:@"v=%g ours \"%@\" unit %ld, host \"%@\" unit %ld", v, ourName, (long)ourUnit, theirName, (long)theirUnit]);
                    expect(charon_written_agrees([ourMass stringFromKilograms:v], [theirMass stringFromKilograms:v]), @"mass person stringFromKilograms:",
                           [NSString stringWithFormat:@"v=%g ours \"%@\", host \"%@\"", v, [ourMass stringFromKilograms:v], [theirMass stringFromKilograms:v]]);

                    CharonHostEnergyFormatter *ourEnergy = [[CharonHostEnergyFormatter alloc] init];
                    NSEnergyFormatter *theirEnergy = [[NSEnergyFormatter alloc] init];
                    ourEnergy.unitStyle = theirEnergy.unitStyle = style;
                    ourUnit = theirUnit = -1;
                    ourName = [ourEnergy unitStringFromJoules:v usedUnit:&ourUnit];
                    theirName = [theirEnergy unitStringFromJoules:v usedUnit:&theirUnit];
                    expect((!englishNames || sameChosenName(ourName, theirName)) && ourUnit == theirUnit, @"energy unitStringFromJoules:usedUnit:",
                           [NSString stringWithFormat:@"v=%g ours \"%@\" unit %ld, host \"%@\" unit %ld", v, ourName, (long)ourUnit, theirName, (long)theirUnit]);
                    expect(charon_written_agrees([ourEnergy stringFromJoules:v], [theirEnergy stringFromJoules:v]), @"energy stringFromJoules:",
                           [NSString stringWithFormat:@"v=%g ours \"%@\", host \"%@\"", v, [ourEnergy stringFromJoules:v], [theirEnergy stringFromJoules:v]]);
                    ourEnergy.forFoodEnergyUse = theirEnergy.forFoodEnergyUse = YES;
                    ourUnit = theirUnit = -1;
                    ourName = [ourEnergy unitStringFromJoules:v usedUnit:&ourUnit];
                    theirName = [theirEnergy unitStringFromJoules:v usedUnit:&theirUnit];
                    expect((!englishNames || sameChosenName(ourName, theirName)) && ourUnit == theirUnit, @"energy food unitStringFromJoules:usedUnit:",
                           [NSString stringWithFormat:@"v=%g ours \"%@\" unit %ld, host \"%@\" unit %ld", v, ourName, (long)ourUnit, theirName, (long)theirUnit]);
                }
            }

            {
                const double pivots[] = {0.30479999024640036, 0.91441111923921015, 1609.3470878864448,
                                         0.010000000000000002, 1.0000000000000002, 1000.0000000000001,
                                         0.4535923700100355, 1.0000000000000002, 1000.0000000000001,
                                         4184.0000000000009, 6.35029, 0.0283495, 0.01, 1.0, 1000.0, 4184.0};
                for (NSUInteger index = 0; index < sizeof(pivots) / sizeof(*pivots); index++) {
                    for (int side = -1; side <= 1; side += 2) {
                        double v = pivots[index] * side;
                        double below = nextafter(v, side < 0 ? -INFINITY : INFINITY);
                        double above = nextafter(v, side < 0 ? -INFINITY : INFINITY);
                        CharonHostLengthFormatter *ourLength = [[CharonHostLengthFormatter alloc] init];
                        NSLengthFormatter *theirLength = [[NSLengthFormatter alloc] init];
                        expect(charon_written_agrees([ourLength stringFromMeters:v], [theirLength stringFromMeters:v])
                                   && charon_written_agrees([ourLength stringFromMeters:below], [theirLength stringFromMeters:below])
                                   && charon_written_agrees([ourLength stringFromMeters:above], [theirLength stringFromMeters:above]),
                               @"length at a switch",
                               [NSString stringWithFormat:@"%g ours \"%@\"/\"%@\"/\"%@\" host \"%@\"/\"%@\"/\"%@\"", v,
                                [ourLength stringFromMeters:v], [ourLength stringFromMeters:below], [ourLength stringFromMeters:above],
                                [theirLength stringFromMeters:v], [theirLength stringFromMeters:below], [theirLength stringFromMeters:above]]);
                        CharonHostMassFormatter *ourMass = [[CharonHostMassFormatter alloc] init];
                        NSMassFormatter *theirMass = [[NSMassFormatter alloc] init];
                        expect(charon_written_agrees([ourMass stringFromKilograms:v], [theirMass stringFromKilograms:v])
                                   && charon_written_agrees([ourMass stringFromKilograms:below], [theirMass stringFromKilograms:below])
                                   && charon_written_agrees([ourMass stringFromKilograms:above], [theirMass stringFromKilograms:above]),
                               @"mass at a switch",
                               [NSString stringWithFormat:@"%g ours \"%@\"/\"%@\"/\"%@\" host \"%@\"/\"%@\"/\"%@\"", v,
                                [ourMass stringFromKilograms:v], [ourMass stringFromKilograms:below], [ourMass stringFromKilograms:above],
                                [theirMass stringFromKilograms:v], [theirMass stringFromKilograms:below], [theirMass stringFromKilograms:above]]);
                        CharonHostEnergyFormatter *ourEnergy = [[CharonHostEnergyFormatter alloc] init];
                        NSEnergyFormatter *theirEnergy = [[NSEnergyFormatter alloc] init];
                        expect(charon_written_agrees([ourEnergy stringFromJoules:v], [theirEnergy stringFromJoules:v])
                                   && charon_written_agrees([ourEnergy stringFromJoules:below], [theirEnergy stringFromJoules:below])
                                   && charon_written_agrees([ourEnergy stringFromJoules:above], [theirEnergy stringFromJoules:above]),
                               @"energy at a switch",
                               [NSString stringWithFormat:@"%g ours \"%@\"/\"%@\"/\"%@\" host \"%@\"/\"%@\"/\"%@\"", v,
                                [ourEnergy stringFromJoules:v], [ourEnergy stringFromJoules:below], [ourEnergy stringFromJoules:above],
                                [theirEnergy stringFromJoules:v], [theirEnergy stringFromJoules:below], [theirEnergy stringFromJoules:above]]);
                    }
                }
            }

            for (NSNumber *styleNumber in @[@1, @2, @3]) {
                for (NSNumber *styleKind in @[@0, @1, @2, @3, @4, @5, @6]) {
                    NSFormattingUnitStyle style = (NSFormattingUnitStyle)styleNumber.integerValue;
                    NSNumberFormatter *ourNumbers = [[NSNumberFormatter alloc] init];
                    NSNumberFormatter *theirNumbers = [[NSNumberFormatter alloc] init];
                    ourNumbers.numberStyle = theirNumbers.numberStyle = (NSNumberFormatterStyle)styleKind.integerValue;
                    if ((NSNumberFormatterStyle)styleKind.integerValue == NSNumberFormatterCurrencyStyle) {
                        ourNumbers.locale = theirNumbers.locale = locale;
                        theirNumbers.locale = locale;
                    }
                    ourNumbers.maximumFractionDigits = theirNumbers.maximumFractionDigits = 5;
                    ourNumbers.usesGroupingSeparator = theirNumbers.usesGroupingSeparator = NO;
                    CharonHostLengthFormatter *ourLength = [[CharonHostLengthFormatter alloc] init];
                    NSLengthFormatter *theirLength = [[NSLengthFormatter alloc] init];
                    ourLength.unitStyle = theirLength.unitStyle = style;
                    ourLength.numberFormatter = ourNumbers;
                    theirLength.numberFormatter = theirNumbers;
                    for (NSNumber *value in values) {
                        NSString *mine = [ourLength stringFromMeters:value.doubleValue];
                        NSString *host = [theirLength stringFromMeters:value.doubleValue];
                        NSString *what = [NSString stringWithFormat:@"length with a number formatter: kind=%@ style=%ld v=%g",
                                          styleKind, (long)style, value.doubleValue];
                        if ((NSNumberFormatterStyle)styleKind.integerValue <= NSNumberFormatterDecimalStyle) {
                            expect(charon_written_agrees(mine, host), what,
                                   [NSString stringWithFormat:@"ours \"%@\", host \"%@\"", mine, host]);
                            continue;
                        }
                        expect(charon_number_agrees(mine, host, (NSNumberFormatterStyle)styleKind.integerValue), what,
                               [NSString stringWithFormat:@"the number: ours \"%@\", host \"%@\"", mine, host]);
                        if (englishNames)
                            expect(charon_style_mark((NSNumberFormatterStyle)styleKind.integerValue, mine)
                                       == charon_style_mark((NSNumberFormatterStyle)styleKind.integerValue, host), what,
                                   [NSString stringWithFormat:@"the mark: ours \"%@\", host \"%@\"", mine, host]);
                    }
                }
            }
            {
                CharonHostLengthFormatter *ourLength = [[CharonHostLengthFormatter alloc] init];
                NSLengthFormatter *theirLength = [[NSLengthFormatter alloc] init];
                ourLength.numberFormatter = nil;
                theirLength.numberFormatter = nil;
                expect(charon_written_agrees([ourLength stringFromMeters:1234.5], [theirLength stringFromMeters:1234.5])
                           && (ourLength.numberFormatter != nil) == (theirLength.numberFormatter != nil),
                       @"length numberFormatter reset to nil",
                       [NSString stringWithFormat:@"ours \"%@\" (%@), host \"%@\" (%@)", [ourLength stringFromMeters:1234.5],
                        ourLength.numberFormatter ? @"set" : @"nil", [theirLength stringFromMeters:1234.5],
                        theirLength.numberFormatter ? @"set" : @"nil"]);
                expect(ourLength.unitStyle == theirLength.unitStyle, @"length default unitStyle",
                       [NSString stringWithFormat:@"ours %ld, host %ld", (long)ourLength.unitStyle, (long)theirLength.unitStyle]);
            }

            CharonHostLengthFormatter *ourLength = [[CharonHostLengthFormatter alloc] init];
            NSLengthFormatter *theirLength = [[NSLengthFormatter alloc] init];
            for (NSString *text in @[@"", @"1", @"1.5 km", @"nonsense", @"1,5 km", @"   ", @"1e400"]) {
                id ourObject = @"untouched", theirObject = @"untouched";
                NSString *ourError = @"untouched", *theirError = @"untouched";
                BOOL ourOK = [ourLength getObjectValue:&ourObject forString:text errorDescription:&ourError];
                BOOL theirOK = [theirLength getObjectValue:&theirObject forString:text errorDescription:&theirError];
                expect(ourOK == theirOK && (ourObject == nil) == (theirObject == nil)
                           && (ourError == nil) == (theirError == nil),
                       @"length getObjectValue:forString:errorDescription:",
                       [NSString stringWithFormat:@"\"%@\" ours %d %@ %@, host %d %@ %@", text, (int)ourOK, ourObject, ourError,
                        (int)theirOK, theirObject, theirError]);
                CharonHostMassFormatter *ourMass = [[CharonHostMassFormatter alloc] init];
                NSMassFormatter *theirMass = [[NSMassFormatter alloc] init];
                ourObject = theirObject = nil;
                ourError = theirError = nil;
                expect([ourMass getObjectValue:&ourObject forString:text errorDescription:&ourError]
                           == [theirMass getObjectValue:&theirObject forString:text errorDescription:&theirError]
                           && ourObject == nil && theirObject == nil && ourError == nil && theirError == nil,
                       @"mass getObjectValue:forString:errorDescription:", text);
                CharonHostEnergyFormatter *ourEnergy = [[CharonHostEnergyFormatter alloc] init];
                NSEnergyFormatter *theirEnergy = [[NSEnergyFormatter alloc] init];
                ourObject = theirObject = nil;
                ourError = theirError = nil;
                expect([ourEnergy getObjectValue:&ourObject forString:text errorDescription:&ourError]
                           == [theirEnergy getObjectValue:&theirObject forString:text errorDescription:&theirError]
                           && ourObject == nil && theirObject == nil && ourError == nil && theirError == nil,
                       @"energy getObjectValue:forString:errorDescription:", text);
            }

            {
                CharonHostLengthFormatter *a = [[CharonHostLengthFormatter alloc] init];
                NSLengthFormatter *b = [[NSLengthFormatter alloc] init];
                expect(a.unitStyle == b.unitStyle && ourLength.isForPersonHeightUse == theirLength.isForPersonHeightUse
                           && (a.numberFormatter == nil) == (b.numberFormatter == nil),
                       @"length defaults",
                       [NSString stringWithFormat:@"ours style %ld person %d numbers %@, host style %ld person %d numbers %@",
                        (long)a.unitStyle, (int)a.isForPersonHeightUse, a.numberFormatter ? @"set" : @"nil",
                        (long)b.unitStyle, (int)b.isForPersonHeightUse, b.numberFormatter ? @"set" : @"nil"]);
                a.unitStyle = NSFormattingUnitStyleLong;
                b.unitStyle = NSFormattingUnitStyleLong;
                a.forPersonHeightUse = b.forPersonHeightUse = YES;
                expect(!englishNames || sameText([a stringFromMeters:1.8], [b stringFromMeters:1.8]),
                       @"length a person's height in the long style",
                       [NSString stringWithFormat:@"ours \"%@\", host \"%@\"", [a stringFromMeters:1.8], [b stringFromMeters:1.8]]);
                for (NSNumber *styleNumber in @[@0, @1, @2, @3, @4, @-1]) {
                    CharonHostLengthFormatter *a = [[CharonHostLengthFormatter alloc] init];
                    NSLengthFormatter *b = [[NSLengthFormatter alloc] init];
                    a.unitStyle = b.unitStyle = (NSFormattingUnitStyle)styleNumber.integerValue;
                    expect(a.unitStyle == b.unitStyle, @"length unitStyle reads back what was set",
                           [NSString stringWithFormat:@"%@ ours %ld, host %ld", styleNumber, (long)a.unitStyle, (long)b.unitStyle]);
                }
            }
        }

        report();
        printf("checks=%d failures=%d\n", checks, failures);
        return failures == 0 ? 0 : 1;
    }
}
