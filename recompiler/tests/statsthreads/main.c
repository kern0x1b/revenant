#include <stdio.h>
#include <unistd.h>
#include "xl_stats_threads.h"

#ifndef CONTROL
#define CONTROL 0
#endif
#define ONE_COUNTER 1

enum { WAVES = 20, THREADS = 4, MESSAGES = 200000, PAIRS = 64, LONG_THREADS = 2, LONG_MESSAGES = 64 };
#define LONG_TICKS 0x30000000u

#if CONTROL == ONE_COUNTER
static volatile uint32_t one_counter_messages;
static volatile uint64_t one_counter_ticks;
#endif

static void fail(const char *what, const char *detail, unsigned long long got, unsigned long long wanted)
{
    dprintf(2, "FAIL %s: %s (%llu, and %llu were sent)\n", what, detail, got, wanted);
    _exit(1);
}

static void count(uintptr_t cls, uintptr_t sel, uint32_t ticks)
{
#if CONTROL == ONE_COUNTER
    (void)cls;
    (void)sel;
    one_counter_ticks += ticks;
    one_counter_messages++;
#else
    xl_stats_count(cls, sel, ticks);
#endif
}

static void *sender(void *slot)
{
    unsigned thread = (unsigned)(uintptr_t)slot;
    for (unsigned index = 0; index < MESSAGES; index++) {
        unsigned pair = (index * 7 + thread) % PAIRS;
        count(0x1000 + pair * 16, 0x2000 + pair * 4, 1 + index % 7);
    }
    return NULL;
}

static void *long_sender(void *unused)
{
    (void)unused;
    for (unsigned index = 0; index < LONG_MESSAGES; index++)
        count(0x1000, 0x2000, LONG_TICKS);
    return NULL;
}

static volatile int reporting = 1;
static unsigned long long window_messages, window_ticks, windows;

static void close_window(void)
{
    pthread_mutex_lock(&xl_stats_lock);
    xl_stats_window_close_locked();
    for (unsigned index = 0; index < XL_STATS_WINDOW_SLOTS; index++) {
        const struct xl_stats_slot *slot = &xl_stats_window[index];
        if (!slot->count)
            continue;
        unsigned pair = (unsigned)(slot->cls - 0x1000) / 16;
        if (pair >= PAIRS || slot->sel != 0x2000 + pair * 4)
            fail("stats.window", "a window names a class and selector that no thread sent", slot->cls, slot->sel);
        window_messages += slot->count;
        window_ticks += slot->ticks;
    }
    memset(xl_stats_window, 0, sizeof xl_stats_window);
    windows++;
    pthread_mutex_unlock(&xl_stats_lock);
}

static void *reporter(void *unused)
{
    (void)unused;
    while (reporting) {
        usleep(200);
        close_window();
    }
    return NULL;
}

int main(void)
{
    alarm(120);
    unsigned long long sent = (unsigned long long)WAVES * THREADS * MESSAGES, ticks = 0;
    for (unsigned index = 0; index < MESSAGES; index++)
        ticks += 1 + index % 7;
    ticks *= (unsigned long long)WAVES * THREADS;

    pthread_t reports;
    pthread_create(&reports, NULL, reporter, NULL);
    for (unsigned wave = 0; wave < WAVES; wave++) {
        pthread_t threads[THREADS];
        for (uintptr_t index = 0; index < THREADS; index++)
            pthread_create(&threads[index], NULL, sender, (void *)index);
        for (unsigned index = 0; index < THREADS; index++)
            pthread_join(threads[index], NULL);
    }
    reporting = 0;
    pthread_join(reports, NULL);
    close_window();
    close_window();

#if CONTROL == ONE_COUNTER
    if (one_counter_messages != sent || one_counter_ticks != ticks)
        fail("stats.total", "the counters lost messages", one_counter_messages, sent);
#else
    pthread_mutex_lock(&xl_stats_lock);
    xl_stats_fold_locked();
    unsigned long long counted = xl_stats_messages, counted_ticks = xl_stats_routing_ticks;
    int left = xl_stats_threads != NULL;
    pthread_mutex_unlock(&xl_stats_lock);
    if (counted != sent)
        fail("stats.total", "the counters lost messages", counted, sent);
    if (counted_ticks != ticks)
        fail("stats.total", "the counters lost routing time", counted_ticks, ticks);
    if (left)
        fail("stats.threads", "a thread that ended is still in the list", 1, 0);
    unsigned long long slack = (unsigned long long)THREADS * (windows + WAVES);
    if (window_messages > sent || window_messages + slack < sent)
        fail("stats.window", "the windows together do not hold the messages, give or take the one a thread was counting when a window closed", window_messages, sent);
    if (window_ticks > ticks || window_ticks + slack * 7 < ticks)
        fail("stats.window", "the windows together do not hold the routing time", window_ticks, ticks);
#endif

    pthread_t threads[LONG_THREADS];
    for (unsigned index = 0; index < LONG_THREADS; index++)
        pthread_create(&threads[index], NULL, long_sender, NULL);
    for (unsigned index = 0; index < LONG_THREADS; index++)
        pthread_join(threads[index], NULL);
    unsigned long long long_ticks = (unsigned long long)LONG_THREADS * LONG_MESSAGES * LONG_TICKS;
#if CONTROL != ONE_COUNTER
    pthread_mutex_lock(&xl_stats_lock);
    xl_stats_fold_locked();
    unsigned long long after = xl_stats_routing_ticks - counted_ticks;
    pthread_mutex_unlock(&xl_stats_lock);
    if (after != long_ticks)
        fail("stats.wrap", "routing time that passes 32 bits on one thread was not all counted", after, long_ticks);
#endif
    printf("ok: %llu messages of %d threads at a time in %d waves were all counted with their time while %llu windows closed, the windows hold %llu of them, "
           "and %llu ticks on %d threads (32 bits passed %llu times) were all counted\n",
           sent, THREADS, WAVES, windows, window_messages, long_ticks, LONG_THREADS, long_ticks >> 32);
    return 0;
}
