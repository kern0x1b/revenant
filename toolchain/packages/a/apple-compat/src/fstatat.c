#include <errno.h>
#include <fcntl.h>
#include <sys/param.h>
#include <sys/stat.h>

int revenant_resolve_at(int directory, const char *path, char *resolved);

__attribute__((visibility("hidden")))
int revenant_fstatat(int directory, const char *path, struct stat *buffer, int flags)
{
    if (flags & ~AT_SYMLINK_NOFOLLOW) {
        errno = EINVAL;
        return -1;
    }
    char resolved[MAXPATHLEN];
    if (revenant_resolve_at(directory, path, resolved) == -1) {
        return -1;
    }
    return (flags & AT_SYMLINK_NOFOLLOW) ? lstat(resolved, buffer) : stat(resolved, buffer);
}
