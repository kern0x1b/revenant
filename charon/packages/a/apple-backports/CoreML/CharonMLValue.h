/* The value a Core ML feature holds, and the array it holds it in.
 *
 * A feature of a model is a scalar, a string, an image, a dictionary or an array, and the
 * model itself names the shape and the element type of each. This is that: a tagged value
 * with an array that knows its own element type, its shape, its strides and how much of it
 * is its own memory, so a prediction can be built in a buffer the caller owns and a
 * borrowed one can be read without copying a weight matrix out of the model.
 */
#ifndef CHARON_ML_VALUE_H
#define CHARON_ML_VALUE_H

#include <stddef.h>
#include <stdint.h>

/* The most dimensions an array has. The value reader, the tensor reader and the
 * Objective-C surface all bound their shape by it, and it is declared here so there is one
 * number rather than three that have to agree. */
#define CHARON_ML_MAX_RANK 8

/* The array element types, by the numbers the CoreML specification gives them. They are not
 * 1, 2, 3: the specification writes each as a bit field, and a container carries those
 * numbers on the wire, so they are named here rather than renumbered. */
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

/* A dimension's size, or that the specification's "flexible" is: an upper bound of -1 in a
 * SizeRange, which is how a model says the length is not fixed. */
#define CHARON_ML_FLEXIBLE (-1)

typedef struct {
    int data_type;      /* one of CHARON_ML_ARRAY_* */
    int rank;
    int64_t shape[CHARON_ML_MAX_RANK];   /* CHARON_ML_FLEXIBLE for a dimension of no fixed length */
    int64_t strides[CHARON_ML_MAX_RANK]; /* in elements, so a sub-array is a window and not a copy */
    size_t count;       /* the elements this window covers, product of the shape */
    void *data;
    int owns_data;      /* whether freeing the value frees the data */
} charon_ml_array;

/* A dictionary of string keys to numbers, which is what a classifier's probabilities are: the
 * specification gives them a dictionaryType output, and an application reads them through
 * MLFeatureProvider's dictionaryValue. The keys keep the order of the classes, so a caller
 * that wants the score of a class by its index has the same answer the model does. */
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
        /* Whether freeing the value frees these bytes. A string read out of a model's document
         * points into that document and is not freed; one a model produced for an answer is
         * its own copy and is. Getting this wrong is a use after free, not a leak, because a
         * borrowed pointer into a document that outlives it reads memory that has moved. */
        int owned;
    } string;
    charon_ml_array array;
    charon_ml_dictionary dictionary;
} charon_ml_value;

/* --- arrays -------------------------------------------------------------------------------- */

size_t charon_ml_type_size(int data_type);
/* The element count of a shape, or 0 when a dimension is flexible: the count of an array
 * with a dimension of no fixed length is not known until the value arrives. */
int charon_ml_count_of_shape(const int64_t *shape, int rank);
/* An array of `count` elements in one buffer, with the shape and strides of that shape. */
charon_ml_array charon_ml_array_make(int data_type, const int64_t *shape, int rank, void *data);
charon_ml_array charon_ml_array_alloc(int data_type, const int64_t *shape, int rank);
void charon_ml_array_free(charon_ml_array *array);
/* A view of the same buffer, offset by `at` elements and restricted to `shape`: no copy, and
 * the strides that follow the new shape. */
charon_ml_array charon_ml_array_subview(const charon_ml_array *array, const int64_t *shape, int rank, int64_t at);
/* The same buffer read as another element type, which is what a layer that takes float32
 * weights out of a double array does. Fails when the widths differ. */
int charon_ml_array_as(const charon_ml_array *array, int data_type, charon_ml_array *out);

/* One element, by its linear index, as a double whatever it is stored as. A half float is
 * converted; an int8 as the number it holds. Reading out of the window is refused by the
 * caller's own bounds check, so this trusts `index`. */
double charon_ml_array_get(const charon_ml_array *array, int64_t index);
void charon_ml_array_set(charon_ml_array *array, int64_t index, double value);
/* The linear index of a position, or -1 when the position is outside the array. */
int64_t charon_ml_array_offset(const charon_ml_array *array, const int64_t *position, int rank);

/* A float16 as the number it holds: the sign, the exponent biased by 15, and the mantissa,
 * which is what the half of IEEE 754 binary32 is. Subnormals and the infinities and NaNs are
 * the same arithmetic, so there is no separate case for them. */
float charon_ml_half_to_float(uint16_t half);
uint16_t charon_ml_float_to_half(float value);

/* --- values -------------------------------------------------------------------------------- */

charon_ml_value charon_ml_value_number(double number);
/* A string value over bytes the caller keeps: the model's own document, or a buffer that
 * outlives the value. */
charon_ml_value charon_ml_value_string(const char *bytes, size_t length);
/* A string value over a copy the value owns and frees, which is what a value a model
 * *produces* must be: an answer outlives the frame that wrote it. */
charon_ml_value charon_ml_value_string_copy(const char *bytes, size_t length);
charon_ml_value charon_ml_value_array(charon_ml_array array);
/* A dictionary, built by adding one key at a time. The keys are copied. */
charon_ml_value charon_ml_value_dictionary(void);
int charon_ml_dictionary_put(charon_ml_value *value, const char *key, double number);
const char *charon_ml_dictionary_get(const charon_ml_value *value, const char *key, double *number,
                                    int *found);
void charon_ml_value_free(charon_ml_value *value);
/* The name a model gives this kind of value, for an error an application reads. */
const char *charon_ml_value_name(charon_ml_value_kind kind);
const char *charon_ml_type_name(int data_type);

#endif /* CHARON_ML_VALUE_H */
