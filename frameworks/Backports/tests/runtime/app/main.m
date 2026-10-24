#import "revenant_check.h"
#include <stdio.h>
#include <string.h>
#include <spawn.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

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

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (getuid() == 0) {
            pid_t starter = 0;
            char *starterArguments[] = {"launchctl", "start", "com.apple.assetsd", NULL};
            extern char **environ;
            int spawned = posix_spawn(&starter, "/bin/launchctl", NULL, NULL, starterArguments, environ);
            int starterStatus = -1;
            if (spawned == 0)
                waitpid(starter, &starterStatus, 0);
            printf("REVENANT-START assetsd spawn=%d status=%d\n", spawned, starterStatus);
            fflush(stdout);
            setgid(501);
            setuid(501);
        }
        revenant_failed_checks = [NSMutableArray array];
        for (int index = 0; index < revenant_count; index++) {
            revenant_run(revenant_names[index], revenant_functions[index], 0);
            revenant_run(revenant_names[index], revenant_functions[index], 1);
        }
        printf("REVENANT-DONE cases=%d\n", revenant_count);
        fflush(stdout);
    }
    return 0;
}
