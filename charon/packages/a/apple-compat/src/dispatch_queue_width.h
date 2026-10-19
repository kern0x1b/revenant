#ifndef CHARON_DISPATCH_QUEUE_WIDTH_H
#define CHARON_DISPATCH_QUEUE_WIDTH_H

#include <dispatch/dispatch.h>
#include <stdatomic.h>
#include <stdint.h>
#include "system_function.h"

/* How wide a queue is, kept on the queue itself as a specific under a key of this package's own, so
   that dispatch_get_specific answers it from whatever queue a block is running on - which is how a
   source's event handler learns the width of the queue the source runs it on, with no record of the
   source's target to go stale on a later dispatch_set_target_queue.

   The two calls this needs arrived in iOS 5 (dispatch_get_specific and dispatch_queue_set_specific are
   in the export trie of the 5.1.1, 6.0, 6.1.3 and 9.3.6 caches and not in 4.3's), so they are looked
   up in libdispatch rather than called: a call to one of them from a 4.3 image would be an import
   that release does not export. Where they are absent nothing is recorded and nothing is read, and
   every shim that asks falls back on what it did before.

   DISPATCH_QUEUE_SERIAL is NULL and DISPATCH_QUEUE_CONCURRENT is
   DISPATCH_GLOBAL_OBJECT(dispatch_queue_attr_t, _dispatch_queue_attr_concurrent) with the structure
   DISPATCH_EXPORT (iPhoneOS 16.4 SDK dispatch/queue.h:687 and :711 with :717), and the structure is
   exported by the 4.3, 5.1.1, 6.0, 6.1.3 and 9.3.6 caches, so "which of the two is this" is one
   pointer comparison. An attribute made from one of them (dispatch_queue_attr_make_with_qos_class,
   iOS 8) is a structure of this package's release's own making and no call names its width, so a
   queue made from one is recorded as undecided and the shims keep the answer they had. */

#define CHARON_QUEUE_WIDTH ((const void *)(uintptr_t)0x636861726f6e5157u) /* "charonQW" */

enum {
    CHARON_WIDTH_UNDECIDED = 0,
    CHARON_WIDTH_SERIAL = 1,
    CHARON_WIDTH_CONCURRENT = 2,
};

static _Atomic(uintptr_t) charon_queue_get_specific;
static _Atomic(uintptr_t) charon_queue_set_specific;

/* The two calls, looked up in libdispatch itself and not through system_function.h's CHARON_COMPAT_SYSTEM
   switch: that switch means "compile the shim alone, for a test on a system that has the call", and these two
   calls have to be the system's in that mode too, since they are how the width is recorded and read and a
   shim that recorded nothing would answer nothing. RTLD_NOLOAD opens the library only if it is already in
   the process, so this asks the release's own libdispatch and never loads one. */
static inline void *charon_width_function(_Atomic(uintptr_t) *slot, const char *name)
{
    uintptr_t found = atomic_load_explicit(slot, memory_order_relaxed);
    if (found == 0) {
        void *image = dlopen(CHARON_LIBDISPATCH, RTLD_LAZY | RTLD_LOCAL | RTLD_NOLOAD);
        void *symbol = image ? dlsym(image, name) : NULL;
        found = symbol ? (uintptr_t)symbol : 1;
        atomic_store_explicit(slot, found, memory_order_relaxed);
    }
    return found == 1 ? NULL : (void *)found;
}

static inline void *charon_queue_get_specific_call(void)
{
    return charon_width_function(&charon_queue_get_specific, "dispatch_get_specific");
}

static inline void *charon_queue_set_specific_call(void)
{
    return charon_width_function(&charon_queue_set_specific, "dispatch_queue_set_specific");
}

static inline unsigned charon_width_of_attribute(dispatch_queue_attr_t attr)
{
    if (attr == DISPATCH_QUEUE_SERIAL)
        return CHARON_WIDTH_SERIAL;
    if (attr == DISPATCH_QUEUE_CONCURRENT)
        return CHARON_WIDTH_CONCURRENT;
    return CHARON_WIDTH_UNDECIDED;
}

/* CHARON_COMPAT_NO_STATE=1 compiles the shims without either record, which is what they did before the
   records existed and what tests/compat_test.py's control build is: the host differential has to see
   that build differ from Darwin on a serial target queue, or the records are not what answers it.
   system_function.h's CHARON_COMPAT_SYSTEM is the same kind of switch, for the same reason. */
static inline void charon_queue_record_width(dispatch_queue_t queue, unsigned width)
{
#ifdef CHARON_COMPAT_NO_STATE
    (void)queue;
    (void)width;
#else
    if (!queue || width == CHARON_WIDTH_UNDECIDED)
        return;
    void (*set)(dispatch_queue_t, const void *, void *, dispatch_function_t) = charon_queue_set_specific_call();
    if (set)
        set(queue, CHARON_QUEUE_WIDTH, (void *)(uintptr_t)width, NULL);
#endif
}

/* The width of the queue this block is running on, or CHARON_WIDTH_UNDECIDED where the release
   cannot say or nothing was recorded for it. */
static inline unsigned charon_queue_width_here(void)
{
    void *(*get)(const void *) = charon_queue_get_specific_call();
    if (!get)
        return CHARON_WIDTH_UNDECIDED;
    return (unsigned)(uintptr_t)get(CHARON_QUEUE_WIDTH);
}

#endif
