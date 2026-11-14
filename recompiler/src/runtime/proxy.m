#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "xl_proxy.h"

id objc_loadWeakRetained(id *location);
id objc_storeWeak(id *location, id value);
void objc_destroyWeak(id *location);
id objc_autorelease(id value);
void objc_clear_deallocating(id object);

struct xl_proxy_data {
    uintptr_t guest;
};

struct xl_proxy_entry {
    id weak;
    id owner;
};

volatile int xl_proxy_classes_active;

static volatile int xl_proxy_dynamic_active;
static int xl_proxy_disabled;
static CFMutableDictionaryRef xl_proxy_class_of_guest;
static CFMutableDictionaryRef xl_proxy_class_shadows;
static CFMutableDictionaryRef xl_proxy_by_guest;
static pthread_rwlock_t xl_proxy_classes_lock = PTHREAD_RWLOCK_INITIALIZER;
static pthread_mutex_t xl_proxy_lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_once_t xl_proxy_once = PTHREAD_ONCE_INIT;

static const char *const xl_proxy_memory_selectors[] = {"retain", "release", "autorelease", "retainCount", "_tryRetain",
                                                        "_isDeallocating", "allowsWeakReference", "retainWeakReference"};

static void xl_proxy_fatal(const char *message)
{
    fprintf(stderr, "xlate: %s\n", message);
    abort();
}

static void xl_proxy_setup(void)
{
    xl_proxy_class_of_guest = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
    xl_proxy_class_shadows = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
    xl_proxy_by_guest = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
    const char *proxy_switch = getenv("XL_PROXY");
    xl_proxy_disabled = proxy_switch && strcmp(proxy_switch, "0") == 0;
}

static void xl_proxy_dealloc(id self, SEL selector)
{
    struct xl_proxy_data *data = (struct xl_proxy_data *)object_getIndexedIvars(self);
    uintptr_t guest = data->guest;
    objc_removeAssociatedObjects(self);
    objc_clear_deallocating(self);
    pthread_mutex_lock(&xl_proxy_lock);
    struct xl_proxy_entry *entry = (struct xl_proxy_entry *)CFDictionaryGetValue(xl_proxy_by_guest, (const void *)guest);
    if (entry && entry->owner == self) {
        CFDictionaryRemoveValue(xl_proxy_by_guest, (const void *)guest);
        objc_destroyWeak(&entry->weak);
        free(entry);
    }
    pthread_mutex_unlock(&xl_proxy_lock);
    xl_proxy_guest_release(guest);
    free(self);
}

static Class xl_proxy_class_of(id self, SEL selector)
{
    return class_getSuperclass(object_getClass(self));
}

static Class xl_proxy_make_class(uintptr_t guest_class, Class shadow)
{
    const char *base = class_getName(shadow);
    char *name = NULL;
    if (asprintf(&name, "XLProxy.%s", base) < 0)
        xl_proxy_fatal("no memory for the name of a proxy class");
    Class proxy_class = objc_allocateClassPair(shadow, name, 0);
    if (!proxy_class) {
        free(name);
        name = NULL;
        if (asprintf(&name, "XLProxy.%s@%lx", base, (unsigned long)guest_class) < 0)
            xl_proxy_fatal("no memory for the name of a proxy class");
        proxy_class = objc_allocateClassPair(shadow, name, 0);
    }
    free(name);
    if (!proxy_class)
        xl_proxy_fatal("cannot make the proxy class of a guest class");
    class_addMethod(proxy_class, @selector(dealloc), (IMP)xl_proxy_dealloc, "v@:");
    class_addMethod(proxy_class, @selector(class), (IMP)xl_proxy_class_of, "#@:");
    for (size_t index = 0; index < sizeof xl_proxy_memory_selectors / sizeof *xl_proxy_memory_selectors; index++) {
        SEL selector = sel_registerName(xl_proxy_memory_selectors[index]);
        Method root = class_getInstanceMethod([NSObject class], selector);
        if (root)
            class_addMethod(proxy_class, selector, method_getImplementation(root), method_getTypeEncoding(root));
    }
    objc_registerClassPair(proxy_class);
    CFDictionarySetValue(xl_proxy_class_shadows, (const void *)proxy_class, (const void *)shadow);
    CFDictionarySetValue(xl_proxy_class_of_guest, (const void *)guest_class, (const void *)proxy_class);
    xl_proxy_classes_active = 1;
    return proxy_class;
}

static Class xl_proxy_class_for(uintptr_t guest_class)
{
    pthread_rwlock_rdlock(&xl_proxy_classes_lock);
    uintptr_t value = (uintptr_t)CFDictionaryGetValue(xl_proxy_class_of_guest, (const void *)guest_class);
    pthread_rwlock_unlock(&xl_proxy_classes_lock);
    if (value > 1)
        return (Class)value;
    if (!value)
        return Nil;
    pthread_rwlock_wrlock(&xl_proxy_classes_lock);
    value = (uintptr_t)CFDictionaryGetValue(xl_proxy_class_of_guest, (const void *)guest_class);
    if (value == 1) {
        Class shadow = xl_proxy_shadow_of(guest_class);
        value = shadow ? (uintptr_t)xl_proxy_make_class(guest_class, shadow) : 0;
    }
    pthread_rwlock_unlock(&xl_proxy_classes_lock);
    return (Class)value;
}

static id xl_proxy_for(uintptr_t guest, Class proxy_class)
{
    pthread_mutex_lock(&xl_proxy_lock);
    struct xl_proxy_entry *entry = (struct xl_proxy_entry *)CFDictionaryGetValue(xl_proxy_by_guest, (const void *)guest);
    if (entry) {
        id live = objc_loadWeakRetained(&entry->weak);
        if (live) {
            pthread_mutex_unlock(&xl_proxy_lock);
            return live;
        }
    }
    id proxy = class_createInstance(proxy_class, sizeof(struct xl_proxy_data));
    struct xl_proxy_data *data = (struct xl_proxy_data *)object_getIndexedIvars(proxy);
    data->guest = guest;
    xl_proxy_guest_retain(guest);
    if (!entry) {
        entry = calloc(1, sizeof *entry);
        if (!entry)
            xl_proxy_fatal("no memory for a proxy entry");
        CFDictionarySetValue(xl_proxy_by_guest, (const void *)guest, entry);
    }
    objc_storeWeak(&entry->weak, proxy);
    entry->owner = proxy;
    pthread_mutex_unlock(&xl_proxy_lock);
    return proxy;
}

void xl_proxy_note_class(uintptr_t guest_class)
{
    pthread_once(&xl_proxy_once, xl_proxy_setup);
    if (xl_proxy_disabled || !guest_class)
        return;
    pthread_rwlock_wrlock(&xl_proxy_classes_lock);
    if (!CFDictionaryContainsKey(xl_proxy_class_of_guest, (const void *)guest_class))
        CFDictionarySetValue(xl_proxy_class_of_guest, (const void *)guest_class, (const void *)1);
    pthread_rwlock_unlock(&xl_proxy_classes_lock);
    __sync_synchronize();
    xl_proxy_dynamic_active = 1;
}

uintptr_t xl_proxy_in(uintptr_t guest)
{
    if (!xl_proxy_dynamic_active || (guest & 7) || guest < 0x4000)
        return 0;
    uintptr_t guest_class = *(const uint32_t *)guest;
    Class proxy_class = xl_proxy_class_for(guest_class);
    if (!proxy_class)
        return 0;
    return (uintptr_t)objc_autorelease(xl_proxy_for(guest, proxy_class));
}

uint64_t xl_proxy_out(uintptr_t host)
{
    if (!xl_proxy_classes_active || !host)
        return 0;
    Class cls = object_getClass((id)host);
    pthread_rwlock_rdlock(&xl_proxy_classes_lock);
    int proxied = CFDictionaryContainsKey(xl_proxy_class_shadows, (const void *)cls);
    pthread_rwlock_unlock(&xl_proxy_classes_lock);
    return proxied ? ((struct xl_proxy_data *)object_getIndexedIvars((id)host))->guest : 0;
}
