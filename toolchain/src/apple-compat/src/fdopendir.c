#include "at_within.h"
#include <dirent.h>
#include <errno.h>
#include <unistd.h>

struct revenant_listing_request {
    DIR *listing;
};

static int revenant_listing_operation(void *context)
{
    struct revenant_listing_request *request = context;
    request->listing = opendir(".");
    return request->listing == NULL ? -1 : 0;
}

__attribute__((visibility("hidden")))
DIR *revenant_fdopendir(int descriptor)
{
    if (descriptor < 0) {
        errno = EBADF;
        return NULL;
    }
    struct revenant_listing_request request = {NULL};
    if (revenant_at_within(descriptor, revenant_listing_operation, &request) == -1) {
        return NULL;
    }
    close(descriptor);
    return request.listing;
}

__attribute__((visibility("hidden")))
DIR *fdopendir(int descriptor)
{
    return revenant_fdopendir(descriptor);
}
