#include <dlfcn.h>
#include <pthread.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <sys/wait.h>
#include <unistd.h>

typedef struct { uint32_t word; } lock_t;
void os_unfair_lock_lock(lock_t *);
void os_unfair_lock_unlock(lock_t *);
void os_unfair_lock_assert_owner(const lock_t *);
void os_unfair_lock_assert_not_owner(const lock_t *);

static int fails;
static lock_t held_elsewhere;
static lock_t gate;

static void expect(int holds, const char *what)
{
    if (!holds) {
        printf("FAIL  %s\n", what);
        fails++;
    }
}

static int dies(void (*call)(const lock_t *), lock_t *lock, int take)
{
    fflush(stdout);
    pid_t child = fork();
    if (child == 0) {
        freopen("/dev/null", "w", stderr);
        if (take)
            os_unfair_lock_lock(lock);
        call(lock);
        _exit(0);
    }
    int status = 0;
    waitpid(child, &status, 0);
    return WIFSIGNALED(status);
}

static void *other(void *unused)
{
    os_unfair_lock_lock(&held_elsewhere);
    os_unfair_lock_lock(&gate);
    os_unfair_lock_unlock(&gate);
    os_unfair_lock_unlock(&held_elsewhere);
    return NULL;
}

int main(void)
{
    void *platform = dlopen("/usr/lib/system/libsystem_platform.dylib", RTLD_LAZY | RTLD_LOCAL);
    void (*darwin_owner)(const lock_t *) = platform ? dlsym(platform, "os_unfair_lock_assert_owner") : NULL;
    void (*darwin_not_owner)(const lock_t *) = platform ? dlsym(platform, "os_unfair_lock_assert_not_owner") : NULL;
    expect(darwin_owner && (void *)darwin_owner != (void *)os_unfair_lock_assert_owner, "the test reaches Darwin's assert beside the shim");
    lock_t mine = {0};
    struct { const char *name; void (*owner)(const lock_t *); void (*not_owner)(const lock_t *); } sides[] = {
        {"the shim", os_unfair_lock_assert_owner, os_unfair_lock_assert_not_owner},
        {"Darwin", darwin_owner, darwin_not_owner}};
    for (int side = 0; side < 2; side++) {
        char what[160];
        sides[side].not_owner(&mine);
        snprintf(what, sizeof what, "%s: an unlocked lock is not owned by this thread", sides[side].name);
        expect(!dies(sides[side].not_owner, &mine, 0), what);
        snprintf(what, sizeof what, "%s: assert_owner ends the process on an unlocked lock", sides[side].name);
        expect(dies(sides[side].owner, &mine, 0), what);
        snprintf(what, sizeof what, "%s: a lock this thread holds is owned by it", sides[side].name);
        expect(!dies(sides[side].owner, &mine, 1), what);
        snprintf(what, sizeof what, "%s: assert_not_owner ends the process on a lock this thread holds", sides[side].name);
        expect(dies(sides[side].not_owner, &mine, 1), what);
        os_unfair_lock_lock(&mine);
        sides[side].owner(&mine);
        os_unfair_lock_unlock(&mine);
    }
    os_unfair_lock_lock(&gate);
    pthread_t thread;
    pthread_create(&thread, NULL, other, NULL);
    while (__atomic_load_n(&held_elsewhere.word, __ATOMIC_ACQUIRE) == 0)
        usleep(1000);
    for (int side = 0; side < 2; side++) {
        char what[160];
        snprintf(what, sizeof what, "%s: a lock another thread holds is not this thread's", sides[side].name);
        expect(!dies(sides[side].not_owner, &held_elsewhere, 0), what);
        snprintf(what, sizeof what, "%s: assert_owner ends the process on a lock another thread holds", sides[side].name);
        expect(dies(sides[side].owner, &held_elsewhere, 0), what);
    }
    os_unfair_lock_unlock(&gate);
    pthread_join(thread, NULL);
    return fails != 0;
}
