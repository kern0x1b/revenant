#include <dlfcn.h>
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

struct version_entry {
    unsigned platform;
    unsigned version;
};

int __revenant_fb__availability_version_check(unsigned, const struct version_entry *);

static const char *volatile absent_string = NULL;
static const struct timespec *volatile absent_times = NULL;

static void require(int value, const char *label)
{
    if (!value) {
        fprintf(stderr, "%s: %s\n", label, strerror(errno));
        exit(1);
    }
}

static unsigned encode_version(unsigned major, unsigned minor, unsigned patch)
{
    return ((major & 0xffff) << 16) | ((minor & 0xff) << 8) | (patch & 0xff);
}

#if defined(REVENANT_DEVICE)
#define CURRENT_PLATFORM 2
#else
#define CURRENT_PLATFORM 1
#endif

static void check_availability(void)
{
    struct version_entry skipped[] = {{CURRENT_PLATFORM == 1 ? 2 : 1, encode_version(99, 0, 0)}};
    require(__revenant_fb__availability_version_check(0, NULL) == 1, "availability count zero");
    require(__revenant_fb__availability_version_check(1, skipped) == 1, "availability skips another platform");
    struct version_entry skipped_then_current[] = {{CURRENT_PLATFORM == 1 ? 2 : 1, encode_version(99, 0, 0)},
                                                   {CURRENT_PLATFORM, encode_version(0, 0, 0)}};
    require(__revenant_fb__availability_version_check(2, skipped_then_current) == 1, "availability reaches the current platform");
    struct version_entry first_wins[] = {{CURRENT_PLATFORM, encode_version(99, 0, 0)}, {CURRENT_PLATFORM, encode_version(0, 0, 0)}};
    require(__revenant_fb__availability_version_check(2, first_wins) == 0, "availability first matching entry decides");
    struct version_entry second_wins[] = {{CURRENT_PLATFORM, encode_version(0, 0, 0)}, {CURRENT_PLATFORM, encode_version(99, 0, 0)}};
    require(__revenant_fb__availability_version_check(2, second_wins) == 1, "availability stops at the first matching entry");
#if defined(REVENANT_DEVICE)
    struct version_entry exact[] = {{2, encode_version(6, 1, 3)}};
    struct version_entry newer[] = {{2, encode_version(6, 1, 4)}};
    struct version_entry later[] = {{2, encode_version(7, 0, 0)}};
    struct version_entry macos_future[] = {{1, encode_version(99, 0, 0)}};
    require(__revenant_fb__availability_version_check(1, exact) == 1, "availability reads the device release");
    require(__revenant_fb__availability_version_check(1, newer) == 0, "availability refuses a newer patch");
    require(__revenant_fb__availability_version_check(1, later) == 0, "availability refuses a newer major");
    require(__revenant_fb__availability_version_check(1, macos_future) == 1, "availability ignores macOS on the device");
#else
    void *handle = dlopen("/usr/lib/libSystem.B.dylib", RTLD_NOW);
    require(handle != NULL, "open the system libSystem");
    int (*native)(unsigned, const struct version_entry *) = (int (*)(unsigned, const struct version_entry *))dlsym(handle, "_availability_version_check");
    require(native != NULL, "resolve the system availability check");
    for (unsigned major = 0; major <= 40; major++) {
        struct version_entry one[] = {{CURRENT_PLATFORM, encode_version(major, 0, 0)}};
        require(__revenant_fb__availability_version_check(1, one) == native(1, one), "availability host parity by major");
    }
    for (unsigned minor = 0; minor <= 8; minor++) {
        struct version_entry one[] = {{CURRENT_PLATFORM, encode_version(27, minor, 0)}};
        require(__revenant_fb__availability_version_check(1, one) == native(1, one), "availability host parity by minor");
    }
    for (unsigned patch = 0; patch <= 8; patch++) {
        struct version_entry one[] = {{CURRENT_PLATFORM, encode_version(27, 0, patch)}};
        require(__revenant_fb__availability_version_check(1, one) == native(1, one), "availability host parity by patch");
    }
    struct version_entry mixed[] = {{2, encode_version(99, 0, 0)}, {1, encode_version(26, 0, 0)}, {2, encode_version(1, 0, 0)}};
    require(__revenant_fb__availability_version_check(3, mixed) == native(3, mixed), "availability host parity across platforms");
    require(__revenant_fb__availability_version_check(0, NULL) == native(0, NULL), "availability host parity at count zero");
#endif
}

int main(int argc, char **argv)
{
    require(argc == 2, "test root argument");
    struct timespec resolution;
    require(__revenant_fb_clock_getres(CLOCK_REALTIME, &resolution) == 0, "clock_getres realtime");
    require(resolution.tv_sec == 0 && resolution.tv_nsec > 0, "clock_getres resolution");
    check_availability();
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
    errno = 0;
    require(__revenant_fb_symlinkat(absent_string, directory, "bad") == -1 && errno == EFAULT, "symlinkat absent target");
#ifndef REVENANT_DEVICE
    errno = 0;
    int native_symlink_result = symlinkat("destination", file, "native-bad");
    int native_symlink_errno = errno;
    require(native_symlink_result == -1 && native_symlink_errno == ENOTDIR, "host symlinkat non-directory");
    errno = 0;
    int native_absent_target = symlinkat(absent_string, directory, "native-absent");
    int native_absent_errno = errno;
    require(native_absent_target == -1 && native_absent_errno == EFAULT, "host symlinkat absent target");
#endif
    struct timespec times[2] = {{1480000000, 123456789}, {1480000001, 987654321}};
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
    require(status.st_atimespec.tv_sec == times[0].tv_sec && status.st_atimespec.tv_nsec == times[0].tv_nsec, "futimens atime exact");
    require(status.st_mtimespec.tv_sec == times[1].tv_sec && status.st_mtimespec.tv_nsec == times[1].tv_nsec, "futimens mtime exact");
#else
    require(status.st_atimespec.tv_sec == times[0].tv_sec && status.st_atimespec.tv_nsec == 0, "futimens atime with iOS 6 precision");
    require(status.st_mtimespec.tv_sec == times[1].tv_sec && status.st_mtimespec.tv_nsec == 0, "futimens mtime with iOS 6 precision");
#endif
    require(status.st_atimespec.tv_sec == host_status.st_atimespec.tv_sec, "futimens host atime parity");
    require(status.st_atimespec.tv_nsec / 1000 == host_status.st_atimespec.tv_nsec / 1000, "futimens host atime microsecond parity");
    require(status.st_mtimespec.tv_sec == host_status.st_mtimespec.tv_sec, "futimens host mtime parity");
    require(status.st_mtimespec.tv_nsec / 1000 == host_status.st_mtimespec.tv_nsec / 1000, "futimens host mtime microsecond parity");
    struct timespec omitted[2] = {{0, UTIME_OMIT}, {0, UTIME_OMIT}};
    require(fstat(file, &status) == 0, "fstat before omitted times");
    struct timespec before_omit[2] = {{status.st_atimespec.tv_sec, status.st_atimespec.tv_nsec},
                                      {status.st_mtimespec.tv_sec, status.st_mtimespec.tv_nsec}};
    require(__revenant_fb_futimens(file, omitted) == 0, "futimens both omitted");
#ifndef REVENANT_DEVICE
    require(futimens(host_file, omitted) == 0, "host futimens both omitted");
#endif
    require(fstat(file, &status) == 0, "fstat after omitted times");
    require(status.st_atimespec.tv_sec == before_omit[0].tv_sec && status.st_atimespec.tv_nsec == before_omit[0].tv_nsec &&
            status.st_mtimespec.tv_sec == before_omit[1].tv_sec && status.st_mtimespec.tv_nsec == before_omit[1].tv_nsec,
            "futimens omitted timestamps unchanged");
    struct timespec excluded[2] = {{times[0].tv_sec, times[0].tv_nsec}, {0, UTIME_OMIT}};
    require(__revenant_fb_futimens(file, excluded) == 0, "futimens explicit and omitted");
    require(fstat(file, &status) == 0, "fstat after explicit and omitted");
    require(status.st_mtimespec.tv_sec == before_omit[1].tv_sec && status.st_mtimespec.tv_nsec == before_omit[1].tv_nsec,
            "futimens omitted mtime unchanged");
#ifndef REVENANT_DEVICE
    require(status.st_atimespec.tv_sec == times[0].tv_sec && status.st_atimespec.tv_nsec == times[0].tv_nsec, "futimens explicit atime exact");
#else
    require(status.st_atimespec.tv_sec == times[0].tv_sec && status.st_atimespec.tv_nsec == 0, "futimens explicit atime with iOS 6 precision");
#endif
    struct timespec invalid[2] = {{0, 1000000000}, {0, 0}};
    errno = 0;
    require(__revenant_fb_futimens(file, invalid) == -1 && errno == EINVAL, "futimens invalid nanoseconds");
    errno = 0;
    require(__revenant_fb_utimensat(directory, "file", invalid, 0) == -1 && errno == EINVAL, "utimensat invalid nanoseconds");
    errno = 0;
    require(__revenant_fb_utimensat(directory, "file", times, 0x40000000) == -1 && errno == EINVAL, "utimensat unknown flags");
    errno = 0;
    require(__revenant_fb_futimens(-1, times) == -1 && errno == EBADF, "futimens bad fd");
    errno = 0;
    require(__revenant_fb_utimensat(-1, "file", times, 0) == -1 && errno == EBADF, "utimensat bad fd");
    errno = 0;
    require(__revenant_fb_utimensat(-1, absent_string, times, 0) == -1 && errno == EFAULT, "utimensat absent path");
    errno = 0;
    require(__revenant_fb_utimensat(directory, "", times, 0) == -1 && errno == ENOENT, "utimensat empty path");
    errno = 0;
    require(__revenant_fb_utimensat(file, "file", times, 0) == -1 && errno == ENOTDIR, "utimensat non-directory descriptor");
    char missing[PATH_MAX];
    require(snprintf(missing, sizeof missing, "%s/missing", root) > 0, "missing path");
    errno = 0;
    require(__revenant_fb_utimensat(directory, missing, omitted, 0) == -1 && errno == ENOENT, "utimensat omitted missing path");
#ifndef REVENANT_DEVICE
    errno = 0;
    int native_bad_fd = futimens(-1, times);
    int native_bad_fd_errno = errno;
    require(native_bad_fd == -1 && native_bad_fd_errno == EBADF, "host futimens bad fd precedence");
    errno = 0;
    int native_absent_path = utimensat(-1, absent_string, times, 0);
    int native_absent_path_errno = errno;
    require(native_absent_path == -1 && native_absent_path_errno == EFAULT, "host utimensat absent path precedence");
    errno = 0;
    int native_empty = utimensat(directory, "", times, 0);
    int native_empty_errno = errno;
    require(native_empty == -1 && native_empty_errno == ENOENT, "host utimensat empty path precedence");
    errno = 0;
    int native_missing = utimensat(directory, "missing", times, 0);
    int native_missing_errno = errno;
    require(native_missing == -1 && native_missing_errno == ENOENT, "host utimensat missing path precedence");
#endif
    struct timeval before_now;
    struct timeval after_now;
    struct timespec now_times[2] = {{0, UTIME_NOW}, {0, UTIME_NOW}};
    require(gettimeofday(&before_now, NULL) == 0, "window start");
    require(__revenant_fb_futimens(file, now_times) == 0, "futimens both now");
    require(gettimeofday(&after_now, NULL) == 0, "window end");
    require(fstat(file, &status) == 0, "fstat after now");
    require(status.st_atimespec.tv_sec >= before_now.tv_sec && status.st_atimespec.tv_sec <= after_now.tv_sec + 1, "futimens atime window");
    require(status.st_mtimespec.tv_sec >= before_now.tv_sec && status.st_mtimespec.tv_sec <= after_now.tv_sec + 1, "futimens mtime window");
    require(__revenant_fb_utimensat(directory, "file", times, 0) == 0, "utimensat explicit");
#ifndef REVENANT_DEVICE
    require(utimensat(directory, "host-file", times, 0) == 0, "host utimensat explicit");
    require(fstat(file, &status) == 0 && fstat(host_file, &host_status) == 0, "fstat after utimensat");
    require(status.st_atimespec.tv_sec == times[0].tv_sec && status.st_atimespec.tv_nsec == times[0].tv_nsec, "utimensat atime exact");
    require(status.st_mtimespec.tv_sec == times[1].tv_sec && status.st_mtimespec.tv_nsec == times[1].tv_nsec, "utimensat mtime exact");
    require(status.st_atimespec.tv_sec == host_status.st_atimespec.tv_sec && status.st_atimespec.tv_nsec == host_status.st_atimespec.tv_nsec, "utimensat host atime parity");
    require(status.st_mtimespec.tv_sec == host_status.st_mtimespec.tv_sec && status.st_mtimespec.tv_nsec == host_status.st_mtimespec.tv_nsec, "utimensat host mtime parity");
#else
    require(fstat(file, &status) == 0, "fstat after utimensat");
    require(status.st_atimespec.tv_sec == times[0].tv_sec && status.st_atimespec.tv_nsec == 0, "utimensat atime with iOS 6 precision");
    require(status.st_mtimespec.tv_sec == times[1].tv_sec && status.st_mtimespec.tv_nsec == 0, "utimensat mtime with iOS 6 precision");
#endif
    struct timespec update[2] = {{0, UTIME_NOW}, {0, UTIME_OMIT}};
    require(fstat(file, &status) == 0, "fstat before now and omit");
    struct timespec prior_mtime = status.st_mtimespec;
    require(__revenant_fb_utimensat(directory, "file", update, 0) == 0, "utimensat now and omit");
    require(fstat(file, &status) == 0, "fstat after now and omit");
    require(status.st_mtimespec.tv_sec == prior_mtime.tv_sec && status.st_mtimespec.tv_nsec == prior_mtime.tv_nsec,
            "utimensat omitted mtime unchanged");
    require(__revenant_fb_utimensat(directory, "file", absent_times, 0) == 0, "utimensat absent times");
#ifndef REVENANT_DEVICE
    require(fstat(host_file, &host_status) == 0, "fstat host before now and omit");
    struct timespec host_prior_mtime = host_status.st_mtimespec;
    require(utimensat(directory, "host-file", update, 0) == 0, "host utimensat now and omit");
    require(fstat(host_file, &host_status) == 0, "fstat host after now and omit");
    require(host_status.st_mtimespec.tv_sec == host_prior_mtime.tv_sec && host_status.st_mtimespec.tv_nsec == host_prior_mtime.tv_nsec, "host utimensat omitted mtime unchanged");
#endif
    char absolute[PATH_MAX];
    require(snprintf(absolute, sizeof absolute, "%s/link", root) > 0, "absolute path");
    require(__revenant_fb_utimensat(-1, absolute, times, AT_SYMLINK_NOFOLLOW) == 0, "absolute ignores dirfd");
#ifndef REVENANT_DEVICE
    require(utimensat(directory, "host-link", times, AT_SYMLINK_NOFOLLOW) == 0, "host utimensat nofollow");
#endif
    require(lstat(absolute, &status) == 0, "lstat link");
#ifndef REVENANT_DEVICE
    require(status.st_mtimespec.tv_sec == times[1].tv_sec && status.st_mtimespec.tv_nsec == times[1].tv_nsec, "nofollow updates symlink exactly");
#else
    require(status.st_mtimespec.tv_sec == times[1].tv_sec && status.st_mtimespec.tv_nsec == 0, "nofollow updates symlink with iOS 6 timestamp precision");
#endif
#ifndef REVENANT_DEVICE
    require(snprintf(absolute, sizeof absolute, "%s/host-link", root) > 0, "host link path");
    require(lstat(absolute, &host_status) == 0, "lstat host link");
    require(status.st_mtimespec.tv_sec == host_status.st_mtimespec.tv_sec && status.st_mtimespec.tv_nsec == host_status.st_mtimespec.tv_nsec, "nofollow host mtime parity");
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
