#pragma once
#include <CoreFoundation/CoreFoundation.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

struct xl_shared_lock {
    pthread_rwlock_t lock;
};

struct xl_shared_table {
    CFMutableDictionaryRef entries;
    struct xl_shared_lock *lock;
};

#define XL_SHARED_LOCK_INITIALIZER {PTHREAD_RWLOCK_INITIALIZER}

static inline void xl_shared_failed(const char *what, int error)
{
    fprintf(stderr, "xlate: the lock of the runtime's tables could not be %s (error %d); going on would let two threads change one table\n", what, error);
    abort();
}

static inline void xl_shared_read_begin(struct xl_shared_lock *lock)
{
    int error = pthread_rwlock_rdlock(&lock->lock);
    if (error)
        xl_shared_failed("taken to read", error);
}

static inline void xl_shared_write_begin(struct xl_shared_lock *lock)
{
    int error = pthread_rwlock_wrlock(&lock->lock);
    if (error)
        xl_shared_failed("taken to write", error);
}

static inline void xl_shared_end(struct xl_shared_lock *lock)
{
    int error = pthread_rwlock_unlock(&lock->lock);
    if (error)
        xl_shared_failed("given back", error);
}

static inline struct xl_shared_table xl_shared_table_make(struct xl_shared_lock *lock, const CFDictionaryKeyCallBacks *keys)
{
    struct xl_shared_table table = {CFDictionaryCreateMutable(NULL, 0, keys, NULL), lock};
    return table;
}

static inline const void *xl_shared_held_get(const struct xl_shared_table *table, const void *key)
{
    return CFDictionaryGetValue(table->entries, key);
}

static inline void xl_shared_held_set(const struct xl_shared_table *table, const void *key, const void *value)
{
    CFDictionarySetValue(table->entries, key, value);
}

static inline void xl_shared_held_remove(const struct xl_shared_table *table, const void *key)
{
    CFDictionaryRemoveValue(table->entries, key);
}

static inline const void *xl_shared_get(const struct xl_shared_table *table, const void *key)
{
    xl_shared_read_begin(table->lock);
    const void *value = xl_shared_held_get(table, key);
    xl_shared_end(table->lock);
    return value;
}

static inline void xl_shared_set(const struct xl_shared_table *table, const void *key, const void *value)
{
    xl_shared_write_begin(table->lock);
    xl_shared_held_set(table, key, value);
    xl_shared_end(table->lock);
}

static inline const void *xl_shared_claim(const struct xl_shared_table *table, const void *key, const void *value)
{
    xl_shared_write_begin(table->lock);
    const void *held = xl_shared_held_get(table, key);
    if (!held) {
        xl_shared_held_set(table, key, value);
        held = value;
    }
    xl_shared_end(table->lock);
    return held;
}

static inline const void *xl_shared_claim_pair(const struct xl_shared_table *table, const void *key, const void *value,
                                               const struct xl_shared_table *reverse)
{
    xl_shared_write_begin(table->lock);
    const void *held = xl_shared_held_get(table, key);
    if (!held) {
        xl_shared_held_set(table, key, value);
        xl_shared_held_set(reverse, value, key);
        held = value;
    }
    xl_shared_end(table->lock);
    return held;
}
