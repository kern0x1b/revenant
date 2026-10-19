#include <mach-o/getsect.h>
#include <mach-o/loader.h>
#include <objc/runtime.h>
#include <stdlib.h>
#include <string.h>

extern const struct mach_header_64 __dso_handle;

struct host_list {
    uint32_t flags;
    uint32_t count;
};

struct host_category {
    const char *name;
    Class cls;
    struct host_list *instance_methods;
    struct host_list *class_methods;
};

static void host_method(const struct host_list *list, uint32_t index, const char **name, const char **types, IMP *implementation)
{
    uint32_t size = list->flags & 0xFFFC;
    const char *entry = (const char *)(list + 1) + index * size;
    if (list->flags & 0x80000000) {
        const int32_t *offsets = (const int32_t *)entry;
        *name = *(const char *const *)(entry + offsets[0]);
        *types = entry + sizeof(int32_t) + offsets[1];
        *implementation = (IMP)(entry + 2 * sizeof(int32_t) + offsets[2]);
        return;
    }
    const void *const *pointers = (const void *const *)entry;
    *name = pointers[0];
    *types = pointers[1];
    *implementation = (IMP)pointers[2];
}

static void host_add(Class cls, const struct host_list *list, const char *prefix)
{
    for (uint32_t index = 0; list && index < list->count; index++) {
        const char *name, *types;
        IMP implementation;
        host_method(list, index, &name, &types, &implementation);
        size_t length = strlen(prefix) + strlen(name) + 1;
        char *prefixed = malloc(length);
        strcpy(prefixed, prefix);
        strcat(prefixed, name);
        if (!class_addMethod(cls, sel_registerName(prefixed), implementation, types))
            abort();
        free(prefixed);
    }
}

void host_attach_prefixed(const char *prefix)
{
    unsigned long size;
    const struct host_category *const *categories = (const struct host_category *const *)getsectiondata(&__dso_handle, "__DATA", "__charon_catlist", &size);
    if (!categories)
        categories = (const struct host_category *const *)getsectiondata(&__dso_handle, "__DATA_CONST", "__charon_catlist", &size);
    for (size_t index = 0; categories && index < size / sizeof(void *); index++) {
        const struct host_category *category = categories[index];
        host_add(category->cls, category->instance_methods, prefix);
        host_add(object_getClass((id)category->cls), category->class_methods, prefix);
    }
}

/* What a host differential needs where the RELEASE carries the class and exports nothing - the 8.0 -
 * 8.4.1 shape - and a device gets from attach.c's charon_reparent and charon_collect: the port's
 * members on the class the release's own session instantiates. Measured on the host 2026-10-04, the
 * class of the release's NAME is not that class: NSURLSessionStreamTask answers 0 own methods and has
 * no class below it, while the task the host's own factory makes is a __NSCFTCPIOStreamTask, a sibling
 * of it, and it is that class which carries _onqueue_resume and the 26 other instance variables the
 * release's -[NSURLSessionTask resume] drives. charon_reparent's own mechanism cannot be used here at
 * all: it writes the superclass word and reads the layout back, and every compiled class of a host
 * image is already realized before the first constructor runs.
 *
 * So the members are INSTALLED on the release's class rather than inherited by a proxy of it, which is
 * what charon_collect does on a device, and the class is the one the harness measured rather than a
 * private name written here. class_replaceMethod, not class_addMethod: the port's member shadows the
 * release's on the same class, which is the whole point of the comparison. Returns how many it put on,
 * so a run that collected nothing says so instead of quietly measuring the release against itself. */
size_t host_attach_members(Class from, Class to)
{
    unsigned long size;
    const struct host_category *const *categories = (const struct host_category *const *)getsectiondata(&__dso_handle, "__DATA", "__charon_catlist", &size);
    size_t moved = 0;
    if (!categories)
        categories = (const struct host_category *const *)getsectiondata(&__dso_handle, "__DATA_CONST", "__charon_catlist", &size);
    for (size_t index = 0; categories && index < size / sizeof(void *); index++) {
        const struct host_category *category = categories[index];
        if (category->cls != from)
            continue;
        for (uint32_t item = 0; category->instance_methods && item < category->instance_methods->count; item++) {
            const char *name, *types;
            IMP implementation;
            host_method(category->instance_methods, item, &name, &types, &implementation);
            class_replaceMethod(to, sel_registerName(name), implementation, types);
            moved++;
        }
        for (uint32_t item = 0; category->class_methods && item < category->class_methods->count; item++) {
            const char *name, *types;
            IMP implementation;
            host_method(category->class_methods, item, &name, &types, &implementation);
            class_replaceMethod(object_getClass((id)to), sel_registerName(name), implementation, types);
            moved++;
        }
    }
    return moved;
}

/* +alloc on `from` that hands out an instance of `to`, which is what attach.c's alias answers on a
 * device ([release alloc]) and what the port's own factory needs here: it allocates
 * +[NSURLSessionStreamTask alloc], so without this the port's task is an instance of the class of the
 * release's name, which is the empty shell and cannot be resumed by the release. Returns whether it
 * put the method on. */
static Class host_allocated_from;

static id host_alloc_from_released_class(id ignored)
{
    return class_createInstance(host_allocated_from, 0);
}

BOOL host_alloc_from(Class from, Class to)
{
    /* The type encoding is the one the method being replaced carries, read out of the runtime rather
     * than written here: +alloc is (id self, SEL _cmd) and its frame is the two pointers, so the
     * offset is 8 bytes where a pointer is 4 and 16 where it is 8 - "@8:0" is the 32-bit spelling and
     * this host is 64-bit (measured, in test.m's own note). A method installed with an encoding that
     * does not describe its own arguments is a method the runtime and every caller that reads the
     * encoding have to guess about, and the guess is not the method's. A class whose own +alloc is not
     * found gets no method at all, which the caller can see, rather than one typed by a literal. */
    SEL selector = sel_registerName("alloc");
    Method own = class_getClassMethod(from, selector);
    const char *types = own ? method_getTypeEncoding(own) : NULL;
    if (!types)
        return NO;
    /* class_replaceMethod, not class_addMethod: the port's own class answers +alloc already - the
       alias defines it - so adding a second one is refused and the task would still be the port's. */
    if (!class_replaceMethod(object_getClass((id)from), selector, (IMP)host_alloc_from_released_class, types))
        return NO;
    host_allocated_from = to;
    return YES;
}
