#include <dlfcn.h>
#include <objc/message.h>
#include <objc/NSObjCRuntime.h>
#include <objc/runtime.h>

typedef id (*charon_unary)(id);
typedef void (*charon_release)(id);

#define CHARON_NATIVE(type, name)                                   \
    static type charon_native_##name(void)                          \
    {                                                               \
        static type found;                                          \
        static int looked;                                          \
        if (!looked) {                                              \
            found = (type)dlsym(RTLD_DEFAULT, #name);               \
            looked = 1;                                             \
        }                                                           \
        return found;                                               \
    }

CHARON_NATIVE(charon_unary, objc_retain)
CHARON_NATIVE(charon_release, objc_release)
CHARON_NATIVE(charon_unary, objc_autorelease)
CHARON_NATIVE(charon_unary, objc_retainAutorelease)
CHARON_NATIVE(charon_unary, objc_retainAutoreleasedReturnValue)
CHARON_NATIVE(charon_unary, objc_autoreleaseReturnValue)
CHARON_NATIVE(charon_unary, objc_retainAutoreleaseReturnValue)
CHARON_NATIVE(charon_unary, objc_retainBlock)

extern void *_Block_copy(const void *block) __attribute__((weak_import));

typedef void (*charon_store)(id *, id);
typedef void *(*charon_push)(void);
typedef void (*charon_pop)(void *);
CHARON_NATIVE(charon_store, objc_storeStrong)
CHARON_NATIVE(charon_push, objc_autoreleasePoolPush)
CHARON_NATIVE(charon_pop, objc_autoreleasePoolPop)

static id charon_send(id object, const char *selector)
{
    return ((id (*)(id, SEL))objc_msgSend)(object, sel_registerName(selector));
}

__attribute__((visibility("hidden"))) id objc_retain(id object)
{
    charon_unary native = charon_native_objc_retain();
    if (native)
        __attribute__((musttail)) return native(object);
    return charon_send(object, "retain");
}

__attribute__((visibility("hidden"))) void objc_release(id object)
{
    charon_release native = charon_native_objc_release();
    if (native)
        __attribute__((musttail)) return native(object);
    charon_send(object, "release");
}

__attribute__((visibility("hidden"))) id objc_autorelease(id object)
{
    charon_unary native = charon_native_objc_autorelease();
    if (native)
        __attribute__((musttail)) return native(object);
    return charon_send(object, "autorelease");
}

__attribute__((visibility("hidden"))) id objc_retainAutorelease(id object)
{
    charon_unary native = charon_native_objc_retainAutorelease();
    if (native)
        __attribute__((musttail)) return native(object);
    return charon_send(charon_send(object, "retain"), "autorelease");
}

__attribute__((visibility("hidden"))) id objc_retainAutoreleasedReturnValue(id object)
{
    charon_unary native = charon_native_objc_retainAutoreleasedReturnValue();
    if (native)
        __attribute__((musttail)) return native(object);
    return charon_send(object, "retain");
}

__attribute__((visibility("hidden"))) id objc_autoreleaseReturnValue(id object)
{
    charon_unary native = charon_native_objc_autoreleaseReturnValue();
    if (native)
        __attribute__((musttail)) return native(object);
    return charon_send(object, "autorelease");
}

__attribute__((visibility("hidden"))) id objc_retainAutoreleaseReturnValue(id object)
{
    charon_unary native = charon_native_objc_retainAutoreleaseReturnValue();
    if (native)
        __attribute__((musttail)) return native(object);
    return charon_send(charon_send(object, "retain"), "autorelease");
}

__attribute__((visibility("hidden"))) id objc_retainBlock(id block)
{
    charon_unary native = charon_native_objc_retainBlock();
    if (native)
        __attribute__((musttail)) return native(block);
    return _Block_copy(block);
}

__attribute__((visibility("hidden"))) void objc_storeStrong(id *location, id object)
{
    charon_store native = charon_native_objc_storeStrong();
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
    charon_push native = charon_native_objc_autoreleasePoolPush();
    if (native)
        __attribute__((musttail)) return native();
    return charon_send(charon_send((id)objc_getClass("NSAutoreleasePool"), "alloc"), "init");
}

__attribute__((visibility("hidden"))) void objc_autoreleasePoolPop(void *pool)
{
    charon_pop native = charon_native_objc_autoreleasePoolPop();
    if (native)
        __attribute__((musttail)) return native(pool);
    charon_send((id)pool, "release");
}

static id charon_object_at_indexed_subscript(id self, SEL _cmd, NSUInteger index)
{
    return ((id (*)(id, SEL, NSUInteger))objc_msgSend)(self, sel_registerName("objectAtIndex:"), index);
}

static void charon_set_object_at_indexed_subscript(id self, SEL _cmd, id object, NSUInteger index)
{
    NSUInteger count = ((NSUInteger (*)(id, SEL))objc_msgSend)(self, sel_registerName("count"));
    if (index == count)
        ((void (*)(id, SEL, id))objc_msgSend)(self, sel_registerName("addObject:"), object);
    else
        ((void (*)(id, SEL, NSUInteger, id))objc_msgSend)(self, sel_registerName("replaceObjectAtIndex:withObject:"), index, object);
}

static id charon_object_for_keyed_subscript(id self, SEL _cmd, id key)
{
    return ((id (*)(id, SEL, id))objc_msgSend)(self, sel_registerName("objectForKey:"), key);
}

static void charon_set_object_for_keyed_subscript(id self, SEL _cmd, id object, id key)
{
    if (object)
        ((void (*)(id, SEL, id, id))objc_msgSend)(self, sel_registerName("setObject:forKey:"), object, key);
    else
        ((void (*)(id, SEL, id))objc_msgSend)(self, sel_registerName("removeObjectForKey:"), key);
}

struct charon_added_method {
    const char *class_name;
    const char *selector;
    IMP implementation;
    const char *types;
};

static const struct charon_added_method charon_added_methods[] = {
    {"NSArray", "objectAtIndexedSubscript:", (IMP)charon_object_at_indexed_subscript, "@@:I"},
    {"NSOrderedSet", "objectAtIndexedSubscript:", (IMP)charon_object_at_indexed_subscript, "@@:I"},
    {"NSMutableArray", "setObject:atIndexedSubscript:", (IMP)charon_set_object_at_indexed_subscript, "v@:@I"},
    {"NSMutableOrderedSet", "setObject:atIndexedSubscript:", (IMP)charon_set_object_at_indexed_subscript, "v@:@I"},
    {"NSDictionary", "objectForKeyedSubscript:", (IMP)charon_object_for_keyed_subscript, "@@:@"},
    {"NSMutableDictionary", "setObject:forKeyedSubscript:", (IMP)charon_set_object_for_keyed_subscript, "v@:@@"},
};

__attribute__((used, section("__DATA,__charon_addsel"))) static const char *const charon_added_selectors[] = {
    "objectAtIndexedSubscript:",
    "setObject:atIndexedSubscript:",
    "objectForKeyedSubscript:",
    "setObject:forKeyedSubscript:",
};

__attribute__((constructor)) static void charon_arclite_subscripting(void)
{
    for (unsigned index = 0; index < sizeof charon_added_methods / sizeof *charon_added_methods; index++) {
        const struct charon_added_method *method = &charon_added_methods[index];
        Class found = objc_getClass(method->class_name);
        SEL name = sel_registerName(method->selector);
        if (found && !class_getInstanceMethod(found, name))
            class_addMethod(found, name, method->implementation, method->types);
    }
}
