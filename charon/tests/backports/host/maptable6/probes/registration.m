#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#include <dispatch/dispatch.h>
#include <pthread.h>
#include <stdio.h>

/* Does the release's dispatch_resume call a source's registration handler before it returns, or only
   enqueue it? That is what the registration half of the barrier source entry rests on
   (coordination/crutches.md, "apple-compat: a barrier source handler below iOS 10"), where the port's own
   dispatch_resume would take the handler off and run it inside a dispatch_barrier_sync of its own - which
   only answers as the release does if the release runs the handler before it returns.

   The experiment holds the target queue with a block that never returns until told, so nothing can run on
   it. A handler the release runs before returning must then run on the resuming thread, and
   dispatch_resume cannot return before the handler has finished: either the flag is already set when it
   returns, or the call itself is still blocked. Both are read, and the call is made on a thread of its own
   with a timeout, so a release that waits cannot hang the run.

   Read, not asserted: the verdicts are what this prints. Built and run by probes.sh (MAPTABLE6_PROBES=1). */

static volatile int handlerRan;
static volatile long handlerAtMs;
static dispatch_semaphore_t held, release, handlerEntered;
static dispatch_source_t source;

static long now_ms(void)
{
    return (long)(CFAbsoluteTimeGetCurrent() * 1000.0);
}

static void *resume_on_its_own_thread(void *ignored)
{
    dispatch_resume(source);
    return NULL;
}

static void case_for(const char *label, int concurrent)
{
    dispatch_queue_t target = dispatch_queue_create(label, concurrent ? DISPATCH_QUEUE_CONCURRENT : DISPATCH_QUEUE_SERIAL);
    source = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, target);
    dispatch_source_set_timer(source, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), DISPATCH_TIME_FOREVER, 0);
    dispatch_source_set_registration_handler(source, ^{
        handlerAtMs = now_ms();
        handlerRan = 1;
        dispatch_semaphore_signal(handlerEntered);
    });
    /* The queue is held, and nothing is on it but this. */
    dispatch_async(target, ^{ dispatch_semaphore_wait(release, DISPATCH_TIME_FOREVER); });
    dispatch_semaphore_wait(held, DISPATCH_TIME_FOREVER);
    handlerRan = 0;
    handlerAtMs = 0;
    long before = now_ms();
    pthread_t thread;
    pthread_create(&thread, NULL, resume_on_its_own_thread, NULL);
    /* Has the handler run while the queue is held? */
    usleep(300000);
    int duringQueueHeld = handlerRan;
    /* Did dispatch_resume return? */
    long waited = 0;
    while (waited < 2000 && !handlerRan) { usleep(50000); waited += 50; }
    printf("%s target, the queue held: the registration handler ran while the queue was held: %s\n",
           concurrent ? "a concurrent" : "a serial", duringQueueHeld ? "yes" : "no");
    if (duringQueueHeld)
        printf("  it ran %ld ms after the resume started, on the resuming thread: %s\n", handlerAtMs - before,
               handlerAtMs - before < 300 ? "yes" : "no");
    else {
        printf("  dispatch_resume returned without it: the release only enqueues it\n");
        dispatch_semaphore_signal(release);
        long ran = 0;
        while (ran < 2000 && !handlerRan) { usleep(50000); ran += 50; }
        printf("  after the queue drained: the handler %s\n", handlerRan ? "ran" : "did not run within 2 s");
        pthread_join(thread, NULL);
        dispatch_source_cancel(source);
        return;
    }
    /* It ran while the queue was held, so the resume is either finished or blocked on the queue; let it go. */
    dispatch_semaphore_signal(release);
    pthread_join(thread, NULL);
    printf("  dispatch_resume returned %s while the queue was held\n", duringQueueHeld ? "before the handler" : "after it");
    dispatch_source_cancel(source);
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    held = dispatch_semaphore_create(0);
    release = dispatch_semaphore_create(0);
    handlerEntered = dispatch_semaphore_create(0);
    case_for("registration.serial", 0);
    case_for("registration.concurrent", 1);
    printf("registration: done\n");
    return 0;
}
