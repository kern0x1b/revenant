#include <errno.h>
#include <stdio.h>
#include <string.h>
#include "system_function.h"

static _Atomic(uintptr_t) charon_system_strsignal_r;

__attribute__((constructor))
static void charon_resolve_strsignal_r(void)
{
    charon_system_function(&charon_system_strsignal_r, CHARON_LIBSYSTEM, "strsignal_r");
}

/* The description strsignal gives for signal 1 to 31, copied into the buffer and NUL-terminated, and EINVAL with "Unknown
   signal: N" in its place for any other number. The answer for a valid signal is measured on the host, not read from a
   contract: zero when the description fits, and ERANGE when it does not and the buffer is at least 2 + (the number of digits of
   the signal) long, with the copy cut to the buffer's length less one. A buffer shorter than that is zero, with the cut copy.
   The host measures that for every signal from 1 to 31 (the threshold is 3 for one-digit numbers and 4 for two-digit ones).
   iOS 14.0 is the release the SDK names for it, and no held arm64 cache before 13.4 exports it, so the system's answers when
   it is there. */
__attribute__((visibility("default")))
int strsignal_r(int sig, char *strsignalbuf, size_t buflen)
{
    int (*system)(int, char *, size_t) = charon_system_function(&charon_system_strsignal_r, CHARON_LIBSYSTEM, "strsignal_r");
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
