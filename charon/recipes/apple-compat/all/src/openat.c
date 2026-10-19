#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdio.h>
#include <sys/param.h>

__attribute__((visibility("hidden")))
int charon_resolve_at(int directory, const char *path, char *resolved)
{
    if (path[0] == '/' || directory == AT_FDCWD) {
        if (snprintf(resolved, MAXPATHLEN, "%s", path) >= MAXPATHLEN) {
            errno = ENAMETOOLONG;
            return -1;
        }
        return 0;
    }
    char base[MAXPATHLEN];
    if (fcntl(directory, F_GETPATH, base) == -1) {
        return -1;
    }
    if (snprintf(resolved, MAXPATHLEN, "%s/%s", base, path) >= MAXPATHLEN) {
        errno = ENAMETOOLONG;
        return -1;
    }
    return 0;
}

__attribute__((visibility("hidden")))
int charon_openat(int directory, const char *path, int flags, ...)
{
    int mode = 0;
    if (flags & O_CREAT) {
        va_list arguments;
        va_start(arguments, flags);
        mode = va_arg(arguments, int);
        va_end(arguments);
    }
    char resolved[MAXPATHLEN];
    if (charon_resolve_at(directory, path, resolved) == -1) {
        return -1;
    }
    return open(resolved, flags, mode);
}
