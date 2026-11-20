#pragma once

#include <stdint.h>

typedef unsigned __int128 u128;

enum { PAIR_ADD, PAIR_CAS, PAIR_SWAP, PAIR_STORE, PAIR_TORN, PAIR32_ADD, PAIR_BARE };

#define PAIR_STEP ((((u128)1) << 64) | 1)

static uint64_t run(int worker, uint64_t a, uint64_t b, uint64_t c, uint64_t d);
