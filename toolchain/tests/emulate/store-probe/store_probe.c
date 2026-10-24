#include <pthread.h>
#include <stdint.h>
#include <stdio.h>

#define ROUNDS 2000

static volatile uint32_t word;
static volatile uint32_t round_go;
static volatile uint32_t round_done;

static void *writer(void *argument)
{
    (void)argument;
    uint32_t seen = 0;
    while (seen < ROUNDS) {
        while (round_go == seen) {
        }
        seen = round_go;
        word = word;
        round_done = seen;
    }
    return NULL;
}

int main(void)
{
    pthread_t thread;
    if (pthread_create(&thread, NULL, writer, NULL) != 0) {
        printf("store_probe could not start the writer\n");
        return 2;
    }
    uint32_t leaked = 0;
    for (uint32_t round = 1; round <= ROUNDS; round++) {
        uint32_t value;
        uint32_t status;
        __asm__ volatile("ldrex %0, [%1]"
                         : "=&r"(value)
                         : "r"(&word)
                         : "memory");
        round_go = round;
        while (round_done != round) {
        }
        __asm__ volatile("strex %0, %2, [%1]"
                         : "=&r"(status)
                         : "r"(&word), "r"(value + 1)
                         : "memory");
        if (status == 0)
            leaked++;
    }
    round_go = ROUNDS + 1;
    pthread_join(thread, NULL);
    if (leaked != 0) {
        printf("store_probe %u of %u stores succeeded after another processor stored to the word\n", leaked, ROUNDS);
        return 1;
    }
    printf("store_probe ok %u rounds\n", ROUNDS);
    return 0;
}
