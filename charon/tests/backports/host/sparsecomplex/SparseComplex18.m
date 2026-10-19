// The complex half of vecLib/Sparse/BLAS.h: the fifty-eight entry points of iOS 18.5, over the same
// storage and the same arithmetic as the sixty-nine real ones of iOS 9.
//
// No release this port supports exports any of them: measured with the ladder, symbol by symbol over
// every cache the port holds, all fifty-eight are exported by no release at all - not by 16.0, not by
// 18.0. So this is a library written here, the complex face of the one beside it, and it is the object
// file of its own because the sixty-nine beside it are 9.0 and 10.0.1 while these are 18.5.
//
// The arithmetic is the real one with a pair of reals for a value, and the BLAS is the release's own
// complex BLAS where it has a form:
//   - the products gather and accumulate with cblas_ccopy and cblas_caxpy, which the ladder puts at 4.0;
//   - the largest singular value is A' A formed with cblas_cherk (4.0) and the largest eigenvalue of the
//     real Hermitian result read with ssyev_ / dsyev_ (4.0);
//   - the two entry points with no complex form in the release's BLAS are written here, and the ladder
//     says why: cblas_cger, cblas_zger, cblas_cdotu, cblas_cdotc and cblas_zdotu are exported by no
//     release at all, so a rank-one update is an axpy and an inner product is a loop. The real half has
//     the same two gaps and answers them the same way.
//
// Behaviour is the host's own, held against this file by tests/backports/host/sparseblas, which runs
// both over the same inputs and compares every status, every count and every element of every value.
// facts/Accelerate/SparseBLAS.md carries the measurements.

#import <Accelerate/Accelerate.h>
// creal, cimag and the imaginary unit, which is how a value's two halves are named. A complex value is
// two adjacent reals, and the compiler lays them out that way in every ABI this port builds for, so
// these are the accessors and nothing else in this file knows how a complex is stored.
#include <complex.h>
#include "CharonSparseComplex.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wunguarded-availability"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// Which of the two complex types a matrix is, and the element size that goes with it.
static int CharonComplexIsDouble(const void *matrix)
{
    return CharonSparseIsDoubleComplex(matrix);
}

static sparse_status CharonComplexMake(void **out, uint32_t magic, sparse_dimension rows, sparse_dimension columns,
                                       sparse_index blockRows, sparse_index blockColumns,
                                       const sparse_dimension *heights, const sparse_dimension *widths)
{
    sparse_dimension totalRows = rows, totalColumns = columns;
    sparse_dimension *height = NULL, *width = NULL;
    if (blockRows > 0 && blockColumns > 0) {
        height = (sparse_dimension *)calloc(blockRows, sizeof(sparse_dimension));
        width = (sparse_dimension *)calloc(blockColumns, sizeof(sparse_dimension));
        if (!height || !width) {
            free(height);
            free(width);
            return SPARSE_SYSTEM_ERROR;
        }
        for (sparse_index i = 0; i < blockRows; i++) {
            height[i] = heights ? heights[i] : 0;
            totalRows += height[i];
        }
        for (sparse_index j = 0; j < blockColumns; j++) {
            width[j] = widths ? widths[j] : 0;
            totalColumns += width[j];
        }
    }
    void *matrix = calloc(1, sizeof(struct sparse_m_float_complex));
    if (!matrix) {
        free(height);
        free(width);
        return SPARSE_SYSTEM_ERROR;
    }
    struct sparse_m_float_complex *asComplex = (struct sparse_m_float_complex *)matrix;
    asComplex->magic = magic;
    asComplex->rows = totalRows;
    asComplex->columns = totalColumns;
    asComplex->blockRows = blockRows;
    asComplex->blockColumns = blockColumns;
    asComplex->blockHeight = height;
    asComplex->blockWidth = width;
    asComplex->property = 0;
    asComplex->inserted = 0;
    asComplex->nonzero = 0;
    asComplex->row = totalRows > 0 ? (CharonSparseRow *)calloc((size_t)totalRows, sizeof(CharonSparseRow)) : NULL;
    if (totalRows > 0 && !asComplex->row) {
        free(matrix);
        free(height);
        free(width);
        return SPARSE_SYSTEM_ERROR;
    }
    *out = matrix;
    return SPARSE_SUCCESS;
}

// ---------------------------------------------------------------- creation

sparse_matrix_float_complex sparse_matrix_create_float_complex(sparse_dimension M, sparse_dimension N)
{
    void *matrix = NULL;
    return CharonComplexMake(&matrix, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, M, N, 0, 0, NULL, NULL) == SPARSE_SUCCESS
               ? (sparse_matrix_float_complex)matrix
               : NULL;
}

sparse_matrix_double_complex sparse_matrix_create_double_complex(sparse_dimension M, sparse_dimension N)
{
    void *matrix = NULL;
    return CharonComplexMake(&matrix, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, M, N, 0, 0, NULL, NULL) == SPARSE_SUCCESS
               ? (sparse_matrix_double_complex)matrix
               : NULL;
}

static sparse_dimension *CharonComplexRepeated(sparse_dimension value, sparse_index count)
{
    sparse_dimension *sizes = (sparse_dimension *)calloc(count ? (size_t)count : 1, sizeof(sparse_dimension));
    for (sparse_index i = 0; sizes && i < count; i++) {
        sizes[i] = value;
    }
    return sizes;
}

sparse_matrix_float_complex sparse_matrix_block_create_float_complex(sparse_dimension Mb, sparse_dimension Nb,
                                                                    sparse_dimension k, sparse_dimension l)
{
    sparse_dimension *heights = CharonComplexRepeated(k, (sparse_index)Mb);
    sparse_dimension *widths = CharonComplexRepeated(l, (sparse_index)Nb);
    void *matrix = NULL;
    sparse_status made = CharonComplexMake(&matrix, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, 0, 0, (sparse_index)Mb,
                                           (sparse_index)Nb, heights, widths);
    free(heights);
    free(widths);
    return made == SPARSE_SUCCESS ? (sparse_matrix_float_complex)matrix : NULL;
}

sparse_matrix_double_complex sparse_matrix_block_create_double_complex(sparse_dimension Mb, sparse_dimension Nb,
                                                                      sparse_dimension k, sparse_dimension l)
{
    sparse_dimension *heights = CharonComplexRepeated(k, (sparse_index)Mb);
    sparse_dimension *widths = CharonComplexRepeated(l, (sparse_index)Nb);
    void *matrix = NULL;
    sparse_status made = CharonComplexMake(&matrix, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, 0, 0, (sparse_index)Mb,
                                           (sparse_index)Nb, heights, widths);
    free(heights);
    free(widths);
    return made == SPARSE_SUCCESS ? (sparse_matrix_double_complex)matrix : NULL;
}

sparse_matrix_float_complex sparse_matrix_variable_block_create_float_complex(sparse_dimension Mb,
                                                                              sparse_dimension Nb,
                                                                              const sparse_dimension *K,
                                                                              const sparse_dimension *L)
{
    void *matrix = NULL;
    return CharonComplexMake(&matrix, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, 0, 0, (sparse_index)Mb, (sparse_index)Nb, K,
                             L) == SPARSE_SUCCESS
               ? (sparse_matrix_float_complex)matrix
               : NULL;
}

sparse_matrix_double_complex sparse_matrix_variable_block_create_double_complex(sparse_dimension Mb,
                                                                                sparse_dimension Nb,
                                                                                const sparse_dimension *K,
                                                                                const sparse_dimension *L)
{
    void *matrix = NULL;
    return CharonComplexMake(&matrix, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, 0, 0, (sparse_index)Mb, (sparse_index)Nb, K,
                             L) == SPARSE_SUCCESS
               ? (sparse_matrix_double_complex)matrix
               : NULL;
}

// ---------------------------------------------------------------- insertion

static sparse_status CharonComplexPutEntry(void *matrix, uint32_t magic, double re, double im, sparse_index i,
                                           sparse_index j)
{
    if (!CharonSparseIsMatrix(matrix, magic) || ((const struct sparse_m_float_complex *)matrix)->blockRows > 0) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    struct sparse_m_float_complex *asComplex = (struct sparse_m_float_complex *)matrix;
    if (i < 0 || j < 0 || i >= (sparse_index)asComplex->rows || j >= (sparse_index)asComplex->columns) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    sparse_index before = asComplex->row[i].count;
    sparse_status put = CharonComplexPut(&asComplex->row[i], j, re, im, CharonComplexSize(magic == CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX));
    if (put == SPARSE_SUCCESS) {
        asComplex->nonzero += (long)asComplex->row[i].count - (long)before;
        asComplex->inserted = 1;
    }
    return put;
}

sparse_status sparse_insert_entry_float_complex(sparse_matrix_float_complex A, float _Complex val, sparse_index i,
                                                sparse_index j)
{
    return CharonComplexPutEntry(A, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, crealf(val), cimagf(val), i, j);
}

sparse_status sparse_insert_entry_double_complex(sparse_matrix_double_complex A, double _Complex val, sparse_index i,
                                                 sparse_index j)
{
    return CharonComplexPutEntry(A, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, creal(val), cimag(val), i, j);
}

sparse_status sparse_insert_entries_float_complex(sparse_matrix_float_complex A, sparse_dimension N,
                                                  const float _Complex *__restrict val,
                                                  const sparse_index *__restrict indx,
                                                  const sparse_index *__restrict jndx)
{
    if (!CharonSparseIsFloatComplex(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    for (sparse_dimension k = 0; k < N; k++) {
        sparse_status put = CharonComplexPutEntry(A, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, crealf(val[k]), cimagf(val[k]),
                                                  indx[k], jndx[k]);
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
    if (!CharonSparseIsDoubleComplex(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    for (sparse_dimension k = 0; k < N; k++) {
        sparse_status put = CharonComplexPutEntry(A, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, creal(val[k]), cimag(val[k]),
                                                  indx[k], jndx[k]);
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
    if (!CharonSparseIsFloatComplex(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    for (sparse_dimension k = 0; k < nz; k++) {
        sparse_status put = CharonComplexPutEntry(A, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, crealf(val[k]), cimagf(val[k]),
                                                  i, jndx[k]);
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
    if (!CharonSparseIsDoubleComplex(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    for (sparse_dimension k = 0; k < nz; k++) {
        sparse_status put = CharonComplexPutEntry(A, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, creal(val[k]), cimag(val[k]),
                                                  i, jndx[k]);
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
    if (!CharonSparseIsFloatComplex(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    for (sparse_dimension k = 0; k < nz; k++) {
        sparse_status put = CharonComplexPutEntry(A, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, crealf(val[k]), cimagf(val[k]),
                                                  indx[k], j);
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
    if (!CharonSparseIsDoubleComplex(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    for (sparse_dimension k = 0; k < nz; k++) {
        sparse_status put = CharonComplexPutEntry(A, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, creal(val[k]), cimag(val[k]),
                                                  indx[k], j);
        if (put != SPARSE_SUCCESS) {
            return put;
        }
    }
    return SPARSE_SUCCESS;
}

static sparse_status CharonComplexPutBlock(void *matrix, uint32_t magic, const void *val, sparse_dimension rowStride,
                                           sparse_dimension colStride, sparse_index bi, sparse_index bj)
{
    if (!CharonSparseIsMatrix(matrix, magic)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    struct sparse_m_float_complex *asComplex = (struct sparse_m_float_complex *)matrix;
    if (asComplex->blockRows <= 0) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    if (bi >= asComplex->blockRows || bj >= asComplex->blockColumns) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    size_t size = CharonComplexSize(magic == CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX);
    sparse_dimension height = asComplex->blockHeight[bi], width = asComplex->blockWidth[bj];
    sparse_dimension first = 0, left = 0;
    for (sparse_index b = 0; b < bi; b++) {
        first += asComplex->blockHeight[b];
    }
    for (sparse_index b = 0; b < bj; b++) {
        left += asComplex->blockWidth[b];
    }
    for (sparse_dimension i = 0; i < height; i++) {
        for (sparse_dimension j = 0; j < width; j++) {
            const char *from = (const char *)val + (size_t)(i * rowStride + j * colStride) * size;
            double re = 0.0, im = 0.0;
            CharonComplexLoad(from, size == 2 * sizeof(double), &re, &im);
            sparse_index before = asComplex->row[first + i].count;
            sparse_status put = CharonComplexPut(&asComplex->row[first + i], left + j, re, im, size);
            if (put != SPARSE_SUCCESS) {
                return put;
            }
            asComplex->nonzero += (long)asComplex->row[first + i].count - (long)before;
        }
    }
    asComplex->inserted = 1;
    return SPARSE_SUCCESS;
}

sparse_status sparse_insert_block_float_complex(sparse_matrix_float_complex A, const float _Complex *__restrict val,
                                                sparse_dimension row_stride, sparse_dimension col_stride,
                                                sparse_index bi, sparse_index bj)
{
    return CharonComplexPutBlock(A, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, val, row_stride, col_stride, bi, bj);
}

sparse_status sparse_insert_block_double_complex(sparse_matrix_double_complex A, const double _Complex *__restrict val,
                                                 sparse_dimension row_stride, sparse_dimension col_stride,
                                                 sparse_index bi, sparse_index bj)
{
    return CharonComplexPutBlock(A, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, val, row_stride, col_stride, bi, bj);
}

// ---------------------------------------------------------------- extraction

static long CharonComplexExtractRow(void *matrix, uint32_t magic, sparse_index row, sparse_index columnStart,
                                    sparse_index *columnEnd, sparse_dimension nz, void *val, sparse_index *jndx)
{
    if (!CharonSparseIsMatrix(matrix, magic) || !columnEnd) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    struct sparse_m_float_complex *asComplex = (struct sparse_m_float_complex *)matrix;
    if (row < 0 || columnStart < 0 || row >= (sparse_index)asComplex->rows ||
        columnStart >= (sparse_index)asComplex->columns || asComplex->blockRows > 0) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    size_t size = CharonComplexSize(magic == CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX);
    const CharonSparseRow *source = &asComplex->row[row];
    sparse_index at = CharonSparseSearch(source, columnStart);
    sparse_dimension written = 0;
    while (at < source->count && written < nz) {
        if (val) {
            // One memcpy of the entry: a complex value is the two scalars the row holds, laid out
            // contiguously, so nothing has to be converted on the way out.
            memcpy((char *)val + (size_t)written * size, (const char *)source->value + (size_t)at * size, size);
        }
        if (jndx) {
            jndx[written] = source->column[at];
        }
        written++;
        at++;
    }
    *columnEnd = nz == 0 ? columnStart
                         : (at < source->count ? source->column[at] : (sparse_index)asComplex->columns);
    return (long)written;
}

sparse_status sparse_extract_sparse_row_float_complex(sparse_matrix_float_complex A, sparse_index row,
                                                      sparse_index column_start, sparse_index *column_end,
                                                      sparse_dimension nz, float _Complex *__restrict val,
                                                      sparse_index *__restrict jndx)
{
    return (sparse_status)CharonComplexExtractRow(A, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, row, column_start, column_end,
                                                 nz, val, jndx);
}

sparse_status sparse_extract_sparse_row_double_complex(sparse_matrix_double_complex A, sparse_index row,
                                                       sparse_index column_start, sparse_index *column_end,
                                                       sparse_dimension nz, double _Complex *__restrict val,
                                                       sparse_index *__restrict jndx)
{
    return (sparse_status)CharonComplexExtractRow(A, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, row, column_start, column_end,
                                                 nz, val, jndx);
}

static long CharonComplexExtractColumn(void *matrix, uint32_t magic, sparse_index column, sparse_index rowStart,
                                       sparse_index *rowEnd, sparse_dimension nz, void *val, sparse_index *jndx)
{
    if (!CharonSparseIsMatrix(matrix, magic) || !rowEnd) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    struct sparse_m_float_complex *asComplex = (struct sparse_m_float_complex *)matrix;
    if (column < 0 || rowStart < 0 || column >= (sparse_index)asComplex->columns ||
        rowStart >= (sparse_index)asComplex->rows || asComplex->blockRows > 0) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    size_t size = CharonComplexSize(magic == CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX);
    sparse_dimension written = 0;
    sparse_index last = rowStart;
    for (sparse_index i = rowStart; i < (sparse_index)asComplex->rows && written < nz; i++) {
        const CharonSparseRow *source = &asComplex->row[i];
        sparse_index at = CharonSparseSearch(source, column);
        if (at >= source->count || source->column[at] != column) {
            continue;
        }
        if (val) {
            memcpy((char *)val + (size_t)written * size, (const char *)source->value + (size_t)at * size, size);
        }
        if (jndx) {
            jndx[written] = i;
        }
        written++;
        last = i;
    }
    sparse_index next = (sparse_index)asComplex->rows;
    for (sparse_index i = last + 1; i < (sparse_index)asComplex->rows; i++) {
        sparse_index at = CharonSparseSearch(&asComplex->row[i], column);
        if (at < asComplex->row[i].count && asComplex->row[i].column[at] == column) {
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
                                                         sparse_index *__restrict jndx)
{
    return (sparse_status)CharonComplexExtractColumn(A, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, column, row_start, row_end,
                                                    nz, val, jndx);
}

sparse_status sparse_extract_sparse_column_double_complex(sparse_matrix_double_complex A, sparse_index column,
                                                          sparse_index row_start, sparse_index *row_end,
                                                          sparse_dimension nz, double _Complex *__restrict val,
                                                          sparse_index *__restrict jndx)
{
    return (sparse_status)CharonComplexExtractColumn(A, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, column, row_start, row_end,
                                                    nz, val, jndx);
}

static sparse_status CharonComplexExtractBlock(void *matrix, uint32_t magic, sparse_index bi, sparse_index bj,
                                               sparse_dimension rowStride, sparse_dimension colStride, void *val)
{
    if (!CharonSparseIsMatrix(matrix, magic)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    struct sparse_m_float_complex *asComplex = (struct sparse_m_float_complex *)matrix;
    if (asComplex->blockRows <= 0 || bi >= asComplex->blockRows || bj >= asComplex->blockColumns) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    size_t size = CharonComplexSize(magic == CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX);
    sparse_dimension height = asComplex->blockHeight[bi], width = asComplex->blockWidth[bj];
    sparse_dimension first = 0, left = 0;
    for (sparse_index b = 0; b < bi; b++) {
        first += asComplex->blockHeight[b];
    }
    for (sparse_index b = 0; b < bj; b++) {
        left += asComplex->blockWidth[b];
    }
    for (sparse_dimension i = 0; i < height; i++) {
        for (sparse_dimension j = 0; j < width; j++) {
            double re = 0.0, im = 0.0;
            CharonComplexElementAt(&asComplex->row[first + i], left + j, size, &re, &im);
            CharonComplexStore((char *)val + (size_t)(i * rowStride + j * colStride) * size,
                               size == 2 * sizeof(double), re, im);
        }
    }
    return SPARSE_SUCCESS;
}

sparse_status sparse_extract_block_float_complex(sparse_matrix_float_complex A, sparse_index bi, sparse_index bj,
                                                 sparse_dimension row_stride, sparse_dimension col_stride,
                                                 float _Complex *__restrict val)
{
    return CharonComplexExtractBlock(A, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, bi, bj, row_stride, col_stride, val);
}

sparse_status sparse_extract_block_double_complex(sparse_matrix_double_complex A, sparse_index bi, sparse_index bj,
                                                  sparse_dimension row_stride, sparse_dimension col_stride,
                                                  double _Complex *__restrict val)
{
    return CharonComplexExtractBlock(A, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, bi, bj, row_stride, col_stride, val);
}

// ---------------------------------------------------------------- level 1

// The release's complex BLAS has no dot product: cblas_cdotu, cblas_cdotc and cblas_zdotu are exported by
// no release at all (measured, the ladder over every cache the port holds), so the inner product is the
// sum the header writes out, in the caller's order. A complex product a * b is (ar br - ai bi) + i (ar bi +
// ai br), and the real half sums the same way.
static void CharonComplexConjugate(double re, double im, double *outRe, double *outIm)
{
    *outRe = re;
    *outIm = -im;
}

static double CharonComplexNorm2(double re, double im)
{
    return hypot(re, im);
}

static void CharonComplexLoadAt(const void *base, size_t size, long at, double *re, double *im)
{
    CharonComplexLoad((const char *)base + (size_t)at * size, size == 2 * sizeof(double), re, im);
}

static void CharonComplexStoreAt(void *base, size_t size, long at, double re, double im)
{
    CharonComplexStore((char *)base + (size_t)at * size, size == 2 * sizeof(double), re, im);
}

static void CharonComplexInnerDense(sparse_dimension nz, const void *x, const sparse_index *indx, const void *y,
                                    sparse_stride incy, size_t size, double *outRe, double *outIm)
{
    if (nz == 0) {
        *outRe = 0.0;
        *outIm = 0.0;
        return;
    }
    double sumRe = 0.0, sumIm = 0.0;
    for (sparse_dimension k = 0; k < nz; k++) {
        double xr = 0.0, xi = 0.0, yr = 0.0, yi = 0.0;
        CharonComplexLoadAt(x, size, k, &xr, &xi);
        CharonComplexLoadAt(y, size, (long)(indx[k] * incy), &yr, &yi);
        sumRe += xr * yr - xi * yi;
        sumIm += xr * yi + xi * yr;
    }
    *outRe = sumRe;
    *outIm = sumIm;
}

float _Complex sparse_inner_product_dense_float_complex(sparse_dimension nz, const float _Complex *__restrict x,
                                                        const sparse_index *__restrict indx,
                                                        const float _Complex *__restrict y, sparse_stride incy)
{
    double re = 0.0, im = 0.0;
    CharonComplexInnerDense(nz, x, indx, y, incy, 2 * sizeof(float), &re, &im);
    return (float)re + (float)im * (float _Complex)_Complex_I;
}

double _Complex sparse_inner_product_dense_double_complex(sparse_dimension nz, const double _Complex *__restrict x,
                                                          const sparse_index *__restrict indx,
                                                          const double _Complex *__restrict y, sparse_stride incy)
{
    double re = 0.0, im = 0.0;
    CharonComplexInnerDense(nz, x, indx, y, incy, 2 * sizeof(double), &re, &im);
    return re + im * (double _Complex)_Complex_I;
}

static void CharonComplexInnerSparse(sparse_dimension nzx, sparse_dimension nzy, const void *x, const sparse_index *indx,
                                     const void *y, const sparse_index *indy, size_t size, double *outRe, double *outIm)
{
    if (nzx == 0 || nzy == 0) {
        *outRe = 0.0;
        *outIm = 0.0;
        return;
    }
    double sumRe = 0.0, sumIm = 0.0;
    sparse_dimension i = 0, j = 0;
    while (i < nzx && j < nzy) {
        if (indx[i] < indy[j]) {
            i++;
        } else if (indx[i] > indy[j]) {
            j++;
        } else {
            double xr = 0.0, xi = 0.0, yr = 0.0, yi = 0.0;
            CharonComplexLoadAt(x, size, (long)i, &xr, &xi);
            CharonComplexLoadAt(y, size, (long)j, &yr, &yi);
            sumRe += xr * yr - xi * yi;
            sumIm += xr * yi + xi * yr;
            i++;
            j++;
        }
    }
    *outRe = sumRe;
    *outIm = sumIm;
}

float _Complex sparse_inner_product_sparse_float_complex(sparse_dimension nzx, sparse_dimension nzy,
                                                         const float _Complex *__restrict x,
                                                         const sparse_index *__restrict indx,
                                                         const float _Complex *__restrict y,
                                                         const sparse_index *__restrict indy)
{
    double re = 0.0, im = 0.0;
    CharonComplexInnerSparse(nzx, nzy, x, indx, y, indy, 2 * sizeof(float), &re, &im);
    return (float)re + (float)im * (float _Complex)_Complex_I;
}

double _Complex sparse_inner_product_sparse_double_complex(sparse_dimension nzx, sparse_dimension nzy,
                                                          const double _Complex *__restrict x,
                                                          const sparse_index *__restrict indx,
                                                          const double _Complex *__restrict y,
                                                          const sparse_index *__restrict indy)
{
    double re = 0.0, im = 0.0;
    CharonComplexInnerSparse(nzx, nzy, x, indx, y, indy, 2 * sizeof(double), &re, &im);
    return re + im * (double _Complex)_Complex_I;
}

static void CharonComplexAddScale(sparse_dimension nz, double alphaRe, double alphaIm, const void *x,
                                  const sparse_index *indx, void *y, sparse_stride incy, size_t size)
{
    if (nz == 0 || (alphaRe == 0.0 && alphaIm == 0.0)) {
        return;
    }
    for (sparse_dimension k = 0; k < nz; k++) {
        double xr = 0.0, xi = 0.0, yr = 0.0, yi = 0.0;
        CharonComplexLoadAt(x, size, (long)k, &xr, &xi);
        CharonComplexLoadAt(y, size, (long)(indx[k] * incy), &yr, &yi);
        yr += alphaRe * xr - alphaIm * xi;
        yi += alphaRe * xi + alphaIm * xr;
        CharonComplexStoreAt(y, size, (long)(indx[k] * incy), yr, yi);
    }
}

void sparse_vector_add_with_scale_dense_float_complex(sparse_dimension nz, float _Complex alpha,
                                                       const float _Complex *__restrict x,
                                                       const sparse_index *__restrict indx,
                                                       float _Complex *__restrict y, sparse_stride incy)
{
    CharonComplexAddScale(nz, crealf(alpha), cimagf(alpha), x, indx, y, incy, 2 * sizeof(float));
}

void sparse_vector_add_with_scale_dense_double_complex(sparse_dimension nz, double _Complex alpha,
                                                      const double _Complex *__restrict x,
                                                      const sparse_index *__restrict indx,
                                                      double _Complex *__restrict y, sparse_stride incy)
{
    CharonComplexAddScale(nz, creal(alpha), cimag(alpha), x, indx, y, incy, 2 * sizeof(double));
}

// The three norms of a complex sparse vector are NOT the moduli-based ones the real half uses, and the
// host's own answers fix all of them. Measured, on {1, 0, 3 - i} at columns {0, 2, 3} with nz = 3 the one,
// two, infinity, R1 and an unenumerated name answer 5, 3.31662, 3.16228, 3.31662 and 3.16228, and on a
// single value {3 - i} they answer 4, 3.16228 and 3.16228:
//
//   SPARSE_NORM_ONE  the sum over the values of |re| + |im|       1 + 0 + (3 + 1) = 5, and 3 + 1 = 4
//   SPARSE_NORM_TWO  the root sum of the squared moduli          sqrt(1 + 0 + 9 + 1) = 3.31662
//   SPARSE_NORM_INF  the LARGEST MODULUS, sqrt(9 + 1) = 3.16228 - which is not the root sum of the
//                    squared moduli, which would be 3.31662 for that vector and does not match
//   SPARSE_NORM_R1   the two-norm, which the header says a vector does not support
//   any other name   the infinity norm, as the real half is measured to answer
//
// A count of zero answers zero, as in the real half.
static double CharonComplexVectorNorm(sparse_dimension nz, const void *x, const sparse_index *indx, sparse_norm norm,
                                      size_t size)
{
    if (nz == 0) {
        return 0.0;
    }
    if (norm == SPARSE_NORM_ONE) {
        double sum = 0.0;
        for (sparse_dimension k = 0; k < nz; k++) {
            double re = 0.0, im = 0.0;
            CharonComplexLoadAt(x, size, (long)k, &re, &im);
            sum += fabs(re) + fabs(im);
        }
        return sum;
    }
    if (norm == SPARSE_NORM_INF || (norm != SPARSE_NORM_TWO && norm != SPARSE_NORM_R1)) {
        double largest = 0.0;
        for (sparse_dimension k = 0; k < nz; k++) {
            double re = 0.0, im = 0.0;
            CharonComplexLoadAt(x, size, (long)k, &re, &im);
            double magnitude = CharonComplexNorm2(re, im);
            if (magnitude > largest) {
                largest = magnitude;
            }
        }
        return largest;
    }
    double sum = 0.0;
    for (sparse_dimension k = 0; k < nz; k++) {
        double re = 0.0, im = 0.0;
        CharonComplexLoadAt(x, size, (long)k, &re, &im);
        sum += re * re + im * im;
    }
    return sqrt(sum);
}

float sparse_vector_norm_float_complex(sparse_dimension nz, const float _Complex *__restrict x,
                                       const sparse_index *__restrict indx, sparse_norm norm)
{
    return (float)CharonComplexVectorNorm(nz, x, indx, norm, 2 * sizeof(float));
}

double sparse_vector_norm_double_complex(sparse_dimension nz, const double _Complex *__restrict x,
                                         const sparse_index *__restrict indx, sparse_norm norm)
{
    return CharonComplexVectorNorm(nz, x, indx, norm, 2 * sizeof(double));
}

// ---------------------------------------------------------------- the vector utilities

static long CharonComplexVectorNonzero(sparse_dimension N, const void *x, sparse_stride incx, size_t size)
{
    if (N == 0) {
        return 0;
    }
    long count = 0;
    for (sparse_dimension i = 0; i < N; i++) {
        double re = 0.0, im = 0.0;
        CharonComplexLoadAt(x, size, (long)(i * incx), &re, &im);
        if (re != 0.0 || im != 0.0) {
            count++;
        }
    }
    return count;
}

long sparse_get_vector_nonzero_count_float_complex(sparse_dimension N, const float _Complex *__restrict x,
                                                    sparse_stride incx)
{
    return CharonComplexVectorNonzero(N, x, incx, 2 * sizeof(float));
}

long sparse_get_vector_nonzero_count_double_complex(sparse_dimension N, const double _Complex *__restrict x,
                                                     sparse_stride incx)
{
    return CharonComplexVectorNonzero(N, x, incx, 2 * sizeof(double));
}

static long CharonComplexPack(sparse_dimension N, sparse_dimension nz, const void *x, sparse_stride incx, void *y,
                              sparse_index *indy, size_t size)
{
    if (N == 0 || nz == 0) {
        return 0;
    }
    long written = 0;
    for (sparse_dimension i = 0; i < N && (sparse_dimension)written < nz; i++) {
        double re = 0.0, im = 0.0;
        CharonComplexLoadAt(x, size, (long)(i * incx), &re, &im);
        if (re == 0.0 && im == 0.0) {
            continue;
        }
        if (y) {
            CharonComplexStoreAt(y, size, written, re, im);
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
    return CharonComplexPack(N, nz, x, incx, y, indy, 2 * sizeof(float));
}

long sparse_pack_vector_double_complex(sparse_dimension N, sparse_dimension nz, const double _Complex *__restrict x,
                                       sparse_stride incx, double _Complex *__restrict y, sparse_index *__restrict indy)
{
    return CharonComplexPack(N, nz, x, incx, y, indy, 2 * sizeof(double));
}

static void CharonComplexUnpack(sparse_dimension N, sparse_dimension nz, bool zero, const void *x,
                                const sparse_index *indx, void *y, sparse_stride incy, size_t size)
{
    if (zero) {
        for (sparse_dimension i = 0; i < N; i++) {
            CharonComplexStoreAt(y, size, (long)(i * incy), 0.0, 0.0);
        }
    }
    for (sparse_dimension k = 0; k < nz; k++) {
        if (indx[k] < 0 || indx[k] >= (sparse_index)N) {
            continue;
        }
        double re = 0.0, im = 0.0;
        CharonComplexLoadAt(x, size, (long)k, &re, &im);
        CharonComplexStoreAt(y, size, (long)(indx[k] * incy), re, im);
    }
}

void sparse_unpack_vector_float_complex(sparse_dimension N, sparse_dimension nz, bool zero,
                                        const float _Complex *__restrict x, const sparse_index *__restrict indx,
                                        float _Complex *__restrict y, sparse_stride incy)
{
    CharonComplexUnpack(N, nz, zero, x, indx, y, incy, 2 * sizeof(float));
}

void sparse_unpack_vector_double_complex(sparse_dimension N, sparse_dimension nz, bool zero,
                                         const double _Complex *__restrict x, const sparse_index *__restrict indx,
                                         double _Complex *__restrict y, sparse_stride incy)
{
    CharonComplexUnpack(N, nz, zero, x, indx, y, incy, 2 * sizeof(double));
}

// ---------------------------------------------------------------- level 2

// y = alpha * op(A) * x + y. One stored entry at a time, the address of the element computed here and the
// release's own cblas_caxpy doing the one multiply-add at it, which is what makes an increment of zero or
// a negative one work - the same rule and the same reason as the real half, and cblas_caxpy is at 4.0.
static sparse_status CharonComplexVectorProduct(void *matrix, uint32_t magic, int transposed, double alphaRe,
                                                 double alphaIm, const void *x, sparse_stride incx, void *y,
                                                 sparse_stride incy, size_t size)
{
    if (!CharonSparseIsMatrix(matrix, magic)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    const struct sparse_m_float_complex *asComplex = (const struct sparse_m_float_complex *)matrix;
    sparse_dimension inner = transposed ? asComplex->rows : asComplex->columns;
    sparse_dimension outer = transposed ? asComplex->columns : asComplex->rows;
    for (sparse_dimension i = 0; i < outer; i++) {
        for (sparse_dimension k = 0; k < inner; k++) {
            double re = 0.0, im = 0.0;
            CharonComplexElementAt(&asComplex->row[transposed ? k : i], transposed ? i : k, size, &re, &im);
            if (re == 0.0 && im == 0.0) {
                continue;
            }
            long from = (long)(k * incx), to = (long)(i * incy);
            if (size == 2 * sizeof(float)) {
                float factor = (float)(alphaRe * re - alphaIm * im), other = (float)(alphaRe * im + alphaIm * re);
                float complexFactor = factor + other * (float _Complex)_Complex_I;
                cblas_caxpy(1, &complexFactor, (const float complex *)x + from, 1, (float complex *)y + to, 1);
            } else {
                double factor = alphaRe * re - alphaIm * im, other = alphaRe * im + alphaIm * re;
                double complexFactor = factor + other * (double _Complex)_Complex_I;
                cblas_zaxpy(1, &complexFactor, (const double complex *)x + from, 1, (double complex *)y + to, 1);
            }
        }
    }
    return SPARSE_SUCCESS;
}

sparse_status sparse_matrix_vector_product_dense_float_complex(enum CBLAS_TRANSPOSE transa, float _Complex alpha,
                                                               sparse_matrix_float_complex A,
                                                               const float _Complex *__restrict x,
                                                               sparse_stride incx, float _Complex *__restrict y,
                                                               sparse_stride incy)
{
    if (transa != CblasNoTrans && transa != CblasTrans) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    return CharonComplexVectorProduct(A, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, transa == CblasTrans, crealf(alpha),
                                      cimagf(alpha), x, incx, y, incy, 2 * sizeof(float));
}

sparse_status sparse_matrix_vector_product_dense_double_complex(enum CBLAS_TRANSPOSE transa, double _Complex alpha,
                                                                sparse_matrix_double_complex A,
                                                                const double _Complex *__restrict x,
                                                                sparse_stride incx, double _Complex *__restrict y,
                                                                sparse_stride incy)
{
    if (transa != CblasNoTrans && transa != CblasTrans) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    return CharonComplexVectorProduct(A, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, transa == CblasTrans, creal(alpha),
                                      cimag(alpha), x, incx, y, incy, 2 * sizeof(double));
}

// The sparse substitution, over the stored entries, with alpha dividing the right-hand side - the rule
// the host's answers fix for the real types and the one this half follows for the same reason
// (facts/Accelerate/SparseBLAS.md: an alpha of zero answers an infinity and then a NaN where scaling the
// solution would answer zeros).
static sparse_status CharonComplexTriangular(void *matrix, uint32_t magic, int transposed, double alphaRe,
                                              double alphaIm, void *b, long iStep, long rightStep,
                                              sparse_dimension nrhs, size_t size)
{
    if (!CharonSparseIsMatrix(matrix, magic)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    const struct sparse_m_float_complex *asComplex = (const struct sparse_m_float_complex *)matrix;
    if (!(asComplex->property & (SPARSE_UPPER_TRIANGULAR | SPARSE_LOWER_TRIANGULAR))) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    int upper = (asComplex->property & SPARSE_UPPER_TRIANGULAR) != 0;
    sparse_dimension n = asComplex->rows;
    double alphaNorm2 = alphaRe * alphaRe + alphaIm * alphaIm;
    sparse_index *lists = NULL, *offsets = NULL;
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
                sparse_index at = CharonSparseSearch(&asComplex->row[r], (sparse_index)i);
                if (at < asComplex->row[r].count && asComplex->row[r].column[at] == (sparse_index)i) {
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
            CharonComplexLoadAt(b, size, here, &re, &im);
            // b / alpha, which for a complex alpha is b * conj(alpha) / |alpha|^2. An alpha of zero
            // divides, so every element comes back an infinity or a NaN, as it does in the real half.
            if (alphaNorm2 == 0.0) {
                double zero = 0.0;
                re = (re == 0.0 && im == 0.0) ? 0.0 / zero : re / zero;
                im = im / zero;
            } else {
                double scaledRe = (re * alphaRe + im * alphaIm) / alphaNorm2;
                double scaledIm = (im * alphaRe - re * alphaIm) / alphaNorm2;
                re = scaledRe;
                im = scaledIm;
            }
            if (!transposed) {
                for (sparse_index at = 0; at < asComplex->row[i].count; at++) {
                    sparse_index j = asComplex->row[i].column[at];
                    if (j == (sparse_index)i || (j < (sparse_index)i) == backwards) {
                        continue;
                    }
                    double other = 0.0, otherIm = 0.0;
                    CharonComplexLoadAt(asComplex->row[i].value, size, at, &other, &otherIm);
                    double fromRe = 0.0, fromIm = 0.0;
                    CharonComplexLoadAt(b, size, (long)j * iStep + (long)right * rightStep, &fromRe, &fromIm);
                    re -= other * fromRe - otherIm * fromIm;
                    im -= other * fromIm + otherIm * fromRe;
                }
            } else {
                for (sparse_index k = offsets[i]; k < offsets[i + 1]; k++) {
                    sparse_index j = lists[k];
                    if (j == (sparse_index)i || (j < (sparse_index)i) == backwards) {
                        continue;
                    }
                    double other = 0.0, otherIm = 0.0;
                    CharonComplexElementAt(&asComplex->row[j], (sparse_index)i, size, &other, &otherIm);
                    double fromRe = 0.0, fromIm = 0.0;
                    CharonComplexLoadAt(b, size, (long)j * iStep + (long)right * rightStep, &fromRe, &fromIm);
                    re -= other * fromRe - otherIm * fromIm;
                    im -= other * fromIm + otherIm * fromRe;
                }
            }
            double diagRe = 0.0, diagIm = 0.0;
            CharonComplexElementAt(&asComplex->row[i], i, size, &diagRe, &diagIm);
            // A pivot of exactly zero divides, and so does a pivot that is exactly zero in one half only.
            double norm2 = diagRe * diagRe + diagIm * diagIm;
            if (norm2 == 0.0) {
                double zero = 0.0;
                re = re / zero;
                im = im / zero;
            } else {
                double solvedRe = (re * diagRe + im * diagIm) / norm2;
                double solvedIm = (im * diagRe - re * diagIm) / norm2;
                re = solvedRe;
                im = solvedIm;
            }
            CharonComplexStoreAt(b, size, here, re, im);
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
    return CharonComplexTriangular(T, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, transt == CblasTrans, crealf(alpha),
                                   cimagf(alpha), x, incx, 0, 1, 2 * sizeof(float));
}

sparse_status sparse_vector_triangular_solve_dense_double_complex(enum CBLAS_TRANSPOSE transt, double _Complex alpha,
                                                                 sparse_matrix_double_complex T,
                                                                 double _Complex *__restrict x, sparse_stride incx)
{
    if (transt != CblasNoTrans && transt != CblasTrans) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    return CharonComplexTriangular(T, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, transt == CblasTrans, creal(alpha),
                                   cimag(alpha), x, incx, 0, 1, 2 * sizeof(double));
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
    if (!CharonSparseIsFloatComplex(T)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    const struct sparse_m_float_complex *asComplex = (const struct sparse_m_float_complex *)T;
    sparse_dimension needed = order == CblasRowMajor ? (nrhs ? nrhs : 1) : (asComplex->rows ? asComplex->rows : 1);
    if (ldb < needed) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    return CharonComplexTriangular(T, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, transt == CblasTrans, crealf(alpha),
                                   cimagf(alpha), B, order == CblasRowMajor ? (long)ldb : 1,
                                   order == CblasRowMajor ? 1 : (long)ldb, nrhs, 2 * sizeof(float));
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
    if (!CharonSparseIsDoubleComplex(T)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    const struct sparse_m_float_complex *asComplex = (const struct sparse_m_float_complex *)T;
    sparse_dimension needed = order == CblasRowMajor ? (nrhs ? nrhs : 1) : (asComplex->rows ? asComplex->rows : 1);
    if (ldb < needed) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    return CharonComplexTriangular(T, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, transt == CblasTrans, creal(alpha),
                                   cimag(alpha), B, order == CblasRowMajor ? (long)ldb : 1,
                                   order == CblasRowMajor ? 1 : (long)ldb, nrhs, 2 * sizeof(double));
}

// C = alpha * x * y' for a dense x and a sparse y, as a new matrix.
static sparse_status CharonComplexOuter(sparse_dimension M, sparse_dimension N, sparse_dimension nz, double alphaRe,
                                        double alphaIm, const void *x, sparse_stride incx, const void *y,
                                        const sparse_index *indy, void **C, uint32_t magic, size_t size)
{
    if (nz > N) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    void *matrix = NULL;
    if (CharonComplexMake(&matrix, magic, M, N, 0, 0, NULL, NULL) != SPARSE_SUCCESS) {
        return SPARSE_SYSTEM_ERROR;
    }
    struct sparse_m_float_complex *asComplex = (struct sparse_m_float_complex *)matrix;
    for (sparse_dimension k = 0; k < nz; k++) {
        double xr = 0.0, xi = 0.0, yr = 0.0, yi = 0.0;
        CharonComplexLoadAt(x, size, (long)(k * incx), &xr, &xi);
        double valueRe = alphaRe * xr - alphaIm * xi, valueIm = alphaRe * xi + alphaIm * xr;
        if (valueRe == 0.0 && valueIm == 0.0) {
            continue;
        }
        CharonComplexLoadAt(y, size, (long)k, &yr, &yi);
        double productRe = valueRe * yr - valueIm * yi, productIm = valueRe * yi + valueIm * yr;
        if (productRe == 0.0 && productIm == 0.0) {
            continue;
        }
        for (sparse_dimension i = 0; i < M; i++) {
            sparse_index before = asComplex->row[i].count;
            CharonComplexPut(&asComplex->row[i], indy[k], productRe, productIm, size);
            asComplex->nonzero += (long)asComplex->row[i].count - (long)before;
        }
    }
    void **out = (void **)C;
    *out = matrix;
    return SPARSE_SUCCESS;
}

sparse_status sparse_outer_product_dense_float_complex(sparse_dimension M, sparse_dimension N, sparse_dimension nz,
                                                        float _Complex alpha, const float _Complex *__restrict x,
                                                        sparse_stride incx, const float _Complex *__restrict y,
                                                        const sparse_index *__restrict indy,
                                                        sparse_matrix_float_complex *__restrict C)
{
    return CharonComplexOuter(M, N, nz, crealf(alpha), cimagf(alpha), x, incx, y, indy, (void **)C,
                              CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, 2 * sizeof(float));
}

sparse_status sparse_outer_product_dense_double_complex(sparse_dimension M, sparse_dimension N, sparse_dimension nz,
                                                         double _Complex alpha, const double _Complex *__restrict x,
                                                         sparse_stride incx, const double _Complex *__restrict y,
                                                         const sparse_index *__restrict indy,
                                                         sparse_matrix_double_complex *__restrict C)
{
    return CharonComplexOuter(M, N, nz, creal(alpha), cimag(alpha), x, incx, y, indy, (void **)C,
                              CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, 2 * sizeof(double));
}

// The header's swap loop, as in the real half: a permutation is not a gather, and the two are not the
// same function. Measured on the host for the real types; asked for both in the differential.
static sparse_status CharonComplexPermuteRows(void *matrix, uint32_t magic, const sparse_index *perm, size_t size)
{
    if (!CharonSparseIsMatrix(matrix, magic)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    struct sparse_m_float_complex *asComplex = (struct sparse_m_float_complex *)matrix;
    for (sparse_dimension i = 0; i < asComplex->rows; i++) {
        sparse_index target = perm[i];
        if (target < 0 || target >= (sparse_index)asComplex->rows || target == (sparse_index)i) {
            continue;
        }
        CharonSparseRow held = asComplex->row[i];
        asComplex->row[i] = asComplex->row[target];
        asComplex->row[target] = held;
    }
    (void)size;
    return SPARSE_SUCCESS;
}

static sparse_status CharonComplexPermuteCols(void *matrix, uint32_t magic, const sparse_index *perm, size_t size)
{
    if (!CharonSparseIsMatrix(matrix, magic)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    struct sparse_m_float_complex *asComplex = (struct sparse_m_float_complex *)matrix;
    for (sparse_dimension j = 0; j < asComplex->columns; j++) {
        sparse_index target = perm[j];
        if (target < 0 || target >= (sparse_index)asComplex->columns || target == (sparse_index)j) {
            continue;
        }
        for (sparse_dimension i = 0; i < asComplex->rows; i++) {
            double hereRe = 0.0, hereIm = 0.0, thereRe = 0.0, thereIm = 0.0;
            CharonComplexElementAt(&asComplex->row[i], j, size, &hereRe, &hereIm);
            CharonComplexElementAt(&asComplex->row[i], target, size, &thereRe, &thereIm);
            sparse_index atJ = CharonSparseSearch(&asComplex->row[i], j);
            sparse_index atT = CharonSparseSearch(&asComplex->row[i], target);
            int hadJ = atJ < asComplex->row[i].count && asComplex->row[i].column[atJ] == j;
            int hadT = atT < asComplex->row[i].count && asComplex->row[i].column[atT] == target;
            CharonComplexPut(&asComplex->row[i], j, thereRe, thereIm, size);
            CharonComplexPut(&asComplex->row[i], target, hereRe, hereIm, size);
            atJ = CharonSparseSearch(&asComplex->row[i], j);
            atT = CharonSparseSearch(&asComplex->row[i], target);
            int hasJ = atJ < asComplex->row[i].count && asComplex->row[i].column[atJ] == j;
            int hasT = atT < asComplex->row[i].count && asComplex->row[i].column[atT] == target;
            asComplex->nonzero += (hasJ + hasT) - (hadJ + hadT);
        }
    }
    return SPARSE_SUCCESS;
}

sparse_status sparse_permute_rows_float_complex(sparse_matrix_float_complex A, const sparse_index *__restrict perm)
{
    return CharonComplexPermuteRows(A, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, perm, 2 * sizeof(float));
}

sparse_status sparse_permute_rows_double_complex(sparse_matrix_double_complex A, const sparse_index *__restrict perm)
{
    return CharonComplexPermuteRows(A, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, perm, 2 * sizeof(double));
}

sparse_status sparse_permute_cols_float_complex(sparse_matrix_float_complex A, const sparse_index *__restrict perm)
{
    return CharonComplexPermuteCols(A, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, perm, 2 * sizeof(float));
}

sparse_status sparse_permute_cols_double_complex(sparse_matrix_double_complex A, const sparse_index *__restrict perm)
{
    return CharonComplexPermuteCols(A, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, perm, 2 * sizeof(double));
}

// ---------------------------------------------------------------- the norms and the trace

static double CharonComplexElementwise(void *matrix, uint32_t magic, sparse_norm norm, size_t size)
{
    if (!CharonSparseIsMatrix(matrix, magic)) {
        return 0.0;
    }
    const struct sparse_m_float_complex *asComplex = (const struct sparse_m_float_complex *)matrix;
    if (norm == SPARSE_NORM_ONE) {
        // The sum of |re| + |im| over the stored entries, not the sum of the moduli: measured, for
        // [[-1, 2 + i, -3i], [4, 0, -5 + 2i]] the host answers 18, which is 1 + 3 + 3 + 4 + 0 + 7, and the
        // moduli would give 15.6213.
        double sum = 0.0;
        for (sparse_dimension i = 0; i < asComplex->rows; i++) {
            for (sparse_index at = 0; at < asComplex->row[i].count; at++) {
                double re = 0.0, im = 0.0;
                CharonComplexLoadAt(asComplex->row[i].value, size, at, &re, &im);
                sum += fabs(re) + fabs(im);
            }
        }
        return sum;
    }
    if (norm == SPARSE_NORM_TWO) {
        double sum = 0.0;
        for (sparse_dimension i = 0; i < asComplex->rows; i++) {
            for (sparse_index at = 0; at < asComplex->row[i].count; at++) {
                double re = 0.0, im = 0.0;
                CharonComplexLoadAt(asComplex->row[i].value, size, at, &re, &im);
                sum += re * re + im * im;
            }
        }
        return sqrt(sum);
    }
    if (norm == SPARSE_NORM_R1) {
        double total = 0.0;
        for (sparse_index j = 0; j < (sparse_index)asComplex->columns; j++) {
            double sum = 0.0;
            for (sparse_dimension i = 0; i < asComplex->rows; i++) {
                double re = 0.0, im = 0.0;
                CharonComplexElementAt(&asComplex->row[i], j, size, &re, &im);
                sum += re * re + im * im;
            }
            total += sqrt(sum);
        }
        return total;
    }
    double largest = 0.0;
    for (sparse_dimension i = 0; i < asComplex->rows; i++) {
        for (sparse_index at = 0; at < asComplex->row[i].count; at++) {
            double re = 0.0, im = 0.0;
            CharonComplexLoadAt(asComplex->row[i].value, size, at, &re, &im);
            double magnitude = CharonComplexNorm2(re, im);
            if (magnitude > largest) {
                largest = magnitude;
            }
        }
    }
    return largest;
}

float sparse_elementwise_norm_float_complex(sparse_matrix_float_complex A, sparse_norm norm)
{
    return (float)CharonComplexElementwise(A, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, norm, 2 * sizeof(float));
}

double sparse_elementwise_norm_double_complex(sparse_matrix_double_complex A, sparse_norm norm)
{
    return CharonComplexElementwise(A, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, norm, 2 * sizeof(double));
}

// The operator-one and operator-infinity norms are the largest column sum and the largest row sum of the
// moduli, and an unenumerated name is the infinity norm, exactly as in the real half. The operator-two
// norm is the largest singular value, which for a complex matrix is the largest eigenvalue of A' A: a
// real Hermitian matrix, formed here with the release's own cblas_cherk (4.0) and read with ssyev_ or
// dsyev_ (4.0). SPARSE_NORM_R1 is not supported for a matrix and answers NaN.
static double CharonComplexOperator(void *matrix, uint32_t magic, sparse_norm norm, size_t size)
{
    if (!CharonSparseIsMatrix(matrix, magic)) {
        return 0.0;
    }
    const struct sparse_m_float_complex *asComplex = (const struct sparse_m_float_complex *)matrix;
    sparse_dimension m = asComplex->rows, n = asComplex->columns;
    if (m == 0 || n == 0) {
        return 0.0;
    }
    if (norm == SPARSE_NORM_ONE || (norm != SPARSE_NORM_TWO && norm != SPARSE_NORM_R1)) {
        // |re| + |im| in both, as the elementwise one norm is measured to be: for
        // [[-1, 2 + i, -3i], [4, 0, -5 + 2i]] the host answers 10 for the one norm and 11 for the
        // infinity norm, which are the largest column and row sums of 5, 3, 10 and of 7, 0, 11. The one
        // norm walks a column and the infinity norm a row, and the row sum is over the row's own
        // stored entries - reading the diagonal of a row is what the first version did, and it
        // answered 1 where the host answers 11.
        if (norm == SPARSE_NORM_ONE) {
            double largest = 0.0;
            for (sparse_index j = 0; j < (sparse_index)n; j++) {
                double sum = 0.0;
                for (sparse_dimension i = 0; i < m; i++) {
                    double re = 0.0, im = 0.0;
                    CharonComplexElementAt(&asComplex->row[i], j, size, &re, &im);
                    sum += fabs(re) + fabs(im);
                }
                if (sum > largest) {
                    largest = sum;
                }
            }
            return largest;
        }
        double largest = 0.0;
        for (sparse_dimension i = 0; i < m; i++) {
            double sum = 0.0;
            for (sparse_index at = 0; at < asComplex->row[i].count; at++) {
                double re = 0.0, im = 0.0;
                CharonComplexLoadAt(asComplex->row[i].value, size, at, &re, &im);
                sum += fabs(re) + fabs(im);
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
    // A' A, as a dense m x m matrix of reals through cblas_cherk, and its largest eigenvalue.
    int single = size == 2 * sizeof(float);
    size_t entrySize = single ? sizeof(float) : sizeof(double);
    void *dense = calloc((size_t)m * n, 2 * entrySize);
    if (!dense) {
        return 0.0;
    }
    // One pass over the stored entries into the dense form cblas_cherk takes, converting from the
    // matrix's own scalar type once per entry.
    for (sparse_dimension i = 0; i < m; i++) {
        for (sparse_index at = 0; at < asComplex->row[i].count; at++) {
            double re = 0.0, im = 0.0;
            CharonComplexLoadAt(asComplex->row[i].value, size, at, &re, &im);
            CharonComplexStoreAt(dense, 2 * entrySize, (long)(i * n + asComplex->row[i].column[at]), re, im);
        }
    }
    void *gram = calloc((size_t)m * m, entrySize);
    if (!gram) {
        free(dense);
        return 0.0;
    }
    if (single) {
        cblas_cherk(CblasColMajor, CblasUpper, CblasConjTrans, (int)m, (int)n, 1.0f, (const float *)dense, (int)n,
                    0.0f, (float *)gram, (int)m);
    } else {
        cblas_zherk(CblasColMajor, CblasUpper, CblasConjTrans, (int)m, (int)n, 1.0, (const double *)dense, (int)n,
                    0.0, (double *)gram, (int)m);
    }
    free(dense);
    __CLPK_integer count = (__CLPK_integer)m, leading = (__CLPK_integer)m, lwork = 4 * (__CLPK_integer)m + 64,
                      info = 0;
    double largest = 0.0;
    if (single) {
        float *work = (float *)malloc((size_t)lwork * sizeof(float));
        float *values = (float *)malloc((size_t)m * sizeof(float));
        if (work && values) {
            ssyev_("N", "U", &count, (float *)gram, &leading, values, work, &lwork, &info);
            for (sparse_dimension i = 0; !info && i < m; i++) {
                if (values[i] > largest) {
                    largest = values[i];
                }
            }
        }
        free(work);
        free(values);
    } else {
        double *work = (double *)malloc((size_t)lwork * sizeof(double));
        double *values = (double *)malloc((size_t)m * sizeof(double));
        if (work && values) {
            dsyev_("N", "U", &count, (double *)gram, &leading, values, work, &lwork, &info);
            for (sparse_dimension i = 0; !info && i < m; i++) {
                if (values[i] > largest) {
                    largest = values[i];
                }
            }
        }
        free(work);
        free(values);
    }
    free(gram);
    return largest > 0.0 ? sqrt(largest) : 0.0;
}

float sparse_operator_norm_float_complex(sparse_matrix_float_complex A, sparse_norm norm)
{
    return (float)CharonComplexOperator(A, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, norm, 2 * sizeof(float));
}

double sparse_operator_norm_double_complex(sparse_matrix_double_complex A, sparse_norm norm)
{
    return CharonComplexOperator(A, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, norm, 2 * sizeof(double));
}

// The sum along one diagonal, of complex values: A[i, i + offset] above the main diagonal and
// A[i - offset, i] below it, which is the header's own spelling (measured on the host for the real
// types: on a 3x4 whose diagonal is 2, 4 and 0 the offsets 0, 1 and -1 answer 6, 8 and 0).
static void CharonComplexTrace(void *matrix, uint32_t magic, sparse_index offset, size_t size, double *outRe,
                                double *outIm)
{
    *outRe = 0.0;
    *outIm = 0.0;
    if (!CharonSparseIsMatrix(matrix, magic)) {
        return;
    }
    const struct sparse_m_float_complex *asComplex = (const struct sparse_m_float_complex *)matrix;
    for (sparse_dimension i = 0; i < asComplex->rows; i++) {
        sparse_index row = offset >= 0 ? (sparse_index)i : (sparse_index)i - offset;
        sparse_index column = offset >= 0 ? (sparse_index)i + offset : (sparse_index)i;
        if (row < 0 || row >= (sparse_index)asComplex->rows || column < 0 ||
            column >= (sparse_index)asComplex->columns) {
            continue;
        }
        double re = 0.0, im = 0.0;
        CharonComplexElementAt(&asComplex->row[row], column, size, &re, &im);
        *outRe += re;
        *outIm += im;
    }
}

float _Complex sparse_matrix_trace_float_complex(sparse_matrix_float_complex A, sparse_index offset)
{
    double re = 0.0, im = 0.0;
    CharonComplexTrace(A, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, offset, 2 * sizeof(float), &re, &im);
    return (float)re + (float)im * (float _Complex)_Complex_I;
}

double _Complex sparse_matrix_trace_double_complex(sparse_matrix_double_complex A, sparse_index offset)
{
    double re = 0.0, im = 0.0;
    CharonComplexTrace(A, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, offset, 2 * sizeof(double), &re, &im);
    return re + im * (double _Complex)_Complex_I;
}

// ---------------------------------------------------------------- level 3

// C = alpha * op(A) * B + C, one stored entry of op(A) at a time: the release's own cblas_ccopy gathers
// the row of B the entry names and cblas_caxpy adds alpha times the entry's value times it to the row of
// C. cblas_cger is exported by no release at all (measured), so the rank-one update is an axpy, which is
// the same shape the real half has.
static sparse_status CharonComplexProductDense(void *matrix, uint32_t magic, int order, int transposed,
                                                sparse_dimension n, double alphaRe, double alphaIm, const void *B,
                                                sparse_dimension ldb, void *C, sparse_dimension ldc, size_t size)
{
    if (order != CblasRowMajor && order != CblasColMajor) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    if (!CharonSparseIsMatrix(matrix, magic)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    const struct sparse_m_float_complex *asComplex = (const struct sparse_m_float_complex *)matrix;
    sparse_dimension m = transposed ? asComplex->columns : asComplex->rows;
    sparse_dimension k = transposed ? asComplex->rows : asComplex->columns;
    sparse_dimension bStep = order == CblasRowMajor ? 1 : ldb;
    sparse_dimension cStep = order == CblasRowMajor ? 1 : ldc;
    if (ldb < (order == CblasRowMajor ? (n ? n : 1) : (k ? k : 1)) ||
        ldc < (order == CblasRowMajor ? (n ? n : 1) : (m ? m : 1))) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    if (n == 0 || (alphaRe == 0.0 && alphaIm == 0.0)) {
        return SPARSE_SUCCESS;
    }
    void *row = calloc((size_t)(n ? n : 1), size);
    if (!row) {
        return SPARSE_SYSTEM_ERROR;
    }
    for (sparse_dimension i = 0; i < m; i++) {
        const CharonSparseRow *line = transposed ? NULL : &asComplex->row[i];
        for (sparse_index at = 0; at < (transposed ? (sparse_index)asComplex->rows : line->count); at++) {
            sparse_index r = transposed ? at : (sparse_index)i;
            sparse_index c = transposed ? (sparse_index)i : line->column[at];
            if (c >= (sparse_index)asComplex->columns) {
                continue;
            }
            double re = 0.0, im = 0.0;
            CharonComplexLoadAt(line ? line->value : asComplex->row[r].value, size, at, &re, &im);
            if (re == 0.0 && im == 0.0) {
                continue;
            }
            long from = CharonSparseDenseAt(order, ldb, transposed ? r : c, 0);
            long to = CharonSparseDenseAt(order, ldc, i, 0);
            if (size == 2 * sizeof(float)) {
                float factor = (float)(alphaRe * re - alphaIm * im), other = (float)(alphaRe * im + alphaIm * re);
                float complexFactor = factor + other * (float _Complex)_Complex_I;
                cblas_ccopy((int)n, (const float complex *)B + from, (int)bStep, (float complex *)row, 1);
                cblas_caxpy((int)n, &complexFactor, (const float complex *)row, 1, (float complex *)C + to, (int)cStep);
            } else {
                double factor = alphaRe * re - alphaIm * im, other = alphaRe * im + alphaIm * re;
                double complexFactor = factor + other * (double _Complex)_Complex_I;
                cblas_zcopy((int)n, (const double complex *)B + from, (int)bStep, (double complex *)row, 1);
                cblas_zaxpy((int)n, &complexFactor, (const double complex *)row, 1, (double complex *)C + to, (int)cStep);
            }
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
    return CharonComplexProductDense(A, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, order, transa == CblasTrans, n, crealf(alpha),
                                      cimagf(alpha), B, ldb, C, ldc, 2 * sizeof(float));
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
    return CharonComplexProductDense(A, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, order, transa == CblasTrans, n, creal(alpha),
                                      cimag(alpha), B, ldb, C, ldc, 2 * sizeof(double));
}

// C = alpha * op(A) * B + C with B sparse too, the same update per nonzero with B's row out of its own
// stored entries.
static sparse_status CharonComplexProductSparse(void *A, uint32_t magicA, int order, int transposed, double alphaRe,
                                                 double alphaIm, void *B, uint32_t magicB, void *C,
                                                 sparse_dimension ldc, size_t size)
{
    if (order != CblasRowMajor && order != CblasColMajor) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    if (!CharonSparseIsMatrix(A, magicA) || !CharonSparseIsMatrix(B, magicB)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    const struct sparse_m_float_complex *asA = (const struct sparse_m_float_complex *)A;
    const struct sparse_m_float_complex *asB = (const struct sparse_m_float_complex *)B;
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
    double *row = (double *)calloc(n ? n : 1, 2 * sizeof(double));
    if (!row) {
        return SPARSE_SYSTEM_ERROR;
    }
    for (sparse_dimension i = 0; i < m; i++) {
        const CharonSparseRow *line = transposed ? NULL : &asA->row[i];
        for (sparse_index at = 0; at < (transposed ? (sparse_index)asA->rows : line->count); at++) {
            sparse_index r = transposed ? at : (sparse_index)i;
            sparse_index c = transposed ? (sparse_index)i : line->column[at];
            if (c >= (sparse_index)asA->columns) {
                continue;
            }
            double re = 0.0, im = 0.0;
            CharonComplexLoadAt(line ? line->value : asA->row[r].value, size, at, &re, &im);
            if (re == 0.0 && im == 0.0) {
                continue;
            }
            memset(row, 0, (size_t)(n ? n : 1) * 2 * sizeof(double));
            const CharonSparseRow *from = &asB->row[transposed ? r : c];
            for (sparse_index b = 0; b < from->count; b++) {
                if (from->column[b] < (sparse_index)n) {
                    double br = 0.0, bi = 0.0;
                    CharonComplexLoadAt(from->value, size, b, &br, &bi);
                    CharonComplexStoreAt(row, 2 * sizeof(double), from->column[b], br, bi);
                }
            }
            long to = CharonSparseDenseAt(order, ldc, i, 0);
            for (sparse_dimension j = 0; j < n; j++) {
                double br = 0.0, bi = 0.0;
                CharonComplexLoadAt(row, 2 * sizeof(double), (long)j, &br, &bi);
                if (br == 0.0 && bi == 0.0) {
                    continue;
                }
                long at2 = to + (long)(j * cStep);
                if (size == 2 * sizeof(float)) {
                    float factor = (float)(alphaRe * re - alphaIm * im), other = (float)(alphaRe * im + alphaIm * re);
                    float complexFactor = factor + other * (float _Complex)_Complex_I;
                    cblas_caxpy(1, &complexFactor, (const float complex *)row + j, 1, (float complex *)C + at2, 1);
                } else {
                    double factor = alphaRe * re - alphaIm * im, other = alphaRe * im + alphaIm * re;
                    double complexFactor = factor + other * (double _Complex)_Complex_I;
                    cblas_zaxpy(1, &complexFactor, (const double complex *)row + j, 1, (double complex *)C + at2, 1);
                }
            }
        }
    }
    free(row);
    return SPARSE_SUCCESS;
}

sparse_status sparse_matrix_product_sparse_float_complex(enum CBLAS_ORDER order, enum CBLAS_TRANSPOSE transa,
                                                         float _Complex alpha, sparse_matrix_float_complex A,
                                                         sparse_matrix_float_complex B,
                                                         float _Complex *__restrict C, sparse_dimension ldc)
{
    if (transa != CblasNoTrans && transa != CblasTrans) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    return CharonComplexProductSparse(A, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, order, transa == CblasTrans, crealf(alpha),
                                      cimagf(alpha), B, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, C, ldc, 2 * sizeof(float));
}

sparse_status sparse_matrix_product_sparse_double_complex(enum CBLAS_ORDER order, enum CBLAS_TRANSPOSE transa,
                                                          double _Complex alpha, sparse_matrix_double_complex A,
                                                          sparse_matrix_double_complex B,
                                                          double _Complex *__restrict C, sparse_dimension ldc)
{
    if (transa != CblasNoTrans && transa != CblasTrans) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    return CharonComplexProductSparse(A, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, order, transa == CblasTrans, creal(alpha),
                                      cimag(alpha), B, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, C, ldc, 2 * sizeof(double));
}
