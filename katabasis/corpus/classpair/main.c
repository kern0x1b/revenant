// Class objects laid out the way the Swift runtime lays them out, handed to libobjc the way it hands them over.
//
// Swift keeps its classes in the platform's objc_class layout (arm64: isa, superclass, two cache words, a data word with
// the class_ro_t) and gives them to the Objective-C runtime in place: a class the compiler emitted and listed in
// __objc_clsrolist is realized by the first message that reaches it, one the Swift runtime builds is handed over through
// objc_readClassPair or _objc_realizeClassFromSwift, and a class with no name in its ro is named by the hook registered
// through objc_setHook_lazyClassNamer. iOS 6 libobjc has none of the three calls and cannot read the layout at all.
//
// The program builds one of each and prints what the runtime answers. It is built for macOS, where objc4 is the real thing,
// and expected.txt is what it printed there: the translated program on the iPad 2 must print the same.
#include <objc/message.h>
#include <objc/runtime.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct cls {
    struct cls *isa;
    struct cls *super;
    const void *cache;
    uintptr_t cache_mask;
    uintptr_t bits;
};

struct ro {
    uint32_t flags;
    uint32_t instance_start;
    uint32_t instance_size;
    uint32_t reserved;
    const void *ivar_layout;  // a metaclass's: the class it belongs to, which a lazily named class needs
    const char *name;
    const void *methods;
    const void *protocols;
    const void *ivars;
    const void *weak_ivar_layout;
    const void *properties;
};

struct method {
    const char *name;
    const char *types;
    void *imp;
};

struct method_list {
    uint32_t entsize;
    uint32_t count;
    struct method methods[4];
};

extern struct cls OBJC_CLASS_$_NSObject;
extern struct cls OBJC_METACLASS_$_NSObject;
extern char _objc_empty_cache;
extern Class objc_readClassPair(Class cls, const void *info);
extern Class _objc_realizeClassFromSwift(Class cls, void *previously);
typedef const char *(*lazy_namer)(Class);
extern void objc_setHook_lazyClassNamer(lazy_namer hook, lazy_namer *previous);

enum { RO_META = 1, RO_ROOT = 2, RO_ARC = 0x80 };

static long ping(id self, SEL cmd, long x) { return x + 1; }
static long class_ping(id self, SEL cmd, long x) { return x + 100; }
static long pong(id self, SEL cmd, long x) { return x + 2; }

// 1. A class the compiler laid out statically and listed only in __objc_clsrolist: nothing hands it over.
static struct method_list static_methods = {24, 1, {{"xl_ping:", "q24@0:8q16", ping}}};
static struct method_list static_class_methods = {24, 1, {{"xl_classPing:", "q24@0:8q16", class_ping}}};
__attribute__((section("__DATA,__objc_const"))) static struct ro static_ro = {RO_ARC, 8, 8, 0, 0, "XLPairStatic", &static_methods, 0, 0, 0, 0};
__attribute__((section("__DATA,__objc_const"))) static struct ro static_meta_ro = {RO_ARC | RO_META, 40, 40, 0, 0, "XLPairStatic", &static_class_methods, 0, 0, 0, 0};
static struct cls static_meta = {&OBJC_METACLASS_$_NSObject, &OBJC_METACLASS_$_NSObject, &_objc_empty_cache, 0, (uintptr_t)&static_meta_ro};
static struct cls static_class = {&static_meta, &OBJC_CLASS_$_NSObject, &_objc_empty_cache, 0, (uintptr_t)&static_ro};
__attribute__((used, section("__DATA,__objc_clsrolist,regular,no_dead_strip"))) static const void *static_rolist[] = {&static_ro, &static_meta_ro};

// 1b. A root class of the program's own (as libswiftCore's _SwiftObject is) with a Swift class beneath it that the compiler listed
// in __objc_classlist: the Objective-C runtime registers the listed ones at load, so a lookup by name finds them from the start.
static id root_self(id self, SEL cmd) { return self; }
static Class root_class(id self, SEL cmd) { return object_getClass(self); }
static struct method_list root_methods = {24, 2, {{"self", "@16@0:8", root_self}, {"class", "#16@0:8", root_class}}};
static struct method_list root_class_methods = {24, 2, {{"self", "@16@0:8", root_self}, {"class", "#16@0:8", root_self}}};
__attribute__((section("__DATA,__objc_const"))) static struct ro root_ro = {RO_ARC | RO_ROOT, 8, 8, 0, 0, "XLPairRoot", &root_methods, 0, 0, 0, 0};
__attribute__((section("__DATA,__objc_const"))) static struct ro root_meta_ro = {RO_ARC | RO_META | RO_ROOT, 40, 40, 0, 0, "XLPairRoot", &root_class_methods, 0, 0, 0, 0};
extern struct cls root_class_object;
static struct cls root_meta = {&root_meta, &root_class_object, &_objc_empty_cache, 0, (uintptr_t)&root_meta_ro};
struct cls root_class_object = {&root_meta, 0, &_objc_empty_cache, 0, (uintptr_t)&root_ro};
static struct method_list listed_methods = {24, 1, {{"xl_ping:", "q24@0:8q16", ping}}};
static struct method_list listed_class_methods = {24, 1, {{"xl_classPing:", "q24@0:8q16", class_ping}}};
__attribute__((section("__DATA,__objc_const"))) static struct ro listed_ro = {RO_ARC, 8, 8, 0, 0, "XLPairListed", &listed_methods, 0, 0, 0, 0};
__attribute__((section("__DATA,__objc_const"))) static struct ro listed_meta_ro = {RO_ARC | RO_META, 40, 40, 0, 0, "XLPairListed", &listed_class_methods, 0, 0, 0, 0};
static struct cls listed_meta = {&root_meta, &root_meta, &_objc_empty_cache, 0, (uintptr_t)&listed_meta_ro};
// bits 3: Swift's class flags (FAST_IS_SWIFT_LEGACY | FAST_IS_SWIFT_STABLE), as on a class the Swift compiler emits
static struct cls listed_class = {&listed_meta, &root_class_object, &_objc_empty_cache, 0, (uintptr_t)((char *)&listed_ro + 3)};
__attribute__((used, section("__DATA,__objc_classlist,regular,no_dead_strip"))) static struct cls *listed_classlist[] = {&root_class_object, &listed_class};
// what the compiler emits for any Objective-C image, and without which the runtime reads no class list from it
__attribute__((used, section("__DATA,__objc_imageinfo,regular,no_dead_strip"))) static const uint32_t image_info[2] = {0, 64};

// 1c. A classlist class whose immediate superclass is laid out ONLY in __objc_clsrolist, with no ancestor of its own
// (review of f248398: SplitGuestLayoutClasses's ancestor walk consulted only the classes __objc_classlist gave it, so a
// clsrolist-only ancestor was invisible and this classlist class was silently kept at host layout instead of moved).
// Its own superclass is root_class_object (not Null directly): a clsrolist-only class with no ancestor at all would also
// need to answer "class" as a bare host root once shadow-built (xl_build_shadow realizes a host superclass by messaging
// it), which a fresh objc_allocateClassPair(Nil, ...) root does not, before it has any NSObject-descended ancestor to
// inherit that from -- a real limitation of the shadow builder, orthogonal to the ancestor-walk bug this fixture is for.
__attribute__((section("__DATA,__objc_const"))) static struct ro clsroot_ro = {RO_ARC, 8, 8, 0, 0, "XLPairClsroRoot", 0, 0, 0, 0, 0};
__attribute__((section("__DATA,__objc_const"))) static struct ro clsroot_meta_ro = {RO_ARC | RO_META, 40, 40, 0, 0, "XLPairClsroRoot", 0, 0, 0, 0, 0};
static struct cls clsroot_meta = {&root_meta, &root_meta, &_objc_empty_cache, 0, (uintptr_t)&clsroot_meta_ro};
static struct cls clsroot_class = {&clsroot_meta, &root_class_object, &_objc_empty_cache, 0, (uintptr_t)&clsroot_ro};
__attribute__((used, section("__DATA,__objc_clsrolist,regular,no_dead_strip"))) static const void *clsroot_rolist[] = {&clsroot_ro, &clsroot_meta_ro};
static struct method_list clsrochild_methods = {24, 1, {{"xl_ping:", "q24@0:8q16", ping}}};
static struct method_list clsrochild_class_methods = {24, 1, {{"xl_classPing:", "q24@0:8q16", class_ping}}};
__attribute__((section("__DATA,__objc_const"))) static struct ro clsrochild_ro = {RO_ARC, 8, 8, 0, 0, "XLPairListedOverClsro", &clsrochild_methods, 0, 0, 0, 0};
__attribute__((section("__DATA,__objc_const"))) static struct ro clsrochild_meta_ro = {RO_ARC | RO_META, 40, 40, 0, 0, "XLPairListedOverClsro", &clsrochild_class_methods, 0, 0, 0, 0};
static struct cls clsrochild_meta = {&root_meta, &clsroot_meta, &_objc_empty_cache, 0, (uintptr_t)&clsrochild_meta_ro};
// bits 3: Swift's class flags, same as listed_class above -- what makes SplitGuestLayoutClasses consider moving it
static struct cls clsrochild_class = {&clsrochild_meta, &clsroot_class, &_objc_empty_cache, 0, (uintptr_t)((char *)&clsrochild_ro + 3)};
__attribute__((used, section("__DATA,__objc_classlist,regular,no_dead_strip"))) static struct cls *clsrochild_classlist[] = {&clsrochild_class};

// The class the Swift runtime builds for itself: objects on the heap, from an ro it fills in.
static struct cls *build(const char *name, struct cls *super, struct method_list *methods, struct method_list *class_methods,
                         struct cls **meta_out)
{
    struct cls *c = calloc(1, sizeof *c), *m = calloc(1, sizeof *m);
    struct ro *ro = calloc(1, sizeof *ro), *meta_ro = calloc(1, sizeof *meta_ro);
    ro->flags = RO_ARC;
    ro->instance_start = ro->instance_size = 8;
    ro->name = name;
    ro->methods = methods;
    meta_ro->flags = RO_ARC | RO_META;
    meta_ro->instance_start = meta_ro->instance_size = 40;
    meta_ro->ivar_layout = c;
    meta_ro->name = name;
    meta_ro->methods = class_methods;
    m->isa = &OBJC_METACLASS_$_NSObject;
    m->super = super == &OBJC_CLASS_$_NSObject ? &OBJC_METACLASS_$_NSObject : super->isa;
    m->cache = &_objc_empty_cache;
    m->bits = (uintptr_t)meta_ro;
    c->isa = m;
    c->super = super;
    c->cache = &_objc_empty_cache;
    c->bits = (uintptr_t)ro;
    if (meta_out)
        *meta_out = m;
    return c;
}

static const char *namer(Class cls) { return strdup("XLPairLazy"); }

static void report(const char *label, struct cls *c, struct cls *super, struct cls *meta, int nsobject)
{
    Class cls = (Class)c;
    SEL ping_sel = sel_registerName("xl_ping:"), class_ping_sel = sel_registerName("xl_classPing:");
    SEL self_sel = sel_registerName("self"), class_sel = sel_registerName("class");
    printf("%s: self is the class: %d\n", label, ((id(*)(id, SEL))objc_msgSend)((id)cls, self_sel) == (id)cls);
    printf("%s: name: %s\n", label, class_getName(cls));
    printf("%s: superclass: %s, the expected one: %d\n", label, class_getName(class_getSuperclass(cls)),
           class_getSuperclass(cls) == (Class)super);
    printf("%s: isa is the metaclass: %d, and a metaclass: %d\n", label, object_getClass((id)cls) == (Class)meta,
           class_isMetaClass(object_getClass((id)cls)));
    printf("%s: class method: %ld\n", label, ((long (*)(id, SEL, long))objc_msgSend)((id)cls, class_ping_sel, 41));
    printf("%s: instances respond: %d, the class responds to the class method: %d\n", label,
           class_respondsToSelector(cls, ping_sel), class_respondsToSelector(object_getClass((id)cls), class_ping_sel));
    id instance = class_createInstance(cls, 0);
    printf("%s: instance class is the class: %d\n", label, object_getClass(instance) == cls);
    printf("%s: instance method: %ld\n", label, ((long (*)(id, SEL, long))objc_msgSend)(instance, ping_sel, 41));
    printf("%s: [instance class] is the class: %d\n", label, ((id(*)(id, SEL))objc_msgSend)(instance, class_sel) == (id)cls);
    if (nsobject)
        printf("%s: subclass of NSObject: %ld\n", label,
               (long)((char (*)(id, SEL, Class))objc_msgSend)((id)cls, sel_registerName("isSubclassOfClass:"), objc_getClass("NSObject")));
}

int main(void)
{
    setvbuf(stdout, 0, _IONBF, 0);
    // 1. the static class, before anything hands it over
    report("static", &static_class, &OBJC_CLASS_$_NSObject, &static_meta, 1);

    // 1b. the listed Swift class under a root of the program's own: registered at load, found by name before anything else
    printf("listed: found by name: %d\n", objc_getClass("XLPairListed") == (Class)&listed_class);
    printf("listed: root found by name: %d\n", objc_getClass("XLPairRoot") == (Class)&root_class_object);
    report("listed", &listed_class, &root_class_object, &listed_meta, 0);

    // 2. a class built at run time and handed over through objc_readClassPair
    static struct method_list built_methods = {24, 1, {{"xl_ping:", "q24@0:8q16", ping}}};
    static struct method_list built_class_methods = {24, 1, {{"xl_classPing:", "q24@0:8q16", class_ping}}};
    struct cls *meta;
    struct cls *built = build("XLPairBuilt", &OBJC_CLASS_$_NSObject, &built_methods, &built_class_methods, &meta);
    printf("readClassPair: returns the class: %d\n", objc_readClassPair((Class)built, (const void *)&(uintptr_t){0}) == (Class)built);
    printf("readClassPair: found by name: %d\n", objc_getClass("XLPairBuilt") == (Class)built);
    report("built", built, &OBJC_CLASS_$_NSObject, meta, 1);

    // 3. a subclass of it, which inherits the method and overrides the other
    static struct method_list sub_methods = {24, 1, {{"xl_pong:", "q24@0:8q16", pong}}};
    struct cls *sub_meta;
    struct cls *sub = build("XLPairSub", built, &sub_methods, 0, &sub_meta);
    printf("subclass: returns the class: %d\n", objc_readClassPair((Class)sub, (const void *)&(uintptr_t){0}) == (Class)sub);
    id sub_instance = class_createInstance((Class)sub, 0);
    printf("subclass: superclass is the built one: %d\n", class_getSuperclass((Class)sub) == (Class)built);
    printf("subclass: inherited method: %ld\n", ((long (*)(id, SEL, long))objc_msgSend)(sub_instance, sel_registerName("xl_ping:"), 41));
    printf("subclass: own method: %ld\n", ((long (*)(id, SEL, long))objc_msgSend)(sub_instance, sel_registerName("xl_pong:"), 41));
    printf("subclass: inherited class method: %ld\n", ((long (*)(id, SEL, long))objc_msgSend)((id)sub, sel_registerName("xl_classPing:"), 41));
    printf("subclass: instance is a kind of the built class: %ld\n",
           (long)((char (*)(id, SEL, Class))objc_msgSend)(sub_instance, sel_registerName("isKindOfClass:"), (Class)built));

    // 4. a class built at run time and realized through _objc_realizeClassFromSwift, new (previously nil)
    struct cls *realized = build("XLPairRealized", &OBJC_CLASS_$_NSObject, &built_methods, &built_class_methods, 0);
    printf("realizeClassFromSwift: returns the class: %d\n", _objc_realizeClassFromSwift((Class)realized, 0) == (Class)realized);
    printf("realizeClassFromSwift: found by name: %d\n", objc_getClass("XLPairRealized") == (Class)realized);
    printf("realizeClassFromSwift: superclass: %s\n", class_getName(class_getSuperclass((Class)realized)));

    // 5. a class with no name in its ro: the hook the Swift runtime registers names it
    lazy_namer previous = 0;
    objc_setHook_lazyClassNamer(namer, &previous);
    struct cls *lazy = build(0, &OBJC_CLASS_$_NSObject, &built_methods, &built_class_methods, 0);
    printf("lazy: returns the class: %d\n", objc_readClassPair((Class)lazy, (const void *)&(uintptr_t){0}) == (Class)lazy);
    printf("lazy: name: %s\n", class_getName((Class)lazy));
    printf("lazy: instance method: %ld\n",
           ((long (*)(id, SEL, long))objc_msgSend)(class_createInstance((Class)lazy, 0), sel_registerName("xl_ping:"), 41));
    return 0;
}
