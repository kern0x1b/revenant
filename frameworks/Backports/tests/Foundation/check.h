#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <stdio.h>
#include <string.h>

#define REVENANT_IMP(base, selector, type) ((type)method_getImplementation(class_getInstanceMethod([base class], selector)))
#define REVENANT_CLASS_IMP(base, selector, type) ((type)method_getImplementation(class_getClassMethod([base class], selector)))

static int revenant_checks;
static int revenant_failures;
static BOOL revenant_negative;

static void revenant_check(BOOL ok, const char *name, NSString *seen)
{
    revenant_checks++;
    if (ok) {
        printf("ok %s\n", name);
    } else {
        revenant_failures++;
        printf("FAIL %s: %s\n", name, [seen UTF8String]);
    }
    fflush(stdout);
}

static void revenant_expect_string(const char *name, NSString *value, NSString *expected)
{
    revenant_check([value isEqualToString:expected], name, [NSString stringWithFormat:@"%@ is not %@", value, expected]);
}

static int revenant_finish(void)
{
    printf("checks=%d failures=%d\n", revenant_checks, revenant_failures);
    fflush(stdout);
    return revenant_failures;
}

static void revenant_read_arguments(int argc, char **argv)
{
    revenant_negative = argc > 1 && strcmp(argv[1], "--negative") == 0;
}
