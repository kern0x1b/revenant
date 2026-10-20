#pragma once

#import <Accelerate/Accelerate.h>
#import <Foundation/Foundation.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

typedef enum {
    RevenantLAError = 0,
    RevenantLASplat = 1,
    RevenantLAArray = 2
} RevenantLAKind;

typedef struct RevenantLAValue {
    RevenantLAKind kind;
    la_status_t status;
    la_attribute_t attributes;
    la_hint_t hint;
    la_scalar_type_t scalar_type;
    la_count_t rows;
    la_count_t cols;
    double splat;
    void *elements;
    la_deallocator_t deallocator;
} RevenantLAValue;

#if OS_OBJECT_USE_OBJC

@interface RevenantLAObject : NSObject {
@public
    RevenantLAValue value;
}
@end

static inline RevenantLAValue *RevenantLAValueOf(la_object_t object)
{
    return object ? &((RevenantLAObject *)(object))->value : NULL;
}
#define REVENANT_LA_VALUE(object) RevenantLAValueOf(object)

static inline la_object_t RevenantLANewObject(void)
{
    return (la_object_t)(id)[[RevenantLAObject alloc] init];
}

#else

struct la_s {
    unsigned long retain_count;
    RevenantLAValue value;
};

static inline RevenantLAValue *revenant_la_value(la_object_t object) { return object ? &object->value : NULL; }
#define REVENANT_LA_VALUE(object) revenant_la_value(object)

static inline la_object_t RevenantLANewObject(void) { return (la_object_t)calloc(1, sizeof(struct la_s)); }

#endif

static inline double RevenantLAGet(const RevenantLAValue *value, la_count_t row, la_count_t col)
{
    la_count_t at = row * value->cols + col;
    return value->scalar_type == LA_SCALAR_TYPE_FLOAT ? ((const float *)value->elements)[at] : ((const double *)value->elements)[at];
}

static inline void RevenantLASet(RevenantLAValue *value, la_count_t row, la_count_t col, double element)
{
    la_count_t at = row * value->cols + col;
    if (value->scalar_type == LA_SCALAR_TYPE_FLOAT) {
        ((float *)value->elements)[at] = (float)element;
    } else {
        ((double *)value->elements)[at] = element;
    }
}

static inline size_t RevenantLAWidth(la_scalar_type_t scalar_type) { return scalar_type == LA_SCALAR_TYPE_FLOAT ? sizeof(float) : sizeof(double); }

static inline void RevenantLAFreeValue(RevenantLAValue *value)
{
    if (value->deallocator && value->elements) {
        value->deallocator(value->elements);
    }
    free(value->elements);
    value->elements = NULL;
    value->deallocator = NULL;
}

static inline la_count_t RevenantLALength(const RevenantLAValue *value)
{
    if (value->kind != RevenantLAArray) {
        return 0;
    }
    return value->rows == 1 ? value->cols : value->rows;
}
