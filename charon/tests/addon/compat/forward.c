
#include <dlfcn.h>
#include <pthread.h>
#include <signal.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

typedef struct { uint32_t value; } lock_t;
void os_unfair_lock_lock(lock_t *);
void os_unfair_lock_unlock(lock_t *);

static void (*darwin_lock)(lock_t *);
static void (*darwin_unlock)(lock_t *);
static lock_t shared;
static _Atomic int done;

static void stalled(int signal)
{
    (void)signal;
    printf("FAIL  the exported copy reaches the system's os_unfair_lock by opening libsystem_platform, not by a search that finds the copy itself\n");
    fflush(stdout);
    _exit(1);
}

static void *wait_in_darwin(void *unused)
{
    (void)unused;
    darwin_lock(&shared);
    darwin_unlock(&shared);
    atomic_store(&done, 1);
    return NULL;
}

int main(void)
{
    int fails = 0;
    signal(SIGALRM, stalled);
    alarm(20);
    void *platform = dlopen("/usr/lib/system/libsystem_platform.dylib", RTLD_LAZY | RTLD_NOLOAD);
    darwin_lock = platform ? dlsym(platform, "os_unfair_lock_lock") : NULL;
    darwin_unlock = platform ? dlsym(platform, "os_unfair_lock_unlock") : NULL;
    Dl_info first;
    void *found = dlsym(RTLD_DEFAULT, "os_unfair_lock_lock");
    if (!darwin_lock || !found || found == darwin_lock || !dladdr(found, &first) || !strstr(first.dli_fname, "libshared")) {
        printf("FAIL  the test must reproduce the trap: a search of every image finds the exported copy before the system's\n");
        fails++;
    }
    os_unfair_lock_lock(&shared);
    pthread_t waiter;
    pthread_create(&waiter, NULL, wait_in_darwin, NULL);
    usleep(200000);
    os_unfair_lock_unlock(&shared);
    for (int tick = 0; tick < 500 && !atomic_load(&done); tick++)
        usleep(10000);
    if (!atomic_load(&done)) {
        printf("FAIL  where the system has os_unfair_lock, the exported copy is the system's, so a waiter in the system's lock hears its unlock\n");
        fails++;
    }
    return fails != 0;
}
