// The complex sparse BLAS of vecLib/Sparse/BLAS.h: the 58 entry points that arrived in iOS 18.5, in
// the float complex and the double complex of each.
//
// No release this port supports has any of them - measured over the fifty-one rungs of the release
// ladder this port holds (1.1.4 through 18.0), the first held rung carrying any of the fifty-eight is
// NONE, and the 26.2 header that declares them puts all of them at 18.5 - so this is a library
// written here, over the same storage the sixty-nine real entry points use (CharonSparseBLAS.h) and
// over the release's own complex BLAS and LAPACK, which every band exports.
//
// What the arithmetic is made of, and why each piece is where it is:
//
//   - A matrix is a list of rows, each a run of (column, value) pairs kept sorted by column, and a
//     value of a complex row is a pair stored in the row's own width. That is the whole storage, and
//     it is what makes every operation below either a walk of the stored entries or a call into the
//     release's BLAS over one row.
//   - The arithmetic is on pairs of doubles (CharonSparseComplex.h) and never on a `_Complex`
//     operator, because the two operations that would need one - a complex product and a complex
//     quotient - are the only two the compiler would hand to a helper, and the arithmetic is spelled
//     out instead. A value is rounded to the width its row stores when it is written, which is the
//     same rule the real entry points follow when they store a float through a double.
//   - The products - y = alpha * op(A) * x + y and C = alpha * op(A) * B + C for a dense B or a sparse
//     one - are the textbook sparse level-2 and level-3 kernels: one multiply-add per stored entry of
//     op(A), each over the row of x or of B the entry names, with the multiply-add and the gather the
//     release's own cblas_caxpy / cblas_zaxpy and cblas_ccopy / cblas_zcopy. That is the same choice the
//     real family makes with cblas_saxpy / cblas_daxpy, and it is measured that a complex alpha is done
//     properly by those (facts/Accelerate/SparseComplex.md).
//   - The operator-two norm, the largest singular value, is the release's own LAPACK: the Hermitian
//     Gram matrix A * A' formed here and its eigenvalues read with cheev_ / zheev_.
//   - The triangular solves are the sparse substitution itself, over the stored entries, because a
//     dense cblas_ctrsv would throw the sparsity away: the solve is O(nnz) and the dense one is
//     O(n^2), which is the whole reason a caller reached for a sparse matrix.
//   - The norms, the trace, the inner products, the permutations and the vector utilities have no
//     dense BLAS form - irregular indices, a max, a diagonal - and are the arithmetic the header
//     writes out.
//
// Two measured rules are not the same as the real entry points' and are called out below where they
// are used: the inner products do not conjugate (measured, for x = {3+4i, 1} and y = {1+i, 2} the
// host answers 1+7i, which is x.y, and 9-i, which is conj(x).y), and the one-norm is the sum of the
// parts of the values rather than the sum of their moduli (measured, the same vector's one norm is 8
// and the sum of its moduli is 6).
//
// Behaviour is the host's own, measured case by case by tests/backports/host/sparseblas, which runs
// this file and the host's Accelerate over the same inputs and compares the status, the count and
// every element; facts/Accelerate/SparseComplex.md carries the measurements, the three cases the host
// answers in a way that is not reproducible from the header, and which side of each one the port is on.

#import <Accelerate/Accelerate.h>
#include "CharonSparseComplex26.h"
#include "CharonSparseBLAS.h"
#include "CharonSparseComplex.h"


// ---------------------------------------------------------------- shape of a matrix

sparse_matrix_float_complex sparse_matrix_create_float_complex(sparse_dimension M, sparse_dimension N)
{
    void *matrix = NULL;
    if (CharonSparseMake(&matrix, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, sizeof(struct sparse_m_float_complex), M, N, 0, 0,
                         NULL, NULL) != SPARSE_SUCCESS) {
        return NULL;
    }
    return (sparse_matrix_float_complex)matrix;
}

sparse_matrix_double_complex sparse_matrix_create_double_complex(sparse_dimension M, sparse_dimension N)
{
    void *matrix = NULL;
    if (CharonSparseMake(&matrix, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, sizeof(struct sparse_m_double_complex), M, N, 0, 0,
                         NULL, NULL) != SPARSE_SUCCESS) {
        return NULL;
    }
    return (sparse_matrix_double_complex)matrix;
}

sparse_matrix_float_complex sparse_matrix_block_create_float_complex(sparse_dimension Mb, sparse_dimension Nb,
                                                                    sparse_dimension k, sparse_dimension l)
{
    sparse_dimension *heights = CharonSparseRepeated(k, (sparse_index)Mb);
    sparse_dimension *widths = CharonSparseRepeated(l, (sparse_index)Nb);
    void *matrix = NULL;
    sparse_status made =
        CharonSparseMake(&matrix, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, sizeof(struct sparse_m_float_complex), 0, 0,
                         (sparse_index)Mb, (sparse_index)Nb, heights, widths);
    free(heights);
    free(widths);
    return made == SPARSE_SUCCESS ? (sparse_matrix_float_complex)matrix : NULL;
}

sparse_matrix_double_complex sparse_matrix_block_create_double_complex(sparse_dimension Mb, sparse_dimension Nb,
                                                                      sparse_dimension k, sparse_dimension l)
{
    sparse_dimension *heights = CharonSparseRepeated(k, (sparse_index)Mb);
    sparse_dimension *widths = CharonSparseRepeated(l, (sparse_index)Nb);
    void *matrix = NULL;
    sparse_status made =
        CharonSparseMake(&matrix, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, sizeof(struct sparse_m_double_complex), 0, 0,
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
    if (CharonSparseMake(&matrix, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, sizeof(struct sparse_m_float_complex), 0, 0,
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
    if (CharonSparseMake(&matrix, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, sizeof(struct sparse_m_double_complex), 0, 0,
                         (sparse_index)Mb, (sparse_index)Nb, K, L) != SPARSE_SUCCESS) {
        return NULL;
    }
    return (sparse_matrix_double_complex)matrix;
}

// ---------------------------------------------------------------- writing a matrix

sparse_status sparse_insert_entry_float_complex(sparse_matrix_float_complex A, float _Complex val, sparse_index i,
                                                sparse_index j)
{
    return CharonSparsePutEntryComplex(A, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, __real__ val, __imag__ val, i, j,
                                       sizeof(float _Complex));
}

sparse_status sparse_insert_entry_double_complex(sparse_matrix_double_complex A, double _Complex val, sparse_index i,
                                                 sparse_index j)
{
    return CharonSparsePutEntryComplex(A, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, __real__ val, __imag__ val, i, j,
                                       sizeof(double _Complex));
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
        sparse_status put = CharonSparsePutEntryComplex(A, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, __real__ val[k],
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
    if (!CharonSparseIsDoubleComplex(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    for (sparse_dimension k = 0; k < N; k++) {
        sparse_status put = CharonSparsePutEntryComplex(A, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, __real__ val[k],
                                                        __imag__ val[k], indx[k], jndx[k], sizeof(double _Complex));
        if (put != SPARSE_SUCCESS) {
            return put;
        }
    }
    return SPARSE_SUCCESS;
}

// A column of a point-wise matrix, and a row of one, both appended and overwriting what is there: the
// same rule the real entry points follow, and measured the same way on the host for the complex ones -
// inserting into a column that already holds values raises the matrix's nonzero count rather than
// replacing the column, and an entry written twice is counted once.
sparse_status sparse_insert_col_float_complex(sparse_matrix_float_complex A, sparse_index j, sparse_dimension nz,
                                              const float _Complex *__restrict val,
                                              const sparse_index *__restrict indx)
{
    if (!CharonSparseIsFloatComplex(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    for (sparse_dimension k = 0; k < nz; k++) {
        sparse_status put = CharonSparsePutEntryComplex(A, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, __real__ val[k],
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
    if (!CharonSparseIsDoubleComplex(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    for (sparse_dimension k = 0; k < nz; k++) {
        sparse_status put = CharonSparsePutEntryComplex(A, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, __real__ val[k],
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
    if (!CharonSparseIsFloatComplex(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    for (sparse_dimension k = 0; k < nz; k++) {
        sparse_status put = CharonSparsePutEntryComplex(A, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, __real__ val[k],
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
    if (!CharonSparseIsDoubleComplex(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    for (sparse_dimension k = 0; k < nz; k++) {
        sparse_status put = CharonSparsePutEntryComplex(A, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, __real__ val[k],
                                                        __imag__ val[k], i, jndx[k], sizeof(double _Complex));
        if (put != SPARSE_SUCCESS) {
            return put;
        }
    }
    return SPARSE_SUCCESS;
}

// A block entry of a block matrix: the k x l values at block index (bi, bj), read at the strides the
// caller gives, written to the k x l elements of the matrix the block covers. A block index outside the
// matrix is SPARSE_ILLEGAL_PARAMETER, and a scalar entry into a block matrix and a block entry into a
// point-wise one are both refused, all measured on the host.
static sparse_status CharonSparsePutBlockComplex(void *matrix, uint32_t magic, const void *val,
                                                 sparse_dimension rowStride, sparse_dimension colStride, sparse_index bi,
                                                 sparse_index bj, size_t size)
{
    struct sparse_m_float *asFloat = NULL;
    sparse_status ready = CharonSparseWritable(matrix, magic, 1, &asFloat);
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
            CharonSparseReadComplexValue(val, (sparse_index)(i * rowStride + j * colStride), size, &re, &im);
            sparse_index before = asFloat->row[first + i].count;
            sparse_status put = CharonSparsePutComplex(&asFloat->row[first + i], left + j, re, im, size);
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
    return CharonSparsePutBlockComplex(A, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, val, row_stride, col_stride, bi, bj,
                                       sizeof(float _Complex));
}

sparse_status sparse_insert_block_double_complex(sparse_matrix_double_complex A, const double _Complex *__restrict val,
                                                 sparse_dimension row_stride, sparse_dimension col_stride,
                                                 sparse_index bi, sparse_index bj)
{
    return CharonSparsePutBlockComplex(A, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, val, row_stride, col_stride, bi, bj,
                                       sizeof(double _Complex));
}

// ---------------------------------------------------------------- reading a matrix

// The first nz stored entries of a row from column_start onwards, and the column of the next one: the
// row extraction of the real family, over the complex values, with the same answer for column_end and
// the same refusals (measured on the host for the complex type: from column_start = 2 the indices
// written are the absolute columns 2 and 3, column_end is the column of the next stored entry or the
// number of columns, and a row, a column_start outside the matrix or a negative one all answer
// SPARSE_ILLEGAL_PARAMETER).
static long CharonSparseExtractRowComplex(void *matrix, uint32_t magic, sparse_index row, sparse_index columnStart,
                                          sparse_index *columnEnd, sparse_dimension nz, void *val, sparse_index *jndx,
                                          size_t size)
{
    if (!CharonSparseIsMatrix(matrix, magic) || !columnEnd) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    struct sparse_m_float *asFloat = (struct sparse_m_float *)matrix;
    if (row < 0 || columnStart < 0 || row >= (sparse_index)asFloat->rows || columnStart >= (sparse_index)asFloat->columns ||
        asFloat->blockRows > 0) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    const CharonSparseRow *source = &asFloat->row[row];
    sparse_index at = CharonSparseSearch(source, columnStart);
    sparse_dimension written = 0;
    while (at < source->count && written < nz) {
        if (val) {
            double re = 0.0, im = 0.0;
            CharonSparseReadComplexValue(source->value, at, size, &re, &im);
            CharonSparseWriteComplexValue(val, written, re, im, size);
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
    return (sparse_status)CharonSparseExtractRowComplex(A, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, row, column_start,
                                                        column_end, nz, val, jndx, sizeof(float _Complex));
}

sparse_status sparse_extract_sparse_row_double_complex(sparse_matrix_double_complex A, sparse_index row,
                                                       sparse_index column_start, sparse_index *column_end,
                                                       sparse_dimension nz, double _Complex *__restrict val,
                                                       sparse_index *__restrict jndx)
{
    return (sparse_status)CharonSparseExtractRowComplex(A, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, row, column_start,
                                                        column_end, nz, val, jndx, sizeof(double _Complex));
}

// The first nz stored entries of a column from row_start onwards, and the row of the next one: the
// transpose of the row extraction, with the same refusals.
static long CharonSparseExtractColumnComplex(void *matrix, uint32_t magic, sparse_index column, sparse_index rowStart,
                                             sparse_index *rowEnd, sparse_dimension nz, void *val, sparse_index *jndx,
                                             size_t size)
{
    if (!CharonSparseIsMatrix(matrix, magic) || !rowEnd) {
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
        const CharonSparseRow *source = &asFloat->row[i];
        sparse_index at = CharonSparseSearch(source, column);
        if (at >= source->count || source->column[at] != column) {
            continue;
        }
        if (val) {
            double re = 0.0, im = 0.0;
            CharonSparseReadComplexValue(source->value, at, size, &re, &im);
            CharonSparseWriteComplexValue(val, written, re, im, size);
        }
        if (jndx) {
            jndx[written] = i;
        }
        written++;
        last = i;
    }
    sparse_index next = (sparse_index)asFloat->rows;
    for (sparse_index i = last + 1; i < (sparse_index)asFloat->rows; i++) {
        sparse_index at = CharonSparseSearch(&asFloat->row[i], column);
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
    return (sparse_status)CharonSparseExtractColumnComplex(A, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, column, row_start,
                                                          row_end, nz, val, indx, sizeof(float _Complex));
}

sparse_status sparse_extract_sparse_column_double_complex(sparse_matrix_double_complex A, sparse_index column,
                                                          sparse_index row_start, sparse_index *row_end,
                                                          sparse_dimension nz, double _Complex *__restrict val,
                                                          sparse_index *__restrict indx)
{
    return (sparse_status)CharonSparseExtractColumnComplex(A, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, column, row_start,
                                                          row_end, nz, val, indx, sizeof(double _Complex));
}

// The k x l values of block (bi, bj), read at the strides the caller gives, written to val. A block
// that was never inserted reads as zeros, and a point-wise matrix and a block index outside the matrix
// answer SPARSE_ILLEGAL_PARAMETER, all measured on the host.
static sparse_status CharonSparseExtractBlockComplex(void *matrix, uint32_t magic, sparse_index bi, sparse_index bj,
                                                     sparse_dimension rowStride, sparse_dimension colStride, void *val,
                                                     size_t size)
{
    struct sparse_m_float *asFloat = NULL;
    sparse_status ready = CharonSparseWritable(matrix, magic, 1, &asFloat);
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
            CharonSparseElementComplexAt(&asFloat->row[first + i], left + j, size, &re, &im);
            CharonSparseWriteComplexValue(val, (sparse_index)(i * rowStride + j * colStride), re, im, size);
        }
    }
    return SPARSE_SUCCESS;
}

sparse_status sparse_extract_block_float_complex(sparse_matrix_float_complex A, sparse_index bi, sparse_index bj,
                                                 sparse_dimension row_stride, sparse_dimension col_stride,
                                                 float _Complex *__restrict val)
{
    return CharonSparseExtractBlockComplex(A, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, bi, bj, row_stride, col_stride, val,
                                           sizeof(float _Complex));
}

sparse_status sparse_extract_block_double_complex(sparse_matrix_double_complex A, sparse_index bi, sparse_index bj,
                                                  sparse_dimension row_stride, sparse_dimension col_stride,
                                                  double _Complex *__restrict val)
{
    return CharonSparseExtractBlockComplex(A, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, bi, bj, row_stride, col_stride, val,
                                           sizeof(double _Complex));
}

// ---------------------------------------------------------------- level 1

// The inner product of a sparse vector and a dense one, in the caller's order, and of two sparse ones.
//
// It does not conjugate, and that is a measurement and not an oversight: for x = {3+4i, 1} and
// y = {1+i, 2} the host answers 1+7i, which is x.y term by term, and 9-i is what conj(x).y gives. So
// the value is the bilinear form and not the Hermitian one, on both this and the two sparse-sparse
// forms, and the difference is a caller's whole problem when it matters.
static CharonComplex CharonSparseInnerDenseComplex(sparse_dimension nz, const void *x, const sparse_index *indx,
                                                   const void *y, sparse_stride incy, size_t size)
{
    CharonComplex sum = CharonComplexMake(0.0, 0.0);
    if (nz == 0) {
        return sum;
    }
    for (sparse_dimension k = 0; k < nz; k++) {
        double xre = 0.0, xim = 0.0, yre = 0.0, yim = 0.0;
        CharonSparseReadComplexValue(x, k, size, &xre, &xim);
        CharonSparseReadComplexValue(y, (sparse_index)(indx[k] * incy), size, &yre, &yim);
        sum = CharonComplexAdd(sum, CharonComplexMul(CharonComplexMake(xre, xim), CharonComplexMake(yre, yim)));
    }
    return sum;
}

float _Complex sparse_inner_product_dense_float_complex(sparse_dimension nz, const float _Complex *__restrict x,
                                                        const sparse_index *__restrict indx,
                                                        const float _Complex *__restrict y, sparse_stride incy)
{
    CharonComplex sum = CharonSparseInnerDenseComplex(nz, x, indx, y, incy, sizeof(float _Complex));
    return CharonComplexAsFloat(sum);
}

double _Complex sparse_inner_product_dense_double_complex(sparse_dimension nz, const double _Complex *__restrict x,
                                                          const sparse_index *__restrict indx,
                                                          const double _Complex *__restrict y, sparse_stride incy)
{
    CharonComplex sum = CharonSparseInnerDenseComplex(nz, x, indx, y, incy, sizeof(double _Complex));
    return CharonComplexAsDouble(sum);
}

// The inner product of two sparse vectors: a walk of the two index runs against each other. A count of
// zero on either side answers zero, measured on the host for the complex type as for the real one.
static CharonComplex CharonSparseInnerSparseComplex(sparse_dimension nzx, sparse_dimension nzy, const void *x,
                                                    const sparse_index *indx, const void *y, const sparse_index *indy,
                                                    size_t size)
{
    CharonComplex sum = CharonComplexMake(0.0, 0.0);
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
            CharonSparseReadComplexValue(x, i, size, &lre, &lim);
            CharonSparseReadComplexValue(y, j, size, &rre, &rim);
            sum = CharonComplexAdd(sum, CharonComplexMul(CharonComplexMake(lre, lim), CharonComplexMake(rre, rim)));
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
    CharonComplex sum = CharonSparseInnerSparseComplex(nzx, nzy, x, indx, y, indy, sizeof(float _Complex));
    return CharonComplexAsFloat(sum);
}

double _Complex sparse_inner_product_sparse_double_complex(sparse_dimension nzx, sparse_dimension nzy,
                                                            const double _Complex *__restrict x,
                                                            const sparse_index *__restrict indx,
                                                            const double _Complex *__restrict y,
                                                            const sparse_index *__restrict indy)
{
    CharonComplex sum = CharonSparseInnerSparseComplex(nzx, nzy, x, indx, y, indy, sizeof(double _Complex));
    return CharonComplexAsDouble(sum);
}

// y = alpha * x + y for a sparse x, one stored entry at a time. An alpha of exactly zero or a count of
// zero leaves y as it was, measured on the host for the complex type as for the real one.
static void CharonSparseAddScaleComplex(sparse_dimension nz, CharonComplex alpha, const void *x, const sparse_index *indx,
                                        void *y, sparse_stride incy, size_t size)
{
    if (nz == 0 || CharonComplexIsZero(alpha)) {
        return;
    }
    for (sparse_dimension k = 0; k < nz; k++) {
        double re = 0.0, im = 0.0;
        CharonSparseReadComplexValue(x, k, size, &re, &im);
        sparse_index at = (sparse_index)(indx[k] * incy);
        double yre = 0.0, yim = 0.0;
        CharonSparseReadComplexValue(y, at, size, &yre, &yim);
        CharonComplex sum = CharonComplexAdd(CharonComplexMake(yre, yim),
                                             CharonComplexMul(alpha, CharonComplexMake(re, im)));
        CharonSparseWriteComplexValue(y, at, sum.re, sum.im, size);
    }
}

void sparse_vector_add_with_scale_dense_float_complex(sparse_dimension nz, float _Complex alpha,
                                                      const float _Complex *__restrict x,
                                                      const sparse_index *__restrict indx,
                                                      float _Complex *__restrict y, sparse_stride incy)
{
    CharonSparseAddScaleComplex(nz, CharonComplexMake(__real__ alpha, __imag__ alpha), x, indx, y, incy,
                                sizeof(float _Complex));
}

void sparse_vector_add_with_scale_dense_double_complex(sparse_dimension nz, double _Complex alpha,
                                                       const double _Complex *__restrict x,
                                                       const sparse_index *__restrict indx,
                                                       double _Complex *__restrict y, sparse_stride incy)
{
    CharonSparseAddScaleComplex(nz, CharonComplexMake(__real__ alpha, __imag__ alpha), x, indx, y, incy,
                                sizeof(double _Complex));
}

// The three norms of a sparse vector, over the values the header gives them to be measured on.
//
// The one norm is the sum of the parts of each value and not the sum of the moduli, which is the one
// place where this family is not the real family's arithmetic: measured on the host, for the values
// {3+4i, 1} the one norm answers 8 - 3 + 4 and then 1 - where the sum of the moduli is 5 + 1 = 6. The
// two norm and the infinity norm are over the moduli: the same vector answers sqrt(26) and 5.
//
// The two fallbacks are the real family's, measured on the host for the complex type as well: a norm
// the enumeration does not name is answered as SPARSE_NORM_INF, and SPARSE_NORM_R1 - which the header
// says a vector does not support - is answered as SPARSE_NORM_TWO. A count of zero answers 0 for all
// three.
static double CharonSparseVectorNormComplex(sparse_dimension nz, const void *x, const sparse_index *indx, sparse_norm norm,
                                            size_t size)
{
    if (nz == 0) {
        return 0.0;
    }
    if (norm == SPARSE_NORM_ONE) {
        double sum = 0.0;
        for (sparse_dimension k = 0; k < nz; k++) {
            double re = 0.0, im = 0.0;
            CharonSparseReadComplexValue(x, k, size, &re, &im);
            sum += CharonComplexPartSum(CharonComplexMake(re, im));
        }
        return sum;
    }
    if (norm == SPARSE_NORM_TWO || norm == SPARSE_NORM_R1) {
        double sum = 0.0;
        for (sparse_dimension k = 0; k < nz; k++) {
            double re = 0.0, im = 0.0;
            CharonSparseReadComplexValue(x, k, size, &re, &im);
            double magnitude = CharonComplexModulus(CharonComplexMake(re, im));
            sum += magnitude * magnitude;
        }
        return sqrt(sum);
    }
    double largest = 0.0;
    for (sparse_dimension k = 0; k < nz; k++) {
        double re = 0.0, im = 0.0;
        CharonSparseReadComplexValue(x, k, size, &re, &im);
        double magnitude = CharonComplexModulus(CharonComplexMake(re, im));
        if (magnitude > largest) {
            largest = magnitude;
        }
    }
    return largest;
}

float sparse_vector_norm_float_complex(sparse_dimension nz, const float _Complex *__restrict x,
                                       const sparse_index *__restrict indx, sparse_norm norm)
{
    return (float)CharonSparseVectorNormComplex(nz, x, indx, norm, sizeof(float _Complex));
}

double sparse_vector_norm_double_complex(sparse_dimension nz, const double _Complex *__restrict x,
                                         const sparse_index *__restrict indx, sparse_norm norm)
{
    return CharonSparseVectorNormComplex(nz, x, indx, norm, sizeof(double _Complex));
}

// ---------------------------------------------------------------- the vector utilities

// The elements a strided dense vector has: the N of them at base + i * incx. A value is nonzero when
// neither of its parts is, which is what the count below counts and what the host's own count counts:
// measured, a vector of {0, 1i, 2} has two nonzero elements and not one.
static long CharonSparseVectorNonzeroComplex(sparse_dimension N, const void *x, sparse_stride incx, size_t size)
{
    if (N == 0) {
        return 0;
    }
    long count = 0;
    for (sparse_dimension i = 0; i < N; i++) {
        double re = 0.0, im = 0.0;
        CharonSparseReadComplexValue(x, (sparse_index)(i * incx), size, &re, &im);
        if (!CharonComplexIsZero(CharonComplexMake(re, im))) {
            count++;
        }
    }
    return count;
}

long sparse_get_vector_nonzero_count_float_complex(sparse_dimension N, const float _Complex *__restrict x,
                                                   sparse_stride incx)
{
    return CharonSparseVectorNonzeroComplex(N, x, incx, sizeof(float _Complex));
}

long sparse_get_vector_nonzero_count_double_complex(sparse_dimension N, const double _Complex *__restrict x,
                                                    sparse_stride incx)
{
    return CharonSparseVectorNonzeroComplex(N, x, incx, sizeof(double _Complex));
}

// The first nz nonzero elements of a dense vector, with their indices, and how many there were: the
// real family's rule, measured the same way on the host for the complex type - fewer nonzeros than nz
// leaves the tail of both arrays untouched and the count is what was written, and a count of nz or an N
// of zero writes nothing.
static long CharonSparsePackComplex(sparse_dimension N, sparse_dimension nz, const void *x, sparse_stride incx, void *y,
                                     sparse_index *indy, size_t size)
{
    if (N == 0 || nz == 0) {
        return 0;
    }
    long written = 0;
    for (sparse_dimension i = 0; i < N && (sparse_dimension)written < nz; i++) {
        double re = 0.0, im = 0.0;
        CharonSparseReadComplexValue(x, (sparse_index)(i * incx), size, &re, &im);
        if (CharonComplexIsZero(CharonComplexMake(re, im))) {
            continue;
        }
        if (y) {
            CharonSparseWriteComplexValue(y, written, re, im, size);
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
    return CharonSparsePackComplex(N, nz, x, incx, y, indy, sizeof(float _Complex));
}

long sparse_pack_vector_double_complex(sparse_dimension N, sparse_dimension nz, const double _Complex *__restrict x,
                                       sparse_stride incx, double _Complex *__restrict y, sparse_index *__restrict indy)
{
    return CharonSparsePackComplex(N, nz, x, incx, y, indy, sizeof(double _Complex));
}

// The entries of a sparse vector written into a dense one, optionally zeroing the rest. The zeroing walk
// visits the strided elements only - the padding between them is left alone, measured - and an index
// at or past N is not written, also measured: it is not an error, and the element it names is left as
// the zeroing left it.
static void CharonSparseUnpackComplex(sparse_dimension N, sparse_dimension nz, bool zero, const void *x,
                                      const sparse_index *indx, void *y, sparse_stride incy, size_t size)
{
    if (zero) {
        for (sparse_dimension i = 0; i < N; i++) {
            CharonSparseWriteComplexValue(y, (sparse_index)(i * incy), 0.0, 0.0, size);
        }
    }
    for (sparse_dimension k = 0; k < nz; k++) {
        if (indx[k] < 0 || indx[k] >= (sparse_index)N) {
            continue;
        }
        double re = 0.0, im = 0.0;
        CharonSparseReadComplexValue(x, k, size, &re, &im);
        CharonSparseWriteComplexValue(y, (sparse_index)(indx[k] * incy), re, im, size);
    }
}

void sparse_unpack_vector_float_complex(sparse_dimension N, sparse_dimension nz, bool zero,
                                        const float _Complex *__restrict x, const sparse_index *__restrict indx,
                                        float _Complex *__restrict y, sparse_stride incy)
{
    CharonSparseUnpackComplex(N, nz, zero, x, indx, y, incy, sizeof(float _Complex));
}

void sparse_unpack_vector_double_complex(sparse_dimension N, sparse_dimension nz, bool zero,
                                         const double _Complex *__restrict x, const sparse_index *__restrict indx,
                                         double _Complex *__restrict y, sparse_stride incy)
{
    CharonSparseUnpackComplex(N, nz, zero, x, indx, y, incy, sizeof(double _Complex));
}

// ---------------------------------------------------------------- level 2

// The two kernels the products below are made of: a multiply-add over n elements of a dense vector at an
// element offset with the caller's increments, and a gather of n elements of a dense row.
//
// Both are the release's own: cblas_caxpy / cblas_zaxpy for the multiply-add and cblas_ccopy /
// cblas_zcopy for the gather. That is the same choice the real family makes with cblas_saxpy /
// cblas_daxpy and for the same reason - the arithmetic belongs to the BLAS the release exports, not to a
// loop of ours. A complex alpha is measured to be done properly by all four: on the host, with
// alpha = 2+i and the vector element 3+4i, cblas_caxpy and cblas_zaxpy both answer 2+11i, and with
// alpha = 0+i both answer -4+3i, each of them the product (facts/Accelerate/SparseComplex.md).
//
// from and to count elements of the caller's vector and incX and incY are its increments, so one body
// serves both layouts: the level-3 kernel below hands the leading dimension of B and of C as their
// increments, which is what makes a column-major C step by ldc and not by one.
//
// An increment of zero or a negative one is never handed here: the level-2 kernel folds its increments
// into the addresses itself and passes one for both, exactly as the real family does and for the reason
// its comment gives - measured on the host, cblas_saxpy with an increment that is not positive treats it
// as one, so an increment of that shape cannot be given to a BLAS at all.
static void CharonComplexAxpy(long n, CharonComplex alpha, const void *x, long from, long incX, void *y, long to,
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

static void CharonComplexCopy(long n, const void *b, long from, long inc, void *row, size_t size)
{
    if (size == sizeof(float _Complex)) {
        cblas_ccopy((int)n, (const float *)b + from * 2, (int)inc, row, 1);
    } else {
        cblas_zcopy((int)n, (const double *)b + from * 2, (int)inc, row, 1);
    }
}

// y = alpha * op(A) * x + y. One entry of the matrix at a time, the sparse level-2 kernel, with the
// multiply-add the release's own cblas_caxpy / cblas_zaxpy over the single product. A transpose the
// enumeration does not name is SPARSE_ILLEGAL_PARAMETER and y is left alone.
static sparse_status CharonSparseVectorProductComplex(void *matrix, uint32_t magic, int transposed, CharonComplex alpha,
                                                      const void *x, sparse_stride incx, void *y, sparse_stride incy,
                                                      size_t size)
{
    if (!CharonSparseIsMatrix(matrix, magic)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    const struct sparse_m_float *asFloat = (const struct sparse_m_float *)matrix;
    sparse_dimension inner = transposed ? asFloat->rows : asFloat->columns;
    sparse_dimension outer = transposed ? asFloat->columns : asFloat->rows;
    for (sparse_dimension i = 0; i < outer; i++) {
        for (sparse_dimension k = 0; k < inner; k++) {
            double re = 0.0, im = 0.0;
            CharonSparseElementComplexAt(&asFloat->row[transposed ? k : i], transposed ? i : k, size, &re, &im);
            if (CharonComplexIsZero(CharonComplexMake(re, im))) {
                continue;
            }
            CharonComplexAxpy(1, CharonComplexMul(alpha, CharonComplexMake(re, im)), x, (long)(k * incx), 1, y,
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
    return CharonSparseVectorProductComplex(A, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, transa == CblasTrans,
                                           CharonComplexMake(__real__ alpha, __imag__ alpha), x, incx, y, incy,
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
    return CharonSparseVectorProductComplex(A, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, transa == CblasTrans,
                                           CharonComplexMake(__real__ alpha, __imag__ alpha), x, incx, y, incy,
                                           sizeof(double _Complex));
}

// The triangular solve, over the stored entries, which is the reason a caller reached for a sparse
// matrix at all: O(nnz) rather than the O(n^2) a dense cblas_ctrsv would spend.
//
// Two rules, and both of them the real family's, measured the same way on the host. A matrix with no
// triangular property is refused and the vector is left alone. And alpha DIVIDES the right-hand side
// rather than scaling the solution: measured on the host for the complex type, the lower triangular
// [[2,0,0],[1,3,0],[0,0,4]] against (2, 5, 4) answers (0.5, 0.666667) for the first two elements at
// alpha = 2, which is the solution of T x = b / alpha and not of T x = alpha b. The third element is
// where the host's own answer is not reproducible and is named in facts/Accelerate/SparseComplex.md;
// the port divides and does what the arithmetic says.
//
// A pivot of exactly zero divides, so both parts become a NaN, which is what the host gives: measured,
// the lower [[0,0],[0,1]] against (1,1) answers a NaN in both parts of both elements.
static sparse_status CharonSparseTriangularComplex(void *matrix, uint32_t magic, int transposed, CharonComplex alpha,
                                                   void *b, long iStep, long rightStep, sparse_dimension nrhs, size_t size)
{
    if (!CharonSparseIsMatrix(matrix, magic)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    const struct sparse_m_float *asFloat = (const struct sparse_m_float *)matrix;
    if (!(asFloat->property & (SPARSE_UPPER_TRIANGULAR | SPARSE_LOWER_TRIANGULAR))) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    // A transposed triangular matrix is the other triangle, read out of the matrix's own storage, and
    // the transposed case builds the column lists once so that the whole solve stays O(nnz).
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
                sparse_index at = CharonSparseSearch(&asFloat->row[r], (sparse_index)i);
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
            CharonSparseReadComplexValue(b, (sparse_index)here, size, &re, &im);
            CharonComplex value = CharonComplexDiv(CharonComplexMake(re, im), alpha);
            if (!transposed) {
                for (sparse_index at = 0; at < asFloat->row[i].count; at++) {
                    sparse_index j = asFloat->row[i].column[at];
                    if (j == (sparse_index)i || (j < (sparse_index)i) == backwards) {
                        continue; // the diagonal, or the triangle the caller did not declare
                    }
                    double otherRe = 0.0, otherIm = 0.0;
                    CharonSparseReadComplexValue(asFloat->row[i].value, at, size, &otherRe, &otherIm);
                    double addRe = 0.0, addIm = 0.0;
                    CharonSparseReadComplexValue(b, (sparse_index)((long)j * iStep + (long)right * rightStep), size, &addRe,
                                                 &addIm);
                    value = CharonComplexSub(value, CharonComplexMul(CharonComplexMake(otherRe, otherIm),
                                                                    CharonComplexMake(addRe, addIm)));
                }
            } else {
                sparse_index from = offsets[i], to = offsets[i + 1];
                for (sparse_index k = from; k < to; k++) {
                    sparse_index j = lists[k];
                    if (j == (sparse_index)i || (j < (sparse_index)i) == backwards) {
                        continue;
                    }
                    double otherRe = 0.0, otherIm = 0.0;
                    CharonSparseElementComplexAt(&asFloat->row[j], (sparse_index)i, size, &otherRe, &otherIm);
                    double addRe = 0.0, addIm = 0.0;
                    CharonSparseReadComplexValue(b, (sparse_index)((long)j * iStep + (long)right * rightStep), size, &addRe,
                                                 &addIm);
                    value = CharonComplexSub(value, CharonComplexMul(CharonComplexMake(otherRe, otherIm),
                                                                    CharonComplexMake(addRe, addIm)));
                }
            }
            double pivotRe = 0.0, pivotIm = 0.0;
            CharonSparseElementComplexAt(&asFloat->row[i], i, size, &pivotRe, &pivotIm);
            CharonComplex solved = CharonComplexDiv(value, CharonComplexMake(pivotRe, pivotIm));
            CharonSparseWriteComplexValue(b, (sparse_index)here, solved.re, solved.im, size);
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
    return CharonSparseTriangularComplex(T, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, transt == CblasTrans,
                                        CharonComplexMake(__real__ alpha, __imag__ alpha), x, incx, 0, 1,
                                        sizeof(float _Complex));
}

sparse_status sparse_vector_triangular_solve_dense_double_complex(enum CBLAS_TRANSPOSE transt, double _Complex alpha,
                                                                  sparse_matrix_double_complex T,
                                                                  double _Complex *__restrict x, sparse_stride incx)
{
    if (transt != CblasNoTrans && transt != CblasTrans) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    return CharonSparseTriangularComplex(T, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, transt == CblasTrans,
                                        CharonComplexMake(__real__ alpha, __imag__ alpha), x, incx, 0, 1,
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
    if (!CharonSparseIsFloatComplex(T)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    const struct sparse_m_float *asFloat = (const struct sparse_m_float *)T;
    sparse_dimension needed = order == CblasRowMajor ? (nrhs ? nrhs : 1) : (asFloat->rows ? asFloat->rows : 1);
    if (ldb < needed) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    return CharonSparseTriangularComplex(T, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, transt == CblasTrans,
                                        CharonComplexMake(__real__ alpha, __imag__ alpha), B,
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
    if (!CharonSparseIsDoubleComplex(T)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    const struct sparse_m_float *asFloat = (const struct sparse_m_float *)T;
    sparse_dimension needed = order == CblasRowMajor ? (nrhs ? nrhs : 1) : (asFloat->rows ? asFloat->rows : 1);
    if (ldb < needed) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    return CharonSparseTriangularComplex(T, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, transt == CblasTrans,
                                        CharonComplexMake(__real__ alpha, __imag__ alpha), B,
                                        order == CblasRowMajor ? (long)ldb : 1, order == CblasRowMajor ? 1 : (long)ldb,
                                        nrhs, sizeof(double _Complex));
}

// ---------------------------------------------------------------- level 3

// C = alpha * op(A) * B + C, with B dense. One stored entry of op(A) at a time: the release's own
// cblas_ccopy gathers the row of B the entry names and cblas_caxpy adds alpha times the entry's value
// times it to the row of C - the sparse level-3 kernel, one rank-one update per nonzero.
//
// What is refused, measured on the host for the complex type as for the real one: an order or a
// transpose the enumeration does not name, a leading dimension below what the layout needs, and a
// matrix that is not one of ours, each SPARSE_ILLEGAL_PARAMETER with C untouched. A count of columns
// of zero and an alpha of exactly zero both answer SPARSE_SUCCESS and leave C as it was.
static sparse_status CharonSparseProductDenseComplex(void *matrix, uint32_t magic, int order, int transposed,
                                                      sparse_dimension n, CharonComplex alpha, const void *B,
                                                      sparse_dimension ldb, void *C, sparse_dimension ldc, size_t size)
{
    if (order != CblasRowMajor && order != CblasColMajor) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    if (!CharonSparseIsMatrix(matrix, magic)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    const struct sparse_m_float *asFloat = (const struct sparse_m_float *)matrix;
    sparse_dimension m = transposed ? asFloat->columns : asFloat->rows;
    sparse_dimension k = transposed ? asFloat->rows : asFloat->columns;
    // The two increments of the caller's layout: a row of B steps by one in row-major and by ldb in
    // column-major, and so does a row of C, which is what CharonComplexAxpy and CharonComplexCopy take.
    sparse_dimension bStep = order == CblasRowMajor ? 1 : ldb;
    sparse_dimension cStep = order == CblasRowMajor ? 1 : ldc;
    if (ldb < (order == CblasRowMajor ? (n ? n : 1) : (k ? k : 1)) ||
        ldc < (order == CblasRowMajor ? (n ? n : 1) : (m ? m : 1))) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    if (n == 0 || CharonComplexIsZero(alpha)) {
        return SPARSE_SUCCESS;
    }
    void *row = malloc((size_t)(n ? n : 1) * size);
    if (!row) {
        return SPARSE_SYSTEM_ERROR;
    }
    for (sparse_dimension i = 0; i < m; i++) {
        const CharonSparseRow *line = transposed ? NULL : &asFloat->row[i];
        for (sparse_index at = 0; at < (transposed ? (sparse_index)asFloat->rows : line->count); at++) {
            sparse_index r = transposed ? at : (sparse_index)i;
            sparse_index c = transposed ? (sparse_index)i : line->column[at];
            if (c >= (sparse_index)asFloat->columns) {
                continue;
            }
            double re = 0.0, im = 0.0;
            CharonSparseElementComplexAt(&asFloat->row[r], c, size, &re, &im);
            if (CharonComplexIsZero(CharonComplexMake(re, im))) {
                continue;
            }
            long from = CharonSparseDenseAt(order, ldb, transposed ? r : c, 0);
            long to = CharonSparseDenseAt(order, ldc, i, 0);
            CharonComplexCopy((long)n, B, from, (long)bStep, row, size);
            CharonComplexAxpy((long)n, CharonComplexMul(alpha, CharonComplexMake(re, im)), row, 0, 1, C, to,
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
    return CharonSparseProductDenseComplex(A, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, order, transa == CblasTrans, n,
                                           CharonComplexMake(__real__ alpha, __imag__ alpha), B, ldb, C, ldc,
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
    return CharonSparseProductDenseComplex(A, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, order, transa == CblasTrans, n,
                                           CharonComplexMake(__real__ alpha, __imag__ alpha), B, ldb, C, ldc,
                                           sizeof(double _Complex));
}

// C = alpha * x * y' for a dense x and a sparse y, as a new matrix, and **x is indexed by the row and y
// by the column**, because C[i, j] = alpha * x[i] * y[k] for the k whose indy[k] is j: the outer product
// is a column of x scaled into a row. An earlier version read x at k and wrote the same value into every
// row, which answers the right number only where x is constant down its length; the host does not do that
// (measured, for M = N = 3, nz = 2, alpha = 1, x = {1, 2+i, -1} and y = {5+i, -6+2i} at the columns {0, 2}
// it answers C[0] = (9+7i, -14-2i), C[1] = (11+8i, -18-3i) and C[2] = (8+6i, -12+4i), which is
// alpha * x[i] * y[k] row by row), and the differential's case and its mutant are in
// tests/backports/host/sparseblas/differential-complex.m.
//
// A count of nonzeros above N is SPARSE_ILLEGAL_PARAMETER and the caller's matrix pointer is left alone,
// and a count of zero and an alpha of exactly zero both answer a matrix of the right shape with nothing in
// it, all measured on the host for the complex type as for the real one.
static sparse_status CharonSparseOuterComplex(sparse_dimension M, sparse_dimension N, sparse_dimension nz,
                                               CharonComplex alpha, const void *x, sparse_stride incx, const void *y,
                                               const sparse_index *indy, void **C, uint32_t magic, size_t size,
                                               size_t matrixSize)
{
    if (nz > N) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    void *matrix = NULL;
    if (CharonSparseMake(&matrix, magic, matrixSize, M, N, 0, 0, NULL, NULL) != SPARSE_SUCCESS) {
        return SPARSE_SYSTEM_ERROR;
    }
    struct sparse_m_float *asFloat = (struct sparse_m_float *)matrix;
    for (sparse_dimension k = 0; k < nz; k++) {
        double rightRe = 0.0, rightIm = 0.0;
        CharonSparseReadComplexValue(y, k, size, &rightRe, &rightIm);
        if (CharonComplexIsZero(alpha) || CharonComplexIsZero(CharonComplexMake(rightRe, rightIm))) {
            continue;
        }
        for (sparse_dimension i = 0; i < M; i++) {
            double leftRe = 0.0, leftIm = 0.0;
            CharonSparseReadComplexValue(x, (sparse_index)(i * incx), size, &leftRe, &leftIm);
            CharonComplex scaled = CharonComplexMul(alpha, CharonComplexMul(CharonComplexMake(leftRe, leftIm),
                                                                             CharonComplexMake(rightRe, rightIm)));
            if (CharonComplexIsZero(scaled)) {
                continue;
            }
            sparse_index before = asFloat->row[i].count;
            CharonSparsePutComplex(&asFloat->row[i], indy[k], scaled.re, scaled.im, size);
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
    return CharonSparseOuterComplex(M, N, nz, CharonComplexMake(__real__ alpha, __imag__ alpha), x, incx, y, indy,
                                    (void **)C, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, sizeof(float _Complex),
                                    sizeof(struct sparse_m_float_complex));
}

sparse_status sparse_outer_product_dense_double_complex(sparse_dimension M, sparse_dimension N, sparse_dimension nz,
                                                        double _Complex alpha, const double _Complex *__restrict x,
                                                        sparse_stride incx, const double _Complex *__restrict y,
                                                        const sparse_index *__restrict indy,
                                                        sparse_matrix_double_complex *__restrict C)
{
    return CharonSparseOuterComplex(M, N, nz, CharonComplexMake(__real__ alpha, __imag__ alpha), x, incx, y, indy,
                                    (void **)C, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, sizeof(double _Complex),
                                    sizeof(struct sparse_m_double_complex));
}

// C = alpha * op(A) * B + C with B sparse too, written out into a dense C: the complex counterpart of
// Accelerate/SparseProduct10.m, over the same storage and with the same refusals. The same rank-one
// update per nonzero, with the row of B taken from its own stored entries and the multiply-add the
// release's own cblas_caxpy / cblas_zaxpy.
//
// Note where the two families of this header put the same name. The real sparse-sparse product arrived
// in 10.0.1 and has an object file of its own because the release ladder measures it there while the
// other sixty-seven names of the real family are at 9.0 (facts/Accelerate/SparseBLAS.md). The complex
// ones did not exist before 18.5, all fifty-eight of them, so one object file holds all of them and no
// split is called for.
static sparse_status CharonSparseProductSparseComplex(void *A, uint32_t magicA, int order, int transposed,
                                                      CharonComplex alpha, void *B, uint32_t magicB, void *C,
                                                      sparse_dimension ldc, size_t size)
{
    if (order != CblasRowMajor && order != CblasColMajor) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    if (!CharonSparseIsMatrix(A, magicA) || !CharonSparseIsMatrix(B, magicB)) {
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
        const CharonSparseRow *line = transposed ? NULL : &asA->row[i];
        for (sparse_index at = 0; at < (transposed ? (sparse_index)asA->rows : line->count); at++) {
            sparse_index r = transposed ? at : (sparse_index)i;
            sparse_index c = transposed ? (sparse_index)i : line->column[at];
            if (c >= (sparse_index)asA->columns) {
                continue;
            }
            // A[r, c] in both cases, read through the same lookup the rest of the family uses.
            double valueRe = 0.0, valueIm = 0.0;
            CharonSparseElementComplexAt(&asA->row[r], c, size, &valueRe, &valueIm);
            if (CharonComplexIsZero(CharonComplexMake(valueRe, valueIm))) {
                continue;
            }
            memset(row, 0, (size_t)(n ? n : 1) * size);
            const CharonSparseRow *from = &asB->row[transposed ? r : c];
            for (sparse_index b = 0; b < from->count; b++) {
                if (from->column[b] < (sparse_index)n) {
                    double bre = 0.0, bim = 0.0;
                    CharonSparseReadComplexValue(from->value, b, size, &bre, &bim);
                    CharonSparseWriteComplexValue(row, from->column[b], bre, bim, size);
                }
            }
            long to = CharonSparseDenseAt(order, ldc, i, 0);
            for (sparse_dimension j = 0; j < n; j++) {
                double re = 0.0, im = 0.0;
                CharonSparseReadComplexValue(row, j, size, &re, &im);
                if (CharonComplexIsZero(CharonComplexMake(re, im))) {
                    continue;
                }
                // The gathered value is the vector and alpha times the entry's own value is the factor,
                // so the product is formed once and by the release's BLAS rather than here.
                CharonComplexAxpy(1, CharonComplexMul(alpha, CharonComplexMake(valueRe, valueIm)), row, j, 1, C,
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
    return CharonSparseProductSparseComplex(A, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, order, transa == CblasTrans,
                                           CharonComplexMake(__real__ alpha, __imag__ alpha), B,
                                           CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, C, ldc, sizeof(float _Complex));
}

sparse_status sparse_matrix_product_sparse_double_complex(enum CBLAS_ORDER order, enum CBLAS_TRANSPOSE transa,
                                                          double _Complex alpha, sparse_matrix_double_complex A,
                                                          sparse_matrix_double_complex B, double _Complex *__restrict C,
                                                          sparse_dimension ldc)
{
    if (transa != CblasNoTrans && transa != CblasTrans) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    return CharonSparseProductSparseComplex(A, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, order, transa == CblasTrans,
                                           CharonComplexMake(__real__ alpha, __imag__ alpha), B,
                                           CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, C, ldc, sizeof(double _Complex));
}

// ---------------------------------------------------------------- the permutations, the norms, the trace

// The two permutations below are CharonSparsePermuteRows and CharonSparsePermuteColumnsComplex, in
// CharonSparseBLAS.h, which SparseBLAS9.m runs over the same storage for the real types.

sparse_status sparse_permute_rows_float_complex(sparse_matrix_float_complex A, const sparse_index *__restrict perm)
{
    if (!CharonSparseIsFloatComplex(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    CharonSparsePermuteRows((struct sparse_m_float *)A, perm);
    return SPARSE_SUCCESS;
}

sparse_status sparse_permute_rows_double_complex(sparse_matrix_double_complex A, const sparse_index *__restrict perm)
{
    if (!CharonSparseIsDoubleComplex(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    CharonSparsePermuteRows((struct sparse_m_float *)A, perm);
    return SPARSE_SUCCESS;
}

sparse_status sparse_permute_cols_float_complex(sparse_matrix_float_complex A, const sparse_index *__restrict perm)
{
    if (!CharonSparseIsFloatComplex(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    CharonSparsePermuteColumnsComplex((struct sparse_m_float *)A, perm, sizeof(float _Complex));
    return SPARSE_SUCCESS;
}

sparse_status sparse_permute_cols_double_complex(sparse_matrix_double_complex A, const sparse_index *__restrict perm)
{
    if (!CharonSparseIsDoubleComplex(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    // The element width, and not sizeof(float _Complex): this helper branches on it to read and write
    // every value, so a double's values passed as the float one were read and written half as many
    // bytes as they occupy.
    CharonSparsePermuteColumnsComplex((struct sparse_m_float *)A, perm, sizeof(double _Complex));
    return SPARSE_SUCCESS;
}

// The four elementwise norms of a matrix, over its stored entries. The one norm is the sum of the parts
// of the values and the two and the infinity norm are over their moduli, which is the same split the
// vector norms above have and is measured the same way. A norm the enumeration does not name is
// answered as SPARSE_NORM_INF, and an empty matrix answers zero for all four, both measured on the host.
static double CharonSparseElementwiseComplex(void *matrix, uint32_t magic, sparse_norm norm, size_t size)
{
    if (!CharonSparseIsMatrix(matrix, magic)) {
        return 0.0;
    }
    const struct sparse_m_float *asFloat = (const struct sparse_m_float *)matrix;
    if (norm == SPARSE_NORM_ONE) {
        double sum = 0.0;
        for (sparse_dimension i = 0; i < asFloat->rows; i++) {
            for (sparse_index at = 0; at < asFloat->row[i].count; at++) {
                double re = 0.0, im = 0.0;
                CharonSparseReadComplexValue(asFloat->row[i].value, at, size, &re, &im);
                sum += CharonComplexPartSum(CharonComplexMake(re, im));
            }
        }
        return sum;
    }
    if (norm == SPARSE_NORM_TWO) {
        double sum = 0.0;
        for (sparse_dimension i = 0; i < asFloat->rows; i++) {
            for (sparse_index at = 0; at < asFloat->row[i].count; at++) {
                double re = 0.0, im = 0.0;
                CharonSparseReadComplexValue(asFloat->row[i].value, at, size, &re, &im);
                double magnitude = CharonComplexModulus(CharonComplexMake(re, im));
                sum += magnitude * magnitude;
            }
        }
        return sqrt(sum);
    }
    if (norm == SPARSE_NORM_R1) {
        // sum over j of the modulus of column j: a square root per column, which is why the column
        // sums are kept apart.
        double total = 0.0;
        for (sparse_index j = 0; j < (sparse_index)asFloat->columns; j++) {
            double sum = 0.0;
            for (sparse_dimension i = 0; i < asFloat->rows; i++) {
                double re = 0.0, im = 0.0;
                CharonSparseElementComplexAt(&asFloat->row[i], j, size, &re, &im);
                double magnitude = CharonComplexModulus(CharonComplexMake(re, im));
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
            CharonSparseReadComplexValue(asFloat->row[i].value, at, size, &re, &im);
            double magnitude = CharonComplexModulus(CharonComplexMake(re, im));
            if (magnitude > largest) {
                largest = magnitude;
            }
        }
    }
    return largest;
}

float sparse_elementwise_norm_float_complex(sparse_matrix_float_complex A, sparse_norm norm)
{
    return (float)CharonSparseElementwiseComplex(A, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, norm, sizeof(float _Complex));
}

double sparse_elementwise_norm_double_complex(sparse_matrix_double_complex A, sparse_norm norm)
{
    return CharonSparseElementwiseComplex(A, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, norm, sizeof(double _Complex));
}

// The operator-one norm, the largest column sum, and the operator-infinity norm, the largest row sum:
// both over the parts of the values, as the elementwise one norm is. A matrix that is not one of ours,
// or an empty one, answers zero.
//
// The operator-two norm, the largest singular value, is the release's own LAPACK: the Hermitian Gram
// matrix A * A' formed here, and the largest of its eigenvalues read with cheev_ / zheev_. That is the
// same route the real entry points take through ssyev_ / dsyev_, and it is the exact answer: measured
// on the host for [[3+4i,0,0],[1,0,-2+i],[0,0,0]] it answers 5.12196, which is the square root of the
// larger root of t^2 - 31t + 125, the characteristic polynomial of A * A'.
//
// SPARSE_NORM_R1 is not supported for a matrix and answers NaN, measured on the host for the complex
// type as for the real one.
static double CharonSparseOperatorComplex(void *matrix, uint32_t magic, sparse_norm norm, size_t size)
{
    if (!CharonSparseIsMatrix(matrix, magic)) {
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
                CharonSparseElementComplexAt(&asFloat->row[i], j, size, &re, &im);
                sum += CharonComplexPartSum(CharonComplexMake(re, im));
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
                CharonSparseReadComplexValue(asFloat->row[i].value, at, size, &re, &im);
                sum += CharonComplexPartSum(CharonComplexMake(re, im));
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
    // A * A' as a dense m x m Hermitian matrix, and the largest of its eigenvalues through the
    // release's own LAPACK. A is taken conjugated on the right of the product, which is what makes the
    // Gram matrix Hermitian and the eigen-decomposition a real one: the element (i, k) is the sum over j
    // of A[i, j] * conj(A[k, j]). cheev_ and zheev_ read one triangle by default, which is the half the
    // product below fills, and both take the count and the leading dimension in the header's own
    // __CLPK_integer, which is a long int on the 32-bit target this library is built for.
    if (size == sizeof(float _Complex)) {
        __CLPK_complex *gram = (__CLPK_complex *)calloc((size_t)m * m, sizeof(__CLPK_complex));
        if (!gram) {
            return 0.0;
        }
        for (sparse_dimension i = 0; i < m; i++) {
            for (sparse_dimension k = 0; k < m; k++) {
                CharonComplex sum = CharonComplexMake(0.0, 0.0);
                for (sparse_index at = 0; at < asFloat->row[i].count; at++) {
                    sparse_index j = asFloat->row[i].column[at];
                    double re = 0.0, im = 0.0;
                    CharonSparseReadComplexValue(asFloat->row[i].value, at, size, &re, &im);
                    double otherRe = 0.0, otherIm = 0.0;
                    CharonSparseElementComplexAt(&asFloat->row[k], j, size, &otherRe, &otherIm);
                    sum = CharonComplexAdd(sum, CharonComplexMul(CharonComplexMake(re, im),
                                                                 CharonComplexMake(otherRe, -otherIm)));
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
                CharonComplex sum = CharonComplexMake(0.0, 0.0);
                for (sparse_index at = 0; at < asFloat->row[i].count; at++) {
                    sparse_index j = asFloat->row[i].column[at];
                    double re = 0.0, im = 0.0;
                    CharonSparseReadComplexValue(asFloat->row[i].value, at, size, &re, &im);
                    double otherRe = 0.0, otherIm = 0.0;
                    CharonSparseElementComplexAt(&asFloat->row[k], j, size, &otherRe, &otherIm);
                    sum = CharonComplexAdd(sum, CharonComplexMul(CharonComplexMake(re, im),
                                                                 CharonComplexMake(otherRe, -otherIm)));
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
    return (float)CharonSparseOperatorComplex(A, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, norm, sizeof(float _Complex));
}

double sparse_operator_norm_double_complex(sparse_matrix_double_complex A, sparse_norm norm)
{
    return CharonSparseOperatorComplex(A, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, norm, sizeof(double _Complex));
}

// The sum along one diagonal: A[i, i + offset] for an offset above the main one and A[i - offset, i]
// for one below, as a pair. An offset that names no element of the matrix answers a zero pair,
// measured, and so does a matrix that is not one of ours.
static CharonComplex CharonSparseTraceComplex(void *matrix, uint32_t magic, sparse_index offset, size_t size)
{
    CharonComplex sum = CharonComplexMake(0.0, 0.0);
    if (!CharonSparseIsMatrix(matrix, magic)) {
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
        CharonSparseElementComplexAt(&asFloat->row[row], column, size, &re, &im);
        sum = CharonComplexAdd(sum, CharonComplexMake(re, im));
    }
    return sum;
}

float _Complex sparse_matrix_trace_float_complex(sparse_matrix_float_complex A, sparse_index offset)
{
    CharonComplex sum = CharonSparseTraceComplex(A, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, offset, sizeof(float _Complex));
    return CharonComplexAsFloat(sum);
}

double _Complex sparse_matrix_trace_double_complex(sparse_matrix_double_complex A, sparse_index offset)
{
    CharonComplex sum = CharonSparseTraceComplex(A, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, offset, sizeof(double _Complex));
    return CharonComplexAsDouble(sum);
}
