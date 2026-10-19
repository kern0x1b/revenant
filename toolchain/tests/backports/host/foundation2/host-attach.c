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
    const struct host_category *const *categories = (const struct host_category *const *)getsectiondata(&__dso_handle, "__DATA", "__revenant_catlist", &size);
    if (!categories)
        categories = (const struct host_category *const *)getsectiondata(&__dso_handle, "__DATA_CONST", "__revenant_catlist", &size);
    for (size_t index = 0; categories && index < size / sizeof(void *); index++) {
        const struct host_category *category = categories[index];
        host_add(category->cls, category->instance_methods, prefix);
        host_add(object_getClass((id)category->cls), category->class_methods, prefix);
    }
}

size_t host_attach_members(Class from, Class to)
{
    unsigned long size;
    const struct host_category *const *categories = (const struct host_category *const *)getsectiondata(&__dso_handle, "__DATA", "__revenant_catlist", &size);
    size_t moved = 0;
    if (!categories)
        categories = (const struct host_category *const *)getsectiondata(&__dso_handle, "__DATA_CONST", "__revenant_catlist", &size);
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

static Class host_allocated_from;

static id host_alloc_from_released_class(id ignored)
{
    return class_createInstance(host_allocated_from, 0);
}

BOOL host_alloc_from(Class from, Class to)
{
    SEL selector = sel_registerName("alloc");
    Method own = class_getClassMethod(from, selector);
    const char *types = own ? method_getTypeEncoding(own) : NULL;
    if (!types)
        return NO;
    if (!class_replaceMethod(object_getClass((id)from), selector, (IMP)host_alloc_from_released_class, types))
        return NO;
    host_allocated_from = to;
    return YES;
}
