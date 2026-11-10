#include "../revenant_impl.h"
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>
#include "RevenantAtPath.h"

#define REVENANT_LIBSYSTEM_EXPORT __attribute__((visibility("default")))

static int valid_times(const struct timespec times[2])
{
    if (times == NULL) {
        return 1;
    }
    for (size_t index = 0; index < 2; index++) {
        long nanoseconds = times[index].tv_nsec;
        if (nanoseconds != UTIME_NOW && nanoseconds != UTIME_OMIT && (nanoseconds < 0 || nanoseconds >= 1000000000L)) {
            errno = EINVAL;
            return 0;
        }
    }
    return 1;
}

static int make_times(const struct timespec times[2], const struct stat *status, struct timeval output[2])
{
    struct timeval now;
    if (times == NULL || times[0].tv_nsec == UTIME_NOW || times[1].tv_nsec == UTIME_NOW) {
        if (gettimeofday(&now, NULL) == -1) {
            return -1;
        }
    }
    for (size_t index = 0; index < 2; index++) {
        if (times == NULL || times[index].tv_nsec == UTIME_NOW) {
            output[index] = now;
        } else if (times[index].tv_nsec == UTIME_OMIT) {
            output[index].tv_sec = index == 0 ? status->st_atimespec.tv_sec : status->st_mtimespec.tv_sec;
            output[index].tv_usec = (index == 0 ? status->st_atimespec.tv_nsec : status->st_mtimespec.tv_nsec) / 1000;
        } else {
            output[index].tv_sec = times[index].tv_sec;
            output[index].tv_usec = times[index].tv_nsec / 1000;
        }
    }
    return 0;
}

static int omit_both(const struct timespec times[2])
{
    return times != NULL && times[0].tv_nsec == UTIME_OMIT && times[1].tv_nsec == UTIME_OMIT;
}

static int owned_or_writable_fd(int fd, const struct stat *status)
{
    if (geteuid() == 0 || status->st_uid == geteuid()) {
        return 1;
    }
    int mode = fcntl(fd, F_GETFL);
    if (mode != -1 && (mode & O_ACCMODE) != O_RDONLY) {
        return 1;
    }
    errno = EPERM;
    return 0;
}

REVENANT_LIBSYSTEM_EXPORT int BACKPORT_IMPL(futimens)(int fd, const struct timespec times[2])
{
    if (!valid_times(times)) {
        return -1;
    }
    struct stat status;
    if (fstat(fd, &status) == -1) {
        return -1;
    }
    if (omit_both(times)) {
        return owned_or_writable_fd(fd, &status) ? 0 : -1;
    }
    struct timeval values[2];
    if (make_times(times, &status, values) == -1) {
        return -1;
    }
    return futimes(fd, values);
}

REVENANT_LIBSYSTEM_EXPORT int BACKPORT_IMPL(utimensat)(int dirfd, const char *path, const struct timespec times[2], int flags)
{
    if (flags & ~AT_SYMLINK_NOFOLLOW) {
        errno = EINVAL;
        return -1;
    }
    if (!valid_times(times)) {
        return -1;
    }
    char full[PATH_MAX];
    if (revenant_absolute_path(dirfd, path, full) == -1) {
        return -1;
    }
    struct stat status;
    int nofollow = (flags & AT_SYMLINK_NOFOLLOW) != 0;
    if ((nofollow ? lstat(full, &status) : stat(full, &status)) == -1) {
        return -1;
    }
    if (omit_both(times)) {
        if (nofollow && (geteuid() != 0 && status.st_uid != geteuid())) {
            errno = EPERM;
            return -1;
        }
        if (!nofollow && geteuid() != 0 && status.st_uid != geteuid() && access(full, W_OK) == -1) return -1;
        return 0;
    }
    struct timeval values[2];
    if (make_times(times, &status, values) == -1) {
        return -1;
    }
    if (!nofollow || !S_ISLNK(status.st_mode)) {
        return utimes(full, values);
    }
    int fd = open(full, O_RDONLY | O_SYMLINK);
    if (fd == -1) {
        return -1;
    }
    int result = futimes(fd, values);
    int saved = errno;
    close(fd);
    errno = saved;
    return result;
}
