#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <stdio.h>
#include <string.h>
#import "check.h"

static NSArray *SplitLine(NSString *line)
{
    return [line componentsSeparatedByString:@"\t"];
}

static void expect(BOOL ok, NSString *what, NSString *detail)
{
    charon_checks++;
    if (!ok) {
        charon_failures++;
        printf("FAIL %s: %s\n", [what UTF8String], [detail UTF8String]);
    }
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        charon_log_to(argc > 1 ? [NSString stringWithUTF8String:argv[1]] : nil);
        NSString *path = argc > 1 ? [NSString stringWithUTF8String:argv[1]] : nil;
        if (!path) {
            printf("dateinterval: no golden file given\n");
            return 1;
        }
        NSString *contents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
        CHECK(contents != nil, "the golden file is there");
        if (!contents)
            return 1;

        Class formatterClass = NSClassFromString(@"NSDateIntervalFormatter");
        if (!formatterClass) {
            printf("dateinterval: no NSDateIntervalFormatter on this release, which is below the 5.0 floor\n");
            return 0;
        }
        BOOL ported = strstr(class_getImageName(formatterClass), "FoundationBackports") != NULL;

        NSArray *lines = [contents componentsSeparatedByString:@"\n"];
        NSUInteger compared = 0, differing = 0;
        for (NSString *line in lines) {
            if (!line.length)
                continue;
            NSArray *fields = SplitLine(line);
            if ([fields[0] isEqualToString:@"defaults"]) {
                NSDateIntervalFormatter *fresh = [[formatterClass alloc] init];
                NSString *what = [NSString stringWithFormat:@"the defaults of a fresh formatter: %@", line];
                expect([[fresh valueForKey:@"dateStyle"] integerValue] == [fields[1] integerValue]
                           && [[fresh valueForKey:@"timeStyle"] integerValue] == [fields[2] integerValue]
                           && [[fresh valueForKey:@"dateTemplate"] isEqualToString:fields[3]],
                       what,
                       [NSString stringWithFormat:@"ours %ld %ld \"%@\"", (long)[fresh valueForKey:@"dateStyle"],
                        (long)[fresh valueForKey:@"timeStyle"], [[fresh valueForKey:@"dateTemplate"] description]]);
                compared++;
                continue;
            }
            if ([fields[0] isEqualToString:@"template"]) {
                if (fields.count < 5) {
                    CHECK(NO, "a template line has its five fields");
                    continue;
                }
                NSDateIntervalFormatter *formatter = [[formatterClass alloc] init];
                formatter.locale = [NSLocale localeWithLocaleIdentifier:fields[1]];
                formatter.dateStyle = formatter.timeStyle = 0;
                formatter.dateTemplate = fields[2];
                formatter.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
                NSString *answer = [formatter stringFromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:[fields[3] doubleValue]]
                                                   toDate:[NSDate dateWithTimeIntervalSinceReferenceDate:[fields[3] doubleValue] + 3600]];
                compared++;
                if (![answer isEqualToString:[fields[4] UTF8String]]) {
                    differing++;
                    if (differing <= 20) {
                        NSString *note = [NSString stringWithFormat:@"template %@ %@ expected [%@] got [%@]", fields[1],
                                          fields[2], fields[4], answer];
                        printf("  %s\n", [note UTF8String]);
                    }
                }
                continue;
            }
            if (fields.count < 7) {
                CHECK(NO, "a case line has its seven fields");
                continue;
            }
            NSLocale *locale = [NSLocale localeWithLocaleIdentifier:fields[0]];
            NSInteger dateStyle = [fields[1] integerValue], timeStyle = [fields[2] integerValue];
            NSTimeZone *zone = [NSTimeZone timeZoneWithName:fields[3]];
            NSDate *from = [NSDate dateWithTimeIntervalSinceReferenceDate:[fields[4] doubleValue]];
            NSDate *to = [NSDate dateWithTimeIntervalSinceReferenceDate:[fields[5] doubleValue]];
            NSArray *rest = [fields subarrayWithRange:NSMakeRange(6, fields.count - 6)];
            NSString *expected = [rest componentsJoinedByString:@"\t"];

            id formatter = [[formatterClass alloc] init];
            [formatter setValue:locale forKey:@"locale"];
            [formatter setValue:@(dateStyle) forKey:@"dateStyle"];
            [formatter setValue:@(timeStyle) forKey:@"timeStyle"];
            [formatter setValue:zone forKey:@"timeZone"];
            NSString *answer = [formatter stringFromDate:from toDate:to];
            compared++;
            if (![answer isEqualToString:expected]) {
                differing++;
                if (differing <= 20) {
                    NSString *mine = [answer description];
                    NSString *note = [NSString stringWithFormat:@"%@ %ld %ld %@ expected [%@] got [%@]",
                                      fields[0], (long)dateStyle, (long)timeStyle, fields[3], expected, mine];
                    printf("  %s\n", [note UTF8String]);
                }
            }
            SEL withInterval = NSSelectorFromString(@"stringFromDateInterval:");
            if ([formatter respondsToSelector:withInterval]) {
                Class intervalClass = NSClassFromString(@"NSDateInterval");
                id interval = [[intervalClass alloc] initWithStartDate:from endDate:to];
                NSString *viaInterval = [formatter performSelector:withInterval withObject:interval];
                if (viaInterval)
                    CHECK([viaInterval isEqualToString:answer], "the interval and the pair of dates agree");
            }
        }
        printf("dateinterval: %s, compared %lu cases, %lu differing\n", ported ? "the port's class" : "the release's class",
               (unsigned long)compared, (unsigned long)differing);
        CHECK(differing == 0, "every case is the answer the golden file holds");
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        return charon_failures;
    }
}
