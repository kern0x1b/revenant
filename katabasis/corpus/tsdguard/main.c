// corpus/tsdguard: proves runtime/xl_tsd_guard.h's page-protection scheme itself, not the
// lifted-code path that uses it. mmap/mprotect/fork/wait are POSIX, so this runs on the build
// host or is cross-built for the target device (round 12: both, see check.sh): it includes the
// exact header runtime.c does, so there is one implementation under test, not a reimplementation
// that could quietly drift from it.
//
// coordination/crutches.md, "TPIDRRO_EL0 backed by a mostly-zero block": round 10's build-time
// scan (xlate/src/tsd_scan.cpp) is a static heuristic with known false-negative gaps (see
// xl_tsd_guard.h's own comment, and coordination/reviews/2026-09-27-katabasis-7ecd76e.md). This
// is what actually proves a guest read below the one audited offset (0x358, Swift's
// __PTK_FRAMEWORK_SWIFT_KEY7) cannot silently return zero: it now faults for real, regardless of
// whether any static scan would have caught the instruction that did it.
//
// Each candidate access runs in its OWN forked child, bounded by its own alarm() and, from the
// parent, a second bounded wait with a SIGKILL fallback: an earlier version of this test used
// sigsetjmp/siglongjmp out of a SIGSEGV/SIGBUS handler in the ONE process and hung on the real
// device for 13+ minutes (coordinator's hypothesis: the handler returned to the same faulting
// instruction and re-faulted forever instead of unwinding -- host and device may simply differ
// here, and this test does not need to find out which). fork+waitpid cannot have that failure
// mode: whatever the child does, the parent's wait either gets a normal exit or a signal, never a
// hang caused by the child's own signal delivery -- and the timeouts below mean this process
// itself cannot hang either, so a device run is always a bounded result, not an open-ended wait.
#include "../../runtime/xl_tsd_guard.h"

#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>

#define TIMEOUT_SECONDS 5

static void alarm_die(int sig)
{
    (void)sig;
    _exit(99); // distinct from a real SIGSEGV/SIGBUS (which kills the child via a signal, not exit)
}

// Runs in the forked child only; never returns.
static void child_read(uintptr_t addr)
{
    signal(SIGALRM, alarm_die);
    alarm(TIMEOUT_SECONDS);
    volatile uint64_t v = *(volatile uint64_t *)addr;
    (void)v;
    _exit(0); // read succeeded, no fault
}

// 0: clean read. 1: killed by a signal (a real fault -- what a protected offset must produce).
// 2: the child's own alarm fired (should never happen for a plain memory read; bounds it anyway).
// 3: even the parent's bounded wait ran out before the child changed state at all (SIGKILLed).
// 4: some other wait status (stopped, ...) -- not classifiable as fault or clean read.
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

    // Slots this recompiler's guest threads have never populated and never audited (real Darwin
    // has pthread_self at slot 0, errno at slot 1, and so on up to slot 106, all below 0x358) must
    // fault; the audited offset and a bit further into the same RW page (unprotected by design,
    // see xl_tsd_guard.h) must read cleanly.
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
    // Named per round-11 review (coordination/reviews/2026-09-27-katabasis-2afe24d.md): a bare
    // "ok" does not say what page size the test just proved the guard at, and this binary can run
    // on a build host (16 KiB on Apple Silicon) or the actual armv7 device (4 KiB) -- print it so
    // the answer is in the run's own output, not left to whoever launched it to remember.
    printf("ok (pagesize=%ld)\n", (long)sysconf(_SC_PAGESIZE));
    return 0;
}
