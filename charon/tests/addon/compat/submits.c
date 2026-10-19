#include <Block.h>
#include <dispatch/dispatch.h>
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

typedef dispatch_block_t (*create_f)(unsigned long, dispatch_block_t);
typedef void (*async_f)(dispatch_queue_t, dispatch_block_t);
typedef void (*group_async_f)(dispatch_group_t, dispatch_queue_t, dispatch_block_t);
typedef void (*after_f)(dispatch_time_t, dispatch_queue_t, dispatch_block_t);

dispatch_block_t dispatch_block_create(unsigned long, dispatch_block_t);
void charon_dispatch_async(dispatch_queue_t, dispatch_block_t);
void charon_dispatch_sync(dispatch_queue_t, dispatch_block_t);
void charon_dispatch_group_async(dispatch_group_t, dispatch_queue_t, dispatch_block_t);
void charon_dispatch_group_notify(dispatch_group_t, dispatch_queue_t, dispatch_block_t);
void charon_dispatch_after(dispatch_time_t, dispatch_queue_t, dispatch_block_t);

struct api {
    create_f create; async_f async; async_f sync; group_async_f group_async; group_async_f group_notify; after_f after;
};

static int fails;
static int inside, alone, broken, barriers;

static void expect(int holds, const char *what)
{
    if (!holds) {
        printf("FAIL  %s\n", what);
        fails++;
    }
}

static dispatch_block_t ordinary(void)
{
    return Block_copy(^{
        if (__atomic_load_n(&alone, __ATOMIC_SEQ_CST))
            __atomic_add_fetch(&broken, 1, __ATOMIC_SEQ_CST);
        __atomic_add_fetch(&inside, 1, __ATOMIC_SEQ_CST);
        usleep(20000);
        if (__atomic_load_n(&alone, __ATOMIC_SEQ_CST))
            __atomic_add_fetch(&broken, 1, __ATOMIC_SEQ_CST);
        __atomic_sub_fetch(&inside, 1, __ATOMIC_SEQ_CST);
    });
}

static dispatch_block_t barrier(const struct api *api, dispatch_semaphore_t done)
{
    return api->create(DISPATCH_BLOCK_BARRIER, ^{
        if (__atomic_load_n(&inside, __ATOMIC_SEQ_CST))
            __atomic_add_fetch(&broken, 1, __ATOMIC_SEQ_CST);
        __atomic_store_n(&alone, 1, __ATOMIC_SEQ_CST);
        usleep(40000);
        if (__atomic_load_n(&inside, __ATOMIC_SEQ_CST))
            __atomic_add_fetch(&broken, 1, __ATOMIC_SEQ_CST);
        __atomic_store_n(&alone, 0, __ATOMIC_SEQ_CST);
        __atomic_add_fetch(&barriers, 1, __ATOMIC_SEQ_CST);
        if (done)
            dispatch_semaphore_signal(done);
    });
}

static void around(dispatch_queue_t queue, dispatch_group_t all, int count)
{
    for (int index = 0; index < count; index++) {
        dispatch_block_t work = ordinary();
        dispatch_group_async(all, queue, work);
        Block_release(work);
    }
}

static char *scenario(const struct api *api, char *log, size_t size)
{
    dispatch_queue_t queue = dispatch_queue_create("barriers", DISPATCH_QUEUE_CONCURRENT);
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    size_t at = 0;
#define LOG(...) at += snprintf(log + at, size - at, __VA_ARGS__)
#define SETTLE(all) do { dispatch_group_wait(all, DISPATCH_TIME_FOREVER); dispatch_release(all); } while (0)

    broken = barriers = 0;
    dispatch_group_t all = dispatch_group_create();
    around(queue, all, 3);
    dispatch_block_t work = barrier(api, done);
    api->async(queue, work);
    around(queue, all, 3);
    dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
    SETTLE(all);
    LOG("async:ran=%d broken=%d;", barriers, broken);
    Block_release(work);

    broken = barriers = 0;
    all = dispatch_group_create();
    around(queue, all, 3);
    work = barrier(api, NULL);
    api->sync(queue, work);
    LOG("sync:ran-on-return=%d;", barriers);
    around(queue, all, 3);
    SETTLE(all);
    LOG("broken=%d;", broken);
    Block_release(work);

    broken = barriers = 0;
    all = dispatch_group_create();
    dispatch_group_t group = dispatch_group_create();
    around(queue, all, 3);
    work = barrier(api, NULL);
    api->group_async(group, queue, work);
    around(queue, all, 3);
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    LOG("group:ran-on-wait=%d;", barriers);
    SETTLE(all);
    LOG("broken=%d;", broken);
    dispatch_release(group);
    Block_release(work);

    broken = barriers = 0;
    all = dispatch_group_create();
    around(queue, all, 3);
    work = barrier(api, done);
    api->after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_MSEC), queue, work);
    usleep(30000);
    around(queue, all, 3);
    dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
    SETTLE(all);
    LOG("after:ran=%d broken=%d;", barriers, broken);
    Block_release(work);

    broken = barriers = 0;
    all = dispatch_group_create();
    group = dispatch_group_create();
    dispatch_group_enter(group);
    around(queue, all, 3);
    work = barrier(api, done);
    api->group_notify(group, queue, work);
    dispatch_group_leave(group);
    usleep(5000);
    around(queue, all, 3);
    dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
    SETTLE(all);
    LOG("notify:ran=%d broken=%d;", barriers, broken);
    dispatch_release(group);
    Block_release(work);

    dispatch_release(queue);
    return log;
}

int main(void)
{
#ifdef SUBMIT_PLAIN
    struct api ours = {dispatch_block_create, dispatch_async, dispatch_sync, dispatch_group_async, dispatch_group_notify, dispatch_after};
#else
    struct api ours = {dispatch_block_create, charon_dispatch_async, charon_dispatch_sync, charon_dispatch_group_async,
                       charon_dispatch_group_notify, charon_dispatch_after};
#endif
    void *libdispatch = dlopen("/usr/lib/system/libdispatch.dylib", RTLD_LAZY | RTLD_LOCAL);
    expect(libdispatch != NULL, "the test reaches Darwin's libdispatch beside the shim");
    struct api darwins = {dlsym(libdispatch, "dispatch_block_create"), dispatch_async, dispatch_sync, dispatch_group_async,
                          dispatch_group_notify, dispatch_after};
    expect(darwins.create && (void *)darwins.create != (void *)ours.create, "Darwin's dispatch_block_create is not the shim");
    char mine[1024], theirs[1024];
    scenario(&darwins, theirs, sizeof theirs);
    const char *alone_every_time = "async:ran=1 broken=0;sync:ran-on-return=1;broken=0;group:ran-on-wait=1;broken=0;"
                                   "after:ran=1 broken=0;notify:ran=1 broken=0;";
    if (strcmp(theirs, alone_every_time)) {
        printf("FAIL  Darwin keeps every barrier alone on its queue, or the scenario measures nothing: %s\n", theirs);
        fails++;
    }
    scenario(&ours, mine, sizeof mine);
    if (strcmp(mine, theirs)) {
        printf("FAIL  the shims submit a barrier block as Darwin does\n  shim:   %s\n  darwin: %s\n", mine, theirs);
        fails++;
    }
    return fails != 0;
}
