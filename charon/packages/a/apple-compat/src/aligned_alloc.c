#include <errno.h>
#include <stddef.h>

extern int posix_memalign(void **result, size_t alignment, size_t size);

__attribute__((visibility("hidden")))
void *charon_aligned_alloc(size_t alignment, size_t size)
{
    void *result = NULL;
    if (alignment == 0 || (alignment & (alignment - 1)) != 0 || size % alignment != 0) {
        errno = EINVAL;
        return NULL;
    }
    if (alignment < sizeof(void *)) {
        alignment = sizeof(void *);
    }
    int failed = posix_memalign(&result, alignment, size);
    if (failed) {
        errno = failed;
        return NULL;
    }
    return result;
}
