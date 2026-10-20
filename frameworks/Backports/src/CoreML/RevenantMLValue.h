#ifndef REVENANT_ML_VALUE_H
#define REVENANT_ML_VALUE_H

#include <stddef.h>
#include <stdint.h>

#define REVENANT_ML_MAX_RANK 8

enum {
    REVENANT_ML_ARRAY_INVALID = 0,
    REVENANT_ML_ARRAY_FLOAT32 = 65568,
    REVENANT_ML_ARRAY_DOUBLE = 65600,
    REVENANT_ML_ARRAY_INT32 = 131104,
    REVENANT_ML_ARRAY_INT8 = 131080,
    REVENANT_ML_ARRAY_FLOAT16 = 65552
};

typedef enum {
    REVENANT_ML_VALUE_NONE = 0,
    REVENANT_ML_VALUE_NUMBER,
    REVENANT_ML_VALUE_STRING,
    REVENANT_ML_VALUE_IMAGE,
    REVENANT_ML_VALUE_DICTIONARY,
    REVENANT_ML_VALUE_ARRAY,
    REVENANT_ML_VALUE_SEQUENCE
} revenant_ml_value_kind;

#define REVENANT_ML_FLEXIBLE (-1)

typedef struct {
    int data_type;
    int rank;
    int64_t shape[REVENANT_ML_MAX_RANK];
    int64_t strides[REVENANT_ML_MAX_RANK];
    size_t count;
    void *data;
    int owns_data;
} revenant_ml_array;

#define REVENANT_ML_DICTIONARY_PAIRS 256

typedef struct {
    char *keys[REVENANT_ML_DICTIONARY_PAIRS];
    double values[REVENANT_ML_DICTIONARY_PAIRS];
    size_t count;
} revenant_ml_dictionary;

typedef struct {
    revenant_ml_value_kind kind;
    double number;
    struct {
        const char *bytes;
        size_t length;
        int owned;
    } string;
    revenant_ml_array array;
    revenant_ml_dictionary dictionary;
} revenant_ml_value;

size_t revenant_ml_type_size(int data_type);
int revenant_ml_count_of_shape(const int64_t *shape, int rank);
revenant_ml_array revenant_ml_array_make(int data_type, const int64_t *shape, int rank, void *data);
revenant_ml_array revenant_ml_array_alloc(int data_type, const int64_t *shape, int rank);
void revenant_ml_array_free(revenant_ml_array *array);
revenant_ml_array revenant_ml_array_subview(const revenant_ml_array *array, const int64_t *shape, int rank, int64_t at);
int revenant_ml_array_as(const revenant_ml_array *array, int data_type, revenant_ml_array *out);

double revenant_ml_array_get(const revenant_ml_array *array, int64_t index);
void revenant_ml_array_set(revenant_ml_array *array, int64_t index, double value);
int64_t revenant_ml_array_offset(const revenant_ml_array *array, const int64_t *position, int rank);

float revenant_ml_half_to_float(uint16_t half);
uint16_t revenant_ml_float_to_half(float value);

revenant_ml_value revenant_ml_value_number(double number);
revenant_ml_value revenant_ml_value_string(const char *bytes, size_t length);
revenant_ml_value revenant_ml_value_string_copy(const char *bytes, size_t length);
revenant_ml_value revenant_ml_value_array(revenant_ml_array array);
revenant_ml_value revenant_ml_value_dictionary(void);
int revenant_ml_dictionary_put(revenant_ml_value *value, const char *key, double number);
const char *revenant_ml_dictionary_get(const revenant_ml_value *value, const char *key, double *number,
                                    int *found);
void revenant_ml_value_free(revenant_ml_value *value);
const char *revenant_ml_value_name(revenant_ml_value_kind kind);
const char *revenant_ml_type_name(int data_type);

#endif
