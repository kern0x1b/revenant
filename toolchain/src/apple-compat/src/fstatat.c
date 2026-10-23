#include "at_within.h"
#include <errno.h>
#include <fcntl.h>
#include <sys/stat.h>

struct revenant_stat_request {
    const char *path;
    struct stat *buffer;
    int flags;
};

static int revenant_stat_operation(void *context)
{
    struct revenant_stat_request *request = context;
    return (request->flags & AT_SYMLINK_NOFOLLOW) ? lstat(request->path, request->buffer) : stat(request->path, request->buffer);
}

__attribute__((visibility("hidden")))
int revenant_fstatat(int directory, const char *path, struct stat *buffer, int flags)
{
    if (flags & ~AT_SYMLINK_NOFOLLOW) {
        errno = EINVAL;
        return -1;
    }
    struct revenant_stat_request request = {path, buffer, flags};
    return revenant_at_within(path[0] == '/' ? AT_FDCWD : directory, revenant_stat_operation, &request);
}

__attribute__((visibility("hidden")))
int fstatat(int directory, const char *path, struct stat *buffer, int flags)
{
    return revenant_fstatat(directory, path, buffer, flags);
}
