#include <errno.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

int timingsafe_bcmp(const void *, const void *, size_t);
char *strchrnul(const char *, int);
int rpmatch(const char *);
long long strtonum(const char *, long long, long long, const char **);
int strsignal_r(int, char *, size_t);
int timespec_get(struct timespec *, int);
int revenant_port_timingsafe_bcmp(const void *, const void *, size_t);
char *revenant_port_strchrnul(const char *, int);
int revenant_port_rpmatch(const char *);
long long revenant_port_strtonum(const char *, long long, long long, const char **);
int revenant_port_strsignal_r(int, char *, size_t);
int revenant_port_timespec_get(struct timespec *, int);

static int failures;

static void report(int passed, const char *name, long long got, long long want)
{
    if (passed) {
        printf("ok %s\n", name);
    } else {
        printf("FAIL %s got=%lld want=%lld\n", name, got, want);
        failures++;
    }
}

static void bcmp_case(void)
{
    unsigned char a[40], b[40];
    int passed = 1;
    for (size_t len = 0; len <= sizeof(a) && passed; len++) {
        for (size_t i = 0; i < sizeof(a); i++)
            a[i] = b[i] = (unsigned char)(i * 37 + len);
        if ((timingsafe_bcmp(a, b, len) != 0) != (revenant_port_timingsafe_bcmp(a, b, len) != 0)) {
            report(0, "timingsafe_bcmp", 1, 0);
            passed = 0;
        }
        for (size_t at = 0; at < len && passed; at++) {
            unsigned char saved = b[at];
            b[at] ^= 0x80;
            int host = timingsafe_bcmp(a, b, len) != 0, port = revenant_port_timingsafe_bcmp(a, b, len) != 0;
            b[at] = saved;
            if (host != port || !port) {
                report(0, "timingsafe_bcmp", port, host);
                passed = 0;
            }
        }
    }
    if (passed)
        report(1, "timingsafe_bcmp", 0, 0);
}

static void strchrnul_case(void)
{
    const char *texts[] = {"", "a", "abc", "cabcc", "zzzz"};
    const int targets[] = {'a', 'c', 'z', 'q', 0, 'a' + 256};
    int passed = 1;
    for (size_t i = 0; i < sizeof(texts) / sizeof(texts[0]); i++) {
        for (size_t j = 0; j < sizeof(targets) / sizeof(targets[0]); j++) {
            long host = strchrnul(texts[i], targets[j]) - texts[i];
            long port = revenant_port_strchrnul(texts[i], targets[j]) - texts[i];
            if (host != port) {
                report(0, "strchrnul", port, host);
                passed = 0;
            }
        }
    }
    if (passed)
        report(1, "strchrnul", 0, 0);
}

static void rpmatch_case(void)
{
    const char *responses[] = {"y", "Y", "yes", "YES", "n", "N", "no", "x", "", "Yes", " y", "nope"};
    int passed = 1;
    for (size_t i = 0; i < sizeof(responses) / sizeof(responses[0]); i++) {
        int host = rpmatch(responses[i]), port = revenant_port_rpmatch(responses[i]);
        if (host != port) {
            report(0, "rpmatch", port, host);
            passed = 0;
        }
    }
    if (passed)
        report(1, "rpmatch", 0, 0);
}

static void strtonum_case(void)
{
    const char *numbers[] = {"0", "42", "-7", " 12", "12x", "", "abc", "9223372036854775807", "9223372036854775808",
                             "-9223372036854775808", "-9223372036854775809", "+5", "-", "3"};
    const long long bounds[][2] = {{LLONG_MIN, LLONG_MAX}, {0, 100}, {-10, -5}, {5, 3}, {42, 42}};
    int passed = 1;
    for (size_t i = 0; i < sizeof(numbers) / sizeof(numbers[0]); i++) {
        for (size_t j = 0; j < sizeof(bounds) / sizeof(bounds[0]); j++) {
            const char *host_error = "unset", *port_error = "unset";
            errno = 0;
            long long host = strtonum(numbers[i], bounds[j][0], bounds[j][1], &host_error);
            int host_errno = errno;
            errno = 0;
            long long port = revenant_port_strtonum(numbers[i], bounds[j][0], bounds[j][1], &port_error);
            int port_errno = errno;
            int same_error = (host_error == NULL) == (port_error == NULL) &&
                             (host_error == NULL || strcmp(host_error, port_error) == 0);
            if (host != port || host_errno != port_errno || !same_error) {
                report(0, "strtonum", port, host);
                passed = 0;
            }
        }
    }
    if (passed)
        report(1, "strtonum", 0, 0);
}

static void strsignal_case(void)
{
    const size_t sizes[] = {0, 1, 2, 5, 64};
    int passed = 1;
    for (int sig = -1; sig <= 33 && passed; sig++) {
        for (size_t s = 0; s < sizeof(sizes) / sizeof(sizes[0]) && passed; s++) {
            char host_buf[64], port_buf[64];
            memset(host_buf, '#', sizeof(host_buf));
            memset(port_buf, '#', sizeof(port_buf));
            int host = strsignal_r(sig, host_buf, sizes[s]);
            int port = revenant_port_strsignal_r(sig, port_buf, sizes[s]);
            if (host != port || (sizes[s] > 0 && strcmp(host_buf, port_buf) != 0)) {
                report(0, "strsignal_r", port, host);
                passed = 0;
            }
        }
    }
    if (passed)
        report(1, "strsignal_r", 0, 0);
}

static void timespec_case(void)
{
    struct timespec ts;
    time_t before = time(NULL);
    int port = revenant_port_timespec_get(&ts, TIME_UTC);
    time_t after = time(NULL);
    int passed = port == TIME_UTC && ts.tv_sec >= before && ts.tv_sec <= after && ts.tv_nsec >= 0 && ts.tv_nsec < 1000000000L;
    if (revenant_port_timespec_get(&ts, 0) != 0 || timespec_get(&ts, 0) != 0)
        passed = 0;
    if (passed)
        report(1, "timespec_get", 0, 0);
    else
        report(0, "timespec_get", port, TIME_UTC);
}

int main(void)
{
    bcmp_case();
    strchrnul_case();
    rpmatch_case();
    strtonum_case();
    strsignal_case();
    timespec_case();
    if (failures == 0)
        printf("checks=all failures=0\n");
    else
        printf("checks=failed failures=%d\n", failures);
    return failures;
}
