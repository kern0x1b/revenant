/* The value a Core ML feature holds, and the array it holds it in. CharonMLValue.h says what
 * it is for; this is the arithmetic of it. */
#include "CharonMLValue.h"

#include <stdlib.h>
#include <string.h>
#include <string.h>

char *charon_ml_strndup(const char *bytes, size_t length)
{
    /* The value reader's own copy of a string, for a dictionary's keys and a classifier's
     * label: both outlive the frame that wrote them, so both own their bytes. */
    char *copy = (char *)malloc(length + 1);
    if (copy == NULL) {
        return NULL;
    }
    if (length > 0) {
        memcpy(copy, bytes, length);
    }
    copy[length] = 0;
    return copy;
}

size_t charon_ml_type_size(int data_type)
{
    switch (data_type) {
    case CHARON_ML_ARRAY_FLOAT16:
    case CHARON_ML_ARRAY_INT8:
        return 1;
    case CHARON_ML_ARRAY_FLOAT32:
    case CHARON_ML_ARRAY_INT32:
        return 4;
    case CHARON_ML_ARRAY_DOUBLE:
        return 8;
    default:
        return 0;
    }
}

const char *charon_ml_type_name(int data_type)
{
    switch (data_type) {
    case CHARON_ML_ARRAY_FLOAT32:
        return "float32";
    case CHARON_ML_ARRAY_DOUBLE:
        return "double";
    case CHARON_ML_ARRAY_INT32:
        return "int32";
    case CHARON_ML_ARRAY_INT8:
        return "int8";
    case CHARON_ML_ARRAY_FLOAT16:
        return "float16";
    default:
        return "invalid";
    }
}

const char *charon_ml_value_name(charon_ml_value_kind kind)
{
    switch (kind) {
    case CHARON_ML_VALUE_NUMBER:
        return "a number";
    case CHARON_ML_VALUE_STRING:
        return "a string";
    case CHARON_ML_VALUE_IMAGE:
        return "an image";
    case CHARON_ML_VALUE_DICTIONARY:
        return "a dictionary";
    case CHARON_ML_VALUE_ARRAY:
        return "an array";
    case CHARON_ML_VALUE_SEQUENCE:
        return "a sequence";
    default:
        return "no value";
    }
}

int charon_ml_count_of_shape(const int64_t *shape, int rank)
{
    int index;
    int64_t count = 1;
    if (rank < 0 || rank > CHARON_ML_MAX_RANK) {
        return 0;
    }
    for (index = 0; index < rank; index++) {
        if (shape[index] < 0) {
            return 0; /* a flexible dimension: the count is not known from the shape */
        }
        if (shape[index] == 0) {
            return 0;
        }
        count *= shape[index];
    }
    return count > 0 && count <= (int64_t)(1u << 30) ? (int)count : 0;
}

/* The strides of a shape laid out in row-major order, which is the order the specification's
 * weights and every MLMultiArray are in: the last dimension varies fastest. */
static void strides_of(const int64_t *shape, int rank, int64_t *strides)
{
    int index;
    int64_t stride = 1;
    for (index = rank - 1; index >= 0; index--) {
        strides[index] = stride;
        stride *= shape[index] > 0 ? shape[index] : 1;
    }
}

charon_ml_array charon_ml_array_make(int data_type, const int64_t *shape, int rank, void *data)
{
    charon_ml_array array;
    memset(&array, 0, sizeof array);
    array.data_type = data_type;
    array.rank = rank;
    if (rank > CHARON_ML_MAX_RANK) {
        array.rank = CHARON_ML_MAX_RANK;
    }
    memcpy(array.shape, shape, (size_t)array.rank * sizeof *shape);
    strides_of(shape, rank, array.strides);
    array.count = (size_t)charon_ml_count_of_shape(shape, rank);
    array.data = data;
    array.owns_data = 0;
    return array;
}

charon_ml_array charon_ml_array_alloc(int data_type, const int64_t *shape, int rank)
{
    charon_ml_array array = charon_ml_array_make(data_type, shape, rank, NULL);
    size_t width = charon_ml_type_size(data_type);
    if (array.count == 0 || width == 0) {
        return array;
    }
    array.data = calloc(array.count, width);
    array.owns_data = array.data != NULL;
    return array;
}

void charon_ml_array_free(charon_ml_array *array)
{
    if (array == NULL) {
        return;
    }
    if (array->owns_data) {
        free(array->data);
    }
    array->data = NULL;
    array->owns_data = 0;
    array->count = 0;
}

charon_ml_array charon_ml_array_subview(const charon_ml_array *array, const int64_t *shape, int rank, int64_t at)
{
    charon_ml_array view = *array;
    if (rank > CHARON_ML_MAX_RANK) {
        rank = CHARON_ML_MAX_RANK;
    }
    view.rank = rank;
    memcpy(view.shape, shape, (size_t)rank * sizeof *shape);
    strides_of(shape, rank, view.strides);
    view.count = (size_t)charon_ml_count_of_shape(shape, rank);
    /* The data is the same buffer: only the offset moves, so a weight matrix is never copied
     * out of the model, and a layer that reads one row of it reads that row where it lies. */
    view.data = array->data == NULL ? NULL : (char *)array->data + at * (int64_t)charon_ml_type_size(array->data_type);
    view.owns_data = 0;
    return view;
}

int charon_ml_array_as(const charon_ml_array *array, int data_type, charon_ml_array *out)
{
    *out = *array;
    out->data_type = data_type;
    out->owns_data = 0;
    if (array->data_type == data_type) {
        return 1;
    }
    /* Only a re-typed view over the same bytes, which is sound only when the widths agree:
     * a layer that wants float32 weights out of a double array has to convert, and refusing
     * is what keeps it from reading a double as two floats. */
    return charon_ml_type_size(array->data_type) == charon_ml_type_size(data_type);
}

float charon_ml_half_to_float(uint16_t half)
{
    unsigned sign = (unsigned)(half >> 15) & 1u;
    int exponent = (int)((half >> 10) & 0x1fu);
    unsigned mantissa = (unsigned)half & 0x3ffu;
    uint32_t bits;
    float value;

    if (exponent == 0) {
        if (mantissa == 0) {
            bits = sign << 31; /* a signed zero */
        } else {
            /* A subnormal half is a normal float with the exponent shifted down: the value is
             * mantissa * 2^-24, which is what putting it at exponent 1 with the mantissa's
             * own leading bit at 2^-10 gives. */
            exponent = 1;
            while ((mantissa & 0x400u) == 0) {
                mantissa <<= 1;
                exponent--;
            }
            mantissa &= 0x3ffu;
            bits = (sign << 31) | ((uint32_t)(exponent - 15 + 127) << 23) | (mantissa << 13);
        }
    } else if (exponent == 31) {
        bits = (sign << 31) | 0x7f800000u | (mantissa << 13); /* an infinity, or a NaN */
    } else {
        bits = (sign << 31) | ((uint32_t)(exponent - 15 + 127) << 23) | (mantissa << 13);
    }
    memcpy(&value, &bits, sizeof value);
    return value;
}

uint16_t charon_ml_float_to_half(float value)
{
    uint32_t bits;
    unsigned sign, exponent, mantissa;
    int unbiased;

    memcpy(&bits, &value, sizeof bits);
    sign = (bits >> 31) & 1u;
    exponent = (bits >> 23) & 0xffu;
    mantissa = bits & 0x7fffffu;
    if (exponent == 0xff) {
        /* An infinity, or a NaN whose payload is kept as far as a half can hold one. */
        return (uint16_t)((sign << 15) | 0x7c00u | (mantissa != 0 ? 0x200u : 0u));
    }
    unbiased = (int)exponent - 127;
    if (unbiased > 15) {
        return (uint16_t)((sign << 15) | 0x7c00u); /* larger than a half holds: an infinity */
    }
    if (unbiased < -14) {
        if (unbiased < -25) {
            return (uint16_t)(sign << 15); /* smaller than a subnormal half: a signed zero */
        }
        /* A subnormal half: the mantissa carries the value, shifted so the leading bit lands
         * where the exponent of a normal half would have put it. */
        mantissa |= 0x800000u;
        {
            int shift = -unbiased - 14 + 13;
            return (uint16_t)((sign << 15) | (mantissa >> shift));
        }
    }
    return (uint16_t)((sign << 15) | (uint16_t)((unbiased + 15) << 10) | (uint16_t)(mantissa >> 13));
}

double charon_ml_array_get(const charon_ml_array *array, int64_t index)
{
    const char *at;
    if (array->data == NULL || index < 0 || (size_t)index >= array->count) {
        return 0.0;
    }
    at = (const char *)array->data + (size_t)index * charon_ml_type_size(array->data_type);
    switch (array->data_type) {
    case CHARON_ML_ARRAY_FLOAT32: {
        float value;
        memcpy(&value, at, sizeof value);
        return (double)value;
    }
    case CHARON_ML_ARRAY_DOUBLE: {
        double value;
        memcpy(&value, at, sizeof value);
        return value;
    }
    case CHARON_ML_ARRAY_INT32: {
        int32_t value;
        memcpy(&value, at, sizeof value);
        return (double)value;
    }
    case CHARON_ML_ARRAY_INT8:
        return (double)*(const int8_t *)at;
    case CHARON_ML_ARRAY_FLOAT16: {
        uint16_t half;
        memcpy(&half, at, sizeof half);
        return (double)charon_ml_half_to_float(half);
    }
    default:
        return 0.0;
    }
}

void charon_ml_array_set(charon_ml_array *array, int64_t index, double value)
{
    char *at;
    if (array->data == NULL || index < 0 || (size_t)index >= array->count) {
        return;
    }
    at = (char *)array->data + (size_t)index * charon_ml_type_size(array->data_type);
    switch (array->data_type) {
    case CHARON_ML_ARRAY_FLOAT32: {
        float narrow = (float)value;
        memcpy(at, &narrow, sizeof narrow);
        break;
    }
    case CHARON_ML_ARRAY_DOUBLE:
        memcpy(at, &value, sizeof value);
        break;
    case CHARON_ML_ARRAY_INT32: {
        int32_t narrow = (int32_t)value;
        memcpy(at, &narrow, sizeof narrow);
        break;
    }
    case CHARON_ML_ARRAY_INT8:
        *(int8_t *)at = (int8_t)value;
        break;
    case CHARON_ML_ARRAY_FLOAT16: {
        float narrow = (float)value;
        memcpy(at, &(uint16_t){charon_ml_float_to_half(narrow)}, sizeof(uint16_t));
        break;
    }
    default:
        break;
    }
}

int64_t charon_ml_array_offset(const charon_ml_array *array, const int64_t *position, int rank)
{
    int64_t offset = 0;
    int index;
    if (rank > array->rank) {
        return -1;
    }
    for (index = 0; index < rank; index++) {
        if (position[index] < 0 || position[index] >= array->shape[index]) {
            return -1;
        }
        offset += position[index] * array->strides[index];
    }
    return offset;
}

charon_ml_value charon_ml_value_number(double number)
{
    charon_ml_value value;
    memset(&value, 0, sizeof value);
    value.kind = CHARON_ML_VALUE_NUMBER;
    value.number = number;
    return value;
}

charon_ml_value charon_ml_value_string(const char *bytes, size_t length)
{
    charon_ml_value value;
    memset(&value, 0, sizeof value);
    value.kind = CHARON_ML_VALUE_STRING;
    value.string.bytes = bytes;
    value.string.length = length;
    return value;
}

charon_ml_value charon_ml_value_string_copy(const char *bytes, size_t length)
{
    charon_ml_value value = charon_ml_value_string(bytes, length);
    char *copy = (char *)malloc(length + 1);
    if (copy == NULL) {
        memset(&value, 0, sizeof value);
        return value;
    }
    if (length > 0) {
        memcpy(copy, bytes, length);
    }
    copy[length] = 0;
    value.string.bytes = copy;
    value.string.owned = 1;
    return value;
}

charon_ml_value charon_ml_value_array(charon_ml_array array)
{
    charon_ml_value value;
    memset(&value, 0, sizeof value);
    value.kind = array.data_type == CHARON_ML_ARRAY_INVALID ? CHARON_ML_VALUE_NONE : CHARON_ML_VALUE_ARRAY;
    value.array = array;
    return value;
}

charon_ml_value charon_ml_value_dictionary(void)
{
    charon_ml_value value;
    memset(&value, 0, sizeof value);
    value.kind = CHARON_ML_VALUE_DICTIONARY;
    return value;
}

int charon_ml_dictionary_put(charon_ml_value *value, const char *key, double number)
{
    char *copy;
    if (value == NULL || value->kind != CHARON_ML_VALUE_DICTIONARY || key == NULL ||
        value->dictionary.count >= CHARON_ML_DICTIONARY_PAIRS) {
        return 0;
    }
    copy = charon_ml_strndup(key, strlen(key));
    if (copy == NULL) {
        return 0;
    }
    value->dictionary.keys[value->dictionary.count] = copy;
    value->dictionary.values[value->dictionary.count] = number;
    value->dictionary.count++;
    return 1;
}

const char *charon_ml_dictionary_get(const charon_ml_value *value, const char *key, double *number, int *found)
{
    size_t index;
    if (number != NULL) {
        *number = 0.0;
    }
    if (value == NULL || value->kind != CHARON_ML_VALUE_DICTIONARY || key == NULL) {
        if (found != NULL) {
            *found = 0;
        }
        return NULL;
    }
    for (index = 0; index < value->dictionary.count; index++) {
        if (strcmp(value->dictionary.keys[index], key) == 0) {
            if (number != NULL) {
                *number = value->dictionary.values[index];
            }
            if (found != NULL) {
                *found = 1;
            }
            return value->dictionary.keys[index];
        }
    }
    if (found != NULL) {
        *found = 0;
    }
    return NULL;
}

void charon_ml_value_free(charon_ml_value *value)
{
    size_t index;
    if (value == NULL) {
        return;
    }
    if (value->kind == CHARON_ML_VALUE_ARRAY) {
        charon_ml_array_free(&value->array);
    }
    if (value->kind == CHARON_ML_VALUE_STRING && value->string.owned) {
        free((void *)value->string.bytes);
    }
    if (value->kind == CHARON_ML_VALUE_DICTIONARY) {
        for (index = 0; index < value->dictionary.count; index++) {
            free(value->dictionary.keys[index]);
        }
    }
    memset(value, 0, sizeof *value);
}
