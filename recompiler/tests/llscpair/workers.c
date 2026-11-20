#include "workers.h"

#define WORKER __attribute__((noinline, used))

WORKER uint64_t pair_add(u128 *cell, uint64_t times)
{
    while (times--)
        __atomic_fetch_add(cell, PAIR_STEP, __ATOMIC_SEQ_CST);
    return 0;
}

WORKER uint64_t pair_cas(u128 *cell, uint64_t times)
{
    while (times--) {
        u128 seen = __atomic_load_n(cell, __ATOMIC_RELAXED);
        while (!__atomic_compare_exchange_n(cell, &seen, seen + PAIR_STEP, 0, __ATOMIC_ACQ_REL, __ATOMIC_RELAXED)) {
        }
    }
    return 0;
}

WORKER uint64_t pair_swap(u128 *cells, uint64_t mask, u128 *mine, uint64_t times)
{
    u128 held = *mine;
    uint64_t at = (uint64_t)held;
    while (times--) {
        at = at * 5 + 1;
        held = __atomic_exchange_n(&cells[at >> 3 & mask], held, __ATOMIC_SEQ_CST);
    }
    *mine = held;
    return 0;
}

WORKER uint64_t pair_store(u128 *cell, uint64_t seed, uint64_t times)
{
    while (times--) {
        seed = seed * 6364136223846793005ull + 1442695040888963407ull;
        __atomic_store_n(cell, ((u128)~seed << 64) | seed, __ATOMIC_SEQ_CST);
    }
    return 0;
}

WORKER uint64_t pair_torn(u128 *cell, uint64_t times)
{
    uint64_t wrong = 0;
    while (times--) {
        u128 seen = __atomic_load_n(cell, __ATOMIC_SEQ_CST);
        wrong += (uint64_t)(seen >> 64) != ~(uint64_t)seen;
    }
    return wrong;
}

__attribute__((naked, noinline, used)) uint64_t pair32_add(uint32_t *cell, uint64_t times)
{
    __asm__("1:\n"
            "ldxp w2, w3, [x0]\n"
            "add w2, w2, #1\n"
            "add w3, w3, #1\n"
            "stxp w4, w2, w3, [x0]\n"
            "cbnz w4, 1b\n"
            "subs x1, x1, #1\n"
            "b.ne 1b\n"
            "mov x0, #0\n"
            "ret\n");
}

__attribute__((naked, noinline, used)) uint64_t pair_bare(u128 *cell)
{
    __asm__("clrex\n"
            "mov x2, #0\n"
            "stxp w3, x2, x2, [x0]\n"
            "mov w0, w3\n"
            "ret\n");
}

__attribute__((naked, noinline, used)) uint64_t pair_elsewhere(u128 *cell, u128 *other)
{
    __asm__("ldxp x2, x3, [x0]\n"
            "mov x2, #0\n"
            "stxp w4, x2, x2, [x1]\n"
            "mov w0, w4\n"
            "ret\n");
}

__attribute__((naked, noinline, used)) uint64_t pair_after_single(u128 *cell)
{
    __asm__("ldxr x2, [x0]\n"
            "mov x2, #0\n"
            "stxp w4, x2, x2, [x0]\n"
            "mov w0, w4\n"
            "ret\n");
}

__attribute__((naked, noinline, used)) uint64_t single_after_pair(u128 *cell)
{
    __asm__("ldxp x2, x3, [x0]\n"
            "mov x2, #0\n"
            "stxr w4, x2, [x0]\n"
            "mov w0, w4\n"
            "ret\n");
}

__attribute__((naked, noinline, used)) uint64_t pair_twice(u128 *cell)
{
    __asm__("ldxp x2, x3, [x0]\n"
            "stxp w4, x3, x2, [x0]\n"
            "stxp w5, x2, x3, [x0]\n"
            "orr w0, w4, w5, lsl #1\n"
            "ret\n");
}

#ifdef WORKERS_ALONE
int main(void)
{
    static _Alignas(16) u128 cell;
    pair_add(&cell, 1);
    return (int)cell;
}
#endif
