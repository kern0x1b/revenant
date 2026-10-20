#ifndef REVENANT_ML_TENSOR_H
#define REVENANT_ML_TENSOR_H

#include <stddef.h>
#include <stdint.h>

#include "RevenantMLValue.h"



typedef struct {
    int rank;
    int64_t shape[REVENANT_ML_MAX_RANK];
    size_t count;
    float *data;
} revenant_ml_tensor;

revenant_ml_tensor revenant_ml_tensor_make(int rank, const int64_t *shape);
void revenant_ml_tensor_free(revenant_ml_tensor *tensor);
void revenant_ml_tensor_zero(revenant_ml_tensor *tensor);

int revenant_ml_tensor_from_value(revenant_ml_tensor *tensor, const revenant_ml_value *value);
revenant_ml_value revenant_ml_tensor_to_value(const revenant_ml_tensor *tensor, int data_type);

int revenant_ml_shape_equal(const int64_t *left, int left_rank, const int64_t *right, int right_rank);
void revenant_ml_shape_describe(const int64_t *shape, int rank, char *out, size_t size);

int64_t revenant_ml_element_count(const int64_t *shape, int rank);

int revenant_ml_broadcast_shape(const int64_t *left, int left_rank, const int64_t *right, int right_rank,
                              int64_t *out, int *out_rank);
void revenant_ml_broadcast_strides(const int64_t *shape, int rank, const int64_t *out_shape,
                                 int64_t *strides);

void revenant_ml_unravel(int64_t index, int rank, const int64_t *shape, int64_t *position);
int64_t revenant_ml_ravel(const int64_t *position, int rank, const int64_t *strides);

#endif
