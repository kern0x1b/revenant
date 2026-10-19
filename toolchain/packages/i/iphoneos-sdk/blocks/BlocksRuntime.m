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
    REVENANT_BLOCK_DEALLOCATING = 0x0001,
    REVENANT_BLOCK_REFCOUNT_MASK = 0xfffe,
    REVENANT_BLOCK_NEEDS_FREE = 1 << 24,
    REVENANT_BLOCK_HAS_COPY_DISPOSE = 1 << 25,
    REVENANT_BLOCK_IS_GLOBAL = 1 << 28,
    REVENANT_BYREF_HAS_COPY_DISPOSE = 1 << 25,
    REVENANT_BYREF_NEEDS_FREE = 1 << 24,
    REVENANT_BYREF_LAYOUT_MASK = 0xf << 28,
    REVENANT_BYREF_LAYOUT_EXTENDED = 1 << 28,
    REVENANT_FIELD_IS_OBJECT = 3,
    REVENANT_FIELD_IS_BLOCK = 7,
    REVENANT_FIELD_IS_BYREF = 8,
    REVENANT_FIELD_IS_WEAK = 16,
    REVENANT_BYREF_CALLER = 128,
};

struct revenant_block_descriptor {
    unsigned long reserved;
    unsigned long size;
    void (*copy)(void *destination, const void *source);
    void (*dispose)(const void *block);
};

struct revenant_block {
    void *isa;
    volatile int32_t flags;
    int32_t reserved;
    void (*invoke)(void *, ...);
    struct revenant_block_descriptor *descriptor;
};

struct revenant_byref {
    void *isa;
    struct revenant_byref *forwarding;
    volatile int32_t flags;
    uint32_t size;
};

struct revenant_byref_helpers {
    void (*keep)(struct revenant_byref *destination, struct revenant_byref *source);
    void (*destroy)(struct revenant_byref *byref);
};

struct revenant_byref_layout {
    const char *layout;
};

__attribute__((objc_root_class))
@interface __RevenantBlock {
    Class isa;
}
@end

@interface __RevenantStackBlock : __RevenantBlock
@end

@interface __RevenantMallocBlock : __RevenantBlock
@end

@interface __RevenantGlobalBlock : __RevenantBlock
@end

@interface __RevenantAutoBlock : __RevenantBlock
@end

@interface __RevenantFinalizingBlock : __RevenantBlock
@end

@interface __RevenantWeakBlockVariable : __RevenantBlock
@end

__asm__(".private_extern __NSConcreteStackBlock\n__NSConcreteStackBlock = _OBJC_CLASS_$___RevenantStackBlock\n"
        ".private_extern __NSConcreteMallocBlock\n__NSConcreteMallocBlock = _OBJC_CLASS_$___RevenantMallocBlock\n"
        ".private_extern __NSConcreteGlobalBlock\n__NSConcreteGlobalBlock = _OBJC_CLASS_$___RevenantGlobalBlock\n"
        ".private_extern __NSConcreteAutoBlock\n__NSConcreteAutoBlock = _OBJC_CLASS_$___RevenantAutoBlock\n"
        ".private_extern __NSConcreteFinalizingBlock\n__NSConcreteFinalizingBlock = _OBJC_CLASS_$___RevenantFinalizingBlock\n"
        ".private_extern __NSConcreteWeakBlockVariable\n__NSConcreteWeakBlockVariable = _OBJC_CLASS_$___RevenantWeakBlockVariable\n");

extern void *_NSConcreteMallocBlock[];

typedef void *(*revenant_copy_function)(const void *);
typedef void (*revenant_release_function)(const void *);
typedef void (*revenant_assign_function)(void *, const void *, const int);
typedef void (*revenant_dispose_function)(const void *, const int);

#define REVENANT_NATIVE(type, name)                                   \
    static type revenant_native_##name(void)                          \
    {                                                               \
        static type found;                                          \
        static int looked;                                          \
        if (!looked) {                                              \
            found = (type)dlsym(RTLD_DEFAULT, #name);               \
            looked = 1;                                             \
        }                                                           \
        return found;                                               \
    }

REVENANT_NATIVE(revenant_copy_function, _Block_copy)
REVENANT_NATIVE(revenant_release_function, _Block_release)
REVENANT_NATIVE(revenant_assign_function, _Block_object_assign)
REVENANT_NATIVE(revenant_dispose_function, _Block_object_dispose)

static id revenant_send(id object, const char *selector)
{
    return ((id (*)(id, SEL))objc_msgSend)(object, sel_registerName(selector));
}

static int32_t revenant_retain_count(volatile int32_t *flags)
{
    while (1) {
        int32_t old = *flags;
        if ((old & REVENANT_BLOCK_REFCOUNT_MASK) == REVENANT_BLOCK_REFCOUNT_MASK)
            return old;
        if (OSAtomicCompareAndSwap32Barrier(old, old + 2, flags))
            return old + 2;
    }
}

static int revenant_release_count(volatile int32_t *flags)
{
    while (1) {
        int32_t old = *flags;
        if ((old & REVENANT_BLOCK_REFCOUNT_MASK) == REVENANT_BLOCK_REFCOUNT_MASK)
            return 0;
        if ((old & REVENANT_BLOCK_REFCOUNT_MASK) == 0)
            abort();
        int32_t updated = old - 2;
        if ((old & REVENANT_BLOCK_REFCOUNT_MASK) == 2)
            updated = (old & ~REVENANT_BLOCK_REFCOUNT_MASK) | REVENANT_BLOCK_DEALLOCATING;
        if (OSAtomicCompareAndSwap32Barrier(old, updated, flags))
            return (updated & REVENANT_BLOCK_DEALLOCATING) != 0;
    }
}

static struct revenant_byref *revenant_byref_copy(struct revenant_byref *source)
{
    if (!(source->forwarding->flags & REVENANT_BYREF_NEEDS_FREE)) {
        struct revenant_byref *copy = malloc(source->size);
        copy->isa = NULL;
        copy->flags = (source->flags & ~REVENANT_BLOCK_REFCOUNT_MASK) | REVENANT_BYREF_NEEDS_FREE | 4;
        copy->forwarding = copy;
        source->forwarding = copy;
        copy->size = source->size;
        if (source->flags & REVENANT_BYREF_HAS_COPY_DISPOSE) {
            struct revenant_byref_helpers *to = (struct revenant_byref_helpers *)(copy + 1);
            struct revenant_byref_helpers *from = (struct revenant_byref_helpers *)(source + 1);
            *to = *from;
            if ((source->flags & REVENANT_BYREF_LAYOUT_MASK) == REVENANT_BYREF_LAYOUT_EXTENDED)
                *(struct revenant_byref_layout *)(to + 1) = *(struct revenant_byref_layout *)(from + 1);
            from->keep(copy, source);
        } else {
            memmove(copy + 1, source + 1, source->size - sizeof(struct revenant_byref));
        }
    } else if (source->forwarding->flags & REVENANT_BYREF_NEEDS_FREE) {
        revenant_retain_count(&source->forwarding->flags);
    }
    return source->forwarding;
}

static void revenant_byref_release(struct revenant_byref *byref)
{
    byref = byref->forwarding;
    if (!(byref->flags & REVENANT_BYREF_NEEDS_FREE))
        return;
    if (revenant_release_count(&byref->flags)) {
        if (byref->flags & REVENANT_BYREF_HAS_COPY_DISPOSE)
            ((struct revenant_byref_helpers *)(byref + 1))->destroy(byref);
        free(byref);
    }
}

__attribute__((visibility("hidden"))) void *_Block_copy(const void *argument)
{
    revenant_copy_function native = revenant_native__Block_copy();
    if (native)
        __attribute__((musttail)) return native(argument);
    struct revenant_block *block = (struct revenant_block *)argument;
    if (!block)
        return NULL;
    if (block->flags & REVENANT_BLOCK_NEEDS_FREE) {
        revenant_retain_count(&block->flags);
        return block;
    }
    if (block->flags & REVENANT_BLOCK_IS_GLOBAL)
        return block;
    struct revenant_block *copy = malloc(block->descriptor->size);
    if (!copy)
        return NULL;
    memmove(copy, block, block->descriptor->size);
    copy->flags &= ~(REVENANT_BLOCK_REFCOUNT_MASK | REVENANT_BLOCK_DEALLOCATING);
    copy->flags |= REVENANT_BLOCK_NEEDS_FREE | 2;
    copy->isa = _NSConcreteMallocBlock;
    if (block->flags & REVENANT_BLOCK_HAS_COPY_DISPOSE)
        block->descriptor->copy(copy, block);
    return copy;
}

__attribute__((visibility("hidden"))) void _Block_release(const void *argument)
{
    revenant_release_function native = revenant_native__Block_release();
    if (native)
        __attribute__((musttail)) return native(argument);
    struct revenant_block *block = (struct revenant_block *)argument;
    if (!block || !(block->flags & REVENANT_BLOCK_NEEDS_FREE))
        return;
    if (revenant_release_count(&block->flags)) {
        if (block->flags & REVENANT_BLOCK_HAS_COPY_DISPOSE)
            block->descriptor->dispose(block);
        free(block);
    }
}

__attribute__((visibility("hidden"))) void _Block_object_assign(void *destination, const void *object, const int flags)
{
    revenant_assign_function native = revenant_native__Block_object_assign();
    if (native)
        __attribute__((musttail)) return native(destination, object, flags);
    switch (flags & (REVENANT_FIELD_IS_OBJECT | REVENANT_FIELD_IS_BLOCK | REVENANT_FIELD_IS_BYREF | REVENANT_FIELD_IS_WEAK | REVENANT_BYREF_CALLER)) {
    case REVENANT_FIELD_IS_OBJECT:
        revenant_send((id)object, "retain");
        *(const void **)destination = object;
        break;
    case REVENANT_FIELD_IS_BLOCK:
        *(const void **)destination = _Block_copy(object);
        break;
    case REVENANT_FIELD_IS_BYREF:
    case REVENANT_FIELD_IS_BYREF | REVENANT_FIELD_IS_WEAK:
        *(const void **)destination = revenant_byref_copy((struct revenant_byref *)object);
        break;
    default:
        *(const void **)destination = object;
        break;
    }
}

__attribute__((visibility("hidden"))) void _Block_object_dispose(const void *object, const int flags)
{
    revenant_dispose_function native = revenant_native__Block_object_dispose();
    if (native)
        __attribute__((musttail)) return native(object, flags);
    switch (flags & (REVENANT_FIELD_IS_OBJECT | REVENANT_FIELD_IS_BLOCK | REVENANT_FIELD_IS_BYREF | REVENANT_FIELD_IS_WEAK | REVENANT_BYREF_CALLER)) {
    case REVENANT_FIELD_IS_BYREF:
    case REVENANT_FIELD_IS_BYREF | REVENANT_FIELD_IS_WEAK:
        revenant_byref_release((struct revenant_byref *)object);
        break;
    case REVENANT_FIELD_IS_BLOCK:
        _Block_release(object);
        break;
    case REVENANT_FIELD_IS_OBJECT:
        revenant_send((id)object, "release");
        break;
    default:
        break;
    }
}

@implementation __RevenantBlock
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

@implementation __RevenantStackBlock
@end

@implementation __RevenantMallocBlock
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
    return (((struct revenant_block *)self)->flags & REVENANT_BLOCK_REFCOUNT_MASK) / 2;
}
@end

@implementation __RevenantGlobalBlock
- (id)copy
{
    return self;
}

- (id)copyWithZone:(void *)zone
{
    return self;
}
@end

@implementation __RevenantAutoBlock
@end

@implementation __RevenantFinalizingBlock
@end

@implementation __RevenantWeakBlockVariable
@end
