#include "system_function.h"

static _Atomic(uintptr_t) revenant_system_strchrnul;

__attribute__((constructor))
static void revenant_resolve_strchrnul(void)
{
    revenant_system_function(&revenant_system_strchrnul, REVENANT_LIBSYSTEM, "strchrnul");
}

__attribute__((visibility("default")))
char *strchrnul(const char *s, int c)
{
    char *(*system)(const char *, int) = revenant_system_function(&revenant_system_strchrnul, REVENANT_LIBSYSTEM, "strchrnul");
    if (system)
        return system(s, c);
    char target = (char)c;
    while (*s != target && *s != '\0')
        s++;
    return (char *)s;
}
