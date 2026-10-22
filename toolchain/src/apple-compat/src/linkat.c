#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
#include <sys/param.h>
#include <unistd.h>

int revenant_resolve_at(int directory, const char *path, char *resolved);

__attribute__((visibility("hidden")))
int linkat(int source_directory, const char *source, int target_directory, const char *target, int flags)
{
    if (flags & ~AT_SYMLINK_FOLLOW) {
        errno = EINVAL;
        return -1;
    }
    char from[MAXPATHLEN];
    char to[MAXPATHLEN];
    if (revenant_resolve_at(source_directory, source, from) == -1 ||
        revenant_resolve_at(target_directory, target, to) == -1) {
        return -1;
    }
    if (flags & AT_SYMLINK_FOLLOW) {
        char real[MAXPATHLEN];
        if (realpath(from, real) == NULL) {
            return -1;
        }
        return link(real, to);
    }
    return link(from, to);
}
