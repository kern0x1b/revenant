#ifndef CHARON_DISPATCH_SOURCE_STATE_H
#define CHARON_DISPATCH_SOURCE_STATE_H

#include <dispatch/dispatch.h>
#include <objc/runtime.h>
#include <pthread.h>
#include <stdint.h>

/* What the shims that answer for a barrier source below iOS 10 know about a queue and about a source,
   and where each of them keeps it. A dispatch object is an Objective-C object from iOS 6 on, so what
   is known about a source is an associated object on it, which goes when the object does; what is
   known about a queue is a specific under a key of this package's own, which dispatch_get_specific
   answers from the queue a block is running on. Both keys are a value cast to a pointer rather than
   the address of a variable, because every shim that reads or writes one is its own object file and
   two addresses of two static variables would be two keys.

   Nothing here is a decision: what a shim does with what it finds is in the shim. */

#define CHARON_SOURCE_ACTIVATED ((const void *)(uintptr_t)0x636861726f6e4143u) /* "charonAC" */

/* dispatch_object_t is a transparent union of the object kinds (SDK 16.4 dispatch/object.h:95), which
   cannot be cast; this is the one member every kind is a pointer to. */
static inline void *charon_object_pointer(dispatch_object_t object)
{
    union {
        dispatch_object_t object;
        void *pointer;
    } same;
    same.object = object;
    return same.pointer;
}

/* Whether a dispatch object is one the Objective-C runtime can carry an association. Measured: the
   dispatch objects of 6.1.3 are OS_dispatch_source and its subclasses, and 4.3's are not objects at
   all (dispatch_activate.c walks the same chain for the same reason). */
static inline int charon_dispatch_is_object(dispatch_object_t object)
{
    static int checked;
    static Class source;
    if (!checked) {
        source = objc_getClass("OS_dispatch_source");
        checked = 1;
    }
    if (!source)
        return 0;
    Class kind = object_getClass((id)charon_object_pointer(object));
    while (kind && kind != source)
        kind = class_getSuperclass(kind);
    return kind != NULL;
}

/* Whether the source has been activated, which below iOS 10 is the one dispatch_resume that starts
   it: a source is made suspended and waits for that, and libdispatch-703 reads the event handler's
   DISPATCH_BLOCK_BARRIER once, in _dispatch_source_finalize_activation, which that resume reaches.
   A handler set before it is a barrier handler; one set after it is not. */
static inline int charon_source_activated(dispatch_object_t source)
{
    if (!charon_dispatch_is_object(source))
        return 0;
    return objc_getAssociatedObject((id)charon_object_pointer(source), CHARON_SOURCE_ACTIVATED) != nil;
}

static inline void charon_source_mark_activated(dispatch_object_t source)
{
#ifdef CHARON_COMPAT_NO_STATE
    (void)source;
#else
    if (!charon_dispatch_is_object(source))
        return;
    objc_setAssociatedObject((id)charon_object_pointer(source), CHARON_SOURCE_ACTIVATED, (id)1, OBJC_ASSOCIATION_ASSIGN);
#endif
}

/* The one caller of the mark that has to know whether it is the first (dispatch_activate's own
   fallback resume) holds this while it looks and marks. */
static pthread_mutex_t charon_source_lock;
static pthread_once_t charon_source_lock_once = PTHREAD_ONCE_INIT;

static void charon_source_lock_make(void)
{
    pthread_mutexattr_t attributes;
    pthread_mutexattr_init(&attributes);
    pthread_mutexattr_settype(&attributes, PTHREAD_MUTEX_RECURSIVE);
    pthread_mutex_init(&charon_source_lock, &attributes);
    pthread_mutexattr_destroy(&attributes);
}

static inline void charon_source_lock_take(void)
{
    pthread_once(&charon_source_lock_once, charon_source_lock_make);
    pthread_mutex_lock(&charon_source_lock);
}

static inline void charon_source_lock_give(void)
{
    pthread_mutex_unlock(&charon_source_lock);
}

#endif
