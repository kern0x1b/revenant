#include <dispatch/dispatch.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static volatile int holderInside;
static volatile int handlerAlone;
static volatile int handlerRan;
static volatile int handlerOnSecond;
static volatile int returned;

static int registration;
static int never;
static int onQueue;
static dispatch_source_t source;
static const char *width;
static dispatch_semaphore_t returnedSem;

static void tag(dispatch_queue_t queue, const void *value)
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    dispatch_queue_set_specific(queue, (const void *)0x636861726f6e51u, (void *)value, NULL);
#pragma clang diagnostic pop
}

static void *where(void)
{
    return dispatch_get_specific((const void *)0x636861726f6e51u);
}

static void call_under_test(void)
{
    if (registration)
        dispatch_resume(source);
    else
        dispatch_source_cancel(source);
    returned = 1;
    dispatch_semaphore_signal(returnedSem);
}

static void *runner(void *ignored)
{
    (void)ignored;
    call_under_test();
    return NULL;
}

static void say(const char *which, const char *held, const char *ran)
{
    printf("%s %s: held=%s ran=%s alone=%s second=%s returned=%s\n", which, width, held, ran,
           handlerAlone < 0 ? "n/a" : (handlerAlone ? "yes" : "no"),
           handlerOnSecond < 0 ? "n/a" : (handlerOnSecond ? "yes" : "no"),
           returned ? "yes" : "no");
}

int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    const char *which = argc > 1 ? argv[1] : "cancel";
    width = argc > 2 && strcmp(argv[2], "serial") == 0 ? "serial" : "concurrent";
    registration = strcmp(which, "registration") == 0;
    never = strcmp(which, "neverresumed") == 0;
    int retargetBefore = strcmp(which, "retargetbefore") == 0;
    int retargetAfter = strcmp(which, "retargetafter") == 0;
    onQueue = strcmp(which, "onqueue") == 0;

    holderInside = 0;
    handlerAlone = -1;
    handlerRan = 0;
    handlerOnSecond = -1;
    returned = 0;
    returnedSem = dispatch_semaphore_create(0);

    dispatch_queue_attr_t attr = strcmp(width, "serial") == 0 ? DISPATCH_QUEUE_SERIAL : DISPATCH_QUEUE_CONCURRENT;
    dispatch_queue_t queue = dispatch_queue_create("target", attr);
    dispatch_queue_t second = dispatch_queue_create("second", attr);
    tag(queue, (const void *)1);
    tag(second, (const void *)2);
    source = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    int firstIsTarget = 1;

    dispatch_semaphore_t entered = dispatch_semaphore_create(0);
    dispatch_semaphore_t release = dispatch_semaphore_create(0);
    dispatch_semaphore_t handlerDone = dispatch_semaphore_create(0);
    dispatch_block_t handler = dispatch_block_create(DISPATCH_BLOCK_BARRIER, ^{
        handlerAlone = holderInside ? 0 : 1;
        handlerRan = 1;
        handlerOnSecond = where() == (void *)2 ? 1 : 0;
        dispatch_semaphore_signal(handlerDone);
    });

    if (retargetBefore) {
        dispatch_set_target_queue(source, second);
        firstIsTarget = 0;
    }
    if (registration) {
        dispatch_source_set_registration_handler(source, handler);
    } else {
        dispatch_source_set_cancel_handler(source, handler);
        if (!never)
            dispatch_resume(source);
    }
    if (retargetAfter) {
        dispatch_set_target_queue(source, second);
        firstIsTarget = 0;
    }

    dispatch_queue_t held = firstIsTarget ? queue : second;
    if (onQueue) {
        dispatch_semaphore_t callReturned = dispatch_semaphore_create(0);
        dispatch_async(held, ^{
            holderInside = 1;
            dispatch_semaphore_signal(entered);
            dispatch_semaphore_wait(release, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC));
            holderInside = 0;
            call_under_test();
            dispatch_semaphore_signal(callReturned);
        });
        dispatch_semaphore_wait(entered, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
        dispatch_semaphore_signal(release);
        long called = dispatch_semaphore_wait(callReturned, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC));
        dispatch_semaphore_wait(handlerDone, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC));
        say(which, "n/a", handlerRan ? "yes" : "no");
        return called ? 1 : 0;
    }

    dispatch_async(held, ^{
        holderInside = 1;
        dispatch_semaphore_signal(entered);
        dispatch_semaphore_wait(release, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC));
        holderInside = 0;
    });
    dispatch_semaphore_wait(entered, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));

    pthread_t thread;
    pthread_create(&thread, NULL, runner, NULL);
    dispatch_semaphore_wait(returnedSem, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC));
    int returnedWhileHeld = returned;
    long ranWhileHeld = strcmp(width, "serial") == 0 ? 1 : dispatch_semaphore_wait(handlerDone, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC));
    dispatch_semaphore_signal(release);
    pthread_join(thread, NULL);
    if (ranWhileHeld != 0)
        dispatch_semaphore_wait(handlerDone, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC));
    say(which, returnedWhileHeld ? "yes" : "no", handlerRan ? "yes" : "no");
    return 0;
}
