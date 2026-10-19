#import <Foundation/Foundation.h>

extern int charon_failures;
extern int charon_checks;

void charon_check(BOOL passed, const char *name, NSString *detail);
void charon_log_to(NSString *path);

#define CHECK(condition, name) charon_check((condition) ? YES : NO, name, @#condition)
#define CHECK_EQUAL(actual, expected, name) do { \
        id charon_actual = (actual), charon_expected = (expected); \
        charon_check(charon_actual == charon_expected || [charon_actual isEqual:charon_expected], name, \
                     [NSString stringWithFormat:@"%@ != %@", charon_actual, charon_expected]); \
    } while (0)
