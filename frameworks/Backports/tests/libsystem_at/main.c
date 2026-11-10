#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>

int __revenant_fb_readlinkat(int, const char *, char *, size_t);
int __revenant_fb_symlinkat(const char *, int, const char *);
int __revenant_fb_futimens(int, const struct timespec [2]);
int __revenant_fb_utimensat(int, const char *, const struct timespec [2], int);
int __revenant_fb_clock_getres(clockid_t, struct timespec *);

static void require(int value, const char *label)
{
    if (!value) {
        fprintf(stderr, "%s: %s\n", label, strerror(errno));
        exit(1);
    }
}

int main(int argc, char **argv)
{
    require(argc == 2, "test root argument");
    struct timespec resolution;
    require(__revenant_fb_clock_getres(CLOCK_REALTIME, &resolution) == 0, "clock_getres realtime");
    require(resolution.tv_sec == 0 && resolution.tv_nsec > 0, "clock_getres resolution");
    char root[PATH_MAX];
    require(snprintf(root, sizeof root, "%s", argv[1]) > 0 && mkdir(root, 0700) == 0, "create test root");
    int directory = open(root, O_RDONLY);
    require(directory != -1, "open directory");
    require(__revenant_fb_symlinkat("destination", directory, "link") == 0, "symlinkat relative");
#ifndef REVENANT_DEVICE
    require(symlinkat("destination", directory, "host-link") == 0, "host symlinkat relative");
#endif
    char actual[64];
#ifndef REVENANT_DEVICE
    char expected[64];
#endif
    memset(actual, 0x5a, sizeof actual);
#ifndef REVENANT_DEVICE
    memset(expected, 0x5a, sizeof expected);
#endif
    ssize_t actual_size = __revenant_fb_readlinkat(directory, "link", actual, sizeof actual);
#ifndef REVENANT_DEVICE
    ssize_t expected_size = readlinkat(directory, "link", expected, sizeof expected);
    require(actual_size == expected_size && actual_size == 11, "readlinkat size");
    require(memcmp(actual, expected, sizeof actual) == 0 && actual[actual_size] == 0x5a, "readlinkat bytes and terminator");
#else
    require(actual_size == 11 && memcmp(actual, "destination", 11) == 0 && actual[actual_size] == 0x5a, "readlinkat bytes and terminator");
#endif
#ifndef REVENANT_DEVICE
    int original_directory = open(".", O_RDONLY);
    require(original_directory != -1 && chdir(root) == 0, "change to test root");
    memset(actual, 0x5a, sizeof actual);
    memset(expected, 0x5a, sizeof expected);
    actual_size = __revenant_fb_readlinkat(AT_FDCWD, "link", actual, sizeof actual);
    expected_size = readlinkat(AT_FDCWD, "link", expected, sizeof expected);
    require(actual_size == expected_size && memcmp(actual, expected, sizeof actual) == 0, "readlinkat AT_FDCWD parity");
    require(fchdir(original_directory) == 0 && close(original_directory) == 0, "restore working directory");
#endif
    errno = 0;
    ssize_t bad_fd_result = __revenant_fb_readlinkat(-1, "link", actual, sizeof actual);
    int bad_fd_errno = errno;
    require(bad_fd_result == -1 && bad_fd_errno == EBADF, "readlinkat bad fd");
    errno = 0;
    require(__revenant_fb_readlinkat(directory, "", actual, sizeof actual) == -1 && errno == ENOENT, "readlinkat empty path");
    char too_long[PATH_MAX + 1];
    memset(too_long, 'a', sizeof too_long - 1);
    too_long[sizeof too_long - 1] = '\0';
    errno = 0;
    require(__revenant_fb_readlinkat(directory, too_long, actual, sizeof actual) == -1 && errno == ENAMETOOLONG, "readlinkat long path");
    char file_path[PATH_MAX];
    require(snprintf(file_path, sizeof file_path, "%s/file", root) > 0, "file path");
    int file = open(file_path, O_CREAT | O_RDWR, 0600);
    require(file != -1, "create file");
    char host_file_path[PATH_MAX];
    require(snprintf(host_file_path, sizeof host_file_path, "%s/host-file", root) > 0, "host file path");
    int host_file = open(host_file_path, O_CREAT | O_RDWR, 0600);
    require(host_file != -1, "create host file");
    errno = 0;
    require(__revenant_fb_symlinkat("destination", file, "bad") == -1 && errno == ENOTDIR, "symlinkat non-directory");
#ifndef REVENANT_DEVICE
    errno = 0;
    int native_symlink_result = symlinkat("destination", file, "native-bad");
    int native_symlink_errno = errno;
    require(native_symlink_result == -1 && native_symlink_errno == ENOTDIR, "host symlinkat non-directory");
#endif
    struct timespec times[2] = {{1480000000, 123000000}, {1480000001, 987000000}};
    require(__revenant_fb_futimens(file, times) == 0, "futimens explicit");
#ifndef REVENANT_DEVICE
    require(futimens(host_file, times) == 0, "host futimens explicit");
#else
    struct timeval host_times[2] = {{times[0].tv_sec, times[0].tv_nsec / 1000}, {times[1].tv_sec, times[1].tv_nsec / 1000}};
    require(futimes(host_file, host_times) == 0, "host futimes explicit");
#endif
    struct stat status;
    struct stat host_status;
    require(fstat(file, &status) == 0, "fstat file");
    require(fstat(host_file, &host_status) == 0, "fstat host file");
#ifndef REVENANT_DEVICE
    require(status.st_atimespec.tv_sec == times[0].tv_sec && status.st_atimespec.tv_nsec / 1000 == times[0].tv_nsec / 1000, "futimens atime");
    require(status.st_mtimespec.tv_sec == times[1].tv_sec && status.st_mtimespec.tv_nsec / 1000 == times[1].tv_nsec / 1000, "futimens mtime");
#else
    require(status.st_atimespec.tv_sec == times[0].tv_sec && status.st_mtimespec.tv_sec == times[1].tv_sec, "futimens seconds");
#endif
    require(status.st_atimespec.tv_sec == host_status.st_atimespec.tv_sec && status.st_atimespec.tv_nsec / 1000 == host_status.st_atimespec.tv_nsec / 1000, "futimens host atime parity");
    require(status.st_mtimespec.tv_sec == host_status.st_mtimespec.tv_sec && status.st_mtimespec.tv_nsec / 1000 == host_status.st_mtimespec.tv_nsec / 1000, "futimens host mtime parity");
    struct timespec omitted[2] = {{0, UTIME_OMIT}, {0, UTIME_OMIT}};
#ifndef REVENANT_DEVICE
    require(__revenant_fb_futimens(file, omitted) == 0, "futimens both omitted");
    require(futimens(host_file, omitted) == 0, "host futimens both omitted");
#else
    require(fstat(file, &status) == 0, "fstat before omitted times");
    struct timespec before_omit[2] = {{status.st_atimespec.tv_sec, status.st_atimespec.tv_nsec}, {status.st_mtimespec.tv_sec, status.st_mtimespec.tv_nsec}};
    require(__revenant_fb_futimens(file, omitted) == 0, "futimens both omitted");
    require(fstat(file, &status) == 0, "fstat after omitted times");
    require(status.st_atimespec.tv_sec == before_omit[0].tv_sec && status.st_atimespec.tv_nsec == before_omit[0].tv_nsec &&
            status.st_mtimespec.tv_sec == before_omit[1].tv_sec && status.st_mtimespec.tv_nsec == before_omit[1].tv_nsec, "futimens omitted timestamps unchanged");
#endif
    struct timespec invalid[2] = {{0, 1000000000}, {0, 0}};
    errno = 0;
    require(__revenant_fb_futimens(file, invalid) == -1 && errno == EINVAL, "futimens invalid nanoseconds");
    struct timespec update[2] = {{0, UTIME_NOW}, {0, UTIME_OMIT}};
    require(__revenant_fb_utimensat(directory, "file", update, 0) == 0, "utimensat now and omit");
#ifndef REVENANT_DEVICE
    require(utimensat(directory, "host-file", update, 0) == 0, "host utimensat now and omit");
    require(fstat(file, &status) == 0 && fstat(host_file, &host_status) == 0, "fstat after utimensat");
    require(status.st_mtimespec.tv_sec == host_status.st_mtimespec.tv_sec && status.st_mtimespec.tv_nsec / 1000 == host_status.st_mtimespec.tv_nsec / 1000, "utimensat host mtime parity");
#else
    require(status.st_mtimespec.tv_sec == before_omit[1].tv_sec && status.st_mtimespec.tv_nsec == before_omit[1].tv_nsec, "utimensat omitted mtime unchanged");
#endif
    errno = 0;
    int empty_result = __revenant_fb_utimensat(directory, "", update, 0);
    int empty_errno = errno;
#ifndef REVENANT_DEVICE
    errno = 0;
    int native_empty_result = utimensat(directory, "", update, 0);
    int native_empty_errno = errno;
    require(empty_result == native_empty_result && empty_errno == native_empty_errno, "utimensat empty path parity");
#else
    require(empty_result == -1 && empty_errno == ENOENT, "utimensat empty path");
#endif
    char absolute[PATH_MAX];
    require(snprintf(absolute, sizeof absolute, "%s/link", root) > 0, "absolute path");
    require(__revenant_fb_utimensat(-1, absolute, times, AT_SYMLINK_NOFOLLOW) == 0, "absolute ignores dirfd");
#ifndef REVENANT_DEVICE
    require(utimensat(directory, "host-link", times, AT_SYMLINK_NOFOLLOW) == 0, "host utimensat nofollow");
#endif
    require(lstat(absolute, &status) == 0, "lstat link");
#ifndef REVENANT_DEVICE
    require(status.st_mtimespec.tv_sec == times[1].tv_sec && status.st_mtimespec.tv_nsec / 1000 == times[1].tv_nsec / 1000, "nofollow updates symlink");
#else
    require(status.st_mtimespec.tv_sec == times[1].tv_sec && status.st_mtimespec.tv_nsec == 0, "nofollow updates symlink with iOS 6 timestamp precision");
#endif
#ifndef REVENANT_DEVICE
    require(snprintf(absolute, sizeof absolute, "%s/host-link", root) > 0, "host link path");
    require(lstat(absolute, &host_status) == 0, "lstat host link");
    require(status.st_mtimespec.tv_sec == host_status.st_mtimespec.tv_sec && status.st_mtimespec.tv_nsec / 1000 == host_status.st_mtimespec.tv_nsec / 1000, "nofollow host mtime parity");
#endif
    close(file);
    close(host_file);
    close(directory);
    unlink(absolute);
    unlink(file_path);
    unlink(host_file_path);
#ifndef REVENANT_DEVICE
    snprintf(absolute, sizeof absolute, "%s/host-link", root);
    unlink(absolute);
#endif
    snprintf(absolute, sizeof absolute, "%s/link", root);
    unlink(absolute);
    rmdir(root);
    return 0;
}
