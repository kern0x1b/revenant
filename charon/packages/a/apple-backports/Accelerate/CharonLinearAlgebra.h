#pragma once

#import <Accelerate/Accelerate.h>
#import <Foundation/Foundation.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

typedef enum {
    CharonLAError = 0,
    CharonLASplat = 1,
    CharonLAArray = 2
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

@interface CharonLAObject : NSObject {
@public
    CharonLAValue value;
}
@end

static inline CharonLAValue *CharonLAValueOf(la_object_t object)
{
    return object ? &((CharonLAObject *)(object))->value : NULL;
}
#define CHARON_LA_VALUE(object) CharonLAValueOf(object)

static inline la_object_t CharonLANewObject(void)
{
    return (la_object_t)(id)[[CharonLAObject alloc] init];
}

#else

struct la_s {
    unsigned long retain_count;
    CharonLAValue value;
};

static inline CharonLAValue *charon_la_value(la_object_t object) { return object ? &object->value : NULL; }
#define CHARON_LA_VALUE(object) charon_la_value(object)

static inline la_object_t CharonLANewObject(void) { return (la_object_t)calloc(1, sizeof(struct la_s)); }

#endif

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

static inline void CharonLAFreeValue(CharonLAValue *value)
{
    if (value->deallocator && value->elements) {
        value->deallocator(value->elements);
    }
    free(value->elements);
    value->elements = NULL;
    value->deallocator = NULL;
}

static inline la_count_t CharonLALength(const CharonLAValue *value)
{
    if (value->kind != CharonLAArray) {
        return 0;
    }
    return value->rows == 1 ? value->cols : value->rows;
}
