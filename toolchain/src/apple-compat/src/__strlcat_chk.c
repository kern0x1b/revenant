#include <stdlib.h>
#include <string.h>

__attribute__((visibility("hidden")))
size_t __strlcat_chk(char *destination, const char *source, size_t size, size_t capacity)
{
    if (size > capacity)
        abort();
    return (strlcat)(destination, source, size);
}
