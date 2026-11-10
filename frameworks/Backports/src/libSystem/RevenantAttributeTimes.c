#include "../revenant_impl.h"
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <string.h>
#include <sys/attr.h>
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

static int omit_both(const struct timespec times[2])
{
    return times != NULL && times[0].tv_nsec == UTIME_OMIT && times[1].tv_nsec == UTIME_OMIT;
}

static size_t build_attributes(struct attrlist *list, struct timespec buffer[2], const struct timespec times[2])
{
    memset(list, 0, sizeof *list);
    list->bitmapcount = ATTR_BIT_MAP_COUNT;
    struct timeval now;
    if (times == NULL || times[0].tv_nsec == UTIME_NOW || times[1].tv_nsec == UTIME_NOW) {
        if (gettimeofday(&now, NULL) == -1) {
            return (size_t)-1;
        }
    }
    size_t count = 0;
    if (times == NULL || times[1].tv_nsec != UTIME_OMIT) {
        list->commonattr |= ATTR_CMN_MODTIME;
        if (times == NULL || times[1].tv_nsec == UTIME_NOW) {
            buffer[count].tv_sec = now.tv_sec;
            buffer[count].tv_nsec = now.tv_usec * 1000;
        } else {
            buffer[count] = times[1];
        }
        count++;
    }
    if (times == NULL || times[0].tv_nsec != UTIME_OMIT) {
        list->commonattr |= ATTR_CMN_ACCTIME;
        if (times == NULL || times[0].tv_nsec == UTIME_NOW) {
            buffer[count].tv_sec = now.tv_sec;
            buffer[count].tv_nsec = now.tv_usec * 1000;
        } else {
            buffer[count] = times[0];
        }
        count++;
    }
    return count;
}

static int set_link_times(const char *path, struct attrlist *list, const struct timespec buffer[2], size_t size)
{
    int fd = open(path, O_RDONLY | O_SYMLINK);
    if (fd == -1) {
        return -1;
    }
    int result = fsetattrlist(fd, list, (void *)buffer, size, 0);
    int saved = errno;
    close(fd);
    errno = saved;
    return result;
}

REVENANT_LIBSYSTEM_EXPORT int BACKPORT_IMPL(futimens)(int fd, const struct timespec times[2])
{
    struct stat status;
    if (fstat(fd, &status) == -1) {
        return -1;
    }
    if (!valid_times(times)) {
        return -1;
    }
    if (omit_both(times)) {
        return 0;
    }
    struct attrlist list;
    struct timespec buffer[2];
    size_t count = build_attributes(&list, buffer, times);
    if (count == (size_t)-1) {
        return -1;
    }
    return fsetattrlist(fd, &list, buffer, count * sizeof(struct timespec), 0);
}

REVENANT_LIBSYSTEM_EXPORT int BACKPORT_IMPL(utimensat)(int dirfd, const char *path, const struct timespec times[2], int flags)
{
    char full[PATH_MAX];
    if (revenant_absolute_path(dirfd, path, full) == -1) {
        return -1;
    }
    int nofollow = (flags & AT_SYMLINK_NOFOLLOW) != 0;
    struct stat status;
    if ((nofollow ? lstat(full, &status) : stat(full, &status)) == -1) {
        return -1;
    }
    if ((flags & ~AT_SYMLINK_NOFOLLOW) != 0) {
        errno = EINVAL;
        return -1;
    }
    if (!valid_times(times)) {
        return -1;
    }
    if (omit_both(times)) {
        return 0;
    }
    struct attrlist list;
    struct timespec buffer[2];
    size_t count = build_attributes(&list, buffer, times);
    if (count == (size_t)-1) {
        return -1;
    }
    size_t size = count * sizeof(struct timespec);
    if (nofollow && S_ISLNK(status.st_mode)) {
        return set_link_times(full, &list, buffer, size);
    }
    return setattrlist(full, &list, buffer, size, 0);
}
