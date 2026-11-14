#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <objc/message.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "xl_loader.h"

#define RACE_THREADS 4

static __unsafe_unretained id published[RACE_THREADS];
static volatile int violations;
static volatile int rounds_done;

struct race_arguments {
    __unsafe_unretained id runner;
    int index;
    int rounds;
};

static void *race_thread(void *argument)
{
    struct race_arguments *race = argument;
    for (int round = 0; round < race->rounds; round++) {
        @autoreleasepool {
            id first = ((id (*)(id, SEL))objc_msgSend)(race->runner, @selector(sharedObject));
            published[race->index] = first;
            __sync_synchronize();
            for (int other = 0; other < RACE_THREADS; other++) {
                __unsafe_unretained id seen = published[other];
                if (seen && seen != first)
                    __sync_fetch_and_add(&violations, 1);
            }
            id second = ((id (*)(id, SEL))objc_msgSend)(race->runner, @selector(sharedObject));
            if (second != first)
                __sync_fetch_and_add(&violations, 1);
            __sync_synchronize();
            published[race->index] = nil;
        }
        __sync_fetch_and_add(&rounds_done, 1);
    }
    return NULL;
}

static void race(id runner, int rounds)
{
    (void)((id (*)(id, SEL))objc_msgSend)(runner, @selector(sharedObject));
    pthread_t threads[RACE_THREADS];
    struct race_arguments arguments[RACE_THREADS];
    for (int index = 0; index < RACE_THREADS; index++) {
        arguments[index].runner = runner;
        arguments[index].index = index;
        arguments[index].rounds = rounds;
        pthread_create(&threads[index], NULL, race_thread, &arguments[index]);
    }
    for (int index = 0; index < RACE_THREADS; index++)
        pthread_join(threads[index], NULL);
    printf("%s proxy.race\n", violations == 0 && rounds_done == RACE_THREADS * rounds ? "ok" : "FAIL");
    if (violations || rounds_done != RACE_THREADS * rounds)
        printf("race violations=%d rounds=%d of %d\n", violations, rounds_done, RACE_THREADS * rounds);
}

static id shared_object(id runner)
{
    return ((id (*)(id, SEL))objc_msgSend)(runner, @selector(sharedObject));
}

static void weak_references(id runner)
{
    __weak id weak = nil;
    int alive = 0;
    @autoreleasepool {
        id proxy = shared_object(runner);
        weak = proxy;
        id strong = weak;
        alive = proxy != nil && strong == proxy && [proxy isEqual:proxy];
    }
    printf("%s proxy.weak.alive\n", alive ? "ok" : "FAIL");
    printf("%s proxy.weak.cleared\n", weak == nil ? "ok" : "FAIL");
    int recreated = 0;
    @autoreleasepool {
        id again = shared_object(runner);
        __weak id second = again;
        recreated = again != nil && second == again && [again isEqual:again];
    }
    printf("%s proxy.weak.recreated\n", recreated ? "ok" : "FAIL");
}

int main(int argc, char **argv)
{
    setbuf(stdout, NULL);
    if (argc < 4) {
        printf("FAIL usage\n");
        return 2;
    }
    xl_load_status reserved = xl_reserve(argv[1]);
    if (reserved != XL_LOAD_OK) {
        printf("FAIL reserve %d %s\n", (int)reserved, xl_load_error());
        return 1;
    }
    xl_load_status loaded = xl_load(argv[1]);
    if (loaded != XL_LOAD_OK) {
        printf("FAIL load %d %s\n", (int)loaded, xl_load_error());
        return 1;
    }
    void *handle = dlopen(argv[1], RTLD_NOW | RTLD_NOLOAD);
    void (*diagnostics)(void) = handle ? (void (*)(void))dlsym(handle, "xl_library_diagnostics") : NULL;
    if (diagnostics)
        diagnostics();
    id runner = nil;
    @autoreleasepool {
        Class cls = NSClassFromString([NSString stringWithUTF8String:argv[2]]);
        if (cls == Nil) {
            printf("FAIL class.absent %s\n", argv[2]);
            return 1;
        }
        runner = [[cls alloc] init];
        SEL selector = NSSelectorFromString([NSString stringWithUTF8String:argv[3]]);
        if (![runner respondsToSelector:selector]) {
            printf("FAIL selector.absent %s\n", argv[3]);
            return 1;
        }
        if (strcmp(argv[3], "stepProxyRace") == 0)
            race(runner, argc > 4 ? atoi(argv[4]) : 100000);
        else if (strcmp(argv[3], "stepProxyWeak") == 0)
            weak_references(runner);
        else
            ((void (*)(id, SEL))objc_msgSend)(runner, selector);
    }
    @autoreleasepool {
        SEL after = NSSelectorFromString([NSString stringWithFormat:@"%sAfter", argv[3]]);
        if ([runner respondsToSelector:after])
            ((void (*)(id, SEL))objc_msgSend)(runner, after);
    }
    printf("done\n");
    return 0;
}
