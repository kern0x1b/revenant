
#include <errno.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdio.h>
#include <sys/time.h>
#include <unistd.h>

int __ulock_wait(uint32_t operation, void *address, uint64_t value, uint32_t timeout);
int __ulock_wake(uint32_t operation, void *address, uint64_t value);

static int fails;

static void expect(int holds, const char *what)
{
    if (!holds) {
        printf("FAIL  %s\n", what);
        fails++;
    }
}

static _Atomic uint32_t narrow;
static _Atomic uint64_t wide;
static _Atomic int woke;

static void *wait_narrow(void *unused)
{
    (void)unused;
    while (atomic_load(&narrow) == 0)
        __ulock_wait(1, &narrow, 0, 0);
    atomic_fetch_add(&woke, 1);
    return NULL;
}

static void *wait_wide(void *unused)
{
    (void)unused;
    while (atomic_load(&wide) == 0)
        __ulock_wait(5, &wide, 0, 0);
    atomic_fetch_add(&woke, 1);
    return NULL;
}

static double now(void)
{
    struct timeval time;
    gettimeofday(&time, NULL);
    return time.tv_sec + time.tv_usec / 1e6;
}

int main(void)
{
    uint32_t differs = 7;
    expect(__ulock_wait(1, &differs, 3, 0) == 0, "a value that already differs returns at once");
    uint64_t same = 9;
    double started = now();
    expect(__ulock_wait(5, &same, 9, 50000) == -1 && errno == ETIMEDOUT, "a timed wait nobody wakes times out");
    expect(now() - started >= 0.04 && now() - started < 2.0, "the timeout is in microseconds");
    errno = 0;
    expect(__ulock_wake(1, &differs, 0) == -1 && errno == ENOENT, "waking an address nobody waits on says so");

    pthread_t threads[8];
    for (int index = 0; index < 4; index++)
        pthread_create(&threads[index], NULL, wait_narrow, NULL);
    for (int index = 4; index < 8; index++)
        pthread_create(&threads[index], NULL, wait_wide, NULL);
    usleep(100000);
    expect(atomic_load(&woke) == 0, "waiters sleep while the value is unchanged");
    atomic_store(&narrow, 1);
    __ulock_wake(1 | 0x100, &narrow, 0);
    atomic_store(&wide, 1);
    __ulock_wake(5 | 0x100, &wide, 0);
    for (int index = 0; index < 8; index++)
        pthread_join(threads[index], NULL);
    expect(atomic_load(&woke) == 8, "every waiter on 32-bit and 64-bit values wakes once it changes");
    return fails != 0;
}
