
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <sys/time.h>
#include <signal.h>
#include <unistd.h>

typedef struct { uint32_t value; } lock_t;
void one_lock(lock_t *);
void one_unlock(lock_t *);
void two_lock(lock_t *);
void two_unlock(lock_t *);

static lock_t shared;

static void stalled(int signal)
{
    (void)signal;
    printf("FAIL  two images that bind the lock to one copy wake each other; a waiter slept past every unlock for 30 s\n");
    fflush(stdout);
    _exit(1);
}
static long counter;

static void *through_one(void *unused)
{
    (void)unused;
    for (int round = 0; round < 3000; round++) {
        one_lock(&shared);
        counter++;
        if (round % 500 == 0)
            usleep(2000);
        one_unlock(&shared);
    }
    return NULL;
}

static void *through_two(void *unused)
{
    (void)unused;
    for (int round = 0; round < 3000; round++) {
        two_lock(&shared);
        counter++;
        if (round % 500 == 0)
            usleep(2000);
        two_unlock(&shared);
    }
    return NULL;
}

int main(void)
{
    signal(SIGALRM, stalled);
    alarm(30);
    struct timeval start, end;
    gettimeofday(&start, NULL);
    pthread_t threads[8];
    for (int index = 0; index < 8; index++)
        pthread_create(&threads[index], NULL, index % 2 ? through_two : through_one, NULL);
    for (int index = 0; index < 8; index++)
        pthread_join(threads[index], NULL);
    gettimeofday(&end, NULL);
    double seconds = (end.tv_sec - start.tv_sec) + (end.tv_usec - start.tv_usec) / 1e6;
    int fails = 0;
    if (counter != 8 * 3000) {
        printf("FAIL  a lock two images take, each with its own copy of the shim, loses no update\n");
        fails++;
    }
    (void)seconds;
    return fails;
}
