#import <Foundation/Foundation.h>
#include <dlfcn.h>
#import "check.h"
#import "relativedatetime-cases.h"
#import "relativedatetime-expectations.h"

int main(void)
{
    @autoreleasepool {
        Dl_info info;
        Class class = [NSRelativeDateTimeFormatter class];
        CHECK(dladdr((__bridge const void *)class, &info) && !strcmp(strrchr(info.dli_fname, '/') + 1, "libFoundationBackports.dylib"),
              "NSRelativeDateTimeFormatter comes from the backports library");
        CHECK(sizeof relative_expectations / sizeof relative_expectations[0] == RELATIVE_CASE_COUNT, "there is one recorded answer for every case");
        size_t wrong = 0;
        for (size_t index = 0; index < RELATIVE_CASE_COUNT; index++) {
            NSString *actual = relative_answer([[NSRelativeDateTimeFormatter alloc] init], index);
            NSString *expected = @(relative_expectations[index]);
            if (![actual isEqualToString:expected]) {
                wrong++;
                NSString *name = [NSString stringWithFormat:@"case %zu answers as the system does", index];
                CHECK_EQUAL(actual, expected, name.UTF8String);
            }
        }
        CHECK(wrong == 0, "all recorded cases answer as the system does");
        NSRelativeDateTimeFormatter *formatter = [[NSRelativeDateTimeFormatter alloc] init];
        CHECK(formatter.dateTimeStyle == NSRelativeDateTimeFormatterStyleNumeric && formatter.unitsStyle == NSRelativeDateTimeFormatterUnitsStyleFull
                  && formatter.formattingContext == NSFormattingContextUnknown, "a fresh formatter is numeric, full and of unknown context");
        CHECK([formatter stringForObjectValue:@5] == nil && [formatter stringForObjectValue:[NSDate date]] != nil, "only a date has a string");
        NSString *soon = [formatter localizedStringFromTimeInterval:7200];
        CHECK_EQUAL(soon, @"in 2 hours", "a time interval is read from now");
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        return charon_failures;
    }
}
