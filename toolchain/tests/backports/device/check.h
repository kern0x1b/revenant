#import <Foundation/Foundation.h>

extern int revenant_failures;
extern int revenant_checks;

void revenant_check(BOOL passed, const char *name, NSString *detail);
void revenant_log_to(NSString *path);

#define CHECK(condition, name) revenant_check((condition) ? YES : NO, name, @#condition)
#define CHECK_EQUAL(actual, expected, name) do { \
        id revenant_actual = (actual), revenant_expected = (expected); \
        revenant_check(revenant_actual == revenant_expected || [revenant_actual isEqual:revenant_expected], name, \
                     [NSString stringWithFormat:@"%@ != %@", revenant_actual, revenant_expected]); \
    } while (0)
