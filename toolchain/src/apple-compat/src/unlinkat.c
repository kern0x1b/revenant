#include "at_plain.h"
#include <errno.h>
#include <fcntl.h>
#include <sys/param.h>
#include <unistd.h>

int revenant_resolve_at(int directory, const char *path, char *resolved);

__attribute__((visibility("hidden")))
int revenant_unlinkat(int directory, const char *path, int flags)
{
    if (flags & ~AT_REMOVEDIR) {
        errno = EINVAL;
        return -1;
    }
    char resolved[MAXPATHLEN];
    if (revenant_resolve_at(directory, path, resolved) == -1) {
        return -1;
    }
    return (flags & AT_REMOVEDIR) ? rmdir(resolved) : unlink(resolved);
}

__attribute__((visibility("hidden")))
int unlinkat(int directory, const char *path, int flags)
{
    if (revenant_at_refused(directory, path)) {
        return -1;
    }
    return revenant_unlinkat(directory, path, flags);
}
