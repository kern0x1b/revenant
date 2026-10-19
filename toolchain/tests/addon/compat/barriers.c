#include <dispatch/dispatch.h>
#include <dlfcn.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

dispatch_queue_t revenant_dispatch_queue_create(const char *, dispatch_queue_attr_t);
void revenant_dispatch_resume(dispatch_object_t);
void revenant_dispatch_source_set_event_handler(dispatch_source_t, dispatch_block_t);
dispatch_block_t dispatch_block_create(dispatch_block_flags_t, dispatch_block_t);

typedef dispatch_queue_t (*create_f)(const char *, dispatch_queue_attr_t);
typedef dispatch_block_t (*block_create_f)(dispatch_block_flags_t, dispatch_block_t);
typedef void (*resume_f)(dispatch_object_t);
typedef void (*set_event_handler_f)(dispatch_source_t, dispatch_block_t);

struct api {
    create_f create;
    block_create_f block_create;
    resume_f resume;
    set_event_handler_f set_event_handler;
};

static struct api ours, darwins, control;
static int fails;

struct seen { char order[16]; int inside; int otherAtEntry; };
static struct seen *revenant_next_seen(void)
{
    static struct seen slots[16];
    static unsigned used;
    if (used >= sizeof slots / sizeof slots[0])
        abort();
    struct seen *s = &slots[used++];
    memset(s, 0, sizeof *s);
    s->otherAtEntry = -1;
    return s;
}

static void expect(int holds, const char *what)
{
    if (!holds) {
        printf("FAIL  %s\n", what);
        fails++;
    }
}

static const char *alone_of(const char *answer)
{
    const char *alone = strstr(answer, "alone=");
    return alone ? alone : answer;
}

static void scenario(const struct api *api, int concurrent, int late, char *answer, size_t size)
{
    dispatch_queue_t queue = api->create(concurrent ? "barriers.concurrent" : "barriers.serial",
                                         concurrent ? DISPATCH_QUEUE_CONCURRENT : DISPATCH_QUEUE_SERIAL);
    if (!queue) {
        snprintf(answer, size, "no queue");
        return;
    }
    dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(source, dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC), DISPATCH_TIME_FOREVER, 0);
    struct seen *s = revenant_next_seen();
    dispatch_semaphore_t started = dispatch_semaphore_create(0);
    dispatch_semaphore_t release = dispatch_semaphore_create(0);
    dispatch_semaphore_t entered = dispatch_semaphore_create(0);
    dispatch_semaphore_t handlerDone = dispatch_semaphore_create(0);
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
#define RECORD(c) do { size_t length = strlen(s->order); \
        if (length + 2 < sizeof s->order) { s->order[length] = (c); s->order[length + 1] = 0; } } while (0)
    dispatch_block_t handler = api->block_create(DISPATCH_BLOCK_BARRIER, ^{
        s->otherAtEntry = s->inside;
        RECORD('H');
        dispatch_semaphore_signal(entered);
        dispatch_semaphore_signal(handlerDone);
    });
    if (!late)
        api->set_event_handler(source, handler);
    api->resume(source);
    if (late)
        api->set_event_handler(source, handler);

    dispatch_async(queue, ^{
        s->inside = 1;
        RECORD('A');
        dispatch_semaphore_signal(started);
        dispatch_semaphore_wait(release, DISPATCH_TIME_FOREVER);
        s->inside = 0;
    });
    dispatch_semaphore_wait(started, DISPATCH_TIME_FOREVER);
    dispatch_async(queue, ^{
        RECORD('B');
        dispatch_semaphore_signal(done);
    });
    usleep(300000);

    long enteredInTime = dispatch_semaphore_wait(entered, dispatch_time(DISPATCH_TIME_NOW, 500 * NSEC_PER_MSEC));
    int alone = concurrent ? (enteredInTime != 0 ? s->otherAtEntry == 0 : 1) : 1;
    dispatch_semaphore_signal(release);
    dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    dispatch_semaphore_wait(handlerDone, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    snprintf(answer, size, "%s alone=%s", s->order, alone ? "yes" : "no");
#undef RECORD
    dispatch_source_cancel(source);
    dispatch_semaphore_signal(release);
    dispatch_release(source);
    dispatch_release(queue);
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    ours = (struct api){revenant_dispatch_queue_create, dispatch_block_create, revenant_dispatch_resume,
                        revenant_dispatch_source_set_event_handler};
    void *libdispatch = dlopen("/usr/lib/system/libdispatch.dylib", RTLD_LAZY | RTLD_LOCAL);
    darwins = (struct api){dlsym(libdispatch, "dispatch_queue_create"), dlsym(libdispatch, "dispatch_block_create"),
                           dlsym(libdispatch, "dispatch_resume"), dlsym(libdispatch, "dispatch_source_set_event_handler")};
    expect(libdispatch && darwins.create && darwins.block_create && darwins.resume && darwins.set_event_handler,
           "the test reaches Darwin's dispatch calls beside the shims");
    control = ours;
    static const struct { const char *label; int concurrent; int late; } cases[] = {
        {"serial", 0, 0}, {"concurrent", 1, 0}, {"late", 1, 1},
    };
    for (unsigned index = 0; index < sizeof cases / sizeof cases[0]; index++) {
        char mine[64], theirs[64], before[64];
        scenario(&ours, cases[index].concurrent, cases[index].late, mine, sizeof mine);
        scenario(&darwins, cases[index].concurrent, cases[index].late, theirs, sizeof theirs);
        scenario(&control, cases[index].concurrent, cases[index].late, before, sizeof before);
        printf("%s: the shim %s; Darwin %s; the shims as they were %s\n", cases[index].label, mine, theirs, before);
        char what[300];
        if (cases[index].concurrent) {
            snprintf(what, sizeof what, "%s: the shim runs the handler alone as Darwin does (the shim %s, Darwin %s)",
                     cases[index].label, alone_of(mine), alone_of(theirs));
            expect(strcmp(alone_of(mine), alone_of(theirs)) == 0, what);
        } else {
            snprintf(what, sizeof what, "%s: the shim runs the queue in Darwin's order (the shim %s, Darwin %s)",
                     cases[index].label, mine, theirs);
            expect(strcmp(mine, theirs) == 0, what);
        }
#ifdef REVENANT_COMPAT_NO_STATE
        if (cases[index].late) {
            snprintf(what, sizeof what, "late: the shims without the records are what they were, which is not Darwin (%s against %s)",
                     alone_of(before), alone_of(theirs));
            expect(strcmp(alone_of(before), alone_of(theirs)) != 0, what);
        }
#endif
    }
    return fails != 0;
}
