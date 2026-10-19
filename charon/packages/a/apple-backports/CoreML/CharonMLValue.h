#ifndef CHARON_ML_VALUE_H
#define CHARON_ML_VALUE_H

#include <stddef.h>
#include <stdint.h>

#define CHARON_ML_MAX_RANK 8

enum {
    CHARON_ML_ARRAY_INVALID = 0,
    CHARON_ML_ARRAY_FLOAT32 = 65568,
    CHARON_ML_ARRAY_DOUBLE = 65600,
    CHARON_ML_ARRAY_INT32 = 131104,
    CHARON_ML_ARRAY_INT8 = 131080,
    CHARON_ML_ARRAY_FLOAT16 = 65552
};

typedef enum {
    CHARON_ML_VALUE_NONE = 0,
    CHARON_ML_VALUE_NUMBER,
    CHARON_ML_VALUE_STRING,
    CHARON_ML_VALUE_IMAGE,
    CHARON_ML_VALUE_DICTIONARY,
    CHARON_ML_VALUE_ARRAY,
    CHARON_ML_VALUE_SEQUENCE
} charon_ml_value_kind;

#define CHARON_ML_FLEXIBLE (-1)

typedef struct {
    int data_type;
    int rank;
    int64_t shape[CHARON_ML_MAX_RANK];
    int64_t strides[CHARON_ML_MAX_RANK];
    size_t count;
    void *data;
    int owns_data;
} charon_ml_array;

#define CHARON_ML_DICTIONARY_PAIRS 256

typedef struct {
    char *keys[CHARON_ML_DICTIONARY_PAIRS];
    double values[CHARON_ML_DICTIONARY_PAIRS];
    size_t count;
} charon_ml_dictionary;

typedef struct {
    charon_ml_value_kind kind;
    double number;
    struct {
        const char *bytes;
        size_t length;
        int owned;
    } string;
    charon_ml_array array;
    charon_ml_dictionary dictionary;
} charon_ml_value;

size_t charon_ml_type_size(int data_type);
int charon_ml_count_of_shape(const int64_t *shape, int rank);
charon_ml_array charon_ml_array_make(int data_type, const int64_t *shape, int rank, void *data);
charon_ml_array charon_ml_array_alloc(int data_type, const int64_t *shape, int rank);
void charon_ml_array_free(charon_ml_array *array);
charon_ml_array charon_ml_array_subview(const charon_ml_array *array, const int64_t *shape, int rank, int64_t at);
int charon_ml_array_as(const charon_ml_array *array, int data_type, charon_ml_array *out);

double charon_ml_array_get(const charon_ml_array *array, int64_t index);
void charon_ml_array_set(charon_ml_array *array, int64_t index, double value);
int64_t charon_ml_array_offset(const charon_ml_array *array, const int64_t *position, int rank);

float charon_ml_half_to_float(uint16_t half);
uint16_t charon_ml_float_to_half(float value);

charon_ml_value charon_ml_value_number(double number);
charon_ml_value charon_ml_value_string(const char *bytes, size_t length);
charon_ml_value charon_ml_value_string_copy(const char *bytes, size_t length);
charon_ml_value charon_ml_value_array(charon_ml_array array);
charon_ml_value charon_ml_value_dictionary(void);
int charon_ml_dictionary_put(charon_ml_value *value, const char *key, double number);
const char *charon_ml_dictionary_get(const charon_ml_value *value, const char *key, double *number,
                                    int *found);
void charon_ml_value_free(charon_ml_value *value);
const char *charon_ml_value_name(charon_ml_value_kind kind);
const char *charon_ml_type_name(int data_type);

#endif
