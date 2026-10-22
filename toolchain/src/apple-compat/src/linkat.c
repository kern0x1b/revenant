#include "at_plain.h"
#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
#include <sys/param.h>
#include <sys/stat.h>
#include <unistd.h>

__attribute__((visibility("hidden")))
int linkat(int source_directory, const char *source, int target_directory, const char *target, int flags)
{
    if (flags & ~AT_SYMLINK_FOLLOW) {
        errno = EINVAL;
        return -1;
    }
    if (revenant_at_refused(source_directory, source) || revenant_at_refused(target_directory, target)) {
        return -1;
    }
    if (flags & AT_SYMLINK_FOLLOW) {
        char real[MAXPATHLEN];
        if (realpath(source, real) == NULL) {
            return -1;
        }
        return link(real, target);
    }
    struct stat info;
    if (lstat(source, &info) == -1) {
        return -1;
    }
    if (S_ISLNK(info.st_mode)) {
        errno = ENOTSUP;
        return -1;
    }
    return link(source, target);
}
