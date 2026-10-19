#import <Accelerate/Accelerate.h>
#include "RevenantSparseComplex26.h"
#include "RevenantSparseBLAS.h"
#include "RevenantSparseComplex.h"


sparse_matrix_float_complex sparse_matrix_create_float_complex(sparse_dimension M, sparse_dimension N)
{
    void *matrix = NULL;
    if (RevenantSparseMake(&matrix, REVENANT_SPARSE_MAGIC_FLOAT_COMPLEX, sizeof(struct sparse_m_float_complex), M, N, 0, 0,
                         NULL, NULL) != SPARSE_SUCCESS) {
        return NULL;
    }
    return (sparse_matrix_float_complex)matrix;
}

sparse_matrix_double_complex sparse_matrix_create_double_complex(sparse_dimension M, sparse_dimension N)
{
    void *matrix = NULL;
    if (RevenantSparseMake(&matrix, REVENANT_SPARSE_MAGIC_DOUBLE_COMPLEX, sizeof(struct sparse_m_double_complex), M, N, 0, 0,
                         NULL, NULL) != SPARSE_SUCCESS) {
        return NULL;
    }
    return (sparse_matrix_double_complex)matrix;
}

sparse_matrix_float_complex sparse_matrix_block_create_float_complex(sparse_dimension Mb, sparse_dimension Nb,
                                                                    sparse_dimension k, sparse_dimension l)
{
    sparse_dimension *heights = RevenantSparseRepeated(k, (sparse_index)Mb);
    sparse_dimension *widths = RevenantSparseRepeated(l, (sparse_index)Nb);
    void *matrix = NULL;
    sparse_status made =
        RevenantSparseMake(&matrix, REVENANT_SPARSE_MAGIC_FLOAT_COMPLEX, sizeof(struct sparse_m_float_complex), 0, 0,
                         (sparse_index)Mb, (sparse_index)Nb, heights, widths);
    free(heights);
    free(widths);
    return made == SPARSE_SUCCESS ? (sparse_matrix_float_complex)matrix : NULL;
}

sparse_matrix_double_complex sparse_matrix_block_create_double_complex(sparse_dimension Mb, sparse_dimension Nb,
                                                                      sparse_dimension k, sparse_dimension l)
{
    sparse_dimension *heights = RevenantSparseRepeated(k, (sparse_index)Mb);
    sparse_dimension *widths = RevenantSparseRepeated(l, (sparse_index)Nb);
    void *matrix = NULL;
    sparse_status made =
        RevenantSparseMake(&matrix, REVENANT_SPARSE_MAGIC_DOUBLE_COMPLEX, sizeof(struct sparse_m_double_complex), 0, 0,
                         (sparse_index)Mb, (sparse_index)Nb, heights, widths);
    free(heights);
    free(widths);
    return made == SPARSE_SUCCESS ? (sparse_matrix_double_complex)matrix : NULL;
}

sparse_matrix_float_complex sparse_matrix_variable_block_create_float_complex(sparse_dimension Mb, sparse_dimension Nb,
                                                                             const sparse_dimension *K,
                                                                             const sparse_dimension *L)
{
    void *matrix = NULL;
    if (RevenantSparseMake(&matrix, REVENANT_SPARSE_MAGIC_FLOAT_COMPLEX, sizeof(struct sparse_m_float_complex), 0, 0,
                         (sparse_index)Mb, (sparse_index)Nb, K, L) != SPARSE_SUCCESS) {
        return NULL;
    }
    return (sparse_matrix_float_complex)matrix;
}

sparse_matrix_double_complex sparse_matrix_variable_block_create_double_complex(sparse_dimension Mb, sparse_dimension Nb,
                                                                               const sparse_dimension *K,
                                                                               const sparse_dimension *L)
{
    void *matrix = NULL;
    if (RevenantSparseMake(&matrix, REVENANT_SPARSE_MAGIC_DOUBLE_COMPLEX, sizeof(struct sparse_m_double_complex), 0, 0,
                         (sparse_index)Mb, (sparse_index)Nb, K, L) != SPARSE_SUCCESS) {
        return NULL;
    }
    return (sparse_matrix_double_complex)matrix;
}

sparse_status sparse_insert_entry_float_complex(sparse_matrix_float_complex A, float _Complex val, sparse_index i,
                                                sparse_index j)
{
    return RevenantSparsePutEntryComplex(A, REVENANT_SPARSE_MAGIC_FLOAT_COMPLEX, __real__ val, __imag__ val, i, j,
                                       sizeof(float _Complex));
}

sparse_status sparse_insert_entry_double_complex(sparse_matrix_double_complex A, double _Complex val, sparse_index i,
                                                 sparse_index j)
{
    return RevenantSparsePutEntryComplex(A, REVENANT_SPARSE_MAGIC_DOUBLE_COMPLEX, __real__ val, __imag__ val, i, j,
                                       sizeof(double _Complex));
}

sparse_status sparse_insert_entries_float_complex(sparse_matrix_float_complex A, sparse_dimension N,
                                                  const float _Complex *__restrict val,
                                                  const sparse_index *__restrict indx,
                                                  const sparse_index *__restrict jndx)
{
    if (!RevenantSparseIsFloatComplex(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    for (sparse_dimension k = 0; k < N; k++) {
        sparse_status put = RevenantSparsePutEntryComplex(A, REVENANT_SPARSE_MAGIC_FLOAT_COMPLEX, __real__ val[k],
                                                        __imag__ val[k], indx[k], jndx[k], sizeof(float _Complex));
        if (put != SPARSE_SUCCESS) {
            return put;
        }
    }
    return SPARSE_SUCCESS;
}

sparse_status sparse_insert_entries_double_complex(sparse_matrix_double_complex A, sparse_dimension N,
                                                   const double _Complex *__restrict val,
                                                   const sparse_index *__restrict indx,
                                                   const sparse_index *__restrict jndx)
{
    if (!RevenantSparseIsDoubleComplex(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    for (sparse_dimension k = 0; k < N; k++) {
        sparse_status put = RevenantSparsePutEntryComplex(A, REVENANT_SPARSE_MAGIC_DOUBLE_COMPLEX, __real__ val[k],
                                                        __imag__ val[k], indx[k], jndx[k], sizeof(double _Complex));
        if (put != SPARSE_SUCCESS) {
            return put;
        }
    }
    return SPARSE_SUCCESS;
}

sparse_status sparse_insert_col_float_complex(sparse_matrix_float_complex A, sparse_index j, sparse_dimension nz,
                                              const float _Complex *__restrict val,
                                              const sparse_index *__restrict indx)
{
    if (!RevenantSparseIsFloatComplex(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    for (sparse_dimension k = 0; k < nz; k++) {
        sparse_status put = RevenantSparsePutEntryComplex(A, REVENANT_SPARSE_MAGIC_FLOAT_COMPLEX, __real__ val[k],
                                                        __imag__ val[k], indx[k], j, sizeof(float _Complex));
        if (put != SPARSE_SUCCESS) {
            return put;
        }
    }
    return SPARSE_SUCCESS;
}

sparse_status sparse_insert_col_double_complex(sparse_matrix_double_complex A, sparse_index j, sparse_dimension nz,
                                                const double _Complex *__restrict val,
                                                const sparse_index *__restrict indx)
{
    if (!RevenantSparseIsDoubleComplex(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    for (sparse_dimension k = 0; k < nz; k++) {
        sparse_status put = RevenantSparsePutEntryComplex(A, REVENANT_SPARSE_MAGIC_DOUBLE_COMPLEX, __real__ val[k],
                                                        __imag__ val[k], indx[k], j, sizeof(double _Complex));
        if (put != SPARSE_SUCCESS) {
            return put;
        }
    }
    return SPARSE_SUCCESS;
}

sparse_status sparse_insert_row_float_complex(sparse_matrix_float_complex A, sparse_index i, sparse_dimension nz,
                                              const float _Complex *__restrict val,
                                              const sparse_index *__restrict jndx)
{
    if (!RevenantSparseIsFloatComplex(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    for (sparse_dimension k = 0; k < nz; k++) {
        sparse_status put = RevenantSparsePutEntryComplex(A, REVENANT_SPARSE_MAGIC_FLOAT_COMPLEX, __real__ val[k],
                                                        __imag__ val[k], i, jndx[k], sizeof(float _Complex));
        if (put != SPARSE_SUCCESS) {
            return put;
        }
    }
    return SPARSE_SUCCESS;
}

sparse_status sparse_insert_row_double_complex(sparse_matrix_double_complex A, sparse_index i, sparse_dimension nz,
                                                const double _Complex *__restrict val,
                                                const sparse_index *__restrict jndx)
{
    if (!RevenantSparseIsDoubleComplex(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    for (sparse_dimension k = 0; k < nz; k++) {
        sparse_status put = RevenantSparsePutEntryComplex(A, REVENANT_SPARSE_MAGIC_DOUBLE_COMPLEX, __real__ val[k],
                                                        __imag__ val[k], i, jndx[k], sizeof(double _Complex));
        if (put != SPARSE_SUCCESS) {
            return put;
        }
    }
    return SPARSE_SUCCESS;
}

static sparse_status RevenantSparsePutBlockComplex(void *matrix, uint32_t magic, const void *val,
                                                 sparse_dimension rowStride, sparse_dimension colStride, sparse_index bi,
                                                 sparse_index bj, size_t size)
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
            double re = 0.0, im = 0.0;
            RevenantSparseReadComplexValue(val, (sparse_index)(i * rowStride + j * colStride), size, &re, &im);
            sparse_index before = asFloat->row[first + i].count;
            sparse_status put = RevenantSparsePutComplex(&asFloat->row[first + i], left + j, re, im, size);
            if (put != SPARSE_SUCCESS) {
                return put;
            }
            asFloat->nonzero += (long)asFloat->row[first + i].count - (long)before;
        }
    }
    asFloat->inserted = 1;
    return SPARSE_SUCCESS;
}

sparse_status sparse_insert_block_float_complex(sparse_matrix_float_complex A, const float _Complex *__restrict val,
                                                sparse_dimension row_stride, sparse_dimension col_stride,
                                                sparse_index bi, sparse_index bj)
{
    return RevenantSparsePutBlockComplex(A, REVENANT_SPARSE_MAGIC_FLOAT_COMPLEX, val, row_stride, col_stride, bi, bj,
                                       sizeof(float _Complex));
}

sparse_status sparse_insert_block_double_complex(sparse_matrix_double_complex A, const double _Complex *__restrict val,
                                                 sparse_dimension row_stride, sparse_dimension col_stride,
                                                 sparse_index bi, sparse_index bj)
{
    return RevenantSparsePutBlockComplex(A, REVENANT_SPARSE_MAGIC_DOUBLE_COMPLEX, val, row_stride, col_stride, bi, bj,
                                       sizeof(double _Complex));
}

static long RevenantSparseExtractRowComplex(void *matrix, uint32_t magic, sparse_index row, sparse_index columnStart,
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
            double re = 0.0, im = 0.0;
            RevenantSparseReadComplexValue(source->value, at, size, &re, &im);
            RevenantSparseWriteComplexValue(val, written, re, im, size);
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

sparse_status sparse_extract_sparse_row_float_complex(sparse_matrix_float_complex A, sparse_index row,
                                                      sparse_index column_start, sparse_index *column_end,
                                                      sparse_dimension nz, float _Complex *__restrict val,
                                                      sparse_index *__restrict jndx)
{
    return (sparse_status)RevenantSparseExtractRowComplex(A, REVENANT_SPARSE_MAGIC_FLOAT_COMPLEX, row, column_start,
                                                        column_end, nz, val, jndx, sizeof(float _Complex));
}

sparse_status sparse_extract_sparse_row_double_complex(sparse_matrix_double_complex A, sparse_index row,
                                                       sparse_index column_start, sparse_index *column_end,
                                                       sparse_dimension nz, double _Complex *__restrict val,
                                                       sparse_index *__restrict jndx)
{
    return (sparse_status)RevenantSparseExtractRowComplex(A, REVENANT_SPARSE_MAGIC_DOUBLE_COMPLEX, row, column_start,
                                                        column_end, nz, val, jndx, sizeof(double _Complex));
}

static long RevenantSparseExtractColumnComplex(void *matrix, uint32_t magic, sparse_index column, sparse_index rowStart,
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
            double re = 0.0, im = 0.0;
            RevenantSparseReadComplexValue(source->value, at, size, &re, &im);
            RevenantSparseWriteComplexValue(val, written, re, im, size);
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

sparse_status sparse_extract_sparse_column_float_complex(sparse_matrix_float_complex A, sparse_index column,
                                                         sparse_index row_start, sparse_index *row_end,
                                                         sparse_dimension nz, float _Complex *__restrict val,
                                                         sparse_index *__restrict indx)
{
    return (sparse_status)RevenantSparseExtractColumnComplex(A, REVENANT_SPARSE_MAGIC_FLOAT_COMPLEX, column, row_start,
                                                          row_end, nz, val, indx, sizeof(float _Complex));
}

sparse_status sparse_extract_sparse_column_double_complex(sparse_matrix_double_complex A, sparse_index column,
                                                          sparse_index row_start, sparse_index *row_end,
                                                          sparse_dimension nz, double _Complex *__restrict val,
                                                          sparse_index *__restrict indx)
{
    return (sparse_status)RevenantSparseExtractColumnComplex(A, REVENANT_SPARSE_MAGIC_DOUBLE_COMPLEX, column, row_start,
                                                          row_end, nz, val, indx, sizeof(double _Complex));
}

static sparse_status RevenantSparseExtractBlockComplex(void *matrix, uint32_t magic, sparse_index bi, sparse_index bj,
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
            double re = 0.0, im = 0.0;
            RevenantSparseElementComplexAt(&asFloat->row[first + i], left + j, size, &re, &im);
            RevenantSparseWriteComplexValue(val, (sparse_index)(i * rowStride + j * colStride), re, im, size);
        }
    }
    return SPARSE_SUCCESS;
}

sparse_status sparse_extract_block_float_complex(sparse_matrix_float_complex A, sparse_index bi, sparse_index bj,
                                                 sparse_dimension row_stride, sparse_dimension col_stride,
                                                 float _Complex *__restrict val)
{
    return RevenantSparseExtractBlockComplex(A, REVENANT_SPARSE_MAGIC_FLOAT_COMPLEX, bi, bj, row_stride, col_stride, val,
                                           sizeof(float _Complex));
}

sparse_status sparse_extract_block_double_complex(sparse_matrix_double_complex A, sparse_index bi, sparse_index bj,
                                                  sparse_dimension row_stride, sparse_dimension col_stride,
                                                  double _Complex *__restrict val)
{
    return RevenantSparseExtractBlockComplex(A, REVENANT_SPARSE_MAGIC_DOUBLE_COMPLEX, bi, bj, row_stride, col_stride, val,
                                           sizeof(double _Complex));
}

static RevenantComplex RevenantSparseInnerDenseComplex(sparse_dimension nz, const void *x, const sparse_index *indx,
                                                   const void *y, sparse_stride incy, size_t size)
{
    RevenantComplex sum = RevenantComplexMake(0.0, 0.0);
    if (nz == 0) {
        return sum;
    }
    for (sparse_dimension k = 0; k < nz; k++) {
        double xre = 0.0, xim = 0.0, yre = 0.0, yim = 0.0;
        RevenantSparseReadComplexValue(x, k, size, &xre, &xim);
        RevenantSparseReadComplexValue(y, (sparse_index)(indx[k] * incy), size, &yre, &yim);
        sum = RevenantComplexAdd(sum, RevenantComplexMul(RevenantComplexMake(xre, xim), RevenantComplexMake(yre, yim)));
    }
    return sum;
}

float _Complex sparse_inner_product_dense_float_complex(sparse_dimension nz, const float _Complex *__restrict x,
                                                        const sparse_index *__restrict indx,
                                                        const float _Complex *__restrict y, sparse_stride incy)
{
    RevenantComplex sum = RevenantSparseInnerDenseComplex(nz, x, indx, y, incy, sizeof(float _Complex));
    return RevenantComplexAsFloat(sum);
}

double _Complex sparse_inner_product_dense_double_complex(sparse_dimension nz, const double _Complex *__restrict x,
                                                          const sparse_index *__restrict indx,
                                                          const double _Complex *__restrict y, sparse_stride incy)
{
    RevenantComplex sum = RevenantSparseInnerDenseComplex(nz, x, indx, y, incy, sizeof(double _Complex));
    return RevenantComplexAsDouble(sum);
}

static RevenantComplex RevenantSparseInnerSparseComplex(sparse_dimension nzx, sparse_dimension nzy, const void *x,
                                                    const sparse_index *indx, const void *y, const sparse_index *indy,
                                                    size_t size)
{
    RevenantComplex sum = RevenantComplexMake(0.0, 0.0);
    if (nzx == 0 || nzy == 0) {
        return sum;
    }
    sparse_dimension i = 0, j = 0;
    while (i < nzx && j < nzy) {
        if (indx[i] < indy[j]) {
            i++;
        } else if (indx[i] > indy[j]) {
            j++;
        } else {
            double lre = 0.0, lim = 0.0, rre = 0.0, rim = 0.0;
            RevenantSparseReadComplexValue(x, i, size, &lre, &lim);
            RevenantSparseReadComplexValue(y, j, size, &rre, &rim);
            sum = RevenantComplexAdd(sum, RevenantComplexMul(RevenantComplexMake(lre, lim), RevenantComplexMake(rre, rim)));
            i++;
            j++;
        }
    }
    return sum;
}

float _Complex sparse_inner_product_sparse_float_complex(sparse_dimension nzx, sparse_dimension nzy,
                                                          const float _Complex *__restrict x,
                                                          const sparse_index *__restrict indx,
                                                          const float _Complex *__restrict y,
                                                          const sparse_index *__restrict indy)
{
    RevenantComplex sum = RevenantSparseInnerSparseComplex(nzx, nzy, x, indx, y, indy, sizeof(float _Complex));
    return RevenantComplexAsFloat(sum);
}

double _Complex sparse_inner_product_sparse_double_complex(sparse_dimension nzx, sparse_dimension nzy,
                                                            const double _Complex *__restrict x,
                                                            const sparse_index *__restrict indx,
                                                            const double _Complex *__restrict y,
                                                            const sparse_index *__restrict indy)
{
    RevenantComplex sum = RevenantSparseInnerSparseComplex(nzx, nzy, x, indx, y, indy, sizeof(double _Complex));
    return RevenantComplexAsDouble(sum);
}

static void RevenantSparseAddScaleComplex(sparse_dimension nz, RevenantComplex alpha, const void *x, const sparse_index *indx,
                                        void *y, sparse_stride incy, size_t size)
{
    if (nz == 0 || RevenantComplexIsZero(alpha)) {
        return;
    }
    for (sparse_dimension k = 0; k < nz; k++) {
        double re = 0.0, im = 0.0;
        RevenantSparseReadComplexValue(x, k, size, &re, &im);
        sparse_index at = (sparse_index)(indx[k] * incy);
        double yre = 0.0, yim = 0.0;
        RevenantSparseReadComplexValue(y, at, size, &yre, &yim);
        RevenantComplex sum = RevenantComplexAdd(RevenantComplexMake(yre, yim),
                                             RevenantComplexMul(alpha, RevenantComplexMake(re, im)));
        RevenantSparseWriteComplexValue(y, at, sum.re, sum.im, size);
    }
}

void sparse_vector_add_with_scale_dense_float_complex(sparse_dimension nz, float _Complex alpha,
                                                      const float _Complex *__restrict x,
                                                      const sparse_index *__restrict indx,
                                                      float _Complex *__restrict y, sparse_stride incy)
{
    RevenantSparseAddScaleComplex(nz, RevenantComplexMake(__real__ alpha, __imag__ alpha), x, indx, y, incy,
                                sizeof(float _Complex));
}

void sparse_vector_add_with_scale_dense_double_complex(sparse_dimension nz, double _Complex alpha,
                                                       const double _Complex *__restrict x,
                                                       const sparse_index *__restrict indx,
                                                       double _Complex *__restrict y, sparse_stride incy)
{
    RevenantSparseAddScaleComplex(nz, RevenantComplexMake(__real__ alpha, __imag__ alpha), x, indx, y, incy,
                                sizeof(double _Complex));
}

static double RevenantSparseVectorNormComplex(sparse_dimension nz, const void *x, const sparse_index *indx, sparse_norm norm,
                                            size_t size)
{
    if (nz == 0) {
        return 0.0;
    }
    if (norm == SPARSE_NORM_ONE) {
        double sum = 0.0;
        for (sparse_dimension k = 0; k < nz; k++) {
            double re = 0.0, im = 0.0;
            RevenantSparseReadComplexValue(x, k, size, &re, &im);
            sum += RevenantComplexPartSum(RevenantComplexMake(re, im));
        }
        return sum;
    }
    if (norm == SPARSE_NORM_TWO || norm == SPARSE_NORM_R1) {
        double sum = 0.0;
        for (sparse_dimension k = 0; k < nz; k++) {
            double re = 0.0, im = 0.0;
            RevenantSparseReadComplexValue(x, k, size, &re, &im);
            double magnitude = RevenantComplexModulus(RevenantComplexMake(re, im));
            sum += magnitude * magnitude;
        }
        return sqrt(sum);
    }
    double largest = 0.0;
    for (sparse_dimension k = 0; k < nz; k++) {
        double re = 0.0, im = 0.0;
        RevenantSparseReadComplexValue(x, k, size, &re, &im);
        double magnitude = RevenantComplexModulus(RevenantComplexMake(re, im));
        if (magnitude > largest) {
            largest = magnitude;
        }
    }
    return largest;
}

float sparse_vector_norm_float_complex(sparse_dimension nz, const float _Complex *__restrict x,
                                       const sparse_index *__restrict indx, sparse_norm norm)
{
    return (float)RevenantSparseVectorNormComplex(nz, x, indx, norm, sizeof(float _Complex));
}

double sparse_vector_norm_double_complex(sparse_dimension nz, const double _Complex *__restrict x,
                                         const sparse_index *__restrict indx, sparse_norm norm)
{
    return RevenantSparseVectorNormComplex(nz, x, indx, norm, sizeof(double _Complex));
}

static long RevenantSparseVectorNonzeroComplex(sparse_dimension N, const void *x, sparse_stride incx, size_t size)
{
    if (N == 0) {
        return 0;
    }
    long count = 0;
    for (sparse_dimension i = 0; i < N; i++) {
        double re = 0.0, im = 0.0;
        RevenantSparseReadComplexValue(x, (sparse_index)(i * incx), size, &re, &im);
        if (!RevenantComplexIsZero(RevenantComplexMake(re, im))) {
            count++;
        }
    }
    return count;
}

long sparse_get_vector_nonzero_count_float_complex(sparse_dimension N, const float _Complex *__restrict x,
                                                   sparse_stride incx)
{
    return RevenantSparseVectorNonzeroComplex(N, x, incx, sizeof(float _Complex));
}

long sparse_get_vector_nonzero_count_double_complex(sparse_dimension N, const double _Complex *__restrict x,
                                                    sparse_stride incx)
{
    return RevenantSparseVectorNonzeroComplex(N, x, incx, sizeof(double _Complex));
}

static long RevenantSparsePackComplex(sparse_dimension N, sparse_dimension nz, const void *x, sparse_stride incx, void *y,
                                     sparse_index *indy, size_t size)
{
    if (N == 0 || nz == 0) {
        return 0;
    }
    long written = 0;
    for (sparse_dimension i = 0; i < N && (sparse_dimension)written < nz; i++) {
        double re = 0.0, im = 0.0;
        RevenantSparseReadComplexValue(x, (sparse_index)(i * incx), size, &re, &im);
        if (RevenantComplexIsZero(RevenantComplexMake(re, im))) {
            continue;
        }
        if (y) {
            RevenantSparseWriteComplexValue(y, written, re, im, size);
        }
        if (indy) {
            indy[written] = (sparse_index)i;
        }
        written++;
    }
    return written;
}

long sparse_pack_vector_float_complex(sparse_dimension N, sparse_dimension nz, const float _Complex *__restrict x,
                                      sparse_stride incx, float _Complex *__restrict y, sparse_index *__restrict indy)
{
    return RevenantSparsePackComplex(N, nz, x, incx, y, indy, sizeof(float _Complex));
}

long sparse_pack_vector_double_complex(sparse_dimension N, sparse_dimension nz, const double _Complex *__restrict x,
                                       sparse_stride incx, double _Complex *__restrict y, sparse_index *__restrict indy)
{
    return RevenantSparsePackComplex(N, nz, x, incx, y, indy, sizeof(double _Complex));
}

static void RevenantSparseUnpackComplex(sparse_dimension N, sparse_dimension nz, bool zero, const void *x,
                                      const sparse_index *indx, void *y, sparse_stride incy, size_t size)
{
    if (zero) {
        for (sparse_dimension i = 0; i < N; i++) {
            RevenantSparseWriteComplexValue(y, (sparse_index)(i * incy), 0.0, 0.0, size);
        }
    }
    for (sparse_dimension k = 0; k < nz; k++) {
        if (indx[k] < 0 || indx[k] >= (sparse_index)N) {
            continue;
        }
        double re = 0.0, im = 0.0;
        RevenantSparseReadComplexValue(x, k, size, &re, &im);
        RevenantSparseWriteComplexValue(y, (sparse_index)(indx[k] * incy), re, im, size);
    }
}

void sparse_unpack_vector_float_complex(sparse_dimension N, sparse_dimension nz, bool zero,
                                        const float _Complex *__restrict x, const sparse_index *__restrict indx,
                                        float _Complex *__restrict y, sparse_stride incy)
{
    RevenantSparseUnpackComplex(N, nz, zero, x, indx, y, incy, sizeof(float _Complex));
}

void sparse_unpack_vector_double_complex(sparse_dimension N, sparse_dimension nz, bool zero,
                                         const double _Complex *__restrict x, const sparse_index *__restrict indx,
                                         double _Complex *__restrict y, sparse_stride incy)
{
    RevenantSparseUnpackComplex(N, nz, zero, x, indx, y, incy, sizeof(double _Complex));
}

static void RevenantComplexAxpy(long n, RevenantComplex alpha, const void *x, long from, long incX, void *y, long to,
                              long incY, size_t size)
{
    if (size == sizeof(float _Complex)) {
        float pair[2];
        pair[0] = (float)alpha.re;
        pair[1] = (float)alpha.im;
        cblas_caxpy((int)n, pair, (const float *)x + from * 2, (int)incX, (float *)y + to * 2, (int)incY);
    } else {
        double pair[2];
        pair[0] = alpha.re;
        pair[1] = alpha.im;
        cblas_zaxpy((int)n, pair, (const double *)x + from * 2, (int)incX, (double *)y + to * 2, (int)incY);
    }
}

static void RevenantComplexCopy(long n, const void *b, long from, long inc, void *row, size_t size)
{
    if (size == sizeof(float _Complex)) {
        cblas_ccopy((int)n, (const float *)b + from * 2, (int)inc, row, 1);
    } else {
        cblas_zcopy((int)n, (const double *)b + from * 2, (int)inc, row, 1);
    }
}

static sparse_status RevenantSparseVectorProductComplex(void *matrix, uint32_t magic, int transposed, RevenantComplex alpha,
                                                      const void *x, sparse_stride incx, void *y, sparse_stride incy,
                                                      size_t size)
{
    if (!RevenantSparseIsMatrix(matrix, magic)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    const struct sparse_m_float *asFloat = (const struct sparse_m_float *)matrix;
    sparse_dimension inner = transposed ? asFloat->rows : asFloat->columns;
    sparse_dimension outer = transposed ? asFloat->columns : asFloat->rows;
    for (sparse_dimension i = 0; i < outer; i++) {
        for (sparse_dimension k = 0; k < inner; k++) {
            double re = 0.0, im = 0.0;
            RevenantSparseElementComplexAt(&asFloat->row[transposed ? k : i], transposed ? i : k, size, &re, &im);
            if (RevenantComplexIsZero(RevenantComplexMake(re, im))) {
                continue;
            }
            RevenantComplexAxpy(1, RevenantComplexMul(alpha, RevenantComplexMake(re, im)), x, (long)(k * incx), 1, y,
                              (long)(i * incy), 1, size);
        }
    }
    return SPARSE_SUCCESS;
}

sparse_status sparse_matrix_vector_product_dense_float_complex(enum CBLAS_TRANSPOSE transa, float _Complex alpha,
                                                               sparse_matrix_float_complex A,
                                                               const float _Complex *__restrict x, sparse_stride incx,
                                                               float _Complex *__restrict y, sparse_stride incy)
{
    if (transa != CblasNoTrans && transa != CblasTrans) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    return RevenantSparseVectorProductComplex(A, REVENANT_SPARSE_MAGIC_FLOAT_COMPLEX, transa == CblasTrans,
                                           RevenantComplexMake(__real__ alpha, __imag__ alpha), x, incx, y, incy,
                                           sizeof(float _Complex));
}

sparse_status sparse_matrix_vector_product_dense_double_complex(enum CBLAS_TRANSPOSE transa, double _Complex alpha,
                                                                sparse_matrix_double_complex A,
                                                                const double _Complex *__restrict x, sparse_stride incx,
                                                                double _Complex *__restrict y, sparse_stride incy)
{
    if (transa != CblasNoTrans && transa != CblasTrans) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    return RevenantSparseVectorProductComplex(A, REVENANT_SPARSE_MAGIC_DOUBLE_COMPLEX, transa == CblasTrans,
                                           RevenantComplexMake(__real__ alpha, __imag__ alpha), x, incx, y, incy,
                                           sizeof(double _Complex));
}

static sparse_status RevenantSparseTriangularComplex(void *matrix, uint32_t magic, int transposed, RevenantComplex alpha,
                                                   void *b, long iStep, long rightStep, sparse_dimension nrhs, size_t size)
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
            double re = 0.0, im = 0.0;
            RevenantSparseReadComplexValue(b, (sparse_index)here, size, &re, &im);
            RevenantComplex value = RevenantComplexDiv(RevenantComplexMake(re, im), alpha);
            if (!transposed) {
                for (sparse_index at = 0; at < asFloat->row[i].count; at++) {
                    sparse_index j = asFloat->row[i].column[at];
                    if (j == (sparse_index)i || (j < (sparse_index)i) == backwards) {
                        continue;
                    }
                    double otherRe = 0.0, otherIm = 0.0;
                    RevenantSparseReadComplexValue(asFloat->row[i].value, at, size, &otherRe, &otherIm);
                    double addRe = 0.0, addIm = 0.0;
                    RevenantSparseReadComplexValue(b, (sparse_index)((long)j * iStep + (long)right * rightStep), size, &addRe,
                                                 &addIm);
                    value = RevenantComplexSub(value, RevenantComplexMul(RevenantComplexMake(otherRe, otherIm),
                                                                    RevenantComplexMake(addRe, addIm)));
                }
            } else {
                sparse_index from = offsets[i], to = offsets[i + 1];
                for (sparse_index k = from; k < to; k++) {
                    sparse_index j = lists[k];
                    if (j == (sparse_index)i || (j < (sparse_index)i) == backwards) {
                        continue;
                    }
                    double otherRe = 0.0, otherIm = 0.0;
                    RevenantSparseElementComplexAt(&asFloat->row[j], (sparse_index)i, size, &otherRe, &otherIm);
                    double addRe = 0.0, addIm = 0.0;
                    RevenantSparseReadComplexValue(b, (sparse_index)((long)j * iStep + (long)right * rightStep), size, &addRe,
                                                 &addIm);
                    value = RevenantComplexSub(value, RevenantComplexMul(RevenantComplexMake(otherRe, otherIm),
                                                                    RevenantComplexMake(addRe, addIm)));
                }
            }
            double pivotRe = 0.0, pivotIm = 0.0;
            RevenantSparseElementComplexAt(&asFloat->row[i], i, size, &pivotRe, &pivotIm);
            RevenantComplex solved = RevenantComplexDiv(value, RevenantComplexMake(pivotRe, pivotIm));
            RevenantSparseWriteComplexValue(b, (sparse_index)here, solved.re, solved.im, size);
        }
    }
    free(lists);
    free(offsets);
    return SPARSE_SUCCESS;
}

sparse_status sparse_vector_triangular_solve_dense_float_complex(enum CBLAS_TRANSPOSE transt, float _Complex alpha,
                                                                 sparse_matrix_float_complex T,
                                                                 float _Complex *__restrict x, sparse_stride incx)
{
    if (transt != CblasNoTrans && transt != CblasTrans) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    return RevenantSparseTriangularComplex(T, REVENANT_SPARSE_MAGIC_FLOAT_COMPLEX, transt == CblasTrans,
                                        RevenantComplexMake(__real__ alpha, __imag__ alpha), x, incx, 0, 1,
                                        sizeof(float _Complex));
}

sparse_status sparse_vector_triangular_solve_dense_double_complex(enum CBLAS_TRANSPOSE transt, double _Complex alpha,
                                                                  sparse_matrix_double_complex T,
                                                                  double _Complex *__restrict x, sparse_stride incx)
{
    if (transt != CblasNoTrans && transt != CblasTrans) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    return RevenantSparseTriangularComplex(T, REVENANT_SPARSE_MAGIC_DOUBLE_COMPLEX, transt == CblasTrans,
                                        RevenantComplexMake(__real__ alpha, __imag__ alpha), x, incx, 0, 1,
                                        sizeof(double _Complex));
}

sparse_status sparse_matrix_triangular_solve_dense_float_complex(enum CBLAS_ORDER order, enum CBLAS_TRANSPOSE transt,
                                                                 sparse_dimension nrhs, float _Complex alpha,
                                                                 sparse_matrix_float_complex T,
                                                                 float _Complex *__restrict B, sparse_dimension ldb)
{
    if (order != CblasRowMajor && order != CblasColMajor) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    if (transt != CblasNoTrans && transt != CblasTrans) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    if (!RevenantSparseIsFloatComplex(T)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    const struct sparse_m_float *asFloat = (const struct sparse_m_float *)T;
    sparse_dimension needed = order == CblasRowMajor ? (nrhs ? nrhs : 1) : (asFloat->rows ? asFloat->rows : 1);
    if (ldb < needed) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    return RevenantSparseTriangularComplex(T, REVENANT_SPARSE_MAGIC_FLOAT_COMPLEX, transt == CblasTrans,
                                        RevenantComplexMake(__real__ alpha, __imag__ alpha), B,
                                        order == CblasRowMajor ? (long)ldb : 1, order == CblasRowMajor ? 1 : (long)ldb,
                                        nrhs, sizeof(float _Complex));
}

sparse_status sparse_matrix_triangular_solve_dense_double_complex(enum CBLAS_ORDER order, enum CBLAS_TRANSPOSE transt,
                                                                  sparse_dimension nrhs, double _Complex alpha,
                                                                  sparse_matrix_double_complex T,
                                                                  double _Complex *__restrict B, sparse_dimension ldb)
{
    if (order != CblasRowMajor && order != CblasColMajor) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    if (transt != CblasNoTrans && transt != CblasTrans) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    if (!RevenantSparseIsDoubleComplex(T)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    const struct sparse_m_float *asFloat = (const struct sparse_m_float *)T;
    sparse_dimension needed = order == CblasRowMajor ? (nrhs ? nrhs : 1) : (asFloat->rows ? asFloat->rows : 1);
    if (ldb < needed) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    return RevenantSparseTriangularComplex(T, REVENANT_SPARSE_MAGIC_DOUBLE_COMPLEX, transt == CblasTrans,
                                        RevenantComplexMake(__real__ alpha, __imag__ alpha), B,
                                        order == CblasRowMajor ? (long)ldb : 1, order == CblasRowMajor ? 1 : (long)ldb,
                                        nrhs, sizeof(double _Complex));
}

static sparse_status RevenantSparseProductDenseComplex(void *matrix, uint32_t magic, int order, int transposed,
                                                      sparse_dimension n, RevenantComplex alpha, const void *B,
                                                      sparse_dimension ldb, void *C, sparse_dimension ldc, size_t size)
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
    if (n == 0 || RevenantComplexIsZero(alpha)) {
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
            double re = 0.0, im = 0.0;
            RevenantSparseElementComplexAt(&asFloat->row[r], c, size, &re, &im);
            if (RevenantComplexIsZero(RevenantComplexMake(re, im))) {
                continue;
            }
            long from = RevenantSparseDenseAt(order, ldb, transposed ? r : c, 0);
            long to = RevenantSparseDenseAt(order, ldc, i, 0);
            RevenantComplexCopy((long)n, B, from, (long)bStep, row, size);
            RevenantComplexAxpy((long)n, RevenantComplexMul(alpha, RevenantComplexMake(re, im)), row, 0, 1, C, to,
                              (long)cStep, size);
        }
    }
    free(row);
    return SPARSE_SUCCESS;
}

sparse_status sparse_matrix_product_dense_float_complex(enum CBLAS_ORDER order, enum CBLAS_TRANSPOSE transa,
                                                        sparse_dimension n, float _Complex alpha,
                                                        sparse_matrix_float_complex A,
                                                        const float _Complex *__restrict B, sparse_dimension ldb,
                                                        float _Complex *__restrict C, sparse_dimension ldc)
{
    if (transa != CblasNoTrans && transa != CblasTrans) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    return RevenantSparseProductDenseComplex(A, REVENANT_SPARSE_MAGIC_FLOAT_COMPLEX, order, transa == CblasTrans, n,
                                           RevenantComplexMake(__real__ alpha, __imag__ alpha), B, ldb, C, ldc,
                                           sizeof(float _Complex));
}

sparse_status sparse_matrix_product_dense_double_complex(enum CBLAS_ORDER order, enum CBLAS_TRANSPOSE transa,
                                                         sparse_dimension n, double _Complex alpha,
                                                         sparse_matrix_double_complex A,
                                                         const double _Complex *__restrict B, sparse_dimension ldb,
                                                         double _Complex *__restrict C, sparse_dimension ldc)
{
    if (transa != CblasNoTrans && transa != CblasTrans) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    return RevenantSparseProductDenseComplex(A, REVENANT_SPARSE_MAGIC_DOUBLE_COMPLEX, order, transa == CblasTrans, n,
                                           RevenantComplexMake(__real__ alpha, __imag__ alpha), B, ldb, C, ldc,
                                           sizeof(double _Complex));
}

static sparse_status RevenantSparseOuterComplex(sparse_dimension M, sparse_dimension N, sparse_dimension nz,
                                               RevenantComplex alpha, const void *x, sparse_stride incx, const void *y,
                                               const sparse_index *indy, void **C, uint32_t magic, size_t size,
                                               size_t matrixSize)
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
        double rightRe = 0.0, rightIm = 0.0;
        RevenantSparseReadComplexValue(y, k, size, &rightRe, &rightIm);
        if (RevenantComplexIsZero(alpha) || RevenantComplexIsZero(RevenantComplexMake(rightRe, rightIm))) {
            continue;
        }
        for (sparse_dimension i = 0; i < M; i++) {
            double leftRe = 0.0, leftIm = 0.0;
            RevenantSparseReadComplexValue(x, (sparse_index)(i * incx), size, &leftRe, &leftIm);
            RevenantComplex scaled = RevenantComplexMul(alpha, RevenantComplexMul(RevenantComplexMake(leftRe, leftIm),
                                                                             RevenantComplexMake(rightRe, rightIm)));
            if (RevenantComplexIsZero(scaled)) {
                continue;
            }
            sparse_index before = asFloat->row[i].count;
            RevenantSparsePutComplex(&asFloat->row[i], indy[k], scaled.re, scaled.im, size);
            asFloat->nonzero += (long)asFloat->row[i].count - (long)before;
        }
    }
    *C = matrix;
    return SPARSE_SUCCESS;
}

sparse_status sparse_outer_product_dense_float_complex(sparse_dimension M, sparse_dimension N, sparse_dimension nz,
                                                       float _Complex alpha, const float _Complex *__restrict x,
                                                       sparse_stride incx, const float _Complex *__restrict y,
                                                       const sparse_index *__restrict indy,
                                                       sparse_matrix_float_complex *__restrict C)
{
    return RevenantSparseOuterComplex(M, N, nz, RevenantComplexMake(__real__ alpha, __imag__ alpha), x, incx, y, indy,
                                    (void **)C, REVENANT_SPARSE_MAGIC_FLOAT_COMPLEX, sizeof(float _Complex),
                                    sizeof(struct sparse_m_float_complex));
}

sparse_status sparse_outer_product_dense_double_complex(sparse_dimension M, sparse_dimension N, sparse_dimension nz,
                                                        double _Complex alpha, const double _Complex *__restrict x,
                                                        sparse_stride incx, const double _Complex *__restrict y,
                                                        const sparse_index *__restrict indy,
                                                        sparse_matrix_double_complex *__restrict C)
{
    return RevenantSparseOuterComplex(M, N, nz, RevenantComplexMake(__real__ alpha, __imag__ alpha), x, incx, y, indy,
                                    (void **)C, REVENANT_SPARSE_MAGIC_DOUBLE_COMPLEX, sizeof(double _Complex),
                                    sizeof(struct sparse_m_double_complex));
}

static sparse_status RevenantSparseProductSparseComplex(void *A, uint32_t magicA, int order, int transposed,
                                                      RevenantComplex alpha, void *B, uint32_t magicB, void *C,
                                                      sparse_dimension ldc, size_t size)
{
    if (order != CblasRowMajor && order != CblasColMajor) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    if (!RevenantSparseIsMatrix(A, magicA) || !RevenantSparseIsMatrix(B, magicB)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    const struct sparse_m_float *asA = (const struct sparse_m_float *)A;
    const struct sparse_m_float *asB = (const struct sparse_m_float *)B;
    sparse_dimension m = transposed ? asA->columns : asA->rows;
    sparse_dimension k = transposed ? asA->rows : asA->columns;
    sparse_dimension n = asB->columns;
    if (k != asB->rows) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    if (ldc < (order == CblasRowMajor ? (n ? n : 1) : (m ? m : 1))) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    sparse_dimension cStep = order == CblasRowMajor ? 1 : ldc;
    void *row = calloc(n ? n : 1, size);
    if (!row) {
        return SPARSE_SYSTEM_ERROR;
    }
    for (sparse_dimension i = 0; i < m; i++) {
        const RevenantSparseRow *line = transposed ? NULL : &asA->row[i];
        for (sparse_index at = 0; at < (transposed ? (sparse_index)asA->rows : line->count); at++) {
            sparse_index r = transposed ? at : (sparse_index)i;
            sparse_index c = transposed ? (sparse_index)i : line->column[at];
            if (c >= (sparse_index)asA->columns) {
                continue;
            }
            double valueRe = 0.0, valueIm = 0.0;
            RevenantSparseElementComplexAt(&asA->row[r], c, size, &valueRe, &valueIm);
            if (RevenantComplexIsZero(RevenantComplexMake(valueRe, valueIm))) {
                continue;
            }
            memset(row, 0, (size_t)(n ? n : 1) * size);
            const RevenantSparseRow *from = &asB->row[transposed ? r : c];
            for (sparse_index b = 0; b < from->count; b++) {
                if (from->column[b] < (sparse_index)n) {
                    double bre = 0.0, bim = 0.0;
                    RevenantSparseReadComplexValue(from->value, b, size, &bre, &bim);
                    RevenantSparseWriteComplexValue(row, from->column[b], bre, bim, size);
                }
            }
            long to = RevenantSparseDenseAt(order, ldc, i, 0);
            for (sparse_dimension j = 0; j < n; j++) {
                double re = 0.0, im = 0.0;
                RevenantSparseReadComplexValue(row, j, size, &re, &im);
                if (RevenantComplexIsZero(RevenantComplexMake(re, im))) {
                    continue;
                }
                RevenantComplexAxpy(1, RevenantComplexMul(alpha, RevenantComplexMake(valueRe, valueIm)), row, j, 1, C,
                                  to + (long)(j * cStep), 1, size);
            }
        }
    }
    free(row);
    return SPARSE_SUCCESS;
}

sparse_status sparse_matrix_product_sparse_float_complex(enum CBLAS_ORDER order, enum CBLAS_TRANSPOSE transa,
                                                         float _Complex alpha, sparse_matrix_float_complex A,
                                                         sparse_matrix_float_complex B, float _Complex *__restrict C,
                                                         sparse_dimension ldc)
{
    if (transa != CblasNoTrans && transa != CblasTrans) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    return RevenantSparseProductSparseComplex(A, REVENANT_SPARSE_MAGIC_FLOAT_COMPLEX, order, transa == CblasTrans,
                                           RevenantComplexMake(__real__ alpha, __imag__ alpha), B,
                                           REVENANT_SPARSE_MAGIC_FLOAT_COMPLEX, C, ldc, sizeof(float _Complex));
}

sparse_status sparse_matrix_product_sparse_double_complex(enum CBLAS_ORDER order, enum CBLAS_TRANSPOSE transa,
                                                          double _Complex alpha, sparse_matrix_double_complex A,
                                                          sparse_matrix_double_complex B, double _Complex *__restrict C,
                                                          sparse_dimension ldc)
{
    if (transa != CblasNoTrans && transa != CblasTrans) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    return RevenantSparseProductSparseComplex(A, REVENANT_SPARSE_MAGIC_DOUBLE_COMPLEX, order, transa == CblasTrans,
                                           RevenantComplexMake(__real__ alpha, __imag__ alpha), B,
                                           REVENANT_SPARSE_MAGIC_DOUBLE_COMPLEX, C, ldc, sizeof(double _Complex));
}

sparse_status sparse_permute_rows_float_complex(sparse_matrix_float_complex A, const sparse_index *__restrict perm)
{
    if (!RevenantSparseIsFloatComplex(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    RevenantSparsePermuteRows((struct sparse_m_float *)A, perm);
    return SPARSE_SUCCESS;
}

sparse_status sparse_permute_rows_double_complex(sparse_matrix_double_complex A, const sparse_index *__restrict perm)
{
    if (!RevenantSparseIsDoubleComplex(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    RevenantSparsePermuteRows((struct sparse_m_float *)A, perm);
    return SPARSE_SUCCESS;
}

sparse_status sparse_permute_cols_float_complex(sparse_matrix_float_complex A, const sparse_index *__restrict perm)
{
    if (!RevenantSparseIsFloatComplex(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    RevenantSparsePermuteColumnsComplex((struct sparse_m_float *)A, perm, sizeof(float _Complex));
    return SPARSE_SUCCESS;
}

sparse_status sparse_permute_cols_double_complex(sparse_matrix_double_complex A, const sparse_index *__restrict perm)
{
    if (!RevenantSparseIsDoubleComplex(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    RevenantSparsePermuteColumnsComplex((struct sparse_m_float *)A, perm, sizeof(double _Complex));
    return SPARSE_SUCCESS;
}

static double RevenantSparseElementwiseComplex(void *matrix, uint32_t magic, sparse_norm norm, size_t size)
{
    if (!RevenantSparseIsMatrix(matrix, magic)) {
        return 0.0;
    }
    const struct sparse_m_float *asFloat = (const struct sparse_m_float *)matrix;
    if (norm == SPARSE_NORM_ONE) {
        double sum = 0.0;
        for (sparse_dimension i = 0; i < asFloat->rows; i++) {
            for (sparse_index at = 0; at < asFloat->row[i].count; at++) {
                double re = 0.0, im = 0.0;
                RevenantSparseReadComplexValue(asFloat->row[i].value, at, size, &re, &im);
                sum += RevenantComplexPartSum(RevenantComplexMake(re, im));
            }
        }
        return sum;
    }
    if (norm == SPARSE_NORM_TWO) {
        double sum = 0.0;
        for (sparse_dimension i = 0; i < asFloat->rows; i++) {
            for (sparse_index at = 0; at < asFloat->row[i].count; at++) {
                double re = 0.0, im = 0.0;
                RevenantSparseReadComplexValue(asFloat->row[i].value, at, size, &re, &im);
                double magnitude = RevenantComplexModulus(RevenantComplexMake(re, im));
                sum += magnitude * magnitude;
            }
        }
        return sqrt(sum);
    }
    if (norm == SPARSE_NORM_R1) {
        double total = 0.0;
        for (sparse_index j = 0; j < (sparse_index)asFloat->columns; j++) {
            double sum = 0.0;
            for (sparse_dimension i = 0; i < asFloat->rows; i++) {
                double re = 0.0, im = 0.0;
                RevenantSparseElementComplexAt(&asFloat->row[i], j, size, &re, &im);
                double magnitude = RevenantComplexModulus(RevenantComplexMake(re, im));
                sum += magnitude * magnitude;
            }
            total += sqrt(sum);
        }
        return total;
    }
    double largest = 0.0;
    for (sparse_dimension i = 0; i < asFloat->rows; i++) {
        for (sparse_index at = 0; at < asFloat->row[i].count; at++) {
            double re = 0.0, im = 0.0;
            RevenantSparseReadComplexValue(asFloat->row[i].value, at, size, &re, &im);
            double magnitude = RevenantComplexModulus(RevenantComplexMake(re, im));
            if (magnitude > largest) {
                largest = magnitude;
            }
        }
    }
    return largest;
}

float sparse_elementwise_norm_float_complex(sparse_matrix_float_complex A, sparse_norm norm)
{
    return (float)RevenantSparseElementwiseComplex(A, REVENANT_SPARSE_MAGIC_FLOAT_COMPLEX, norm, sizeof(float _Complex));
}

double sparse_elementwise_norm_double_complex(sparse_matrix_double_complex A, sparse_norm norm)
{
    return RevenantSparseElementwiseComplex(A, REVENANT_SPARSE_MAGIC_DOUBLE_COMPLEX, norm, sizeof(double _Complex));
}

static double RevenantSparseOperatorComplex(void *matrix, uint32_t magic, sparse_norm norm, size_t size)
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
                double re = 0.0, im = 0.0;
                RevenantSparseElementComplexAt(&asFloat->row[i], j, size, &re, &im);
                sum += RevenantComplexPartSum(RevenantComplexMake(re, im));
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
                double re = 0.0, im = 0.0;
                RevenantSparseReadComplexValue(asFloat->row[i].value, at, size, &re, &im);
                sum += RevenantComplexPartSum(RevenantComplexMake(re, im));
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
    if (size == sizeof(float _Complex)) {
        __CLPK_complex *gram = (__CLPK_complex *)calloc((size_t)m * m, sizeof(__CLPK_complex));
        if (!gram) {
            return 0.0;
        }
        for (sparse_dimension i = 0; i < m; i++) {
            for (sparse_dimension k = 0; k < m; k++) {
                RevenantComplex sum = RevenantComplexMake(0.0, 0.0);
                for (sparse_index at = 0; at < asFloat->row[i].count; at++) {
                    sparse_index j = asFloat->row[i].column[at];
                    double re = 0.0, im = 0.0;
                    RevenantSparseReadComplexValue(asFloat->row[i].value, at, size, &re, &im);
                    double otherRe = 0.0, otherIm = 0.0;
                    RevenantSparseElementComplexAt(&asFloat->row[k], j, size, &otherRe, &otherIm);
                    sum = RevenantComplexAdd(sum, RevenantComplexMul(RevenantComplexMake(re, im),
                                                                 RevenantComplexMake(otherRe, -otherIm)));
                }
                gram[i * m + k].r = (float)sum.re;
                gram[i * m + k].i = (float)sum.im;
            }
        }
        __CLPK_integer count = (__CLPK_integer)m, leading = (__CLPK_integer)m, lwork = 2 * (__CLPK_integer)m + 64,
                          rworkSize = (__CLPK_integer)(4 * m + 64), info = 0;
        __CLPK_complex *work = (__CLPK_complex *)malloc((size_t)lwork * sizeof(__CLPK_complex));
        __CLPK_real *rwork = (__CLPK_real *)malloc((size_t)rworkSize * sizeof(__CLPK_real));
        __CLPK_real *values = (__CLPK_real *)malloc((size_t)m * sizeof(__CLPK_real));
        double largest = 0.0;
        if (work && rwork && values) {
            cheev_("N", "L", &count, gram, &leading, values, work, &lwork, rwork, &info);
            for (sparse_dimension i = 0; !info && i < m; i++) {
                if (values[i] > largest) {
                    largest = values[i];
                }
            }
        }
        free(work);
        free(rwork);
        free(values);
        free(gram);
        return largest > 0.0 ? sqrt(largest) : 0.0;
    }
    {
        __CLPK_doublecomplex *gram = (__CLPK_doublecomplex *)calloc((size_t)m * m, sizeof(__CLPK_doublecomplex));
        if (!gram) {
            return 0.0;
        }
        for (sparse_dimension i = 0; i < m; i++) {
            for (sparse_dimension k = 0; k < m; k++) {
                RevenantComplex sum = RevenantComplexMake(0.0, 0.0);
                for (sparse_index at = 0; at < asFloat->row[i].count; at++) {
                    sparse_index j = asFloat->row[i].column[at];
                    double re = 0.0, im = 0.0;
                    RevenantSparseReadComplexValue(asFloat->row[i].value, at, size, &re, &im);
                    double otherRe = 0.0, otherIm = 0.0;
                    RevenantSparseElementComplexAt(&asFloat->row[k], j, size, &otherRe, &otherIm);
                    sum = RevenantComplexAdd(sum, RevenantComplexMul(RevenantComplexMake(re, im),
                                                                 RevenantComplexMake(otherRe, -otherIm)));
                }
                gram[i * m + k].r = sum.re;
                gram[i * m + k].i = sum.im;
            }
        }
        __CLPK_integer count = (__CLPK_integer)m, leading = (__CLPK_integer)m, lwork = 2 * (__CLPK_integer)m + 64,
                          rworkSize = (__CLPK_integer)(4 * m + 64), info = 0;
        __CLPK_doublecomplex *work = (__CLPK_doublecomplex *)malloc((size_t)lwork * sizeof(__CLPK_doublecomplex));
        __CLPK_doublereal *rwork = (__CLPK_doublereal *)malloc((size_t)rworkSize * sizeof(__CLPK_doublereal));
        __CLPK_doublereal *values = (__CLPK_doublereal *)malloc((size_t)m * sizeof(__CLPK_doublereal));
        double largest = 0.0;
        if (work && rwork && values) {
            zheev_("N", "L", &count, gram, &leading, values, work, &lwork, rwork, &info);
            for (sparse_dimension i = 0; !info && i < m; i++) {
                if (values[i] > largest) {
                    largest = values[i];
                }
            }
        }
        free(work);
        free(rwork);
        free(values);
        free(gram);
        return largest > 0.0 ? sqrt(largest) : 0.0;
    }
}

float sparse_operator_norm_float_complex(sparse_matrix_float_complex A, sparse_norm norm)
{
    return (float)RevenantSparseOperatorComplex(A, REVENANT_SPARSE_MAGIC_FLOAT_COMPLEX, norm, sizeof(float _Complex));
}

double sparse_operator_norm_double_complex(sparse_matrix_double_complex A, sparse_norm norm)
{
    return RevenantSparseOperatorComplex(A, REVENANT_SPARSE_MAGIC_DOUBLE_COMPLEX, norm, sizeof(double _Complex));
}

static RevenantComplex RevenantSparseTraceComplex(void *matrix, uint32_t magic, sparse_index offset, size_t size)
{
    RevenantComplex sum = RevenantComplexMake(0.0, 0.0);
    if (!RevenantSparseIsMatrix(matrix, magic)) {
        return sum;
    }
    const struct sparse_m_float *asFloat = (const struct sparse_m_float *)matrix;
    for (sparse_dimension i = 0; i < asFloat->rows; i++) {
        sparse_index row = offset >= 0 ? (sparse_index)i : (sparse_index)i - offset;
        sparse_index column = offset >= 0 ? (sparse_index)i + offset : (sparse_index)i;
        if (row < 0 || row >= (sparse_index)asFloat->rows || column < 0 || column >= (sparse_index)asFloat->columns) {
            continue;
        }
        double re = 0.0, im = 0.0;
        RevenantSparseElementComplexAt(&asFloat->row[row], column, size, &re, &im);
        sum = RevenantComplexAdd(sum, RevenantComplexMake(re, im));
    }
    return sum;
}

float _Complex sparse_matrix_trace_float_complex(sparse_matrix_float_complex A, sparse_index offset)
{
    RevenantComplex sum = RevenantSparseTraceComplex(A, REVENANT_SPARSE_MAGIC_FLOAT_COMPLEX, offset, sizeof(float _Complex));
    return RevenantComplexAsFloat(sum);
}

double _Complex sparse_matrix_trace_double_complex(sparse_matrix_double_complex A, sparse_index offset)
{
    RevenantComplex sum = RevenantSparseTraceComplex(A, REVENANT_SPARSE_MAGIC_DOUBLE_COMPLEX, offset, sizeof(double _Complex));
    return RevenantComplexAsDouble(sum);
}
