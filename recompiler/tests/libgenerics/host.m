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

static void check(const char *name, int passed)
{
    printf("%s host.%s\n", passed ? "ok" : "FAIL", name);
}

static int all_present(__unsafe_unretained id *items, unsigned count)
{
    for (unsigned index = 0; index < count; index++) {
        if (!items[index])
            return 0;
    }
    return 1;
}

static void dictionary_probe(id runner, const char *step)
{
    NSDictionary *table = ((id (*)(id, SEL))objc_msgSend)(runner, @selector(bridgedDictionary));
    @try {
        if (strcmp(step, "stepHostCount") == 0) {
            check("count", [table count] == 3);
        } else if (strcmp(step, "stepHostObject") == 0) {
            id key = [[table keyEnumerator] nextObject];
            check("object.found", key && [table objectForKey:key]);
            check("object.missing", [table objectForKey:@"absent-key-0123456789"] == nil);
        } else if (strcmp(step, "stepHostKeyEnumerator") == 0) {
            NSEnumerator *enumerator = [table keyEnumerator];
            int seen = 0;
            id each;
            while ((each = [enumerator nextObject]))
                seen++;
            check("keyenumerator", seen == 3);
        } else if (strcmp(step, "stepHostAllKeys") == 0) {
            NSArray *keys = [table allKeys];
            __unsafe_unretained id items[3] = {nil, nil, nil};
            check("allkeys", [keys count] == 3 && ([keys getObjects:items range:NSMakeRange(0, 3)], all_present(items, 3)));
        } else if (strcmp(step, "stepHostAllValues") == 0) {
            NSArray *values = [table allValues];
            __unsafe_unretained id items[3] = {nil, nil, nil};
            check("allvalues", [values count] == 3 && ([values getObjects:items range:NSMakeRange(0, 3)], all_present(items, 3)));
        } else if (strcmp(step, "stepHostGetObjects") == 0) {
            __unsafe_unretained id keys[3] = {nil, nil, nil};
            __unsafe_unretained id objects[3] = {nil, nil, nil};
            [table getObjects:objects andKeys:keys count:3];
            check("getobjects", all_present(keys, 3) && all_present(objects, 3) && keys[0] != keys[1] && keys[1] != keys[2] && keys[0] != keys[2]);
        } else if (strcmp(step, "stepHostFast") == 0) {
            int seen = 0;
            for (id each in table) {
                if (each)
                    seen++;
            }
            check("fastenumeration", seen == 3);
        } else if (strcmp(step, "stepHostEnumerate") == 0) {
            __block int seen = 0;
            [table enumerateKeysAndObjectsUsingBlock:^(id each_key, id each_object, BOOL *stop) {
                if (each_key && each_object)
                    seen++;
            }];
            check("enumerate", seen == 3);
        } else {
            printf("FAIL host.step.absent %s\n", step);
        }
    } @catch (NSException *exception) {
        printf("note exception %s: %s\n", [[exception name] UTF8String], [[exception reason] UTF8String]);
        printf("FAIL host.%s\n", step + 8);
    }
}

static void sequence_probe(id runner)
{
    id sequence = ((id (*)(id, SEL))objc_msgSend)(runner, @selector(fastSequence));
    @try {
        NSFastEnumerationState state;
        memset(&state, 0, sizeof state);
        __unsafe_unretained id buffer[16];
        NSUInteger total = 0;
        NSUInteger batches = 0;
        int firsts_ok = 0, items_ok = 1, mutations_ok = 1;
        NSUInteger count;
        while ((count = [sequence countByEnumeratingWithState:&state objects:buffer count:16]) > 0) {
            if (batches == 0)
                firsts_ok = count == 16 && state.state == 16;
            batches++;
            total += count;
            if (!state.itemsPtr)
                items_ok = 0;
            for (NSUInteger index = 0; state.itemsPtr && index < count; index++) {
                if (!state.itemsPtr[index] || (index > 0 && state.itemsPtr[index] == state.itemsPtr[index - 1]))
                    items_ok = 0;
            }
            if (state.mutationsPtr != &state.extra[0] || *state.mutationsPtr != state.extra[0])
                mutations_ok = 0;
        }
        check("sequence.batch", firsts_ok && total == 40 && batches == 3);
        check("sequence.items", items_ok);
        check("sequence.mutations", mutations_ok && batches > 0);
        int seen = 0;
        for (id each in sequence) {
            if (each)
                seen++;
        }
        check("sequence.forin", seen == 40);
    } @catch (NSException *exception) {
        printf("note exception %s: %s\n", [[exception name] UTF8String], [[exception reason] UTF8String]);
        printf("FAIL host.sequence\n");
    }
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
        int in_host = strncmp(argv[3], "stepHost", 8) == 0;
        if (!in_host && ![runner respondsToSelector:selector]) {
            printf("FAIL selector.absent %s\n", argv[3]);
            return 1;
        }
        if (strcmp(argv[3], "stepHostSequence") == 0)
            sequence_probe(runner);
        else if (in_host)
            dictionary_probe(runner, argv[3]);
        else if (strcmp(argv[3], "stepProxyRace") == 0)
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
