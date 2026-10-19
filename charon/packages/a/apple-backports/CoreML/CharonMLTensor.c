/* A float tensor and the shape arithmetic a neural network's layers need.
 * CharonMLTensor.h says what it is for; this is the arithmetic of it. */
#include "CharonMLTensor.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int64_t charon_ml_element_count(const int64_t *shape, int rank)
{
    int index;
    int64_t count = 1;
    if (rank < 0 || rank > CHARON_ML_MAX_RANK) {
        return 0;
    }
    for (index = 0; index < rank; index++) {
        if (shape[index] <= 0) {
            return 0;
        }
        count *= shape[index];
    }
    return count;
}

charon_ml_tensor charon_ml_tensor_make(int rank, const int64_t *shape)
{
    charon_ml_tensor tensor;
    int64_t count;
    memset(&tensor, 0, sizeof tensor);
    if (rank < 0) {
        rank = 0;
    }
    if (rank > CHARON_ML_MAX_RANK) {
        rank = CHARON_ML_MAX_RANK;
    }
    tensor.rank = rank;
    memcpy(tensor.shape, shape, (size_t)rank * sizeof *shape);
    count = charon_ml_element_count(shape, rank);
    if (count <= 0) {
        return tensor;
    }
    tensor.count = (size_t)count;
    tensor.data = (float *)calloc(tensor.count, sizeof *tensor.data);
    if (tensor.data == NULL) {
        tensor.count = 0;
    }
    return tensor;
}

void charon_ml_tensor_free(charon_ml_tensor *tensor)
{
    if (tensor == NULL) {
        return;
    }
    free(tensor->data);
    tensor->data = NULL;
    tensor->count = 0;
}

void charon_ml_tensor_zero(charon_ml_tensor *tensor)
{
    if (tensor != NULL && tensor->data != NULL) {
        memset(tensor->data, 0, tensor->count * sizeof *tensor->data);
    }
}

int charon_ml_tensor_from_value(charon_ml_tensor *tensor, const charon_ml_value *value)
{
    size_t index;
    memset(tensor, 0, sizeof *tensor);
    if (value == NULL || value->kind != CHARON_ML_VALUE_ARRAY || value->array.rank > CHARON_ML_MAX_RANK ||
        value->array.count == 0) {
        return 0;
    }
    tensor->rank = value->array.rank;
    memcpy(tensor->shape, value->array.shape, (size_t)tensor->rank * sizeof *tensor->shape);
    tensor->count = value->array.count;
    tensor->data = (float *)malloc(tensor->count * sizeof *tensor->data);
    if (tensor->data == NULL) {
        tensor->count = 0;
        return 0;
    }
    /* A stride is not necessarily 1: a caller may hand over a view of a larger array, and a
     * layer reads what it is given rather than what it assumes. */
    for (index = 0; index < tensor->count; index++) {
        int64_t position[CHARON_ML_MAX_RANK];
        int64_t offset = 0;
        int axis;
        charon_ml_unravel((int64_t)index, tensor->rank, tensor->shape, position);
        for (axis = 0; axis < tensor->rank; axis++) {
            offset += position[axis] * value->array.strides[axis];
        }
        tensor->data[index] = (float)charon_ml_array_get(&value->array, offset);
    }
    return 1;
}

charon_ml_value charon_ml_tensor_to_value(const charon_ml_tensor *tensor, int data_type)
{
    charon_ml_array array = charon_ml_array_alloc(data_type, tensor->shape, tensor->rank);
    size_t index;
    if (array.data == NULL) {
        return charon_ml_value_array(array);
    }
    for (index = 0; index < tensor->count; index++) {
        charon_ml_array_set(&array, (int64_t)index, (double)tensor->data[index]);
    }
    return charon_ml_value_array(array);
}

int charon_ml_shape_equal(const int64_t *left, int left_rank, const int64_t *right, int right_rank)
{
    int index;
    if (left_rank != right_rank) {
        return 0;
    }
    for (index = 0; index < left_rank; index++) {
        if (left[index] != right[index]) {
            return 0;
        }
    }
    return 1;
}

void charon_ml_shape_describe(const int64_t *shape, int rank, char *out, size_t size)
{
    size_t used = 0;
    int index;
    out[0] = 0;
    for (index = 0; index < rank; index++) {
        int written = snprintf(out + used, size - used, "%s%lld", index > 0 ? "x" : "",
                               (long long)shape[index]);
        if (written < 0 || (size_t)written >= size - used) {
            return;
        }
        used += (size_t)written;
    }
}

int charon_ml_broadcast_shape(const int64_t *left, int left_rank, const int64_t *right, int right_rank,
                              int64_t *out, int *out_rank)
{
    int index;
    if (left_rank != right_rank || right_rank > CHARON_ML_MAX_RANK) {
        return 0;
    }
    for (index = 0; index < right_rank; index++) {
        if (left[index] == right[index]) {
            out[index] = left[index];
        } else if (left[index] == 1) {
            out[index] = right[index];
        } else if (right[index] == 1) {
            out[index] = left[index];
        } else {
            return 0;
        }
    }
    *out_rank = right_rank;
    return 1;
}

void charon_ml_broadcast_strides(const int64_t *shape, int rank, const int64_t *out_shape,
                                 int64_t *strides)
{
    /* Row-major strides of the result shape, with a dimension of 1 in `shape` given a stride
     * of 0: that is what makes a single value stretch along the whole dimension. */
    int64_t stride = 1;
    int index;
    for (index = rank - 1; index >= 0; index--) {
        strides[index] = shape[index] == out_shape[index] ? stride : 0;
        stride *= out_shape[index];
    }
}

void charon_ml_unravel(int64_t index, int rank, const int64_t *shape, int64_t *position)
{
    int axis;
    for (axis = rank - 1; axis >= 0; axis--) {
        if (shape[axis] <= 0) {
            position[axis] = 0;
            continue;
        }
        position[axis] = index % shape[axis];
        index /= shape[axis];
    }
}

int64_t charon_ml_ravel(const int64_t *position, int rank, const int64_t *strides)
{
    int64_t offset = 0;
    int axis;
    for (axis = 0; axis < rank; axis++) {
        offset += position[axis] * strides[axis];
    }
    return offset;
}
