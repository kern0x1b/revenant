#include <errno.h>
#include <limits.h>
#include <stdlib.h>
#include "system_function.h"

static _Atomic(uintptr_t) charon_system_strtonum;

__attribute__((constructor))
static void charon_resolve_strtonum(void)
{
    charon_system_function(&charon_system_strtonum, CHARON_LIBSYSTEM, "strtonum");
}

__attribute__((visibility("default")))
long long strtonum(const char *numstr, long long minval, long long maxval, const char **errstrp)
{
    long long (*system)(const char *, long long, long long, const char **) =
        charon_system_function(&charon_system_strtonum, CHARON_LIBSYSTEM, "strtonum");
    if (system)
        return system(numstr, minval, maxval, errstrp);

    enum { ok, invalid, too_small, too_large } failure = ok;
    long long value = 0;
    int saved = errno;
    errno = 0;
    if (minval > maxval) {
        failure = invalid;
    } else {
        char *end;
        value = strtoll(numstr, &end, 10);
        if (numstr == end || *end != '\0')
            failure = invalid;
        else if ((value == LLONG_MIN && errno == ERANGE) || value < minval)
            failure = too_small;
        else if ((value == LLONG_MAX && errno == ERANGE) || value > maxval)
            failure = too_large;
    }
    static const char *const messages[] = {NULL, "invalid", "too small", "too large"};
    static const int codes[] = {0, EINVAL, ERANGE, ERANGE};
    if (errstrp != NULL)
        *errstrp = messages[failure];
    errno = failure == ok ? saved : codes[failure];
    return failure == ok ? value : 0;
}
