#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>
#import <objc/message.h>

CF_EXPORT CFDateFormatterRef CFDateFormatterCreateISO8601Formatter(CFAllocatorRef allocator,
                                                                   CFISO8601DateFormatOptions options);
/* The backport's own pattern builder, which is what the formatter is assembled from. */
extern NSString *charon_iso8601_pattern(NSISO8601DateFormatOptions options);

static int checks;
static int failures;

static void fail(NSString *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    NSString *text = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    printf("FAIL %s\n", text.UTF8String);
    failures++;
}

static void same_object(id ours, id theirs, NSString *what)
{
    checks++;
    if (ours == theirs || [ours isEqual:theirs])
        return;
    fail(@"%@: ours %@, Foundation %@", what, ours, theirs);
}

int main(void)
{
    @autoreleasepool {
        Class mine = NSClassFromString(@"CharonHostNSISO8601DateFormatter");
        if (!mine) {
            printf("FAIL the backport defines no NSISO8601DateFormatter\n");
            return 1;
        }
        const NSISO8601DateFormatOptions flags[] = {
            NSISO8601DateFormatWithYear, NSISO8601DateFormatWithMonth, NSISO8601DateFormatWithWeekOfYear,
            NSISO8601DateFormatWithDay, NSISO8601DateFormatWithTime, NSISO8601DateFormatWithTimeZone,
            NSISO8601DateFormatWithSpaceBetweenDateAndTime, NSISO8601DateFormatWithDashSeparatorInDate,
            NSISO8601DateFormatWithColonSeparatorInTime, NSISO8601DateFormatWithColonSeparatorInTimeZone,
            NSISO8601DateFormatWithFractionalSeconds };

        /* Every combination of the eleven options, held to the pattern the real
           CFDateFormatterCreateISO8601Formatter builds. */
        for (unsigned mask = 0; mask < 2048; mask++) {
            NSISO8601DateFormatOptions options = 0;
            for (unsigned bit = 0; bit < 11; bit++)
                if (mask & (1u << bit))
                    options |= flags[bit];
            CFDateFormatterRef theirs = CFDateFormatterCreateISO8601Formatter(NULL, (CFISO8601DateFormatOptions)options);
            NSString *theirPattern = theirs ? (__bridge NSString *)CFDateFormatterGetFormat(theirs) : @"";
            NSString *ourPattern = charon_iso8601_pattern(options);
            same_object(ourPattern ? ourPattern : @"", theirPattern ? theirPattern : @"",
                        [NSString stringWithFormat:@"the pattern for options %#lx", (unsigned long)options]);
            if (theirs)
                CFRelease(theirs);
        }

        /* And what the formatter makes of real dates, in several zones. */
        NSArray *dates = @[[NSDate dateWithTimeIntervalSinceReferenceDate:0],
                           [NSDate dateWithTimeIntervalSinceReferenceDate:0.25],
                           [NSDate dateWithTimeIntervalSinceReferenceDate:-0.25],
                           [NSDate dateWithTimeIntervalSinceReferenceDate:1234567.891],
                           [NSDate dateWithTimeIntervalSince1970:0],
                           [NSDate dateWithTimeIntervalSince1970:1600000000]];
        NSArray *zones = @[@"GMT", @"America/New_York", @"Asia/Tokyo", @"Europe/Moscow"];
        const NSISO8601DateFormatOptions interesting[] = {
            NSISO8601DateFormatWithInternetDateTime,
            NSISO8601DateFormatWithFullDate,
            NSISO8601DateFormatWithFullTime,
            NSISO8601DateFormatWithFullDate | NSISO8601DateFormatWithFullTime,
            NSISO8601DateFormatWithYear | NSISO8601DateFormatWithMonth | NSISO8601DateFormatWithDay,
            NSISO8601DateFormatWithYear | NSISO8601DateFormatWithWeekOfYear | NSISO8601DateFormatWithDay
                | NSISO8601DateFormatWithDashSeparatorInDate,
            NSISO8601DateFormatWithTime | NSISO8601DateFormatWithColonSeparatorInTime,
            NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds,
            NSISO8601DateFormatWithTime | NSISO8601DateFormatWithFractionalSeconds };
        for (unsigned index = 0; index < sizeof(interesting) / sizeof(*interesting); index++)
            for (NSString *zoneName in zones)
                for (NSDate *date in dates) {
                    NSTimeZone *zone = [NSTimeZone timeZoneWithName:zoneName];
                    NSISO8601DateFormatter *them = [[NSISO8601DateFormatter alloc] init];
                    them.timeZone = zone;
                    them.formatOptions = interesting[index];
                    id us = [[mine alloc] init];
                    ((void (*)(id, SEL, id))objc_msgSend)(us, @selector(setTimeZone:), zone);
                    ((void (*)(id, SEL, NSUInteger))objc_msgSend)(us, @selector(setFormatOptions:), interesting[index]);
                    NSString *theirText = [them stringFromDate:date];
                    NSString *ourText = ((id (*)(id, SEL, id))objc_msgSend)(us, @selector(stringFromDate:), date);
                    NSString *what = [NSString stringWithFormat:@"%#lx in %@ of %@",
                                      (unsigned long)interesting[index], zoneName, date];
                    same_object(ourText, theirText, what);
                    if (!theirText.length)
                        continue;
                    NSDate *theirBack = [them dateFromString:theirText];
                    NSDate *ourBack = ((id (*)(id, SEL, id))objc_msgSend)(us, @selector(dateFromString:), theirText);
                    same_object(ourBack, theirBack, [what stringByAppendingString:@" read back"]);
                }

        /* A fresh formatter, and what it refuses. */
        NSISO8601DateFormatter *themPlain = [[NSISO8601DateFormatter alloc] init];
        id usPlain = [[mine alloc] init];
        same_object(((id (*)(id, SEL))objc_msgSend)(usPlain, @selector(timeZone)), themPlain.timeZone,
                    @"a fresh formatter's time zone");
        checks++;
        if (((NSUInteger (*)(id, SEL))objc_msgSend)(usPlain, @selector(formatOptions)) != themPlain.formatOptions)
            fail(@"a fresh formatter's options: ours %#lx, Foundation %#lx",
                 (unsigned long)((NSUInteger (*)(id, SEL))objc_msgSend)(usPlain, @selector(formatOptions)),
                 (unsigned long)themPlain.formatOptions);
        same_object(((id (*)(id, SEL, id))objc_msgSend)(usPlain, @selector(dateFromString:), @"not a date"),
                    [themPlain dateFromString:@"not a date"], @"a string that is not a date");
        same_object(((id (*)(id, SEL, id))objc_msgSend)(usPlain, @selector(dateFromString:), @""),
                    [themPlain dateFromString:@""], @"an empty string");

        id usFraction = [[mine alloc] init];
        NSISO8601DateFormatter *themFraction = [[NSISO8601DateFormatter alloc] init];
        NSISO8601DateFormatOptions fraction = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
        ((void (*)(id, SEL, NSUInteger))objc_msgSend)(usFraction, @selector(setFormatOptions:), fraction);
        themFraction.formatOptions = fraction;
        for (NSString *text in @[@"2001-01-01T12:00:00Z", @"2001-01-01T12:00:00.1Z", @"2001-01-01T12:00:00.12Z",
                                 @"2001-01-01T12:00:00.123Z", @"2001-01-01T12:00:00.123456Z"]) {
            same_object(((id (*)(id, SEL, id))objc_msgSend)(usFraction, @selector(dateFromString:), text),
                        [themFraction dateFromString:text], [@"with fractional seconds, " stringByAppendingString:text]);
            same_object(((id (*)(id, SEL, id))objc_msgSend)(usPlain, @selector(dateFromString:), text),
                        [themPlain dateFromString:text], [@"without them, " stringByAppendingString:text]);
        }
        NSString *(^refusal)(void (^)(void)) = ^(void (^block)(void)) {
            @try {
                block();
            } @catch (NSException *exception) {
                return [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
            }
            return @"nothing";
        };
        same_object(refusal(^{ ((void (*)(id, SEL, NSUInteger))objc_msgSend)(usPlain, @selector(setFormatOptions:), 1u << 20); }),
                    refusal(^{ themPlain.formatOptions = 1u << 20; }), @"an option that is none of them");

        printf("%d checks, %d failures\n", checks, failures);
    }
    return failures;
}
