#include <stdint.h>
#include <stdio.h>

static uint32_t special_guard(uint32_t value)
{
    uint32_t result;
    __asm__ volatile(
        "movs r2, #2\n"
        "movt r2, #1\n"
        "it ne\n"
        "cmpne %1, r2\n"
        "beq 1f\n"
        "movs %0, #0\n"
        "b 2f\n"
        "1:\n"
        "movs %0, #1\n"
        "2:\n"
        : "=&r"(result)
        : "r"(value)
        : "r2", "cc");
    return result;
}

static uint32_t decrement_pair(volatile uint32_t *address)
{
    uint32_t value;
    uint32_t status;
    uint32_t old;
    do {
        __asm__ volatile(
            "ldrex %0, [%3]\n"
            "subs %1, %0, #2\n"
            "strex %2, %1, [%3]\n"
            : "=&r"(old), "=&r"(value), "=&r"(status)
            : "r"(address)
            : "cc", "memory");
    } while (status != 0);
    return old;
}

int main(void)
{
    int failures = 0;
    const uint32_t cases[][2] = {
        {0x10002U, 1U},
        {0x10003U, 0U},
        {0x2U, 0U},
        {0x0U, 0U},
    };
    for (unsigned index = 0; index < sizeof cases / sizeof cases[0]; index++) {
        uint32_t got = special_guard(cases[index][0]);
        if (got != cases[index][1]) {
            printf("it_probe guard %#x gave %u, expected %u\n", cases[index][0], got, cases[index][1]);
            failures++;
        }
    }
    volatile uint32_t word = 6U;
    uint32_t observed = decrement_pair(&word);
    if (observed != 6U || word != 4U) {
        printf("it_probe ldrex/strex observed %u, stored %u, expected 6 and 4\n", observed, word);
        failures++;
    }
    if (failures == 0) {
        printf("it_probe ok\n");
    }
    return failures == 0 ? 0 : 1;
}
