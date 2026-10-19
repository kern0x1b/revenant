#ifndef REVENANT_DISPATCH_QUEUE_WIDTH_H
#define REVENANT_DISPATCH_QUEUE_WIDTH_H

#include <dispatch/dispatch.h>
#include <stdatomic.h>
#include <stdint.h>
#include "system_function.h"

#define REVENANT_QUEUE_WIDTH ((const void *)(uintptr_t)0x636861726f6e5157u)

enum {
    REVENANT_WIDTH_UNDECIDED = 0,
    REVENANT_WIDTH_SERIAL = 1,
    REVENANT_WIDTH_CONCURRENT = 2,
};

static _Atomic(uintptr_t) revenant_queue_get_specific;
static _Atomic(uintptr_t) revenant_queue_set_specific;

static inline void *revenant_width_function(_Atomic(uintptr_t) *slot, const char *name)
{
    uintptr_t found = atomic_load_explicit(slot, memory_order_relaxed);
    if (found == 0) {
        void *image = dlopen(REVENANT_LIBDISPATCH, RTLD_LAZY | RTLD_LOCAL | RTLD_NOLOAD);
        void *symbol = image ? dlsym(image, name) : NULL;
        found = symbol ? (uintptr_t)symbol : 1;
        atomic_store_explicit(slot, found, memory_order_relaxed);
    }
    return found == 1 ? NULL : (void *)found;
}

static inline void *revenant_queue_get_specific_call(void)
{
    return revenant_width_function(&revenant_queue_get_specific, "dispatch_get_specific");
}

static inline void *revenant_queue_set_specific_call(void)
{
    return revenant_width_function(&revenant_queue_set_specific, "dispatch_queue_set_specific");
}

static inline unsigned revenant_width_of_attribute(dispatch_queue_attr_t attr)
{
    if (attr == DISPATCH_QUEUE_SERIAL)
        return REVENANT_WIDTH_SERIAL;
    if (attr == DISPATCH_QUEUE_CONCURRENT)
        return REVENANT_WIDTH_CONCURRENT;
    return REVENANT_WIDTH_UNDECIDED;
}

static inline void revenant_queue_record_width(dispatch_queue_t queue, unsigned width)
{
#ifdef REVENANT_COMPAT_NO_STATE
    (void)queue;
    (void)width;
#else
    if (!queue || width == REVENANT_WIDTH_UNDECIDED)
        return;
    void (*set)(dispatch_queue_t, const void *, void *, dispatch_function_t) = revenant_queue_set_specific_call();
    if (set)
        set(queue, REVENANT_QUEUE_WIDTH, (void *)(uintptr_t)width, NULL);
#endif
}

static inline unsigned revenant_queue_width_here(void)
{
    void *(*get)(const void *) = revenant_queue_get_specific_call();
    if (!get)
        return REVENANT_WIDTH_UNDECIDED;
    return (unsigned)(uintptr_t)get(REVENANT_QUEUE_WIDTH);
}

#endif
