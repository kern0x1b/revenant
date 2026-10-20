#include "objc_abi.h"
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#include <Block.h>
#include <libkern/OSAtomic.h>
#include <pthread.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include "xl_bridge.h"
#include "xl_host.h"

struct xl_guest_class {
    uint64_t isa;
    uint64_t superclass;
    uint64_t cache;
    uint64_t cache_mask;
    uint64_t bits;
};

struct xl_guest_ro {
    uint32_t flags;
    uint32_t instance_start;
    uint32_t instance_size;
    uint32_t reserved;
    uint64_t ivar_layout;
    uint64_t name;
    uint64_t base_methods;
    uint64_t base_protocols;
    uint64_t ivars;
    uint64_t weak_ivar_layout;
    uint64_t base_properties;
};

enum { XL_RO_META = 1, XL_RO_ROOT = 2 };

extern const uint32_t xl_swift_static_classes[];
extern const uint32_t xl_swift_listed_classes[];

static volatile int xl_shadows_active;
static OSSpinLock xl_table_lock = OS_SPINLOCK_INIT;
static CFMutableDictionaryRef xl_guest_to_host;
static CFMutableDictionaryRef xl_host_to_guest;
static CFMutableDictionaryRef xl_unbuilt_static;
static CFMutableDictionaryRef xl_shadow_imps;
static pthread_mutex_t xl_build_lock;
static pthread_once_t xl_shadow_once = PTHREAD_ONCE_INIT;
static uint64_t xl_lazy_namer;

static int xl_shadow_logging = -1;

int xl_shadow_log_enabled(void)
{
    if (xl_shadow_logging < 0)
        xl_shadow_logging = access("/private/var/revenant/xl-shadow-log", F_OK) == 0;
    return xl_shadow_logging;
}

void xl_shadow_note(const char *format, ...)
{
    if (!xl_shadow_log_enabled())
        return;
    FILE *log = fopen("/private/var/revenant/xlate-shadow.log", "a");
    if (!log)
        return;
    va_list arguments;
    va_start(arguments, format);
    vfprintf(log, format, arguments);
    va_end(arguments);
    fputc('\n', log);
    fclose(log);
}

static void xl_shadow_setup(void)
{
    pthread_mutexattr_t attribute;
    pthread_mutexattr_init(&attribute);
    pthread_mutexattr_settype(&attribute, PTHREAD_MUTEX_RECURSIVE);
    pthread_mutex_init(&xl_build_lock, &attribute);
    xl_guest_to_host = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
    xl_host_to_guest = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
    xl_unbuilt_static = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
    xl_shadow_imps = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
    for (const uint32_t *object = xl_swift_static_classes; *object; object++) {
        const struct xl_guest_class *c = (const struct xl_guest_class *)(uintptr_t)*object;
        const struct xl_guest_ro *ro = (const struct xl_guest_ro *)(uintptr_t)(c->bits & ~7ull);
        if (ro->flags & XL_RO_META)
            continue;
        CFDictionarySetValue(xl_unbuilt_static, (const void *)(uintptr_t)*object, (const void *)(uintptr_t)*object);
        if (c->isa)
            CFDictionarySetValue(xl_unbuilt_static, (const void *)(uintptr_t)c->isa, (const void *)(uintptr_t)*object);
    }
    if (xl_swift_static_classes[0])
        xl_shadows_active = 1;
}

void xl_shadow_init(void)
{
    pthread_once(&xl_shadow_once, xl_shadow_setup);
}

static const void *xl_table_get(CFMutableDictionaryRef table, uintptr_t key)
{
    OSSpinLockLock(&xl_table_lock);
    const void *value = CFDictionaryGetValue(table, (const void *)key);
    OSSpinLockUnlock(&xl_table_lock);
    return value;
}

static void xl_table_set(CFMutableDictionaryRef table, uintptr_t key, const void *value)
{
    OSSpinLockLock(&xl_table_lock);
    CFDictionarySetValue(table, (const void *)key, value);
    OSSpinLockUnlock(&xl_table_lock);
}

static IMP xl_guest_method_imp(uint64_t guest, SEL selector)
{
    IMP imp = imp_implementationWithBlock(^uintptr_t(id self_, uintptr_t a, uintptr_t b, uintptr_t c, uintptr_t d) {
        uint64_t arguments[6] = {xl_object_out((uintptr_t)self_), (uint64_t)(uintptr_t)selector, a, b, c, d};
        return (uintptr_t)xl_invoke_n(guest, arguments, 6);
    });
    xl_table_set(xl_shadow_imps, (uintptr_t)imp, (const void *)(uintptr_t)guest);
    return imp;
}

uint32_t xl_shadow_imp(IMP imp)
{
    if (!xl_shadows_active || !imp)
        return 0;
    return (uint32_t)(uintptr_t)xl_table_get(xl_shadow_imps, (uintptr_t)imp);
}

static void xl_add_guest_methods(Class target, uint64_t list, const char *class_name)
{
    if (!list)
        return;
    uint32_t header = *(const uint32_t *)(uintptr_t)list;
    uint32_t count = *(const uint32_t *)(uintptr_t)(list + 4);
    int relative = (header & 0x80000000u) != 0;
    uint32_t entsize = header & 0x0000FFFCu;
    for (uint32_t i = 0; i < count; i++) {
        uint64_t entry = list + 8 + (uint64_t)i * entsize;
        SEL selector;
        const char *types;
        uint64_t imp;
        if (relative) {
            selector = (SEL)(uintptr_t) * (const uint32_t *)(uintptr_t)(entry + *(const int32_t *)(uintptr_t)entry);
            types = (const char *)(uintptr_t)(entry + 4 + *(const int32_t *)(uintptr_t)(entry + 4));
            imp = entry + 8 + *(const int32_t *)(uintptr_t)(entry + 8);
        } else {
            selector = sel_registerName((const char *)(uintptr_t) * (const uint64_t *)(uintptr_t)entry);
            types = (const char *)(uintptr_t) * (const uint64_t *)(uintptr_t)(entry + 8);
            imp = *(const uint64_t *)(uintptr_t)(entry + 16);
        }
        if (!class_addMethod(target, selector, xl_guest_method_imp(imp, selector), types))
            xl_shadow_note("%s: method %s already defined", class_name, sel_getName(selector));
    }
}

static Class xl_class_from_guest(uint64_t guest);

static Class xl_build_shadow(uintptr_t guest)
{
    pthread_mutex_lock(&xl_build_lock);
    Class shadow = (Class)xl_table_get(xl_guest_to_host, guest);
    if (shadow) {
        pthread_mutex_unlock(&xl_build_lock);
        return shadow;
    }
    const struct xl_guest_class *c = (const struct xl_guest_class *)guest;
    const struct xl_guest_ro *ro = (const struct xl_guest_ro *)(uintptr_t)(c->bits & ~7ull);
    if (!ro || (ro->flags & XL_RO_META)) {
        char why[128];
        snprintf(why, sizeof why, "xlate: class object %p is not a class (data word 0x%llx)", (void *)guest, (unsigned long long)c->bits);
        pthread_mutex_unlock(&xl_build_lock);
        xl_unsupported(why);
    }
    const struct xl_guest_class *meta = (const struct xl_guest_class *)(uintptr_t)c->isa;
    const struct xl_guest_ro *meta_ro = meta ? (const struct xl_guest_ro *)(uintptr_t)(meta->bits & ~7ull) : NULL;

    const char *name = (const char *)(uintptr_t)ro->name;
    if (!name) {
        if (!xl_lazy_namer) {
            char why[128];
            snprintf(why, sizeof why, "xlate: class %p has no name and no lazy class namer is registered", (void *)guest);
            pthread_mutex_unlock(&xl_build_lock);
            xl_unsupported(why);
        }
        uint64_t argument = guest;
        name = (const char *)(uintptr_t)xl_invoke_n(xl_lazy_namer, &argument, 1);
        if (!name) {
            char why[128];
            snprintf(why, sizeof why, "xlate: the lazy class namer gave class %p no name", (void *)guest);
            pthread_mutex_unlock(&xl_build_lock);
            xl_unsupported(why);
        }
    }

    Class host_super = c->superclass ? xl_class_from_guest(c->superclass) : Nil;
    if (host_super)
        ((id(*)(id, SEL))objc_msgSend)((id)host_super, sel_registerName("class"));
    shadow = objc_allocateClassPair(host_super, name, 0);
    if (!shadow) {
        char why[256];
        snprintf(why, sizeof why, "xlate: cannot make the shadow of class %s (%p): a class of that name exists", name, (void *)guest);
        pthread_mutex_unlock(&xl_build_lock);
        xl_unsupported(why);
    }
    size_t super_size = host_super ? class_getInstanceSize(host_super) : 0;
    if (ro->instance_size > super_size)
        class_addIvar(shadow, "xl_guest_storage", ro->instance_size - super_size, 3, "?");
    xl_add_guest_methods(shadow, ro->base_methods, name);
    Class shadow_meta = object_getClass(shadow);
    if (meta_ro)
        xl_add_guest_methods(shadow_meta, meta_ro->base_methods, name);
    if (ro->base_protocols || ro->ivars || ro->base_properties)
        xl_shadow_note("%s: protocols %llx, ivars %llx, properties %llx are not carried to the shadow", name,
                       (unsigned long long)ro->base_protocols, (unsigned long long)ro->ivars, (unsigned long long)ro->base_properties);
    objc_registerClassPair(shadow);

    OSSpinLockLock(&xl_table_lock);
    CFDictionarySetValue(xl_guest_to_host, (const void *)guest, shadow);
    CFDictionarySetValue(xl_host_to_guest, shadow, (const void *)guest);
    CFDictionaryRemoveValue(xl_unbuilt_static, (const void *)guest);
    if (meta) {
        CFDictionarySetValue(xl_guest_to_host, (const void *)(uintptr_t)c->isa, shadow_meta);
        CFDictionarySetValue(xl_host_to_guest, shadow_meta, (const void *)(uintptr_t)c->isa);
        CFDictionaryRemoveValue(xl_unbuilt_static, (const void *)(uintptr_t)c->isa);
    }
    xl_shadows_active = 1;
    OSSpinLockUnlock(&xl_table_lock);
    xl_shadow_note("registered %s: class %p meta %p (guest meta %llx), instance size %zu, super %p", name, shadow, shadow_meta,
                   (unsigned long long)c->isa, class_getInstanceSize(shadow), class_getSuperclass(shadow));
    xl_shadow_note("shadow %s: guest %p -> host %p, super %p, guest size %u, methods %llx / %llx", name, (void *)guest, shadow,
                   host_super, ro->instance_size, (unsigned long long)ro->base_methods,
                   (unsigned long long)(meta_ro ? meta_ro->base_methods : 0));
    pthread_mutex_unlock(&xl_build_lock);
    return shadow;
}

static Class xl_class_from_guest(uint64_t guest)
{
    if (!xl_shadows_active)
        return (Class)(uintptr_t)guest;
    Class shadow = (Class)xl_table_get(xl_guest_to_host, (uintptr_t)guest);
    if (shadow)
        return shadow;
    uintptr_t owner = (uintptr_t)xl_table_get(xl_unbuilt_static, (uintptr_t)guest);
    if (!owner)
        return (Class)(uintptr_t)guest;
    shadow = xl_build_shadow(owner);
    return owner == guest ? shadow : object_getClass(shadow);
}

void xl_shadow_register_listed(void)
{
    static volatile int registering;
    if (registering || __sync_lock_test_and_set(&registering, 1))
        return;
    xl_shadow_init();
    for (const uint32_t *c = xl_swift_listed_classes; *c; c++)
        xl_class_from_guest(*c);
}

Class xl_class_in(uint64_t guest)
{
    Class host = xl_class_from_guest(guest);
    if (xl_shadow_log_enabled() && (uintptr_t)host != (uintptr_t)guest)
        xl_shadow_note("in %llx -> %p", (unsigned long long)guest, host);
    return host;
}

uint64_t xl_class_out(uintptr_t host)
{
    if (!xl_shadows_active)
        return host;
    uintptr_t guest = (uintptr_t)xl_table_get(xl_host_to_guest, host);
    return guest ? guest : host;
}

Class xl_class_of(id object)
{
    if (!object)
        return Nil;
    if (!xl_shadows_active)
        return object_getClass(object);
    return xl_class_from_guest(*(const uintptr_t *)(uintptr_t)object);
}

int xl_guest_send(id object, SEL selector, uint64_t *result)
{
    if (!xl_shadows_active || !object)
        return 0;
    Class shadow = (Class)xl_table_get(xl_guest_to_host, *(const uintptr_t *)(uintptr_t)object);
    if (!shadow)
        return 0;
    uint32_t guest = xl_guest_imp_address(class_getMethodImplementation(shadow, selector));
    if (!guest) {
        char why[192];
        snprintf(why, sizeof why, "xlate: -[%s %s] on an instance the guest allocated is implemented by the host, which cannot read its class",
                 class_getName(shadow), sel_getName(selector));
        xl_unsupported(why);
    }
    uint64_t arguments[2] = {(uint64_t)(uintptr_t)object, (uint64_t)(uintptr_t)selector};
    *result = xl_invoke_n(guest, arguments, 2);
    return 1;
}

static uintptr_t xl_register_class(uintptr_t guest, const char *call)
{
    if (!guest)
        return 0;
    (void)call;
    return (uintptr_t)xl_build_shadow(guest);
}

struct __attribute__((packed)) xl_pair_pack {
    uint64_t a0;
    uint64_t a1;
    uint64_t r;
};

void xl_manual_objc_readClassPair(void *pack)
{
    struct xl_pair_pack *p = pack;
    xl_shadow_init();
    xl_register_class(xl_narrow_pointer(p->a0, "objc_readClassPair", 0), "objc_readClassPair");
    p->r = p->a0;
}

void xl_manual__objc_realizeClassFromSwift(void *pack)
{
    struct xl_pair_pack *p = pack;
    xl_shadow_init();
    uintptr_t cls = xl_narrow_pointer(p->a0, "_objc_realizeClassFromSwift", 0);
    uintptr_t previously = xl_narrow_pointer(p->a1, "_objc_realizeClassFromSwift", 1);
    if (!cls) {
        char why[128];
        snprintf(why, sizeof why, "Swift requested that class %p be ignored, but libobjc does not support that", (void *)previously);
        xl_unsupported(why);
    }
    Class shadow = (Class)xl_register_class(cls, "_objc_realizeClassFromSwift");
    if (previously && previously != cls)
        xl_table_set(xl_guest_to_host, previously, shadow);
    p->r = p->a0;
}

struct __attribute__((packed)) xl_hook_pack {
    uint64_t new_hook;
    uint64_t old_out;
    uint64_t none;
};

void xl_manual_objc_setHook_lazyClassNamer(void *pack)
{
    struct xl_hook_pack *p = pack;
    xl_shadow_init();
    uint64_t *old = (uint64_t *)xl_narrow_pointer(p->old_out, "objc_setHook_lazyClassNamer", 1);
    *old = xl_lazy_namer ? xl_lazy_namer : p->none;
    xl_lazy_namer = p->new_hook;
}

static uint64_t xl_image_name_hook;

struct __attribute__((packed)) xl_image_name_hook_pack {
    uint64_t new_hook;
    uint64_t old_out;
    uint64_t default_hook;
};

void xl_manual_objc_setHook_getImageName(void *pack)
{
    struct xl_image_name_hook_pack *p = pack;
    uint64_t *old = (uint64_t *)xl_narrow_pointer(p->old_out, "objc_setHook_getImageName", 1);
    *old = xl_image_name_hook ? xl_image_name_hook : p->default_hook;
    xl_image_name_hook = p->new_hook;
}

struct __attribute__((packed)) xl_image_name_pack {
    uint64_t cls;
    uint64_t r;
};

void xl_manual_class_getImageName(void *pack)
{
    struct xl_image_name_pack *p = pack;
    if (xl_image_name_hook) {
        uint64_t name = 0;
        uint64_t arguments[2] = {p->cls, (uint64_t)(uintptr_t)&name};
        p->r = (xl_invoke_n(xl_image_name_hook, arguments, 2) & 0xff) ? name : 0;
        return;
    }
    p->r = xl_widen_pointer((uintptr_t)class_getImageName(xl_class_in(xl_narrow_pointer(p->cls, "class_getImageName", 0))));
}

void xl_manual_default_class_getImageName(void *pack)
{
    struct xl_image_name_pack *p = pack;
    p->r = xl_widen_pointer((uintptr_t)class_getImageName(xl_class_in(xl_narrow_pointer(p->cls, "class_getImageName", 0))));
}
