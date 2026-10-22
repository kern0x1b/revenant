#include "at_plain.h"
#include <errno.h>
#include <fcntl.h>
#include <sys/stat.h>

__attribute__((visibility("hidden")))
int mkdirat(int directory, const char *path, mode_t mode)
{
    if (revenant_at_refused(directory, path)) {
        return -1;
    }
    return mkdir(path, mode);
}
