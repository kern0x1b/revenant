#include "../../src/runtime/xl_tsd_guard.h"
#include "../../src/runtime/xl_budget_lines.h"

#include <limits.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
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

static int same_line(const char *what, const char *got, size_t length, const char *want)
{
    if (length == strlen(want) && strcmp(got, want) == 0)
        return 1;
    fprintf(stderr, "FAIL: %s is built as\n%sand the statistics printed it as\n%s", what, got, want);
    return 0;
}

static int cut_line(const char *what, const char *whole, size_t (*build)(char *, size_t, const void *), const void *count)
{
    size_t sizes[] = {0, 1, 2, 17, 60, strlen(whole), strlen(whole) + 1};
    for (size_t i = 0; i < sizeof(sizes) / sizeof(sizes[0]); i++) {
        char room[400];
        memset(room, '#', sizeof room);
        size_t size = sizes[i];
        size_t length = build(room, size, count);
        size_t kept = size ? size - 1 : 0;
        if (kept > strlen(whole))
            kept = strlen(whole);
        if (length != kept || memcmp(room, whole, kept) != 0 || (size && room[kept] != 0) || room[size] != '#') {
            fprintf(stderr, "FAIL: %s built into %lu bytes is not the first %lu bytes of the line and a zero, or it wrote past them\n", what,
                    (unsigned long)size, (unsigned long)kept);
            return 0;
        }
    }
    return 1;
}

static size_t build_stacks(char *line, size_t size, const void *count)
{
    return xl_stacks_line(line, size, 1, count);
}

static size_t build_budget(char *line, size_t size, const void *count)
{
    return xl_budget_line(line, size, count);
}

static size_t build_pairs(char *line, size_t size, const void *count)
{
    return xl_pair_line(line, size, count, NULL);
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
    struct xl_stacks_count stacks[] = {
        {0, 0, 0, 0, 0},
        {1, 1024ul << 10, 4ul << 10, 1024ul << 10, 4ul << 10},
        {14, 7732ul << 10, 12ul << 10, 516ul << 10, 12ul << 10},
        {UINT_MAX, ULONG_MAX, ULONG_MAX, ULONG_MAX, ULONG_MAX},
    };
    for (size_t i = 0; i < sizeof(stacks) / sizeof(stacks[0]); i++) {
        char want[256], got[256];
        snprintf(want, sizeof want, "xlate: guest stacks: %u live, %lu KiB mapped; the deepest live one has used %lu KiB of %lu KiB, the deepest ever %lu KiB\n",
                 stacks[i].live, stacks[i].mapped >> 10, stacks[i].deepest >> 10, stacks[i].deepest_of >> 10, stacks[i].ever >> 10);
        if (!same_line("the line of the guest stacks", got, xl_stacks_line(got, sizeof got, 1, &stacks[i]), want) ||
            !cut_line("the line of the guest stacks", want, build_stacks, &stacks[i]))
            fail = 1;
        snprintf(want, sizeof want, "xlate: guest stacks: not read (the lock of the list of threads is held), the deepest ever %lu KiB\n", stacks[i].ever >> 10);
        if (!same_line("the line of guest stacks that could not be counted", got, xl_stacks_line(got, sizeof got, 0, &stacks[i]), want))
            fail = 1;
    }
    struct xl_budget_count budgets[] = {
        {0, 20ul << 10, 32ul << 10, 0, 262144, 0, 0},
        {0, 1280ul << 10, 1280ul << 10, 262144, 262144, 4096ul << 10, 4096ul << 10},
        {12, 0, 1280ul << 10, 7, 262144, 1ul << 10, 4096ul << 10},
        {-1, 0, 48ul << 10, 0, 16, 0, 0},
        {INT_MIN, ULONG_MAX, ULONG_MAX, UINT_MAX, UINT_MAX, ULONG_MAX, ULONG_MAX},
    };
    for (size_t i = 0; i < sizeof(budgets) / sizeof(budgets[0]); i++) {
        char want[320], got[320];
        if (budgets[i].unread)
            snprintf(want, sizeof want, "xlate: budget: metadata arena of %lu KiB not read (mincore: errno %d), opaque words %u of %u, aliases %lu of %lu KiB (0 of 0 is not set up yet)\n",
                     budgets[i].arena_size >> 10, budgets[i].unread, budgets[i].words, budgets[i].slots, budgets[i].aliases >> 10, budgets[i].aliases_size >> 10);
        else
            snprintf(want, sizeof want, "xlate: budget: metadata arena %lu of %lu KiB touched, opaque words %u of %u, aliases %lu of %lu KiB (0 of 0 is not set up yet)\n",
                     budgets[i].arena >> 10, budgets[i].arena_size >> 10, budgets[i].words, budgets[i].slots, budgets[i].aliases >> 10, budgets[i].aliases_size >> 10);
        if (!same_line("the budget line", got, xl_budget_line(got, sizeof got, &budgets[i]), want) || !cut_line("the budget line", want, build_budget, &budgets[i]))
            fail = 1;
    }
    struct xl_pair_count pairs[] = {
        {0, 0, 0, 0, 0},
        {123456, 17, 9, 2, 1},
        {4294967295u, 4294967295u, 4294967295u, 4294967295u, 64},
    };
    for (size_t i = 0; i < sizeof(pairs) / sizeof(pairs[0]); i++) {
        char want[320], got[320];
        const struct xl_pair_count *all = &pairs[i], *before = &pairs[i ? i - 1 : 0];
        snprintf(want, sizeof want, "xlate: pair stores: %u stored and %u failed since the start (a failed one found the pair changed after its load); "
                 "%u waited for a lock and gave up the processor %u times; %u of 64 locks held now\n", all->stored, all->failed, all->waited, all->yielded, all->held);
        if (!same_line("the line of the pair stores", got, xl_pair_line(got, sizeof got, all, NULL), want) || !cut_line("the line of the pair stores", want, build_pairs, all))
            fail = 1;
        snprintf(want, sizeof want, "xlate: pair stores: %u stored and %u failed in this window, %u stored and %u failed since the start (a failed one found the pair changed after its load); "
                 "%u waited for a lock and gave up the processor %u times; %u of 64 locks held now\n", all->stored - before->stored, all->failed - before->failed,
                 all->stored, all->failed, all->waited, all->yielded, all->held);
        if (!same_line("the line of the pair stores of a window", got, xl_pair_line(got, sizeof got, all, before), want))
            fail = 1;
    }
    if (fail)
        return 1;
    printf("ok (pagesize=%ld)\n", (long)sysconf(_SC_PAGESIZE));
    return 0;
}
