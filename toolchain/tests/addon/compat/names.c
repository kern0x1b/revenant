#include <mach/mach.h>
#include <pthread.h>
#include <signal.h>
#include <stdatomic.h>
#include <stdio.h>
#include <unistd.h>

#include "unfair_lock.h"

static int fails;

static void expect(int holds, const char *what)
{
    if (!holds) {
        printf("FAIL  %s\n", what);
        fails++;
    }
}

static revenant_unfair_lock shared;
static uint32_t owners[2];
static _Atomic int held;
static _Atomic(uint32_t) seen;
static _Atomic long counter;

static void *hold(void *which)
{
    uint32_t self = revenant_unfair_owner(owners[(intptr_t)which]);
    revenant_unfair_lock_lock(&shared, self);
    atomic_store(&held, 1);
    usleep(150000);
    atomic_store(&seen, atomic_load(&shared.value));
    revenant_unfair_unlock(&shared, self);
    return NULL;
}

static void *wait_for_it(void *which)
{
    uint32_t self = revenant_unfair_owner(owners[(intptr_t)which]);
    for (int round = 0; round < 200; round++) {
        revenant_unfair_lock_lock(&shared, self);
        atomic_fetch_add(&counter, 1);
        revenant_unfair_unlock(&shared, self);
    }
    return NULL;
}

static void names(uint32_t first, uint32_t second, const char *what)
{
    char said[160];
    owners[0] = first;
    owners[1] = second;
    atomic_store(&shared.value, 0);
    atomic_store(&held, 0);
    atomic_store(&counter, 0);
    pthread_t holder, waiter;
    pthread_create(&holder, NULL, hold, (void *)0);
    while (!atomic_load(&held))
        usleep(1000);
    pthread_create(&waiter, NULL, wait_for_it, (void *)1);
    pthread_join(holder, NULL);
    pthread_join(waiter, NULL);
    snprintf(said, sizeof said, "a lock whose owners have %s port names hands over to a waiter", what);
    expect(atomic_load(&counter) == 200 && atomic_load(&shared.value) == 0, said);
    snprintf(said, sizeof said, "a waiter on %s port names clears the low bit of the owner's word", what);
    expect((atomic_load(&seen) & REVENANT_UNFAIR_NO_WAITERS) == 0 && atomic_load(&seen) != 0, said);
}

static void stalled(int signal)
{
    (void)signal;
    printf("FAIL  a lock whose owners have the port names one of these kernels gives hands over to a waiter; one slept for 30 s\n");
    fflush(stdout);
    _exit(1);
}

int main(void)
{
    signal(SIGALRM, stalled);
    alarm(30);
    names(0x1e03, 0x1e17, "the odd");
    names(0x10c00, 0x11e00, "the even");
    uint32_t self = revenant_unfair_self();
    expect((self & REVENANT_UNFAIR_NO_WAITERS) != 0 && (self | REVENANT_UNFAIR_NO_WAITERS) == self,
           "the owner a thread records always carries the no-waiters bit, whichever name the kernel gave it");
    expect(self == (pthread_mach_thread_np(pthread_self()) | REVENANT_UNFAIR_NO_WAITERS),
           "the owner is this thread's Mach port name with that bit set");
    return fails != 0;
}
