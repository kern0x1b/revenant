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
    if (fail)
        return 1;
    printf("ok (pagesize=%ld)\n", (long)sysconf(_SC_PAGESIZE));
    return 0;
}
