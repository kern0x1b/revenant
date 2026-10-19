#import <Foundation/Foundation.h>
#include <dlfcn.h>
#import "check.h"

/* The formatter is assembled out of CoreFoundation rather than taken from it, and
   the week rule comes from the locale, so what matters here is that the ICU of this
   release answers the same as the one the expectations were taken from. */

static NSString *image_of(Class cls)
{
    Dl_info info;
    return dladdr((__bridge const void *)cls, &info) ? @(info.dli_fname).lastPathComponent : @"?";
}

static NSISO8601DateFormatter *formatter(NSISO8601DateFormatOptions options, NSString *zone)
{
    NSISO8601DateFormatter *made = [[NSISO8601DateFormatter alloc] init];
    made.timeZone = [NSTimeZone timeZoneWithName:zone];
    made.formatOptions = options;
    return made;
}

int main(void)
{
    @autoreleasepool {
        CHECK_EQUAL(image_of([NSISO8601DateFormatter class]), @"libFoundationBackports.dylib",
                    "NSISO8601DateFormatter comes from the backports library");

        NSDate *epoch = [NSDate dateWithTimeIntervalSinceReferenceDate:0];        /* 2001-01-01 00:00 UTC */
        NSDate *sunday = [NSDate dateWithTimeIntervalSince1970:1600000000];       /* 2020-09-13, a Sunday */
        NSDate *yearEnd = [NSDate dateWithTimeIntervalSince1970:978220800];       /* 2000-12-31 00:00 UTC */

        NSISO8601DateFormatter *plain = [[NSISO8601DateFormatter alloc] init];
        CHECK_EQUAL([plain.timeZone name], @"GMT", "a fresh formatter is in GMT");
        CHECK(plain.formatOptions == NSISO8601DateFormatWithInternetDateTime,
              "a fresh formatter writes the internet date and time");
        CHECK_EQUAL([plain stringFromDate:epoch], @"2001-01-01T00:00:00Z",
                    "the internet date and time of the reference date");
        CHECK_EQUAL([plain stringFromDate:sunday], @"2020-09-13T12:26:40Z", "and of a later one");

        CHECK_EQUAL([formatter(NSISO8601DateFormatWithFullDate, @"GMT") stringFromDate:sunday], @"2020-09-13",
                    "the full date alone");
        CHECK_EQUAL([formatter(NSISO8601DateFormatWithFullTime, @"GMT") stringFromDate:sunday], @"12:26:40Z",
                    "the full time alone");
        CHECK_EQUAL([formatter(NSISO8601DateFormatWithYear | NSISO8601DateFormatWithMonth
                               | NSISO8601DateFormatWithDay, @"GMT") stringFromDate:sunday], @"20200913",
                    "a date without separators");

        /* The week rule is the whole reason the locale is what it is: the week has to
           start on Monday and the first week of a year must be the one with four days
           in it, or the last Sunday of a year lands in a week of its own. */
        NSISO8601DateFormatOptions week = NSISO8601DateFormatWithYear | NSISO8601DateFormatWithWeekOfYear
                                        | NSISO8601DateFormatWithDay | NSISO8601DateFormatWithDashSeparatorInDate;
        CHECK_EQUAL([formatter(week, @"GMT") stringFromDate:sunday], @"2020-W37-07",
                    "a Sunday is the seventh day of its week, not the first of the next");
        CHECK_EQUAL([formatter(week, @"GMT") stringFromDate:yearEnd], @"2000-W52-07",
                    "the last Sunday of a year stays in the last week of it");
        CHECK_EQUAL([formatter(week, @"GMT") stringFromDate:epoch], @"2001-W01-01",
                    "the first of January 2001 opens the first week");

        NSISO8601DateFormatter *newYork = formatter(NSISO8601DateFormatWithInternetDateTime, @"America/New_York");
        CHECK_EQUAL([newYork stringFromDate:epoch], @"2000-12-31T19:00:00-05:00", "a zone behind GMT");
        NSISO8601DateFormatter *tokyo = formatter(NSISO8601DateFormatWithInternetDateTime, @"Asia/Tokyo");
        CHECK_EQUAL([tokyo stringFromDate:epoch], @"2001-01-01T09:00:00+09:00", "and one ahead of it");

        CHECK([[plain dateFromString:@"2001-01-01T00:00:00Z"] isEqualToDate:epoch], "a date reads back");
        CHECK([[newYork dateFromString:@"2000-12-31T19:00:00-05:00"] isEqualToDate:epoch], "and one in a zone");
        CHECK([plain dateFromString:@"not a date"] == nil, "what is not a date reads back as nothing");
        CHECK([plain dateFromString:@""] == nil, "and so does an empty string");

        CHECK_EQUAL([NSISO8601DateFormatter stringFromDate:epoch
                                                  timeZone:[NSTimeZone timeZoneWithName:@"GMT"]
                                             formatOptions:NSISO8601DateFormatWithFullDate],
                    @"2001-01-01", "the class method writes a date without a formatter of one's own");

        NSISO8601DateFormatter *back = [NSKeyedUnarchiver unarchiveObjectWithData:
                                           [NSKeyedArchiver archivedDataWithRootObject:newYork]];
        CHECK_EQUAL([back stringFromDate:epoch], [newYork stringFromDate:epoch], "a formatter survives an archive");
        CHECK(back.formatOptions == newYork.formatOptions, "with its options");
        CHECK_EQUAL([back.timeZone name], [newYork.timeZone name], "and its zone");

        NSISO8601DateFormatter *fraction = formatter(NSISO8601DateFormatWithInternetDateTime
                                                     | NSISO8601DateFormatWithFractionalSeconds, @"GMT");
        const struct { double when; const char *written; } rounded[] = {
            {0.25, "2001-01-01T00:00:00.250Z"}, {1.0005, "2001-01-01T00:00:01.001Z"},
            {1.9999, "2001-01-01T00:00:02.000Z"}, {-0.25, "2000-12-31T23:59:59.750Z"}};
        for (unsigned index = 0; index < sizeof(rounded) / sizeof(*rounded); index++) {
            NSString *written = [fraction stringFromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:rounded[index].when]];
            NSString *name = [NSString stringWithFormat:@"%g seconds are written to the nearest millisecond", rounded[index].when];
            charon_check([written isEqual:@(rounded[index].written)], name.UTF8String,
                         [NSString stringWithFormat:@"%@ != %s", written, rounded[index].written]);
        }
        const struct { const char *text; double when; } read[] = {
            {"2001-01-01T12:00:00.1Z", 43200.1}, {"2001-01-01T12:00:00.12Z", 43200.12},
            {"2001-01-01T12:00:00.123Z", 43200.123}, {"2001-01-01T12:00:00.123456Z", 43200.123}};
        for (unsigned index = 0; index < sizeof(read) / sizeof(*read); index++) {
            NSDate *date = [fraction dateFromString:@(read[index].text)];
            NSString *name = [NSString stringWithFormat:@"%s is read to the millisecond", read[index].text];
            charon_check(date && fabs(date.timeIntervalSinceReferenceDate - read[index].when) < 1e-6, name.UTF8String,
                         [NSString stringWithFormat:@"%.6f", date.timeIntervalSinceReferenceDate]);
        }
        CHECK([fraction dateFromString:@"2001-01-01T12:00:00Z"] == nil,
              "with fractional seconds asked for, a time without them is not read");
        CHECK([formatter(NSISO8601DateFormatWithInternetDateTime, @"GMT") dateFromString:@"2001-01-01T12:00:00.123Z"] == nil,
              "without them asked for, a time with them is not read");

        printf("%d checks, %d failures\n", charon_checks, charon_failures);
        return charon_failures;
    }
}
