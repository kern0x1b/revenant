#ifndef CHARON_ML_TENSOR_H
#define CHARON_ML_TENSOR_H

#include <stddef.h>
#include <stdint.h>

#include "CharonMLValue.h"



typedef struct {
    int rank;
    int64_t shape[CHARON_ML_MAX_RANK];
    size_t count;
    float *data;
} charon_ml_tensor;

charon_ml_tensor charon_ml_tensor_make(int rank, const int64_t *shape);
void charon_ml_tensor_free(charon_ml_tensor *tensor);
void charon_ml_tensor_zero(charon_ml_tensor *tensor);

int charon_ml_tensor_from_value(charon_ml_tensor *tensor, const charon_ml_value *value);
charon_ml_value charon_ml_tensor_to_value(const charon_ml_tensor *tensor, int data_type);

int charon_ml_shape_equal(const int64_t *left, int left_rank, const int64_t *right, int right_rank);
void charon_ml_shape_describe(const int64_t *shape, int rank, char *out, size_t size);

int64_t charon_ml_element_count(const int64_t *shape, int rank);

int charon_ml_broadcast_shape(const int64_t *left, int left_rank, const int64_t *right, int right_rank,
                              int64_t *out, int *out_rank);
void charon_ml_broadcast_strides(const int64_t *shape, int rank, const int64_t *out_shape,
                                 int64_t *strides);

void charon_ml_unravel(int64_t index, int rank, const int64_t *shape, int64_t *position);
int64_t charon_ml_ravel(const int64_t *position, int rank, const int64_t *strides);

#endif
