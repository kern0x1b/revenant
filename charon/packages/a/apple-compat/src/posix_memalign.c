#include <errno.h>
#include <stdlib.h>
#include <unistd.h>

int posix_memalign(void **result, size_t alignment, size_t size)
{
    if (alignment == 0 || (alignment & (alignment - 1)) != 0 || alignment % sizeof(void *) != 0)
        return EINVAL;
    void *block = NULL;
    if (alignment <= 16)
        block = malloc(size ? size : 1);
    else if (alignment <= (size_t)getpagesize())
        block = valloc(size ? size : 1);
    if (block == NULL)
        return ENOMEM;
    *result = block;
    return 0;
}
