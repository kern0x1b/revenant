#include <errno.h>
#include <mach/mach_time.h>
#include <pthread.h>
#include <sched.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>
#include <libkern/OSAtomic.h>

#ifdef REVENANT_DEVICE
void os_unfair_lock_lock(void *lock);
void os_unfair_lock_unlock(void *lock);
uint64_t clock_gettime_nsec_np(clockid_t which);
#define CANDIDATE_LOCK os_unfair_lock_lock
#define CANDIDATE_UNLOCK os_unfair_lock_unlock
#define CANDIDATE_NSEC clock_gettime_nsec_np
#else
#include <os/lock.h>
void __revenant_fb_os_unfair_lock_lock(void *lock);
void __revenant_fb_os_unfair_lock_unlock(void *lock);
uint64_t __revenant_fb_clock_gettime_nsec_np(clockid_t which);
#define CANDIDATE_LOCK __revenant_fb_os_unfair_lock_lock
#define CANDIDATE_UNLOCK __revenant_fb_os_unfair_lock_unlock
#define CANDIDATE_NSEC __revenant_fb_clock_gettime_nsec_np
#endif

enum {
    CLOCK_IDENTIFIER_REALTIME = 0,
    CLOCK_IDENTIFIER_MONOTONIC_RAW = 4,
    CLOCK_IDENTIFIER_MONOTONIC_RAW_APPROX = 5,
    CLOCK_IDENTIFIER_MONOTONIC = 6,
    CLOCK_IDENTIFIER_UPTIME_RAW = 8,
    CLOCK_IDENTIFIER_UPTIME_RAW_APPROX = 9,
    CLOCK_IDENTIFIER_PROCESS_CPUTIME = 12,
    CLOCK_IDENTIFIER_THREAD_CPUTIME = 16,
};

typedef struct {
    uint32_t value;
} lock_word;

typedef void (*lock_function)(void *);

static unsigned checks;

static void require(int value, const char *label)
{
    if (!value) {
        fprintf(stderr, "FAIL %s\n", label);
        exit(1);
    }
    checks++;
    printf("PASS %s\n", label);
}

static uint64_t now_nanoseconds(void)
{
    static mach_timebase_info_data_t timebase;
    if (timebase.denom == 0)
        mach_timebase_info(&timebase);
    return mach_absolute_time() * timebase.numer / timebase.denom;
}

static void sleep_milliseconds(unsigned milliseconds)
{
    struct timespec interval = {milliseconds / 1000, (long)(milliseconds % 1000) * 1000000L};
    nanosleep(&interval, NULL);
}

struct counting {
    lock_function lock;
    lock_function unlock;
    lock_word *guard;
    volatile uint64_t *counter;
    unsigned rounds;
};

static void *count(void *argument)
{
    struct counting *job = argument;
    for (unsigned round = 0; round < job->rounds; round++) {
        job->lock(job->guard);
        uint64_t seen = *job->counter;
        *job->counter = seen + 1;
        job->unlock(job->guard);
    }
    return NULL;
}

static int exclusion(lock_function lock, lock_function unlock, unsigned threads, unsigned rounds)
{
    lock_word guard = {0};
    volatile uint64_t counter = 0;
    struct counting job = {lock, unlock, &guard, &counter, rounds};
    pthread_t workers[16];
    for (unsigned index = 0; index < threads; index++)
        pthread_create(&workers[index], NULL, count, &job);
    for (unsigned index = 0; index < threads; index++)
        pthread_join(workers[index], NULL);
    return counter == (uint64_t)threads * rounds && guard.value == 0;
}

struct waiting {
    lock_function lock;
    lock_function unlock;
    lock_word *guard;
    volatile int started;
    volatile int acquired;
};

static void *wait_for_lock(void *argument)
{
    struct waiting *job = argument;
    job->started = 1;
    job->lock(job->guard);
    job->acquired = 1;
    job->unlock(job->guard);
    return NULL;
}

static int blocks_then_wakes(lock_function lock, lock_function unlock)
{
    lock_word guard = {0};
    struct waiting job = {lock, unlock, &guard, 0, 0};
    lock(&guard);
    pthread_t waiter;
    pthread_create(&waiter, NULL, wait_for_lock, &job);
    while (!job.started)
        sched_yield();
    sleep_milliseconds(100);
    int held_back = !job.acquired;
    unlock(&guard);
    uint64_t start = now_nanoseconds();
    while (!job.acquired && now_nanoseconds() - start < 2000000000ull)
        sleep_milliseconds(1);
    int woken = job.acquired;
    pthread_join(waiter, NULL);
    return held_back && woken && guard.value == 0;
}

struct foreign {
    lock_function unlock;
    lock_word *guard;
};

static void *unlock_here(void *argument)
{
    struct foreign *job = argument;
    job->unlock(job->guard);
    return NULL;
}

static int dies_by_signal(lock_function lock, lock_function unlock, int scenario)
{
    fflush(NULL);
    pid_t child = fork();
    if (child == 0) {
        freopen("/dev/null", "w", stderr);
        lock_word guard = {0};
        if (scenario == 0) {
            lock(&guard);
            lock(&guard);
        } else if (scenario == 1) {
            unlock(&guard);
        } else {
            lock(&guard);
            struct foreign job = {unlock, &guard};
            pthread_t other;
            pthread_create(&other, NULL, unlock_here, &job);
            pthread_join(other, NULL);
        }
        _exit(0);
    }
    int status = 0;
    waitpid(child, &status, 0);
    return WIFSIGNALED(status);
}

static void check_locks(const char *name, lock_function lock, lock_function unlock)
{
    char label[200];
    snprintf(label, sizeof label, "%s: an uncontended lock and unlock leave the word zero", name);
    lock_word guard = {0};
    lock(&guard);
    int taken = guard.value != 0;
    unlock(&guard);
    require(taken && guard.value == 0, label);
    snprintf(label, sizeof label, "%s: four threads count 20000 times each under the lock without a lost update", name);
    require(exclusion(lock, unlock, 4, 20000), label);
    snprintf(label, sizeof label, "%s: sixteen threads count 2000 times each without a lost update", name);
    require(exclusion(lock, unlock, 16, 2000), label);
    snprintf(label, sizeof label, "%s: a second thread waits while the lock is held and acquires it after the unlock", name);
    require(blocks_then_wakes(lock, unlock), label);
    snprintf(label, sizeof label, "%s: locking a lock the thread holds ends the process", name);
    require(dies_by_signal(lock, unlock, 0), label);
    snprintf(label, sizeof label, "%s: unlocking a lock nobody holds ends the process", name);
    require(dies_by_signal(lock, unlock, 1), label);
    snprintf(label, sizeof label, "%s: unlocking from a thread that is not the owner ends the process", name);
    require(dies_by_signal(lock, unlock, 2), label);
}

#ifndef REVENANT_DEVICE
static void host_lock(void *lock)
{
    os_unfair_lock_lock(lock);
}

static void host_unlock(void *lock)
{
    os_unfair_lock_unlock(lock);
}
#endif

static const struct {
    const char *name;
    clockid_t identifier;
} CLOCKS[] = {
    {"CLOCK_REALTIME", CLOCK_IDENTIFIER_REALTIME},
    {"CLOCK_MONOTONIC_RAW", CLOCK_IDENTIFIER_MONOTONIC_RAW},
    {"CLOCK_MONOTONIC_RAW_APPROX", CLOCK_IDENTIFIER_MONOTONIC_RAW_APPROX},
    {"CLOCK_MONOTONIC", CLOCK_IDENTIFIER_MONOTONIC},
    {"CLOCK_UPTIME_RAW", CLOCK_IDENTIFIER_UPTIME_RAW},
    {"CLOCK_UPTIME_RAW_APPROX", CLOCK_IDENTIFIER_UPTIME_RAW_APPROX},
    {"CLOCK_PROCESS_CPUTIME_ID", CLOCK_IDENTIFIER_PROCESS_CPUTIME},
    {"CLOCK_THREAD_CPUTIME_ID", CLOCK_IDENTIFIER_THREAD_CPUTIME},
};

static void burn_milliseconds(unsigned milliseconds)
{
    uint64_t start = now_nanoseconds();
    volatile uint64_t sink = 0;
    while (now_nanoseconds() - start < (uint64_t)milliseconds * 1000000ull)
        sink++;
}

static uint64_t difference(uint64_t first, uint64_t second)
{
    return first > second ? first - second : second - first;
}

static void check_clocks(void)
{
    char label[200];
    static const clockid_t invalid[] = {1, 2, 3, 7, 10, 11, 13, 14, 15, 17, 100, (clockid_t)-1};
    for (unsigned index = 0; index < sizeof invalid / sizeof *invalid; index++) {
        snprintf(label, sizeof label, "clock identifier %d is refused with 0", (int)invalid[index]);
        require(CANDIDATE_NSEC(invalid[index]) == 0, label);
#ifndef REVENANT_DEVICE
        snprintf(label, sizeof label, "clock identifier %d is refused with 0 by macOS too", (int)invalid[index]);
        require(clock_gettime_nsec_np(invalid[index]) == 0, label);
#endif
    }
    for (unsigned index = 0; index < sizeof CLOCKS / sizeof *CLOCKS; index++) {
        clockid_t identifier = CLOCKS[index].identifier;
        const char *name = CLOCKS[index].name;
        int cpu = identifier == CLOCK_IDENTIFIER_PROCESS_CPUTIME || identifier == CLOCK_IDENTIFIER_THREAD_CPUTIME;
        burn_milliseconds(cpu ? 60 : 1);
        uint64_t first = CANDIDATE_NSEC(identifier);
        sleep_milliseconds(30);
        burn_milliseconds(cpu ? 60 : 1);
        uint64_t second = CANDIDATE_NSEC(identifier);
        snprintf(label, sizeof label, "%s answers and does not run backwards", name);
        require(first != 0 && second >= first, label);
        snprintf(label, sizeof label, "%s %s over a 30 ms sleep and 60 ms of work", name, cpu ? "gains the work and not the sleep" : "gains the sleep");
        uint64_t gained = second - first;
        printf("INFO %s gained %llu ns over a 30 ms sleep and 60 ms of work\n", name, (unsigned long long)gained);
        if (cpu)
            require(gained >= 10000000ull && gained < 75000000ull, label);
        else
            require(gained >= 29000000ull && gained < 500000000ull, label);
#ifndef REVENANT_DEVICE
        int raw = identifier == CLOCK_IDENTIFIER_MONOTONIC_RAW || identifier == CLOCK_IDENTIFIER_MONOTONIC_RAW_APPROX;
        uint64_t before = CANDIDATE_NSEC(identifier);
        uint64_t reference = clock_gettime_nsec_np(identifier);
        uint64_t after = CANDIDATE_NSEC(identifier);
        if (raw) {
            printf("INFO %s: macOS reads %llu ms apart from the library's, which counts since boot by the calendar\n", name,
                   (unsigned long long)(difference(reference, before) / 1000000ull));
            uint64_t library_first = CANDIDATE_NSEC(identifier);
            uint64_t reference_first = clock_gettime_nsec_np(identifier);
            sleep_milliseconds(30);
            uint64_t library_second = CANDIDATE_NSEC(identifier);
            uint64_t reference_second = clock_gettime_nsec_np(identifier);
            snprintf(label, sizeof label, "%s gains over a 30 ms sleep what macOS gains, within 5 ms", name);
            require(difference(library_second - library_first, reference_second - reference_first) < 5000000ull, label);
        } else {
            uint64_t slack = cpu ? 20000000ull : 50000000ull;
            snprintf(label, sizeof label, "%s agrees with macOS within %llu ms (%llu ns apart)", name, (unsigned long long)(slack / 1000000ull),
                     (unsigned long long)difference(reference, before > after ? before : after));
            require(difference(reference, before) < slack && difference(reference, after) < slack, label);
        }
#endif
    }
    struct timeval calendar;
    gettimeofday(&calendar, NULL);
    uint64_t real = CANDIDATE_NSEC(CLOCK_IDENTIFIER_REALTIME);
    uint64_t expected = (uint64_t)calendar.tv_sec * 1000000000ull + (uint64_t)calendar.tv_usec * 1000ull;
    require(difference(real, expected) < 50000000ull, "CLOCK_REALTIME agrees with gettimeofday");
    require(CANDIDATE_NSEC(CLOCK_IDENTIFIER_MONOTONIC) >= CANDIDATE_NSEC(CLOCK_IDENTIFIER_UPTIME_RAW), "the clock that counts sleep is not behind the one that does not");
}

#ifdef REVENANT_DEVICE
enum { KIND_UNFAIR, KIND_PTHREAD, KIND_SPIN, KINDS };

struct inversion {
    int kind;
    lock_word unfair;
    pthread_mutex_t mutex;
    OSSpinLock spin;
    volatile int held;
    volatile int stop;
    volatile uint64_t waited;
    uint64_t iterations;
};

static void take(struct inversion *state)
{
    if (state->kind == KIND_UNFAIR)
        CANDIDATE_LOCK(&state->unfair);
    else if (state->kind == KIND_PTHREAD)
        pthread_mutex_lock(&state->mutex);
    else
        OSSpinLockLock(&state->spin);
}

static void release(struct inversion *state)
{
    if (state->kind == KIND_UNFAIR)
        CANDIDATE_UNLOCK(&state->unfair);
    else if (state->kind == KIND_PTHREAD)
        pthread_mutex_unlock(&state->mutex);
    else
        OSSpinLockUnlock(&state->spin);
}

static void work(uint64_t iterations)
{
    volatile uint64_t sink = 0;
    for (uint64_t index = 0; index < iterations; index++)
        sink += index;
}

static void *low_holder(void *argument)
{
    struct inversion *state = argument;
    take(state);
    state->held = 1;
    work(state->iterations);
    release(state);
    return NULL;
}

static void *burner(void *argument)
{
    struct inversion *state = argument;
    volatile uint64_t sink = 0;
    while (!state->stop)
        sink++;
    return NULL;
}

static void *high_waiter(void *argument)
{
    struct inversion *state = argument;
    uint64_t start = now_nanoseconds();
    take(state);
    state->waited = now_nanoseconds() - start;
    release(state);
    return NULL;
}

static pthread_t start_with_priority(void *(*entry)(void *), struct inversion *state, int priority)
{
    pthread_attr_t attributes;
    pthread_attr_init(&attributes);
    struct sched_param parameter = {priority};
    pthread_attr_setschedparam(&attributes, &parameter);
    pthread_t thread;
    pthread_create(&thread, &attributes, entry, state);
    pthread_attr_destroy(&attributes);
    return thread;
}

static uint64_t inversion_wait(int kind, uint64_t iterations, int burners)
{
    struct inversion state = {.kind = kind, .iterations = iterations};
    pthread_mutex_init(&state.mutex, NULL);
    pthread_t low = start_with_priority(low_holder, &state, 10);
    while (!state.held)
        sched_yield();
    pthread_t medium[4];
    for (int index = 0; index < burners; index++)
        medium[index] = start_with_priority(burner, &state, 40);
    pthread_t high = start_with_priority(high_waiter, &state, 60);
    pthread_join(high, NULL);
    state.stop = 1;
    for (int index = 0; index < burners; index++)
        pthread_join(medium[index], NULL);
    pthread_join(low, NULL);
    pthread_mutex_destroy(&state.mutex);
    return state.waited;
}

static void measure_inversion(void)
{
    uint64_t start = now_nanoseconds();
    work(20000000);
    uint64_t per_millisecond = 20000000ull * 1000000ull / (now_nanoseconds() - start);
    uint64_t iterations = per_millisecond * 50;
    static const char *names[KINDS] = {"os_unfair_lock", "pthread_mutex", "OSSpinLock"};
    for (int kind = 0; kind < KINDS; kind++) {
        uint64_t best_idle = UINT64_MAX, worst_idle = 0, best_loaded = UINT64_MAX, worst_loaded = 0;
        for (int round = 0; round < 5; round++) {
            uint64_t idle = inversion_wait(kind, iterations, 0);
            uint64_t loaded = inversion_wait(kind, iterations, 2);
            best_idle = idle < best_idle ? idle : best_idle;
            worst_idle = idle > worst_idle ? idle : worst_idle;
            best_loaded = loaded < best_loaded ? loaded : best_loaded;
            worst_loaded = loaded > worst_loaded ? loaded : worst_loaded;
        }
        printf("INFO priority inversion, %s: a priority 60 thread waits for a priority 10 holder of 50 ms of work: %llu to %llu ms with no other load, %llu to %llu ms with two priority 40 busy threads\n",
               names[kind], best_idle / 1000000ull, worst_idle / 1000000ull, best_loaded / 1000000ull, worst_loaded / 1000000ull);
    }
}
#endif

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
#ifdef REVENANT_DEVICE
    check_locks("the library", CANDIDATE_LOCK, CANDIDATE_UNLOCK);
#else
    check_locks("the library", __revenant_fb_os_unfair_lock_lock, __revenant_fb_os_unfair_lock_unlock);
    check_locks("macOS", host_lock, host_unlock);
#endif
    check_clocks();
#ifdef REVENANT_DEVICE
    measure_inversion();
#endif
    printf("%u checks passed\n", checks);
    return 0;
}
