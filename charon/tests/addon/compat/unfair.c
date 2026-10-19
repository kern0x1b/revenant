
#include <dlfcn.h>
#include <mach/mach.h>
#include <pthread.h>
#include <signal.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <sys/wait.h>
#include <unistd.h>

typedef struct { uint32_t value; } lock_t;
typedef struct { lock_t lock; uint32_t count; } recursive_t;
void os_unfair_lock_lock(lock_t *);
bool os_unfair_lock_trylock(lock_t *);
void os_unfair_lock_unlock(lock_t *);
void os_unfair_recursive_lock_lock_with_options(recursive_t *, uint32_t);
void os_unfair_recursive_lock_unlock(recursive_t *);

static int fails;

static void expect(int holds, const char *what)
{
    if (!holds) {
        printf("FAIL  %s\n", what);
        fails++;
    }
}

struct api {
    void (*lock)(lock_t *);
    bool (*trylock)(lock_t *);
    void (*unlock)(lock_t *);
};

static struct api ours = { os_unfair_lock_lock, os_unfair_lock_trylock, os_unfair_lock_unlock };
static struct api darwins;
static const struct api *using;
static lock_t shared;
static long counter;
static _Atomic int holding;
static _Atomic(uint32_t) seen;

static void *hold(void *unused)
{
    (void)unused;
    using->lock(&shared);
    atomic_store(&holding, 1);
    usleep(200000);
    atomic_store(&seen, shared.value);
    using->unlock(&shared);
    return NULL;
}

static void *contend(void *unused)
{
    (void)unused;
    using->lock(&shared);
    using->unlock(&shared);
    return NULL;
}

static void *count(void *unused)
{
    (void)unused;
    for (int round = 0; round < 20000; round++) {
        using->lock(&shared);
        counter++;
        using->unlock(&shared);
    }
    return NULL;
}

static void *try_other(void *unused)
{
    (void)unused;
    return (void *)(intptr_t)using->trylock(&shared);
}

static int dies(void (*body)(void))
{
    fflush(stdout);
    pid_t child = fork();
    if (child == 0) {
        freopen("/dev/null", "w", stderr);
        alarm(10);
        body();
        _exit(0);
    }
    int status = 0;
    waitpid(child, &status, 0);
    return WIFSIGNALED(status) && WTERMSIG(status) != SIGALRM;
}

static void relock(void) { lock_t lock = {0}; using->lock(&lock); using->lock(&lock); }
static void unlock_unlocked(void) { lock_t lock = {0}; using->unlock(&lock); }
static void *take(void *lock) { using->lock(lock); return NULL; }
static void unlock_foreign(void) { lock_t lock = {0}; pthread_t thread; pthread_create(&thread, NULL, take, &lock); pthread_join(thread, NULL); using->unlock(&lock); }

static void behaves(const struct api *api, const char *name)
{
    char what[256];
    using = api;
    uint32_t self = pthread_mach_thread_np(pthread_self()) | 1;
    snprintf(what, sizeof what, "%s: this kernel hands out odd thread port names, so the shim's word is Darwin's own", name);
    expect(self == pthread_mach_thread_np(pthread_self()), what);
    shared.value = 0;
    api->lock(&shared);
    snprintf(what, sizeof what, "%s: a held lock records the owner's Mach thread port name with the no-waiters bit", name);
    expect(shared.value == self, what);
    snprintf(what, sizeof what, "%s: trylock of a lock this thread holds fails", name);
    expect(!api->trylock(&shared), what);
    pthread_t thread;
    pthread_create(&thread, NULL, try_other, NULL);
    void *got;
    pthread_join(thread, &got);
    snprintf(what, sizeof what, "%s: trylock of a lock another thread holds fails", name);
    expect(got == NULL, what);
    api->unlock(&shared);
    snprintf(what, sizeof what, "%s: unlock leaves the lock free", name);
    expect(shared.value == 0, what);
    pthread_create(&thread, NULL, try_other, NULL);
    pthread_join(thread, &got);
    snprintf(what, sizeof what, "%s: trylock of a free lock takes it", name);
    expect(got != NULL && shared.value != 0, what);
    shared.value = 0;

    atomic_store(&holding, 0);
    pthread_t holder, waiter;
    pthread_create(&holder, NULL, hold, NULL);
    while (!atomic_load(&holding))
        usleep(1000);
    pthread_create(&waiter, NULL, contend, NULL);
    pthread_join(holder, NULL);
    pthread_join(waiter, NULL);
    snprintf(what, sizeof what, "%s: a waiter clears the low bit of the owner's word, so the unlock wakes it", name);
    expect((atomic_load(&seen) & 1) == 0 && atomic_load(&seen) != 0, what);
    snprintf(what, sizeof what, "%s: the waiter gets the lock and releases it", name);
    expect(shared.value == 0, what);

    counter = 0;
    pthread_t threads[8];
    for (int index = 0; index < 8; index++)
        pthread_create(&threads[index], NULL, count, NULL);
    for (int index = 0; index < 8; index++)
        pthread_join(threads[index], NULL);
    snprintf(what, sizeof what, "%s: eight threads contending lose no update", name);
    expect(counter == 8 * 20000, what);

    snprintf(what, sizeof what, "%s: locking a lock this thread holds crashes", name);
    expect(dies(relock), what);
    snprintf(what, sizeof what, "%s: unlocking a free lock crashes", name);
    expect(dies(unlock_unlocked), what);
    snprintf(what, sizeof what, "%s: unlocking another thread's lock crashes", name);
    expect(dies(unlock_foreign), what);
}

typedef void (*recursive_lock_f)(recursive_t *, uint32_t);
typedef void (*recursive_unlock_f)(recursive_t *);

static void recursive(recursive_lock_f lock, recursive_unlock_f unlock, const char *name)
{
    char what[256];
    recursive_t held = {{0}, 0};
    uint32_t self = pthread_mach_thread_np(pthread_self()) | 1;
    lock(&held, 0);
    lock(&held, 0);
    lock(&held, 0);
    snprintf(what, sizeof what, "%s: a recursive lock taken three times holds the owner and a count of two", name);
    expect(held.lock.value == self && held.count == 2, what);
    unlock(&held);
    unlock(&held);
    snprintf(what, sizeof what, "%s: two unlocks leave it held once", name);
    expect(held.lock.value == self && held.count == 0, what);
    unlock(&held);
    snprintf(what, sizeof what, "%s: the last unlock frees it", name);
    expect(held.lock.value == 0, what);
}

int main(void)
{
    void *platform = dlopen("/usr/lib/system/libsystem_platform.dylib", RTLD_LAZY | RTLD_NOLOAD);
    darwins.lock = platform ? dlsym(platform, "os_unfair_lock_lock") : NULL;
    darwins.trylock = platform ? dlsym(platform, "os_unfair_lock_trylock") : NULL;
    darwins.unlock = platform ? dlsym(platform, "os_unfair_lock_unlock") : NULL;
    expect(darwins.lock && darwins.lock != ours.lock, "the test reaches Darwin's os_unfair_lock_lock beside the shim");
    behaves(&darwins, "Darwin");
    behaves(&ours, "the shim");
    recursive_lock_f darwin_lock = platform ? dlsym(platform, "os_unfair_recursive_lock_lock_with_options") : NULL;
    recursive_unlock_f darwin_unlock = platform ? dlsym(platform, "os_unfair_recursive_lock_unlock") : NULL;
    if (darwin_lock && darwin_unlock)
        recursive(darwin_lock, darwin_unlock, "Darwin");
    recursive(os_unfair_recursive_lock_lock_with_options, os_unfair_recursive_lock_unlock, "the shim");
    return fails != 0;
}
