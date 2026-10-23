#include "at_within.h"
#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

__attribute__((visibility("hidden")))
int revenant_at_within(int directory, revenant_at_operation operation, void *context)
{
    if (directory == AT_FDCWD) {
        return operation(context);
    }
    if (__pthread_fchdir(directory) == -1) {
        return -1;
    }
    int result = operation(context);
    int failure = errno;
    if (__pthread_fchdir(-1) == -1) {
        fprintf(stderr, "apple-compat: the thread's working directory could not be restored after an *at call\n");
        abort();
    }
    errno = failure;
    return result;
}

static int revenant_absolute(int directory, const char *name, char *buffer)
{
    char base[MAXPATHLEN];
    if (directory == AT_FDCWD) {
        if (getcwd(base, sizeof base) == NULL) {
            return -1;
        }
    } else if (fcntl(directory, F_GETPATH, base) == -1) {
        return -1;
    }
    if (snprintf(buffer, MAXPATHLEN, "%s/%s", base, name) >= MAXPATHLEN) {
        errno = ENAMETOOLONG;
        return -1;
    }
    return 0;
}

static int revenant_name_in(int directory, int pinned, const char *name, const char **out, char *buffer)
{
    if (name[0] == '/' || directory == pinned) {
        *out = name;
        return 0;
    }
    if (revenant_absolute(directory, name, buffer) == -1) {
        return -1;
    }
    *out = buffer;
    return 0;
}

__attribute__((visibility("hidden")))
int revenant_at_pair(int first_directory, const char *first, int second_directory, const char *second, struct revenant_at_pair *pair)
{
    int pinned = AT_FDCWD;
    if (first[0] != '/' && first_directory != AT_FDCWD) {
        pinned = first_directory;
    } else if (second[0] != '/' && second_directory != AT_FDCWD) {
        pinned = second_directory;
    }
    pair->directory = pinned;
    if (revenant_name_in(first_directory, pinned, first, &pair->first, pair->first_path) == -1) {
        return -1;
    }
    return revenant_name_in(second_directory, pinned, second, &pair->second, pair->second_path);
}

struct revenant_open_request {
    const char *path;
    int flags;
    int mode;
};

static int revenant_open_operation(void *context)
{
    struct revenant_open_request *request = context;
    return open(request->path, request->flags, request->mode);
}

static int revenant_openat_mode(int directory, const char *path, int flags, int mode)
{
    struct revenant_open_request request = {path, flags, mode};
    return revenant_at_within(path[0] == '/' ? AT_FDCWD : directory, revenant_open_operation, &request);
}

__attribute__((visibility("hidden")))
int revenant_openat(int directory, const char *path, int flags, ...)
{
    int mode = 0;
    if (flags & O_CREAT) {
        va_list arguments;
        va_start(arguments, flags);
        mode = va_arg(arguments, int);
        va_end(arguments);
    }
    return revenant_openat_mode(directory, path, flags, mode);
}

__attribute__((visibility("hidden")))
int openat(int directory, const char *path, int flags, ...)
{
    int mode = 0;
    if (flags & O_CREAT) {
        va_list arguments;
        va_start(arguments, flags);
        mode = va_arg(arguments, int);
        va_end(arguments);
    }
    return revenant_openat_mode(directory, path, flags, mode);
}
