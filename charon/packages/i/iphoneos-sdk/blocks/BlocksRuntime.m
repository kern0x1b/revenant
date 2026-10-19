#include <dlfcn.h>
#include <libkern/OSAtomic.h>
#include <limits.h>
#include <objc/message.h>
#include <objc/runtime.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum {
    CHARON_BLOCK_DEALLOCATING = 0x0001,
    CHARON_BLOCK_REFCOUNT_MASK = 0xfffe,
    CHARON_BLOCK_NEEDS_FREE = 1 << 24,
    CHARON_BLOCK_HAS_COPY_DISPOSE = 1 << 25,
    CHARON_BLOCK_IS_GLOBAL = 1 << 28,
    CHARON_BYREF_HAS_COPY_DISPOSE = 1 << 25,
    CHARON_BYREF_NEEDS_FREE = 1 << 24,
    CHARON_BYREF_LAYOUT_MASK = 0xf << 28,
    CHARON_BYREF_LAYOUT_EXTENDED = 1 << 28,
    CHARON_FIELD_IS_OBJECT = 3,
    CHARON_FIELD_IS_BLOCK = 7,
    CHARON_FIELD_IS_BYREF = 8,
    CHARON_FIELD_IS_WEAK = 16,
    CHARON_BYREF_CALLER = 128,
};

struct charon_block_descriptor {
    unsigned long reserved;
    unsigned long size;
    void (*copy)(void *destination, const void *source);
    void (*dispose)(const void *block);
};

struct charon_block {
    void *isa;
    volatile int32_t flags;
    int32_t reserved;
    void (*invoke)(void *, ...);
    struct charon_block_descriptor *descriptor;
};

struct charon_byref {
    void *isa;
    struct charon_byref *forwarding;
    volatile int32_t flags;
    uint32_t size;
};

struct charon_byref_helpers {
    void (*keep)(struct charon_byref *destination, struct charon_byref *source);
    void (*destroy)(struct charon_byref *byref);
};

struct charon_byref_layout {
    const char *layout;
};

__attribute__((objc_root_class))
@interface __CharonBlock {
    Class isa;
}
@end

@interface __CharonStackBlock : __CharonBlock
@end

@interface __CharonMallocBlock : __CharonBlock
@end

@interface __CharonGlobalBlock : __CharonBlock
@end

@interface __CharonAutoBlock : __CharonBlock
@end

@interface __CharonFinalizingBlock : __CharonBlock
@end

@interface __CharonWeakBlockVariable : __CharonBlock
@end

__asm__(".private_extern __NSConcreteStackBlock\n__NSConcreteStackBlock = _OBJC_CLASS_$___CharonStackBlock\n"
        ".private_extern __NSConcreteMallocBlock\n__NSConcreteMallocBlock = _OBJC_CLASS_$___CharonMallocBlock\n"
        ".private_extern __NSConcreteGlobalBlock\n__NSConcreteGlobalBlock = _OBJC_CLASS_$___CharonGlobalBlock\n"
        ".private_extern __NSConcreteAutoBlock\n__NSConcreteAutoBlock = _OBJC_CLASS_$___CharonAutoBlock\n"
        ".private_extern __NSConcreteFinalizingBlock\n__NSConcreteFinalizingBlock = _OBJC_CLASS_$___CharonFinalizingBlock\n"
        ".private_extern __NSConcreteWeakBlockVariable\n__NSConcreteWeakBlockVariable = _OBJC_CLASS_$___CharonWeakBlockVariable\n");

extern void *_NSConcreteMallocBlock[];

typedef void *(*charon_copy_function)(const void *);
typedef void (*charon_release_function)(const void *);
typedef void (*charon_assign_function)(void *, const void *, const int);
typedef void (*charon_dispose_function)(const void *, const int);

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

CHARON_NATIVE(charon_copy_function, _Block_copy)
CHARON_NATIVE(charon_release_function, _Block_release)
CHARON_NATIVE(charon_assign_function, _Block_object_assign)
CHARON_NATIVE(charon_dispose_function, _Block_object_dispose)

static id charon_send(id object, const char *selector)
{
    return ((id (*)(id, SEL))objc_msgSend)(object, sel_registerName(selector));
}

static int32_t charon_retain_count(volatile int32_t *flags)
{
    while (1) {
        int32_t old = *flags;
        if ((old & CHARON_BLOCK_REFCOUNT_MASK) == CHARON_BLOCK_REFCOUNT_MASK)
            return old;
        if (OSAtomicCompareAndSwap32Barrier(old, old + 2, flags))
            return old + 2;
    }
}

static int charon_release_count(volatile int32_t *flags)
{
    while (1) {
        int32_t old = *flags;
        if ((old & CHARON_BLOCK_REFCOUNT_MASK) == CHARON_BLOCK_REFCOUNT_MASK)
            return 0;
        if ((old & CHARON_BLOCK_REFCOUNT_MASK) == 0)
            abort();
        int32_t updated = old - 2;
        if ((old & CHARON_BLOCK_REFCOUNT_MASK) == 2)
            updated = (old & ~CHARON_BLOCK_REFCOUNT_MASK) | CHARON_BLOCK_DEALLOCATING;
        if (OSAtomicCompareAndSwap32Barrier(old, updated, flags))
            return (updated & CHARON_BLOCK_DEALLOCATING) != 0;
    }
}

static struct charon_byref *charon_byref_copy(struct charon_byref *source)
{
    if (!(source->forwarding->flags & CHARON_BYREF_NEEDS_FREE)) {
        struct charon_byref *copy = malloc(source->size);
        copy->isa = NULL;
        copy->flags = (source->flags & ~CHARON_BLOCK_REFCOUNT_MASK) | CHARON_BYREF_NEEDS_FREE | 4;
        copy->forwarding = copy;
        source->forwarding = copy;
        copy->size = source->size;
        if (source->flags & CHARON_BYREF_HAS_COPY_DISPOSE) {
            struct charon_byref_helpers *to = (struct charon_byref_helpers *)(copy + 1);
            struct charon_byref_helpers *from = (struct charon_byref_helpers *)(source + 1);
            *to = *from;
            if ((source->flags & CHARON_BYREF_LAYOUT_MASK) == CHARON_BYREF_LAYOUT_EXTENDED)
                *(struct charon_byref_layout *)(to + 1) = *(struct charon_byref_layout *)(from + 1);
            from->keep(copy, source);
        } else {
            memmove(copy + 1, source + 1, source->size - sizeof(struct charon_byref));
        }
    } else if (source->forwarding->flags & CHARON_BYREF_NEEDS_FREE) {
        charon_retain_count(&source->forwarding->flags);
    }
    return source->forwarding;
}

static void charon_byref_release(struct charon_byref *byref)
{
    byref = byref->forwarding;
    if (!(byref->flags & CHARON_BYREF_NEEDS_FREE))
        return;
    if (charon_release_count(&byref->flags)) {
        if (byref->flags & CHARON_BYREF_HAS_COPY_DISPOSE)
            ((struct charon_byref_helpers *)(byref + 1))->destroy(byref);
        free(byref);
    }
}

__attribute__((visibility("hidden"))) void *_Block_copy(const void *argument)
{
    charon_copy_function native = charon_native__Block_copy();
    if (native)
        __attribute__((musttail)) return native(argument);
    struct charon_block *block = (struct charon_block *)argument;
    if (!block)
        return NULL;
    if (block->flags & CHARON_BLOCK_NEEDS_FREE) {
        charon_retain_count(&block->flags);
        return block;
    }
    if (block->flags & CHARON_BLOCK_IS_GLOBAL)
        return block;
    struct charon_block *copy = malloc(block->descriptor->size);
    if (!copy)
        return NULL;
    memmove(copy, block, block->descriptor->size);
    copy->flags &= ~(CHARON_BLOCK_REFCOUNT_MASK | CHARON_BLOCK_DEALLOCATING);
    copy->flags |= CHARON_BLOCK_NEEDS_FREE | 2;
    copy->isa = _NSConcreteMallocBlock;
    if (block->flags & CHARON_BLOCK_HAS_COPY_DISPOSE)
        block->descriptor->copy(copy, block);
    return copy;
}

__attribute__((visibility("hidden"))) void _Block_release(const void *argument)
{
    charon_release_function native = charon_native__Block_release();
    if (native)
        __attribute__((musttail)) return native(argument);
    struct charon_block *block = (struct charon_block *)argument;
    if (!block || !(block->flags & CHARON_BLOCK_NEEDS_FREE))
        return;
    if (charon_release_count(&block->flags)) {
        if (block->flags & CHARON_BLOCK_HAS_COPY_DISPOSE)
            block->descriptor->dispose(block);
        free(block);
    }
}

__attribute__((visibility("hidden"))) void _Block_object_assign(void *destination, const void *object, const int flags)
{
    charon_assign_function native = charon_native__Block_object_assign();
    if (native)
        __attribute__((musttail)) return native(destination, object, flags);
    switch (flags & (CHARON_FIELD_IS_OBJECT | CHARON_FIELD_IS_BLOCK | CHARON_FIELD_IS_BYREF | CHARON_FIELD_IS_WEAK | CHARON_BYREF_CALLER)) {
    case CHARON_FIELD_IS_OBJECT:
        charon_send((id)object, "retain");
        *(const void **)destination = object;
        break;
    case CHARON_FIELD_IS_BLOCK:
        *(const void **)destination = _Block_copy(object);
        break;
    case CHARON_FIELD_IS_BYREF:
    case CHARON_FIELD_IS_BYREF | CHARON_FIELD_IS_WEAK:
        *(const void **)destination = charon_byref_copy((struct charon_byref *)object);
        break;
    default:
        *(const void **)destination = object;
        break;
    }
}

__attribute__((visibility("hidden"))) void _Block_object_dispose(const void *object, const int flags)
{
    charon_dispose_function native = charon_native__Block_object_dispose();
    if (native)
        __attribute__((musttail)) return native(object, flags);
    switch (flags & (CHARON_FIELD_IS_OBJECT | CHARON_FIELD_IS_BLOCK | CHARON_FIELD_IS_BYREF | CHARON_FIELD_IS_WEAK | CHARON_BYREF_CALLER)) {
    case CHARON_FIELD_IS_BYREF:
    case CHARON_FIELD_IS_BYREF | CHARON_FIELD_IS_WEAK:
        charon_byref_release((struct charon_byref *)object);
        break;
    case CHARON_FIELD_IS_BLOCK:
        _Block_release(object);
        break;
    case CHARON_FIELD_IS_OBJECT:
        charon_send((id)object, "release");
        break;
    default:
        break;
    }
}

@implementation __CharonBlock
+ (void)initialize
{
}

+ (id)class
{
    return self;
}

- (Class)class
{
    return object_getClass(self);
}

- (Class)superclass
{
    return class_getSuperclass(object_getClass(self));
}

- (id)self
{
    return self;
}

- (BOOL)isEqual:(id)other
{
    return self == other;
}

- (unsigned long)hash
{
    return (unsigned long)self;
}

- (BOOL)isKindOfClass:(Class)wanted
{
    for (Class found = object_getClass(self); found; found = class_getSuperclass(found)) {
        if (found == wanted)
            return YES;
    }
    return NO;
}

- (BOOL)isMemberOfClass:(Class)wanted
{
    return object_getClass(self) == wanted;
}

- (BOOL)respondsToSelector:(SEL)selector
{
    return class_respondsToSelector(object_getClass(self), selector);
}

- (BOOL)conformsToProtocol:(Protocol *)protocol
{
    return class_conformsToProtocol(object_getClass(self), protocol);
}

- (BOOL)isProxy
{
    return NO;
}

- (void *)zone
{
    return NULL;
}

- (id)description
{
    char text[64];
    snprintf(text, sizeof text, "<%s: %p>", object_getClassName(self), (void *)self);
    return ((id (*)(id, SEL, const char *))objc_msgSend)((id)objc_getClass("NSString"), sel_registerName("stringWithUTF8String:"), text);
}

- (id)debugDescription
{
    return [self description];
}

- (id)methodSignatureForSelector:(SEL)selector
{
    Method method = class_getInstanceMethod(object_getClass(self), selector);
    if (!method)
        return nil;
    return ((id (*)(id, SEL, const char *))objc_msgSend)((id)objc_getClass("NSMethodSignature"), sel_registerName("signatureWithObjCTypes:"), method_getTypeEncoding(method));
}

- (void)doesNotRecognizeSelector:(SEL)selector
{
    fprintf(stderr, "-[%s %s]: unrecognized selector sent to block %p\n", object_getClassName(self), sel_getName(selector), (void *)self);
    abort();
}

- (id)retain
{
    return self;
}

- (oneway void)release
{
}

- (id)autorelease
{
    ((void (*)(id, SEL, id))objc_msgSend)((id)objc_getClass("NSAutoreleasePool"), sel_registerName("addObject:"), self);
    return self;
}

- (id)copy
{
    return _Block_copy(self);
}

- (id)copyWithZone:(void *)zone
{
    return _Block_copy(self);
}

- (unsigned long)retainCount
{
    return ULONG_MAX;
}
@end

@implementation __CharonStackBlock
@end

@implementation __CharonMallocBlock
- (id)retain
{
    return _Block_copy(self);
}

- (oneway void)release
{
    _Block_release(self);
}

- (unsigned long)retainCount
{
    return (((struct charon_block *)self)->flags & CHARON_BLOCK_REFCOUNT_MASK) / 2;
}
@end

@implementation __CharonGlobalBlock
- (id)copy
{
    return self;
}

- (id)copyWithZone:(void *)zone
{
    return self;
}
@end

@implementation __CharonAutoBlock
@end

@implementation __CharonFinalizingBlock
@end

@implementation __CharonWeakBlockVariable
@end
