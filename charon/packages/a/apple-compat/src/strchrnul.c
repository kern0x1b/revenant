#include "system_function.h"

static _Atomic(uintptr_t) charon_system_strchrnul;

__attribute__((constructor))
static void charon_resolve_strchrnul(void)
{
    charon_system_function(&charon_system_strchrnul, CHARON_LIBSYSTEM, "strchrnul");
}

/* The first byte of the string equal to c, converted to char, or the terminating NUL when there is none: strchr with the
   failure answer moved to the end of the string, so the result is never NULL. iOS 18.4 is the release the SDK names for it, and
   no held arm64 cache before 13.4 exports it, so the system's answers when it is there. */
__attribute__((visibility("default")))
char *strchrnul(const char *s, int c)
{
    char *(*system)(const char *, int) = charon_system_function(&charon_system_strchrnul, CHARON_LIBSYSTEM, "strchrnul");
    if (system)
        return system(s, c);
    char target = (char)c;
    while (*s != target && *s != '\0')
        s++;
    return (char *)s;
}
