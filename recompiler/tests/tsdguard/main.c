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

    size_t size = 0, guard = 0;
    size_t page = (size_t)sysconf(_SC_PAGESIZE);
    void *stack = xl_stack_map(4u << 20, 256u << 10, limited_mapper, &size, &guard);
    if (stack == MAP_FAILED || size != (1u << 20) || guard != page) {
        fprintf(stderr, "FAIL: a mapper that refuses more than 1 MB gave size %lu and guard %lu for a first try of 4 MB, wanted 1 MB and one page\n",
                (unsigned long)size, (unsigned long)guard);
        fail = 1;
    } else {
        struct { uintptr_t offset; int want_fault; } stack_cases[] = {
            {0, 1},
            {page - 8, 1},
            {page, 0},
            {size - 8, 0},
        };
        for (size_t i = 0; i < sizeof(stack_cases) / sizeof(stack_cases[0]); i++) {
            int r = try_read((uintptr_t)stack + stack_cases[i].offset);
            if ((r != 0 && r != 1) || (r == 1) != stack_cases[i].want_fault) {
                fprintf(stderr, "FAIL: guest stack offset 0x%lx: wanted %s, got %s\n", (unsigned long)stack_cases[i].offset,
                        stack_cases[i].want_fault ? "fault" : "clean read", Describe(r));
                fail = 1;
            }
        }
        munmap(stack, size);
    }
    struct { size_t host, want; } firsts[] = {
        {512u << 10, 1u << 20},
        {1u << 20, 2u << 20},
        {2u << 20, 4u << 20},
        {8u << 20, 4u << 20},
        {(size_t)-1 / 4, 4u << 20},
        {64u << 10, 256u << 10},
        {0, 256u << 10},
        {(300u << 10) + 1, (640u << 10)},
    };
    for (size_t i = 0; i < sizeof(firsts) / sizeof(firsts[0]); i++) {
        size_t got = xl_stack_first(firsts[i].host, 256u << 10, 4u << 20);
        if (got != firsts[i].want) {
            fprintf(stderr, "FAIL: a thread with a host stack of %lu bytes first tries %lu bytes of guest stack, wanted %lu\n",
                    (unsigned long)firsts[i].host, (unsigned long)got, (unsigned long)firsts[i].want);
            fail = 1;
        }
    }
    stack = xl_stack_map(4u << 20, 256u << 10, refusing_mapper, &size, &guard);
    if (stack != MAP_FAILED) {
        fprintf(stderr, "FAIL: a mapper that refuses everything still gave a stack\n");
        fail = 1;
    }
    if (fail)
        return 1;
    printf("ok (pagesize=%ld)\n", (long)sysconf(_SC_PAGESIZE));
    return 0;
}
