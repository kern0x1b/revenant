#include <mach-o/dyld.h>
#include <mach-o/getsect.h>
#include <asl.h>
#include <mach-o/loader.h>
#include <objc/runtime.h>
#include <stdlib.h>
#include <string.h>
#include "charon_alias.h"

#ifdef __LP64__
typedef struct mach_header_64 charon_header;
#else
typedef struct mach_header charon_header;
#endif

extern const charon_header __dso_handle;

static intptr_t charon_slide(void)
{
    for (uint32_t index = 0; index < _dyld_image_count(); index++) {
        if ((const void *)_dyld_get_image_header(index) == (const void *)&__dso_handle)
            return _dyld_get_image_vmaddr_slide(index);
    }
    return 0;
}

static const void *charon_section(const charon_header *header, intptr_t slide, const char *segment, const char *section, unsigned long *size)
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

// Every alias of charon_alias.h in the images loaded so far: a library's categories on
// a class another library aliases are attached after that library is loaded.
static const struct charon_alias *charon_image_aliases(uint32_t image, size_t *count)
{
    unsigned long size = 0;
    const struct charon_alias *aliases = charon_section((const charon_header *)_dyld_get_image_header(image), _dyld_get_image_vmaddr_slide(image), "__DATA", "__charon_alias", &size);
    *count = aliases ? size / sizeof *aliases : 0;
    return aliases;
}

static struct charon_alias *charon_aliases(size_t *count)
{
    size_t total = 0, held;
    for (uint32_t index = 0; index < _dyld_image_count(); index++) {
        charon_image_aliases(index, &held);
        total += held;
    }
    struct charon_alias *found = calloc(total ? total : 1, sizeof *found);
    *count = 0;
    for (uint32_t index = 0; index < _dyld_image_count() && *count < total; index++) {
        const struct charon_alias *aliases = charon_image_aliases(index, &held);
        held = held < total - *count ? held : total - *count;
        if (held)
            memcpy(found + *count, aliases, held * sizeof *found);
        *count += held;
    }
    return found;
}

// A category written on a name charon_alias.h aliases belongs to the release's class, where the
// release has one. Where it has none, the proxy IS the class that name stands for -- the alias's own
// class methods answer as the proxy's own there, and the members ld64 merged into the proxy are
// already on it -- so the category is given the proxy and reaches the methods it adds. Answering nil
// instead dropped the whole category on a release that has no such class.
static Class charon_release_class(Class cls, const struct charon_alias *aliases, size_t count)
{
    for (size_t index = 0; index < count; index++) {
        if (aliases[index].proxy == (const void *)cls) {
            Class release = objc_getClass(aliases[index].name);
            return release ? release : cls;
        }
    }
    return cls;
}

struct charon_list {
    uint32_t flags;
    uint32_t count;
};

struct charon_category {
    const char *name;
    Class cls;
    struct charon_list *instance_methods;
    struct charon_list *class_methods;
    struct charon_protocols *protocols;
    struct charon_list *instance_properties;
};

struct charon_protocols {
    uintptr_t count;
    const struct charon_protocol *list[];
};

struct charon_protocol {
    Class isa;
    const char *name;
};

struct charon_pending {
    Class cls;
    SEL name;
    IMP implementation;
    const char *types;
};

static const uint32_t charon_relative_methods = 0x80000000;

static int32_t charon_offset(const struct charon_list *list, uint32_t index, uint32_t field)
{
    uint32_t size = list->flags & 0xFFFC;
    const int32_t *at = (const int32_t *)((const char *)(list + 1) + index * size + field * sizeof(int32_t));
    return *at;
}

static const char *charon_relative(const struct charon_list *list, uint32_t index, uint32_t field)
{
    uint32_t size = list->flags & 0xFFFC;
    const char *at = (const char *)(list + 1) + index * size + field * sizeof(int32_t);
    return at + charon_offset(list, index, field);
}

static void charon_method(const struct charon_list *list, uint32_t index, const char **name, const char **types, IMP *implementation)
{
    if (list->flags & charon_relative_methods) {
        *name = *(const char *const *)charon_relative(list, index, 0);
        *types = charon_relative(list, index, 1);
        *implementation = (IMP)charon_relative(list, index, 2);
        return;
    }
    uint32_t size = list->flags & 0xFFFC;
    const void *const *entry = (const void *const *)((const char *)(list + 1) + index * size);
    *name = (const char *)entry[0];
    *types = (const char *)entry[1];
    *implementation = (IMP)entry[2];
}

// The question is whether cls or a superclass implements a selector, asked for every category
// method (charon_collect) and every proxy method (charon_adopt_methods). The old answer copied
// each class's method list and scanned the copy, once per question: most of the launch cost.
// class_getInstanceMethod is not used for it: a selector the class lacks goes to
// +resolveInstanceMethod: (and +resolveClassMethod: for a metaclass), a message this constructor
// would send to application classes, possibly before their +initialize, and a resolver that
// installs the selector would make the backport skip it.
// So each class walked is copied once, its selectors are kept sorted, and the walk answers from
// those copies: the lists are the ones the old loop read (none changes before the additions,
// which come after every question), the chain is class_getSuperclass as before, and no message
// is sent. The copies are freed at the end of the constructor.
struct charon_snapshot {
    Class cls;
    SEL *selectors;
    unsigned count;
};

static struct charon_snapshot *charon_snapshots;
static size_t charon_snapshot_slots, charon_snapshot_used;

static int charon_sel_order(const void *left, const void *right)
{
    uintptr_t a = (uintptr_t)*(SEL const *)left, b = (uintptr_t)*(SEL const *)right;
    return (a > b) - (a < b);
}

static size_t charon_snapshot_slot(Class cls, size_t slots)
{
    return ((uintptr_t)cls >> 4) & (slots - 1);
}

static void charon_grow_snapshots(void)
{
    size_t slots = charon_snapshot_slots ? charon_snapshot_slots * 2 : 256;
    struct charon_snapshot *old = charon_snapshots;
    size_t old_slots = charon_snapshot_slots;
    charon_snapshots = calloc(slots, sizeof *charon_snapshots);
    charon_snapshot_slots = slots;
    for (size_t index = 0; index < old_slots; index++) {
        if (!old[index].cls)
            continue;
        size_t slot = charon_snapshot_slot(old[index].cls, slots);
        while (charon_snapshots[slot].cls)
            slot = (slot + 1) & (slots - 1);
        charon_snapshots[slot] = old[index];
    }
    free(old);
}

static const struct charon_snapshot *charon_snapshot_of(Class cls)
{
    if (!charon_snapshot_slots || charon_snapshot_used * 2 >= charon_snapshot_slots)
        charon_grow_snapshots();
    size_t slot = charon_snapshot_slot(cls, charon_snapshot_slots);
    while (charon_snapshots[slot].cls) {
        if (charon_snapshots[slot].cls == cls)
            return &charon_snapshots[slot];
        slot = (slot + 1) & (charon_snapshot_slots - 1);
    }
    unsigned count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    SEL *selectors = calloc(count ? count : 1, sizeof *selectors);
    for (unsigned index = 0; index < count; index++)
        selectors[index] = method_getName(methods[index]);
    free(methods);
    qsort(selectors, count, sizeof *selectors, charon_sel_order);
    charon_snapshots[slot] = (struct charon_snapshot){cls, selectors, count};
    charon_snapshot_used++;
    return &charon_snapshots[slot];
}

static void charon_free_snapshots(void)
{
    for (size_t index = 0; index < charon_snapshot_slots; index++)
        free(charon_snapshots[index].selectors);
    free(charon_snapshots);
    charon_snapshots = NULL;
    charon_snapshot_slots = charon_snapshot_used = 0;
}

static int charon_implements(Class cls, SEL selector)
{
    for (Class current = cls; current; current = class_getSuperclass(current)) {
        const struct charon_snapshot *snapshot = charon_snapshot_of(current);
        if (snapshot->count && bsearch(&selector, snapshot->selectors, snapshot->count, sizeof selector, charon_sel_order))
            return 1;
    }
    return 0;
}

static size_t charon_collect(Class cls, const struct charon_list *list, struct charon_pending *pending, size_t used)
{
    if (!list)
        return used;
    for (uint32_t index = 0; index < list->count; index++) {
        const char *name, *types;
        IMP implementation;
        charon_method(list, index, &name, &types, &implementation);
        SEL selector = sel_registerName(name);
        if (!charon_implements(cls, selector))
            pending[used++] = (struct charon_pending){cls, selector, implementation, types};
    }
    return used;
}

static void charon_add_properties(Class cls, const struct charon_list *list)
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

// An alias of charon_alias.h is a subclass of the release's class, so that a subclass an
// application writes of the name inherits the release's class and is laid out after its
// instance variables. The compiler cannot name a class the release does not export, so the
// superclass is written here, into the second word of the alias's class and metaclass (the
// superclass of objc's class layout), before the runtime first uses the alias; using it then
// lays it out from the release's class, which is what the check after it reads. An image loaded
// with the library whose class used the alias earlier - a subclass with a +load of its own - has
// had it laid out on NSObject, which the write cannot change: it is taken back, and the log
// names the alias.
static void charon_reparent(Class proxy, Class release)
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

// ld64 merges a category written on an alias into the class the alias names, CharonName,
// since both are in one image, so the release's class takes from CharonName whatever it and
// its superclasses lack. Where the release's class has the method itself, CharonName's copy
// would stand before it for a subclass, so it is given the release's implementation. CharonName's
// own class methods are selectors of the root class, which the release's class answers already.
static unsigned charon_method_count(Class cls)
{
    unsigned count = 0;
    free(class_copyMethodList(cls, &count));
    return count;
}

static size_t charon_adopt_methods(Class release, Class proxy, Class own, struct charon_pending *pending, size_t used)
{
    unsigned count = 0;
    Method *methods = class_copyMethodList(proxy, &count);
    for (unsigned index = 0; index < count; index++) {
        SEL selector = method_getName(methods[index]);
        if (!charon_implements(release, selector))
            pending[used++] = (struct charon_pending){release, selector, method_getImplementation(methods[index]), method_getTypeEncoding(methods[index])};
        else if (!own || !charon_implements(own, selector))
            method_setImplementation(methods[index], class_getMethodImplementation(release, selector));
    }
    free(methods);
    return used;
}

static void charon_adopt_declarations(Class release, Class proxy)
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

__attribute__((constructor)) static void charon_backports_attach(void)
{
    unsigned long size;
    const struct charon_category *const *categories = (const struct charon_category *const *)charon_section(&__dso_handle, charon_slide(), "__DATA", "__charon_catlist", &size);
    size_t count = categories ? size / sizeof(void *) : 0;
    size_t capacity = 0;
    for (size_t index = 0; index < count; index++) {
        const struct charon_category *category = categories[index];
        capacity += (category->instance_methods ? category->instance_methods->count : 0) + (category->class_methods ? category->class_methods->count : 0);
    }
    unsigned long own_size = 0;
    const struct charon_alias *own = charon_section(&__dso_handle, charon_slide(), "__DATA", "__charon_alias", &own_size);
    size_t own_count = own ? own_size / sizeof *own : 0;
    Class *releases = calloc(own_count ? own_count : 1, sizeof *releases);
    for (size_t index = 0; index < own_count; index++) {
        releases[index] = objc_getClass(own[index].name);
        if (!releases[index])
            continue;
        // class_copyMethodList reads a class as realized without checking; charon_reparent realizes it.
        charon_reparent((Class)own[index].proxy, releases[index]);
        capacity += charon_method_count((Class)own[index].proxy) + charon_method_count(object_getClass((id)own[index].proxy));
    }
    size_t alias_count;
    struct charon_alias *aliases = charon_aliases(&alias_count);
    Class *classes = calloc(count ? count : 1, sizeof *classes);
    for (size_t index = 0; index < count; index++) {
        Class cls = categories[index]->cls;
        classes[index] = cls ? charon_release_class(cls, aliases, alias_count) : Nil;
    }
    free(aliases);
    struct charon_pending *pending = calloc(capacity ? capacity : 1, sizeof *pending);
    size_t used = 0;
    for (size_t index = 0; index < count; index++) {
        const struct charon_category *category = categories[index];
        Class cls = classes[index];
        if (!cls)
            continue;
        objc_lookUpClass(class_getName(cls));
        used = charon_collect(cls, category->instance_methods, pending, used);
        used = charon_collect(object_getClass((id)cls), category->class_methods, pending, used);
    }
    for (size_t index = 0; index < own_count; index++) {
        if (!releases[index])
            continue;
        Class proxy = (Class)own[index].proxy;
        used = charon_adopt_methods(releases[index], proxy, Nil, pending, used);
        used = charon_adopt_methods(object_getClass((id)releases[index]), object_getClass((id)proxy), object_getClass((id)objc_getClass("NSObject")), pending, used);
    }
    for (size_t index = 0; index < used; index++)
        class_addMethod(pending[index].cls, pending[index].name, pending[index].implementation, pending[index].types);
    free(pending);
    for (size_t index = 0; index < own_count; index++) {
        if (releases[index])
            charon_adopt_declarations(releases[index], (Class)own[index].proxy);
    }
    free(releases);
    for (size_t index = 0; index < count; index++) {
        const struct charon_category *category = categories[index];
        Class cls = classes[index];
        if (!cls)
            continue;
        for (uintptr_t protocol = 0; category->protocols && protocol < category->protocols->count; protocol++) {
            Protocol *found = objc_getProtocol(category->protocols->list[protocol]->name);
            if (found && !class_conformsToProtocol(cls, found))
                class_addProtocol(cls, found);
        }
        charon_add_properties(cls, category->instance_properties);
    }
    free(classes);
    charon_free_snapshots();
}
