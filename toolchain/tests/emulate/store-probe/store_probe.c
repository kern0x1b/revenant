#include <pthread.h>
#include <stdint.h>
#include <stdio.h>

#define ROUNDS 2000
#define SPIN 200000

static volatile uint32_t word __attribute__((aligned(4096)));
static volatile uint32_t flags[1024] __attribute__((aligned(4096)));

#define round_go flags[0]
#define round_done flags[64]

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
    uint32_t alone = 0;
    for (uint32_t round = 1; round <= ROUNDS; round++) {
        uint32_t value;
        uint32_t status;
        __asm__ volatile("ldrex %0, [%1]"
                         : "=&r"(value)
                         : "r"(&word)
                         : "memory");
        __asm__ volatile("strex %0, %2, [%1]"
                         : "=&r"(status)
                         : "r"(&word), "r"(value + 1)
                         : "memory");
        if (status == 0)
            alone++;
    }
    pthread_t thread;
    if (pthread_create(&thread, NULL, writer, NULL) != 0) {
        printf("store_probe could not start the writer\n");
        return 2;
    }
    uint32_t responded = 0;
    uint32_t succeeded = 0;
    uint32_t leaked = 0;
    for (uint32_t round = 1; round <= ROUNDS; round++) {
        uint32_t value;
        uint32_t status;
        __asm__ volatile("ldrex %0, [%1]"
                         : "=&r"(value)
                         : "r"(&word)
                         : "memory");
        round_go = round;
        for (uint32_t spin = 0; spin < SPIN && round_done != round; spin++) {
        }
        const uint32_t observed = round_done == round;
        __asm__ volatile("strex %0, %2, [%1]"
                         : "=&r"(status)
                         : "r"(&word), "r"(value + 1)
                         : "memory");
        if (observed)
            responded++;
        if (status == 0) {
            succeeded++;
            if (observed)
                leaked++;
        }
    }
    round_go = ROUNDS + 1;
    pthread_join(thread, NULL);
    printf("store_probe alone %u of %u succeeded\n", alone, ROUNDS);
    printf("store_probe rounds %u responded %u succeeded %u leaked %u\n", ROUNDS, responded, succeeded, leaked);
    return leaked == 0 ? 0 : 1;
}
