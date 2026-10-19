#include <errno.h>
#include <stdint.h>
#include <string.h>

/* ISO/IEC 9899:2011 K.3.7.4.1, with the answers of Apple's Libc (string/NetBSD/memset_s.c): the bytes it may write are
   written even when n overflows smax, and the call writes to the caller's memory, which no caller's optimizer can drop. */
__attribute__((visibility("hidden")))
int charon_memset_s(void *bytes, size_t capacity, int value, size_t count)
{
    int error = 0;
    if (bytes == NULL)
        return EINVAL;
    if (capacity > RSIZE_MAX)
        return E2BIG;
    if (count > RSIZE_MAX) {
        error = E2BIG;
        count = capacity;
    }
    if (count > capacity) {
        error = EOVERFLOW;
        count = capacity;
    }
    memset(bytes, value, count);
    return error;
}
