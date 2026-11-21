#import "revenant_check.h"
#include <stdio.h>
#include <string.h>

#define REVENANT_CASE_CAPACITY 128

static const char *revenant_names[REVENANT_CASE_CAPACITY];
static revenant_case_function revenant_functions[REVENANT_CASE_CAPACITY];
static int revenant_count;
static int revenant_failures;
static NSMutableArray *revenant_failed_checks;

void revenant_register_case(const char *name, revenant_case_function function)
{
    revenant_names[revenant_count] = name;
    revenant_functions[revenant_count] = function;
    revenant_count++;
}

void revenant_expect(BOOL ok, NSString *check, NSString *detail)
{
    if (ok) {
        printf("check ok %s\n", [check UTF8String]);
    } else {
        revenant_failures++;
        [revenant_failed_checks addObject:[NSString stringWithFormat:@"%@: %@", check, detail]];
        printf("check FAIL %s: %s\n", [check UTF8String], [detail UTF8String]);
    }
    fflush(stdout);
}

void revenant_expect_string(NSString *check, NSString *value, NSString *expected)
{
    revenant_expect([value isEqualToString:expected], check,
                    [NSString stringWithFormat:@"%@ is not %@", value, expected]);
}

void revenant_expect_integer(NSString *check, long long value, long long expected)
{
    revenant_expect(value == expected, check, [NSString stringWithFormat:@"%lld is not %lld", value, expected]);
}

void revenant_expect_real(NSString *check, double value, double expected, double tolerance)
{
    revenant_expect(value - expected <= tolerance && expected - value <= tolerance, check,
                    [NSString stringWithFormat:@"%g is not %g within %g", value, expected, tolerance]);
}

void revenant_expect_true(NSString *check, BOOL ok, NSString *detail)
{
    revenant_expect(ok, check, detail);
}

static void revenant_run(const char *name, revenant_case_function function, int negative)
{
    revenant_failures = 0;
    [revenant_failed_checks removeAllObjects];
    const char *outcome = "pass";
    NSString *detail = @"";
    @try {
        function(negative);
    } @catch (NSException *exception) {
        outcome = "error";
        detail = [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
    }
    if (strcmp(outcome, "error") != 0 && revenant_failures > 0) {
        outcome = "fail";
        detail = [revenant_failed_checks componentsJoinedByString:@"; "];
    }
    printf("REVENANT-CASE %s %s %s %s\n", name, negative ? "negative" : "positive", outcome, [detail UTF8String]);
    fflush(stdout);
}

static int revenant_selected(const char *selection, const char *name)
{
    size_t length = strlen(name);
    for (const char *cursor = selection; *cursor;) {
        const char *end = strchr(cursor, ',');
        size_t span = end ? (size_t)(end - cursor) : strlen(cursor);
        if (span == length && strncmp(cursor, name, length) == 0)
            return 1;
        cursor += span + (end ? 1 : 0);
    }
    return 0;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        revenant_failed_checks = [NSMutableArray array];
        const char *selection = NULL;
        for (int index = 1; index + 1 < argc; index++) {
            if (strcmp(argv[index], "--cases") == 0)
                selection = argv[index + 1];
        }
        int ran = 0;
        for (int index = 0; index < revenant_count; index++) {
            if (selection && !revenant_selected(selection, revenant_names[index]))
                continue;
            revenant_run(revenant_names[index], revenant_functions[index], 0);
            revenant_run(revenant_names[index], revenant_functions[index], 1);
            ran++;
        }
        printf("REVENANT-DONE cases=%d\n", ran);
        fflush(stdout);
    }
    return 0;
}
