#include <dispatch/dispatch.h>
#include <dlfcn.h>
#include <spawn.h>
#include <stdio.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

extern char **environ;

typedef void (*assert_f)(dispatch_queue_t);
typedef unsigned int (*qos_f)(dispatch_queue_t, int *);
typedef dispatch_queue_t (*create_f)(const char *, dispatch_queue_attr_t, dispatch_queue_t);
typedef dispatch_queue_attr_t (*qos_attr_f)(dispatch_queue_attr_t, unsigned int, int);

void dispatch_assert_queue_not(dispatch_queue_t) __asm("_dispatch_assert_queue_not$V2");
void dispatch_assert_queue_barrier(dispatch_queue_t);
unsigned int dispatch_queue_get_qos_class(dispatch_queue_t, int *);
dispatch_queue_t dispatch_queue_create_with_target(const char *, dispatch_queue_attr_t, dispatch_queue_t) __asm("_dispatch_queue_create_with_target$V2");
dispatch_queue_attr_t dispatch_queue_attr_make_with_qos_class(dispatch_queue_attr_t, unsigned int, int);
dispatch_queue_attr_t dispatch_queue_attr_make_initially_inactive(dispatch_queue_attr_t);
dispatch_queue_attr_t dispatch_queue_attr_make_with_autorelease_frequency(dispatch_queue_attr_t, unsigned long);

struct api {
    assert_f not_on, barrier;
    qos_f qos;
    create_f create;
    qos_attr_f qos_attr;
};

static struct api ours, darwins;
static char *self;
static int fails;

static void expect(int holds, const char *what)
{
    if (!holds) {
        printf("FAIL  %s\n", what);
        fails++;
    }
}

static void on_queue(dispatch_queue_t queue, void (^work)(void))
{
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    dispatch_async(queue, ^{ work(); dispatch_semaphore_signal(done); });
    dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
}

static void scenario(const struct api *api, const char *name)
{
    dispatch_queue_t serial = dispatch_queue_create("scenario.serial", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_t other = dispatch_queue_create("scenario.other", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_t target = dispatch_queue_create("scenario.target", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_t targeting = api->create("scenario.targeting", DISPATCH_QUEUE_SERIAL, target);
    if (!strcmp(name, "not-main-on-main"))
        api->not_on(dispatch_get_main_queue());
    else if (!strcmp(name, "not-main-off-main"))
        on_queue(serial, ^{ api->not_on(dispatch_get_main_queue()); });
    else if (!strcmp(name, "not-serial-inside"))
        on_queue(serial, ^{ api->not_on(serial); });
    else if (!strcmp(name, "not-serial-outside"))
        api->not_on(serial);
    else if (!strcmp(name, "not-other-inside"))
        on_queue(serial, ^{ api->not_on(other); });
    else if (!strcmp(name, "not-target-inside-targeting"))
        on_queue(targeting, ^{ api->not_on(target); });
    else if (!strcmp(name, "not-global-inside"))
        on_queue(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ api->not_on(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)); });
    else if (!strcmp(name, "barrier-inside"))
        on_queue(serial, ^{ api->barrier(serial); });
    else if (!strcmp(name, "barrier-outside"))
        api->barrier(serial);
}

static int ends(const char *program, const char *name, const char *side)
{
    fflush(stdout);
    char *argv[] = {(char *)program, (char *)name, (char *)side, NULL};
    pid_t child;
    if (posix_spawn(&child, program, NULL, NULL, argv, environ))
        return -1;
    int status = 0;
    waitpid(child, &status, 0);
    return WIFSIGNALED(status);
}

int main(int argc, char **argv)
{
    ours = (struct api){dispatch_assert_queue_not, dispatch_assert_queue_barrier, dispatch_queue_get_qos_class,
                        dispatch_queue_create_with_target, dispatch_queue_attr_make_with_qos_class};
    void *libdispatch = dlopen("/usr/lib/system/libdispatch.dylib", RTLD_LAZY | RTLD_LOCAL);
    darwins = (struct api){dlsym(libdispatch, "dispatch_assert_queue_not$V2"), dlsym(libdispatch, "dispatch_assert_queue_barrier"),
                           dlsym(libdispatch, "dispatch_queue_get_qos_class"), dlsym(libdispatch, "dispatch_queue_create_with_target$V2"),
                           dlsym(libdispatch, "dispatch_queue_attr_make_with_qos_class")};
    if (argc == 3) {
        scenario(!strcmp(argv[2], "shim") ? &ours : &darwins, argv[1]);
        return 0;
    }
    self = argv[0];
    expect(libdispatch && darwins.not_on && (void *)darwins.not_on != (void *)ours.not_on, "the test reaches Darwin's dispatch_assert_queue_not beside the shim");
    static const char *names[] = {"not-main-on-main", "not-main-off-main", "not-serial-inside", "not-serial-outside", "not-other-inside",
                                  "not-target-inside-targeting", "not-global-inside", "barrier-inside", "barrier-outside"};
    for (unsigned index = 0; index < sizeof names / sizeof names[0]; index++) {
        int mine = ends(self, names[index], "shim"), theirs = ends(self, names[index], "darwin");
        char what[200];
        snprintf(what, sizeof what, "%s: the shim ends the process as Darwin does (shim %d, Darwin %d)", names[index], mine, theirs);
        expect(mine == theirs, what);
    }

    dispatch_queue_t made = dispatch_queue_create("qos.made", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_t queues[] = {dispatch_get_main_queue(), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0),
                                 dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0),
                                 dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), made};
    for (unsigned index = 0; index < sizeof queues / sizeof queues[0]; index++) {
        int mine_relative = 7, theirs_relative = 7;
        unsigned int mine = ours.qos(queues[index], &mine_relative), theirs = darwins.qos(queues[index], &theirs_relative);
        char what[200];
        snprintf(what, sizeof what, "queue %u: the class is Darwin's (shim 0x%x/%d, Darwin 0x%x/%d)", index, mine, mine_relative, theirs, theirs_relative);
        expect(mine == theirs && mine_relative == theirs_relative, what);
    }
    expect(ours.qos(made, NULL) == 0, "a queue with no class answers none, and a null relative priority is allowed");

    expect(dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_CONCURRENT, 0x99, 0) == DISPATCH_QUEUE_CONCURRENT &&
           darwins.qos_attr(DISPATCH_QUEUE_CONCURRENT, 0x99, 0) == DISPATCH_QUEUE_CONCURRENT, "an invalid class answers the attribute given");
    dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_CONCURRENT, 0x19, -2);
    attr = dispatch_queue_attr_make_with_autorelease_frequency(attr, 1);
    attr = dispatch_queue_attr_make_initially_inactive(attr);
    dispatch_queue_t made_with = dispatch_queue_create("qos.attr", attr);
    __block int ran = 0;
    on_queue(made_with, ^{ ran = 1; });
    expect(ran == 1 && !strcmp(dispatch_queue_get_label(made_with), "qos.attr"),
           "a queue made from the attributes runs its blocks, active, under the label it was given");

    dispatch_queue_t target = dispatch_queue_create("target.q", DISPATCH_QUEUE_SERIAL);
    static char key;
    dispatch_queue_set_specific(target, &key, &key, NULL);
    for (int side = 0; side < 2; side++) {
        dispatch_queue_t targeting = (side ? darwins.create : ours.create)("targeting.q", DISPATCH_QUEUE_SERIAL, target);
        __block void *seen = NULL;
        on_queue(targeting, ^{ seen = dispatch_get_specific(&key); });
        char what[120];
        snprintf(what, sizeof what, "%s: a queue made with a target sees the target's specifics", side ? "Darwin" : "the shim");
        expect(seen == &key && !strcmp(dispatch_queue_get_label(targeting), "targeting.q"), what);
    }
    dispatch_queue_t untargeted = ours.create("untargeted.q", NULL, NULL);
    ran = 0;
    on_queue(untargeted, ^{ ran = 1; });
    expect(ran == 1, "a queue made with no target is an ordinary queue");
    return fails != 0;
}
