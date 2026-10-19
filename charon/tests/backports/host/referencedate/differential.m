#import <Foundation/Foundation.h>
#import "check.h"

static const char *label(NSString *format, ...)
{
    static NSMutableArray *keep;
    if (!keep)
        keep = [NSMutableArray array];
    va_list arguments;
    va_start(arguments, format);
    NSString *string = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    [keep addObject:string];
    return string.UTF8String;
}

int main(void)
{
    @autoreleasepool {
        Class port = NSClassFromString(@"CharonHostNSDateComponentsFormatter");
        NSCalendar *calendar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
        calendar.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
        NSDateFormatter *dates = [[NSDateFormatter alloc] init];
        dates.dateFormat = @"yyyy-MM-dd";
        dates.timeZone = calendar.timeZone;
        NSArray *references = @[[NSNull null], @"2019-01-01", @"2019-02-01", @"2020-01-01", @"2020-02-01", @"2020-02-29", @"2020-03-01", @"2020-12-31", @"2021-06-15", @"1970-01-01", @"2100-02-28"];
        NSArray *units = @[@(NSCalendarUnitMonth | NSCalendarUnitDay), @(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay), @(NSCalendarUnitYear | NSCalendarUnitDay), @(NSCalendarUnitMonth | NSCalendarUnitWeekOfMonth | NSCalendarUnitDay), @(NSCalendarUnitYear | NSCalendarUnitMonth), @(NSCalendarUnitMonth), @(NSCalendarUnitDay | NSCalendarUnitHour)];
        NSArray *intervals = @[@(45 * 86400.0), @(400 * 86400.0), @(59 * 86400.0), @(30 * 86400.0), @(365 * 86400.0), @(1000 * 86400.0), @(3725.0), @(86400.0 * 1.5), @(-45 * 86400.0)];
        for (NSNumber *style in @[@0, @1, @2, @3]) {
            for (id reference in references) {
                for (NSNumber *unit in units) {
                    for (NSNumber *interval in intervals) {
                        NSDate *date = [reference isKindOfClass:[NSString class]] ? [dates dateFromString:reference] : nil;
                        NSMutableArray *answers = [NSMutableArray array];
                        for (int side = 0; side < 2; side++) {
                            NSDateComponentsFormatter *formatter = side ? [[port alloc] init] : [[NSDateComponentsFormatter alloc] init];
                            formatter.unitsStyle = style.integerValue;
                            formatter.allowedUnits = unit.unsignedIntegerValue;
                            formatter.calendar = calendar;
                            formatter.referenceDate = date;
                            NSMutableDictionary *first = [NSMutableDictionary dictionary];
                            @try { first[@"interval"] = [formatter stringFromTimeInterval:interval.doubleValue] ?: @"nil"; } @catch (NSException *e) { first[@"interval"] = e.name; }
                            NSDateComponents *components = [[NSDateComponents alloc] init];
                            components.day = (NSInteger)(interval.doubleValue / 86400);
                            @try { first[@"components"] = [formatter stringFromDateComponents:components] ?: @"nil"; } @catch (NSException *e) { first[@"components"] = e.name; }
                            [answers addObject:first];
                        }
                        CHECK_EQUAL(answers[1], answers[0], label(@"style %@ reference %@ units %@ interval %@", style, reference, unit, interval));
                    }
                }
            }
        }
        NSMutableArray *shape[2] = {[NSMutableArray array], [NSMutableArray array]};
        for (int side = 0; side < 2; side++) {
            NSDateComponentsFormatter *formatter = side ? [[port alloc] init] : [[NSDateComponentsFormatter alloc] init];
            [shape[side] addObject:formatter.referenceDate ? @"set" : @"nil"];
            NSDate *date = [dates dateFromString:@"2020-02-01"];
            formatter.referenceDate = date;
            [shape[side] addObject:[formatter.referenceDate isEqual:date] ? @"equal" : @"different"];
            NSDateComponentsFormatter *copy = [formatter copy];
            [shape[side] addObject:[copy.referenceDate isEqual:date] ? @"copied" : @"not copied"];
            formatter.unitsStyle = NSDateComponentsFormatterUnitsStyleSpellOut;
            formatter.allowedUnits = NSCalendarUnitYear | NSCalendarUnitDay;
            formatter.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorPad;
            formatter.maximumUnitCount = 2;
            formatter.collapsesLargestUnit = YES;
            formatter.includesApproximationPhrase = YES;
            formatter.includesTimeRemainingPhrase = YES;
            formatter.allowsFractionalUnits = YES;
            formatter.formattingContext = NSFormattingContextStandalone;
            formatter.calendar = calendar;
            NSDateComponentsFormatter *full = [formatter copy];
            [shape[side] addObject:[NSString stringWithFormat:@"%ld %lu %lu %ld %d %d %d %d %ld %d", (long)full.unitsStyle, (unsigned long)full.allowedUnits, (unsigned long)full.zeroFormattingBehavior, (long)full.maximumUnitCount, full.collapsesLargestUnit, full.includesApproximationPhrase, full.includesTimeRemainingPhrase, full.allowsFractionalUnits, (long)full.formattingContext, [full.calendar isEqual:calendar]]];
            formatter.referenceDate = nil;
            [shape[side] addObject:formatter.referenceDate ? @"set" : @"nil"];
        }
        CHECK_EQUAL(shape[1], shape[0], "the reference date is kept, copied with the formatter and cleared as the system's is");
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures ? 1 : 0;
}
