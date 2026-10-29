#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>

extern int RevenantDeferFixtureAbsent(void);

int main(void)
{
    long length = CFStringGetLength(CFSTR("hello"));
    long expected = REVENANT_DEFER_EXPECT_SYSTEM ? 5 : -1;
    int absent = RevenantDeferFixtureAbsent();
    printf("CFStringGetLength %ld (expected %ld), RevenantDeferFixtureAbsent %d (expected 42)\n", length, expected, absent);
    return length == expected && absent == 42 ? 0 : 1;
}
