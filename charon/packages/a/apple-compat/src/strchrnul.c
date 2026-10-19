#include "system_function.h"

static _Atomic(uintptr_t) charon_system_strchrnul;

__attribute__((constructor))
static void charon_resolve_strchrnul(void)
{
    charon_system_function(&charon_system_strchrnul, CHARON_LIBSYSTEM, "strchrnul");
}

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
