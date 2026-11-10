#include "../revenant_impl.h"
#include <limits.h>
#include <sys/types.h>
#include <unistd.h>
#include "RevenantAtPath.h"

#define REVENANT_LIBSYSTEM_EXPORT __attribute__((visibility("default")))

REVENANT_LIBSYSTEM_EXPORT ssize_t BACKPORT_IMPL(readlinkat)(int dirfd, const char *path, char *buffer, size_t size)
{
    char full[PATH_MAX];
    if (revenant_absolute_path(dirfd, path, full) == -1) {
        return -1;
    }
    return readlink(full, buffer, size);
}

REVENANT_LIBSYSTEM_EXPORT int BACKPORT_IMPL(symlinkat)(const char *target, int dirfd, const char *path)
{
    char full[PATH_MAX];
    if (revenant_absolute_path(dirfd, path, full) == -1) {
        return -1;
    }
    return symlink(target, full);
}
