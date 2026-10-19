#import <Accelerate/Accelerate.h>
#include "RevenantSparseBLAS.h"


typedef struct sparse_m_float RevenantSparseFloatMatrix;
typedef struct sparse_m_double RevenantSparseDoubleMatrix;

sparse_matrix_float sparse_matrix_create_float(sparse_dimension M, sparse_dimension N)
{
    void *matrix = NULL;
    if (RevenantSparseMake(&matrix, REVENANT_SPARSE_MAGIC_FLOAT, sizeof(struct sparse_m_float), M, N, 0, 0, NULL, NULL) !=
        SPARSE_SUCCESS) {
        return NULL;
    }
    return (sparse_matrix_float)matrix;
}

sparse_matrix_double sparse_matrix_create_double(sparse_dimension M, sparse_dimension N)
{
    void *matrix = NULL;
    if (RevenantSparseMake(&matrix, REVENANT_SPARSE_MAGIC_DOUBLE, sizeof(struct sparse_m_double), M, N, 0, 0, NULL, NULL) !=
        SPARSE_SUCCESS) {
        return NULL;
    }
    return (sparse_matrix_double)matrix;
}

sparse_matrix_float sparse_matrix_block_create_float(sparse_dimension Mb, sparse_dimension Nb, sparse_dimension k,
                                                    sparse_dimension l)
{
    sparse_dimension *heights = RevenantSparseRepeated(k, (sparse_index)Mb);
    sparse_dimension *widths = RevenantSparseRepeated(l, (sparse_index)Nb);
    void *matrix = NULL;
    sparse_status made =
        RevenantSparseMake(&matrix, REVENANT_SPARSE_MAGIC_FLOAT, sizeof(struct sparse_m_float), 0, 0, (sparse_index)Mb,
                         (sparse_index)Nb, heights, widths);
    free(heights);
    free(widths);
    return made == SPARSE_SUCCESS ? (sparse_matrix_float)matrix : NULL;
}

sparse_matrix_double sparse_matrix_block_create_double(sparse_dimension Mb, sparse_dimension Nb, sparse_dimension k,
                                                      sparse_dimension l)
{
    sparse_dimension *heights = RevenantSparseRepeated(k, (sparse_index)Mb);
    sparse_dimension *widths = RevenantSparseRepeated(l, (sparse_index)Nb);
    void *matrix = NULL;
    sparse_status made =
        RevenantSparseMake(&matrix, REVENANT_SPARSE_MAGIC_DOUBLE, sizeof(struct sparse_m_double), 0, 0, (sparse_index)Mb,
                         (sparse_index)Nb, heights, widths);
    free(heights);
    free(widths);
    return made == SPARSE_SUCCESS ? (sparse_matrix_double)matrix : NULL;
}

sparse_matrix_float sparse_matrix_variable_block_create_float(sparse_dimension Mb, sparse_dimension Nb,
                                                             const sparse_dimension *K, const sparse_dimension *L)
{
    void *matrix = NULL;
    if (RevenantSparseMake(&matrix, REVENANT_SPARSE_MAGIC_FLOAT, sizeof(struct sparse_m_float), 0, 0, (sparse_index)Mb,
                         (sparse_index)Nb, K, L) != SPARSE_SUCCESS) {
        return NULL;
    }
    return (sparse_matrix_float)matrix;
}

sparse_matrix_double sparse_matrix_variable_block_create_double(sparse_dimension Mb, sparse_dimension Nb,
                                                               const sparse_dimension *K, const sparse_dimension *L)
{
    void *matrix = NULL;
    if (RevenantSparseMake(&matrix, REVENANT_SPARSE_MAGIC_DOUBLE, sizeof(struct sparse_m_double), 0, 0, (sparse_index)Mb,
                         (sparse_index)Nb, K, L) != SPARSE_SUCCESS) {
        return NULL;
    }
    return (sparse_matrix_double)matrix;
}

sparse_status sparse_insert_entry_float(sparse_matrix_float A, float val, sparse_index i, sparse_index j)
{
    return RevenantSparsePutEntry(A, REVENANT_SPARSE_MAGIC_FLOAT, val, i, j, sizeof(float));
}

sparse_status sparse_insert_entry_double(sparse_matrix_double A, double val, sparse_index i, sparse_index j)
{
    return RevenantSparsePutEntry(A, REVENANT_SPARSE_MAGIC_DOUBLE, val, i, j, sizeof(double));
}

sparse_status sparse_insert_entries_float(sparse_matrix_float A, sparse_dimension N, const float *__restrict val,
                                          const sparse_index *__restrict indx, const sparse_index *__restrict jndx)
{
    if (!RevenantSparseIsFloat(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    for (sparse_dimension k = 0; k < N; k++) {
        sparse_status put = RevenantSparsePutEntry(A, REVENANT_SPARSE_MAGIC_FLOAT, val[k], indx[k], jndx[k], sizeof(float));
        if (put != SPARSE_SUCCESS) {
            return put;
        }
    }
    return SPARSE_SUCCESS;
}

sparse_status sparse_insert_entries_double(sparse_matrix_double A, sparse_dimension N, const double *__restrict val,
                                           const sparse_index *__restrict indx, const sparse_index *__restrict jndx)
{
    if (!RevenantSparseIsDouble(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    for (sparse_dimension k = 0; k < N; k++) {
        sparse_status put = RevenantSparsePutEntry(A, REVENANT_SPARSE_MAGIC_DOUBLE, val[k], indx[k], jndx[k], sizeof(double));
        if (put != SPARSE_SUCCESS) {
            return put;
        }
    }
    return SPARSE_SUCCESS;
}

sparse_status sparse_insert_col_float(sparse_matrix_float A, sparse_index j, sparse_dimension nz,
                                      const float *__restrict val, const sparse_index *__restrict indx)
{
    if (!RevenantSparseIsFloat(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    for (sparse_dimension k = 0; k < nz; k++) {
        sparse_status put = RevenantSparsePutEntry(A, REVENANT_SPARSE_MAGIC_FLOAT, val[k], indx[k], j, sizeof(float));
        if (put != SPARSE_SUCCESS) {
            return put;
        }
    }
    return SPARSE_SUCCESS;
}

sparse_status sparse_insert_col_double(sparse_matrix_double A, sparse_index j, sparse_dimension nz,
                                       const double *__restrict val, const sparse_index *__restrict indx)
{
    if (!RevenantSparseIsDouble(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    for (sparse_dimension k = 0; k < nz; k++) {
        sparse_status put = RevenantSparsePutEntry(A, REVENANT_SPARSE_MAGIC_DOUBLE, val[k], indx[k], j, sizeof(double));
        if (put != SPARSE_SUCCESS) {
            return put;
        }
    }
    return SPARSE_SUCCESS;
}

sparse_status sparse_insert_row_float(sparse_matrix_float A, sparse_index i, sparse_dimension nz,
                                      const float *__restrict val, const sparse_index *__restrict jndx)
{
    if (!RevenantSparseIsFloat(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    for (sparse_dimension k = 0; k < nz; k++) {
        sparse_status put = RevenantSparsePutEntry(A, REVENANT_SPARSE_MAGIC_FLOAT, val[k], i, jndx[k], sizeof(float));
        if (put != SPARSE_SUCCESS) {
            return put;
        }
    }
    return SPARSE_SUCCESS;
}

sparse_status sparse_insert_row_double(sparse_matrix_double A, sparse_index i, sparse_dimension nz,
                                       const double *__restrict val, const sparse_index *__restrict jndx)
{
    if (!RevenantSparseIsDouble(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    for (sparse_dimension k = 0; k < nz; k++) {
        sparse_status put = RevenantSparsePutEntry(A, REVENANT_SPARSE_MAGIC_DOUBLE, val[k], i, jndx[k], sizeof(double));
        if (put != SPARSE_SUCCESS) {
            return put;
        }
    }
    return SPARSE_SUCCESS;
}

static sparse_status RevenantSparsePutBlock(void *matrix, uint32_t magic, const void *val, sparse_dimension rowStride,
                                          sparse_dimension colStride, sparse_index bi, sparse_index bj, size_t size)
{
    struct sparse_m_float *asFloat = NULL;
    sparse_status ready = RevenantSparseWritable(matrix, magic, 1, &asFloat);
    if (ready != SPARSE_SUCCESS) {
        return ready;
    }
    if (bi >= asFloat->blockRows || bj >= asFloat->blockColumns) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    sparse_dimension height = asFloat->blockHeight[bi], width = asFloat->blockWidth[bj];
    sparse_dimension first = 0;
    for (sparse_index b = 0; b < bi; b++) {
        first += asFloat->blockHeight[b];
    }
    sparse_dimension left = 0;
    for (sparse_index b = 0; b < bj; b++) {
        left += asFloat->blockWidth[b];
    }
    for (sparse_dimension i = 0; i < height; i++) {
        for (sparse_dimension j = 0; j < width; j++) {
            const char *from = (const char *)val + (size_t)(i * rowStride + j * colStride) * size;
            double value = size == sizeof(float) ? (double)*(const float *)from : *(const double *)from;
            sparse_index before = asFloat->row[first + i].count;
            sparse_status put = RevenantSparsePut(&asFloat->row[first + i], left + j, value, size);
            if (put != SPARSE_SUCCESS) {
                return put;
            }
            asFloat->nonzero += (long)asFloat->row[first + i].count - (long)before;
        }
    }
    asFloat->inserted = 1;
    return SPARSE_SUCCESS;
}

sparse_status sparse_insert_block_float(sparse_matrix_float A, const float *__restrict val, sparse_dimension row_stride,
                                        sparse_dimension col_stride, sparse_index bi, sparse_index bj)
{
    return RevenantSparsePutBlock(A, REVENANT_SPARSE_MAGIC_FLOAT, val, row_stride, col_stride, bi, bj, sizeof(float));
}

sparse_status sparse_insert_block_double(sparse_matrix_double A, const double *__restrict val,
                                         sparse_dimension row_stride, sparse_dimension col_stride, sparse_index bi,
                                         sparse_index bj)
{
    return RevenantSparsePutBlock(A, REVENANT_SPARSE_MAGIC_DOUBLE, val, row_stride, col_stride, bi, bj, sizeof(double));
}

static long RevenantSparseExtractRow(void *matrix, uint32_t magic, sparse_index row, sparse_index columnStart,
                                   sparse_index *columnEnd, sparse_dimension nz, void *val, sparse_index *jndx,
                                   size_t size)
{
    if (!RevenantSparseIsMatrix(matrix, magic) || !columnEnd) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    struct sparse_m_float *asFloat = (struct sparse_m_float *)matrix;
    if (row < 0 || columnStart < 0 || row >= (sparse_index)asFloat->rows || columnStart >= (sparse_index)asFloat->columns ||
        asFloat->blockRows > 0) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    const RevenantSparseRow *source = &asFloat->row[row];
    sparse_index at = RevenantSparseSearch(source, columnStart);
    sparse_dimension written = 0;
    while (at < source->count && written < nz) {
        if (val) {
            if (size == sizeof(float)) {
                ((float *)val)[written] = ((const float *)source->value)[at];
            } else {
                ((double *)val)[written] = ((const double *)source->value)[at];
            }
        }
        if (jndx) {
            jndx[written] = source->column[at];
        }
        written++;
        at++;
    }
    *columnEnd = nz == 0 ? columnStart
                         : (at < source->count ? source->column[at] : (sparse_index)asFloat->columns);
    return (long)written;
}

sparse_status sparse_extract_sparse_row_float(sparse_matrix_float A, sparse_index row, sparse_index column_start,
                                              sparse_index *column_end, sparse_dimension nz, float *__restrict val,
                                              sparse_index *__restrict jndx)
{
    return (sparse_status)RevenantSparseExtractRow(A, REVENANT_SPARSE_MAGIC_FLOAT, row, column_start, column_end, nz, val,
                                                 jndx, sizeof(float));
}

sparse_status sparse_extract_sparse_row_double(sparse_matrix_double A, sparse_index row, sparse_index column_start,
                                               sparse_index *column_end, sparse_dimension nz, double *__restrict val,
                                               sparse_index *__restrict jndx)
{
    return (sparse_status)RevenantSparseExtractRow(A, REVENANT_SPARSE_MAGIC_DOUBLE, row, column_start, column_end, nz, val,
                                                 jndx, sizeof(double));
}

static long RevenantSparseExtractColumn(void *matrix, uint32_t magic, sparse_index column, sparse_index rowStart,
                                      sparse_index *rowEnd, sparse_dimension nz, void *val, sparse_index *jndx,
                                      size_t size)
{
    if (!RevenantSparseIsMatrix(matrix, magic) || !rowEnd) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    struct sparse_m_float *asFloat = (struct sparse_m_float *)matrix;
    if (column < 0 || rowStart < 0 || column >= (sparse_index)asFloat->columns || rowStart >= (sparse_index)asFloat->rows ||
        asFloat->blockRows > 0) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    sparse_dimension written = 0;
    sparse_index last = rowStart;
    for (sparse_index i = rowStart; i < (sparse_index)asFloat->rows && written < nz; i++) {
        const RevenantSparseRow *source = &asFloat->row[i];
        sparse_index at = RevenantSparseSearch(source, column);
        if (at >= source->count || source->column[at] != column) {
            continue;
        }
        if (val) {
            if (size == sizeof(float)) {
                ((float *)val)[written] = ((const float *)source->value)[at];
            } else {
                ((double *)val)[written] = ((const double *)source->value)[at];
            }
        }
        if (jndx) {
            jndx[written] = i;
        }
        written++;
        last = i;
    }
    sparse_index next = (sparse_index)asFloat->rows;
    for (sparse_index i = last + 1; i < (sparse_index)asFloat->rows; i++) {
        sparse_index at = RevenantSparseSearch(&asFloat->row[i], column);
        if (at < asFloat->row[i].count && asFloat->row[i].column[at] == column) {
            next = i;
            break;
        }
    }
    *rowEnd = nz == 0 ? rowStart : next;
    return (long)written;
}

sparse_status sparse_extract_sparse_column_float(sparse_matrix_float A, sparse_index column, sparse_index row_start,
                                                 sparse_index *row_end, sparse_dimension nz, float *__restrict val,
                                                 sparse_index *__restrict jndx)
{
    return (sparse_status)RevenantSparseExtractColumn(A, REVENANT_SPARSE_MAGIC_FLOAT, column, row_start, row_end, nz, val,
                                                    jndx, sizeof(float));
}

sparse_status sparse_extract_sparse_column_double(sparse_matrix_double A, sparse_index column, sparse_index row_start,
                                                  sparse_index *row_end, sparse_dimension nz, double *__restrict val,
                                                  sparse_index *__restrict jndx)
{
    return (sparse_status)RevenantSparseExtractColumn(A, REVENANT_SPARSE_MAGIC_DOUBLE, column, row_start, row_end, nz, val,
                                                    jndx, sizeof(double));
}

static sparse_status RevenantSparseExtractBlock(void *matrix, uint32_t magic, sparse_index bi, sparse_index bj,
                                              sparse_dimension rowStride, sparse_dimension colStride, void *val,
                                              size_t size)
{
    struct sparse_m_float *asFloat = NULL;
    sparse_status ready = RevenantSparseWritable(matrix, magic, 1, &asFloat);
    if (ready != SPARSE_SUCCESS) {
        return ready;
    }
    if (bi >= asFloat->blockRows || bj >= asFloat->blockColumns) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    sparse_dimension height = asFloat->blockHeight[bi], width = asFloat->blockWidth[bj];
    sparse_dimension first = 0;
    for (sparse_index b = 0; b < bi; b++) {
        first += asFloat->blockHeight[b];
    }
    sparse_dimension left = 0;
    for (sparse_index b = 0; b < bj; b++) {
        left += asFloat->blockWidth[b];
    }
    for (sparse_dimension i = 0; i < height; i++) {
        for (sparse_dimension j = 0; j < width; j++) {
            double value = RevenantSparseElementAt(&asFloat->row[first + i], left + j, size);
            char *to = (char *)val + (size_t)(i * rowStride + j * colStride) * size;
            if (size == sizeof(float)) {
                *(float *)to = (float)value;
            } else {
                *(double *)to = value;
            }
        }
    }
    return SPARSE_SUCCESS;
}

sparse_status sparse_extract_block_float(sparse_matrix_float A, sparse_index bi, sparse_index bj,
                                         sparse_dimension row_stride, sparse_dimension col_stride,
                                         float *__restrict val)
{
    return RevenantSparseExtractBlock(A, REVENANT_SPARSE_MAGIC_FLOAT, bi, bj, row_stride, col_stride, val, sizeof(float));
}

sparse_status sparse_extract_block_double(sparse_matrix_double A, sparse_index bi, sparse_index bj,
                                          sparse_dimension row_stride, sparse_dimension col_stride,
                                          double *__restrict val)
{
    return RevenantSparseExtractBlock(A, REVENANT_SPARSE_MAGIC_DOUBLE, bi, bj, row_stride, col_stride, val, sizeof(double));
}

static sparse_status RevenantSparseSetProperty(void *matrix, uint32_t magic, sparse_matrix_property pname)
{
    if (!RevenantSparseIsMatrix(matrix, magic)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    struct sparse_m_float *asFloat = (struct sparse_m_float *)matrix;
    if ((int)pname < 0) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    if (asFloat->inserted) {
        return SPARSE_CANNOT_SET_PROPERTY;
    }
    asFloat->property |= (long)pname;
    return SPARSE_SUCCESS;
}

sparse_status sparse_set_matrix_property(void *A, sparse_matrix_property pname)
{
    if (RevenantSparseIsFloat(A)) {
        return RevenantSparseSetProperty(A, REVENANT_SPARSE_MAGIC_FLOAT, pname);
    }
    if (RevenantSparseIsDouble(A)) {
        return RevenantSparseSetProperty(A, REVENANT_SPARSE_MAGIC_DOUBLE, pname);
    }
    if (RevenantSparseIsFloatComplex(A)) {
        return RevenantSparseSetProperty(A, REVENANT_SPARSE_MAGIC_FLOAT_COMPLEX, pname);
    }
    return RevenantSparseSetProperty(A, REVENANT_SPARSE_MAGIC_DOUBLE_COMPLEX, pname);
}

long sparse_get_matrix_property(void *A, sparse_matrix_property pname)
{
    if (RevenantSparseIsAny(A)) {
        long property = ((struct sparse_m_float *)A)->property;
        return (property & (long)pname) == (long)pname ? (long)pname : 0;
    }
    return 0;
}

sparse_dimension sparse_get_matrix_number_of_rows(void *A)
{
    return (RevenantSparseIsAny(A)) ? ((struct sparse_m_float *)A)->rows : 0;
}

sparse_dimension sparse_get_matrix_number_of_columns(void *A)
{
    return (RevenantSparseIsAny(A)) ? ((struct sparse_m_float *)A)->columns : 0;
}

long sparse_get_matrix_nonzero_count(void *A)
{
    return (RevenantSparseIsAny(A)) ? ((struct sparse_m_float *)A)->nonzero : 0;
}

long sparse_get_matrix_nonzero_count_for_row(void *A, sparse_index i)
{
    if (!RevenantSparseIsAny(A)) {
        return 0;
    }
    const struct sparse_m_float *asFloat = (const struct sparse_m_float *)A;
    return i < (sparse_index)asFloat->rows && i >= 0 ? (long)asFloat->row[i].count : 0;
}

long sparse_get_matrix_nonzero_count_for_column(void *A, sparse_index j)
{
    if (!RevenantSparseIsAny(A)) {
        return 0;
    }
    const struct sparse_m_float *asFloat = (const struct sparse_m_float *)A;
    if (j < 0 || j >= (sparse_index)asFloat->columns) {
        return 0;
    }
    long count = 0;
    for (sparse_dimension i = 0; i < asFloat->rows; i++) {
        sparse_index at = RevenantSparseSearch(&asFloat->row[i], j);
        if (at < asFloat->row[i].count && asFloat->row[i].column[at] == j) {
            count++;
        }
    }
    return count;
}

long sparse_get_block_dimension_for_row(void *A, sparse_index i)
{
    if (!RevenantSparseIsAny(A)) {
        return 0;
    }
    const struct sparse_m_float *asFloat = (const struct sparse_m_float *)A;
    if (i < 0 || !asFloat->blockHeight) {
        return 0;
    }
    return (long)RevenantSparseBlockAt(asFloat->blockHeight, asFloat->blockRows, i);
}

long sparse_get_block_dimension_for_col(void *A, sparse_index j)
{
    if (!RevenantSparseIsAny(A)) {
        return 0;
    }
    const struct sparse_m_float *asFloat = (const struct sparse_m_float *)A;
    if (j < 0 || !asFloat->blockWidth) {
        return 0;
    }
    return (long)RevenantSparseBlockAt(asFloat->blockWidth, asFloat->blockColumns, j);
}

sparse_status sparse_commit(void *A)
{
    return (RevenantSparseIsAny(A)) ? SPARSE_SUCCESS : SPARSE_ILLEGAL_PARAMETER;
}

sparse_status sparse_matrix_destroy(void *A)
{
    if (!RevenantSparseIsAny(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    struct sparse_m_float *asFloat = (struct sparse_m_float *)A;
    for (sparse_dimension i = 0; i < asFloat->rows; i++) {
        free(asFloat->row[i].column);
        free(asFloat->row[i].value);
    }
    free(asFloat->row);
    free(asFloat->blockHeight);
    free(asFloat->blockWidth);
    asFloat->magic = 0;
    free(asFloat);
    return SPARSE_SUCCESS;
}

static double RevenantSparseInnerDense(sparse_dimension nz, const void *x, const sparse_index *indx, const void *y,
                                     sparse_stride incy, size_t size)
{
    if (nz == 0) {
        return 0.0;
    }
    double sum = 0.0;
    for (sparse_dimension k = 0; k < nz; k++) {
        double value = size == sizeof(float) ? (double)((const float *)x)[k] : ((const double *)x)[k];
        long at = (long)(indx[k] * incy);
        double other = size == sizeof(float) ? (double)((const float *)y)[at] : ((const double *)y)[at];
        sum += value * other;
    }
    return sum;
}

float sparse_inner_product_dense_float(sparse_dimension nz, const float *__restrict x, const sparse_index *__restrict indx,
                                       const float *__restrict y, sparse_stride incy)
{
    return (float)RevenantSparseInnerDense(nz, x, indx, y, incy, sizeof(float));
}

double sparse_inner_product_dense_double(sparse_dimension nz, const double *__restrict x, const sparse_index *__restrict indx,
                                         const double *__restrict y, sparse_stride incy)
{
    return RevenantSparseInnerDense(nz, x, indx, y, incy, sizeof(double));
}

static double RevenantSparseInnerSparse(sparse_dimension nzx, sparse_dimension nzy, const void *x, const sparse_index *indx,
                                      const void *y, const sparse_index *indy, size_t size)
{
    if (nzx == 0 || nzy == 0) {
        return 0.0;
    }
    double sum = 0.0;
    sparse_dimension i = 0, j = 0;
    while (i < nzx && j < nzy) {
        if (indx[i] < indy[j]) {
            i++;
        } else if (indx[i] > indy[j]) {
            j++;
        } else {
            double left = size == sizeof(float) ? (double)((const float *)x)[i] : ((const double *)x)[i];
            double right = size == sizeof(float) ? (double)((const float *)y)[j] : ((const double *)y)[j];
            sum += left * right;
            i++;
            j++;
        }
    }
    return sum;
}

float sparse_inner_product_sparse_float(sparse_dimension nzx, sparse_dimension nzy, const float *__restrict x,
                                        const sparse_index *__restrict indx, const float *__restrict y,
                                        const sparse_index *__restrict indy)
{
    return (float)RevenantSparseInnerSparse(nzx, nzy, x, indx, y, indy, sizeof(float));
}

double sparse_inner_product_sparse_double(sparse_dimension nzx, sparse_dimension nzy, const double *__restrict x,
                                          const sparse_index *__restrict indx, const double *__restrict y,
                                          const sparse_index *__restrict indy)
{
    return RevenantSparseInnerSparse(nzx, nzy, x, indx, y, indy, sizeof(double));
}

static void RevenantSparseAddScale(sparse_dimension nz, double alpha, const void *x, const sparse_index *indx, void *y,
                                 sparse_stride incy, size_t size)
{
    if (nz == 0 || alpha == 0.0) {
        return;
    }
    for (sparse_dimension k = 0; k < nz; k++) {
        double value = size == sizeof(float) ? (double)((const float *)x)[k] : ((const double *)x)[k];
        long at = (long)(indx[k] * incy);
        double addend = alpha * value;
        if (size == sizeof(float)) {
            ((float *)y)[at] += (float)addend;
        } else {
            ((double *)y)[at] += addend;
        }
    }
}

void sparse_vector_add_with_scale_dense_float(sparse_dimension nz, float alpha, const float *__restrict x,
                                              const sparse_index *__restrict indx, float *__restrict y,
                                              sparse_stride incy)
{
    RevenantSparseAddScale(nz, alpha, x, indx, y, incy, sizeof(float));
}

void sparse_vector_add_with_scale_dense_double(sparse_dimension nz, double alpha, const double *__restrict x,
                                               const sparse_index *__restrict indx, double *__restrict y,
                                               sparse_stride incy)
{
    RevenantSparseAddScale(nz, alpha, x, indx, y, incy, sizeof(double));
}

static double RevenantSparseVectorNorm(sparse_dimension nz, const void *x, const sparse_index *indx, sparse_norm norm,
                                     size_t size)
{
    if (nz == 0) {
        return 0.0;
    }
    if (norm == SPARSE_NORM_ONE) {
        double sum = 0.0;
        for (sparse_dimension k = 0; k < nz; k++) {
            double value = size == sizeof(float) ? (double)((const float *)x)[k] : ((const double *)x)[k];
            sum += fabs(value);
        }
        return sum;
    }
    if (norm == SPARSE_NORM_TWO || norm == SPARSE_NORM_R1) {
        double sum = 0.0;
        for (sparse_dimension k = 0; k < nz; k++) {
            double value = size == sizeof(float) ? (double)((const float *)x)[k] : ((const double *)x)[k];
            sum += value * value;
        }
        return sqrt(sum);
    }
    double largest = 0.0;
    for (sparse_dimension k = 0; k < nz; k++) {
        double value = size == sizeof(float) ? (double)((const float *)x)[k] : ((const double *)x)[k];
        double magnitude = fabs(value);
        if (magnitude > largest) {
            largest = magnitude;
        }
    }
    return largest;
}

float sparse_vector_norm_float(sparse_dimension nz, const float *__restrict x, const sparse_index *__restrict indx,
                               sparse_norm norm)
{
    return (float)RevenantSparseVectorNorm(nz, x, indx, norm, sizeof(float));
}

double sparse_vector_norm_double(sparse_dimension nz, const double *__restrict x, const sparse_index *__restrict indx,
                                 sparse_norm norm)
{
    return RevenantSparseVectorNorm(nz, x, indx, norm, sizeof(double));
}

static long RevenantSparseVectorNonzero(sparse_dimension N, const void *x, sparse_stride incx, size_t size)
{
    if (N == 0) {
        return 0;
    }
    long count = 0;
    for (sparse_dimension i = 0; i < N; i++) {
        long at = (long)(i * incx);
        double value = size == sizeof(float) ? (double)((const float *)x)[at] : ((const double *)x)[at];
        if (value != 0.0) {
            count++;
        }
    }
    return count;
}

long sparse_get_vector_nonzero_count_float(sparse_dimension N, const float *__restrict x, sparse_stride incx)
{
    return RevenantSparseVectorNonzero(N, x, incx, sizeof(float));
}

long sparse_get_vector_nonzero_count_double(sparse_dimension N, const double *__restrict x, sparse_stride incx)
{
    return RevenantSparseVectorNonzero(N, x, incx, sizeof(double));
}

static long RevenantSparsePack(sparse_dimension N, sparse_dimension nz, const void *x, sparse_stride incx, void *y,
                             sparse_index *indy, size_t size)
{
    if (N == 0 || nz == 0) {
        return 0;
    }
    long written = 0;
    for (sparse_dimension i = 0; i < N && (sparse_dimension)written < nz; i++) {
        long at = (long)(i * incx);
        double value = size == sizeof(float) ? (double)((const float *)x)[at] : ((const double *)x)[at];
        if (value == 0.0) {
            continue;
        }
        if (y) {
            if (size == sizeof(float)) {
                ((float *)y)[written] = (float)value;
            } else {
                ((double *)y)[written] = value;
            }
        }
        if (indy) {
            indy[written] = (sparse_index)i;
        }
        written++;
    }
    return written;
}

long sparse_pack_vector_float(sparse_dimension N, sparse_dimension nz, const float *__restrict x, sparse_stride incx,
                              float *__restrict y, sparse_index *__restrict indy)
{
    return RevenantSparsePack(N, nz, x, incx, y, indy, sizeof(float));
}

long sparse_pack_vector_double(sparse_dimension N, sparse_dimension nz, const double *__restrict x, sparse_stride incx,
                               double *__restrict y, sparse_index *__restrict indy)
{
    return RevenantSparsePack(N, nz, x, incx, y, indy, sizeof(double));
}

static void RevenantSparseUnpack(sparse_dimension N, sparse_dimension nz, bool zero, const void *x, const sparse_index *indx,
                               void *y, sparse_stride incy, size_t size)
{
    if (zero) {
        for (sparse_dimension i = 0; i < N; i++) {
            long at = (long)(i * incy);
            if (size == sizeof(float)) {
                ((float *)y)[at] = 0.0f;
            } else {
                ((double *)y)[at] = 0.0;
            }
        }
    }
    for (sparse_dimension k = 0; k < nz; k++) {
        if (indx[k] < 0 || indx[k] >= (sparse_index)N) {
            continue;
        }
        double value = size == sizeof(float) ? (double)((const float *)x)[k] : ((const double *)x)[k];
        long at = (long)(indx[k] * incy);
        if (size == sizeof(float)) {
            ((float *)y)[at] = (float)value;
        } else {
            ((double *)y)[at] = value;
        }
    }
}

void sparse_unpack_vector_float(sparse_dimension N, sparse_dimension nz, bool zero, const float *__restrict x,
                                const sparse_index *__restrict indx, float *__restrict y, sparse_stride incy)
{
    RevenantSparseUnpack(N, nz, zero, x, indx, y, incy, sizeof(float));
}

void sparse_unpack_vector_double(sparse_dimension N, sparse_dimension nz, bool zero, const double *__restrict x,
                                 const sparse_index *__restrict indx, double *__restrict y, sparse_stride incy)
{
    RevenantSparseUnpack(N, nz, zero, x, indx, y, incy, sizeof(double));
}

static sparse_status RevenantSparseVectorProduct(void *matrix, uint32_t magic, int transposed, double alpha,
                                              const void *x, sparse_stride incx, void *y, sparse_stride incy, size_t size)
{
    if (!RevenantSparseIsMatrix(matrix, magic)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    const struct sparse_m_float *asFloat = (const struct sparse_m_float *)matrix;
    sparse_dimension inner = transposed ? asFloat->rows : asFloat->columns;
    sparse_dimension outer = transposed ? asFloat->columns : asFloat->rows;
    for (sparse_dimension i = 0; i < outer; i++) {
        for (sparse_dimension k = 0; k < inner; k++) {
            double value = RevenantSparseElementAt(&asFloat->row[transposed ? k : i], transposed ? i : k, size);
            if (value == 0.0) {
                continue;
            }
            double addend = alpha * value;
            long from = (long)(k * incx);
            long to = (long)(i * incy);
            if (size == sizeof(float)) {
                cblas_saxpy(1, (float)addend, (const float *)x + from, 1, (float *)y + to, 1);
            } else {
                cblas_daxpy(1, addend, (const double *)x + from, 1, (double *)y + to, 1);
            }
        }
    }
    return SPARSE_SUCCESS;
}

sparse_status sparse_matrix_vector_product_dense_float(enum CBLAS_TRANSPOSE transa, float alpha, sparse_matrix_float A,
                                                       const float *__restrict x, sparse_stride incx,
                                                       float *__restrict y, sparse_stride incy)
{
    if (transa != CblasNoTrans && transa != CblasTrans) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    return RevenantSparseVectorProduct(A, REVENANT_SPARSE_MAGIC_FLOAT, transa == CblasTrans, alpha, x, incx, y, incy,
                                     sizeof(float));
}

sparse_status sparse_matrix_vector_product_dense_double(enum CBLAS_TRANSPOSE transa, double alpha, sparse_matrix_double A,
                                                        const double *__restrict x, sparse_stride incx,
                                                        double *__restrict y, sparse_stride incy)
{
    if (transa != CblasNoTrans && transa != CblasTrans) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    return RevenantSparseVectorProduct(A, REVENANT_SPARSE_MAGIC_DOUBLE, transa == CblasTrans, alpha, x, incx, y, incy,
                                     sizeof(double));
}

static sparse_status RevenantSparseTriangular(void *matrix, uint32_t magic, int transposed, double alpha, void *b,
                                           long iStep, long rightStep, sparse_dimension nrhs, size_t size)
{
    if (!RevenantSparseIsMatrix(matrix, magic)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    const struct sparse_m_float *asFloat = (const struct sparse_m_float *)matrix;
    if (!(asFloat->property & (SPARSE_UPPER_TRIANGULAR | SPARSE_LOWER_TRIANGULAR))) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    int upper = (asFloat->property & SPARSE_UPPER_TRIANGULAR) != 0;
    sparse_dimension n = asFloat->rows;
    sparse_index *lists = NULL;
    sparse_index *offsets = NULL;
    if (transposed) {
        lists = (sparse_index *)calloc((size_t)n + 1, sizeof(sparse_index));
        offsets = (sparse_index *)calloc((size_t)n + 1, sizeof(sparse_index));
        if (!lists || !offsets) {
            free(lists);
            free(offsets);
            return SPARSE_SYSTEM_ERROR;
        }
        for (sparse_dimension i = 0; i < n; i++) {
            for (sparse_dimension r = 0; r < n; r++) {
                sparse_index at = RevenantSparseSearch(&asFloat->row[r], (sparse_index)i);
                if (at < asFloat->row[r].count && asFloat->row[r].column[at] == (sparse_index)i) {
                    lists[offsets[(sparse_index)i]++] = r;
                }
            }
        }
        sparse_index running = 0;
        for (sparse_index i = 0; i <= (sparse_index)n; i++) {
            sparse_index count = offsets[i];
            offsets[i] = running;
            running += count;
        }
    }
    for (sparse_dimension right = 0; right < nrhs; right++) {
        int backwards = upper != (transposed ? 1 : 0);
        for (sparse_dimension step = 0; step < n; step++) {
            sparse_dimension i = backwards ? n - 1 - step : step;
            long here = (long)i * iStep + (long)right * rightStep;
            double value = size == sizeof(float) ? (double)((float *)b)[here] : ((double *)b)[here];
            value /= alpha;
            if (!transposed) {
                for (sparse_index at = 0; at < asFloat->row[i].count; at++) {
                    sparse_index j = asFloat->row[i].column[at];
                    if (j == (sparse_index)i || (j < (sparse_index)i) == backwards) {
                        continue;
                    }
                    double other = size == sizeof(float) ? (double)((const float *)asFloat->row[i].value)[at]
                                                        : ((const double *)asFloat->row[i].value)[at];
                    long from = (long)j * iStep + (long)right * rightStep;
                    double addend = size == sizeof(float) ? (double)((float *)b)[from] : ((double *)b)[from];
                    value -= other * addend;
                }
            } else {
                sparse_index from = offsets[i], to = offsets[i + 1];
                for (sparse_index k = from; k < to; k++) {
                    sparse_index j = lists[k];
                    if (j == (sparse_index)i || (j < (sparse_index)i) == backwards) {
                        continue;
                    }
                    double other = RevenantSparseElementAt(&asFloat->row[j], (sparse_index)i, size);
                    long at2 = (long)j * iStep + (long)right * rightStep;
                    double addend = size == sizeof(float) ? (double)((float *)b)[at2] : ((double *)b)[at2];
                    value -= other * addend;
                }
            }
            double diagonal = RevenantSparseElementAt(&asFloat->row[i], i, size);
            value /= diagonal;
            if (size == sizeof(float)) {
                ((float *)b)[here] = (float)value;
            } else {
                ((double *)b)[here] = value;
            }
        }
    }
    free(lists);
    free(offsets);
    return SPARSE_SUCCESS;
}

sparse_status sparse_vector_triangular_solve_dense_float(enum CBLAS_TRANSPOSE transt, float alpha, sparse_matrix_float T,
                                                         float *__restrict x, sparse_stride incx)
{
    if (transt != CblasNoTrans && transt != CblasTrans) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    return RevenantSparseTriangular(T, REVENANT_SPARSE_MAGIC_FLOAT, transt == CblasTrans, alpha, x, incx, 0, 1,
                                  sizeof(float));
}

sparse_status sparse_vector_triangular_solve_dense_double(enum CBLAS_TRANSPOSE transt, double alpha, sparse_matrix_double T,
                                                          double *__restrict x, sparse_stride incx)
{
    if (transt != CblasNoTrans && transt != CblasTrans) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    return RevenantSparseTriangular(T, REVENANT_SPARSE_MAGIC_DOUBLE, transt == CblasTrans, alpha, x, incx, 0, 1,
                                  sizeof(double));
}

sparse_status sparse_matrix_triangular_solve_dense_float(enum CBLAS_ORDER order, enum CBLAS_TRANSPOSE transt,
                                                         sparse_dimension nrhs, float alpha, sparse_matrix_float T,
                                                         float *__restrict B, sparse_dimension ldb)
{
    if (order != CblasRowMajor && order != CblasColMajor) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    if (transt != CblasNoTrans && transt != CblasTrans) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    if (!RevenantSparseIsFloat(T)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    const struct sparse_m_float *asFloat = (const struct sparse_m_float *)T;
    sparse_dimension needed = order == CblasRowMajor ? (nrhs ? nrhs : 1) : (asFloat->rows ? asFloat->rows : 1);
    if (ldb < needed) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    return RevenantSparseTriangular(T, REVENANT_SPARSE_MAGIC_FLOAT, transt == CblasTrans, alpha, B,
                                  order == CblasRowMajor ? (long)ldb : 1, order == CblasRowMajor ? 1 : (long)ldb,
                                  nrhs, sizeof(float));
}

sparse_status sparse_matrix_triangular_solve_dense_double(enum CBLAS_ORDER order, enum CBLAS_TRANSPOSE transt,
                                                          sparse_dimension nrhs, double alpha, sparse_matrix_double T,
                                                          double *__restrict B, sparse_dimension ldb)
{
    if (order != CblasRowMajor && order != CblasColMajor) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    if (transt != CblasNoTrans && transt != CblasTrans) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    if (!RevenantSparseIsDouble(T)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    const struct sparse_m_float *asFloat = (const struct sparse_m_float *)T;
    sparse_dimension needed = order == CblasRowMajor ? (nrhs ? nrhs : 1) : (asFloat->rows ? asFloat->rows : 1);
    if (ldb < needed) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    return RevenantSparseTriangular(T, REVENANT_SPARSE_MAGIC_DOUBLE, transt == CblasTrans, alpha, B,
                                  order == CblasRowMajor ? (long)ldb : 1, order == CblasRowMajor ? 1 : (long)ldb,
                                  nrhs, sizeof(double));
}

static sparse_status RevenantSparseOuter(sparse_dimension M, sparse_dimension N, sparse_dimension nz, double alpha,
                                       const void *x, sparse_stride incx, const void *y, const sparse_index *indy,
                                       void **C, uint32_t magic, size_t size, size_t matrixSize)
{
    if (nz > N) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    void *matrix = NULL;
    if (RevenantSparseMake(&matrix, magic, matrixSize, M, N, 0, 0, NULL, NULL) != SPARSE_SUCCESS) {
        return SPARSE_SYSTEM_ERROR;
    }
    struct sparse_m_float *asFloat = (struct sparse_m_float *)matrix;
    for (sparse_dimension k = 0; k < nz; k++) {
        double right = size == sizeof(float) ? (double)((const float *)y)[k] : ((const double *)y)[k];
        if (alpha == 0.0 || right == 0.0) {
            continue;
        }
        for (sparse_dimension i = 0; i < M; i++) {
            double left = size == sizeof(float) ? (double)((const float *)x)[(long)(i * incx)]
                                                : ((const double *)x)[(long)(i * incx)];
            double value = alpha * left * right;
            if (value == 0.0) {
                continue;
            }
            sparse_index before = asFloat->row[i].count;
            RevenantSparsePut(&asFloat->row[i], indy[k], value, size);
            asFloat->nonzero += (long)asFloat->row[i].count - (long)before;
        }
    }
    void **out = (void **)C;
    *out = matrix;
    return SPARSE_SUCCESS;
}

sparse_status sparse_outer_product_dense_float(sparse_dimension M, sparse_dimension N, sparse_dimension nz, float alpha,
                                               const float *__restrict x, sparse_stride incx, const float *__restrict y,
                                               const sparse_index *__restrict indy, sparse_matrix_float *__restrict C)
{
    return RevenantSparseOuter(M, N, nz, alpha, x, incx, y, indy, (void **)C, REVENANT_SPARSE_MAGIC_FLOAT, sizeof(float),
                             sizeof(struct sparse_m_float));
}

sparse_status sparse_outer_product_dense_double(sparse_dimension M, sparse_dimension N, sparse_dimension nz, double alpha,
                                                const double *__restrict x, sparse_stride incx,
                                                const double *__restrict y, const sparse_index *__restrict indy,
                                                sparse_matrix_double *__restrict C)
{
    return RevenantSparseOuter(M, N, nz, alpha, x, incx, y, indy, (void **)C, REVENANT_SPARSE_MAGIC_DOUBLE, sizeof(double),
                             sizeof(struct sparse_m_double));
}

sparse_status sparse_permute_rows_float(sparse_matrix_float A, const sparse_index *__restrict perm)
{
    if (!RevenantSparseIsFloat(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    RevenantSparsePermuteRows((struct sparse_m_float *)A, perm);
    return SPARSE_SUCCESS;
}

sparse_status sparse_permute_rows_double(sparse_matrix_double A, const sparse_index *__restrict perm)
{
    if (!RevenantSparseIsDouble(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    RevenantSparsePermuteRows((struct sparse_m_float *)A, perm);
    return SPARSE_SUCCESS;
}

sparse_status sparse_permute_cols_float(sparse_matrix_float A, const sparse_index *__restrict perm)
{
    if (!RevenantSparseIsFloat(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    RevenantSparsePermuteColumns((struct sparse_m_float *)A, perm, sizeof(float));
    return SPARSE_SUCCESS;
}

sparse_status sparse_permute_cols_double(sparse_matrix_double A, const sparse_index *__restrict perm)
{
    if (!RevenantSparseIsDouble(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    RevenantSparsePermuteColumns((struct sparse_m_float *)A, perm, sizeof(double));
    return SPARSE_SUCCESS;
}

static double RevenantSparseElementwise(void *matrix, uint32_t magic, sparse_norm norm, size_t size)
{
    if (!RevenantSparseIsMatrix(matrix, magic)) {
        return 0.0;
    }
    const struct sparse_m_float *asFloat = (const struct sparse_m_float *)matrix;
    if (norm == SPARSE_NORM_ONE) {
        double sum = 0.0;
        for (sparse_dimension i = 0; i < asFloat->rows; i++) {
            for (sparse_index at = 0; at < asFloat->row[i].count; at++) {
                double value = size == sizeof(float) ? (double)((const float *)asFloat->row[i].value)[at]
                                                    : ((const double *)asFloat->row[i].value)[at];
                sum += fabs(value);
            }
        }
        return sum;
    }
    if (norm == SPARSE_NORM_TWO) {
        double sum = 0.0;
        for (sparse_dimension i = 0; i < asFloat->rows; i++) {
            for (sparse_index at = 0; at < asFloat->row[i].count; at++) {
                double value = size == sizeof(float) ? (double)((const float *)asFloat->row[i].value)[at]
                                                    : ((const double *)asFloat->row[i].value)[at];
                sum += value * value;
            }
        }
        return sqrt(sum);
    }
    if (norm == SPARSE_NORM_R1) {
        double total = 0.0;
        for (sparse_index j = 0; j < (sparse_index)asFloat->columns; j++) {
            double sum = 0.0;
            for (sparse_dimension i = 0; i < asFloat->rows; i++) {
                double value = RevenantSparseElementAt(&asFloat->row[i], j, size);
                sum += value * value;
            }
            total += sqrt(sum);
        }
        return total;
    }
    double largest = 0.0;
    for (sparse_dimension i = 0; i < asFloat->rows; i++) {
        for (sparse_index at = 0; at < asFloat->row[i].count; at++) {
            double value = size == sizeof(float) ? (double)((const float *)asFloat->row[i].value)[at]
                                                : ((const double *)asFloat->row[i].value)[at];
            double magnitude = fabs(value);
            if (magnitude > largest) {
                largest = magnitude;
            }
        }
    }
    return largest;
}

float sparse_elementwise_norm_float(sparse_matrix_float A, sparse_norm norm)
{
    return (float)RevenantSparseElementwise(A, REVENANT_SPARSE_MAGIC_FLOAT, norm, sizeof(float));
}

double sparse_elementwise_norm_double(sparse_matrix_double A, sparse_norm norm)
{
    return RevenantSparseElementwise(A, REVENANT_SPARSE_MAGIC_DOUBLE, norm, sizeof(double));
}

static double RevenantSparseOperator(void *matrix, uint32_t magic, sparse_norm norm, size_t size)
{
    if (!RevenantSparseIsMatrix(matrix, magic)) {
        return 0.0;
    }
    const struct sparse_m_float *asFloat = (const struct sparse_m_float *)matrix;
    sparse_dimension m = asFloat->rows, n = asFloat->columns;
    if (m == 0 || n == 0) {
        return 0.0;
    }
    if (norm == SPARSE_NORM_ONE) {
        double largest = 0.0;
        for (sparse_index j = 0; j < (sparse_index)n; j++) {
            double sum = 0.0;
            for (sparse_dimension i = 0; i < m; i++) {
                sum += fabs(RevenantSparseElementAt(&asFloat->row[i], j, size));
            }
            if (sum > largest) {
                largest = sum;
            }
        }
        return largest;
    }
    if (norm == SPARSE_NORM_INF || (norm != SPARSE_NORM_TWO && norm != SPARSE_NORM_R1)) {
        double largest = 0.0;
        for (sparse_dimension i = 0; i < m; i++) {
            double sum = 0.0;
            for (sparse_index at = 0; at < asFloat->row[i].count; at++) {
                double value = size == sizeof(float) ? (double)((const float *)asFloat->row[i].value)[at]
                                                    : ((const double *)asFloat->row[i].value)[at];
                sum += fabs(value);
            }
            if (sum > largest) {
                largest = sum;
            }
        }
        return largest;
    }
    if (norm == SPARSE_NORM_R1) {
        return (double)NAN;
    }
    if (size == sizeof(float)) {
        float *gram = (float *)calloc((size_t)m * m, sizeof(float));
        if (!gram) {
            return 0.0;
        }
        for (sparse_dimension i = 0; i < m; i++) {
            for (sparse_dimension k = 0; k < m; k++) {
                for (sparse_index at = 0; at < asFloat->row[i].count; at++) {
                    sparse_index j = asFloat->row[i].column[at];
                    float value = ((const float *)asFloat->row[i].value)[at];
                    float other = (float)RevenantSparseElementAt(&asFloat->row[k], j, size);
                    gram[i * m + k] += value * other;
                }
            }
        }
        __CLPK_integer count = (__CLPK_integer)m, leading = (__CLPK_integer)m, lwork = 4 * (__CLPK_integer)m + 64,
                          info = 0;
        float *work = (float *)malloc((size_t)lwork * sizeof(float));
        float *values = (float *)malloc((size_t)m * sizeof(float));
        double largest = 0.0;
        if (work && values) {
            ssyev_("N", "L", &count, gram, &leading, values, work, &lwork, &info);
            for (sparse_dimension i = 0; !info && i < m; i++) {
                if (values[i] > largest) {
                    largest = values[i];
                }
            }
        }
        free(work);
        free(values);
        free(gram);
        return largest > 0.0 ? sqrt(largest) : 0.0;
    }
    {
        double *gram = (double *)calloc((size_t)m * m, sizeof(double));
        if (!gram) {
            return 0.0;
        }
        for (sparse_dimension i = 0; i < m; i++) {
            for (sparse_dimension k = 0; k < m; k++) {
                for (sparse_index at = 0; at < asFloat->row[i].count; at++) {
                    sparse_index j = asFloat->row[i].column[at];
                    double value = ((const double *)asFloat->row[i].value)[at];
                    double other = RevenantSparseElementAt(&asFloat->row[k], j, size);
                    gram[i * m + k] += value * other;
                }
            }
        }
        __CLPK_integer count = (__CLPK_integer)m, leading = (__CLPK_integer)m, lwork = 4 * (__CLPK_integer)m + 64,
                          info = 0;
        double *work = (double *)malloc((size_t)lwork * sizeof(double));
        double *values = (double *)malloc((size_t)m * sizeof(double));
        double largest = 0.0;
        if (work && values) {
            dsyev_("N", "L", &count, gram, &leading, values, work, &lwork, &info);
            for (sparse_dimension i = 0; !info && i < m; i++) {
                if (values[i] > largest) {
                    largest = values[i];
                }
            }
        }
        free(work);
        free(values);
        free(gram);
        return largest > 0.0 ? sqrt(largest) : 0.0;
    }
}

float sparse_operator_norm_float(sparse_matrix_float A, sparse_norm norm)
{
    return (float)RevenantSparseOperator(A, REVENANT_SPARSE_MAGIC_FLOAT, norm, sizeof(float));
}

double sparse_operator_norm_double(sparse_matrix_double A, sparse_norm norm)
{
    return RevenantSparseOperator(A, REVENANT_SPARSE_MAGIC_DOUBLE, norm, sizeof(double));
}

static double RevenantSparseTrace(void *matrix, uint32_t magic, sparse_index offset, size_t size)
{
    if (!RevenantSparseIsMatrix(matrix, magic)) {
        return 0.0;
    }
    const struct sparse_m_float *asFloat = (const struct sparse_m_float *)matrix;
    double sum = 0.0;
    for (sparse_dimension i = 0; i < asFloat->rows; i++) {
        sparse_index row = offset >= 0 ? (sparse_index)i : (sparse_index)i - offset;
        sparse_index column = offset >= 0 ? (sparse_index)i + offset : (sparse_index)i;
        if (row < 0 || row >= (sparse_index)asFloat->rows || column < 0 || column >= (sparse_index)asFloat->columns) {
            continue;
        }
        sum += RevenantSparseElementAt(&asFloat->row[row], column, size);
    }
    return sum;
}

float sparse_matrix_trace_float(sparse_matrix_float A, sparse_index offset)
{
    return (float)RevenantSparseTrace(A, REVENANT_SPARSE_MAGIC_FLOAT, offset, sizeof(float));
}

double sparse_matrix_trace_double(sparse_matrix_double A, sparse_index offset)
{
    return RevenantSparseTrace(A, REVENANT_SPARSE_MAGIC_DOUBLE, offset, sizeof(double));
}

static sparse_status RevenantSparseProductDense(void *matrix, uint32_t magic, int order, int transposed, sparse_dimension n,
                                              double alpha, const void *B, sparse_dimension ldb, void *C,
                                              sparse_dimension ldc, size_t size)
{
    if (order != CblasRowMajor && order != CblasColMajor) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    if (!RevenantSparseIsMatrix(matrix, magic)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    const struct sparse_m_float *asFloat = (const struct sparse_m_float *)matrix;
    sparse_dimension m = transposed ? asFloat->columns : asFloat->rows;
    sparse_dimension k = transposed ? asFloat->rows : asFloat->columns;
    sparse_dimension bStep = order == CblasRowMajor ? 1 : ldb;
    sparse_dimension cStep = order == CblasRowMajor ? 1 : ldc;
    if (ldb < (order == CblasRowMajor ? (n ? n : 1) : (k ? k : 1)) ||
        ldc < (order == CblasRowMajor ? (n ? n : 1) : (m ? m : 1))) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    if (n == 0 || alpha == 0.0) {
        return SPARSE_SUCCESS;
    }
    void *row = malloc((size_t)(n ? n : 1) * size);
    if (!row) {
        return SPARSE_SYSTEM_ERROR;
    }
    for (sparse_dimension i = 0; i < m; i++) {
        const RevenantSparseRow *line = transposed ? NULL : &asFloat->row[i];
        for (sparse_index at = 0; at < (transposed ? (sparse_index)asFloat->rows : line->count); at++) {
            sparse_index r = transposed ? at : (sparse_index)i;
            sparse_index c = transposed ? (sparse_index)i : line->column[at];
            if (c >= (sparse_index)asFloat->columns) {
                continue;
            }
            double value = RevenantSparseElementAt(&asFloat->row[r], c, size);
            if (value == 0.0) {
                continue;
            }
            long from = RevenantSparseDenseAt(order, ldb, transposed ? r : c, 0);
            long to = RevenantSparseDenseAt(order, ldc, i, 0);
            if (size == sizeof(float)) {
                cblas_scopy((int)n, (const float *)B + from, (int)bStep, (float *)row, 1);
                cblas_saxpy((int)n, (float)(alpha * value), (const float *)row, 1, (float *)C + to, (int)cStep);
            } else {
                cblas_dcopy((int)n, (const double *)B + from, (int)bStep, (double *)row, 1);
                cblas_daxpy((int)n, alpha * value, (const double *)row, 1, (double *)C + to, (int)cStep);
            }
        }
    }
    free(row);
    return SPARSE_SUCCESS;
}

sparse_status sparse_matrix_product_dense_float(enum CBLAS_ORDER order, enum CBLAS_TRANSPOSE transa, sparse_dimension n,
                                                float alpha, sparse_matrix_float A, const float *__restrict B,
                                                sparse_dimension ldb, float *__restrict C, sparse_dimension ldc)
{
    if (transa != CblasNoTrans && transa != CblasTrans) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    return RevenantSparseProductDense(A, REVENANT_SPARSE_MAGIC_FLOAT, order, transa == CblasTrans, n, alpha, B, ldb, C, ldc,
                                    sizeof(float));
}

sparse_status sparse_matrix_product_dense_double(enum CBLAS_ORDER order, enum CBLAS_TRANSPOSE transa, sparse_dimension n,
                                                 double alpha, sparse_matrix_double A, const double *__restrict B,
                                                 sparse_dimension ldb, double *__restrict C, sparse_dimension ldc)
{
    if (transa != CblasNoTrans && transa != CblasTrans) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    return RevenantSparseProductDense(A, REVENANT_SPARSE_MAGIC_DOUBLE, order, transa == CblasTrans, n, alpha, B, ldb, C, ldc,
                                    sizeof(double));
}
