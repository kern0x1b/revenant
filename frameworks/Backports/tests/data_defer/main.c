#include <dlfcn.h>
#include <stdio.h>

extern const void *kCFErrorDomainPOSIX;

int main(void)
{
    void *library = dlopen("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation", RTLD_LAZY);
    const void **system = library ? dlsym(library, "kCFErrorDomainPOSIX") : NULL;
    int copied = system != NULL && *system == kCFErrorDomainPOSIX;
    printf("kCFErrorDomainPOSIX holds the system's value %d (expected %d)\n", copied, REVENANT_DEFER_EXPECT_SYSTEM);
    return copied == REVENANT_DEFER_EXPECT_SYSTEM ? 0 : 1;
}
