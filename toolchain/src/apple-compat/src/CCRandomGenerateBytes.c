#include <stddef.h>
#include <stdlib.h>

__attribute__((visibility("hidden")))
int CCRandomGenerateBytes(void *bytes, size_t count)
{
    const int success = 0;
    const int parameter_error = -4300;
    if (count == 0) {
        return success;
    }
    if (bytes == NULL) {
        return parameter_error;
    }
    arc4random_buf(bytes, count);
    return success;
}
