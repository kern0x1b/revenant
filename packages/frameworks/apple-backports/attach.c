#include <mach-o/dyld.h>
#include <mach-o/getsect.h>
#include <asl.h>
#include <mach-o/loader.h>
#include <objc/runtime.h>
#include <stdlib.h>
#include <string.h>
#include "revenant_alias.h"

#ifdef __LP64__
typedef struct mach_header_64 revenant_header;
#else
typedef struct mach_header revenant_header;
#endif

extern const revenant_header __dso_handle;

static intptr_t revenant_slide(void)
{
    for (uint32_t index = 0; index < _dyld_image_count(); index++) {
        if ((const void *)_dyld_get_image_header(index) == (const void *)&__dso_handle)
            return _dyld_get_image_vmaddr_slide(index);
    }
    return 0;
}

static const void *revenant_section(const revenant_header *header, intptr_t slide, const char *segment, const char *section, unsigned long *size)
{
#ifdef __LP64__
    const struct section_64 *found = getsectbynamefromheader_64(header, segment, section);
#else
    const struct section *found = getsectbynamefromheader(header, segment, section);
#endif
    if (!found || found->size == 0)
        return NULL;
    *size = (unsigned long)found->size;
    return (const void *)((uintptr_t)found->addr + slide);
}

static const struct revenant_alias *revenant_image_aliases(uint32_t image, size_t *count)
{
    unsigned long size = 0;
    const struct revenant_alias *aliases = revenant_section((const revenant_header *)_dyld_get_image_header(image), _dyld_get_image_vmaddr_slide(image), "__DATA", "__port_alias", &size);
    *count = aliases ? size / sizeof *aliases : 0;
    return aliases;
}

static struct revenant_alias *revenant_aliases(size_t *count)
{
    size_t total = 0, held;
    for (uint32_t index = 0; index < _dyld_image_count(); index++) {
        revenant_image_aliases(index, &held);
        total += held;
    }
    struct revenant_alias *found = calloc(total ? total : 1, sizeof *found);
    *count = 0;
    for (uint32_t index = 0; index < _dyld_image_count() && *count < total; index++) {
        const struct revenant_alias *aliases = revenant_image_aliases(index, &held);
        held = held < total - *count ? held : total - *count;
        if (held)
            memcpy(found + *count, aliases, held * sizeof *found);
        *count += held;
    }
    return found;
}

static Class revenant_release_class(Class cls, const struct revenant_alias *aliases, size_t count)
{
    for (size_t index = 0; index < count; index++) {
        if (aliases[index].proxy == (const void *)cls) {
            Class release = objc_getClass(aliases[index].name);
            return release ? release : cls;
        }
    }
    return cls;
}

struct revenant_list {
    uint32_t flags;
    uint32_t count;
};

struct revenant_category {
    const char *name;
    Class cls;
    struct revenant_list *instance_methods;
    struct revenant_list *class_methods;
    struct revenant_protocols *protocols;
    struct revenant_list *instance_properties;
};

struct revenant_protocols {
    uintptr_t count;
    const struct revenant_protocol *list[];
};

struct revenant_protocol {
    Class isa;
    const char *name;
};

struct revenant_pending {
    Class cls;
    SEL name;
    IMP implementation;
    const char *types;
};

static const uint32_t revenant_relative_methods = 0x80000000;

static int32_t revenant_offset(const struct revenant_list *list, uint32_t index, uint32_t field)
{
    uint32_t size = list->flags & 0xFFFC;
    const int32_t *at = (const int32_t *)((const char *)(list + 1) + index * size + field * sizeof(int32_t));
    return *at;
}

static const char *revenant_relative(const struct revenant_list *list, uint32_t index, uint32_t field)
{
    uint32_t size = list->flags & 0xFFFC;
    const char *at = (const char *)(list + 1) + index * size + field * sizeof(int32_t);
    return at + revenant_offset(list, index, field);
}

static void revenant_method(const struct revenant_list *list, uint32_t index, const char **name, const char **types, IMP *implementation)
{
    if (list->flags & revenant_relative_methods) {
        *name = *(const char *const *)revenant_relative(list, index, 0);
        *types = revenant_relative(list, index, 1);
        *implementation = (IMP)revenant_relative(list, index, 2);
        return;
    }
    uint32_t size = list->flags & 0xFFFC;
    const void *const *entry = (const void *const *)((const char *)(list + 1) + index * size);
    *name = (const char *)entry[0];
    *types = (const char *)entry[1];
    *implementation = (IMP)entry[2];
}

struct revenant_snapshot {
    Class cls;
    SEL *selectors;
    unsigned count;
};

static struct revenant_snapshot *revenant_snapshots;
static size_t revenant_snapshot_slots, revenant_snapshot_used;

static int revenant_sel_order(const void *left, const void *right)
{
    uintptr_t a = (uintptr_t)*(SEL const *)left, b = (uintptr_t)*(SEL const *)right;
    return (a > b) - (a < b);
}

static size_t revenant_snapshot_slot(Class cls, size_t slots)
{
    return ((uintptr_t)cls >> 4) & (slots - 1);
}

static void revenant_grow_snapshots(void)
{
    size_t slots = revenant_snapshot_slots ? revenant_snapshot_slots * 2 : 256;
    struct revenant_snapshot *old = revenant_snapshots;
    size_t old_slots = revenant_snapshot_slots;
    revenant_snapshots = calloc(slots, sizeof *revenant_snapshots);
    revenant_snapshot_slots = slots;
    for (size_t index = 0; index < old_slots; index++) {
        if (!old[index].cls)
            continue;
        size_t slot = revenant_snapshot_slot(old[index].cls, slots);
        while (revenant_snapshots[slot].cls)
            slot = (slot + 1) & (slots - 1);
        revenant_snapshots[slot] = old[index];
    }
    free(old);
}

static const struct revenant_snapshot *revenant_snapshot_of(Class cls)
{
    if (!revenant_snapshot_slots || revenant_snapshot_used * 2 >= revenant_snapshot_slots)
        revenant_grow_snapshots();
    size_t slot = revenant_snapshot_slot(cls, revenant_snapshot_slots);
    while (revenant_snapshots[slot].cls) {
        if (revenant_snapshots[slot].cls == cls)
            return &revenant_snapshots[slot];
        slot = (slot + 1) & (revenant_snapshot_slots - 1);
    }
    unsigned count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    SEL *selectors = calloc(count ? count : 1, sizeof *selectors);
    for (unsigned index = 0; index < count; index++)
        selectors[index] = method_getName(methods[index]);
    free(methods);
    qsort(selectors, count, sizeof *selectors, revenant_sel_order);
    revenant_snapshots[slot] = (struct revenant_snapshot){cls, selectors, count};
    revenant_snapshot_used++;
    return &revenant_snapshots[slot];
}

static void revenant_free_snapshots(void)
{
    for (size_t index = 0; index < revenant_snapshot_slots; index++)
        free(revenant_snapshots[index].selectors);
    free(revenant_snapshots);
    revenant_snapshots = NULL;
    revenant_snapshot_slots = revenant_snapshot_used = 0;
}

static int revenant_implements(Class cls, SEL selector)
{
    for (Class current = cls; current; current = class_getSuperclass(current)) {
        const struct revenant_snapshot *snapshot = revenant_snapshot_of(current);
        if (snapshot->count && bsearch(&selector, snapshot->selectors, snapshot->count, sizeof selector, revenant_sel_order))
            return 1;
    }
    return 0;
}

static size_t revenant_collect(Class cls, const struct revenant_list *list, struct revenant_pending *pending, size_t used)
{
    if (!list)
        return used;
    for (uint32_t index = 0; index < list->count; index++) {
        const char *name, *types;
        IMP implementation;
        revenant_method(list, index, &name, &types, &implementation);
        SEL selector = sel_registerName(name);
        if (!revenant_implements(cls, selector))
            pending[used++] = (struct revenant_pending){cls, selector, implementation, types};
    }
    return used;
}

static void revenant_add_properties(Class cls, const struct revenant_list *list)
{
    if (!list || !class_addProperty)
        return;
    uint32_t size = list->flags & 0xFFFC;
    for (uint32_t index = 0; index < list->count; index++) {
        const char *const *entry = (const char *const *)((const char *)(list + 1) + index * size);
        if (class_getProperty(cls, entry[0]))
            continue;
        char *attributes = strdup(entry[1]);
        unsigned count = 1;
        for (char *cursor = attributes; *cursor; cursor++)
            count += *cursor == ',';
        objc_property_attribute_t parsed[count];
        char names[count][2];
        unsigned used = 0;
        char *state;
        for (char *item = strtok_r(attributes, ",", &state); item; item = strtok_r(NULL, ",", &state)) {
            names[used][0] = item[0];
            names[used][1] = 0;
            parsed[used] = (objc_property_attribute_t){names[used], item + 1};
            used++;
        }
        class_addProperty(cls, entry[0], parsed, used);
        free(attributes);
    }
}

static void revenant_reparent(Class proxy, Class release)
{
    Class *words = (Class *)(void *)proxy;
    Class *meta = (Class *)(void *)object_getClass((id)proxy);
    Class superclass = words[1], metasuperclass = meta[1];
    words[1] = release;
    meta[1] = object_getClass((id)release);
    objc_lookUpClass(class_getName(proxy));
    if (class_getSuperclass(proxy) == release && class_getInstanceSize(proxy) == class_getInstanceSize(release))
        return;
    words[1] = superclass;
    meta[1] = metasuperclass;
    asl_log(NULL, NULL, ASL_LEVEL_ERR, "apple-backports: %s was laid out before the library's loader ran, so it stays a subclass of NSObject and a subclass of %s does not inherit %s",
            class_getName(proxy), class_getName(release), class_getName(release));
}

static unsigned revenant_method_count(Class cls)
{
    unsigned count = 0;
    free(class_copyMethodList(cls, &count));
    return count;
}

static size_t revenant_adopt_methods(Class release, Class proxy, Class own, struct revenant_pending *pending, size_t used)
{
    unsigned count = 0;
    Method *methods = class_copyMethodList(proxy, &count);
    for (unsigned index = 0; index < count; index++) {
        SEL selector = method_getName(methods[index]);
        if (!revenant_implements(release, selector))
            pending[used++] = (struct revenant_pending){release, selector, method_getImplementation(methods[index]), method_getTypeEncoding(methods[index])};
        else if (!own || !revenant_implements(own, selector))
            method_setImplementation(methods[index], class_getMethodImplementation(release, selector));
    }
    free(methods);
    return used;
}

static void revenant_adopt_declarations(Class release, Class proxy)
{
    unsigned count = 0;
    Protocol **protocols = class_copyProtocolList(proxy, &count);
    for (unsigned index = 0; index < count; index++) {
        if (!class_conformsToProtocol(release, protocols[index]))
            class_addProtocol(release, protocols[index]);
    }
    free(protocols);
    if (!class_addProperty)
        return;
    objc_property_t *properties = class_copyPropertyList(proxy, &count);
    for (unsigned index = 0; index < count; index++) {
        const char *name = property_getName(properties[index]);
        if (class_getProperty(release, name))
            continue;
        unsigned held = 0;
        objc_property_attribute_t *attributes = property_copyAttributeList(properties[index], &held);
        class_addProperty(release, name, attributes, held);
        free(attributes);
    }
    free(properties);
}

__attribute__((constructor)) static void revenant_backports_attach(void)
{
    unsigned long size;
    const struct revenant_category *const *categories = (const struct revenant_category *const *)revenant_section(&__dso_handle, revenant_slide(), "__DATA", "__port_catlist", &size);
    size_t count = categories ? size / sizeof(void *) : 0;
    size_t capacity = 0;
    for (size_t index = 0; index < count; index++) {
        const struct revenant_category *category = categories[index];
        capacity += (category->instance_methods ? category->instance_methods->count : 0) + (category->class_methods ? category->class_methods->count : 0);
    }
    unsigned long own_size = 0;
    const struct revenant_alias *own = revenant_section(&__dso_handle, revenant_slide(), "__DATA", "__port_alias", &own_size);
    size_t own_count = own ? own_size / sizeof *own : 0;
    Class *releases = calloc(own_count ? own_count : 1, sizeof *releases);
    for (size_t index = 0; index < own_count; index++) {
        releases[index] = objc_getClass(own[index].name);
        if (!releases[index])
            continue;
        revenant_reparent((Class)own[index].proxy, releases[index]);
        capacity += revenant_method_count((Class)own[index].proxy) + revenant_method_count(object_getClass((id)own[index].proxy));
    }
    size_t alias_count;
    struct revenant_alias *aliases = revenant_aliases(&alias_count);
    Class *classes = calloc(count ? count : 1, sizeof *classes);
    for (size_t index = 0; index < count; index++) {
        Class cls = categories[index]->cls;
        classes[index] = cls ? revenant_release_class(cls, aliases, alias_count) : Nil;
    }
    free(aliases);
    struct revenant_pending *pending = calloc(capacity ? capacity : 1, sizeof *pending);
    size_t used = 0;
    for (size_t index = 0; index < count; index++) {
        const struct revenant_category *category = categories[index];
        Class cls = classes[index];
        if (!cls)
            continue;
        objc_lookUpClass(class_getName(cls));
        used = revenant_collect(cls, category->instance_methods, pending, used);
        used = revenant_collect(object_getClass((id)cls), category->class_methods, pending, used);
    }
    for (size_t index = 0; index < own_count; index++) {
        if (!releases[index])
            continue;
        Class proxy = (Class)own[index].proxy;
        used = revenant_adopt_methods(releases[index], proxy, Nil, pending, used);
        used = revenant_adopt_methods(object_getClass((id)releases[index]), object_getClass((id)proxy), object_getClass((id)objc_getClass("NSObject")), pending, used);
    }
    for (size_t index = 0; index < used; index++)
        class_addMethod(pending[index].cls, pending[index].name, pending[index].implementation, pending[index].types);
    free(pending);
    for (size_t index = 0; index < own_count; index++) {
        if (releases[index])
            revenant_adopt_declarations(releases[index], (Class)own[index].proxy);
    }
    free(releases);
    for (size_t index = 0; index < count; index++) {
        const struct revenant_category *category = categories[index];
        Class cls = classes[index];
        if (!cls)
            continue;
        for (uintptr_t protocol = 0; category->protocols && protocol < category->protocols->count; protocol++) {
            Protocol *found = objc_getProtocol(category->protocols->list[protocol]->name);
            if (found && !class_conformsToProtocol(cls, found))
                class_addProtocol(cls, found);
        }
        revenant_add_properties(cls, category->instance_properties);
    }
    free(classes);
    revenant_free_snapshots();
}
