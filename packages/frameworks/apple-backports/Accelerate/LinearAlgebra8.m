#import "RevenantLinearAlgebra.h"
#include <math.h>
#include <objc/message.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wunguarded-availability"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static la_object_t RevenantLAWithStatus(la_status_t status, la_attribute_t attributes)
{
    RevenantLAValue *value;
    la_object_t object = RevenantLANewObject();
    if (!object) {
        return object;
    }
    value = REVENANT_LA_VALUE(object);
    memset(value, 0, sizeof(*value));
    value->kind = RevenantLAError;
    value->status = status;
    value->attributes = attributes;
    return object;
}

static la_status_t RevenantLAStatusOf(la_object_t object)
{
    const RevenantLAValue *value = REVENANT_LA_VALUE(object);
    return value ? value->status : LA_INVALID_PARAMETER_ERROR;
}

static la_object_t RevenantLANewArray(la_count_t rows, la_count_t cols, la_scalar_type_t scalar_type,
                                    la_attribute_t attributes, la_status_t inherited)
{
    RevenantLAValue *value;
    la_object_t object = RevenantLANewObject();
    if (!object) {
        return object;
    }
    value = REVENANT_LA_VALUE(object);
    memset(value, 0, sizeof(*value));
    value->kind = RevenantLAArray;
    value->status = inherited;
    value->attributes = attributes;
    value->scalar_type = scalar_type;
    value->rows = rows;
    value->cols = cols;
    if (rows != 0 && cols != 0) {
        if (cols > (la_count_t)-1 / rows) {
            value->kind = RevenantLAError;
            value->status = LA_INTERNAL_ERROR;
            return object;
        }
        value->elements = calloc((size_t)rows * cols, RevenantLAWidth(scalar_type));
        if (!value->elements) {
            value->kind = RevenantLAError;
            value->status = LA_INTERNAL_ERROR;
        }
    }
    return object;
}

static la_object_t RevenantLANewSplat(la_scalar_type_t scalar_type, double element, la_attribute_t attributes)
{
    RevenantLAValue *value;
    la_object_t object = RevenantLANewObject();
    if (!object) {
        return object;
    }
    value = REVENANT_LA_VALUE(object);
    memset(value, 0, sizeof(*value));
    value->kind = RevenantLASplat;
    value->scalar_type = scalar_type;
    value->splat = element;
    value->attributes = attributes;
    return object;
}

#if OS_OBJECT_USE_OBJC

@implementation RevenantLAObject

- (void)dealloc
{
    RevenantLAFreeValue(&self->value);
#if !__has_feature(objc_arc)
    [super dealloc];
#endif
}

@end

#undef la_retain
#undef la_release

static SEL RevenantLASelectorNamed(const char *name) { return sel_registerName(name); }

la_object_t la_retain(la_object_t object)
{
    id kept = ((id (*)(id, SEL))objc_msgSend)((id)object, RevenantLASelectorNamed("retain"));
    return kept;
}

void la_release(la_object_t object)
{
    ((void (*)(id, SEL))objc_msgSend)((id)object, RevenantLASelectorNamed("release"));
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
        RevenantLAFreeValue(&object->value);
        free(object);
    }
}

#endif

la_status_t la_status(la_object_t object)
{
    return RevenantLAStatusOf(object);
}

void la_add_attributes(la_object_t object, la_attribute_t attributes)
{
    RevenantLAValue *value = REVENANT_LA_VALUE(object);
    if (value) {
        value->attributes |= attributes;
    }
}

void la_remove_attributes(la_object_t object, la_attribute_t attributes)
{
    RevenantLAValue *value = REVENANT_LA_VALUE(object);
    if (value) {
        value->attributes &= ~attributes;
    }
}

la_count_t la_matrix_rows(la_object_t matrix)
{
    const RevenantLAValue *value = REVENANT_LA_VALUE(matrix);
    return value && value->kind == RevenantLAArray ? value->rows : 0;
}

la_count_t la_matrix_cols(la_object_t matrix)
{
    const RevenantLAValue *value = REVENANT_LA_VALUE(matrix);
    return value && value->kind == RevenantLAArray ? value->cols : 0;
}

la_count_t la_vector_length(la_object_t vector)
{
    const RevenantLAValue *value = REVENANT_LA_VALUE(vector);
    return value ? RevenantLALength(value) : 0;
}

static la_object_t RevenantLAFromBuffer(const void *buffer, la_scalar_type_t scalar_type, la_count_t rows,
                                      la_count_t cols, la_count_t row_stride, la_hint_t hint, la_attribute_t attributes)
{
    la_object_t result;
    RevenantLAValue *value;
    if (!buffer || rows == 0 || cols == 0 || row_stride < cols) {
        return RevenantLAWithStatus(LA_INVALID_PARAMETER_ERROR, attributes);
    }
    result = RevenantLANewArray(rows, cols, scalar_type, attributes, LA_SUCCESS);
    value = REVENANT_LA_VALUE(result);
    if (value->kind != RevenantLAArray) {
        return result;
    }
    value->hint = hint;
    for (la_count_t row = 0; row < rows; row++) {
        for (la_count_t col = 0; col < cols; col++) {
            la_count_t at = row * row_stride + col;
            RevenantLASet(value, row, col, scalar_type == LA_SCALAR_TYPE_FLOAT ? ((const float *)buffer)[at]
                                                                            : ((const double *)buffer)[at]);
        }
    }
    return result;
}

la_object_t la_matrix_from_float_buffer(const float *buffer, la_count_t matrix_rows, la_count_t matrix_cols,
                                        la_count_t matrix_row_stride, la_hint_t matrix_hint, la_attribute_t attributes)
{
    return RevenantLAFromBuffer(buffer, LA_SCALAR_TYPE_FLOAT, matrix_rows, matrix_cols, matrix_row_stride, matrix_hint, attributes);
}

la_object_t la_matrix_from_double_buffer(const double *buffer, la_count_t matrix_rows, la_count_t matrix_cols,
                                          la_count_t matrix_row_stride, la_hint_t matrix_hint, la_attribute_t attributes)
{
    return RevenantLAFromBuffer(buffer, LA_SCALAR_TYPE_DOUBLE, matrix_rows, matrix_cols, matrix_row_stride, matrix_hint, attributes);
}

static la_object_t RevenantLAFromBufferNoCopy(void *buffer, la_scalar_type_t scalar_type, la_count_t rows,
                                            la_count_t cols, la_count_t row_stride, la_hint_t hint,
                                            la_deallocator_t deallocator, la_attribute_t attributes)
{
    la_object_t result = RevenantLAFromBuffer(buffer, scalar_type, rows, cols, row_stride, hint, attributes);
    RevenantLAValue *value = REVENANT_LA_VALUE(result);
    if (value->kind != RevenantLAArray) {
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
    RevenantLAFreeValue(value);
    value->elements = buffer;
    value->deallocator = deallocator;
    return result;
}

la_object_t la_matrix_from_float_buffer_nocopy(float *buffer, la_count_t matrix_rows, la_count_t matrix_cols,
                                               la_count_t matrix_row_stride, la_hint_t matrix_hint,
                                               la_deallocator_t deallocator, la_attribute_t attributes)
{
    return RevenantLAFromBufferNoCopy(buffer, LA_SCALAR_TYPE_FLOAT, matrix_rows, matrix_cols, matrix_row_stride,
                                    matrix_hint, deallocator, attributes);
}

la_object_t la_matrix_from_double_buffer_nocopy(double *buffer, la_count_t matrix_rows, la_count_t matrix_cols,
                                                 la_count_t matrix_row_stride, la_hint_t matrix_hint,
                                                 la_deallocator_t deallocator, la_attribute_t attributes)
{
    return RevenantLAFromBufferNoCopy(buffer, LA_SCALAR_TYPE_DOUBLE, matrix_rows, matrix_cols, matrix_row_stride,
                                    matrix_hint, deallocator, attributes);
}

static la_status_t RevenantLAStoreRefused(const RevenantLAValue *value, la_scalar_type_t scalar_type)
{
    if (!value || value->kind != RevenantLAArray) {
        if (value && value->kind == RevenantLASplat && value->scalar_type == scalar_type) {
            return LA_INVALID_PARAMETER_ERROR;
        }
        return LA_PRECISION_MISMATCH_ERROR;
    }
    return value->scalar_type == scalar_type ? LA_SUCCESS : LA_PRECISION_MISMATCH_ERROR;
}

static la_status_t RevenantLAStore(la_scalar_type_t scalar_type, la_count_t stride, la_object_t object, void *buffer)
{
    const RevenantLAValue *value = REVENANT_LA_VALUE(object);
    la_count_t count, width;
    if (!buffer) {
        return LA_PRECISION_MISMATCH_ERROR;
    }
    count = value->rows * value->cols;
    width = value->cols;
    for (la_count_t at = 0; at < count; at++) {
        la_count_t row = at / width, col = at % width, destination = (at / width) * stride + (at % width);
        double element = RevenantLAGet(value, row, col);
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
    const RevenantLAValue *value = REVENANT_LA_VALUE(vector);
    la_status_t refused = RevenantLAStoreRefused(value, LA_SCALAR_TYPE_FLOAT);
    if (refused != LA_SUCCESS) {
        return refused;
    }
    if (value->rows != 1 && value->cols != 1) {
        return LA_INVALID_PARAMETER_ERROR;
    }
    return RevenantLAStore(LA_SCALAR_TYPE_FLOAT, (la_count_t)buffer_stride, vector, buffer);
}

la_status_t la_vector_to_double_buffer(double *buffer, la_index_t buffer_stride, la_object_t vector)
{
    const RevenantLAValue *value = REVENANT_LA_VALUE(vector);
    la_status_t refused = RevenantLAStoreRefused(value, LA_SCALAR_TYPE_DOUBLE);
    if (refused != LA_SUCCESS) {
        return refused;
    }
    if (value->rows != 1 && value->cols != 1) {
        return LA_INVALID_PARAMETER_ERROR;
    }
    return RevenantLAStore(LA_SCALAR_TYPE_DOUBLE, (la_count_t)buffer_stride, vector, buffer);
}

la_status_t la_matrix_to_float_buffer(float *buffer, la_count_t buffer_row_stride, la_object_t matrix)
{
    la_status_t refused = RevenantLAStoreRefused(REVENANT_LA_VALUE(matrix), LA_SCALAR_TYPE_FLOAT);
    if (refused != LA_SUCCESS) {
        return refused;
    }
    return RevenantLAStore(LA_SCALAR_TYPE_FLOAT, buffer_row_stride, matrix, buffer);
}

la_status_t la_matrix_to_double_buffer(double *buffer, la_count_t buffer_row_stride, la_object_t matrix)
{
    la_status_t refused = RevenantLAStoreRefused(REVENANT_LA_VALUE(matrix), LA_SCALAR_TYPE_DOUBLE);
    if (refused != LA_SUCCESS) {
        return refused;
    }
    return RevenantLAStore(LA_SCALAR_TYPE_DOUBLE, buffer_row_stride, matrix, buffer);
}

static int RevenantLAInRange(la_index_t first, la_index_t stride, la_count_t count, la_count_t limit)
{
    la_index_t last = first + (la_index_t)(count - 1) * stride;
    la_index_t low = first < last ? first : last;
    la_index_t high = first < last ? last : first;
    return low >= 0 && high < (la_index_t)limit;
}

la_object_t la_vector_slice(la_object_t vector, la_index_t vector_first, la_index_t vector_stride, la_count_t slice_length)
{
    const RevenantLAValue *value = REVENANT_LA_VALUE(vector);
    la_count_t length;
    int across;
    la_object_t result;
    RevenantLAValue *to;
    if (!value || value->kind != RevenantLAArray || (value->rows != 1 && value->cols != 1)) {
        return RevenantLAWithStatus(LA_INVALID_PARAMETER_ERROR, 0);
    }
    length = RevenantLALength(value);
    if (slice_length == 0 || !RevenantLAInRange(vector_first, vector_stride, slice_length, length)) {
        return RevenantLAWithStatus(LA_SLICE_OUT_OF_BOUNDS_ERROR, value->attributes);
    }
    across = value->rows == 1;
    result = RevenantLANewArray(across ? 1 : slice_length, across ? slice_length : 1, value->scalar_type,
                              value->attributes, value->status);
    to = REVENANT_LA_VALUE(result);
    if (to->kind != RevenantLAArray) {
        return result;
    }
    for (la_count_t at = 0; at < slice_length; at++) {
        la_index_t source = vector_first + (la_index_t)at * vector_stride;
        double element = across ? RevenantLAGet(value, 0, (la_count_t)source) : RevenantLAGet(value, (la_count_t)source, 0);
        if (across) {
            RevenantLASet(to, 0, at, element);
        } else {
            RevenantLASet(to, at, 0, element);
        }
    }
    return result;
}

la_object_t la_matrix_slice(la_object_t matrix, la_index_t matrix_first_row, la_index_t matrix_first_col,
                            la_index_t matrix_row_stride, la_index_t matrix_col_stride,
                            la_count_t slice_rows, la_count_t slice_cols)
{
    const RevenantLAValue *value = REVENANT_LA_VALUE(matrix);
    la_object_t result;
    RevenantLAValue *to;
    if (!value || value->kind != RevenantLAArray) {
        return RevenantLAWithStatus(LA_INVALID_PARAMETER_ERROR, 0);
    }
    if (slice_rows == 0 || slice_cols == 0 ||
        !RevenantLAInRange(matrix_first_row, matrix_row_stride, slice_rows, value->rows) ||
        !RevenantLAInRange(matrix_first_col, matrix_col_stride, slice_cols, value->cols)) {
        return RevenantLAWithStatus(LA_SLICE_OUT_OF_BOUNDS_ERROR, value->attributes);
    }
    result = RevenantLANewArray(slice_rows, slice_cols, value->scalar_type, value->attributes, value->status);
    to = REVENANT_LA_VALUE(result);
    if (to->kind != RevenantLAArray) {
        return result;
    }
    for (la_count_t row = 0; row < slice_rows; row++) {
        for (la_count_t col = 0; col < slice_cols; col++) {
            RevenantLASet(to, row, col,
                        RevenantLAGet(value, (la_count_t)(matrix_first_row + (la_index_t)row * matrix_row_stride),
                                    (la_count_t)(matrix_first_col + (la_index_t)col * matrix_col_stride)));
        }
    }
    return result;
}

la_object_t la_identity_matrix(la_count_t matrix_size, la_scalar_type_t scalar_type, la_attribute_t attributes)
{
    la_object_t result;
    RevenantLAValue *value;
    if (scalar_type != LA_SCALAR_TYPE_FLOAT && scalar_type != LA_SCALAR_TYPE_DOUBLE) {
        return RevenantLAWithStatus(LA_INVALID_PARAMETER_ERROR, attributes);
    }
    result = RevenantLANewArray(matrix_size, matrix_size, scalar_type, attributes, LA_SUCCESS);
    value = REVENANT_LA_VALUE(result);
    if (value->kind != RevenantLAArray) {
        return result;
    }
    value->hint = LA_SHAPE_DIAGONAL;
    for (la_count_t at = 0; at < matrix_size; at++) {
        RevenantLASet(value, at, at, 1.0);
    }
    return result;
}

la_object_t la_splat_from_float(float scalar_value, la_attribute_t attributes)
{
    return RevenantLANewSplat(LA_SCALAR_TYPE_FLOAT, scalar_value, attributes);
}

la_object_t la_splat_from_double(double scalar_value, la_attribute_t attributes)
{
    return RevenantLANewSplat(LA_SCALAR_TYPE_DOUBLE, scalar_value, attributes);
}

la_object_t la_splat_from_vector_element(la_object_t vector, la_index_t vector_index)
{
    const RevenantLAValue *value = REVENANT_LA_VALUE(vector);
    la_count_t length;
    if (!value || value->kind != RevenantLAArray) {
        return RevenantLAWithStatus(LA_INVALID_PARAMETER_ERROR, 0);
    }
    length = RevenantLALength(value);
    if (vector_index < 0 || (la_count_t)vector_index >= length) {
        return RevenantLAWithStatus(LA_DIMENSION_MISMATCH_ERROR, value->attributes);
    }
    return RevenantLANewSplat(value->scalar_type,
                            value->rows == 1 ? RevenantLAGet(value, 0, (la_count_t)vector_index)
                                             : RevenantLAGet(value, (la_count_t)vector_index, 0),
                            value->attributes);
}

la_object_t la_splat_from_matrix_element(la_object_t matrix, la_index_t matrix_row, la_index_t matrix_col)
{
    const RevenantLAValue *value = REVENANT_LA_VALUE(matrix);
    if (!value || value->kind != RevenantLAArray) {
        return RevenantLAWithStatus(LA_INVALID_PARAMETER_ERROR, 0);
    }
    if (matrix_row < 0 || matrix_col < 0 || (la_count_t)matrix_row >= value->rows || (la_count_t)matrix_col >= value->cols) {
        return RevenantLAWithStatus(LA_DIMENSION_MISMATCH_ERROR, value->attributes);
    }
    return RevenantLANewSplat(value->scalar_type, RevenantLAGet(value, (la_count_t)matrix_row, (la_count_t)matrix_col),
                            value->attributes);
}

la_object_t la_vector_from_splat(la_object_t splat, la_count_t vector_length)
{
    const RevenantLAValue *value = REVENANT_LA_VALUE(splat);
    la_object_t result;
    RevenantLAValue *to;
    if (!value || value->kind != RevenantLASplat) {
        return RevenantLAWithStatus(LA_INVALID_PARAMETER_ERROR, 0);
    }
    result = RevenantLANewArray(vector_length, 1, value->scalar_type, value->attributes, LA_SUCCESS);
    to = REVENANT_LA_VALUE(result);
    if (to->kind != RevenantLAArray) {
        return result;
    }
    for (la_count_t at = 0; at < vector_length; at++) {
        RevenantLASet(to, at, 0, value->splat);
    }
    return result;
}

la_object_t la_matrix_from_splat(la_object_t splat, la_count_t matrix_rows, la_count_t matrix_cols)
{
    const RevenantLAValue *value = REVENANT_LA_VALUE(splat);
    la_object_t result;
    RevenantLAValue *to;
    if (!value || value->kind != RevenantLASplat) {
        return RevenantLAWithStatus(LA_INVALID_PARAMETER_ERROR, 0);
    }
    result = RevenantLANewArray(matrix_rows, matrix_cols, value->scalar_type, value->attributes, LA_SUCCESS);
    to = REVENANT_LA_VALUE(result);
    if (to->kind != RevenantLAArray) {
        return result;
    }
    for (la_count_t row = 0; row < matrix_rows; row++) {
        for (la_count_t col = 0; col < matrix_cols; col++) {
            RevenantLASet(to, row, col, value->splat);
        }
    }
    return result;
}

la_object_t la_vector_from_matrix_row(la_object_t matrix, la_count_t matrix_row)
{
    const RevenantLAValue *value = REVENANT_LA_VALUE(matrix);
    la_object_t result;
    RevenantLAValue *to;
    if (!value || value->kind != RevenantLAArray) {
        return RevenantLAWithStatus(LA_INVALID_PARAMETER_ERROR, 0);
    }
    if (matrix_row >= value->rows) {
        return RevenantLAWithStatus(LA_INVALID_PARAMETER_ERROR, value->attributes);
    }
    result = RevenantLANewArray(1, value->cols, value->scalar_type, value->attributes, value->status);
    to = REVENANT_LA_VALUE(result);
    if (to->kind != RevenantLAArray) {
        return result;
    }
    for (la_count_t col = 0; col < value->cols; col++) {
        RevenantLASet(to, 0, col, RevenantLAGet(value, matrix_row, col));
    }
    return result;
}

la_object_t la_vector_from_matrix_col(la_object_t matrix, la_count_t matrix_col)
{
    const RevenantLAValue *value = REVENANT_LA_VALUE(matrix);
    la_object_t result;
    RevenantLAValue *to;
    if (!value || value->kind != RevenantLAArray) {
        return RevenantLAWithStatus(LA_INVALID_PARAMETER_ERROR, 0);
    }
    if (matrix_col >= value->cols) {
        return RevenantLAWithStatus(LA_INVALID_PARAMETER_ERROR, value->attributes);
    }
    result = RevenantLANewArray(value->rows, 1, value->scalar_type, value->attributes, value->status);
    to = REVENANT_LA_VALUE(result);
    if (to->kind != RevenantLAArray) {
        return result;
    }
    for (la_count_t row = 0; row < value->rows; row++) {
        RevenantLASet(to, row, 0, RevenantLAGet(value, row, matrix_col));
    }
    return result;
}

la_object_t la_vector_from_matrix_diagonal(la_object_t matrix, la_index_t matrix_diagonal)
{
    const RevenantLAValue *value = REVENANT_LA_VALUE(matrix);
    la_index_t offset = matrix_diagonal < 0 ? -matrix_diagonal : matrix_diagonal;
    la_count_t length;
    la_object_t result;
    RevenantLAValue *to;
    if (!value || value->kind != RevenantLAArray) {
        return RevenantLAWithStatus(LA_INVALID_PARAMETER_ERROR, 0);
    }
    if (matrix_diagonal >= (la_index_t)value->cols || offset >= (la_index_t)value->rows) {
        return RevenantLAWithStatus(LA_INVALID_PARAMETER_ERROR, value->attributes);
    }
    length = value->rows < value->cols - offset ? value->rows : value->cols - offset;
    result = RevenantLANewArray(length, 1, value->scalar_type, value->attributes, value->status);
    to = REVENANT_LA_VALUE(result);
    if (to->kind != RevenantLAArray) {
        return result;
    }
    for (la_count_t at = 0; at < length; at++) {
        RevenantLASet(to, at, 0, matrix_diagonal >= 0 ? RevenantLAGet(value, at, at + offset)
                                                    : RevenantLAGet(value, at + offset, at));
    }
    return result;
}

la_object_t la_diagonal_matrix_from_vector(la_object_t vector, la_index_t matrix_diagonal)
{
    const RevenantLAValue *value = REVENANT_LA_VALUE(vector);
    la_count_t length, size, offset = matrix_diagonal < 0 ? (la_count_t)-matrix_diagonal : (la_count_t)matrix_diagonal;
    la_object_t result;
    RevenantLAValue *to;
    if (!value || value->kind != RevenantLAArray || (value->rows != 1 && value->cols != 1)) {
        return RevenantLAWithStatus(LA_INVALID_PARAMETER_ERROR, 0);
    }
    length = RevenantLALength(value);
    size = length + offset;
    result = RevenantLANewArray(size, size, value->scalar_type, value->attributes, value->status);
    to = REVENANT_LA_VALUE(result);
    if (to->kind != RevenantLAArray) {
        return result;
    }
    to->hint = LA_SHAPE_DIAGONAL;
    for (la_count_t at = 0; at < length; at++) {
        la_count_t row = matrix_diagonal >= 0 ? at : at + offset;
        la_count_t col = matrix_diagonal >= 0 ? at + offset : at;
        RevenantLASet(to, row, col, value->rows == 1 ? RevenantLAGet(value, 0, at) : RevenantLAGet(value, at, 0));
    }
    return result;
}

la_object_t la_transpose(la_object_t matrix)
{
    const RevenantLAValue *value = REVENANT_LA_VALUE(matrix);
    la_object_t result;
    RevenantLAValue *to;
    if (!value || value->kind != RevenantLAArray) {
        return RevenantLAWithStatus(LA_INVALID_PARAMETER_ERROR, 0);
    }
    result = RevenantLANewArray(value->cols, value->rows, value->scalar_type, value->attributes, value->status);
    to = REVENANT_LA_VALUE(result);
    if (to->kind != RevenantLAArray) {
        return result;
    }
    for (la_count_t row = 0; row < value->rows; row++) {
        for (la_count_t col = 0; col < value->cols; col++) {
            RevenantLASet(to, col, row, RevenantLAGet(value, row, col));
        }
    }
    return result;
}

static la_object_t RevenantLAScale(la_object_t object, double scalar, la_scalar_type_t scalar_type)
{
    const RevenantLAValue *value = REVENANT_LA_VALUE(object);
    la_object_t result;
    RevenantLAValue *to;
    if (!value || value->kind != RevenantLAArray) {
        return RevenantLAWithStatus(LA_INVALID_PARAMETER_ERROR, 0);
    }
    if (value->scalar_type != scalar_type) {
        return RevenantLAWithStatus(LA_PRECISION_MISMATCH_ERROR, value->attributes);
    }
    result = RevenantLANewArray(value->rows, value->cols, value->scalar_type, value->attributes, value->status);
    to = REVENANT_LA_VALUE(result);
    if (to->kind != RevenantLAArray) {
        return result;
    }
    for (la_count_t row = 0; row < value->rows; row++) {
        for (la_count_t col = 0; col < value->cols; col++) {
            double element = RevenantLAGet(value, row, col);
            RevenantLASet(to, row, col, scalar_type == LA_SCALAR_TYPE_FLOAT ? (float)(element * (float)scalar)
                                                                         : element * scalar);
        }
    }
    return result;
}

la_object_t la_scale_with_float(la_object_t matrix, float scalar)
{
    return RevenantLAScale(matrix, scalar, LA_SCALAR_TYPE_FLOAT);
}

la_object_t la_scale_with_double(la_object_t matrix, double scalar)
{
    return RevenantLAScale(matrix, scalar, LA_SCALAR_TYPE_DOUBLE);
}

typedef struct RevenantLAOperand {
    la_status_t status;
    la_attribute_t attributes;
    la_scalar_type_t scalar_type;
    la_count_t rows;
    la_count_t cols;
    la_count_t length;
    int is_splat;
    int is_vector;
} RevenantLAOperand;

static void RevenantLAOperandOf(la_object_t object, RevenantLAOperand *operand)
{
    const RevenantLAValue *value = REVENANT_LA_VALUE(object);
    memset(operand, 0, sizeof(*operand));
    if (!value) {
        operand->status = LA_INVALID_PARAMETER_ERROR;
        return;
    }
    operand->status = value->status;
    operand->attributes = value->attributes;
    operand->scalar_type = value->scalar_type;
    operand->is_splat = value->kind == RevenantLASplat;
    if (value->kind == RevenantLAArray) {
        operand->rows = value->rows;
        operand->cols = value->cols;
        operand->length = RevenantLALength(value);
        operand->is_vector = value->rows == 1 || value->cols == 1;
    }
}

static la_status_t RevenantLATypes(la_object_t left, la_object_t right, RevenantLAOperand *a, RevenantLAOperand *b,
                                 la_attribute_t *attributes)
{
    RevenantLAOperandOf(left, a);
    RevenantLAOperandOf(right, b);
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

static la_status_t RevenantLAPair(la_object_t left, la_object_t right, RevenantLAOperand *a, RevenantLAOperand *b,
                                 la_attribute_t *attributes)
{
    la_status_t refused = RevenantLATypes(left, right, a, b, attributes);
    if (refused != LA_SUCCESS) {
        return refused;
    }
    if (!a->is_splat && !b->is_splat && (a->rows != b->rows || a->cols != b->cols)) {
        return LA_DIMENSION_MISMATCH_ERROR;
    }
    return LA_SUCCESS;
}

static double RevenantLAOperandElement(la_object_t object, const RevenantLAOperand *operand, la_count_t row, la_count_t col)
{
    if (operand->is_splat) {
        return REVENANT_LA_VALUE(object)->splat;
    }
    return RevenantLAGet(REVENANT_LA_VALUE(object), operand->rows == 1 ? 0 : row, operand->cols == 1 ? 0 : col);
}

static double RevenantLAOperandAt(la_object_t object, const RevenantLAOperand *operand, la_count_t at)
{
    if (operand->is_splat) {
        return REVENANT_LA_VALUE(object)->splat;
    }
    return operand->rows == 1 ? RevenantLAGet(REVENANT_LA_VALUE(object), 0, at) : RevenantLAGet(REVENANT_LA_VALUE(object), at, 0);
}

typedef enum { RevenantLAAdd, RevenantLASubtract, RevenantLAMultiply } RevenantLAElementwise;

static la_object_t RevenantLAElementwiseOp(RevenantLAElementwise which, la_object_t left, la_object_t right)
{
    RevenantLAOperand a, b;
    la_attribute_t attributes;
    la_status_t refused = RevenantLAPair(left, right, &a, &b, &attributes);
    la_count_t rows, cols;
    la_object_t result;
    RevenantLAValue *to;
    if (refused != LA_SUCCESS) {
        return RevenantLAWithStatus(refused, attributes);
    }
    rows = a.is_splat ? b.rows : a.rows;
    cols = a.is_splat ? b.cols : a.cols;
    result = RevenantLANewArray(rows, cols, a.scalar_type, attributes, LA_SUCCESS);
    to = REVENANT_LA_VALUE(result);
    if (to->kind != RevenantLAArray) {
        return result;
    }
    for (la_count_t row = 0; row < rows; row++) {
        for (la_count_t col = 0; col < cols; col++) {
            double x = RevenantLAOperandElement(left, &a, row, col);
            double y = RevenantLAOperandElement(right, &b, row, col);
            if (a.scalar_type == LA_SCALAR_TYPE_FLOAT) {
                x = (float)x;
                y = (float)y;
            }
            RevenantLASet(to, row, col, which == RevenantLAAdd ? x + y : which == RevenantLASubtract ? x - y : x * y);
        }
    }
    return result;
}

la_object_t la_sum(la_object_t obj_left, la_object_t obj_right)
{
    return RevenantLAElementwiseOp(RevenantLAAdd, obj_left, obj_right);
}

la_object_t la_difference(la_object_t obj_left, la_object_t obj_right)
{
    return RevenantLAElementwiseOp(RevenantLASubtract, obj_left, obj_right);
}

la_object_t la_elementwise_product(la_object_t obj_left, la_object_t obj_right)
{
    return RevenantLAElementwiseOp(RevenantLAMultiply, obj_left, obj_right);
}

#define REVENANT_LA_BY_SHAPE 0
#define REVENANT_LA_BY_INNER 1
#define REVENANT_LA_BY_COLUMN 2

static la_object_t RevenantLAGemm(la_object_t left, la_object_t right, la_count_t rows, la_count_t inner, la_count_t cols,
                                int left_flat, int right_flat)
{
    RevenantLAOperand a, b;
    la_attribute_t attributes;
    la_status_t refused = RevenantLATypes(left, right, &a, &b, &attributes);
    float *af = NULL, *bf = NULL;
    double *ad = NULL, *bd = NULL;
    la_object_t result;
    RevenantLAValue *to;
    if (refused != LA_SUCCESS) {
        return RevenantLAWithStatus(refused, attributes);
    }
    result = RevenantLANewArray(rows, cols, a.scalar_type, attributes, LA_SUCCESS);
    to = REVENANT_LA_VALUE(result);
    if (to->kind != RevenantLAArray) {
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
        return RevenantLAWithStatus(LA_INTERNAL_ERROR, attributes);
    }
    for (la_count_t row = 0; row < rows; row++) {
        for (la_count_t at = 0; at < inner; at++) {
            double element = left_flat ? RevenantLAOperandAt(left, &a, at) : RevenantLAOperandElement(left, &a, row, at);
            if (af) {
                af[row * inner + at] = (float)element;
            } else {
                ad[row * inner + at] = element;
            }
        }
    }
    for (la_count_t at = 0; at < inner; at++) {
        for (la_count_t col = 0; col < cols; col++) {
            double element = right_flat == REVENANT_LA_BY_INNER   ? RevenantLAOperandAt(right, &b, at)
                             : right_flat == REVENANT_LA_BY_COLUMN ? RevenantLAOperandAt(right, &b, col)
                                                                 : RevenantLAOperandElement(right, &b, at, col);
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
    RevenantLAOperand a, b;
    RevenantLAOperandOf(matrix_left, &a);
    RevenantLAOperandOf(matrix_right, &b);
    if (a.is_splat) {
        return RevenantLAGemm(matrix_left, matrix_right, 1, b.rows, b.is_splat ? 1 : b.cols, 0, 0);
    }
    if (b.is_splat) {
        return RevenantLAGemm(matrix_left, matrix_right, a.rows, a.cols, 1, 0, 0);
    }
    if (a.cols != b.rows) {
        return RevenantLAWithStatus(LA_DIMENSION_MISMATCH_ERROR, a.attributes | b.attributes);
    }
    return RevenantLAGemm(matrix_left, matrix_right, a.rows, a.cols, b.cols, 0, 0);
}

la_object_t la_outer_product(la_object_t vector_left, la_object_t vector_right)
{
    RevenantLAOperand a, b;
    la_attribute_t attributes;
    la_status_t refused;
    la_object_t result;
    RevenantLAValue *to;
    RevenantLAOperandOf(vector_left, &a);
    RevenantLAOperandOf(vector_right, &b);
    refused = RevenantLATypes(vector_left, vector_right, &a, &b, &attributes);
    if (refused != LA_SUCCESS) {
        return RevenantLAWithStatus(refused, attributes);
    }
    if (a.is_splat || b.is_splat || !a.is_vector || !b.is_vector) {
        return RevenantLAWithStatus(LA_INVALID_PARAMETER_ERROR, attributes);
    }
    result = RevenantLANewArray(a.length, b.length, a.scalar_type, attributes, LA_SUCCESS);
    to = REVENANT_LA_VALUE(result);
    if (to->kind != RevenantLAArray) {
        return result;
    }
    for (la_count_t row = 0; row < a.length; row++) {
        double x = RevenantLAOperandAt(vector_left, &a, row);
        for (la_count_t col = 0; col < b.length; col++) {
            double y = RevenantLAOperandAt(vector_right, &b, col);
            RevenantLASet(to, row, col, a.scalar_type == LA_SCALAR_TYPE_FLOAT ? (float)x * (float)y : x * y);
        }
    }
    return result;
}

la_object_t la_inner_product(la_object_t vector_left, la_object_t vector_right)
{
    RevenantLAOperand a, b;
    la_attribute_t attributes;
    la_status_t refused = RevenantLAPair(vector_left, vector_right, &a, &b, &attributes);
    if (refused != LA_SUCCESS) {
        return RevenantLAWithStatus(refused, attributes);
    }
    if ((!a.is_splat && !a.is_vector) || (!b.is_splat && !b.is_vector)) {
        return RevenantLAWithStatus(LA_DIMENSION_MISMATCH_ERROR, attributes);
    }
    if (!a.is_splat && !b.is_splat && a.length != b.length) {
        return RevenantLAWithStatus(LA_DIMENSION_MISMATCH_ERROR, attributes);
    }
    return RevenantLAGemm(vector_left, vector_right, 1, a.is_splat ? b.length : a.length, 1, 1, REVENANT_LA_BY_INNER);
}

static double RevenantLANorm(la_object_t object, la_norm_t norm, la_scalar_type_t scalar_type, int *valid)
{
    const RevenantLAValue *value = REVENANT_LA_VALUE(object);
    la_count_t count;
    double sum = 0.0, largest = 0.0;
    *valid = 0;
    if (!value || value->kind != RevenantLAArray || value->scalar_type != scalar_type) {
        return NAN;
    }
    if (norm != LA_L1_NORM && norm != LA_L2_NORM && norm != LA_LINF_NORM) {
        return NAN;
    }
    count = value->rows * value->cols;
    for (la_count_t at = 0; at < count; at++) {
        double element = RevenantLAGet(value, at / value->cols, at % value->cols);
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
    double norm = RevenantLANorm(vector, vector_norm, LA_SCALAR_TYPE_FLOAT, &valid);
    return valid ? (float)norm : NAN;
}

double la_norm_as_double(la_object_t vector, la_norm_t vector_norm)
{
    int valid;
    return RevenantLANorm(vector, vector_norm, LA_SCALAR_TYPE_DOUBLE, &valid);
}

la_object_t la_normalized_vector(la_object_t vector, la_norm_t vector_norm)
{
    const RevenantLAValue *value = REVENANT_LA_VALUE(vector);
    int valid;
    double norm;
    la_object_t result;
    RevenantLAValue *to;
    la_count_t count;
    if (!value || value->kind != RevenantLAArray) {
        return RevenantLAWithStatus(LA_INVALID_PARAMETER_ERROR, 0);
    }
    norm = RevenantLANorm(vector, vector_norm, value->scalar_type, &valid);
    if (!valid) {
        return RevenantLAWithStatus(LA_INVALID_PARAMETER_ERROR, value->attributes);
    }
    result = RevenantLANewArray(value->rows, value->cols, value->scalar_type, value->attributes, value->status);
    to = REVENANT_LA_VALUE(result);
    if (to->kind != RevenantLAArray) {
        return result;
    }
    if (norm == 0.0) {
        return result;
    }
    count = value->rows * value->cols;
    for (la_count_t at = 0; at < count; at++) {
        la_count_t row = at / value->cols, col = at % value->cols;
        double element = RevenantLAGet(value, row, col) / norm;
        RevenantLASet(to, row, col, value->scalar_type == LA_SCALAR_TYPE_FLOAT ? (float)element : element);
    }
    return result;
}

static int RevenantLALapackFloat(const RevenantLAValue *system, const RevenantLAValue *rhs, int vector_rhs,
                               RevenantLAValue *to, la_count_t n, la_count_t columns, float *factor, float *right,
                               __CLPK_integer *pivots)
{
    __CLPK_integer order = (__CLPK_integer)n, leading = (__CLPK_integer)n, count = (__CLPK_integer)columns,
                   info = 0;
    char trans = 'N';
    la_count_t row, col;
    for (col = 0; col < n; col++) {
        for (row = 0; row < n; row++) {
            factor[col * n + row] = (float)RevenantLAGet(system, row, col);
        }
    }
    for (col = 0; col < columns; col++) {
        for (row = 0; row < n; row++) {
            right[col * n + row] =
                (float)(vector_rhs ? (rhs->rows == 1 ? RevenantLAGet(rhs, 0, row) : RevenantLAGet(rhs, row, 0))
                                   : RevenantLAGet(rhs, row, col));
        }
    }
    sgetrf_(&order, &order, factor, &leading, pivots, &info);
    if (info > 0) {
        return 1;
    }
    sgetrs_(&trans, &order, &count, factor, &leading, pivots, right, &leading, &info);
    for (col = 0; col < columns; col++) {
        for (row = 0; row < n; row++) {
            RevenantLASet(to, row, col, right[col * n + row]);
        }
    }
    return 0;
}

static int RevenantLALapackDouble(const RevenantLAValue *system, const RevenantLAValue *rhs, int vector_rhs,
                                RevenantLAValue *to, la_count_t n, la_count_t columns, double *factor, double *right,
                                __CLPK_integer *pivots)
{
    __CLPK_integer order = (__CLPK_integer)n, leading = (__CLPK_integer)n, count = (__CLPK_integer)columns,
                   info = 0;
    char trans = 'N';
    la_count_t row, col;
    for (col = 0; col < n; col++) {
        for (row = 0; row < n; row++) {
            factor[col * n + row] = RevenantLAGet(system, row, col);
        }
    }
    for (col = 0; col < columns; col++) {
        for (row = 0; row < n; row++) {
            right[col * n + row] =
                vector_rhs ? (rhs->rows == 1 ? RevenantLAGet(rhs, 0, row) : RevenantLAGet(rhs, row, 0))
                           : RevenantLAGet(rhs, row, col);
        }
    }
    dgetrf_(&order, &order, factor, &leading, pivots, &info);
    if (info > 0) {
        return 1;
    }
    dgetrs_(&trans, &order, &count, factor, &leading, pivots, right, &leading, &info);
    for (col = 0; col < columns; col++) {
        for (row = 0; row < n; row++) {
            RevenantLASet(to, row, col, right[col * n + row]);
        }
    }
    return 0;
}

la_object_t la_solve(la_object_t matrix_system, la_object_t obj_rhs)
{
    RevenantLAOperand a, b;
    const RevenantLAValue *system = REVENANT_LA_VALUE(matrix_system);
    const RevenantLAValue *rhs = REVENANT_LA_VALUE(obj_rhs);
    la_attribute_t attributes;
    la_status_t refused;
    la_count_t n, columns;
    int vector_rhs, singular;
    la_object_t result;
    RevenantLAValue *to;
    void *factor = NULL, *right = NULL;
    __CLPK_integer *pivots = NULL;
    if (!system || !rhs) {
        return RevenantLAWithStatus(LA_INVALID_PARAMETER_ERROR, 0);
    }
    RevenantLAOperandOf(matrix_system, &a);
    RevenantLAOperandOf(obj_rhs, &b);
    attributes = a.attributes | b.attributes;
    refused = a.status != LA_SUCCESS ? a.status : LA_SUCCESS;
    if (refused != LA_SUCCESS) {
        return RevenantLAWithStatus(refused, attributes);
    }
    if (a.scalar_type != b.scalar_type) {
        return RevenantLAWithStatus(LA_PRECISION_MISMATCH_ERROR, attributes);
    }
    if (a.is_splat || b.is_splat) {
        return RevenantLAWithStatus(LA_INVALID_PARAMETER_ERROR, attributes);
    }
    if (!a.rows) {
        return RevenantLAWithStatus(LA_INVALID_PARAMETER_ERROR, attributes);
    }
    if (a.rows != a.cols) {
        return RevenantLAWithStatus(LA_DIMENSION_MISMATCH_ERROR, attributes);
    }
    n = a.rows;
    vector_rhs = b.is_vector;
    columns = vector_rhs ? 1 : b.cols;
    if ((vector_rhs ? b.length : b.rows) != n || !columns) {
        return RevenantLAWithStatus(LA_DIMENSION_MISMATCH_ERROR, attributes);
    }
    result = RevenantLANewArray(n, columns, a.scalar_type, attributes, LA_SUCCESS);
    to = REVENANT_LA_VALUE(result);
    if (to->kind != RevenantLAArray) {
        return result;
    }
    factor = calloc((size_t)n * n, RevenantLAWidth(a.scalar_type));
    right = calloc((size_t)n * columns, RevenantLAWidth(a.scalar_type));
    pivots = calloc(n, sizeof(__CLPK_integer));
    if (!factor || !right || !pivots) {
        free(factor);
        free(right);
        free(pivots);
        return RevenantLAWithStatus(LA_INTERNAL_ERROR, attributes);
    }
    singular = a.scalar_type == LA_SCALAR_TYPE_FLOAT
                   ? RevenantLALapackFloat(system, rhs, vector_rhs, to, n, columns, (float *)factor, (float *)right, pivots)
                   : RevenantLALapackDouble(system, rhs, vector_rhs, to, n, columns, (double *)factor, (double *)right,
                                          pivots);
    if (singular) {
        to->status = LA_SINGULAR_ERROR;
    }
    free(factor);
    free(right);
    free(pivots);
    return result;
}
