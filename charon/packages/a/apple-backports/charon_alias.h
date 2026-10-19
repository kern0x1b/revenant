#ifndef CHARON_ALIAS_H
#define CHARON_ALIAS_H

// A class the release carries without exporting it cannot be linked against: an
// application that names it does not start. CHARON_ALIAS(Name) defines CharonName,
// exports the release's name as an alias of it, and records the pair in
// __DATA,__charon_alias. The library's loader (attach.c) makes CharonName a subclass of
// the release's class before anything uses it, so a subclass an application writes of
// Name inherits the release's class and is laid out after it. Sent to CharonName itself,
// the class methods below answer as the release's class does, so [Name class], what
// [Name alloc] makes and what the release hands out are one class; sent to a subclass,
// they answer as NSObject's do. ld64 merges a category written on Name in the same image
// into CharonName, and attach.c gives the release's class what CharonName has and the
// release's class lacks; a category on Name in another image is attached to the
// release's class by name.
//
// The release may carry that class in SOME of the releases a band is built for and in none
// of the others -- NSURLSessionStreamTask is such a name: CFNetwork carries it from 8.0 on,
// carrying no method of its own, and nothing below 8.0 carries it at all. Where the release
// has no class of the name, the loader has nothing to re-parent the proxy onto and nothing
// to adopt its members into, so the proxy IS the class and every class method below answers
// as CharonName itself: what it makes is an instance of self, what it answers about members
// is what its own chain answers, and what its superclass is is the superclass it was declared
// with. CHARON_ALIAS_OF(Name, Super) declares it; CHARON_ALIAS(Name) is that with NSObject,
// which is right for a name whose release class is NSObject's own descendant. One thing does
// not answer there and is written down in facts/: an application that asks the runtime for the
// name with NSClassFromString gets nil, where the port's own class used to answer, because the
// class it would have to replace is a class of Charon's own and the release's own name belongs
// to no class on such a release.
struct charon_alias {
    const void *proxy;
    const char *name;
};

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// The released answer is the release's own, and only where the release has the class: the test is
// the class itself, so a release that carries none of the name takes the own answer instead of
// messaging nil.
// CHARON_HOST_BUILD is what a host differential's build defines, and it is the only thing a source of
// this package has to know to be built for a machine that carries no release of its own. A host probe
// links no framework of this name - the port's process and the system's are two processes that write
// canonical text and are compared afterwards - so there is no release class for the proxy to stand in
// for, nothing for the library's loader to re-parent, and no name to export. The two things that do all
// three are exactly what such a build cannot carry, both measured 2026-10-04 on the macOS linker and on
// the -D renaming the host harnesses use:
//
//   * the METACLASS alias: `ld: null objc class data for '_OBJC_METACLASS_$_Charon<Name>'`, from the
//     smallest file that carries nothing but CHARON_ALIAS, on the host linker the differentials link
//     with - and the class alias alone, out of the same file, links. Nothing in this package asks for a
//     metaclass by name: a compiled use of the release's name goes through __objc_classrefs, which is
//     the class symbol, so the class export is what a host probe needs as well as what it can carry.
//   * the PROXY's own name: a harness renames every class the port's objects export by compiling the
//     sources again with -D<name>=CharonHost<name> (healthkit/run.sh, uikit2/renames.sh), and a name
//     built by ## cannot be renamed that way - the declaration this file writes and every use of the
//     name in a source then disagree, and the build stops with
//     "unknown type name 'CharonHostCharon<Name>'".
//
// So in a host build the class of the release's name IS the class: the proxy needs no name of its own,
// there is no second class to tell apart, and every class method below answers its own answer. The
// device build is unaffected - CHARON_HOST_BUILD is defined by the harnesses and by nothing in the
// package - and CHARON_ALIAS_CLASS is how a source names the class whose members it carries in a way
// that is one class in both builds.
#ifdef CHARON_HOST_BUILD
#define CHARON_ALIAS_CLASS(Name) Name
#define CHARON_ALIAS_SELF(Name) (__bridge const void *)self
#define CHARON_ALIAS_RELEASE(Name) self
#define CHARON_ALIAS_ANSWER(Name, own, released) (own)
#define CHARON_ALIAS_DECLARE(Name)
// The SDK's own header declares the release's name, so a host build already has that @interface and
// must not write a second one; a device build has no such declaration and needs the proxy's.
#define CHARON_ALIAS_INTERFACE(Name, Super)
#define CHARON_ALIAS_LINKAGE(Name)
#else
// The class the release's name stands for is one of Charon's own, and CHARON_ALIAS_SELF is the symbol
// it answers through - the declaration a runtime class reference binds to, which is why the class name
// is ## and not a plain parameter.
#define CHARON_ALIAS_CLASS(Name) Charon##Name
// The released answer is the release's own, and only where the release has the class: the test is
// the class itself, so a release that carries none of the name takes the own answer instead of
// messaging nil.
#define CHARON_ALIAS_SELF(Name) ((const void *)&charon_alias_class_##Name)
#define CHARON_ALIAS_RELEASE(Name) objc_getClass(#Name)
#define CHARON_ALIAS_ANSWER(Name, own, released) \
    ((__bridge const void *)self == CHARON_ALIAS_SELF(Name) && CHARON_ALIAS_RELEASE(Name) ? (released) : (own))
#define CHARON_ALIAS_DECLARE(Name) \
    extern char charon_alias_class_##Name __asm__("_OBJC_CLASS_$_Charon" #Name);
#define CHARON_ALIAS_INTERFACE(Name, Super) \
    @interface CHARON_ALIAS_CLASS(Name) : Super \
    @end
#define CHARON_ALIAS_LINKAGE(Name) \
    __asm__(".globl _OBJC_CLASS_$_" #Name "\n"                                                                     \
            ".set _OBJC_CLASS_$_" #Name ", _OBJC_CLASS_$_Charon" #Name "\n"                                        \
            ".globl _OBJC_METACLASS_$_" #Name "\n"                                                                 \
            ".set _OBJC_METACLASS_$_" #Name ", _OBJC_METACLASS_$_Charon" #Name "\n");                              \
    __attribute__((used, section("__DATA,__charon_alias"))) static const struct charon_alias charon_alias_##Name = { \
        CHARON_ALIAS_SELF(Name), #Name};
#endif


// What a class answers about a member, walking its own chain: the question is about the class,
// and [super ...] answers it about the class above it, which is not the class asked about.
static BOOL charon_alias_answers(Class cls, SEL selector, BOOL class_methods)
{
    for (Class current = cls; current; current = class_getSuperclass(current)) {
        if ((class_methods ? class_getClassMethod(current, selector) : class_getInstanceMethod(current, selector))) {
            return YES;
        }
    }
    return NO;
}

static Method charon_alias_method(Class cls, SEL selector, BOOL class_methods)
{
    for (Class current = cls; current; current = class_getSuperclass(current)) {
        Method found = class_methods ? class_getClassMethod(current, selector) : class_getInstanceMethod(current, selector);
        if (found) {
            return found;
        }
    }
    return NULL;
}

#define CHARON_ALIAS_OF(Name, Super)                                                                               \
    CHARON_ALIAS_DECLARE(Name) \
                                                                                                                   \
    CHARON_ALIAS_INTERFACE(Name, Super) \
                                                                                                                   \
    @implementation CHARON_ALIAS_CLASS(Name) \
                                                                                                                   \
    + (Class)class                                                                                                 \
    {                                                                                                              \
        return CHARON_ALIAS_ANSWER(Name, self, CHARON_ALIAS_RELEASE(Name));                                              \
    }                                                                                                              \
                                                                                                                   \
    + (id)alloc                                                                                                    \
    {                                                                                                              \
        return CHARON_ALIAS_ANSWER(Name, class_createInstance(self, 0), [CHARON_ALIAS_RELEASE(Name) alloc]);             \
    }                                                                                                              \
                                                                                                                   \
    + (id)allocWithZone:(NSZone *)zone                                                                             \
    {                                                                                                              \
        return CHARON_ALIAS_ANSWER(Name, class_createInstance(self, 0), [CHARON_ALIAS_RELEASE(Name) allocWithZone:zone]); \
    }                                                                                                              \
                                                                                                                   \
    + (Class)superclass                                                                                            \
    {                                                                                                              \
        Class found = CHARON_ALIAS_ANSWER(Name, class_getSuperclass(self), [CHARON_ALIAS_RELEASE(Name) superclass]);     \
        return (__bridge const void *)found == CHARON_ALIAS_SELF(Name) ? CHARON_ALIAS_RELEASE(Name) : found; \
    }                                                                                                              \
                                                                                                                   \
    + (BOOL)isSubclassOfClass:(Class)aClass                                                                        \
    {                                                                                                              \
        if ((__bridge const void *)self == CHARON_ALIAS_SELF(Name) && CHARON_ALIAS_RELEASE(Name)) {      \
            return [CHARON_ALIAS_RELEASE(Name) isSubclassOfClass:aClass];                                                 \
        }                                                                                                          \
        for (Class current = self; current; current = class_getSuperclass(current)) {                             \
            if (current == aClass) {                                                                               \
                return YES;                                                                                        \
            }                                                                                                      \
        }                                                                                                          \
        return NO;                                                                                                 \
    }                                                                                                              \
                                                                                                                   \
    + (BOOL)instancesRespondToSelector:(SEL)selector                                                               \
    {                                                                                                              \
        return CHARON_ALIAS_ANSWER(Name, charon_alias_answers(self, selector, false),                              \
                                   [CHARON_ALIAS_RELEASE(Name) instancesRespondToSelector:selector]);                    \
    }                                                                                                              \
                                                                                                                   \
    + (IMP)instanceMethodForSelector:(SEL)selector                                                                 \
    {                                                                                                              \
        return CHARON_ALIAS_ANSWER(Name, method_getImplementation(charon_alias_method(self, selector, false)),      \
                                   [CHARON_ALIAS_RELEASE(Name) instanceMethodForSelector:selector]);                     \
    }                                                                                                              \
                                                                                                                   \
    + (NSMethodSignature *)instanceMethodSignatureForSelector:(SEL)selector                                        \
    {                                                                                                              \
        Class asked = CHARON_ALIAS_ANSWER(Name, self, CHARON_ALIAS_RELEASE(Name));                                       \
        const char *types = method_getTypeEncoding(charon_alias_method(asked, selector, false));                   \
        return types ? [NSMethodSignature signatureWithObjCTypes:types] : nil;                                     \
    }                                                                                                              \
                                                                                                                   \
    + (BOOL)conformsToProtocol:(Protocol *)protocol                                                                \
    {                                                                                                              \
        return CHARON_ALIAS_ANSWER(Name, [super conformsToProtocol:protocol], [CHARON_ALIAS_RELEASE(Name) conformsToProtocol:protocol]); \
    }                                                                                                              \
                                                                                                                   \
    + (BOOL)respondsToSelector:(SEL)selector                                                                       \
    {                                                                                                              \
        return CHARON_ALIAS_ANSWER(Name, [super respondsToSelector:selector], [CHARON_ALIAS_RELEASE(Name) respondsToSelector:selector]); \
    }                                                                                                              \
                                                                                                                   \
    + (IMP)methodForSelector:(SEL)selector                                                                         \
    {                                                                                                              \
        return CHARON_ALIAS_ANSWER(Name, method_getImplementation(charon_alias_method(self, selector, true)),       \
                                   [CHARON_ALIAS_RELEASE(Name) methodForSelector:selector]);                            \
    }                                                                                                              \
                                                                                                                   \
    + (NSString *)description                                                                                      \
    {                                                                                                              \
        return CHARON_ALIAS_ANSWER(Name, [super description], [CHARON_ALIAS_RELEASE(Name) description]);                 \
    }                                                                                                              \
                                                                                                                   \
    + (NSUInteger)hash                                                                                             \
    {                                                                                                              \
        return CHARON_ALIAS_ANSWER(Name, [super hash], [CHARON_ALIAS_RELEASE(Name) hash]);                               \
    }                                                                                                              \
                                                                                                                   \
    + (BOOL)isEqual:(id)object                                                                                     \
    {                                                                                                              \
        id other = (__bridge const void *)object == CHARON_ALIAS_SELF(Name) ? CHARON_ALIAS_RELEASE(Name) : object; \
        return CHARON_ALIAS_ANSWER(Name, [super isEqual:other], [CHARON_ALIAS_RELEASE(Name) isEqual:other]);             \
    }                                                                                                              \
                                                                                                                   \
    + (id)forwardingTargetForSelector:(SEL)selector                                                                \
    {                                                                                                              \
        return CHARON_ALIAS_ANSWER(Name, [super forwardingTargetForSelector:selector], CHARON_ALIAS_RELEASE(Name));      \
    }                                                                                                              \
                                                                                                                   \
    @end                                                                                                           \
                                                                                                                   \
    CHARON_ALIAS_LINKAGE(Name) \

#define CHARON_ALIAS(Name) CHARON_ALIAS_OF(Name, NSObject)
#endif

#endif
