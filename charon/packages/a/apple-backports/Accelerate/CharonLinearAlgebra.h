// The storage behind every la_object_t, and the object itself in the two shapes the release's own
// <vecLib/LinearAlgebra/object.h> gives it.
//
// vecLib/LinearAlgebra/object.h declares la_object_t from OS_OBJECT_DECL(la_object), and that macro
// reads __IPHONE_OS_VERSION_MIN_REQUIRED: at iOS 6.1.3 and above it is an Objective-C type
// (NSObject<la_object> *, retained with [object retain]), and below iOS 6.0 - the 4.3 band - it is
// the incomplete `struct la_s *` that la_retain() and la_release() count. The two bands therefore
// compile different code for the same source, and both are held to the answers the host's own
// Accelerate gives (tests/backports/host/linearalgebra, facts/Accelerate/LinearAlgebra.md).
//
// The name carries a Charon prefix on purpose: the gate does not weigh a symbol of the port's own
// against a release or ask the registry about it (modules/apple/backports.lua, internal_symbol).

#pragma once

#import <Accelerate/Accelerate.h>
#import <Foundation/Foundation.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

// What an la_object_t holds: the kind of thing, its shape, its scalar type, its status and its
// attributes. One flat structure, because the host's own is one flat class (measured: a splat and a
// vector both answer OS_la_object for -class, facts/Accelerate/LinearAlgebra.md).
typedef enum {
    CharonLAError = 0,   // carries a status and nothing else: rows and cols are 0, and so is its scalar type
    CharonLASplat = 1,   // one value, dimensions inferred from whatever it meets
    CharonLAArray = 2    // rows x cols elements, row-major, in one block
} CharonLAKind;

typedef struct CharonLAValue {
    CharonLAKind kind;
    la_status_t status;
    la_attribute_t attributes;
    la_hint_t hint;
    la_scalar_type_t scalar_type;
    la_count_t rows;
    la_count_t cols;
    double splat;
    void *elements;
    la_deallocator_t deallocator;
} CharonLAValue;

#if OS_OBJECT_USE_OBJC

// The class carries a Charon prefix and not the release's own name, so the gate weighs neither it nor
// its metaclass against a release or asks the registry about it (modules/apple/backports.lua,
// internal_symbol). It is an NSObject and nothing more: which of the two shapes la_object_t has is the
// header's decision from __OBJC__ and the deployment target, and both spellings are reached from here
// through a cast.
@interface CharonLAObject : NSObject {
@public
    CharonLAValue value;
}
@end

// A NULL object has no value: forming &object->value for one would read the object's own first word
// as an ivar offset, so every accessor goes through here and the NULL checks below it hold.
static inline CharonLAValue *CharonLAValueOf(la_object_t object)
{
    return object ? &((CharonLAObject *)(object))->value : NULL;
}
#define CHARON_LA_VALUE(object) CharonLAValueOf(object)

// One new object with no elements and no status yet. A function rather than a macro because the
// release's own typedef is a protocol-qualified Objective-C type, which cannot be written inside a
// cast, and because a macro expanding to [[...]] is ambiguous with an attribute specifier.
// The release's typedef carries the protocol its own OS_OBJECT_DECL writes, which is <NSObject> and
// which differs in name between SDKs; the cast through id is what keeps one source valid against both.
static inline la_object_t CharonLANewObject(void)
{
    return (la_object_t)(id)[[CharonLAObject alloc] init];
}

#else

// The release's own incomplete type, filled in. la_retain() and la_release() count the field below.
struct la_s {
    unsigned long retain_count;
    CharonLAValue value;
};

static inline CharonLAValue *charon_la_value(la_object_t object) { return object ? &object->value : NULL; }
#define CHARON_LA_VALUE(object) charon_la_value(object)

static inline la_object_t CharonLANewObject(void) { return (la_object_t)calloc(1, sizeof(struct la_s)); }

#endif

// Every element of an array object, read or written, as a double whatever the object's own scalar
// type is; the arithmetic is done in double and narrowed once, at the end, for a float object.
static inline double CharonLAGet(const CharonLAValue *value, la_count_t row, la_count_t col)
{
    la_count_t at = row * value->cols + col;
    return value->scalar_type == LA_SCALAR_TYPE_FLOAT ? ((const float *)value->elements)[at] : ((const double *)value->elements)[at];
}

static inline void CharonLASet(CharonLAValue *value, la_count_t row, la_count_t col, double element)
{
    la_count_t at = row * value->cols + col;
    if (value->scalar_type == LA_SCALAR_TYPE_FLOAT) {
        ((float *)value->elements)[at] = (float)element;
    } else {
        ((double *)value->elements)[at] = element;
    }
}

static inline size_t CharonLAWidth(la_scalar_type_t scalar_type) { return scalar_type == LA_SCALAR_TYPE_FLOAT ? sizeof(float) : sizeof(double); }

// The block of elements, through the deallocator the caller of la_matrix_from_*_buffer_nocopy named
// when it gave the block over, and then the block itself.
static inline void CharonLAFreeValue(CharonLAValue *value)
{
    if (value->deallocator && value->elements) {
        value->deallocator(value->elements);
    }
    free(value->elements);
    value->elements = NULL;
    value->deallocator = NULL;
}

// The number of elements an object of this shape has, and the length the host reports for it:
// a vector is the dimension that is not 1, and any other matrix answers its rows (measured: a 2x3
// answers 2, a 3x2 answers 3, a 1x5 answers 5, a 4x4 answers 4; the header says zero for a matrix
// with both dimensions above one, which the host does not do).
static inline la_count_t CharonLALength(const CharonLAValue *value)
{
    if (value->kind != CharonLAArray) {
        return 0;
    }
    return value->rows == 1 ? value->cols : value->rows;
}
