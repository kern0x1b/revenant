#ifndef CHARON_ALIAS_H
#define CHARON_ALIAS_H

struct charon_alias {
    const void *proxy;
    const char *name;
};

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#ifdef CHARON_HOST_BUILD
#define CHARON_ALIAS_CLASS(Name) Name
#define CHARON_ALIAS_SELF(Name) (__bridge const void *)self
#define CHARON_ALIAS_RELEASE(Name) self
#define CHARON_ALIAS_ANSWER(Name, own, released) (own)
#define CHARON_ALIAS_DECLARE(Name)
#define CHARON_ALIAS_INTERFACE(Name, Super)
#define CHARON_ALIAS_LINKAGE(Name)
#else
#define CHARON_ALIAS_CLASS(Name) Charon##Name
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
