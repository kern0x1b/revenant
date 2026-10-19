#include <dlfcn.h>
#include <objc/message.h>
#include <objc/NSObjCRuntime.h>
#include <objc/runtime.h>

typedef id (*revenant_unary)(id);
typedef void (*revenant_release)(id);

#define REVENANT_NATIVE(type, name)                                   \
    static type revenant_native_##name(void)                          \
    {                                                               \
        static type found;                                          \
        static int looked;                                          \
        if (!looked) {                                              \
            found = (type)dlsym(RTLD_DEFAULT, #name);               \
            looked = 1;                                             \
        }                                                           \
        return found;                                               \
    }

REVENANT_NATIVE(revenant_unary, objc_retain)
REVENANT_NATIVE(revenant_release, objc_release)
REVENANT_NATIVE(revenant_unary, objc_autorelease)
REVENANT_NATIVE(revenant_unary, objc_retainAutorelease)
REVENANT_NATIVE(revenant_unary, objc_retainAutoreleasedReturnValue)
REVENANT_NATIVE(revenant_unary, objc_autoreleaseReturnValue)
REVENANT_NATIVE(revenant_unary, objc_retainAutoreleaseReturnValue)
REVENANT_NATIVE(revenant_unary, objc_retainBlock)

extern void *_Block_copy(const void *block) __attribute__((weak_import));

typedef void (*revenant_store)(id *, id);
typedef void *(*revenant_push)(void);
typedef void (*revenant_pop)(void *);
REVENANT_NATIVE(revenant_store, objc_storeStrong)
REVENANT_NATIVE(revenant_push, objc_autoreleasePoolPush)
REVENANT_NATIVE(revenant_pop, objc_autoreleasePoolPop)

static id revenant_send(id object, const char *selector)
{
    return ((id (*)(id, SEL))objc_msgSend)(object, sel_registerName(selector));
}

__attribute__((visibility("hidden"))) id objc_retain(id object)
{
    revenant_unary native = revenant_native_objc_retain();
    if (native)
        __attribute__((musttail)) return native(object);
    return revenant_send(object, "retain");
}

__attribute__((visibility("hidden"))) void objc_release(id object)
{
    revenant_release native = revenant_native_objc_release();
    if (native)
        __attribute__((musttail)) return native(object);
    revenant_send(object, "release");
}

__attribute__((visibility("hidden"))) id objc_autorelease(id object)
{
    revenant_unary native = revenant_native_objc_autorelease();
    if (native)
        __attribute__((musttail)) return native(object);
    return revenant_send(object, "autorelease");
}

__attribute__((visibility("hidden"))) id objc_retainAutorelease(id object)
{
    revenant_unary native = revenant_native_objc_retainAutorelease();
    if (native)
        __attribute__((musttail)) return native(object);
    return revenant_send(revenant_send(object, "retain"), "autorelease");
}

__attribute__((visibility("hidden"))) id objc_retainAutoreleasedReturnValue(id object)
{
    revenant_unary native = revenant_native_objc_retainAutoreleasedReturnValue();
    if (native)
        __attribute__((musttail)) return native(object);
    return revenant_send(object, "retain");
}

__attribute__((visibility("hidden"))) id objc_autoreleaseReturnValue(id object)
{
    revenant_unary native = revenant_native_objc_autoreleaseReturnValue();
    if (native)
        __attribute__((musttail)) return native(object);
    return revenant_send(object, "autorelease");
}

__attribute__((visibility("hidden"))) id objc_retainAutoreleaseReturnValue(id object)
{
    revenant_unary native = revenant_native_objc_retainAutoreleaseReturnValue();
    if (native)
        __attribute__((musttail)) return native(object);
    return revenant_send(revenant_send(object, "retain"), "autorelease");
}

__attribute__((visibility("hidden"))) id objc_retainBlock(id block)
{
    revenant_unary native = revenant_native_objc_retainBlock();
    if (native)
        __attribute__((musttail)) return native(block);
    return _Block_copy(block);
}

__attribute__((visibility("hidden"))) void objc_storeStrong(id *location, id object)
{
    revenant_store native = revenant_native_objc_storeStrong();
    if (native)
        __attribute__((musttail)) return native(location, object);
    id previous = *location;
    if (object == previous)
        return;
    *location = objc_retain(object);
    objc_release(previous);
}

__attribute__((visibility("hidden"))) void *objc_autoreleasePoolPush(void)
{
    revenant_push native = revenant_native_objc_autoreleasePoolPush();
    if (native)
        __attribute__((musttail)) return native();
    return revenant_send(revenant_send((id)objc_getClass("NSAutoreleasePool"), "alloc"), "init");
}

__attribute__((visibility("hidden"))) void objc_autoreleasePoolPop(void *pool)
{
    revenant_pop native = revenant_native_objc_autoreleasePoolPop();
    if (native)
        __attribute__((musttail)) return native(pool);
    revenant_send((id)pool, "release");
}

static id revenant_object_at_indexed_subscript(id self, SEL _cmd, NSUInteger index)
{
    return ((id (*)(id, SEL, NSUInteger))objc_msgSend)(self, sel_registerName("objectAtIndex:"), index);
}

static void revenant_set_object_at_indexed_subscript(id self, SEL _cmd, id object, NSUInteger index)
{
    NSUInteger count = ((NSUInteger (*)(id, SEL))objc_msgSend)(self, sel_registerName("count"));
    if (index == count)
        ((void (*)(id, SEL, id))objc_msgSend)(self, sel_registerName("addObject:"), object);
    else
        ((void (*)(id, SEL, NSUInteger, id))objc_msgSend)(self, sel_registerName("replaceObjectAtIndex:withObject:"), index, object);
}

static id revenant_object_for_keyed_subscript(id self, SEL _cmd, id key)
{
    return ((id (*)(id, SEL, id))objc_msgSend)(self, sel_registerName("objectForKey:"), key);
}

static void revenant_set_object_for_keyed_subscript(id self, SEL _cmd, id object, id key)
{
    if (object)
        ((void (*)(id, SEL, id, id))objc_msgSend)(self, sel_registerName("setObject:forKey:"), object, key);
    else
        ((void (*)(id, SEL, id))objc_msgSend)(self, sel_registerName("removeObjectForKey:"), key);
}

struct revenant_added_method {
    const char *class_name;
    const char *selector;
    IMP implementation;
    const char *types;
};

static const struct revenant_added_method revenant_added_methods[] = {
    {"NSArray", "objectAtIndexedSubscript:", (IMP)revenant_object_at_indexed_subscript, "@@:I"},
    {"NSOrderedSet", "objectAtIndexedSubscript:", (IMP)revenant_object_at_indexed_subscript, "@@:I"},
    {"NSMutableArray", "setObject:atIndexedSubscript:", (IMP)revenant_set_object_at_indexed_subscript, "v@:@I"},
    {"NSMutableOrderedSet", "setObject:atIndexedSubscript:", (IMP)revenant_set_object_at_indexed_subscript, "v@:@I"},
    {"NSDictionary", "objectForKeyedSubscript:", (IMP)revenant_object_for_keyed_subscript, "@@:@"},
    {"NSMutableDictionary", "setObject:forKeyedSubscript:", (IMP)revenant_set_object_for_keyed_subscript, "v@:@@"},
};

__attribute__((used, section("__DATA,__revenant_addsel"))) static const char *const revenant_added_selectors[] = {
    "objectAtIndexedSubscript:",
    "setObject:atIndexedSubscript:",
    "objectForKeyedSubscript:",
    "setObject:forKeyedSubscript:",
};

__attribute__((constructor)) static void revenant_arclite_subscripting(void)
{
    for (unsigned index = 0; index < sizeof revenant_added_methods / sizeof *revenant_added_methods; index++) {
        const struct revenant_added_method *method = &revenant_added_methods[index];
        Class found = objc_getClass(method->class_name);
        SEL name = sel_registerName(method->selector);
        if (found && !class_getInstanceMethod(found, name))
            class_addMethod(found, name, method->implementation, method->types);
    }
}
