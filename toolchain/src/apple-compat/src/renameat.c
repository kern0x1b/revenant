#include "at_within.h"
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>

struct revenant_rename_request {
    const char *from;
    const char *to;
};

static int revenant_rename_operation(void *context)
{
    struct revenant_rename_request *request = context;
    return rename(request->from, request->to);
}

__attribute__((visibility("hidden")))
int renameat(int from_directory, const char *from, int to_directory, const char *to)
{
    struct revenant_at_pair pair;
    if (revenant_at_pair(from_directory, from, to_directory, to, &pair) == -1) {
        return -1;
    }
    struct revenant_rename_request request = {pair.first, pair.second};
    return revenant_at_within(pair.directory, revenant_rename_operation, &request);
}
