#import <Accelerate/Accelerate.h>
#import <Foundation/Foundation.h>
#include <mach/mach.h>
#include <pthread.h>
#include <stdio.h>
#include <unistd.h>

int charon_host_BLASSetThreading(const enum BLAS_THREADING threading);
enum BLAS_THREADING charon_host_BLASGetThreading(void);

static int failures;
static int checks;

static void report(int passed, const char *name)
{
    checks++;
    printf("%s %s\n", passed ? "ok" : "FAIL", name);
    fflush(stdout);
    if (!passed) {
        failures++;
    }
}

static void answer(const char *what, int mine_set, int mine_get, int theirs_set, int theirs_get)
{
    char label[128];
    int agreed = mine_set == theirs_set && mine_get == theirs_get;
    snprintf(label, sizeof label, "%s (the port %d/%d, the host %d/%d)", what, mine_set, mine_get, theirs_set,
             theirs_get);
    report(agreed, label);
}

#define SIDE 480
static volatile int running;
static volatile double sink;

static int thread_count(void)
{
    thread_act_array_t threads;
    mach_msg_type_number_t count = 0;
    if (task_threads(mach_task_self(), &threads, &count) != KERN_SUCCESS) {
        return -1;
    }
    for (mach_msg_type_number_t at = 0; at < count; at++) {
        mach_port_deallocate(mach_task_self(), threads[at]);
    }
    vm_deallocate(mach_task_self(), (vm_offset_t)threads, count * sizeof(thread_t));
    return (int)count;
}

static void *worker(void *ignored)
{
    static float a[SIDE * SIDE], b[SIDE * SIDE], c[SIDE * SIDE];
    int at;
    for (at = 0; at < SIDE * SIDE; at++) {
        a[at] = (float)(at % 17) / 17.0f;
        b[at] = (float)(at % 13) / 13.0f;
    }
    while (running) {
        cblas_sgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans, SIDE, SIDE, SIDE, 1.0f, a, SIDE, b, SIDE, 0.0f, c, SIDE);
        sink += c[at % (SIDE * SIDE)];
    }
    return NULL;
}

static int threads_while_working(enum BLAS_THREADING model)
{
    pthread_t threads[4];
    int most = 0;
    BLASSetThreading(model);
    running = 1;
    for (int at = 0; at < 4; at++) {
        pthread_create(&threads[at], NULL, worker, NULL);
    }
    for (int round = 0; round < 40; round++) {
        usleep(20000);
        int now = thread_count();
        if (now > most) {
            most = now;
        }
    }
    running = 0;
    for (int at = 0; at < 4; at++) {
        pthread_join(threads[at], NULL);
    }
    return most;
}

static int mine_in_a_thread, theirs_in_a_thread;

static void *reads_both(void *ignored)
{
    mine_in_a_thread = (int)charon_host_BLASGetThreading();
    theirs_in_a_thread = (int)BLASGetThreading();
    return NULL;
}

int main(void)
{
    @autoreleasepool {
        answer("a thread that has set nothing", -1, (int)charon_host_BLASGetThreading(), -1,
               (int)BLASGetThreading());
        answer("a set to single-threaded is kept", charon_host_BLASSetThreading(BLAS_THREADING_SINGLE_THREADED),
               (int)charon_host_BLASGetThreading(), BLASSetThreading(BLAS_THREADING_SINGLE_THREADED),
               (int)BLASGetThreading());
        answer("a set back to multi-threaded is kept", charon_host_BLASSetThreading(BLAS_THREADING_MULTI_THREADED),
               (int)charon_host_BLASGetThreading(), BLASSetThreading(BLAS_THREADING_MULTI_THREADED),
               (int)BLASGetThreading());
        answer("a value the library does not have is refused and the setting is left",
               charon_host_BLASSetThreading((enum BLAS_THREADING)99), (int)charon_host_BLASGetThreading(),
               BLASSetThreading((enum BLAS_THREADING)99), (int)BLASGetThreading());

        pthread_t other;
        charon_host_BLASSetThreading(BLAS_THREADING_SINGLE_THREADED);
        BLASSetThreading(BLAS_THREADING_SINGLE_THREADED);
        pthread_create(&other, NULL, reads_both, NULL);
        pthread_join(other, NULL);
        report(mine_in_a_thread == BLAS_THREADING_MULTI_THREADED && theirs_in_a_thread == BLAS_THREADING_MULTI_THREADED,
               "another thread answers the model it has set (which is none), on both sides");
        charon_host_BLASSetThreading(BLAS_THREADING_MULTI_THREADED);
        BLASSetThreading(BLAS_THREADING_MULTI_THREADED);

        int multi = threads_while_working(BLAS_THREADING_MULTI_THREADED);
        int single = threads_while_working(BLAS_THREADING_SINGLE_THREADED);
        BLASSetThreading(BLAS_THREADING_MULTI_THREADED);
        printf("note threads in the process with four workers inside cblas_sgemm: %d multi-threaded, %d "
               "single-threaded - the model does not bring the count down\n",
               multi, single);

        printf("%d checks, %d failures\n", checks, failures);
    }
    return failures == 0 ? 0 : 1;
}
