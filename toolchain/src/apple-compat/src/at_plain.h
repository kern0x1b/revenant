#ifndef REVENANT_AT_PLAIN_H
#define REVENANT_AT_PLAIN_H

#include <errno.h>
#include <fcntl.h>

static inline int revenant_at_refused(int directory, const char *path)
{
    if (directory != AT_FDCWD && path[0] != '/') {
        errno = ENOTSUP;
        return 1;
    }
    return 0;
}

#endif
