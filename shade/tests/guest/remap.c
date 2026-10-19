// remap.c: guest regression test for stale translated code.
//
// 1. Images swapped at one address: dlopen A, call it, dlclose, dlopen B -
//    which dyld places where A was - and call again. The call must run B's
//    code, never A's translation. Repeated, alternating.
// 2. Protection churn: threads keep calling a function while another thread
//    takes execute permission away from its page and gives it back. Calls
//    between the churn must return the right value; a call while the page is
//    not executable faults, which the test catches and counts.
//
// Prints one line per part and exits with the number of failures.
#include <dlfcn.h>
#include <pthread.h>
#include <setjmp.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

typedef int (*value_fn)(void);

static int swap_images(const char *first, const char *second, int rounds)
{
    int failures = 0, same_base = 0;
    uintptr_t base = 0;
    for (int round = 0; round < rounds; ++round) {
        const char *path = (round & 1) ? second : first;
        const int expected = (round & 1) ? 2 : 1;
        void *image = dlopen(path, RTLD_NOW | RTLD_LOCAL);
        if (!image) {
            printf("swap round %d: dlopen %s failed: %s\n", round, path, dlerror());
            return failures + 1;
        }
        value_fn value = (value_fn)dlsym(image, "remap_value");
        int got = 0;
        for (int call = 0; call < 64; ++call)   // hot enough to be translated
            got = value();
        uintptr_t here = (uintptr_t)value & ~(uintptr_t)0xfff;
        if (round == 0) base = here;
        else if (here == base) ++same_base;
        if (got != expected) {
            if (failures < 5)
                printf("swap round %d: %s at %p returned %d, expected %d\n",
                       round, path, (void *)value, got, expected);
            ++failures;
        }
        dlclose(image);
    }
    printf("swap: %d rounds, %d at the first base, %d wrong\n", rounds, same_base, failures);
    return failures;
}

static value_fn churned;
static volatile int stop_callers;
static volatile int wrong_calls;
static volatile long calls;
static volatile long faults;
static pthread_key_t escape_key;   // no __thread before iOS 8

static void on_fault(int signal)
{
    (void)signal;
    sigjmp_buf *escape = pthread_getspecific(escape_key);
    if (escape) siglongjmp(*escape, 1);
    _exit(99);
}

static void *caller(void *argument)
{
    (void)argument;
    sigjmp_buf escape;
    pthread_setspecific(escape_key, &escape);
    while (!stop_callers) {
        if (sigsetjmp(escape, 1) == 0) {
            if (churned() != 1) ++wrong_calls;
            ++calls;
        } else {
            ++faults;
        }
    }
    return NULL;
}

static int churn_protection(const char *path, int rounds)
{
    void *image = dlopen(path, RTLD_NOW | RTLD_LOCAL);
    if (!image) { printf("churn: dlopen failed: %s\n", dlerror()); return 1; }
    churned = (value_fn)dlsym(image, "remap_value");
    void *page = (void *)((uintptr_t)churned & ~(uintptr_t)(getpagesize() - 1));
    pthread_key_create(&escape_key, NULL);
    // The handler leaves with siglongjmp, which on iOS 6 does not restore the
    // signal mask; SA_NODEFER keeps the next fault deliverable.
    struct sigaction action;
    memset(&action, 0, sizeof action);
    action.sa_handler = on_fault;
    action.sa_flags = SA_NODEFER;
    sigaction(SIGBUS, &action, NULL);
    sigaction(SIGSEGV, &action, NULL);
    pthread_t threads[3];
    for (int i = 0; i < 3; ++i) pthread_create(&threads[i], NULL, caller, NULL);
    int protect_errors = 0;
    for (int round = 0; round < rounds; ++round) {
        protect_errors += mprotect(page, getpagesize(), PROT_READ) != 0;
        usleep(200);
        protect_errors += mprotect(page, getpagesize(), PROT_READ | PROT_EXEC) != 0;
        usleep(200);
    }
    stop_callers = 1;
    for (int i = 0; i < 3; ++i) pthread_join(threads[i], NULL);
    // A device faults every call made while the page is not executable.
    printf("churn: %d rounds, %ld calls, %ld faults, %d wrong, %d mprotect errors\n",
           rounds, calls, faults, wrong_calls, protect_errors);
    return wrong_calls + protect_errors;
}

int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    const char *first = argc > 2 ? argv[1] : "/usr/local/lib/charon-remap-1.dylib";
    const char *second = argc > 2 ? argv[2] : "/usr/local/lib/charon-remap-2.dylib";
    int failures = swap_images(first, second, 200);
    failures += churn_protection(first, 500);
    printf("failures=%d\n", failures);
    return failures > 255 ? 255 : failures;
}
