#ifndef CHARON_ML_LAYER_KINDS_H
#define CHARON_ML_LAYER_KINDS_H

#include "CharonMLLayers.h"

typedef int (*charon_ml_layer_fn)(const charon_ml_node *layer, const charon_ml_node *params,
                                  charon_ml_bindings *bindings, char *error, size_t error_size);

const char *charon_ml_layer_name(const charon_ml_node *layer);
int charon_ml_layer_refuse(const charon_ml_node *layer, const char *kind, int number, char *error,
                           size_t error_size);
int charon_ml_layer_bad_shape(const charon_ml_node *layer, const char *what, const charon_ml_tensor *found,
                              char *error, size_t error_size);
int charon_ml_layer_missing_input(const charon_ml_node *layer, const char *name, char *error, size_t error_size);

double charon_ml_number_of(const charon_ml_node *node, const char *field, double fallback);
int charon_ml_integer_of(const charon_ml_node *node, const char *field, int fallback);
int charon_ml_read_numbers(const charon_ml_node *params, double **out, size_t *count);
const char *charon_ml_name_at(const charon_ml_node *layer, const char *field, size_t index, char *buffer,
                              size_t size);
size_t charon_ml_name_count(const charon_ml_node *layer, const char *field);
charon_ml_tensor *charon_ml_input(charon_ml_bindings *bindings, const charon_ml_node *layer);

double charon_ml_activate(int kind, double x, const charon_ml_node *params);
int charon_ml_activation_kind(const charon_ml_node *params);
void charon_ml_row_major_strides(const int64_t *shape, int rank, int64_t *strides);
void charon_ml_softmax_axis(charon_ml_tensor *tensor, int axis);
charon_ml_tensor charon_ml_map_unary(const charon_ml_tensor *input, int kind, const charon_ml_node *params);

enum {
    CHARON_ML_BINARY_ADD = 0,
    CHARON_ML_BINARY_MULTIPLY,
    CHARON_ML_BINARY_SUBTRACT,
    CHARON_ML_BINARY_DIVIDE,
    CHARON_ML_BINARY_MAX,
    CHARON_ML_BINARY_MIN,
    CHARON_ML_BINARY_POW,
    CHARON_ML_BINARY_FLOOR_DIV,
    CHARON_ML_BINARY_MOD,
    CHARON_ML_BINARY_EQUAL,
    CHARON_ML_BINARY_NOT_EQUAL,
    CHARON_ML_BINARY_LESS,
    CHARON_ML_BINARY_LESS_EQUAL,
    CHARON_ML_BINARY_GREATER,
    CHARON_ML_BINARY_GREATER_EQUAL,
    CHARON_ML_BINARY_ADD_ALPHA
};
double charon_ml_apply_binary(int operation, double a, double b, double alpha);
charon_ml_tensor charon_ml_binary(int operation, const charon_ml_tensor *left,
                                  const charon_ml_tensor *right, double alpha);
int charon_ml_layer_convolution(const charon_ml_node *layer, const charon_ml_node *params,
                                charon_ml_bindings *bindings, char *error, size_t error_size);
int charon_ml_layer_pooling(const charon_ml_node *layer, const charon_ml_node *params,
                            charon_ml_bindings *bindings, char *error, size_t error_size);
int charon_ml_layer_inner_product(const charon_ml_node *layer, const charon_ml_node *params,
                                  charon_ml_bindings *bindings, char *error, size_t error_size);
int charon_ml_layer_activation(const charon_ml_node *layer, const charon_ml_node *params,
                               charon_ml_bindings *bindings, char *error, size_t error_size);
int charon_ml_layer_softmax(const charon_ml_node *layer, const charon_ml_node *params,
                            charon_ml_bindings *bindings, char *error, size_t error_size);
int charon_ml_layer_batchnorm(const charon_ml_node *layer, const charon_ml_node *params,
                              charon_ml_bindings *bindings, char *error, size_t error_size);
int charon_ml_layer_mvn(const charon_ml_node *layer, const charon_ml_node *params, charon_ml_bindings *bindings,
                        char *error, size_t error_size);
int charon_ml_layer_l2normalize(const charon_ml_node *layer, const charon_ml_node *params,
                                charon_ml_bindings *bindings, char *error, size_t error_size);
int charon_ml_layer_lrn(const charon_ml_node *layer, const charon_ml_node *params, charon_ml_bindings *bindings,
                       char *error, size_t error_size);
int charon_ml_layer_embedding(const charon_ml_node *layer, const charon_ml_node *params,
                              charon_ml_bindings *bindings, char *error, size_t error_size);
int charon_ml_layer_unary_math(const charon_ml_node *layer, const charon_ml_node *params,
                               charon_ml_bindings *bindings, char *error, size_t error_size);
int charon_ml_layer_scale(const charon_ml_node *layer, const charon_ml_node *params, charon_ml_bindings *bindings,
                          char *error, size_t error_size);
int charon_ml_layer_bias(const charon_ml_node *layer, const charon_ml_node *params, charon_ml_bindings *bindings,
                         char *error, size_t error_size);
int charon_ml_layer_padding(const charon_ml_node *layer, const charon_ml_node *params,
                            charon_ml_bindings *bindings, char *error, size_t error_size);
int charon_ml_layer_load_constant(const charon_ml_node *layer, const charon_ml_node *params,
                                  charon_ml_bindings *bindings, char *error, size_t error_size);
int charon_ml_layer_permute(const charon_ml_node *layer, const charon_ml_node *params,
                            charon_ml_bindings *bindings, char *error, size_t error_size);
int charon_ml_layer_reshape(const charon_ml_node *layer, const charon_ml_node *params,
                            charon_ml_bindings *bindings, char *error, size_t error_size);
int charon_ml_layer_flatten(const charon_ml_node *layer, const charon_ml_node *params,
                            charon_ml_bindings *bindings, char *error, size_t error_size);
int charon_ml_layer_concat(const charon_ml_node *layer, const charon_ml_node *params,
                           charon_ml_bindings *bindings, char *error, size_t error_size);
int charon_ml_layer_split(const charon_ml_node *layer, const charon_ml_node *params,
                          charon_ml_bindings *bindings, char *error, size_t error_size);
int charon_ml_layer_slice(const charon_ml_node *layer, const charon_ml_node *params,
                          charon_ml_bindings *bindings, char *error, size_t error_size);
int charon_ml_layer_copy(const charon_ml_node *layer, const charon_ml_node *params, charon_ml_bindings *bindings,
                         char *error, size_t error_size);
int charon_ml_layer_transpose(const charon_ml_node *layer, const charon_ml_node *params,
                              charon_ml_bindings *bindings, char *error, size_t error_size);
int charon_ml_layer_upsample(const charon_ml_node *layer, const charon_ml_node *params,
                             charon_ml_bindings *bindings, char *error, size_t error_size);
int charon_ml_layer_dot(const charon_ml_node *layer, const charon_ml_node *params, charon_ml_bindings *bindings,
                        char *error, size_t error_size);
int charon_ml_layer_reduce(const charon_ml_node *layer, const charon_ml_node *params,
                           charon_ml_bindings *bindings, char *error, size_t error_size);
int charon_ml_layer_reorganize(const charon_ml_node *layer, const charon_ml_node *params,
                               charon_ml_bindings *bindings, char *error, size_t error_size);
int charon_ml_layer_squeeze(const charon_ml_node *layer, const charon_ml_node *params,
                            charon_ml_bindings *bindings, char *error, size_t error_size);
int charon_ml_layer_expand_dims(const charon_ml_node *layer, const charon_ml_node *params,
                                charon_ml_bindings *bindings, char *error, size_t error_size);
int charon_ml_layer_tile(const charon_ml_node *layer, const charon_ml_node *params,
                         charon_ml_bindings *bindings, char *error, size_t error_size);
int charon_ml_layer_clip(const charon_ml_node *layer, const charon_ml_node *params,
                         charon_ml_bindings *bindings, char *error, size_t error_size);
int charon_ml_layer_simple_recurrent(const charon_ml_node *layer, const charon_ml_node *params,
                                     charon_ml_bindings *bindings, char *error, size_t error_size);

#endif
