#ifndef REVENANT_ALIAS_H
#define REVENANT_ALIAS_H

struct revenant_alias {
    const void *proxy;
    const char *name;
};

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#ifdef REVENANT_HOST_BUILD
#define REVENANT_ALIAS_CLASS(Name) Name
#define REVENANT_ALIAS_SELF(Name) (__bridge const void *)self
#define REVENANT_ALIAS_RELEASE(Name) self
#define REVENANT_ALIAS_ANSWER(Name, own, released) (own)
#define REVENANT_ALIAS_DECLARE(Name)
#define REVENANT_ALIAS_INTERFACE(Name, Super)
#define REVENANT_ALIAS_LINKAGE(Name)
#else
#define REVENANT_ALIAS_CLASS(Name) Revenant##Name
#define REVENANT_ALIAS_SELF(Name) ((const void *)&revenant_alias_class_##Name)
#define REVENANT_ALIAS_RELEASE(Name) objc_getClass(#Name)
#define REVENANT_ALIAS_ANSWER(Name, own, released) \
    ((__bridge const void *)self == REVENANT_ALIAS_SELF(Name) && REVENANT_ALIAS_RELEASE(Name) ? (released) : (own))
#define REVENANT_ALIAS_DECLARE(Name) \
    extern char revenant_alias_class_##Name __asm__("_OBJC_CLASS_$_Revenant" #Name);
#define REVENANT_ALIAS_INTERFACE(Name, Super) \
    @interface REVENANT_ALIAS_CLASS(Name) : Super \
    @end
#define REVENANT_ALIAS_LINKAGE(Name) \
    __asm__(".globl _OBJC_CLASS_$_" #Name "\n"                                                                     \
            ".set _OBJC_CLASS_$_" #Name ", _OBJC_CLASS_$_Revenant" #Name "\n"                                        \
            ".globl _OBJC_METACLASS_$_" #Name "\n"                                                                 \
            ".set _OBJC_METACLASS_$_" #Name ", _OBJC_METACLASS_$_Revenant" #Name "\n");                              \
    __attribute__((used, section("__DATA,__revenant_alias"))) static const struct revenant_alias revenant_alias_##Name = { \
        REVENANT_ALIAS_SELF(Name), #Name};
#endif


static BOOL revenant_alias_answers(Class cls, SEL selector, BOOL class_methods)
{
    for (Class current = cls; current; current = class_getSuperclass(current)) {
        if ((class_methods ? class_getClassMethod(current, selector) : class_getInstanceMethod(current, selector))) {
            return YES;
        }
    }
    return NO;
}

static Method revenant_alias_method(Class cls, SEL selector, BOOL class_methods)
{
    for (Class current = cls; current; current = class_getSuperclass(current)) {
        Method found = class_methods ? class_getClassMethod(current, selector) : class_getInstanceMethod(current, selector);
        if (found) {
            return found;
        }
    }
    return NULL;
}

#define REVENANT_ALIAS_OF(Name, Super)                                                                               \
    REVENANT_ALIAS_DECLARE(Name) \
                                                                                                                   \
    REVENANT_ALIAS_INTERFACE(Name, Super) \
                                                                                                                   \
    @implementation REVENANT_ALIAS_CLASS(Name) \
                                                                                                                   \
    + (Class)class                                                                                                 \
    {                                                                                                              \
        return REVENANT_ALIAS_ANSWER(Name, self, REVENANT_ALIAS_RELEASE(Name));                                              \
    }                                                                                                              \
                                                                                                                   \
    + (id)alloc                                                                                                    \
    {                                                                                                              \
        return REVENANT_ALIAS_ANSWER(Name, class_createInstance(self, 0), [REVENANT_ALIAS_RELEASE(Name) alloc]);             \
    }                                                                                                              \
                                                                                                                   \
    + (id)allocWithZone:(NSZone *)zone                                                                             \
    {                                                                                                              \
        return REVENANT_ALIAS_ANSWER(Name, class_createInstance(self, 0), [REVENANT_ALIAS_RELEASE(Name) allocWithZone:zone]); \
    }                                                                                                              \
                                                                                                                   \
    + (Class)superclass                                                                                            \
    {                                                                                                              \
        Class found = REVENANT_ALIAS_ANSWER(Name, class_getSuperclass(self), [REVENANT_ALIAS_RELEASE(Name) superclass]);     \
        return (__bridge const void *)found == REVENANT_ALIAS_SELF(Name) ? REVENANT_ALIAS_RELEASE(Name) : found; \
    }                                                                                                              \
                                                                                                                   \
    + (BOOL)isSubclassOfClass:(Class)aClass                                                                        \
    {                                                                                                              \
        if ((__bridge const void *)self == REVENANT_ALIAS_SELF(Name) && REVENANT_ALIAS_RELEASE(Name)) {      \
            return [REVENANT_ALIAS_RELEASE(Name) isSubclassOfClass:aClass];                                                 \
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
        return REVENANT_ALIAS_ANSWER(Name, revenant_alias_answers(self, selector, false),                              \
                                   [REVENANT_ALIAS_RELEASE(Name) instancesRespondToSelector:selector]);                    \
    }                                                                                                              \
                                                                                                                   \
    + (IMP)instanceMethodForSelector:(SEL)selector                                                                 \
    {                                                                                                              \
        return REVENANT_ALIAS_ANSWER(Name, method_getImplementation(revenant_alias_method(self, selector, false)),      \
                                   [REVENANT_ALIAS_RELEASE(Name) instanceMethodForSelector:selector]);                     \
    }                                                                                                              \
                                                                                                                   \
    + (NSMethodSignature *)instanceMethodSignatureForSelector:(SEL)selector                                        \
    {                                                                                                              \
        Class asked = REVENANT_ALIAS_ANSWER(Name, self, REVENANT_ALIAS_RELEASE(Name));                                       \
        const char *types = method_getTypeEncoding(revenant_alias_method(asked, selector, false));                   \
        return types ? [NSMethodSignature signatureWithObjCTypes:types] : nil;                                     \
    }                                                                                                              \
                                                                                                                   \
    + (BOOL)conformsToProtocol:(Protocol *)protocol                                                                \
    {                                                                                                              \
        return REVENANT_ALIAS_ANSWER(Name, [super conformsToProtocol:protocol], [REVENANT_ALIAS_RELEASE(Name) conformsToProtocol:protocol]); \
    }                                                                                                              \
                                                                                                                   \
    + (BOOL)respondsToSelector:(SEL)selector                                                                       \
    {                                                                                                              \
        return REVENANT_ALIAS_ANSWER(Name, [super respondsToSelector:selector], [REVENANT_ALIAS_RELEASE(Name) respondsToSelector:selector]); \
    }                                                                                                              \
                                                                                                                   \
    + (IMP)methodForSelector:(SEL)selector                                                                         \
    {                                                                                                              \
        return REVENANT_ALIAS_ANSWER(Name, method_getImplementation(revenant_alias_method(self, selector, true)),       \
                                   [REVENANT_ALIAS_RELEASE(Name) methodForSelector:selector]);                            \
    }                                                                                                              \
                                                                                                                   \
    + (NSString *)description                                                                                      \
    {                                                                                                              \
        return REVENANT_ALIAS_ANSWER(Name, [super description], [REVENANT_ALIAS_RELEASE(Name) description]);                 \
    }                                                                                                              \
                                                                                                                   \
    + (NSUInteger)hash                                                                                             \
    {                                                                                                              \
        return REVENANT_ALIAS_ANSWER(Name, [super hash], [REVENANT_ALIAS_RELEASE(Name) hash]);                               \
    }                                                                                                              \
                                                                                                                   \
    + (BOOL)isEqual:(id)object                                                                                     \
    {                                                                                                              \
        id other = (__bridge const void *)object == REVENANT_ALIAS_SELF(Name) ? REVENANT_ALIAS_RELEASE(Name) : object; \
        return REVENANT_ALIAS_ANSWER(Name, [super isEqual:other], [REVENANT_ALIAS_RELEASE(Name) isEqual:other]);             \
    }                                                                                                              \
                                                                                                                   \
    + (id)forwardingTargetForSelector:(SEL)selector                                                                \
    {                                                                                                              \
        return REVENANT_ALIAS_ANSWER(Name, [super forwardingTargetForSelector:selector], REVENANT_ALIAS_RELEASE(Name));      \
    }                                                                                                              \
                                                                                                                   \
    @end                                                                                                           \
                                                                                                                   \
    REVENANT_ALIAS_LINKAGE(Name) \

#define REVENANT_ALIAS(Name) REVENANT_ALIAS_OF(Name, NSObject)
#endif

#endif
