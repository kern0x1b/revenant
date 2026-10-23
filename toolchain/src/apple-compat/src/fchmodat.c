#include "at_within.h"
#include <errno.h>
#include <fcntl.h>
#include <sys/stat.h>

struct revenant_chmod_request {
    const char *path;
    mode_t mode;
    int flags;
};

static int revenant_chmod_operation(void *context)
{
    struct revenant_chmod_request *request = context;
    return (request->flags & AT_SYMLINK_NOFOLLOW) ? lchmod(request->path, request->mode) : chmod(request->path, request->mode);
}

__attribute__((visibility("hidden")))
int revenant_fchmodat(int directory, const char *path, mode_t mode, int flags)
{
    if (flags & ~AT_SYMLINK_NOFOLLOW) {
        errno = EINVAL;
        return -1;
    }
    struct revenant_chmod_request request = {path, mode, flags};
    return revenant_at_within(path[0] == '/' ? AT_FDCWD : directory, revenant_chmod_operation, &request);
}
