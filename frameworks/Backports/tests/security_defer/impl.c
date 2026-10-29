#include <CoreFoundation/CoreFoundation.h>

long RevenantImpl_CFStringGetLength(CFStringRef string)
{
    (void)string;
    return -1;
}

int RevenantImpl_RevenantDeferFixtureAbsent(void)
{
    return 42;
}
