#import "CharonLinearAlgebra.h"
#include <math.h>
#include <objc/message.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wunguarded-availability"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static la_object_t CharonLAWithStatus(la_status_t status, la_attribute_t attributes)
{
    CharonLAValue *value;
    la_object_t object = CharonLANewObject();
    if (!object) {
        return object;
    }
    value = CHARON_LA_VALUE(object);
    memset(value, 0, sizeof(*value));
    value->kind = CharonLAError;
    value->status = status;
    value->attributes = attributes;
    return object;
}

static la_status_t CharonLAStatusOf(la_object_t object)
{
    const CharonLAValue *value = CHARON_LA_VALUE(object);
    return value ? value->status : LA_INVALID_PARAMETER_ERROR;
}

static la_object_t CharonLANewArray(la_count_t rows, la_count_t cols, la_scalar_type_t scalar_type,
                                    la_attribute_t attributes, la_status_t inherited)
{
    CharonLAValue *value;
    la_object_t object = CharonLANewObject();
    if (!object) {
        return object;
    }
    value = CHARON_LA_VALUE(object);
    memset(value, 0, sizeof(*value));
    value->kind = CharonLAArray;
    value->status = inherited;
    value->attributes = attributes;
    value->scalar_type = scalar_type;
    value->rows = rows;
    value->cols = cols;
    if (rows != 0 && cols != 0) {
        if (cols > (la_count_t)-1 / rows) {
            value->kind = CharonLAError;
            value->status = LA_INTERNAL_ERROR;
            return object;
        }
        value->elements = calloc((size_t)rows * cols, CharonLAWidth(scalar_type));
        if (!value->elements) {
            value->kind = CharonLAError;
            value->status = LA_INTERNAL_ERROR;
        }
    }
    return object;
}

static la_object_t CharonLANewSplat(la_scalar_type_t scalar_type, double element, la_attribute_t attributes)
{
    CharonLAValue *value;
    la_object_t object = CharonLANewObject();
    if (!object) {
        return object;
    }
    value = CHARON_LA_VALUE(object);
    memset(value, 0, sizeof(*value));
    value->kind = CharonLASplat;
    value->scalar_type = scalar_type;
    value->splat = element;
    value->attributes = attributes;
    return object;
}

#if OS_OBJECT_USE_OBJC

@implementation CharonLAObject

- (void)dealloc
{
    CharonLAFreeValue(&self->value);
#if !__has_feature(objc_arc)
    [super dealloc];
#endif
}

@end

#undef la_retain
#undef la_release

static SEL CharonLASelectorNamed(const char *name) { return sel_registerName(name); }

la_object_t la_retain(la_object_t object)
{
    id kept = ((id (*)(id, SEL))objc_msgSend)((id)object, CharonLASelectorNamed("retain"));
    return kept;
}

void la_release(la_object_t object)
{
    ((void (*)(id, SEL))objc_msgSend)((id)object, CharonLASelectorNamed("release"));
}

#else

la_object_t la_retain(la_object_t object)
{
    if (object) {
        object->retain_count++;
    }
    return object;
}

void la_release(la_object_t object)
{
    if (object && --object->retain_count == 0) {
        CharonLAFreeValue(&object->value);
        free(object);
    }
}

#endif

la_status_t la_status(la_object_t object)
{
    return CharonLAStatusOf(object);
}

void la_add_attributes(la_object_t object, la_attribute_t attributes)
{
    CharonLAValue *value = CHARON_LA_VALUE(object);
    if (value) {
        value->attributes |= attributes;
    }
}

void la_remove_attributes(la_object_t object, la_attribute_t attributes)
{
    CharonLAValue *value = CHARON_LA_VALUE(object);
    if (value) {
        value->attributes &= ~attributes;
    }
}

la_count_t la_matrix_rows(la_object_t matrix)
{
    const CharonLAValue *value = CHARON_LA_VALUE(matrix);
    return value && value->kind == CharonLAArray ? value->rows : 0;
}

la_count_t la_matrix_cols(la_object_t matrix)
{
    const CharonLAValue *value = CHARON_LA_VALUE(matrix);
    return value && value->kind == CharonLAArray ? value->cols : 0;
}

la_count_t la_vector_length(la_object_t vector)
{
    const CharonLAValue *value = CHARON_LA_VALUE(vector);
    return value ? CharonLALength(value) : 0;
}

static la_object_t CharonLAFromBuffer(const void *buffer, la_scalar_type_t scalar_type, la_count_t rows,
                                      la_count_t cols, la_count_t row_stride, la_hint_t hint, la_attribute_t attributes)
{
    la_object_t result;
    CharonLAValue *value;
    if (!buffer || rows == 0 || cols == 0 || row_stride < cols) {
        return CharonLAWithStatus(LA_INVALID_PARAMETER_ERROR, attributes);
    }
    result = CharonLANewArray(rows, cols, scalar_type, attributes, LA_SUCCESS);
    value = CHARON_LA_VALUE(result);
    if (value->kind != CharonLAArray) {
        return result;
    }
    value->hint = hint;
    for (la_count_t row = 0; row < rows; row++) {
        for (la_count_t col = 0; col < cols; col++) {
            la_count_t at = row * row_stride + col;
            CharonLASet(value, row, col, scalar_type == LA_SCALAR_TYPE_FLOAT ? ((const float *)buffer)[at]
                                                                            : ((const double *)buffer)[at]);
        }
    }
    return result;
}

la_object_t la_matrix_from_float_buffer(const float *buffer, la_count_t matrix_rows, la_count_t matrix_cols,
                                        la_count_t matrix_row_stride, la_hint_t matrix_hint, la_attribute_t attributes)
{
    return CharonLAFromBuffer(buffer, LA_SCALAR_TYPE_FLOAT, matrix_rows, matrix_cols, matrix_row_stride, matrix_hint, attributes);
}

la_object_t la_matrix_from_double_buffer(const double *buffer, la_count_t matrix_rows, la_count_t matrix_cols,
                                          la_count_t matrix_row_stride, la_hint_t matrix_hint, la_attribute_t attributes)
{
    return CharonLAFromBuffer(buffer, LA_SCALAR_TYPE_DOUBLE, matrix_rows, matrix_cols, matrix_row_stride, matrix_hint, attributes);
}

static la_object_t CharonLAFromBufferNoCopy(void *buffer, la_scalar_type_t scalar_type, la_count_t rows,
                                            la_count_t cols, la_count_t row_stride, la_hint_t hint,
                                            la_deallocator_t deallocator, la_attribute_t attributes)
{
    la_object_t result = CharonLAFromBuffer(buffer, scalar_type, rows, cols, row_stride, hint, attributes);
    CharonLAValue *value = CHARON_LA_VALUE(result);
    if (value->kind != CharonLAArray) {
        if (deallocator) {
            deallocator(buffer);
        }
        return result;
    }
    if (row_stride != cols) {
        if (deallocator) {
            deallocator(buffer);
        }
        return result;
    }
    CharonLAFreeValue(value);
    value->elements = buffer;
    value->deallocator = deallocator;
    return result;
}

la_object_t la_matrix_from_float_buffer_nocopy(float *buffer, la_count_t matrix_rows, la_count_t matrix_cols,
                                               la_count_t matrix_row_stride, la_hint_t matrix_hint,
                                               la_deallocator_t deallocator, la_attribute_t attributes)
{
    return CharonLAFromBufferNoCopy(buffer, LA_SCALAR_TYPE_FLOAT, matrix_rows, matrix_cols, matrix_row_stride,
                                    matrix_hint, deallocator, attributes);
}

la_object_t la_matrix_from_double_buffer_nocopy(double *buffer, la_count_t matrix_rows, la_count_t matrix_cols,
                                                 la_count_t matrix_row_stride, la_hint_t matrix_hint,
                                                 la_deallocator_t deallocator, la_attribute_t attributes)
{
    return CharonLAFromBufferNoCopy(buffer, LA_SCALAR_TYPE_DOUBLE, matrix_rows, matrix_cols, matrix_row_stride,
                                    matrix_hint, deallocator, attributes);
}

static la_status_t CharonLAStoreRefused(const CharonLAValue *value, la_scalar_type_t scalar_type)
{
    if (!value || value->kind != CharonLAArray) {
        if (value && value->kind == CharonLASplat && value->scalar_type == scalar_type) {
            return LA_INVALID_PARAMETER_ERROR;
        }
        return LA_PRECISION_MISMATCH_ERROR;
    }
    return value->scalar_type == scalar_type ? LA_SUCCESS : LA_PRECISION_MISMATCH_ERROR;
}

static la_status_t CharonLAStore(la_scalar_type_t scalar_type, la_count_t stride, la_object_t object, void *buffer)
{
    const CharonLAValue *value = CHARON_LA_VALUE(object);
    la_count_t count, width;
    if (!buffer) {
        return LA_PRECISION_MISMATCH_ERROR;
    }
    count = value->rows * value->cols;
    width = value->cols;
    for (la_count_t at = 0; at < count; at++) {
        la_count_t row = at / width, col = at % width, destination = (at / width) * stride + (at % width);
        double element = CharonLAGet(value, row, col);
        if (scalar_type == LA_SCALAR_TYPE_FLOAT) {
            ((float *)buffer)[destination] = (float)element;
        } else {
            ((double *)buffer)[destination] = element;
        }
    }
    return LA_SUCCESS;
}

la_status_t la_vector_to_float_buffer(float *buffer, la_index_t buffer_stride, la_object_t vector)
{
    const CharonLAValue *value = CHARON_LA_VALUE(vector);
    la_status_t refused = CharonLAStoreRefused(value, LA_SCALAR_TYPE_FLOAT);
    if (refused != LA_SUCCESS) {
        return refused;
    }
    if (value->rows != 1 && value->cols != 1) {
        return LA_INVALID_PARAMETER_ERROR;
    }
    return CharonLAStore(LA_SCALAR_TYPE_FLOAT, (la_count_t)buffer_stride, vector, buffer);
}

la_status_t la_vector_to_double_buffer(double *buffer, la_index_t buffer_stride, la_object_t vector)
{
    const CharonLAValue *value = CHARON_LA_VALUE(vector);
    la_status_t refused = CharonLAStoreRefused(value, LA_SCALAR_TYPE_DOUBLE);
    if (refused != LA_SUCCESS) {
        return refused;
    }
    if (value->rows != 1 && value->cols != 1) {
        return LA_INVALID_PARAMETER_ERROR;
    }
    return CharonLAStore(LA_SCALAR_TYPE_DOUBLE, (la_count_t)buffer_stride, vector, buffer);
}

la_status_t la_matrix_to_float_buffer(float *buffer, la_count_t buffer_row_stride, la_object_t matrix)
{
    la_status_t refused = CharonLAStoreRefused(CHARON_LA_VALUE(matrix), LA_SCALAR_TYPE_FLOAT);
    if (refused != LA_SUCCESS) {
        return refused;
    }
    return CharonLAStore(LA_SCALAR_TYPE_FLOAT, buffer_row_stride, matrix, buffer);
}

la_status_t la_matrix_to_double_buffer(double *buffer, la_count_t buffer_row_stride, la_object_t matrix)
{
    la_status_t refused = CharonLAStoreRefused(CHARON_LA_VALUE(matrix), LA_SCALAR_TYPE_DOUBLE);
    if (refused != LA_SUCCESS) {
        return refused;
    }
    return CharonLAStore(LA_SCALAR_TYPE_DOUBLE, buffer_row_stride, matrix, buffer);
}

static int CharonLAInRange(la_index_t first, la_index_t stride, la_count_t count, la_count_t limit)
{
    la_index_t last = first + (la_index_t)(count - 1) * stride;
    la_index_t low = first < last ? first : last;
    la_index_t high = first < last ? last : first;
    return low >= 0 && high < (la_index_t)limit;
}

la_object_t la_vector_slice(la_object_t vector, la_index_t vector_first, la_index_t vector_stride, la_count_t slice_length)
{
    const CharonLAValue *value = CHARON_LA_VALUE(vector);
    la_count_t length;
    int across;
    la_object_t result;
    CharonLAValue *to;
    if (!value || value->kind != CharonLAArray || (value->rows != 1 && value->cols != 1)) {
        return CharonLAWithStatus(LA_INVALID_PARAMETER_ERROR, 0);
    }
    length = CharonLALength(value);
    if (slice_length == 0 || !CharonLAInRange(vector_first, vector_stride, slice_length, length)) {
        return CharonLAWithStatus(LA_SLICE_OUT_OF_BOUNDS_ERROR, value->attributes);
    }
    across = value->rows == 1;
    result = CharonLANewArray(across ? 1 : slice_length, across ? slice_length : 1, value->scalar_type,
                              value->attributes, value->status);
    to = CHARON_LA_VALUE(result);
    if (to->kind != CharonLAArray) {
        return result;
    }
    for (la_count_t at = 0; at < slice_length; at++) {
        la_index_t source = vector_first + (la_index_t)at * vector_stride;
        double element = across ? CharonLAGet(value, 0, (la_count_t)source) : CharonLAGet(value, (la_count_t)source, 0);
        if (across) {
            CharonLASet(to, 0, at, element);
        } else {
            CharonLASet(to, at, 0, element);
        }
    }
    return result;
}

la_object_t la_matrix_slice(la_object_t matrix, la_index_t matrix_first_row, la_index_t matrix_first_col,
                            la_index_t matrix_row_stride, la_index_t matrix_col_stride,
                            la_count_t slice_rows, la_count_t slice_cols)
{
    const CharonLAValue *value = CHARON_LA_VALUE(matrix);
    la_object_t result;
    CharonLAValue *to;
    if (!value || value->kind != CharonLAArray) {
        return CharonLAWithStatus(LA_INVALID_PARAMETER_ERROR, 0);
    }
    if (slice_rows == 0 || slice_cols == 0 ||
        !CharonLAInRange(matrix_first_row, matrix_row_stride, slice_rows, value->rows) ||
        !CharonLAInRange(matrix_first_col, matrix_col_stride, slice_cols, value->cols)) {
        return CharonLAWithStatus(LA_SLICE_OUT_OF_BOUNDS_ERROR, value->attributes);
    }
    result = CharonLANewArray(slice_rows, slice_cols, value->scalar_type, value->attributes, value->status);
    to = CHARON_LA_VALUE(result);
    if (to->kind != CharonLAArray) {
        return result;
    }
    for (la_count_t row = 0; row < slice_rows; row++) {
        for (la_count_t col = 0; col < slice_cols; col++) {
            CharonLASet(to, row, col,
                        CharonLAGet(value, (la_count_t)(matrix_first_row + (la_index_t)row * matrix_row_stride),
                                    (la_count_t)(matrix_first_col + (la_index_t)col * matrix_col_stride)));
        }
    }
    return result;
}

la_object_t la_identity_matrix(la_count_t matrix_size, la_scalar_type_t scalar_type, la_attribute_t attributes)
{
    la_object_t result;
    CharonLAValue *value;
    if (scalar_type != LA_SCALAR_TYPE_FLOAT && scalar_type != LA_SCALAR_TYPE_DOUBLE) {
        return CharonLAWithStatus(LA_INVALID_PARAMETER_ERROR, attributes);
    }
    result = CharonLANewArray(matrix_size, matrix_size, scalar_type, attributes, LA_SUCCESS);
    value = CHARON_LA_VALUE(result);
    if (value->kind != CharonLAArray) {
        return result;
    }
    value->hint = LA_SHAPE_DIAGONAL;
    for (la_count_t at = 0; at < matrix_size; at++) {
        CharonLASet(value, at, at, 1.0);
    }
    return result;
}

la_object_t la_splat_from_float(float scalar_value, la_attribute_t attributes)
{
    return CharonLANewSplat(LA_SCALAR_TYPE_FLOAT, scalar_value, attributes);
}

la_object_t la_splat_from_double(double scalar_value, la_attribute_t attributes)
{
    return CharonLANewSplat(LA_SCALAR_TYPE_DOUBLE, scalar_value, attributes);
}

la_object_t la_splat_from_vector_element(la_object_t vector, la_index_t vector_index)
{
    const CharonLAValue *value = CHARON_LA_VALUE(vector);
    la_count_t length;
    if (!value || value->kind != CharonLAArray) {
        return CharonLAWithStatus(LA_INVALID_PARAMETER_ERROR, 0);
    }
    length = CharonLALength(value);
    if (vector_index < 0 || (la_count_t)vector_index >= length) {
        return CharonLAWithStatus(LA_DIMENSION_MISMATCH_ERROR, value->attributes);
    }
    return CharonLANewSplat(value->scalar_type,
                            value->rows == 1 ? CharonLAGet(value, 0, (la_count_t)vector_index)
                                             : CharonLAGet(value, (la_count_t)vector_index, 0),
                            value->attributes);
}

la_object_t la_splat_from_matrix_element(la_object_t matrix, la_index_t matrix_row, la_index_t matrix_col)
{
    const CharonLAValue *value = CHARON_LA_VALUE(matrix);
    if (!value || value->kind != CharonLAArray) {
        return CharonLAWithStatus(LA_INVALID_PARAMETER_ERROR, 0);
    }
    if (matrix_row < 0 || matrix_col < 0 || (la_count_t)matrix_row >= value->rows || (la_count_t)matrix_col >= value->cols) {
        return CharonLAWithStatus(LA_DIMENSION_MISMATCH_ERROR, value->attributes);
    }
    return CharonLANewSplat(value->scalar_type, CharonLAGet(value, (la_count_t)matrix_row, (la_count_t)matrix_col),
                            value->attributes);
}

la_object_t la_vector_from_splat(la_object_t splat, la_count_t vector_length)
{
    const CharonLAValue *value = CHARON_LA_VALUE(splat);
    la_object_t result;
    CharonLAValue *to;
    if (!value || value->kind != CharonLASplat) {
        return CharonLAWithStatus(LA_INVALID_PARAMETER_ERROR, 0);
    }
    result = CharonLANewArray(vector_length, 1, value->scalar_type, value->attributes, LA_SUCCESS);
    to = CHARON_LA_VALUE(result);
    if (to->kind != CharonLAArray) {
        return result;
    }
    for (la_count_t at = 0; at < vector_length; at++) {
        CharonLASet(to, at, 0, value->splat);
    }
    return result;
}

la_object_t la_matrix_from_splat(la_object_t splat, la_count_t matrix_rows, la_count_t matrix_cols)
{
    const CharonLAValue *value = CHARON_LA_VALUE(splat);
    la_object_t result;
    CharonLAValue *to;
    if (!value || value->kind != CharonLASplat) {
        return CharonLAWithStatus(LA_INVALID_PARAMETER_ERROR, 0);
    }
    result = CharonLANewArray(matrix_rows, matrix_cols, value->scalar_type, value->attributes, LA_SUCCESS);
    to = CHARON_LA_VALUE(result);
    if (to->kind != CharonLAArray) {
        return result;
    }
    for (la_count_t row = 0; row < matrix_rows; row++) {
        for (la_count_t col = 0; col < matrix_cols; col++) {
            CharonLASet(to, row, col, value->splat);
        }
    }
    return result;
}

la_object_t la_vector_from_matrix_row(la_object_t matrix, la_count_t matrix_row)
{
    const CharonLAValue *value = CHARON_LA_VALUE(matrix);
    la_object_t result;
    CharonLAValue *to;
    if (!value || value->kind != CharonLAArray) {
        return CharonLAWithStatus(LA_INVALID_PARAMETER_ERROR, 0);
    }
    if (matrix_row >= value->rows) {
        return CharonLAWithStatus(LA_INVALID_PARAMETER_ERROR, value->attributes);
    }
    result = CharonLANewArray(1, value->cols, value->scalar_type, value->attributes, value->status);
    to = CHARON_LA_VALUE(result);
    if (to->kind != CharonLAArray) {
        return result;
    }
    for (la_count_t col = 0; col < value->cols; col++) {
        CharonLASet(to, 0, col, CharonLAGet(value, matrix_row, col));
    }
    return result;
}

la_object_t la_vector_from_matrix_col(la_object_t matrix, la_count_t matrix_col)
{
    const CharonLAValue *value = CHARON_LA_VALUE(matrix);
    la_object_t result;
    CharonLAValue *to;
    if (!value || value->kind != CharonLAArray) {
        return CharonLAWithStatus(LA_INVALID_PARAMETER_ERROR, 0);
    }
    if (matrix_col >= value->cols) {
        return CharonLAWithStatus(LA_INVALID_PARAMETER_ERROR, value->attributes);
    }
    result = CharonLANewArray(value->rows, 1, value->scalar_type, value->attributes, value->status);
    to = CHARON_LA_VALUE(result);
    if (to->kind != CharonLAArray) {
        return result;
    }
    for (la_count_t row = 0; row < value->rows; row++) {
        CharonLASet(to, row, 0, CharonLAGet(value, row, matrix_col));
    }
    return result;
}

la_object_t la_vector_from_matrix_diagonal(la_object_t matrix, la_index_t matrix_diagonal)
{
    const CharonLAValue *value = CHARON_LA_VALUE(matrix);
    la_index_t offset = matrix_diagonal < 0 ? -matrix_diagonal : matrix_diagonal;
    la_count_t length;
    la_object_t result;
    CharonLAValue *to;
    if (!value || value->kind != CharonLAArray) {
        return CharonLAWithStatus(LA_INVALID_PARAMETER_ERROR, 0);
    }
    if (matrix_diagonal >= (la_index_t)value->cols || offset >= (la_index_t)value->rows) {
        return CharonLAWithStatus(LA_INVALID_PARAMETER_ERROR, value->attributes);
    }
    length = value->rows < value->cols - offset ? value->rows : value->cols - offset;
    result = CharonLANewArray(length, 1, value->scalar_type, value->attributes, value->status);
    to = CHARON_LA_VALUE(result);
    if (to->kind != CharonLAArray) {
        return result;
    }
    for (la_count_t at = 0; at < length; at++) {
        CharonLASet(to, at, 0, matrix_diagonal >= 0 ? CharonLAGet(value, at, at + offset)
                                                    : CharonLAGet(value, at + offset, at));
    }
    return result;
}

la_object_t la_diagonal_matrix_from_vector(la_object_t vector, la_index_t matrix_diagonal)
{
    const CharonLAValue *value = CHARON_LA_VALUE(vector);
    la_count_t length, size, offset = matrix_diagonal < 0 ? (la_count_t)-matrix_diagonal : (la_count_t)matrix_diagonal;
    la_object_t result;
    CharonLAValue *to;
    if (!value || value->kind != CharonLAArray || (value->rows != 1 && value->cols != 1)) {
        return CharonLAWithStatus(LA_INVALID_PARAMETER_ERROR, 0);
    }
    length = CharonLALength(value);
    size = length + offset;
    result = CharonLANewArray(size, size, value->scalar_type, value->attributes, value->status);
    to = CHARON_LA_VALUE(result);
    if (to->kind != CharonLAArray) {
        return result;
    }
    to->hint = LA_SHAPE_DIAGONAL;
    for (la_count_t at = 0; at < length; at++) {
        la_count_t row = matrix_diagonal >= 0 ? at : at + offset;
        la_count_t col = matrix_diagonal >= 0 ? at + offset : at;
        CharonLASet(to, row, col, value->rows == 1 ? CharonLAGet(value, 0, at) : CharonLAGet(value, at, 0));
    }
    return result;
}

la_object_t la_transpose(la_object_t matrix)
{
    const CharonLAValue *value = CHARON_LA_VALUE(matrix);
    la_object_t result;
    CharonLAValue *to;
    if (!value || value->kind != CharonLAArray) {
        return CharonLAWithStatus(LA_INVALID_PARAMETER_ERROR, 0);
    }
    result = CharonLANewArray(value->cols, value->rows, value->scalar_type, value->attributes, value->status);
    to = CHARON_LA_VALUE(result);
    if (to->kind != CharonLAArray) {
        return result;
    }
    for (la_count_t row = 0; row < value->rows; row++) {
        for (la_count_t col = 0; col < value->cols; col++) {
            CharonLASet(to, col, row, CharonLAGet(value, row, col));
        }
    }
    return result;
}

static la_object_t CharonLAScale(la_object_t object, double scalar, la_scalar_type_t scalar_type)
{
    const CharonLAValue *value = CHARON_LA_VALUE(object);
    la_object_t result;
    CharonLAValue *to;
    if (!value || value->kind != CharonLAArray) {
        return CharonLAWithStatus(LA_INVALID_PARAMETER_ERROR, 0);
    }
    if (value->scalar_type != scalar_type) {
        return CharonLAWithStatus(LA_PRECISION_MISMATCH_ERROR, value->attributes);
    }
    result = CharonLANewArray(value->rows, value->cols, value->scalar_type, value->attributes, value->status);
    to = CHARON_LA_VALUE(result);
    if (to->kind != CharonLAArray) {
        return result;
    }
    for (la_count_t row = 0; row < value->rows; row++) {
        for (la_count_t col = 0; col < value->cols; col++) {
            double element = CharonLAGet(value, row, col);
            CharonLASet(to, row, col, scalar_type == LA_SCALAR_TYPE_FLOAT ? (float)(element * (float)scalar)
                                                                         : element * scalar);
        }
    }
    return result;
}

la_object_t la_scale_with_float(la_object_t matrix, float scalar)
{
    return CharonLAScale(matrix, scalar, LA_SCALAR_TYPE_FLOAT);
}

la_object_t la_scale_with_double(la_object_t matrix, double scalar)
{
    return CharonLAScale(matrix, scalar, LA_SCALAR_TYPE_DOUBLE);
}

typedef struct CharonLAOperand {
    la_status_t status;
    la_attribute_t attributes;
    la_scalar_type_t scalar_type;
    la_count_t rows;
    la_count_t cols;
    la_count_t length;
    int is_splat;
    int is_vector;
} CharonLAOperand;

static void CharonLAOperandOf(la_object_t object, CharonLAOperand *operand)
{
    const CharonLAValue *value = CHARON_LA_VALUE(object);
    memset(operand, 0, sizeof(*operand));
    if (!value) {
        operand->status = LA_INVALID_PARAMETER_ERROR;
        return;
    }
    operand->status = value->status;
    operand->attributes = value->attributes;
    operand->scalar_type = value->scalar_type;
    operand->is_splat = value->kind == CharonLASplat;
    if (value->kind == CharonLAArray) {
        operand->rows = value->rows;
        operand->cols = value->cols;
        operand->length = CharonLALength(value);
        operand->is_vector = value->rows == 1 || value->cols == 1;
    }
}

static la_status_t CharonLATypes(la_object_t left, la_object_t right, CharonLAOperand *a, CharonLAOperand *b,
                                 la_attribute_t *attributes)
{
    CharonLAOperandOf(left, a);
    CharonLAOperandOf(right, b);
    *attributes = a->attributes | b->attributes;
    if (a->status != LA_SUCCESS) {
        return a->status;
    }
    if (a->scalar_type != b->scalar_type) {
        return LA_PRECISION_MISMATCH_ERROR;
    }
    if (a->is_splat && b->is_splat) {
        return LA_INVALID_PARAMETER_ERROR;
    }
    return LA_SUCCESS;
}

static la_status_t CharonLAPair(la_object_t left, la_object_t right, CharonLAOperand *a, CharonLAOperand *b,
                                 la_attribute_t *attributes)
{
    la_status_t refused = CharonLATypes(left, right, a, b, attributes);
    if (refused != LA_SUCCESS) {
        return refused;
    }
    if (!a->is_splat && !b->is_splat && (a->rows != b->rows || a->cols != b->cols)) {
        return LA_DIMENSION_MISMATCH_ERROR;
    }
    return LA_SUCCESS;
}

static double CharonLAOperandElement(la_object_t object, const CharonLAOperand *operand, la_count_t row, la_count_t col)
{
    if (operand->is_splat) {
        return CHARON_LA_VALUE(object)->splat;
    }
    return CharonLAGet(CHARON_LA_VALUE(object), operand->rows == 1 ? 0 : row, operand->cols == 1 ? 0 : col);
}

static double CharonLAOperandAt(la_object_t object, const CharonLAOperand *operand, la_count_t at)
{
    if (operand->is_splat) {
        return CHARON_LA_VALUE(object)->splat;
    }
    return operand->rows == 1 ? CharonLAGet(CHARON_LA_VALUE(object), 0, at) : CharonLAGet(CHARON_LA_VALUE(object), at, 0);
}

typedef enum { CharonLAAdd, CharonLASubtract, CharonLAMultiply } CharonLAElementwise;

static la_object_t CharonLAElementwiseOp(CharonLAElementwise which, la_object_t left, la_object_t right)
{
    CharonLAOperand a, b;
    la_attribute_t attributes;
    la_status_t refused = CharonLAPair(left, right, &a, &b, &attributes);
    la_count_t rows, cols;
    la_object_t result;
    CharonLAValue *to;
    if (refused != LA_SUCCESS) {
        return CharonLAWithStatus(refused, attributes);
    }
    rows = a.is_splat ? b.rows : a.rows;
    cols = a.is_splat ? b.cols : a.cols;
    result = CharonLANewArray(rows, cols, a.scalar_type, attributes, LA_SUCCESS);
    to = CHARON_LA_VALUE(result);
    if (to->kind != CharonLAArray) {
        return result;
    }
    for (la_count_t row = 0; row < rows; row++) {
        for (la_count_t col = 0; col < cols; col++) {
            double x = CharonLAOperandElement(left, &a, row, col);
            double y = CharonLAOperandElement(right, &b, row, col);
            if (a.scalar_type == LA_SCALAR_TYPE_FLOAT) {
                x = (float)x;
                y = (float)y;
            }
            CharonLASet(to, row, col, which == CharonLAAdd ? x + y : which == CharonLASubtract ? x - y : x * y);
        }
    }
    return result;
}

la_object_t la_sum(la_object_t obj_left, la_object_t obj_right)
{
    return CharonLAElementwiseOp(CharonLAAdd, obj_left, obj_right);
}

la_object_t la_difference(la_object_t obj_left, la_object_t obj_right)
{
    return CharonLAElementwiseOp(CharonLASubtract, obj_left, obj_right);
}

la_object_t la_elementwise_product(la_object_t obj_left, la_object_t obj_right)
{
    return CharonLAElementwiseOp(CharonLAMultiply, obj_left, obj_right);
}

#define CHARON_LA_BY_SHAPE 0
#define CHARON_LA_BY_INNER 1
#define CHARON_LA_BY_COLUMN 2

static la_object_t CharonLAGemm(la_object_t left, la_object_t right, la_count_t rows, la_count_t inner, la_count_t cols,
                                int left_flat, int right_flat)
{
    CharonLAOperand a, b;
    la_attribute_t attributes;
    la_status_t refused = CharonLATypes(left, right, &a, &b, &attributes);
    float *af = NULL, *bf = NULL;
    double *ad = NULL, *bd = NULL;
    la_object_t result;
    CharonLAValue *to;
    if (refused != LA_SUCCESS) {
        return CharonLAWithStatus(refused, attributes);
    }
    result = CharonLANewArray(rows, cols, a.scalar_type, attributes, LA_SUCCESS);
    to = CHARON_LA_VALUE(result);
    if (to->kind != CharonLAArray) {
        return result;
    }
    if (rows == 0 || cols == 0) {
        return result;
    }
    la_count_t left_count = rows * (inner ? inner : 1), right_count = (inner ? inner : 1) * cols;
    int lda = inner ? (int)inner : 1, ldb = inner ? (int)cols : 1;
    if (a.scalar_type == LA_SCALAR_TYPE_FLOAT) {
        af = calloc(left_count, sizeof(float));
        bf = calloc(right_count, sizeof(float));
    } else {
        ad = calloc(left_count, sizeof(double));
        bd = calloc(right_count, sizeof(double));
    }
    if (!(af && bf) && !(ad && bd)) {
        free(af);
        free(bf);
        free(ad);
        free(bd);
        return CharonLAWithStatus(LA_INTERNAL_ERROR, attributes);
    }
    for (la_count_t row = 0; row < rows; row++) {
        for (la_count_t at = 0; at < inner; at++) {
            double element = left_flat ? CharonLAOperandAt(left, &a, at) : CharonLAOperandElement(left, &a, row, at);
            if (af) {
                af[row * inner + at] = (float)element;
            } else {
                ad[row * inner + at] = element;
            }
        }
    }
    for (la_count_t at = 0; at < inner; at++) {
        for (la_count_t col = 0; col < cols; col++) {
            double element = right_flat == CHARON_LA_BY_INNER   ? CharonLAOperandAt(right, &b, at)
                             : right_flat == CHARON_LA_BY_COLUMN ? CharonLAOperandAt(right, &b, col)
                                                                 : CharonLAOperandElement(right, &b, at, col);
            if (bf) {
                bf[at * cols + col] = (float)element;
            } else {
                bd[at * cols + col] = element;
            }
        }
    }
    if (af) {
        cblas_sgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans, (int)rows, (int)cols, (int)inner, 1.0f, af, lda, bf,
                    ldb, 0.0f, (float *)to->elements, (int)cols);
    } else {
        cblas_dgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans, (int)rows, (int)cols, (int)inner, 1.0, ad, lda, bd, ldb,
                    0.0, (double *)to->elements, (int)cols);
    }
    free(af);
    free(bf);
    free(ad);
    free(bd);
    return result;
}

la_object_t la_matrix_product(la_object_t matrix_left, la_object_t matrix_right)
{
    CharonLAOperand a, b;
    CharonLAOperandOf(matrix_left, &a);
    CharonLAOperandOf(matrix_right, &b);
    if (a.is_splat) {
        return CharonLAGemm(matrix_left, matrix_right, 1, b.rows, b.is_splat ? 1 : b.cols, 0, 0);
    }
    if (b.is_splat) {
        return CharonLAGemm(matrix_left, matrix_right, a.rows, a.cols, 1, 0, 0);
    }
    if (a.cols != b.rows) {
        return CharonLAWithStatus(LA_DIMENSION_MISMATCH_ERROR, a.attributes | b.attributes);
    }
    return CharonLAGemm(matrix_left, matrix_right, a.rows, a.cols, b.cols, 0, 0);
}

la_object_t la_outer_product(la_object_t vector_left, la_object_t vector_right)
{
    CharonLAOperand a, b;
    la_attribute_t attributes;
    la_status_t refused;
    la_object_t result;
    CharonLAValue *to;
    CharonLAOperandOf(vector_left, &a);
    CharonLAOperandOf(vector_right, &b);
    refused = CharonLATypes(vector_left, vector_right, &a, &b, &attributes);
    if (refused != LA_SUCCESS) {
        return CharonLAWithStatus(refused, attributes);
    }
    if (a.is_splat || b.is_splat || !a.is_vector || !b.is_vector) {
        return CharonLAWithStatus(LA_INVALID_PARAMETER_ERROR, attributes);
    }
    result = CharonLANewArray(a.length, b.length, a.scalar_type, attributes, LA_SUCCESS);
    to = CHARON_LA_VALUE(result);
    if (to->kind != CharonLAArray) {
        return result;
    }
    for (la_count_t row = 0; row < a.length; row++) {
        double x = CharonLAOperandAt(vector_left, &a, row);
        for (la_count_t col = 0; col < b.length; col++) {
            double y = CharonLAOperandAt(vector_right, &b, col);
            CharonLASet(to, row, col, a.scalar_type == LA_SCALAR_TYPE_FLOAT ? (float)x * (float)y : x * y);
        }
    }
    return result;
}

la_object_t la_inner_product(la_object_t vector_left, la_object_t vector_right)
{
    CharonLAOperand a, b;
    la_attribute_t attributes;
    la_status_t refused = CharonLAPair(vector_left, vector_right, &a, &b, &attributes);
    if (refused != LA_SUCCESS) {
        return CharonLAWithStatus(refused, attributes);
    }
    if ((!a.is_splat && !a.is_vector) || (!b.is_splat && !b.is_vector)) {
        return CharonLAWithStatus(LA_DIMENSION_MISMATCH_ERROR, attributes);
    }
    if (!a.is_splat && !b.is_splat && a.length != b.length) {
        return CharonLAWithStatus(LA_DIMENSION_MISMATCH_ERROR, attributes);
    }
    return CharonLAGemm(vector_left, vector_right, 1, a.is_splat ? b.length : a.length, 1, 1, CHARON_LA_BY_INNER);
}

static double CharonLANorm(la_object_t object, la_norm_t norm, la_scalar_type_t scalar_type, int *valid)
{
    const CharonLAValue *value = CHARON_LA_VALUE(object);
    la_count_t count;
    double sum = 0.0, largest = 0.0;
    *valid = 0;
    if (!value || value->kind != CharonLAArray || value->scalar_type != scalar_type) {
        return NAN;
    }
    if (norm != LA_L1_NORM && norm != LA_L2_NORM && norm != LA_LINF_NORM) {
        return NAN;
    }
    count = value->rows * value->cols;
    for (la_count_t at = 0; at < count; at++) {
        double element = CharonLAGet(value, at / value->cols, at % value->cols);
        double magnitude = fabs(element);
        if (norm == LA_L1_NORM) {
            sum += magnitude;
        } else if (norm == LA_L2_NORM) {
            sum += magnitude * magnitude;
        } else if (magnitude > largest) {
            largest = magnitude;
        }
    }
    *valid = 1;
    if (norm == LA_L2_NORM) {
        return sqrt(sum);
    }
    return norm == LA_L1_NORM ? sum : largest;
}

float la_norm_as_float(la_object_t vector, la_norm_t vector_norm)
{
    int valid;
    double norm = CharonLANorm(vector, vector_norm, LA_SCALAR_TYPE_FLOAT, &valid);
    return valid ? (float)norm : NAN;
}

double la_norm_as_double(la_object_t vector, la_norm_t vector_norm)
{
    int valid;
    return CharonLANorm(vector, vector_norm, LA_SCALAR_TYPE_DOUBLE, &valid);
}

la_object_t la_normalized_vector(la_object_t vector, la_norm_t vector_norm)
{
    const CharonLAValue *value = CHARON_LA_VALUE(vector);
    int valid;
    double norm;
    la_object_t result;
    CharonLAValue *to;
    la_count_t count;
    if (!value || value->kind != CharonLAArray) {
        return CharonLAWithStatus(LA_INVALID_PARAMETER_ERROR, 0);
    }
    norm = CharonLANorm(vector, vector_norm, value->scalar_type, &valid);
    if (!valid) {
        return CharonLAWithStatus(LA_INVALID_PARAMETER_ERROR, value->attributes);
    }
    result = CharonLANewArray(value->rows, value->cols, value->scalar_type, value->attributes, value->status);
    to = CHARON_LA_VALUE(result);
    if (to->kind != CharonLAArray) {
        return result;
    }
    if (norm == 0.0) {
        return result;
    }
    count = value->rows * value->cols;
    for (la_count_t at = 0; at < count; at++) {
        la_count_t row = at / value->cols, col = at % value->cols;
        double element = CharonLAGet(value, row, col) / norm;
        CharonLASet(to, row, col, value->scalar_type == LA_SCALAR_TYPE_FLOAT ? (float)element : element);
    }
    return result;
}

static int CharonLALapackFloat(const CharonLAValue *system, const CharonLAValue *rhs, int vector_rhs,
                               CharonLAValue *to, la_count_t n, la_count_t columns, float *factor, float *right,
                               __CLPK_integer *pivots)
{
    __CLPK_integer order = (__CLPK_integer)n, leading = (__CLPK_integer)n, count = (__CLPK_integer)columns,
                   info = 0;
    char trans = 'N';
    la_count_t row, col;
    for (col = 0; col < n; col++) {
        for (row = 0; row < n; row++) {
            factor[col * n + row] = (float)CharonLAGet(system, row, col);
        }
    }
    for (col = 0; col < columns; col++) {
        for (row = 0; row < n; row++) {
            right[col * n + row] =
                (float)(vector_rhs ? (rhs->rows == 1 ? CharonLAGet(rhs, 0, row) : CharonLAGet(rhs, row, 0))
                                   : CharonLAGet(rhs, row, col));
        }
    }
    sgetrf_(&order, &order, factor, &leading, pivots, &info);
    if (info > 0) {
        return 1;
    }
    sgetrs_(&trans, &order, &count, factor, &leading, pivots, right, &leading, &info);
    for (col = 0; col < columns; col++) {
        for (row = 0; row < n; row++) {
            CharonLASet(to, row, col, right[col * n + row]);
        }
    }
    return 0;
}

static int CharonLALapackDouble(const CharonLAValue *system, const CharonLAValue *rhs, int vector_rhs,
                                CharonLAValue *to, la_count_t n, la_count_t columns, double *factor, double *right,
                                __CLPK_integer *pivots)
{
    __CLPK_integer order = (__CLPK_integer)n, leading = (__CLPK_integer)n, count = (__CLPK_integer)columns,
                   info = 0;
    char trans = 'N';
    la_count_t row, col;
    for (col = 0; col < n; col++) {
        for (row = 0; row < n; row++) {
            factor[col * n + row] = CharonLAGet(system, row, col);
        }
    }
    for (col = 0; col < columns; col++) {
        for (row = 0; row < n; row++) {
            right[col * n + row] =
                vector_rhs ? (rhs->rows == 1 ? CharonLAGet(rhs, 0, row) : CharonLAGet(rhs, row, 0))
                           : CharonLAGet(rhs, row, col);
        }
    }
    dgetrf_(&order, &order, factor, &leading, pivots, &info);
    if (info > 0) {
        return 1;
    }
    dgetrs_(&trans, &order, &count, factor, &leading, pivots, right, &leading, &info);
    for (col = 0; col < columns; col++) {
        for (row = 0; row < n; row++) {
            CharonLASet(to, row, col, right[col * n + row]);
        }
    }
    return 0;
}

la_object_t la_solve(la_object_t matrix_system, la_object_t obj_rhs)
{
    CharonLAOperand a, b;
    const CharonLAValue *system = CHARON_LA_VALUE(matrix_system);
    const CharonLAValue *rhs = CHARON_LA_VALUE(obj_rhs);
    la_attribute_t attributes;
    la_status_t refused;
    la_count_t n, columns;
    int vector_rhs, singular;
    la_object_t result;
    CharonLAValue *to;
    void *factor = NULL, *right = NULL;
    __CLPK_integer *pivots = NULL;
    if (!system || !rhs) {
        return CharonLAWithStatus(LA_INVALID_PARAMETER_ERROR, 0);
    }
    CharonLAOperandOf(matrix_system, &a);
    CharonLAOperandOf(obj_rhs, &b);
    attributes = a.attributes | b.attributes;
    refused = a.status != LA_SUCCESS ? a.status : LA_SUCCESS;
    if (refused != LA_SUCCESS) {
        return CharonLAWithStatus(refused, attributes);
    }
    if (a.scalar_type != b.scalar_type) {
        return CharonLAWithStatus(LA_PRECISION_MISMATCH_ERROR, attributes);
    }
    if (a.is_splat || b.is_splat) {
        return CharonLAWithStatus(LA_INVALID_PARAMETER_ERROR, attributes);
    }
    if (!a.rows) {
        return CharonLAWithStatus(LA_INVALID_PARAMETER_ERROR, attributes);
    }
    if (a.rows != a.cols) {
        return CharonLAWithStatus(LA_DIMENSION_MISMATCH_ERROR, attributes);
    }
    n = a.rows;
    vector_rhs = b.is_vector;
    columns = vector_rhs ? 1 : b.cols;
    if ((vector_rhs ? b.length : b.rows) != n || !columns) {
        return CharonLAWithStatus(LA_DIMENSION_MISMATCH_ERROR, attributes);
    }
    result = CharonLANewArray(n, columns, a.scalar_type, attributes, LA_SUCCESS);
    to = CHARON_LA_VALUE(result);
    if (to->kind != CharonLAArray) {
        return result;
    }
    factor = calloc((size_t)n * n, CharonLAWidth(a.scalar_type));
    right = calloc((size_t)n * columns, CharonLAWidth(a.scalar_type));
    pivots = calloc(n, sizeof(__CLPK_integer));
    if (!factor || !right || !pivots) {
        free(factor);
        free(right);
        free(pivots);
        return CharonLAWithStatus(LA_INTERNAL_ERROR, attributes);
    }
    singular = a.scalar_type == LA_SCALAR_TYPE_FLOAT
                   ? CharonLALapackFloat(system, rhs, vector_rhs, to, n, columns, (float *)factor, (float *)right, pivots)
                   : CharonLALapackDouble(system, rhs, vector_rhs, to, n, columns, (double *)factor, (double *)right,
                                          pivots);
    if (singular) {
        to->status = LA_SINGULAR_ERROR;
    }
    free(factor);
    free(right);
    free(pivots);
    return result;
}
