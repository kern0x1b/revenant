#include <stddef.h>
#include "system_function.h"

static _Atomic(uintptr_t) charon_system_timingsafe_bcmp;

__attribute__((constructor))
static void charon_resolve_timingsafe_bcmp(void)
{
    charon_system_function(&charon_system_timingsafe_bcmp, CHARON_LIBSYSTEM, "timingsafe_bcmp");
}

/* Zero when the two buffers hold the same bytes, non-zero otherwise. Every byte is compared, whatever the first difference
   is, so the time taken does not say where the buffers part; that is the point of the call. iOS 11 has it in libsystem_c,
   and the releases before it have none, so the system's answers when it is there. */
__attribute__((visibility("default")))
int timingsafe_bcmp(const void *b1, const void *b2, size_t len)
{
    int (*system)(const void *, const void *, size_t) = charon_system_function(&charon_system_timingsafe_bcmp, CHARON_LIBSYSTEM, "timingsafe_bcmp");
    if (system)
        return system(b1, b2, len);
    const unsigned char *p = b1, *q = b2;
    unsigned char difference = 0;
    for (size_t i = 0; i < len; i++)
        difference |= (unsigned char)(p[i] ^ q[i]);
    return difference != 0;
}
