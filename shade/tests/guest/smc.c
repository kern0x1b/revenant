// smc.c: guest regression test for translated code that is rewritten while it may be running.
//
// 1. Two views of one page: a file is mapped twice, once writable and once
//    executable. Code written through the first view and invalidated through
//    the second must be what the second view runs, however often it changes.
// 2. Rewriting from a signal handler: the handler patches the function it
//    interrupted the caller of, calls it, and returns; the caller then runs the
//    new code, and a handler that ends by taking execute permission away and
//    giving it back leaves nothing stale behind.
//
// Prints one line per part and exits with the number of failures.
#include <libkern/OSCacheControl.h>
#include <fcntl.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

typedef int (*value_fn)(void);

// ARM: mov r0, #N ; bx lr
static void store_value(volatile uint32_t *code, int value)
{
    code[0] = 0xe3a00000U | (uint32_t)value;
    code[1] = 0xe12fff1eU;
}

static int failures;
static void report(const char *name, int ok, const char *why)
{
    printf("%-24s %s%s%s\n", name, ok ? "ok" : "FAIL", ok ? "" : ": ", ok ? "" : why);
    if (!ok)
        ++failures;
}

static void two_views(void)
{
    char path[] = "/tmp/charon-smc-XXXXXX";
    int fd = mkstemp(path);
    if (fd < 0 || ftruncate(fd, getpagesize()) != 0) {
        report("alias-code", 0, "no file");
        return;
    }
    volatile uint32_t *writer = mmap(NULL, getpagesize(), PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    void *runner = mmap(NULL, getpagesize(), PROT_READ | PROT_EXEC, MAP_SHARED, fd, 0);
    unlink(path);
    close(fd);
    if (writer == MAP_FAILED || runner == MAP_FAILED) {
        report("alias-code", 0, "mmap failed");
        return;
    }
    int wrong = 0;
    for (int round = 1; round <= 200; ++round) {
        store_value(writer, round & 0xff);
        sys_icache_invalidate(runner, 8);
        if (((value_fn)runner)() != (round & 0xff))
            ++wrong;
    }
    report("alias-code", wrong == 0, "the executable view ran code that had been replaced");
}

static uint32_t *patched;
static int patched_in_handler, after_return;

static void on_usr1(int sig)
{
    (void)sig;
    store_value((volatile uint32_t *)patched, 7);
    sys_icache_invalidate(patched, 8);
    patched_in_handler = ((value_fn)patched)();
    mprotect(patched, getpagesize(), PROT_READ);
    mprotect(patched, getpagesize(), PROT_READ | PROT_WRITE | PROT_EXEC);
}

static void signal_rewrite(void)
{
    patched = mmap(NULL, getpagesize(), PROT_READ | PROT_WRITE | PROT_EXEC, MAP_ANON | MAP_PRIVATE, -1, 0);
    if (patched == MAP_FAILED) {
        report("handler-rewrite", 0, "mmap failed");
        return;
    }
    store_value((volatile uint32_t *)patched, 3);
    sys_icache_invalidate(patched, 8);
    int before = ((value_fn)patched)();
    signal(SIGUSR1, on_usr1);
    kill(getpid(), SIGUSR1);
    after_return = ((value_fn)patched)();
    report("handler-rewrite", before == 3 && patched_in_handler == 7 && after_return == 7,
           "code patched in a handler was not what ran, in the handler or after it");
}

int main(void)
{
    two_views();
    signal_rewrite();
    printf("failures=%d\n", failures);
    return failures;
}
