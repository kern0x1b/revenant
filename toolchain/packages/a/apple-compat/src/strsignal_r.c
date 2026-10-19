#include <errno.h>
#include <stdio.h>
#include <string.h>
#include "system_function.h"

static _Atomic(uintptr_t) revenant_system_strsignal_r;

__attribute__((constructor))
static void revenant_resolve_strsignal_r(void)
{
    revenant_system_function(&revenant_system_strsignal_r, REVENANT_LIBSYSTEM, "strsignal_r");
}

__attribute__((visibility("default")))
int strsignal_r(int sig, char *strsignalbuf, size_t buflen)
{
    int (*system)(int, char *, size_t) = revenant_system_function(&revenant_system_strsignal_r, REVENANT_LIBSYSTEM, "strsignal_r");
    if (system)
        return system(sig, strsignalbuf, buflen);
    char unknown[64];
    const char *text;
    size_t length;
    int result = 0;
    if (sig >= 1 && sig <= 31) {
        text = strsignal(sig);
        length = strlen(text);
        size_t threshold = sig < 10 ? 3 : 4;
        if (buflen >= threshold && buflen <= length)
            result = ERANGE;
    } else {
        snprintf(unknown, sizeof unknown, "Unknown signal: %d", sig);
        text = unknown;
        length = strlen(text);
        result = EINVAL;
    }
    if (buflen == 0)
        return result;
    if (length >= buflen)
        length = buflen - 1;
    memcpy(strsignalbuf, text, length);
    strsignalbuf[length] = '\0';
    return result;
}
