#import <Foundation/Foundation.h>
#import "check.h"
#import "datecomponents-cases.h"
#import "datecomponents-expectations.h"

@interface CharonHostNSDateComponentsFormatter : NSFormatter
@property NSDateComponentsFormatterUnitsStyle unitsStyle;
@property NSCalendarUnit allowedUnits;
@property NSDateComponentsFormatterZeroFormattingBehavior zeroFormattingBehavior;
@property (copy) NSCalendar *calendar;
@property (copy) NSDate *referenceDate;
@property BOOL allowsFractionalUnits;
@property NSInteger maximumUnitCount;
@property BOOL collapsesLargestUnit;
@property BOOL includesApproximationPhrase;
@property BOOL includesTimeRemainingPhrase;
- (NSString *)stringFromTimeInterval:(NSTimeInterval)interval;
- (NSString *)stringFromDateComponents:(NSDateComponents *)components;
- (NSString *)stringFromDate:(NSDate *)start toDate:(NSDate *)end;
+ (NSString *)localizedStringFromDateComponents:(NSDateComponents *)components unitsStyle:(NSDateComponentsFormatterUnitsStyle)style;
@end

static uint64_t state = 0x9E3779B97F4A7C15ull;

static uint32_t next(void)
{
    state = state * 6364136223846793005ull + 1442695040888963407ull;
    return (uint32_t)(state >> 33);
}

static NSString *safely(id formatter, NSTimeInterval interval)
{
    @try {
        return [formatter stringFromTimeInterval:interval] ?: @"(nil)";
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"raises %@", exception.name];
    }
}

static void configure(id formatter, NSDictionary *config)
{
    [formatter setUnitsStyle:(NSDateComponentsFormatterUnitsStyle)[config[@"style"] integerValue]];
    [formatter setAllowedUnits:(NSCalendarUnit)[config[@"units"] unsignedIntegerValue]];
    [formatter setZeroFormattingBehavior:(NSDateComponentsFormatterZeroFormattingBehavior)[config[@"zero"] unsignedIntegerValue]];
    [formatter setMaximumUnitCount:[config[@"max"] integerValue]];
    [formatter setCollapsesLargestUnit:[config[@"collapse"] boolValue]];
    [formatter setIncludesApproximationPhrase:[config[@"approx"] boolValue]];
    [formatter setIncludesTimeRemainingPhrase:[config[@"remaining"] boolValue]];
    NSCalendar *calendar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    calendar.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    [formatter setCalendar:calendar];
    [formatter setReferenceDate:[NSDate dateWithTimeIntervalSince1970:1700000000]];
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        for (size_t index = 0; index < DATE_COMPONENTS_CASE_COUNT; index++) {
            NSString *name = [NSString stringWithFormat:@"recorded case %zu", index];
            CHECK_EQUAL(date_components_answer([[CharonHostNSDateComponentsFormatter alloc] init], &date_components_cases[index]), @(date_components_expectations[index]), name.UTF8String);
        }
        NSUInteger cases = argc > 1 ? (NSUInteger)atoi(argv[1]) : 3000;
        NSArray *unitPool = @[@(NSCalendarUnitYear), @(NSCalendarUnitMonth), @(NSCalendarUnitWeekOfMonth), @(NSCalendarUnitDay), @(NSCalendarUnitHour), @(NSCalendarUnitMinute), @(NSCalendarUnitSecond)];
        NSArray *zeros = @[@1, @1, @1, @0, @2, @4, @8, @14, @65536, @65537, @(65536 | 2), @10, @6];
        NSMutableDictionary *mismatches = [NSMutableDictionary dictionary];
        NSMutableArray *samples = [NSMutableArray array];
        NSUInteger total = 0, wrong = 0;
        for (NSUInteger index = 0; index < cases; index++) {
            NSCalendarUnit units = 0;
            for (NSUInteger bit = 0; bit < unitPool.count; bit++)
                if (next() % 3 != 0 || (bit >= 3 && next() % 2))
                    units |= [unitPool[bit] unsignedIntegerValue];
            if (next() % 5 == 0)
                units = 0;
            NSDictionary *config = @{@"style": @(next() % 6), @"units": @(units), @"zero": zeros[next() % zeros.count], @"max": @(next() % 4), @"collapse": @(next() % 4 == 0), @"approx": @(next() % 5 == 0), @"remaining": @(next() % 5 == 0)};
            CharonHostNSDateComponentsFormatter *ours = [[CharonHostNSDateComponentsFormatter alloc] init];
            NSDateComponentsFormatter *system = [[NSDateComponentsFormatter alloc] init];
            configure(ours, config);
            configure(system, config);
            for (int probe = 0; probe < 12; probe++) {
                NSTimeInterval interval;
                switch (next() % 6) {
                case 0: interval = next() % 120; break;
                case 1: interval = (next() % 200) * 60 + next() % 60; break;
                case 2: interval = (next() % 100) * 3600 + (next() % 4) * 60 + (next() % 3) * 30; break;
                case 3: interval = (next() % 60) * 86400 + next() % 90000; break;
                case 4: interval = (double)(next() % 100000000) * (next() % 4 + 1); break;
                default: interval = (double)(next() % 10000) + (next() % 100) / 100.0; break;
                }
                if (next() % 15 == 0)
                    interval = -interval;
                NSString *one = safely(ours, interval), *two = safely(system, interval);
                total++;
                if (![one isEqualToString:two]) {
                    wrong++;
                    NSString *key = [NSString stringWithFormat:@"style%@ zero%@ max%@", config[@"style"], config[@"zero"], config[@"max"]];
                    mismatches[key] = @([mismatches[key] integerValue] + 1);
                    if (samples.count < 25)
                        [samples addObject:[NSString stringWithFormat:@"%@ units=%lx collapse=%@ approx=%@ rem=%@ interval=%g\n     port   %@\n     system %@", key, (unsigned long)units, config[@"collapse"], config[@"approx"], config[@"remaining"], interval, one, two]];
                }
            }
        }
        printf("compared %lu, differing %lu (%.2f%%)\n", (unsigned long)total, (unsigned long)wrong, total ? 100.0 * wrong / total : 0);
        for (NSString *sample in samples)
            printf("  %s\n", sample.UTF8String);
        NSArray *keys = [mismatches.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) { return [mismatches[b] compare:mismatches[a]]; }];
        for (NSString *key in [keys subarrayWithRange:NSMakeRange(0, MIN(keys.count, (NSUInteger)15))])
            printf("  %s: %ld\n", key.UTF8String, (long)[mismatches[key] integerValue]);
        charon_check(wrong * 100 <= total * 5, "the formatter answers as the system's for all but a few percent of random configurations", [NSString stringWithFormat:@"%lu of %lu differ", (unsigned long)wrong, (unsigned long)total]);
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures;
}
