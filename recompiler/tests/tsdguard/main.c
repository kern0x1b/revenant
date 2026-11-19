#include "../../src/runtime/xl_tsd_guard.h"

#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>

#define TIMEOUT_SECONDS 5

static void alarm_die(int sig)
{
    (void)sig;
    _exit(99);
}

static void child_read(uintptr_t addr)
{
    signal(SIGALRM, alarm_die);
    alarm(TIMEOUT_SECONDS);
    volatile uint64_t v = *(volatile uint64_t *)addr;
    (void)v;
    _exit(0);
}

static int try_read(uintptr_t addr)
{
    pid_t pid = fork();
    if (pid < 0) {
        perror("fork");
        exit(1);
    }
    if (pid == 0) {
        child_read(addr);
    }
    for (int waited = 0; waited < TIMEOUT_SECONDS * 20; waited++) {
        int status;
        pid_t r = waitpid(pid, &status, WNOHANG);
        if (r == pid) {
            if (WIFEXITED(status)) {
                return WEXITSTATUS(status) == 99 ? 2 : 0;
            }
            if (WIFSIGNALED(status)) {
                return 1;
            }
            return 4;
        }
        usleep(50000);
    }
    kill(pid, SIGKILL);
    waitpid(pid, NULL, 0);
    return 3;
}

static const char *Describe(int r)
{
    switch (r) {
        case 0: return "clean read";
        case 1: return "faulted";
        case 2: return "child's own alarm fired (unexpected for a plain read)";
        case 3: return "parent's wait timed out, child killed";
        default: return "unclassifiable wait status";
    }
}

static void *limited_mapper(size_t length)
{
    if (length > (1u << 20)) {
        errno = ENOMEM;
        return MAP_FAILED;
    }
    return xl_map_anonymous(length);
}

static void *refusing_mapper(size_t length)
{
    (void)length;
    errno = ENOMEM;
    return MAP_FAILED;
}

int main(void)
{
    void *pages = xl_tsd_alloc();
    uintptr_t base = xl_tsd_base(pages);
    int fail = 0;

    struct { uintptr_t offset; int want_fault; } cases[] = {
        {0, 1},
        {8, 1},
        {XL_TSD_AUDITED_OFFSET - 8, 1},
        {XL_TSD_AUDITED_OFFSET, 0},
        {XL_TSD_AUDITED_OFFSET + 8, 0},
    };
    for (size_t i = 0; i < sizeof(cases) / sizeof(cases[0]); i++) {
        printf("checking offset 0x%lx (want %s)...\n", (unsigned long)cases[i].offset,
               cases[i].want_fault ? "fault" : "clean read");
        fflush(stdout);
        int r = try_read(base + cases[i].offset);
        printf("  -> %s\n", Describe(r));
        fflush(stdout);
        if (r != 0 && r != 1) {
            fprintf(stderr, "FAIL: offset 0x%lx: test infrastructure itself timed out or misbehaved (%s)\n",
                    (unsigned long)cases[i].offset, Describe(r));
            fail = 1;
            continue;
        }
        int got_fault = (r == 1);
        if (got_fault != cases[i].want_fault) {
            fprintf(stderr, "FAIL: offset 0x%lx: wanted %s, got %s\n", (unsigned long)cases[i].offset,
                    cases[i].want_fault ? "fault" : "clean read", Describe(r));
            fail = 1;
        }
    }

    xl_tsd_free(pages);

    size_t guard = 0;
    size_t page = (size_t)sysconf(_SC_PAGESIZE);
    struct { size_t thread, want; } lengths[] = {
        {512u << 10, (512u << 10) + page},
        {1u << 20, (1u << 20) + page},
        {8u << 20, (8u << 20) + page},
        {(300u << 10) + 1, ((300u << 10) / page + 1) * page + page},
        {1, 2 * page},
    };
    for (size_t i = 0; i < sizeof(lengths) / sizeof(lengths[0]); i++) {
        size_t got = 0;
        if (!xl_stack_length(lengths[i].thread, page, &got) || got != lengths[i].want) {
            fprintf(stderr, "FAIL: a thread whose own stack is %lu bytes maps %lu bytes for its guest stack and the guard page, wanted %lu\n",
                    (unsigned long)lengths[i].thread, (unsigned long)got, (unsigned long)lengths[i].want);
            fail = 1;
        }
    }
    size_t refused[] = {0, SIZE_MAX, SIZE_MAX - page, SIZE_MAX - 2 * page + 1};
    for (size_t i = 0; i < sizeof(refused) / sizeof(refused[0]); i++) {
        size_t got = 7;
        if (xl_stack_length(refused[i], page, &got) || got != 7) {
            fprintf(stderr, "FAIL: a thread that says its own stack is %lu bytes got a guest stack length (%lu): no stack and a stack whose length with the guard does not fit a size must be refused, not rounded\n",
                    (unsigned long)refused[i], (unsigned long)got);
            fail = 1;
        }
    }
    size_t largest = 0;
    if (!xl_stack_length(SIZE_MAX - 2 * page, page, &largest) || largest != SIZE_MAX - page + 1) {
        fprintf(stderr, "FAIL: the longest stack whose length with the guard still fits a size gives %lu, wanted %lu\n", (unsigned long)largest,
                (unsigned long)(SIZE_MAX - page + 1));
        fail = 1;
    }
    size_t length = 0;
    xl_stack_length(512u << 10, page, &length);
    void *stack = xl_stack_map(length, xl_map_anonymous, &guard);
    if (stack == MAP_FAILED || guard != page) {
        fprintf(stderr, "FAIL: the guest stack of a thread with a 512 KiB stack was not mapped with a guard of one page (guard %lu)\n", (unsigned long)guard);
        fail = 1;
    } else {
        struct { uintptr_t offset; int want_fault; } stack_cases[] = {
            {0, 1},
            {page - 8, 1},
            {page, 0},
            {length - 8, 0},
        };
        size_t used = 1;
        if (!xl_stack_used(stack, length, page, &used) || used != 0) {
            fprintf(stderr, "FAIL: a guest stack that nothing wrote to counts %lu bytes as used\n", (unsigned long)used);
            fail = 1;
        }
        struct { size_t depth, want; } marks[] = {
            {8, page},
            {5 * page - 8, 5 * page},
            {3 * page, 5 * page},
            {9 * page + 1, 10 * page},
            {length - page, length - page},
        };
        for (size_t i = 0; i < sizeof(marks) / sizeof(marks[0]); i++) {
            *((volatile char *)stack + length - marks[i].depth) = 1;
            if (!xl_stack_used(stack, length, page, &used) || used != marks[i].want) {
                fprintf(stderr, "FAIL: after a write %lu bytes below the top the guest stack counts %lu bytes as used, wanted %lu\n",
                        (unsigned long)marks[i].depth, (unsigned long)used, (unsigned long)marks[i].want);
                fail = 1;
            }
        }
        for (size_t i = 0; i < sizeof(stack_cases) / sizeof(stack_cases[0]); i++) {
            int r = try_read((uintptr_t)stack + stack_cases[i].offset);
            if ((r != 0 && r != 1) || (r == 1) != stack_cases[i].want_fault) {
                fprintf(stderr, "FAIL: guest stack offset 0x%lx: wanted %s, got %s\n", (unsigned long)stack_cases[i].offset,
                        stack_cases[i].want_fault ? "fault" : "clean read", Describe(r));
                fail = 1;
            }
        }
        munmap(stack, length);
    }
    guard = 0;
    stack = xl_stack_map(4u << 20, limited_mapper, &guard);
    if (stack != MAP_FAILED) {
        fprintf(stderr, "FAIL: a mapper that refuses more than 1 MB gave a stack for 4 MB: a refused size must not be replaced by a smaller one\n");
        fail = 1;
    }
    stack = xl_stack_map(1u << 20, limited_mapper, &guard);
    if (stack == MAP_FAILED || guard != page) {
        fprintf(stderr, "FAIL: a mapper that allows 1 MB gave no stack of 1 MB with a guard page\n");
        fail = 1;
    } else {
        munmap(stack, 1u << 20);
    }
    size_t short_lengths[] = {0, page, page + 1, 3 * page - 1};
    for (size_t i = 0; i < sizeof(short_lengths) / sizeof(short_lengths[0]); i++) {
        stack = xl_stack_map(short_lengths[i], xl_map_anonymous, &guard);
        if (stack != MAP_FAILED) {
            fprintf(stderr, "FAIL: a guest stack of %lu bytes was mapped: a length that leaves no whole page above the guard, or is not whole pages, must be refused\n",
                    (unsigned long)short_lengths[i]);
            fail = 1;
        }
    }
    stack = xl_stack_map(2 * page, xl_map_anonymous, &guard);
    if (stack == MAP_FAILED || guard != page) {
        fprintf(stderr, "FAIL: the shortest guest stack, one page and its guard, was not mapped\n");
        fail = 1;
    } else {
        *((volatile char *)stack + 2 * page - 1) = 1;
        if (try_read((uintptr_t)stack + page - 1) != 1 || try_read((uintptr_t)stack + page) != 0) {
            fprintf(stderr, "FAIL: the shortest guest stack does not fault in its guard and read above it\n");
            fail = 1;
        }
        munmap(stack, 2 * page);
    }
    stack = xl_stack_map(4u << 20, refusing_mapper, &guard);
    if (stack != MAP_FAILED) {
        fprintf(stderr, "FAIL: a mapper that refuses everything still gave a stack\n");
        fail = 1;
    }
    if (fail)
        return 1;
    printf("ok (pagesize=%ld)\n", (long)sysconf(_SC_PAGESIZE));
    return 0;
}
