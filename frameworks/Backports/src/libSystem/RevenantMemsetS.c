#include "../revenant_impl.h"
#include <stddef.h>
#include <revenant/memset_s.h>

__attribute__((visibility("default"))) int BACKPORT_IMPL(memset_s)(void *bytes, size_t capacity, int value, size_t count)
{
    return revenant_memset_s(bytes, capacity, value, count);
}
