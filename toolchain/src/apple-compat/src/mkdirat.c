#include "at_within.h"
#include <errno.h>
#include <fcntl.h>
#include <sys/stat.h>

struct revenant_mkdir_request {
    const char *path;
    mode_t mode;
};

static int revenant_mkdir_operation(void *context)
{
    struct revenant_mkdir_request *request = context;
    return mkdir(request->path, request->mode);
}

__attribute__((visibility("hidden")))
int mkdirat(int directory, const char *path, mode_t mode)
{
    struct revenant_mkdir_request request = {path, mode};
    return revenant_at_within(path[0] == '/' ? AT_FDCWD : directory, revenant_mkdir_operation, &request);
}
