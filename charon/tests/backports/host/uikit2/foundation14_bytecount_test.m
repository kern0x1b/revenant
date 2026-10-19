#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "check.h"

static uint64_t state = 0xB17EC0117ull;

static uint32_t next(void)
{
    state = state * 6364136223846793005ull + 1442695040888963407ull;
    return (uint32_t)(state >> 33);
}

static NSString *host_selector(NSString *name)
{
    return [@"charonHost" stringByAppendingString:[[name substringToIndex:1].uppercaseString stringByAppendingString:[name substringFromIndex:1]]];
}

static NSString *significant(NSString *text)
{
    NSMutableString *digits = [NSMutableString string];
    for (NSUInteger index = 0; index < text.length; index++) {
        unichar c = [text characterAtIndex:index];
        if (c >= '0' && c <= '9')
            [digits appendFormat:@"%C", c];
    }
    return digits;
}

static double magnitude_of(NSString *text)
{
    NSString *decimal = [[NSLocale currentLocale] objectForKey:NSLocaleDecimalSeparator];
    NSMutableString *number = [NSMutableString string];
    BOOL started = NO;
    for (NSUInteger index = 0; index < text.length; index++) {
        NSString *c = [text substringWithRange:NSMakeRange(index, 1)];
        if ([text characterAtIndex:index] == '(')
            break;
        if ([c isEqualToString:decimal])
            [number appendString:@"."];
        else if ([text characterAtIndex:index] >= '0' && [text characterAtIndex:index] <= '9') {
            [number appendString:c];
            started = YES;
        } else if ([c isEqualToString:@"-"] && !started)
            [number appendString:@"-"];
    }
    return number.doubleValue;
}

static NSString *letters_of(NSString *text)
{
    NSMutableString *letters = [NSMutableString string];
    for (NSUInteger index = 0; index < text.length; index++) {
        unichar c = [text characterAtIndex:index];
        if (c == '(')
            break;
        if ([[NSCharacterSet letterCharacterSet] characterIsMember:c])
            [letters appendFormat:@"%C", c];
    }
    return letters;
}

static NSString *safely(NSString *(^block)(void))
{
    @try {
        return block() ?: @"(nil)";
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"raises %@ | %@", exception.name, [[exception.reason stringByReplacingOccurrencesOfString:@"CharonHost" withString:@""] stringByReplacingOccurrencesOfString:@"_NSStatic_" withString:@""]];
    }
}

static BOOL last_digits_only(NSString *a, NSString *b)
{
    NSCharacterSet *digits = [NSCharacterSet decimalDigitCharacterSet];
    NSMutableString *da = [NSMutableString string], *db = [NSMutableString string], *ka = [NSMutableString string], *kb = [NSMutableString string];
    for (NSUInteger i = 0; i < a.length; i++) {
        unichar c = [a characterAtIndex:i];
        [digits characterIsMember:c] ? [da appendFormat:@"%C", c] : (c == '.' || c == ',' || c == 0x202F || c == 0xA0 || c == '\'' ? (void)0 : [ka appendFormat:@"%C", c]);
    }
    for (NSUInteger i = 0; i < b.length; i++) {
        unichar c = [b characterAtIndex:i];
        [digits characterIsMember:c] ? [db appendFormat:@"%C", c] : (c == '.' || c == ',' || c == 0x202F || c == 0xA0 || c == '\'' ? (void)0 : [kb appendFormat:@"%C", c]);
    }
    return da.length >= 16 && da.length == db.length && [ka isEqualToString:kb] && [[da substringToIndex:15] isEqualToString:[db substringToIndex:15]];
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        Class ours = NSClassFromString(@"CharonHostNSUnitInformationStorage");
        Class ourMeasurement = NSClassFromString(@"CharonHostNSMeasurement");
        Class ourLength = NSClassFromString(@"CharonHostNSUnitLength");
        NSArray *names = @[@"bits", @"nibbles", @"bytes", @"kilobits", @"kilobytes", @"kibibits", @"kibibytes", @"megabits", @"megabytes", @"mebibits", @"mebibytes", @"gigabits", @"gigabytes",
                           @"gibibits", @"gibibytes", @"terabits", @"terabytes", @"tebibits", @"tebibytes", @"petabits", @"petabytes", @"pebibits", @"pebibytes", @"exabits", @"exabytes",
                           @"exbibits", @"exbibytes", @"zettabits", @"zettabytes", @"zebibits", @"zebibytes", @"yottabits", @"yottabytes", @"yobibits", @"yobibytes"];
        NSUInteger cases = argc > 1 ? (NSUInteger)atoi(argv[1]) : 30000, wrong = 0;
        NSMutableArray *samples = [NSMutableArray array];
        for (NSUInteger index = 0; index < cases; index++) {
            NSString *unit = names[next() % names.count];
            double magnitude = pow(10.0, (double)(int)(next() % 34) - 4.0);
            double value = next() % 20 == 0 ? (double)(int)(next() % 3) : ((double)next() / 2147483648.0) * magnitude * (next() % 6 == 0 ? -1 : 1);
            if (next() % 60 == 0)
                value = next() % 3 == 0 ? NAN : (next() % 2 ? INFINITY : -INFINITY);
            NSMeasurement *system = [[NSMeasurement alloc] initWithDoubleValue:value unit:((id (*)(id, SEL))objc_msgSend)([NSUnitInformationStorage class], NSSelectorFromString(unit))];
            id port = ((id (*)(id, SEL, double, id))objc_msgSend)([ourMeasurement alloc], @selector(initWithDoubleValue:unit:), value, ((id (*)(id, SEL))objc_msgSend)(ours, NSSelectorFromString(unit)));
            NSByteCountFormatter *formatter = [[NSByteCountFormatter alloc] init];
            formatter.countStyle = (NSByteCountFormatterCountStyle)(next() % 4);
            if (next() % 3 == 0) {
                unsigned mask = (unsigned)(next() % 3 ? (1u << (next() % 9)) : (next() % 512));
                double inBytes = [[system measurementByConvertingToUnit:[NSUnitInformationStorage bytes]] doubleValue];
                BOOL beyond = !isnan(inBytes) && fabs(inBytes) >= 9.2e18;
                if (beyond && (mask & (mask - 1)) != 0 && mask != 0x1ff)
                    mask = 0;
                formatter.allowedUnits = (NSByteCountFormatterUnits)mask;
            }
            formatter.includesUnit = next() % 6 != 0;
            formatter.includesCount = next() % 6 != 0;
            formatter.includesActualByteCount = next() % 5 == 0;
            formatter.zeroPadsFractionDigits = next() % 4 == 0;
            formatter.adaptive = next() % 3 != 0;
            NSString *a = safely(^{ return ((id (*)(id, SEL, id))objc_msgSend)(formatter, NSSelectorFromString(host_selector(@"stringFromMeasurement:")), port); });
            NSString *b = safely(^{ return [formatter stringFromMeasurement:system]; });
            if (![a isEqualToString:b] && !last_digits_only(a, b) && !([a hasPrefix:@"-"] && ![b hasPrefix:@"-"] && a.length >= 18)) {
                wrong++;
                if (samples.count < 12)
                    [samples addObject:[NSString stringWithFormat:@"%.17g %@ style %ld allowed %lx unit %d count %d actual %d pad %d adaptive %d\n     port   %@\n     system %@", value, unit, (long)formatter.countStyle, (unsigned long)formatter.allowedUnits, formatter.includesUnit, formatter.includesCount, formatter.includesActualByteCount, formatter.zeroPadsFractionDigits, formatter.adaptive, a, b]];
            }
        }
        for (NSString *sample in samples)
            printf("  %s\n", sample.UTF8String);
        charon_check(wrong == 0, "random measurements in random units read as the system's formatter writes them", [NSString stringWithFormat:@"%lu of %lu differ", (unsigned long)wrong, (unsigned long)cases]);

        for (NSNumber *style in @[@0, @1, @2, @3]) {
            NSMeasurement *system = [[NSMeasurement alloc] initWithDoubleValue:1234.5 unit:[NSUnitInformationStorage kilobytes]];
            id port = ((id (*)(id, SEL, double, id))objc_msgSend)([ourMeasurement alloc], @selector(initWithDoubleValue:unit:), 1234.5, ((id (*)(id, SEL))objc_msgSend)(ours, @selector(kilobytes)));
            NSString *a = ((id (*)(id, SEL, id, NSInteger))objc_msgSend)([NSByteCountFormatter class], NSSelectorFromString(host_selector(@"stringFromMeasurement:countStyle:")), port, style.integerValue);
            CHECK_EQUAL(a, [NSByteCountFormatter stringFromMeasurement:system countStyle:(NSByteCountFormatterCountStyle)style.integerValue], "the class method formats with a fresh formatter of the count style");
        }
        NSByteCountFormatter *formatter = [[NSByteCountFormatter alloc] init];
        id length = ((id (*)(id, SEL, double, id))objc_msgSend)([ourMeasurement alloc], @selector(initWithDoubleValue:unit:), 5.0, ((id (*)(id, SEL))objc_msgSend)(ourLength, @selector(meters)));
        NSString *a = safely(^{ return ((id (*)(id, SEL, id))objc_msgSend)(formatter, NSSelectorFromString(host_selector(@"stringFromMeasurement:")), length); });
        NSString *b = safely(^{ return [formatter stringFromMeasurement:[[NSMeasurement alloc] initWithDoubleValue:5 unit:[NSUnitLength meters]]]; });
        CHECK_EQUAL(a, b, "a measurement of another dimension raises the system's exception");
        a = safely(^{ return ((id (*)(id, SEL, id))objc_msgSend)(formatter, NSSelectorFromString(host_selector(@"stringFromMeasurement:")), nil); });
        b = safely(^{ return [formatter stringFromMeasurement:nil]; });
        CHECK_EQUAL(a, b, "no measurement raises the system's exception");
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures;
}
