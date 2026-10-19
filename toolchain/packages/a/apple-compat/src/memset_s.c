#include <errno.h>
#include <stdint.h>
#include <string.h>

__attribute__((visibility("hidden")))
int revenant_memset_s(void *bytes, size_t capacity, int value, size_t count)
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
