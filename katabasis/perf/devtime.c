// devtime.c -- on-device wall-clock benchmark: translated (armv7-lifted-from-arm64)
// vs native armv7 for each compute kernel, plus resident-memory reporting.
// Runs as a normal iOS CLI process (has libSystem), unlike the -nostdlib emulator harness.
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <mach/mach.h>
#include <mach/mach_time.h>

#include "xl_state.h"
#include "kernel_addrs.h"   // generated: kernel_count, kernel_names[], kernel_addrs[]

typedef struct State State;
typedef void (*xl_lifted)(State *);
struct xl_function { uint32_t address; xl_lifted function; };
extern const struct xl_function xl_functions[];
extern const uint32_t xl_function_count;
#define XL_REG(state, name) (*(uint64_t *)((char *)(state) + XL_OFFSET_##name))

static xl_lifted xl_lookup(uint64_t address)
{
    uint32_t low = 0, high = xl_function_count;
    while (low < high) {
        uint32_t mid = low + (high - low) / 2;
        if (xl_functions[mid].address < address) low = mid + 1; else high = mid;
    }
    if (low < xl_function_count && xl_functions[low].address == address) return xl_functions[low].function;
    return 0;
}
void xl_call(State *state) { xl_lifted f = xl_lookup(XL_REG(state, PC)); if (f) f(state); }
void xl_tail(State *state) { xl_lifted f = xl_lookup(XL_REG(state, PC)); if (f) [[clang::musttail]] return f(state); }

uint64_t xlate_run(uint32_t address, uint8_t *arena, uint32_t size, State *state, uint32_t stack_top)
{
    XL_REG(state, X0) = (uintptr_t)arena;
    XL_REG(state, X1) = size;
    XL_REG(state, SP) = stack_top & ~15u;
    XL_REG(state, X30) = 0;
    XL_REG(state, PC) = address;
    xl_lifted f = xl_lookup(address);
    if (!f) return 0;
    f(state);
    return XL_REG(state, X0);
}

uint64_t native_run(unsigned which, uint8_t *arena, uint32_t size);

#define ARENA (8u * 1024u * 1024u)
#define STACK (2u * 1024u * 1024u)

// Per-kernel work size, matching the emulator harness (count.py). For the hash/text
// kernels this is a byte count; for sort/list/geometry it is an element count (the
// lifted arm64 code uses 8-byte longs, native armv7 uses 4-byte, so the arena is sized
// generously); for matrix it is the dimension.
static const uint32_t kernel_size[] = { 1u<<16, 1u<<16, 1u<<16, 20000, 20000, 20000, 60, 1u<<16 };

static void fill(uint8_t *arena, uint32_t size)
{
    uint32_t x = 0x12345678u;
    for (uint32_t i = 0; i < size; i++) {
        x = x * 1664525u + 1013904223u;
        arena[i] = (uint8_t)(x >> 24);
    }
}

static double ns_per(uint64_t ticks, uint64_t iters, mach_timebase_info_data_t tb)
{
    long double ns = (long double)ticks * tb.numer / tb.denom;
    return (double)(ns / (long double)iters);
}

static uint64_t rss_bytes(void)
{
    mach_task_basic_info_data_t info;
    mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
    if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&info, &count) == KERN_SUCCESS)
        return info.resident_size;
    return 0;
}

int main(void)
{
    setbuf(stdout, NULL);
    mach_timebase_info_data_t tb;
    mach_timebase_info(&tb);

    // RSS-overhead mode: a small arena (no 16 MB test scaffolding) and a single pass,
    // so the reported resident size reflects the translation machinery (binary + lifted
    // code touched + State + stack) rather than the benchmark's own data.
    int rss_mode = getenv("XL_RSS") != NULL;
    uint32_t arena_bytes = rss_mode ? (2u * 1024u * 1024u) : ARENA;  // 2 MB: fits all kernels (list 20000*16=320KB), far below the 16 MB perf scaffolding
    uint64_t base_iters = rss_mode ? 1 : 200;

    uint64_t rss_baseline = rss_bytes();
    uint8_t *arena = malloc(arena_bytes);
    uint8_t *seed = malloc(arena_bytes);
    fill(seed, arena_bytes);

    uint8_t *stack = malloc(STACK);
    State *state = calloc(1, 4096);      // >= V31 offset + slack
    uint32_t stack_top = (uint32_t)(uintptr_t)stack + STACK;

    printf("kernel        native_ns   xlate_ns   xl/native   match\n");
    double geo = 1.0; int n = 0;
    for (unsigned k = 0; k < kernel_count; k++) {
        uint32_t sz = kernel_size[k];
        uint64_t iters = base_iters;

        // Correctness: one run each from an identical arena.
        memcpy(arena, seed, arena_bytes);
        uint64_t rn = native_run(k, arena, sz);
        memcpy(arena, seed, arena_bytes);
        uint64_t rx = xlate_run(kernel_addrs[k], arena, sz, state, stack_top);
        int match = (rn == rx);

        // Native timing.
        memcpy(arena, seed, arena_bytes);
        uint64_t t0 = mach_absolute_time();
        for (uint64_t i = 0; i < iters; i++) native_run(k, arena, sz);
        uint64_t tn = mach_absolute_time() - t0;

        // Translated timing.
        memcpy(arena, seed, arena_bytes);
        t0 = mach_absolute_time();
        for (uint64_t i = 0; i < iters; i++) xlate_run(kernel_addrs[k], arena, sz, state, stack_top);
        uint64_t tx = mach_absolute_time() - t0;

        double nn = ns_per(tn, iters, tb), nx = ns_per(tx, iters, tb);
        double ratio = nn > 0 ? nx / nn : 0;
        printf("%-12s %10.0f %10.0f %8.2fx    %s\n",
               kernel_names[k], nn, nx, ratio, match ? "ok" : "MISMATCH");
        if (ratio > 0) { geo *= ratio; n++; }
    }
    if (n) printf("geomean xl/native = %.2fx over %d kernels\n", pow(geo, 1.0 / n), n);
    uint64_t rss_final = rss_bytes();
    printf("rss: baseline=%llu final=%llu arena=%u stack=%u  (all bytes)\n",
           (unsigned long long)rss_baseline, (unsigned long long)rss_final, arena_bytes * 2u, STACK);
    printf("rss_final = %.2f MB\n", rss_final / (1024.0 * 1024.0));
    return 0;
}
