
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

int revenant_clock_gettime(clockid_t which, struct timespec *now);
uint64_t revenant_clock_gettime_nsec_np(clockid_t which);
DIR *revenant_fdopendir(int descriptor);

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
    struct timespec real, first, second;
    time_t before = time(NULL);
    expect(revenant_clock_gettime(CLOCK_REALTIME, &real) == 0, "CLOCK_REALTIME is answered");
    expect(real.tv_sec >= before - 1 && real.tv_sec <= time(NULL) + 1, "CLOCK_REALTIME is the calendar time");
    expect(real.tv_nsec >= 0 && real.tv_nsec < 1000000000, "nanoseconds stay below a second");
    expect(revenant_clock_gettime(CLOCK_MONOTONIC, &first) == 0, "CLOCK_MONOTONIC is answered");
    usleep(2000);
    expect(revenant_clock_gettime(CLOCK_MONOTONIC, &second) == 0, "CLOCK_MONOTONIC is answered again");
    expect(second.tv_sec > first.tv_sec || (second.tv_sec == first.tv_sec && second.tv_nsec > first.tv_nsec),
           "CLOCK_MONOTONIC moves forward");
    static const struct { clockid_t clock; const char *what; long long tolerance; } clocks[] = {
        { CLOCK_MONOTONIC, "CLOCK_MONOTONIC counts from boot, sleep included, as Darwin's does", 5000000LL },
        { CLOCK_UPTIME_RAW, "CLOCK_UPTIME_RAW counts the time awake, as Darwin's does", 5000000LL },
        { CLOCK_PROCESS_CPUTIME_ID, "CLOCK_PROCESS_CPUTIME_ID counts this process's processor time", 20000000LL },
        { CLOCK_THREAD_CPUTIME_ID, "CLOCK_THREAD_CPUTIME_ID counts this thread's processor time", 20000000LL },
    };
    for (volatile long spin = 0; spin < 30000000; spin++) {
    }
    for (size_t index = 0; index < sizeof clocks / sizeof clocks[0]; index++) {
        struct timespec ours, darwins, later;
        int answered = revenant_clock_gettime(clocks[index].clock, &ours);
        clock_gettime(clocks[index].clock, &darwins);
        int again = revenant_clock_gettime(clocks[index].clock, &later);
        long long lead = ((long long)darwins.tv_sec - ours.tv_sec) * 1000000000LL + darwins.tv_nsec - ours.tv_nsec;
        long long lag = ((long long)later.tv_sec - darwins.tv_sec) * 1000000000LL + later.tv_nsec - darwins.tv_nsec;
        expect(answered == 0 && again == 0 && lead > -clocks[index].tolerance && lag > -clocks[index].tolerance &&
               ours.tv_nsec >= 0 && ours.tv_nsec < 1000000000, clocks[index].what);
    }
    struct timespec monotonic, raw;
    revenant_clock_gettime(CLOCK_MONOTONIC, &monotonic);
    revenant_clock_gettime(CLOCK_MONOTONIC_RAW, &raw);
    long long drift = ((long long)raw.tv_sec - monotonic.tv_sec) * 1000000000LL + raw.tv_nsec - monotonic.tv_nsec;
    expect(drift >= 0 && drift < 5000000LL,
           "CLOCK_MONOTONIC_RAW counts from boot with sleep, the only such clock iOS 6 has");
    errno = 0;
    expect(revenant_clock_gettime((clockid_t)12345, &first) == -1 && errno == EINVAL, "an unknown clock is refused");
    static const clockid_t counted[] = { CLOCK_REALTIME, CLOCK_MONOTONIC, CLOCK_UPTIME_RAW };
    for (size_t index = 0; index < sizeof counted / sizeof counted[0]; index++) {
        uint64_t ours = revenant_clock_gettime_nsec_np(counted[index]);
        uint64_t darwins = clock_gettime_nsec_np(counted[index]);
        uint64_t later = revenant_clock_gettime_nsec_np(counted[index]);
        long long lead = (long long)(darwins - ours);
        long long lag = (long long)(later - darwins);
        expect(ours != 0 && later != 0 && lead > -5000000LL && lag > -5000000LL,
               "clock_gettime_nsec_np counts the nanoseconds of the clock Darwin's counts");
    }
    errno = 0;
    uint64_t refused = clock_gettime_nsec_np((clockid_t)12345);
    int darwins_errno = errno;
    errno = 0;
    expect(revenant_clock_gettime_nsec_np((clockid_t)12345) == refused && refused == 0 && errno == darwins_errno,
           "clock_gettime_nsec_np answers an unknown clock as Darwin's does: 0, and the same errno");

    int descriptor = open(argv[1], O_RDONLY);
    DIR *directory = revenant_fdopendir(descriptor);
    expect(directory != NULL, "an open directory's descriptor becomes a directory stream");
    int seen = 0;
    struct dirent *entry;
    while (directory && (entry = readdir(directory)) != NULL) {
        seen += strcmp(entry->d_name, "marker") == 0;
    }
    expect(seen == 1, "the stream lists the directory the descriptor names");
    expect(fcntl(descriptor, F_GETFD) == -1 && errno == EBADF, "the stream owns the descriptor, as fdopendir's does");
    if (directory) {
        closedir(directory);
    }
    errno = 0;
    expect(revenant_fdopendir(-1) == NULL && errno == EBADF, "a descriptor that is not open is refused");
    return fails != 0;
}
