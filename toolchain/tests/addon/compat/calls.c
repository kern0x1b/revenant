#define __STDC_WANT_LIB_EXT1__ 1
#include <dispatch/dispatch.h>
#include <dlfcn.h>
#include <errno.h>
#include <pthread.h>
#include <signal.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <spawn.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

int revenant_memset_s(void *, size_t, int, size_t);
void revenant_arc4random_buf(void *, size_t);
extern const char *__progname;
void *voucher_copy(void);
void *voucher_adopt(void *);
unsigned int qos_class_self(void);
int revenant_clock_getres(clockid_t, struct timespec *);
dispatch_queue_t revenant_dispatch_get_global_queue(long, unsigned long);
void shim_activate(dispatch_object_t) __asm("_dispatch_activate");
void shim_assert_queue(dispatch_queue_t) __asm("_dispatch_assert_queue$V2");

static int fails;

static void expect(int holds, const char *what)
{
    if (!holds) {
        printf("FAIL  %s\n", what);
        fails++;
    }
}

static const char *program;

static int dies(const char *scenario)
{
    fflush(stdout);
    pid_t child;
    char *arguments[] = {(char *)program, (char *)scenario, NULL};
    if (posix_spawn(&child, program, NULL, NULL, arguments, NULL) != 0)
        return -1;
    int status = 0;
    waitpid(child, &status, 0);
    return WIFSIGNALED(status) && WTERMSIG(status) != SIGALRM;
}

static void memsets(void)
{
    int (*darwin)(void *, size_t, int, size_t) = dlsym(RTLD_DEFAULT, "memset_s");
    expect(darwin && darwin != revenant_memset_s, "the test reaches Darwin's memset_s beside the shim");
    static const struct { size_t capacity, count; int null; } cases[] = {
        {16, 8, 0}, {16, 16, 0}, {16, 17, 0}, {16, SIZE_MAX, 0}, {SIZE_MAX, 4, 0}, {16, 8, 1}, {0, 0, 0},
    };
    for (size_t index = 0; index < sizeof cases / sizeof cases[0]; index++) {
        unsigned char mine[24], theirs[24];
        memset(mine, 0xaa, sizeof mine);
        memset(theirs, 0xaa, sizeof theirs);
        int got = revenant_memset_s(cases[index].null ? NULL : mine, cases[index].capacity, 0x5c, cases[index].count);
        int wanted = darwin(cases[index].null ? NULL : theirs, cases[index].capacity, 0x5c, cases[index].count);
        char what[160];
        snprintf(what, sizeof what, "memset_s(capacity %zu, count %zu%s) answers %d and writes the bytes Darwin's does",
                 cases[index].capacity, cases[index].count, cases[index].null ? ", NULL" : "", wanted);
        expect(got == wanted && memcmp(mine, theirs, sizeof mine) == 0, what);
    }
}

static void names(void)
{
    expect(__progname != NULL, "the program's name is there to read");
    expect(__progname && strcmp(__progname, getprogname()) == 0, "the program's name is the one the system gives");
    Dl_info found;
    expect(dladdr((const void *)&__progname, &found) != 0 && found.dli_fname != NULL &&
           strstr(found.dli_fname, "/lib") == NULL,
           "the name read is this program's own copy, not the system's");
}

static uint32_t revenant_test_words;

uint32_t arc4random(void)
{
    return ++revenant_test_words;
}

static void randoms(void)
{
    void (*darwin)(void *, size_t) = dlsym(RTLD_DEFAULT, "arc4random_buf");
    expect(darwin && darwin != revenant_arc4random_buf, "the test reaches Darwin's arc4random_buf beside the shim");
    static const size_t lengths[] = {0, 1, 3, 4, 5, 8, 31, 64};
    for (size_t index = 0; index < sizeof lengths / sizeof lengths[0]; index++) {
        size_t length = lengths[index];
        unsigned char mine[96], wanted[96];
        memset(mine, 0xaa, sizeof mine);
        memset(wanted, 0xaa, sizeof wanted);
        revenant_test_words = 0;
        for (size_t at = 0; at < length; at += sizeof(uint32_t)) {
            uint32_t word = at + sizeof(uint32_t) <= length ? (uint32_t)(at / sizeof(uint32_t) + 1) : (uint32_t)(length / sizeof(uint32_t) + 1);
            size_t bytes = length - at < sizeof(uint32_t) ? length - at : sizeof(uint32_t);
            memcpy(wanted + 16 + at, &word, bytes);
        }
        revenant_test_words = 0;
        revenant_arc4random_buf(mine + 16, length);
        char what[160];
        snprintf(what, sizeof what, "arc4random_buf fills %zu bytes from the stream, the tail included, and nothing around them", length);
        expect(memcmp(mine, wanted, sizeof mine) == 0, what);
    }
    unsigned char named[16], renamed[16];
    revenant_test_words = 0;
    arc4random_buf(named, sizeof named);
    revenant_test_words = 0;
    revenant_arc4random_buf(renamed, sizeof renamed);
    expect(memcmp(named, renamed, sizeof named) == 0, "the shim answers to the name of the call itself");

    revenant_test_words = 0;
    unsigned char first[32], second[32];
    revenant_arc4random_buf(first, sizeof first);
    revenant_arc4random_buf(second, sizeof second);
    expect(memcmp(first, second, sizeof first) != 0, "two fills of the same length read on through the stream");
}

static void vouchers(void)
{
    expect(voucher_copy() == NULL, "without vouchers the current voucher is none");
    expect(voucher_adopt(NULL) == NULL, "adopting none leaves none adopted before");
    expect(dies("foreign-voucher") == 1, "a voucher no system call made is refused");
}

static _Atomic(unsigned) observed;

static void *plain_thread(void *unused)
{
    (void)unused;
    unsigned int (*darwin)(void) = dlsym(RTLD_DEFAULT, "qos_class_self");
    atomic_store(&observed, qos_class_self() == darwin() ? qos_class_self() : 0xdead);
    long priorities[] = {DISPATCH_QUEUE_PRIORITY_HIGH, DISPATCH_QUEUE_PRIORITY_DEFAULT, DISPATCH_QUEUE_PRIORITY_LOW,
                         DISPATCH_QUEUE_PRIORITY_BACKGROUND};
    unsigned classes[] = {0x19, 0x15, 0x11, 0x09};
    for (int index = 0; index < 4; index++) {
        __block unsigned mine = 0, theirs = 0;
        dispatch_semaphore_t finished = dispatch_semaphore_create(0);
        dispatch_async(dispatch_get_global_queue(priorities[index], 0), ^{
            mine = qos_class_self();
            theirs = darwin();
            dispatch_semaphore_signal(finished);
        });
        dispatch_semaphore_wait(finished, DISPATCH_TIME_FOREVER);
        char what[160];
        snprintf(what, sizeof what, "a worker of the global queue of priority %ld has class 0x%x as Darwin's (0x%x) says",
                 priorities[index], classes[index], theirs);
        expect(mine == classes[index] && theirs == classes[index], what);
    }
    return NULL;
}

static void classes(void)
{
    unsigned int (*darwin)(void) = dlsym(RTLD_DEFAULT, "qos_class_self");
    expect(darwin && darwin != qos_class_self, "the test reaches Darwin's qos_class_self beside the shim");
    expect(qos_class_self() == 0x21 && darwin() == 0x21, "the main thread is user-interactive, as Darwin says");
    pthread_t thread;
    pthread_create(&thread, NULL, plain_thread, NULL);
    pthread_join(thread, NULL);
    expect(atomic_load(&observed) == 0x15, "a thread from pthread_create has the default class, as Darwin says");
}

static void resolutions(void)
{
    static const struct { clockid_t clock; int as_darwin; } clocks[] = {
        {CLOCK_REALTIME, 1}, {CLOCK_MONOTONIC, 1}, {CLOCK_PROCESS_CPUTIME_ID, 1}, {CLOCK_UPTIME_RAW, 1},
        {CLOCK_UPTIME_RAW_APPROX, 1}, {CLOCK_MONOTONIC_RAW, 0}, {CLOCK_MONOTONIC_RAW_APPROX, 0}, {CLOCK_THREAD_CPUTIME_ID, 0},
    };
    for (size_t index = 0; index < sizeof clocks / sizeof clocks[0]; index++) {
        struct timespec mine = {-1, -1}, theirs = {-1, -1};
        int got = revenant_clock_getres(clocks[index].clock, &mine);
        clock_getres(clocks[index].clock, &theirs);
        char what[160];
        if (clocks[index].as_darwin) {
            snprintf(what, sizeof what, "clock %d resolves to Darwin's %ld ns", clocks[index].clock, theirs.tv_nsec);
            expect(got == 0 && mine.tv_sec == theirs.tv_sec && mine.tv_nsec == theirs.tv_nsec, what);
        } else {
            snprintf(what, sizeof what, "clock %d, which revenant_clock_gettime counts in microseconds, resolves to one", clocks[index].clock);
            expect(got == 0 && mine.tv_sec == 0 && mine.tv_nsec == 1000, what);
        }
    }
    errno = 0;
    struct timespec unused;
    expect(revenant_clock_getres((clockid_t)12345, &unused) == -1 && errno == EINVAL, "an unknown clock is refused");
    expect(revenant_clock_getres(CLOCK_REALTIME, NULL) == 0, "a known clock without a result to fill answers 0");
}

static void global_queues(void)
{
    static const struct { long identifier; long priority; } classes[] = {
        {0x21, DISPATCH_QUEUE_PRIORITY_HIGH}, {0x19, DISPATCH_QUEUE_PRIORITY_HIGH}, {0x15, DISPATCH_QUEUE_PRIORITY_DEFAULT},
        {0x11, DISPATCH_QUEUE_PRIORITY_LOW}, {0x09, DISPATCH_QUEUE_PRIORITY_BACKGROUND}, {0, DISPATCH_QUEUE_PRIORITY_DEFAULT},
        {DISPATCH_QUEUE_PRIORITY_HIGH, DISPATCH_QUEUE_PRIORITY_HIGH}, {DISPATCH_QUEUE_PRIORITY_LOW, DISPATCH_QUEUE_PRIORITY_LOW},
        {DISPATCH_QUEUE_PRIORITY_BACKGROUND, DISPATCH_QUEUE_PRIORITY_BACKGROUND},
    };
    for (size_t index = 0; index < sizeof classes / sizeof classes[0]; index++) {
        char what[160];
        snprintf(what, sizeof what, "class or priority %ld reaches the global queue of priority %ld", classes[index].identifier,
                 classes[index].priority);
        expect(revenant_dispatch_get_global_queue(classes[index].identifier, 0) == dispatch_get_global_queue(classes[index].priority, 0),
               what);
    }
    expect(revenant_dispatch_get_global_queue(7, 0) == NULL, "an identifier that is neither a class nor a priority answers NULL");
    expect(revenant_dispatch_get_global_queue(0x19, 2) == dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 2),
           "the flags reach the system unchanged");
}

static void activations(void)
{
    __block _Atomic int fired = 0;
    dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(0, 0));
    dispatch_source_set_timer(source, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_MSEC), DISPATCH_TIME_FOREVER, 0);
    dispatch_source_set_event_handler(source, ^{
        atomic_fetch_add(&fired, 1);
    });
    usleep(50000);
    expect(atomic_load(&fired) == 0, "a source nobody activated does not fire");
    shim_activate(source);
    shim_activate(source);
    for (int tick = 0; tick < 200 && atomic_load(&fired) == 0; tick++)
        usleep(5000);
    expect(atomic_load(&fired) == 1, "an activated source fires, and a second activation resumes nothing more");
    dispatch_source_cancel(source);
    dispatch_queue_t queue = dispatch_queue_create("revenant.activate", NULL);
    shim_activate(queue);
    __block int ran = 0;
    dispatch_sync(queue, ^{
        ran = 1;
    });
    expect(ran, "activating a queue, which starts active, leaves it running blocks");
}

static dispatch_queue_t serial, inner;

static void on_worker(void (^body)(void))
{
    dispatch_semaphore_t finished = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        body();
        dispatch_semaphore_signal(finished);
    });
    dispatch_semaphore_wait(finished, DISPATCH_TIME_FOREVER);
}

static int scenario(const char *name)
{
    freopen("/dev/null", "w", stderr);
    alarm(10);
    void (*darwin)(dispatch_queue_t) = dlsym(RTLD_DEFAULT, "dispatch_assert_queue$V2");
    serial = dispatch_queue_create("revenant.serial", NULL);
    inner = dispatch_queue_create("revenant.inner", NULL);
    dispatch_set_target_queue(inner, serial);
    if (!strcmp(name, "foreign-voucher"))
        voucher_adopt((void *)0x1000);
    else if (!strcmp(name, "shim-main-thread-on-serial"))
        shim_assert_queue(serial);
    else if (!strcmp(name, "darwin-main-thread-on-serial"))
        darwin(serial);
    else if (!strcmp(name, "shim-target-on-targeting"))
        dispatch_sync(serial, ^{ shim_assert_queue(inner); });
    else if (!strcmp(name, "darwin-target-on-targeting"))
        dispatch_sync(serial, ^{ darwin(inner); });
    else if (!strcmp(name, "shim-worker-on-main"))
        on_worker(^{ shim_assert_queue(dispatch_get_main_queue()); });
    else if (!strcmp(name, "darwin-worker-on-main"))
        on_worker(^{ darwin(dispatch_get_main_queue()); });
    return 0;
}

static void assertions(void)
{
    void (*darwin)(dispatch_queue_t) = dlsym(RTLD_DEFAULT, "dispatch_assert_queue$V2");
    expect(darwin != NULL, "the test reaches Darwin's dispatch_assert_queue$V2");
    serial = dispatch_queue_create("revenant.serial", NULL);
    inner = dispatch_queue_create("revenant.inner", NULL);
    dispatch_set_target_queue(inner, serial);
    shim_assert_queue(dispatch_get_main_queue());
    darwin(dispatch_get_main_queue());
    dispatch_sync(serial, ^{ shim_assert_queue(serial); darwin(serial); });
    dispatch_sync(inner, ^{ shim_assert_queue(serial); darwin(serial); shim_assert_queue(inner); });
    dispatch_sync(serial, ^{ shim_assert_queue(dispatch_get_main_queue()); darwin(dispatch_get_main_queue()); });
    dispatch_queue_t global = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
    on_worker(^{ shim_assert_queue(global); darwin(global); });
    static const char *crashes[][2] = {
        {"main-thread-on-serial", "the main thread outside a block is not on another queue"},
        {"target-on-targeting", "a block on a target queue is not on the queue that targets it"},
        {"worker-on-main", "a worker thread is not on the main queue"},
    };
    for (size_t index = 0; index < sizeof crashes / sizeof crashes[0]; index++) {
        char shim[64], system[64];
        snprintf(shim, sizeof shim, "shim-%s", crashes[index][0]);
        snprintf(system, sizeof system, "darwin-%s", crashes[index][0]);
        expect(dies(shim) == 1 && dies(system) == 1, crashes[index][1]);
    }
}

int main(int argc, char **argv)
{
    program = argv[0];
    if (argc > 1)
        return scenario(argv[1]);
    memsets();
    names();
    randoms();
    vouchers();
    classes();
    resolutions();
    global_queues();
    activations();
    assertions();
    return fails != 0;
}
