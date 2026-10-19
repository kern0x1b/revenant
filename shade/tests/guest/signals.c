// signals.c: guest test of signal delivery - handlers, frames, sigreturn,
// faults turned into signals, the alternate stack, masks and VFP state.
// One line per case, "ok" or "FAIL <why>"; exits with the number of failures.
#include <setjmp.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

static int failures;
static void report(const char *name, int ok, const char *why)
{
    printf("%-22s %s%s\n", name, ok ? "ok" : "FAIL ", ok ? "" : why);
    if (!ok) ++failures;
}

// 1. kill(self) with SA_SIGINFO; 7. the signal is blocked while its handler runs.
static volatile int usr1_calls, usr1_signo, usr1_pid, usr1_blocked;
static void on_usr1(int signal, siginfo_t *info, void *context)
{
    (void)context;
    ++usr1_calls;
    usr1_signo = info->si_signo;
    usr1_pid = info->si_pid;
    sigset_t current;
    sigprocmask(SIG_BLOCK, NULL, &current);
    usr1_blocked = sigismember(&current, signal);
}

// 2./4. faults escape with siglongjmp.
static sigjmp_buf escape;
static volatile int fault_signal, fault_code;
static volatile uintptr_t fault_address;
static void on_fault(int signal, siginfo_t *info, void *context)
{
    (void)context;
    fault_signal = signal;
    fault_code = info->si_code;
    fault_address = (uintptr_t)info->si_addr;
    siglongjmp(escape, 1);
}

// 3. a write to a read-only page: the handler makes it writable and returns,
// and the store runs again.
static volatile char *protected_page;
static volatile int bus_calls;
static void on_bus_repair(int signal, siginfo_t *info, void *context)
{
    (void)signal; (void)context;
    ++bus_calls;
    mprotect((void *)((uintptr_t)info->si_addr & ~(uintptr_t)(getpagesize() - 1)),
             getpagesize(), PROT_READ | PROT_WRITE);
}

// 5. the handler runs on the alternate stack.
static char alternate[65536];
static volatile int on_alternate;
static void on_usr2(int signal)
{
    (void)signal;
    char here;
    on_alternate = &here >= alternate && &here < alternate + sizeof alternate;
}

// 6. the handler uses VFP registers; the interrupted code's must survive.
static void on_alarm(int signal)
{
    (void)signal;
    volatile double clobber = 1.0;
    for (int i = 0; i < 100; ++i) clobber = clobber * 3.5 + 0.25;
    __asm__ volatile("vmov.f64 d8, #2.0\n" "vmov.f64 d9, #-3.0" ::: "d8", "d9");
}

// 8. SA_RESETHAND: the second delivery takes the default action (ignore).
static volatile int winch_calls;
static void on_winch(int signal) { (void)signal; ++winch_calls; }

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    struct sigaction action;

    memset(&action, 0, sizeof action);
    action.sa_sigaction = on_usr1;
    action.sa_flags = SA_SIGINFO;
    sigaction(SIGUSR1, &action, NULL);
    volatile int canary = 0x5a5a;
    int result = kill(getpid(), SIGUSR1);
    report("kill-self-handler", usr1_calls == 1 && result == 0 && canary == 0x5a5a,
           "handler did not run once or the caller's state was not restored");
    report("siginfo", usr1_signo == SIGUSR1 && usr1_pid == getpid(), "si_signo/si_pid wrong");
    report("mask-during-handler", usr1_blocked == 1, "own signal not blocked in handler");
    sigset_t after;
    sigprocmask(SIG_BLOCK, NULL, &after);
    report("mask-restored", !sigismember(&after, SIGUSR1), "mask not restored by sigreturn");

    memset(&action, 0, sizeof action);
    action.sa_sigaction = on_fault;
    action.sa_flags = SA_SIGINFO;
    sigaction(SIGSEGV, &action, NULL);
    sigaction(SIGBUS, &action, NULL);
    sigaction(SIGILL, &action, NULL);
    sigaction(SIGTRAP, &action, NULL);
    if (sigsetjmp(escape, 1) == 0) {
        volatile int value = *(volatile int *)0x10;
        (void)value;
        report("segv-unmapped", 0, "no fault");
    } else {
        report("segv-unmapped", fault_signal == SIGSEGV && fault_address == 0x10 && fault_code == SEGV_MAPERR,
               "wrong signal, address or code");
    }
    if (sigsetjmp(escape, 1) == 0) {
        __asm__ volatile(".inst.n 0xde00"); // UDF #0 in Thumb
        report("sigill-udf", 0, "no fault");
    } else {
        report("sigill-udf", fault_signal == SIGILL, "wrong signal");
    }
    if (sigsetjmp(escape, 1) == 0) {
        __asm__ volatile(".inst.n 0xdefe"); // the trap encoding: a breakpoint to Darwin
        report("sigtrap-trap", 0, "no fault");
    } else {
        report("sigtrap-trap", fault_signal == SIGTRAP, "wrong signal");
    }

    memset(&action, 0, sizeof action);
    action.sa_sigaction = on_bus_repair;
    action.sa_flags = SA_SIGINFO;
    sigaction(SIGBUS, &action, NULL);
    protected_page = mmap(NULL, getpagesize(), PROT_READ, MAP_ANON | MAP_PRIVATE, -1, 0);
    protected_page[16] = 'x';
    report("bus-repair-retry", bus_calls == 1 && protected_page[16] == 'x',
           "handler did not run once or the store was not retried");

    // 3b. calling into a page that is not executable, three times over:
    // each call faults, each fault reaches the handler.
    {
        // iOS 6's sigsetjmp never saves the mask and its siglongjmp never
        // restores it (both test the savemask flag with "tst rN, #0"), so a
        // handler left with siglongjmp keeps its signal blocked and the next
        // fault kills the process - on the device as here. SA_NODEFER keeps
        // the signal deliverable, as code that escapes its handlers must.
        memset(&action, 0, sizeof action);
        action.sa_sigaction = on_fault;
        action.sa_flags = SA_SIGINFO | SA_NODEFER;
        sigaction(SIGBUS, &action, NULL);
        sigaction(SIGSEGV, &action, NULL);
        static char blob[8192] __attribute__((aligned(4096)));
        void *data = (void *)(((uintptr_t)blob + 4095) & ~(uintptr_t)4095);
        ((volatile uint16_t *)data)[0] = 0x4770; // bx lr, Thumb
        int (*call)(void) = (int (*)(void))((uintptr_t)data | 1);
        volatile int faults = 0;
        for (int i = 0; i < 3; ++i) {
            if (sigsetjmp(escape, 1) == 0)
                call();
            else
                ++faults;
        }
        report("exec-fault-repeated", faults == 3 && fault_signal == SIGBUS,
               "calling a data page did not fault into the handler every time");
    }

    stack_t stack = { .ss_sp = alternate, .ss_size = sizeof alternate, .ss_flags = 0 };
    report("sigaltstack", sigaltstack(&stack, NULL) == 0, "sigaltstack failed");
    memset(&action, 0, sizeof action);
    action.sa_handler = on_usr2;
    action.sa_flags = SA_ONSTACK;
    sigaction(SIGUSR2, &action, NULL);
    kill(getpid(), SIGUSR2);
    report("handler-on-altstack", on_alternate == 1, "handler not on the alternate stack");

    memset(&action, 0, sizeof action);
    action.sa_handler = on_alarm;
    sigaction(SIGALRM, &action, NULL);
    double kept8, kept9;
    __asm__ volatile("vmov.f64 d8, #5.0\n" "vmov.f64 d9, #0.5" ::: "d8", "d9");
    kill(getpid(), SIGALRM);
    __asm__ volatile("vmov %Q0, %R0, d8\n" "vmov %Q1, %R1, d9" : "=r"(kept8), "=r"(kept9));
    report("vfp-preserved", kept8 == 5.0 && kept9 == 0.5, "d8/d9 changed across the handler");

    memset(&action, 0, sizeof action);
    action.sa_handler = on_winch;
    action.sa_flags = SA_RESETHAND;
    sigaction(SIGWINCH, &action, NULL);
    kill(getpid(), SIGWINCH);
    kill(getpid(), SIGWINCH);
    report("sa-resethand", winch_calls == 1, "handler ran again after SA_RESETHAND");

    printf("failures=%d\n", failures);
    return failures;
}
