#include "RevenantAtPath.h"
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

int revenant_absolute_path(int dirfd, const char *path, char *buffer)
{
    if (path == NULL) {
        errno = EFAULT;
        return -1;
    }
    if (path[0] == '/') {
        size_t length = strlen(path);
        if (length >= PATH_MAX) {
            errno = ENAMETOOLONG;
            return -1;
        }
        memcpy(buffer, path, length + 1);
        return 0;
    }
    if (dirfd != AT_FDCWD) {
        struct stat status;
        if (fstat(dirfd, &status) == -1) {
            return -1;
        }
        if (!S_ISDIR(status.st_mode)) {
            errno = ENOTDIR;
            return -1;
        }
    }
    size_t length = strlen(path);
    if (length >= PATH_MAX) {
        errno = ENAMETOOLONG;
        return -1;
    }
    if (length == 0) {
        errno = ENOENT;
        return -1;
    }
    if (dirfd == AT_FDCWD) {
        memcpy(buffer, path, length + 1);
        return 0;
    }
    if (fcntl(dirfd, F_GETPATH, buffer) == -1) {
        return -1;
    }
    size_t base = strlen(buffer);
    size_t separator = base > 0 && buffer[base - 1] == '/' ? 0 : 1;
    if (base + separator + length >= PATH_MAX) {
        errno = ENAMETOOLONG;
        return -1;
    }
    if (separator == 1) {
        buffer[base] = '/';
        base += 1;
    }
    memcpy(buffer + base, path, length + 1);
    return 0;
}
