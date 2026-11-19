#pragma once
#include <pthread.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define XL_STATS_WINDOW_SLOTS 1024
#ifndef XL_STATS_FOLD_TICKS
#define XL_STATS_FOLD_TICKS 0x40000000u
#endif

struct xl_stats_slot {
    uintptr_t cls;
    uintptr_t sel;
    uint32_t count;
    uint64_t ticks;
};

struct xl_stats_note {
    uintptr_t cls;
    uintptr_t sel;
    uint32_t count;
    uint32_t ticks;
};

struct xl_stats_thread {
    struct xl_stats_thread *next;
    struct xl_stats_thread **link;
    volatile uint32_t messages;
    volatile uint32_t routing_ticks;
    uint32_t folded_messages;
    uint32_t folded_routing;
    uint32_t asked_routing;
    volatile uint32_t window_of[2];
    struct xl_stats_note window[2][XL_STATS_WINDOW_SLOTS];
};

static struct xl_stats_slot xl_stats_window[XL_STATS_WINDOW_SLOTS];
static pthread_mutex_t xl_stats_lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_once_t xl_stats_once = PTHREAD_ONCE_INIT;
static pthread_key_t xl_stats_key;
static struct xl_stats_thread *xl_stats_threads;
static volatile uint32_t xl_stats_window_number;
static uint32_t xl_stats_messages;
static uint64_t xl_stats_routing_ticks;

static inline unsigned xl_stats_window_start(uintptr_t cls, uintptr_t sel)
{
    return (unsigned)(((sel >> 2) ^ (cls >> 4)) * 2654435761u) % XL_STATS_WINDOW_SLOTS;
}

static inline void xl_stats_fold_locked(void)
{
    for (struct xl_stats_thread *thread = xl_stats_threads; thread; thread = thread->next) {
        uint32_t messages = thread->messages, routing = thread->routing_ticks;
        xl_stats_messages += messages - thread->folded_messages;
        xl_stats_routing_ticks += (uint32_t)(routing - thread->folded_routing);
        thread->folded_messages = messages;
        thread->folded_routing = routing;
    }
}

static inline void xl_stats_window_merge_locked(const struct xl_stats_note *notes)
{
    for (unsigned i = 0; i < XL_STATS_WINDOW_SLOTS; i++) {
        const struct xl_stats_note *note = &notes[i];
        uint32_t count = note->count;
        if (!count || !note->cls || !note->sel)
            continue;
        unsigned start = xl_stats_window_start(note->cls, note->sel);
        for (unsigned probe = 0; probe < XL_STATS_WINDOW_SLOTS; probe++) {
            struct xl_stats_slot *slot = &xl_stats_window[(start + probe) % XL_STATS_WINDOW_SLOTS];
            if (!slot->count) {
                slot->cls = note->cls;
                slot->sel = note->sel;
            }
            if (slot->cls == note->cls && slot->sel == note->sel) {
                slot->count += count;
                slot->ticks += note->ticks;
                break;
            }
        }
    }
}

static inline void xl_stats_window_close_locked(void)
{
    uint32_t closed = __atomic_fetch_add(&xl_stats_window_number, 1, __ATOMIC_SEQ_CST);
    for (struct xl_stats_thread *thread = xl_stats_threads; thread; thread = thread->next) {
        if (thread->window_of[closed & 1] == closed)
            xl_stats_window_merge_locked(thread->window[closed & 1]);
    }
}

static inline void xl_stats_thread_ended(void *value)
{
    struct xl_stats_thread *thread = value;
    pthread_mutex_lock(&xl_stats_lock);
    xl_stats_fold_locked();
    uint32_t number = xl_stats_window_number;
    if (thread->window_of[number & 1] == number)
        xl_stats_window_merge_locked(thread->window[number & 1]);
    *thread->link = thread->next;
    if (thread->next)
        thread->next->link = thread->link;
    pthread_mutex_unlock(&xl_stats_lock);
    free(thread);
}

static inline void xl_stats_key_make(void)
{
    pthread_key_create(&xl_stats_key, xl_stats_thread_ended);
}

static inline struct xl_stats_thread *xl_stats_mine(void)
{
    pthread_once(&xl_stats_once, xl_stats_key_make);
    struct xl_stats_thread *mine = pthread_getspecific(xl_stats_key);
    if (mine)
        return mine;
    mine = calloc(1, sizeof *mine);
    if (!mine)
        return NULL;
    pthread_mutex_lock(&xl_stats_lock);
    uint32_t number = xl_stats_window_number;
    mine->window_of[number & 1] = number;
    mine->window_of[~number & 1] = number + 1;
    mine->next = xl_stats_threads;
    mine->link = &xl_stats_threads;
    if (mine->next)
        mine->next->link = &mine->next;
    xl_stats_threads = mine;
    pthread_mutex_unlock(&xl_stats_lock);
    pthread_setspecific(xl_stats_key, mine);
    return mine;
}

static inline void xl_stats_window_note(struct xl_stats_thread *mine, uintptr_t cls, uintptr_t sel, uint32_t ticks)
{
    uint32_t number = xl_stats_window_number;
    struct xl_stats_note *notes = mine->window[number & 1];
    if (mine->window_of[number & 1] != number) {
        memset(notes, 0, sizeof mine->window[0]);
        mine->window_of[number & 1] = number;
    }
    unsigned start = xl_stats_window_start(cls, sel);
    for (unsigned probe = 0; probe < XL_STATS_WINDOW_SLOTS; probe++) {
        struct xl_stats_note *note = &notes[(start + probe) % XL_STATS_WINDOW_SLOTS];
        if (!note->count) {
            note->cls = cls;
            note->sel = sel;
        }
        if (note->cls == cls && note->sel == sel) {
            note->ticks += ticks;
            note->count++;
            return;
        }
    }
}

static inline void xl_stats_count(uintptr_t cls, uintptr_t sel, uint32_t ticks)
{
    struct xl_stats_thread *mine = xl_stats_mine();
    if (!mine)
        return;
    mine->routing_ticks += ticks;
    mine->messages++;
    xl_stats_window_note(mine, cls, sel, ticks);
    if (mine->routing_ticks - mine->asked_routing >= XL_STATS_FOLD_TICKS) {
        mine->asked_routing = mine->routing_ticks;
        pthread_mutex_lock(&xl_stats_lock);
        xl_stats_fold_locked();
        pthread_mutex_unlock(&xl_stats_lock);
    }
}
