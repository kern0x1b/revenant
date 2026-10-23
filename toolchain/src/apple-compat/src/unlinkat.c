#include "at_within.h"
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>

struct revenant_unlink_request {
    const char *path;
    int flags;
};

static int revenant_unlink_operation(void *context)
{
    struct revenant_unlink_request *request = context;
    return (request->flags & AT_REMOVEDIR) ? rmdir(request->path) : unlink(request->path);
}

__attribute__((visibility("hidden")))
int revenant_unlinkat(int directory, const char *path, int flags)
{
    if (flags & ~AT_REMOVEDIR) {
        errno = EINVAL;
        return -1;
    }
    struct revenant_unlink_request request = {path, flags};
    return revenant_at_within(path[0] == '/' ? AT_FDCWD : directory, revenant_unlink_operation, &request);
}

__attribute__((visibility("hidden")))
int unlinkat(int directory, const char *path, int flags)
{
    return revenant_unlinkat(directory, path, flags);
}
