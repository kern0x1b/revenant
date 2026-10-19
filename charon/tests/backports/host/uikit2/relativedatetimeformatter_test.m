#import <Foundation/Foundation.h>
#import "check.h"

static uint64_t state = 0x2545F4914F6CDD1Dull;

static uint32_t next(void)
{
    state = state * 6364136223846793005ull + 1442695040888963407ull;
    return (uint32_t)(state >> 33);
}

static NSString *safely(NSString *(^block)(void))
{
    @try {
        return block() ?: @"(nil)";
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"raises %@", exception.name];
    }
}

static void configure(id formatter, NSDictionary *config)
{
    [formatter setDateTimeStyle:[config[@"style"] integerValue]];
    [formatter setUnitsStyle:[config[@"units"] integerValue]];
    [formatter setFormattingContext:[config[@"context"] integerValue]];
    [formatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US"]];
    NSCalendar *calendar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    calendar.timeZone = [NSTimeZone timeZoneWithName:config[@"zone"]];
    [formatter setCalendar:calendar];
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        Class ours = NSClassFromString(@"CharonHostNSRelativeDateTimeFormatter");
        CHECK(ours != Nil, "the port defines the class");
        id fresh = [[ours alloc] init], theirs = [[NSRelativeDateTimeFormatter alloc] init];
        CHECK_EQUAL(@([fresh dateTimeStyle]), @([theirs dateTimeStyle]), "the date time style starts numeric");
        CHECK_EQUAL(@([fresh unitsStyle]), @([theirs unitsStyle]), "the units style starts full");
        CHECK_EQUAL(@([fresh formattingContext]), @([theirs formattingContext]), "the formatting context starts unknown");
        CHECK_EQUAL([[fresh calendar] calendarIdentifier], [[theirs calendar] calendarIdentifier], "the calendar starts as the current one");
        CHECK_EQUAL([[[fresh locale] localeIdentifier] description], [[[theirs locale] localeIdentifier] description], "the locale starts as the current one");
        CHECK([fresh stringForObjectValue:@5] == nil && [theirs stringForObjectValue:@5] == nil, "a value that is not a date has no string");
        CHECK([fresh stringForObjectValue:[NSDate date]] != nil, "a date has one");
        id copied = [fresh copy];
        [fresh setUnitsStyle:3];
        [fresh setDateTimeStyle:1];
        [fresh setFormattingContext:4];
        copied = [fresh copy];
        CHECK([copied unitsStyle] == 3 && [copied dateTimeStyle] == 1 && [copied formattingContext] == 4, "a copy keeps the styles");

        NSUInteger cases = argc > 1 ? (NSUInteger)atoi(argv[1]) : 4000;
        NSArray *zones = @[@"UTC", @"America/New_York", @"Asia/Kolkata", @"Pacific/Auckland", @"Europe/Kyiv"];
        NSMutableDictionary *mismatches = [NSMutableDictionary dictionary];
        NSMutableArray *samples = [NSMutableArray array];
        NSUInteger total = 0, wrong = 0;
        for (NSUInteger index = 0; index < cases; index++) {
            NSDictionary *config = @{@"style": @(next() % 2), @"units": @(next() % 4), @"context": @(next() % 6), @"zone": zones[next() % zones.count]};
            id one = [[ours alloc] init];
            NSRelativeDateTimeFormatter *two = [[NSRelativeDateTimeFormatter alloc] init];
            configure(one, config);
            configure(two, config);
            NSDate *reference = [NSDate dateWithTimeIntervalSinceReferenceDate:(double)(next() % 1300000000) - 200000000 + (next() % 4 ? 0 : (next() % 1000) / 1000.0)];
            for (int probe = 0; probe < 10; probe++) {
                double span;
                switch (next() % 8) {
                case 0: span = next() % 200; break;
                case 1: span = (next() % 300) * 60 + next() % 60; break;
                case 2: span = (next() % 100) * 3600 + next() % 3600; break;
                case 3: span = (next() % 40) * 86400 + next() % 86400; break;
                case 4: span = (next() % 400) * 86400 + next() % 86400; break;
                case 5: span = (double)(next() % 60) * 31536000 + next() % 31536000; break;
                case 6: span = (next() % 90000) / 4.0 + (next() % 1000) / 1000.0; break;
                default: span = (double)(next() % 8) * 86400 + (next() % 3 ? 0 : next() % 120); break;
                }
                if (next() % 2)
                    span = -span;
                NSDate *date = [reference dateByAddingTimeInterval:span];
                NSString *a = safely(^{ return [one localizedStringForDate:date relativeToDate:reference]; });
                NSString *b = safely(^{ return [two localizedStringForDate:date relativeToDate:reference]; });
                total++;
                if (![a isEqualToString:b]) {
                    wrong++;
                    NSString *key = [NSString stringWithFormat:@"style%@ units%@", config[@"style"], config[@"units"]];
                    mismatches[key] = @([mismatches[key] integerValue] + 1);
                    if (samples.count < 30)
                        [samples addObject:[NSString stringWithFormat:@"%@ ctx=%@ zone=%@ ref=%.3f span=%g\n     port   %@\n     system %@", key, config[@"context"], config[@"zone"], reference.timeIntervalSinceReferenceDate, span, a, b]];
                }
            }
            for (int probe = 0; probe < 4; probe++) {
                NSDateComponents *components = [[NSDateComponents alloc] init];
                for (int field = 0; field < 8; field++) {
                    if (next() % 3 == 0)
                        continue;
                    NSInteger value = next() % 4 == 0 ? 0 : (NSInteger)(next() % 50) - 25;
                    switch (field) {
                    case 0: components.year = value; break;
                    case 1: components.month = value; break;
                    case 2: components.weekOfMonth = value; break;
                    case 3: components.day = value; break;
                    case 4: components.hour = value; break;
                    case 5: components.minute = value; break;
                    case 6: components.second = value; break;
                    default: if (next() % 3 == 0) components.weekOfYear = value; break;
                    }
                }
                NSString *a = safely(^{ return [one localizedStringFromDateComponents:components]; });
                NSString *b = safely(^{ return [two localizedStringFromDateComponents:components]; });
                total++;
                if (![a isEqualToString:b]) {
                    wrong++;
                    NSString *key = @"components";
                    mismatches[key] = @([mismatches[key] integerValue] + 1);
                    if (samples.count < 30)
                        [samples addObject:[NSString stringWithFormat:@"components style=%@ units=%@ ctx=%@ %@\n     port   %@\n     system %@", config[@"style"], config[@"units"], config[@"context"], components, a, b]];
                }
            }
        }
        printf("compared %lu, differing %lu (%.2f%%)\n", (unsigned long)total, (unsigned long)wrong, total ? 100.0 * wrong / total : 0);
        for (NSString *sample in samples)
            printf("  %s\n", sample.UTF8String);
        for (NSString *key in [mismatches.allKeys sortedArrayUsingSelector:@selector(compare:)])
            printf("  %s: %ld\n", key.UTF8String, (long)[mismatches[key] integerValue]);
        charon_check(wrong == 0, "the formatter answers as the system's for every random configuration", [NSString stringWithFormat:@"%lu of %lu differ", (unsigned long)wrong, (unsigned long)total]);
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures;
}
