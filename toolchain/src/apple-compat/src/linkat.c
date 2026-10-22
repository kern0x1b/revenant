#include "at_within.h"
#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
#include <sys/param.h>
#include <sys/stat.h>
#include <unistd.h>

struct revenant_link_request {
    const char *source;
    const char *target;
    int follow;
};

static int revenant_link_operation(void *context)
{
    struct revenant_link_request *request = context;
    if (request->follow) {
        char real[MAXPATHLEN];
        if (realpath(request->source, real) == NULL) {
            return -1;
        }
        return link(real, request->target);
    }
    struct stat info;
    if (lstat(request->source, &info) == -1) {
        return -1;
    }
    if (S_ISLNK(info.st_mode)) {
        errno = ENOTSUP;
        return -1;
    }
    return link(request->source, request->target);
}

__attribute__((visibility("hidden")))
int linkat(int source_directory, const char *source, int target_directory, const char *target, int flags)
{
    if (flags & ~AT_SYMLINK_FOLLOW) {
        errno = EINVAL;
        return -1;
    }
    int directory;
    if (revenant_at_pair(source_directory, source, target_directory, target, &directory) == -1) {
        return -1;
    }
    struct revenant_link_request request = {source, target, (flags & AT_SYMLINK_FOLLOW) != 0};
    return revenant_at_within(directory, revenant_link_operation, &request);
}
