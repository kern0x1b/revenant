#include <errno.h>
#include <stdint.h>

__attribute__((visibility("hidden")))
int fclonefileat(int source, int destination_directory, const char *destination, uint32_t flags)
{
    (void)source;
    (void)destination_directory;
    (void)destination;
    (void)flags;
    errno = ENOTSUP;
    return -1;
}
