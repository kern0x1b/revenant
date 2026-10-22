#include "at_plain.h"
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>

__attribute__((visibility("hidden")))
int renameat(int from_directory, const char *from, int to_directory, const char *to)
{
    if (revenant_at_refused(from_directory, from) || revenant_at_refused(to_directory, to)) {
        return -1;
    }
    return rename(from, to);
}
