#import <Foundation/Foundation.h>

typedef void (*revenant_case_function)(int negative);

void revenant_register_case(const char *name, revenant_case_function function);
void revenant_expect(BOOL ok, NSString *check, NSString *detail);
void revenant_expect_string(NSString *check, NSString *value, NSString *expected);
void revenant_expect_integer(NSString *check, long long value, long long expected);
void revenant_expect_real(NSString *check, double value, double expected, double tolerance);
void revenant_expect_true(NSString *check, BOOL ok, NSString *detail);

#define REVENANT_CASE(name) \
    static void revenant_run_##name(int negative); \
    __attribute__((constructor)) static void revenant_register_##name(void) \
    { \
        revenant_register_case(#name, revenant_run_##name); \
    } \
    static void revenant_run_##name(int negative)
