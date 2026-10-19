#include "xl_state.h"

#include <stdint.h>

typedef struct State State;
typedef void (*xl_lifted)(State *);

struct xl_function {
    uint32_t address;
    xl_lifted function;
};

extern const struct xl_function xl_functions[];
extern const uint32_t xl_function_count;

#define XL_REG(state, name) (*(uint64_t *)((char *)(state) + XL_OFFSET_##name))

__attribute__((noinline)) void xl_trap(void)
{
    for (;;) {
    }
}

xl_lifted xl_lookup(uint64_t address)
{
    uint32_t low = 0, high = xl_function_count;
    while (low < high) {
        uint32_t middle = low + (high - low) / 2;
        if (xl_functions[middle].address < address)
            low = middle + 1;
        else
            high = middle;
    }
    if (low < xl_function_count && xl_functions[low].address == address)
        return xl_functions[low].function;
    return 0;
}

void xl_call(State *state)
{
    xl_lifted function = xl_lookup(XL_REG(state, PC));
    if (!function)
        xl_trap();
    function(state);
}

void xl_tail(State *state)
{
    xl_lifted function = xl_lookup(XL_REG(state, PC));
    if (!function)
        xl_trap();
    [[clang::musttail]] return function(state);
}

uint64_t xlate_run(uint32_t address, uint8_t *arena, uint32_t size, State *state, uint32_t stack_top)
{
    XL_REG(state, X0) = (uintptr_t)arena;
    XL_REG(state, X1) = size;
    XL_REG(state, SP) = stack_top & ~15u;
    XL_REG(state, X30) = 0;
    XL_REG(state, PC) = address;
    xl_lifted function = xl_lookup(address);
    if (!function)
        xl_trap();
    function(state);
    return XL_REG(state, X0);
}

double trunc(double value)
{
    uint64_t bits;
    __builtin_memcpy(&bits, &value, sizeof bits);
    int exponent = (int)((bits >> 52) & 0x7ff) - 1023;
    if (exponent >= 52)
        return value;
    if (exponent < 0)
        bits &= 1ull << 63;
    else
        bits &= ~((1ull << (52 - exponent)) - 1);
    __builtin_memcpy(&value, &bits, sizeof bits);
    return value;
}
