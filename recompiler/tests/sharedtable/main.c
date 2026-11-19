#include <sched.h>
#include <string.h>
#include <unistd.h>
#include "xl_shared_table.h"

#ifndef CONTROL
#define CONTROL 0
#endif

#define UNLOCKED 1
#define NO_SECOND_LOOK 2
#define SPLIT_LOOKUP 3

enum { SENDERS = 4, REGISTRARS = 2, CLASSES = 2000, VARIANTS = 512, TWINS = 256, RACERS = 4, ROUNDS = 300 };

struct watch {
    volatile int32_t readers;
    volatile int32_t writers;
    volatile int32_t together;
};

static struct watch class_watch, variant_watch;
static __thread struct watch *watching;
static __thread int writing;
static __thread int pauses;

static void fail(const char *what, const char *detail)
{
    dprintf(2, "FAIL %s: %s\n", what, detail);
    _exit(1);
}

static CFHashCode inside(const void *key)
{
    struct watch *watch = watching;
    if (writing) {
        if (__sync_add_and_fetch(&watch->writers, 1) != 1)
            fail("shared.exclusion", "two threads were changing the tables of one lock at once");
        if (watch->readers)
            fail("shared.exclusion", "a thread began to change a table while another was reading it");
        if (pauses) {
            pauses--;
            usleep(20);
        }
        if (watch->readers)
            fail("shared.exclusion", "a thread read a table while another was changing it");
        __sync_sub_and_fetch(&watch->writers, 1);
    } else {
        if (__sync_add_and_fetch(&watch->readers, 1) > 1)
            __sync_add_and_fetch(&watch->together, 1);
        if (watch->writers)
            fail("shared.exclusion", "a thread began to read a table while another was changing it");
        if (pauses) {
            pauses--;
            sched_yield();
        }
        if (watch->writers)
            fail("shared.exclusion", "a thread changed a table while another was reading it");
        __sync_sub_and_fetch(&watch->readers, 1);
    }
    return (CFHashCode)((uintptr_t)key * 2654435761u);
}

static const CFDictionaryKeyCallBacks watched_keys = {0, NULL, NULL, NULL, NULL, inside};

static struct xl_shared_lock class_lock = XL_SHARED_LOCK_INITIALIZER;
static struct xl_shared_lock variant_lock = XL_SHARED_LOCK_INITIALIZER;
static struct xl_shared_table guest_to_host, host_to_guest, unbuilt, imps, host_twin, twin_host, variants, claims, pairs, pairs_back;

static void as(struct watch *watch, int write)
{
    watching = watch;
    writing = write;
    pauses = 1;
}

static const void *word(uintptr_t value)
{
    return (const void *)value;
}

static const void *get(const struct xl_shared_table *table, struct watch *watch, uintptr_t key)
{
    as(watch, 0);
#if CONTROL == UNLOCKED
    return CFDictionaryGetValue(table->entries, word(key));
#else
    return xl_shared_get(table, word(key));
#endif
}

static void set(const struct xl_shared_table *table, struct watch *watch, uintptr_t key, uintptr_t value)
{
    as(watch, 1);
#if CONTROL == UNLOCKED
    CFDictionaryGetValue(table->entries, word(key));
#else
    xl_shared_set(table, word(key), word(value));
#endif
}

static uintptr_t claim(const struct xl_shared_table *table, struct watch *watch, uintptr_t key, uintptr_t value)
{
#if CONTROL == UNLOCKED
    as(watch, 1);
    CFDictionaryGetValue(table->entries, word(key));
    return value;
#elif CONTROL == NO_SECOND_LOOK
    uintptr_t held = (uintptr_t)get(table, watch, key);
    if (!held) {
        set(table, watch, key, value);
        held = value;
    }
    return held;
#else
    as(watch, 1);
    return (uintptr_t)xl_shared_claim(table, word(key), word(value));
#endif
}

static uintptr_t claim_pair(const struct xl_shared_table *table, struct watch *watch, uintptr_t key, uintptr_t value,
                            const struct xl_shared_table *reverse)
{
#if CONTROL == UNLOCKED
    as(watch, 1);
    CFDictionaryGetValue(table->entries, word(key));
    CFDictionaryGetValue(reverse->entries, word(value));
    return value;
#elif CONTROL == NO_SECOND_LOOK
    uintptr_t held = (uintptr_t)get(table, watch, key);
    if (!held) {
        as(watch, 1);
        xl_shared_write_begin(table->lock);
        xl_shared_held_set(table, word(key), word(value));
        xl_shared_held_set(reverse, word(value), word(key));
        xl_shared_end(table->lock);
        held = value;
    }
    return held;
#else
    as(watch, 1);
    return (uintptr_t)xl_shared_claim_pair(table, word(key), word(value), reverse);
#endif
}

static uintptr_t class_key(unsigned number)
{
    return (uintptr_t)number * 16;
}

static uintptr_t shadow_of(unsigned number)
{
    return 0x40000000u + (uintptr_t)number * 16;
}

static uintptr_t variant_of(unsigned number)
{
    return 0x20000000u + (uintptr_t)number * 8;
}

static void lookup_class(unsigned number, uintptr_t *shadow, uintptr_t *owner)
{
    uintptr_t key = class_key(number);
#if CONTROL == UNLOCKED
    as(&class_watch, 0);
    *shadow = (uintptr_t)CFDictionaryGetValue(guest_to_host.entries, word(key));
    *owner = (uintptr_t)CFDictionaryGetValue(unbuilt.entries, word(key));
#elif CONTROL == SPLIT_LOOKUP
    *shadow = (uintptr_t)get(&guest_to_host, &class_watch, key);
    *owner = (uintptr_t)get(&unbuilt, &class_watch, key);
#else
    as(&class_watch, 0);
    xl_shared_read_begin(&class_lock);
    *shadow = (uintptr_t)xl_shared_held_get(&guest_to_host, word(key));
    *owner = (uintptr_t)xl_shared_held_get(&unbuilt, word(key));
    xl_shared_end(&class_lock);
#endif
}

static void register_class(unsigned number)
{
    uintptr_t key = class_key(number);
    as(&class_watch, 1);
#if CONTROL == UNLOCKED
    CFDictionaryGetValue(guest_to_host.entries, word(key));
    CFDictionaryGetValue(host_to_guest.entries, word(shadow_of(number)));
    CFDictionaryGetValue(unbuilt.entries, word(key));
#else
    xl_shared_write_begin(&class_lock);
    xl_shared_held_set(&guest_to_host, word(key), word(shadow_of(number)));
    xl_shared_held_set(&host_to_guest, word(shadow_of(number)), word(key));
    xl_shared_held_remove(&unbuilt, word(key));
    xl_shared_end(&class_lock);
#endif
    set(&imps, &class_watch, key, shadow_of(number) + 4);
}

static volatile int32_t next_class;
static volatile int32_t registrars_left = REGISTRARS;
static volatile int64_t messages;

static void *registrar(void *unused)
{
    (void)unused;
    for (;;) {
        int32_t number = __sync_add_and_fetch(&next_class, 1);
        if (number > CLASSES)
            break;
        register_class((unsigned)number);
    }
    __sync_sub_and_fetch(&registrars_left, 1);
    return NULL;
}

static void *sender(void *slot)
{
    unsigned thread = (unsigned)(uintptr_t)slot;
    uint32_t seed = 0x9e3779b9u * (thread + 1);
    int64_t sent = 0;
    unsigned tail = 2000;
    while (registrars_left || tail--) {
        seed ^= seed << 13;
        seed ^= seed >> 17;
        seed ^= seed << 5;
        int32_t front = next_class;
        unsigned number = (seed & 1) ? (unsigned)front + ((seed >> 1) & 3) : 1 + (seed >> 8) % CLASSES;
        if (number < 1 || number > CLASSES)
            number = CLASSES;
        uintptr_t shadow, owner;
        lookup_class(number, &shadow, &owner);
#if CONTROL != UNLOCKED
        if (!shadow == !owner)
            fail("shared.atomic", shadow ? "one look at a class found it both built and waiting to be built"
                                         : "one look at a class found it neither built nor waiting to be built");
        if (shadow && shadow != shadow_of(number))
            fail("shared.value", "a class was found with another class's shadow");
#endif
        uintptr_t imp = (uintptr_t)get(&imps, &class_watch, class_key(number));
        if (imp && imp != shadow_of(number) + 4)
            fail("shared.value", "a method was found with another class's function");
        unsigned variant = 1 + (seed >> 12) % VARIANTS;
        uintptr_t cached = (uintptr_t)get(&variants, &variant_watch, variant * 4);
        if (!cached)
            cached = claim(&variants, &variant_watch, variant * 4, variant_of(variant));
        if (cached != variant_of(variant))
            fail("shared.value", "the variant cache answered with another method's variant");
        unsigned host = 1 + (seed >> 20) % TWINS;
        uintptr_t twin = (uintptr_t)get(&host_twin, &class_watch, host * 16);
        if (!twin)
            twin = claim_pair(&host_twin, &class_watch, host * 16, ((uintptr_t)(thread + 1) << 24) | (host * 16), &twin_host);
#if CONTROL != UNLOCKED
        if ((uintptr_t)get(&twin_host, &class_watch, twin) != host * 16)
            fail("shared.pair", "the twin of a host class does not lead back to it");
#endif
        sent++;
    }
    __sync_add_and_fetch(&messages, sent);
    return NULL;
}

static volatile int32_t round_now, round_done;
static uintptr_t won[RACERS][ROUNDS + 1], paired[RACERS][ROUNDS + 1];

static void *racer(void *slot)
{
    unsigned thread = (unsigned)(uintptr_t)slot;
    for (int32_t round = 1; round <= ROUNDS; round++) {
        while (round_now != round)
            sched_yield();
        uintptr_t key = (uintptr_t)round * 16;
        uintptr_t mine = ((uintptr_t)(thread + 1) << 24) | key;
        uintptr_t held = (uintptr_t)get(&claims, &variant_watch, key);
        won[thread][round] = held ? held : claim(&claims, &variant_watch, key, mine);
        held = (uintptr_t)get(&pairs, &class_watch, key);
        paired[thread][round] = held ? held : claim_pair(&pairs, &class_watch, key, mine, &pairs_back);
        __sync_add_and_fetch(&round_done, 1);
    }
    return NULL;
}

static struct xl_shared_table watched(struct xl_shared_lock *lock)
{
    struct xl_shared_table table = xl_shared_table_make(lock, &watched_keys);
    watching = &class_watch;
    writing = 0;
    pauses = 0;
    CFDictionarySetValue(table.entries, word(0x7ffffff0u), word(1));
    return table;
}

int main(void)
{
    alarm(120);
    guest_to_host = watched(&class_lock);
    host_to_guest = watched(&class_lock);
    unbuilt = watched(&class_lock);
    imps = watched(&class_lock);
    host_twin = watched(&class_lock);
    twin_host = watched(&class_lock);
    pairs = watched(&class_lock);
    pairs_back = watched(&class_lock);
    variants = watched(&variant_lock);
    claims = watched(&variant_lock);
    for (unsigned number = 1; number <= CLASSES; number++)
        CFDictionarySetValue(unbuilt.entries, word(class_key(number)), word(class_key(number)));

    pthread_t senders[SENDERS], registrars[REGISTRARS], racers[RACERS];
    for (uintptr_t index = 0; index < SENDERS; index++)
        pthread_create(&senders[index], NULL, sender, (void *)index);
    for (uintptr_t index = 0; index < REGISTRARS; index++)
        pthread_create(&registrars[index], NULL, registrar, NULL);
    for (unsigned index = 0; index < REGISTRARS; index++)
        pthread_join(registrars[index], NULL);
    for (unsigned index = 0; index < SENDERS; index++)
        pthread_join(senders[index], NULL);

    for (uintptr_t index = 0; index < RACERS; index++)
        pthread_create(&racers[index], NULL, racer, (void *)index);
    for (int32_t round = 1; round <= ROUNDS; round++) {
        round_done = 0;
        round_now = round;
        while (round_done != RACERS)
            sched_yield();
    }
    for (unsigned index = 0; index < RACERS; index++)
        pthread_join(racers[index], NULL);

    pauses = 0;
    for (int32_t round = 1; round <= ROUNDS; round++) {
        uintptr_t key = (uintptr_t)round * 16;
        for (unsigned index = 1; index < RACERS; index++) {
            if (won[index][round] != won[0][round] || paired[index][round] != paired[0][round])
                fail("shared.claim", "two threads that raced to put one key in each believe their own value is the one in the table");
        }
        if ((uintptr_t)CFDictionaryGetValue(claims.entries, word(key)) != won[0][round])
            fail("shared.claim", "the value every thread was told is not the one in the table");
        if ((uintptr_t)CFDictionaryGetValue(pairs.entries, word(key)) != paired[0][round] ||
            (uintptr_t)CFDictionaryGetValue(pairs_back.entries, word(paired[0][round])) != key)
            fail("shared.claim", "the two tables of a pair do not lead to each other");
    }
    if (CFDictionaryGetCount(pairs_back.entries) != ROUNDS + 1)
        fail("shared.claim", "the table that leads back holds the values of threads that lost the race");
    for (unsigned number = 1; number <= CLASSES; number++) {
        uintptr_t key = class_key(number);
        if ((uintptr_t)CFDictionaryGetValue(guest_to_host.entries, word(key)) != shadow_of(number) ||
            (uintptr_t)CFDictionaryGetValue(host_to_guest.entries, word(shadow_of(number))) != key ||
            CFDictionaryGetValue(unbuilt.entries, word(key)))
            fail("shared.value", "a registered class is not in the tables as it was registered");
    }
    if (CFDictionaryGetCount(twin_host.entries) != CFDictionaryGetCount(host_twin.entries))
        fail("shared.pair", "the table that leads back from the twins holds twins that lost the race");
    if (!class_watch.together)
        fail("shared.readers", "no two threads ever read the tables at the same time: the read side shuts readers out");
    printf("ok: %lld messages on %d threads while %d threads registered %d classes, %d times two threads read at once and none read during a change; "
           "%d keys raced for by %d threads each got one value\n",
           (long long)messages, SENDERS, REGISTRARS, CLASSES, (int)class_watch.together, ROUNDS, RACERS);
    return 0;
}
