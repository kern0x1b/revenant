
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

int charon_openat(int directory, const char *path, int flags, ...);
int charon_fchmodat(int directory, const char *path, mode_t mode, int flags);
int charon_unlinkat(int directory, const char *path, int flags);
int charon_clock_gettime(clockid_t which, struct timespec *now);

static int fails;

static void expect(int holds, const char *what)
{
    if (!holds) {
        printf("FAIL  %s\n", what);
        fails++;
    }
}

int main(int argc, char **argv)
{
    const char *root = argv[1];
    int directory = open(root, O_RDONLY);
    int created = charon_openat(directory, "made", O_CREAT | O_WRONLY, 0640);
    expect(created >= 0, "openat creates a file relative to a directory descriptor");
    close(created);
    char absolute[1024];
    snprintf(absolute, sizeof(absolute), "%s/made", root);
    struct stat seen;
    expect(stat(absolute, &seen) == 0 && (seen.st_mode & 0777) == 0640, "openat passes the creation mode");
    int again = charon_openat(-1, absolute, O_RDONLY);
    expect(again >= 0, "an absolute path ignores the directory descriptor");
    close(again);
    expect(chdir(root) == 0, "the test can change into its folder");
    int here = charon_openat(AT_FDCWD, "made", O_RDONLY);
    expect(here >= 0, "AT_FDCWD resolves against the working directory");
    close(here);
    expect(charon_fchmodat(directory, "made", 0600, 0) == 0 && stat(absolute, &seen) == 0 &&
           (seen.st_mode & 0777) == 0600, "fchmodat changes the mode of a file relative to a descriptor");
    errno = 0;
    expect(charon_fchmodat(directory, "made", 0600, 0x4000) == -1 && errno == EINVAL, "fchmodat refuses unknown flags");
    expect(mkdirat(directory, "folder", 0700) == 0 || mkdir("folder", 0700) == 0, "the test can make a folder");
    errno = 0;
    expect(charon_unlinkat(directory, "folder", 0) == -1, "unlinkat without AT_REMOVEDIR does not remove a folder");
    expect(charon_unlinkat(directory, "folder", AT_REMOVEDIR) == 0, "unlinkat with AT_REMOVEDIR removes a folder");
    expect(charon_unlinkat(directory, "made", 0) == 0 && stat(absolute, &seen) == -1, "unlinkat removes a file");
    errno = 0;
    expect(charon_openat(-1, "relative", O_RDONLY) == -1 && errno == EBADF,
           "a relative path against a descriptor that is not open is refused");
    struct timespec raw, uptime;
    expect(charon_clock_gettime(CLOCK_MONOTONIC_RAW, &raw) == 0, "CLOCK_MONOTONIC_RAW is answered");
    expect(charon_clock_gettime(CLOCK_UPTIME_RAW, &uptime) == 0, "CLOCK_UPTIME_RAW is answered");
    expect(charon_clock_gettime(CLOCK_MONOTONIC_RAW_APPROX, &raw) == 0 &&
           charon_clock_gettime(CLOCK_UPTIME_RAW_APPROX, &uptime) == 0, "the approximate uptime clocks are answered");
    return fails != 0;
}
