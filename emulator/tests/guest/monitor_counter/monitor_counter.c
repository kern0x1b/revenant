#include <pthread.h>
#include <stdint.h>
#include <stdio.h>

#define THREADS 2
#define ROUNDS 200000

static volatile uint32_t counter;

static void *increment(void *argument)
{
    (void)argument;
    for (int round = 0; round < ROUNDS; round++)
        __sync_fetch_and_add(&counter, 1);
    return NULL;
}

int main(void)
{
    pthread_t threads[THREADS];
    for (int index = 0; index < THREADS; index++) {
        if (pthread_create(&threads[index], NULL, increment, NULL) != 0) {
            printf("monitor_counter could not start thread %d\n", index);
            return 2;
        }
    }
    for (int index = 0; index < THREADS; index++)
        pthread_join(threads[index], NULL);
    const uint32_t expected = THREADS * ROUNDS;
    if (counter != expected) {
        printf("monitor_counter lost %u of %u updates\n", expected - counter, expected);
        return 1;
    }
    printf("monitor_counter ok %u updates\n", expected);
    return 0;
}
