#include "scenarios.h"
#include "workers.c"

static uint64_t run(int worker, uint64_t a, uint64_t b, uint64_t c, uint64_t d)
{
    switch (worker) {
    case PAIR_ADD:
        return pair_add((u128 *)a, b);
    case PAIR_CAS:
        return pair_cas((u128 *)a, b);
    case PAIR_SWAP:
        return pair_swap((u128 *)a, b, (u128 *)c, d);
    case PAIR_STORE:
        return pair_store((u128 *)a, b, c);
    case PAIR_TORN:
        return pair_torn((u128 *)a, b);
    case PAIR32_ADD:
        return pair32_add((uint32_t *)a, b);
    default:
        return pair_bare((u128 *)a);
    }
}

int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    int asked = mode(argc, argv);
    if (asked >= 0)
        return asked;
    scenarios();
    printf("done\n");
    return failures != 0;
}
