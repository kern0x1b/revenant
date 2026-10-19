#ifndef REVENANT_DISPATCH_SOURCE_STATE_H
#define REVENANT_DISPATCH_SOURCE_STATE_H

#include <dispatch/dispatch.h>
#include <objc/runtime.h>
#include <pthread.h>
#include <stdint.h>

#define REVENANT_SOURCE_ACTIVATED ((const void *)(uintptr_t)0x636861726f6e4143u)

static inline void *revenant_object_pointer(dispatch_object_t object)
{
    union {
        dispatch_object_t object;
        void *pointer;
    } same;
    same.object = object;
    return same.pointer;
}

static inline int revenant_dispatch_is_object(dispatch_object_t object)
{
    static int checked;
    static Class source;
    if (!checked) {
        source = objc_getClass("OS_dispatch_source");
        checked = 1;
    }
    if (!source)
        return 0;
    Class kind = object_getClass((id)revenant_object_pointer(object));
    while (kind && kind != source)
        kind = class_getSuperclass(kind);
    return kind != NULL;
}

static inline int revenant_source_activated(dispatch_object_t source)
{
    if (!revenant_dispatch_is_object(source))
        return 0;
    return objc_getAssociatedObject((id)revenant_object_pointer(source), REVENANT_SOURCE_ACTIVATED) != nil;
}

static inline void revenant_source_mark_activated(dispatch_object_t source)
{
#ifdef REVENANT_COMPAT_NO_STATE
    (void)source;
#else
    if (!revenant_dispatch_is_object(source))
        return;
    objc_setAssociatedObject((id)revenant_object_pointer(source), REVENANT_SOURCE_ACTIVATED, (id)1, OBJC_ASSOCIATION_ASSIGN);
#endif
}

static pthread_mutex_t revenant_source_lock;
static pthread_once_t revenant_source_lock_once = PTHREAD_ONCE_INIT;

static void revenant_source_lock_make(void)
{
    pthread_mutexattr_t attributes;
    pthread_mutexattr_init(&attributes);
    pthread_mutexattr_settype(&attributes, PTHREAD_MUTEX_RECURSIVE);
    pthread_mutex_init(&revenant_source_lock, &attributes);
    pthread_mutexattr_destroy(&attributes);
}

static inline void revenant_source_lock_take(void)
{
    pthread_once(&revenant_source_lock_once, revenant_source_lock_make);
    pthread_mutex_lock(&revenant_source_lock);
}

static inline void revenant_source_lock_give(void)
{
    pthread_mutex_unlock(&revenant_source_lock);
}

#endif
