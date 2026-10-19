#import <Foundation/Foundation.h>
#include <dlfcn.h>
#import "check.h"
#import "datecomponents-cases.h"
#import "datecomponents-expectations.h"

int main(void)
{
    @autoreleasepool {
        Dl_info info;
        Class class = [NSDateComponentsFormatter class];
        CHECK(dladdr((__bridge const void *)class, &info) && !strcmp(strrchr(info.dli_fname, '/') + 1, "libFoundationBackports.dylib"),
              "NSDateComponentsFormatter comes from the backports library");
        CHECK(sizeof date_components_expectations / sizeof date_components_expectations[0] == DATE_COMPONENTS_CASE_COUNT,
              "there is one recorded answer for every case");
        for (size_t index = 0; index < DATE_COMPONENTS_CASE_COUNT; index++) {
            NSDateComponentsFormatter *formatter = [[NSDateComponentsFormatter alloc] init];
            NSString *actual = date_components_answer(formatter, &date_components_cases[index]);
            NSString *name = [NSString stringWithFormat:@"case %zu answers as the system does", index];
            CHECK_EQUAL(actual, @(date_components_expectations[index]), name.UTF8String);
        }
        NSDateComponentsFormatter *formatter = [[NSDateComponentsFormatter alloc] init];
        BOOL raised = NO;
        @try { formatter.allowedUnits = NSCalendarUnitEra; } @catch (NSException *e) { raised = [e.name isEqual:NSInternalInconsistencyException]; }
        CHECK(raised, "a unit the formatter cannot show is refused");
        raised = NO;
        @try { [formatter stringFromTimeInterval:NAN]; } @catch (NSException *e) { raised = [e.name isEqual:NSInternalInconsistencyException]; }
        CHECK(raised, "a time interval that is not a number is refused");
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        return charon_failures;
    }
}
