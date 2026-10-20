#ifndef REVENANT_ML_LAYER_KINDS_H
#define REVENANT_ML_LAYER_KINDS_H

#include "RevenantMLLayers.h"

typedef int (*revenant_ml_layer_fn)(const revenant_ml_node *layer, const revenant_ml_node *params,
                                  revenant_ml_bindings *bindings, char *error, size_t error_size);

const char *revenant_ml_layer_name(const revenant_ml_node *layer);
int revenant_ml_layer_refuse(const revenant_ml_node *layer, const char *kind, int number, char *error,
                           size_t error_size);
int revenant_ml_layer_bad_shape(const revenant_ml_node *layer, const char *what, const revenant_ml_tensor *found,
                              char *error, size_t error_size);
int revenant_ml_layer_missing_input(const revenant_ml_node *layer, const char *name, char *error, size_t error_size);

double revenant_ml_number_of(const revenant_ml_node *node, const char *field, double fallback);
int revenant_ml_integer_of(const revenant_ml_node *node, const char *field, int fallback);
int revenant_ml_read_numbers(const revenant_ml_node *params, double **out, size_t *count);
const char *revenant_ml_name_at(const revenant_ml_node *layer, const char *field, size_t index, char *buffer,
                              size_t size);
size_t revenant_ml_name_count(const revenant_ml_node *layer, const char *field);
revenant_ml_tensor *revenant_ml_input(revenant_ml_bindings *bindings, const revenant_ml_node *layer);

double revenant_ml_activate(int kind, double x, const revenant_ml_node *params);
int revenant_ml_activation_kind(const revenant_ml_node *params);
void revenant_ml_row_major_strides(const int64_t *shape, int rank, int64_t *strides);
void revenant_ml_softmax_axis(revenant_ml_tensor *tensor, int axis);
revenant_ml_tensor revenant_ml_map_unary(const revenant_ml_tensor *input, int kind, const revenant_ml_node *params);

enum {
    REVENANT_ML_BINARY_ADD = 0,
    REVENANT_ML_BINARY_MULTIPLY,
    REVENANT_ML_BINARY_SUBTRACT,
    REVENANT_ML_BINARY_DIVIDE,
    REVENANT_ML_BINARY_MAX,
    REVENANT_ML_BINARY_MIN,
    REVENANT_ML_BINARY_POW,
    REVENANT_ML_BINARY_FLOOR_DIV,
    REVENANT_ML_BINARY_MOD,
    REVENANT_ML_BINARY_EQUAL,
    REVENANT_ML_BINARY_NOT_EQUAL,
    REVENANT_ML_BINARY_LESS,
    REVENANT_ML_BINARY_LESS_EQUAL,
    REVENANT_ML_BINARY_GREATER,
    REVENANT_ML_BINARY_GREATER_EQUAL,
    REVENANT_ML_BINARY_ADD_ALPHA
};
double revenant_ml_apply_binary(int operation, double a, double b, double alpha);
revenant_ml_tensor revenant_ml_binary(int operation, const revenant_ml_tensor *left,
                                  const revenant_ml_tensor *right, double alpha);
int revenant_ml_layer_convolution(const revenant_ml_node *layer, const revenant_ml_node *params,
                                revenant_ml_bindings *bindings, char *error, size_t error_size);
int revenant_ml_layer_pooling(const revenant_ml_node *layer, const revenant_ml_node *params,
                            revenant_ml_bindings *bindings, char *error, size_t error_size);
int revenant_ml_layer_inner_product(const revenant_ml_node *layer, const revenant_ml_node *params,
                                  revenant_ml_bindings *bindings, char *error, size_t error_size);
int revenant_ml_layer_activation(const revenant_ml_node *layer, const revenant_ml_node *params,
                               revenant_ml_bindings *bindings, char *error, size_t error_size);
int revenant_ml_layer_softmax(const revenant_ml_node *layer, const revenant_ml_node *params,
                            revenant_ml_bindings *bindings, char *error, size_t error_size);
int revenant_ml_layer_batchnorm(const revenant_ml_node *layer, const revenant_ml_node *params,
                              revenant_ml_bindings *bindings, char *error, size_t error_size);
int revenant_ml_layer_mvn(const revenant_ml_node *layer, const revenant_ml_node *params, revenant_ml_bindings *bindings,
                        char *error, size_t error_size);
int revenant_ml_layer_l2normalize(const revenant_ml_node *layer, const revenant_ml_node *params,
                                revenant_ml_bindings *bindings, char *error, size_t error_size);
int revenant_ml_layer_lrn(const revenant_ml_node *layer, const revenant_ml_node *params, revenant_ml_bindings *bindings,
                       char *error, size_t error_size);
int revenant_ml_layer_embedding(const revenant_ml_node *layer, const revenant_ml_node *params,
                              revenant_ml_bindings *bindings, char *error, size_t error_size);
int revenant_ml_layer_unary_math(const revenant_ml_node *layer, const revenant_ml_node *params,
                               revenant_ml_bindings *bindings, char *error, size_t error_size);
int revenant_ml_layer_scale(const revenant_ml_node *layer, const revenant_ml_node *params, revenant_ml_bindings *bindings,
                          char *error, size_t error_size);
int revenant_ml_layer_bias(const revenant_ml_node *layer, const revenant_ml_node *params, revenant_ml_bindings *bindings,
                         char *error, size_t error_size);
int revenant_ml_layer_padding(const revenant_ml_node *layer, const revenant_ml_node *params,
                            revenant_ml_bindings *bindings, char *error, size_t error_size);
int revenant_ml_layer_load_constant(const revenant_ml_node *layer, const revenant_ml_node *params,
                                  revenant_ml_bindings *bindings, char *error, size_t error_size);
int revenant_ml_layer_permute(const revenant_ml_node *layer, const revenant_ml_node *params,
                            revenant_ml_bindings *bindings, char *error, size_t error_size);
int revenant_ml_layer_reshape(const revenant_ml_node *layer, const revenant_ml_node *params,
                            revenant_ml_bindings *bindings, char *error, size_t error_size);
int revenant_ml_layer_flatten(const revenant_ml_node *layer, const revenant_ml_node *params,
                            revenant_ml_bindings *bindings, char *error, size_t error_size);
int revenant_ml_layer_concat(const revenant_ml_node *layer, const revenant_ml_node *params,
                           revenant_ml_bindings *bindings, char *error, size_t error_size);
int revenant_ml_layer_split(const revenant_ml_node *layer, const revenant_ml_node *params,
                          revenant_ml_bindings *bindings, char *error, size_t error_size);
int revenant_ml_layer_slice(const revenant_ml_node *layer, const revenant_ml_node *params,
                          revenant_ml_bindings *bindings, char *error, size_t error_size);
int revenant_ml_layer_copy(const revenant_ml_node *layer, const revenant_ml_node *params, revenant_ml_bindings *bindings,
                         char *error, size_t error_size);
int revenant_ml_layer_transpose(const revenant_ml_node *layer, const revenant_ml_node *params,
                              revenant_ml_bindings *bindings, char *error, size_t error_size);
int revenant_ml_layer_upsample(const revenant_ml_node *layer, const revenant_ml_node *params,
                             revenant_ml_bindings *bindings, char *error, size_t error_size);
int revenant_ml_layer_dot(const revenant_ml_node *layer, const revenant_ml_node *params, revenant_ml_bindings *bindings,
                        char *error, size_t error_size);
int revenant_ml_layer_reduce(const revenant_ml_node *layer, const revenant_ml_node *params,
                           revenant_ml_bindings *bindings, char *error, size_t error_size);
int revenant_ml_layer_reorganize(const revenant_ml_node *layer, const revenant_ml_node *params,
                               revenant_ml_bindings *bindings, char *error, size_t error_size);
int revenant_ml_layer_squeeze(const revenant_ml_node *layer, const revenant_ml_node *params,
                            revenant_ml_bindings *bindings, char *error, size_t error_size);
int revenant_ml_layer_expand_dims(const revenant_ml_node *layer, const revenant_ml_node *params,
                                revenant_ml_bindings *bindings, char *error, size_t error_size);
int revenant_ml_layer_tile(const revenant_ml_node *layer, const revenant_ml_node *params,
                         revenant_ml_bindings *bindings, char *error, size_t error_size);
int revenant_ml_layer_clip(const revenant_ml_node *layer, const revenant_ml_node *params,
                         revenant_ml_bindings *bindings, char *error, size_t error_size);
int revenant_ml_layer_simple_recurrent(const revenant_ml_node *layer, const revenant_ml_node *params,
                                     revenant_ml_bindings *bindings, char *error, size_t error_size);

#endif
