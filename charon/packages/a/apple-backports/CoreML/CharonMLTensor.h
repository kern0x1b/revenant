/* A float tensor and the shape arithmetic a neural network's layers need.
 *
 * Every intermediate of a Core ML neural network is a tensor of float32 whose dimensions are
 * channels first and then the spatial ones, or a plain vector when there is one dimension.
 * This is that, with the operations on shapes separated from the operations on the numbers,
 * so a layer says what shape it produces and then fills it.
 */
#ifndef CHARON_ML_TENSOR_H
#define CHARON_ML_TENSOR_H

#include <stddef.h>
#include <stdint.h>

#include "CharonMLValue.h"



typedef struct {
    int rank;
    int64_t shape[CHARON_ML_MAX_RANK]; /* in elements */
    size_t count;
    float *data; /* NULL for a shape with no numbers in it yet */
} charon_ml_tensor;

charon_ml_tensor charon_ml_tensor_make(int rank, const int64_t *shape);
void charon_ml_tensor_free(charon_ml_tensor *tensor);
void charon_ml_tensor_zero(charon_ml_tensor *tensor);

/* A tensor of the same numbers, read out of an MLMultiArray-shaped value whatever its
 * element type is, which is how a model that takes a double array runs float arithmetic. */
int charon_ml_tensor_from_value(charon_ml_tensor *tensor, const charon_ml_value *value);
charon_ml_value charon_ml_tensor_to_value(const charon_ml_tensor *tensor, int data_type);

/* Whether two shapes are the same, dimension for dimension. */
int charon_ml_shape_equal(const int64_t *left, int left_rank, const int64_t *right, int right_rank);
/* The same shape written out, for an error message. */
void charon_ml_shape_describe(const int64_t *shape, int rank, char *out, size_t size);

/* The number of elements of a product, or 0 when any factor is not positive. */
int64_t charon_ml_element_count(const int64_t *shape, int rank);

/* Broadcasting as CoreML's elementwise layers do: two shapes combine when they have the same
 * rank and each dimension either agrees or is 1, and 1 stretches. Fails otherwise, so a
 * layer that was handed two things it cannot combine says so instead of reading past an end. */
int charon_ml_broadcast_shape(const int64_t *left, int left_rank, const int64_t *right, int right_rank,
                              int64_t *out, int *out_rank);
/* The index into the flat numbers of a position in the broadcast shape, and the two indices
 * it reads from, given the two strides each shape has in the broadcast shape. */
void charon_ml_broadcast_strides(const int64_t *shape, int rank, const int64_t *out_shape,
                                 int64_t *strides);

/* The position of an index of `tensor` in the given shape, when it has one, or NULL. */
void charon_ml_unravel(int64_t index, int rank, const int64_t *shape, int64_t *position);
int64_t charon_ml_ravel(const int64_t *position, int rank, const int64_t *strides);

#endif /* CHARON_ML_TENSOR_H */
