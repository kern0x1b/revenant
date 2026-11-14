#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "xl_proxy.h"

enum { THREADS = 4, GUESTS = 8, FIRST_CLASS = 0x10001, SECOND_CLASS = 0x10002 };

struct guest_object {
    uint64_t isa;
    atomic_long references;
};

static atomic_long retains;
static atomic_long releases;
static int failures;
static volatile int violations;

static void forbidden(const char *what)
{
    fprintf(stderr, "FAIL proxy.guest-imp: %s reached the shadow's guest implementation through a proxy\n", what);
    abort();
}

@interface Shadow : NSObject
- (uintptr_t)guestPointer;
@end

@implementation Shadow
- (id)retain
{
    forbidden("retain");
    return self;
}

- (oneway void)release
{
    forbidden("release");
}

- (id)autorelease
{
    forbidden("autorelease");
    return self;
}

- (NSUInteger)retainCount
{
    forbidden("retainCount");
    return 0;
}

- (BOOL)_tryRetain
{
    forbidden("_tryRetain");
    return NO;
}

- (BOOL)_isDeallocating
{
    forbidden("_isDeallocating");
    return NO;
}

- (BOOL)allowsWeakReference
{
    forbidden("allowsWeakReference");
    return YES;
}

- (BOOL)retainWeakReference
{
    forbidden("retainWeakReference");
    return YES;
}

- (uintptr_t)guestPointer
{
    return (uintptr_t)xl_self_out(self);
}
@end

@interface Other : Shadow
@end

@implementation Other
@end

Class xl_proxy_shadow_of(uintptr_t guest_class)
{
    if (guest_class == FIRST_CLASS)
        return [Shadow class];
    if (guest_class == SECOND_CLASS)
        return [Other class];
    return Nil;
}

void xl_proxy_guest_retain(uintptr_t guest)
{
    atomic_fetch_add(&((struct guest_object *)guest)->references, 1);
    atomic_fetch_add(&retains, 1);
}

void xl_proxy_guest_release(uintptr_t guest)
{
    atomic_fetch_sub(&((struct guest_object *)guest)->references, 1);
    atomic_fetch_add(&releases, 1);
}

static struct guest_object *guest_new(uint32_t class_id)
{
    struct guest_object *guest = calloc(1, sizeof *guest);
    guest->isa = class_id;
    return guest;
}

static long references(struct guest_object *guest)
{
    return atomic_load(&guest->references);
}

static void report(const char *name, int passed)
{
    printf("%s %s\n", passed ? "ok" : "FAIL", name);
    fflush(stdout);
    if (!passed)
        failures++;
}

static id volatile published[GUESTS][THREADS];

struct race {
    struct guest_object **guests;
    int index;
    int rounds;
};

static void *race_thread(void *argument)
{
    struct race *race = argument;
    for (int round = 0; round < race->rounds; round++) {
        @autoreleasepool {
            int which = (round + race->index) % GUESTS;
            struct guest_object *guest = race->guests[which];
            id first = (id)xl_proxy_in((uintptr_t)guest);
            published[which][race->index] = first;
            __sync_synchronize();
            for (int other = 0; other < THREADS; other++) {
                id seen = published[which][other];
                if (seen && seen != first)
                    __sync_fetch_and_add(&violations, 1);
            }
            id second = (id)xl_proxy_in((uintptr_t)guest);
            if (second != first || xl_proxy_out((uintptr_t)first) != (uintptr_t)guest)
                __sync_fetch_and_add(&violations, 1);
            __sync_synchronize();
            published[which][race->index] = nil;
        }
    }
    return NULL;
}

static void race(int rounds)
{
    struct guest_object *guests[GUESTS];
    for (int index = 0; index < GUESTS; index++)
        guests[index] = guest_new(FIRST_CLASS);
    pthread_t threads[THREADS];
    struct race arguments[THREADS];
    long before = atomic_load(&retains);
    for (int index = 0; index < THREADS; index++) {
        arguments[index].guests = guests;
        arguments[index].index = index;
        arguments[index].rounds = rounds;
        pthread_create(&threads[index], NULL, race_thread, &arguments[index]);
    }
    for (int index = 0; index < THREADS; index++)
        pthread_join(threads[index], NULL);
    long balanced = 1;
    for (int index = 0; index < GUESTS; index++)
        balanced = balanced && references(guests[index]) == 0;
    report("proxy.race.single", violations == 0);
    report("proxy.race.balanced", balanced && atomic_load(&retains) == atomic_load(&releases) && atomic_load(&retains) > before);
    printf("race violations=%d proxies=%ld rounds=%d\n", violations, atomic_load(&retains) - before, THREADS * rounds);
    for (int index = 0; index < GUESTS; index++)
        free(guests[index]);
}

int main(int argc, char **argv)
{
    setbuf(stdout, NULL);
    int rounds = argc > 1 ? atoi(argv[1]) : 100000;
    struct guest_object *first = guest_new(FIRST_CLASS);
    struct guest_object *second = guest_new(SECOND_CLASS);
    xl_proxy_note_class(FIRST_CLASS);
    xl_proxy_note_class(SECOND_CLASS);
    @autoreleasepool {
        id proxy = (id)xl_proxy_in((uintptr_t)first);
        report("proxy.in", proxy != nil);
        if (!proxy)
            return 1;
        report("proxy.shape", strncmp(class_getName(object_getClass(proxy)), "XLProxy.", 8) == 0 && [proxy class] == [Shadow class] &&
                                  [proxy isKindOfClass:[Shadow class]] && [proxy isKindOfClass:[NSObject class]] && ![proxy isKindOfClass:[Other class]]);
        id plain = [[[NSObject alloc] init] autorelease];
        report("proxy.roundtrip", xl_proxy_out((uintptr_t)proxy) == (uintptr_t)first && xl_self_out(proxy) == (uintptr_t)first &&
                                      [(Shadow *)proxy guestPointer] == (uintptr_t)first && xl_proxy_out((uintptr_t)plain) == 0 &&
                                      xl_self_out(plain) == (uint64_t)(uintptr_t)plain);
        report("proxy.identity", (id)xl_proxy_in((uintptr_t)first) == proxy && (id)xl_proxy_in((uintptr_t)second) != proxy);
        report("proxy.holds-guest", references(first) == 1 && references(second) == 1);
        [proxy retain];
        [proxy release];
        report("proxy.memory-selectors", references(first) == 1 && [proxy retainCount] >= 1);
        xl_proxy_note_class(FIRST_CLASS);
        report("proxy.renote", (id)xl_proxy_in((uintptr_t)first) == proxy && !strchr(class_getName(object_getClass(proxy)), '@'));
        report("proxy.unknown", xl_proxy_in((uintptr_t)guest_new(0x20000)) == 0 && xl_proxy_in(0) == 0 && xl_proxy_in(0x1000) == 0);
    }
    report("proxy.released", references(first) == 0 && references(second) == 0);
    __weak id weak = nil;
    @autoreleasepool {
        id proxy = (id)xl_proxy_in((uintptr_t)first);
        weak = proxy;
        id strong = weak;
        report("proxy.weak.alive", strong == proxy && weak != nil && references(first) == 1);
    }
    report("proxy.weak.cleared", weak == nil && references(first) == 0);
    @autoreleasepool {
        id proxy = (id)xl_proxy_in((uintptr_t)first);
        report("proxy.weak.recreated", proxy != nil && [(Shadow *)proxy guestPointer] == (uintptr_t)first && references(first) == 1);
    }
    report("proxy.weak.balanced", references(first) == 0);
    race(rounds);
    free(first);
    free(second);
    return failures ? 1 : 0;
}
