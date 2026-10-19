#include <Block.h>
#include <dispatch/dispatch.h>
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

typedef dispatch_block_t (*create_f)(unsigned long, dispatch_block_t);
typedef dispatch_block_t (*create_qos_f)(unsigned long, unsigned int, int, dispatch_block_t);
typedef void (*perform_f)(unsigned long, dispatch_block_t);
typedef intptr_t (*wait_f)(dispatch_block_t, dispatch_time_t);
typedef void (*notify_f)(dispatch_block_t, dispatch_queue_t, dispatch_block_t);
typedef void (*cancel_f)(dispatch_block_t);
typedef intptr_t (*testcancel_f)(dispatch_block_t);

dispatch_block_t dispatch_block_create(unsigned long, dispatch_block_t);
dispatch_block_t dispatch_block_create_with_qos_class(unsigned long, unsigned int, int, dispatch_block_t);
void dispatch_block_perform(unsigned long, dispatch_block_t);
intptr_t dispatch_block_wait(dispatch_block_t, dispatch_time_t);
void dispatch_block_notify(dispatch_block_t, dispatch_queue_t, dispatch_block_t);
void dispatch_block_cancel(dispatch_block_t);
intptr_t dispatch_block_testcancel(dispatch_block_t);

struct api {
    create_f create; create_qos_f create_qos; perform_f perform; wait_f wait; notify_f notify; cancel_f cancel;
    testcancel_f testcancel;
};

static int fails;
static int ran;
static int inside, alone, broken;

static void expect(int holds, const char *what)
{
    if (!holds) {
        printf("FAIL  %s\n", what);
        fails++;
    }
}

static char *scenario(const struct api *api, char *log, size_t size)
{
    dispatch_queue_t queue = dispatch_queue_create("scenario", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_t parallel = dispatch_queue_create("parallel", DISPATCH_QUEUE_CONCURRENT);
    size_t at = 0;
#define LOG(...) at += snprintf(log + at, size - at, __VA_ARGS__)

    ran = 0;
    dispatch_block_t work = api->create(0, ^{ __atomic_add_fetch(&ran, 1, __ATOMIC_SEQ_CST); });
    dispatch_async(queue, work);
    LOG("run:wait=%ld ran=%d cancelled=%ld;", (long)api->wait(work, DISPATCH_TIME_FOREVER), ran, (long)api->testcancel(work));
    Block_release(work);

    ran = 0;
    work = api->create(0, ^{ __atomic_add_fetch(&ran, 1, __ATOMIC_SEQ_CST); });
    api->cancel(work);
    LOG("cancel:test=%ld;", (long)api->testcancel(work));
    dispatch_async(queue, work);
    LOG("wait=%ld ran=%d;", (long)api->wait(work, DISPATCH_TIME_FOREVER), ran);
    Block_release(work);

    ran = 0;
    work = api->create(0, ^{ __atomic_add_fetch(&ran, 1, __ATOMIC_SEQ_CST); });
    LOG("timeout:wait=%d;", api->wait(work, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_MSEC)) != 0);
    dispatch_async(queue, work);
    LOG("again=%ld ran=%d;", (long)api->wait(work, DISPATCH_TIME_FOREVER), ran);
    Block_release(work);

    ran = 0;
    __block int notified = 0;
    __block int notices = 0;
    dispatch_semaphore_t told = dispatch_semaphore_create(0);
    work = api->create(0, ^{ __atomic_add_fetch(&ran, 1, __ATOMIC_SEQ_CST); });
    api->notify(work, parallel, ^{ notified = ran; __atomic_add_fetch(&notices, 1, __ATOMIC_SEQ_CST); dispatch_semaphore_signal(told); });
    dispatch_async(queue, work);
    LOG("notify:got=%d ran-at-notice=%d;", dispatch_semaphore_wait(told, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC)) == 0, notified);
    dispatch_barrier_sync(parallel, ^{ });
    LOG("notices=%d;", notices);
    Block_release(work);

    ran = inside = broken = 0;
    dispatch_group_t busy = dispatch_group_create();
    for (int index = 0; index < 6; index++) {
        dispatch_block_t hold = Block_copy(^{
            if (__atomic_load_n(&alone, __ATOMIC_SEQ_CST))
                __atomic_add_fetch(&broken, 1, __ATOMIC_SEQ_CST);
            __atomic_add_fetch(&inside, 1, __ATOMIC_SEQ_CST);
            usleep(40000);
            __atomic_sub_fetch(&inside, 1, __ATOMIC_SEQ_CST);
        });
        dispatch_group_async(busy, parallel, hold);
        Block_release(hold);
    }
    work = api->create(0, ^{ usleep(20000); __atomic_add_fetch(&ran, 1, __ATOMIC_SEQ_CST); });
    __block int barrier_notices = 0;
    dispatch_block_t notice = api->create(DISPATCH_BLOCK_BARRIER, ^{
        if (__atomic_load_n(&inside, __ATOMIC_SEQ_CST))
            __atomic_add_fetch(&broken, 1, __ATOMIC_SEQ_CST);
        __atomic_store_n(&alone, 1, __ATOMIC_SEQ_CST);
        usleep(20000);
        if (__atomic_load_n(&inside, __ATOMIC_SEQ_CST))
            __atomic_add_fetch(&broken, 1, __ATOMIC_SEQ_CST);
        __atomic_store_n(&alone, 0, __ATOMIC_SEQ_CST);
        __atomic_add_fetch(&barrier_notices, 1, __ATOMIC_SEQ_CST);
    });
    api->notify(work, parallel, notice);
    dispatch_async(queue, work);
    dispatch_group_wait(busy, DISPATCH_TIME_FOREVER);
    dispatch_barrier_sync(parallel, ^{ });
    LOG("barrier-notify:notices=%d broken=%d;", barrier_notices, broken);
    dispatch_release(busy);
    Block_release(notice);
    Block_release(work);

    ran = 0;
    api->perform(0, ^{ __atomic_add_fetch(&ran, 1, __ATOMIC_SEQ_CST); });
    LOG("perform:ran=%d;", ran);

    ran = 0;
    work = api->create(0, ^{ __atomic_add_fetch(&ran, 1, __ATOMIC_SEQ_CST); });
    work();
    work();
    LOG("direct:twice=%d;", ran);
    Block_release(work);

    dispatch_block_t some = ^{ };
    LOG("valid:flags=%d qos=%d rel=%d ok=", api->create(0x100, some) == NULL, api->create_qos(0, 0x99, 0, some) == NULL,
        api->create_qos(0, 0x21, -16, some) == NULL);
    dispatch_block_t fine = api->create_qos(0x20, 0x21, -3, some);
    LOG("%d;", fine != NULL);
    if (fine)
        Block_release(fine);
    fine = api->create_qos(0, 0x00, 0, some);
    LOG("unspecified=%d;", fine != NULL);
    if (fine)
        Block_release(fine);

    dispatch_semaphore_t left = dispatch_semaphore_create(0);
    work = api->create(0, ^{ });
    api->notify(work, parallel, ^{ dispatch_semaphore_signal(left); });
    Block_release(work);
    LOG("dispose:notified=%d;", dispatch_semaphore_wait(left, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC)) == 0);

    ran = 0;
    work = api->create(DISPATCH_BLOCK_BARRIER | DISPATCH_BLOCK_ENFORCE_QOS_CLASS, ^{ __atomic_add_fetch(&ran, 1, __ATOMIC_SEQ_CST); });
    dispatch_async(parallel, work);
    LOG("flags:wait=%ld ran=%d;", (long)api->wait(work, DISPATCH_TIME_FOREVER), ran);
    Block_release(work);

    ran = 0;
    dispatch_semaphore_t gate = dispatch_semaphore_create(0);
    dispatch_async(queue, ^{ dispatch_semaphore_wait(gate, DISPATCH_TIME_FOREVER); });
    work = api->create_qos(DISPATCH_BLOCK_ENFORCE_QOS_CLASS, 0x15, 0, ^{ __atomic_add_fetch(&ran, 1, __ATOMIC_SEQ_CST); });
    dispatch_async(queue, work);
    api->cancel(work);
    dispatch_semaphore_signal(gate);
    LOG("cancelled-queued:wait=%ld ran=%d test=%ld;", (long)api->wait(work, DISPATCH_TIME_FOREVER), ran, (long)api->testcancel(work));
    Block_release(work);
    dispatch_release(queue);
    dispatch_release(parallel);
    return log;
}

int main(void)
{
    struct api ours = {dispatch_block_create, dispatch_block_create_with_qos_class, dispatch_block_perform, dispatch_block_wait,
                       dispatch_block_notify, dispatch_block_cancel, dispatch_block_testcancel};
    void *libdispatch = dlopen("/usr/lib/system/libdispatch.dylib", RTLD_LAZY | RTLD_LOCAL);
    expect(libdispatch != NULL, "the test reaches Darwin's libdispatch beside the shim");
    struct api darwins = {dlsym(libdispatch, "dispatch_block_create"), dlsym(libdispatch, "dispatch_block_create_with_qos_class"),
                          dlsym(libdispatch, "dispatch_block_perform"), dlsym(libdispatch, "dispatch_block_wait"),
                          dlsym(libdispatch, "dispatch_block_notify"), dlsym(libdispatch, "dispatch_block_cancel"),
                          dlsym(libdispatch, "dispatch_block_testcancel")};
    expect(darwins.create && (void *)darwins.create != (void *)ours.create, "Darwin's dispatch_block_create is not the shim");
    char mine[2048], theirs[2048];
    scenario(&ours, mine, sizeof mine);
    scenario(&darwins, theirs, sizeof theirs);
    if (strcmp(mine, theirs)) {
        printf("FAIL  the shim and Darwin answer alike\n  shim:   %s\n  darwin: %s\n", mine, theirs);
        fails++;
    }
    return fails != 0;
}
