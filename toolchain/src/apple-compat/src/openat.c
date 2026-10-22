#include "at_within.h"
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#define REVENANT_AT_ANY (-100)

__attribute__((weak, visibility("default")))
pthread_mutex_t revenant_at_directory_lock = PTHREAD_MUTEX_INITIALIZER;

__attribute__((visibility("hidden")))
int revenant_at_within(int directory, revenant_at_operation operation, void *context)
{
    if (directory == AT_FDCWD) {
        return operation(context);
    }
    pthread_mutex_lock(&revenant_at_directory_lock);
    int saved = open(".", O_RDONLY);
    if (saved == -1) {
        int failure = errno;
        pthread_mutex_unlock(&revenant_at_directory_lock);
        errno = failure;
        return -1;
    }
    if (fchdir(directory) == -1) {
        int failure = errno;
        close(saved);
        pthread_mutex_unlock(&revenant_at_directory_lock);
        errno = failure;
        return -1;
    }
    int result = operation(context);
    int failure = errno;
    if (fchdir(saved) == -1) {
        fprintf(stderr, "apple-compat: the working directory could not be restored after an *at call\n");
        abort();
    }
    close(saved);
    pthread_mutex_unlock(&revenant_at_directory_lock);
    errno = failure;
    return result;
}

__attribute__((visibility("hidden")))
int revenant_at_pair(int first_directory, const char *first, int second_directory, const char *second, int *directory)
{
    int first_pinned = first[0] == '/' ? REVENANT_AT_ANY : first_directory;
    int second_pinned = second[0] == '/' ? REVENANT_AT_ANY : second_directory;
    if (first_pinned == REVENANT_AT_ANY) {
        first_pinned = second_pinned;
    }
    if (second_pinned == REVENANT_AT_ANY) {
        second_pinned = first_pinned;
    }
    if (first_pinned != second_pinned) {
        errno = ENOTSUP;
        return -1;
    }
    *directory = first_pinned == REVENANT_AT_ANY ? AT_FDCWD : first_pinned;
    return 0;
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
