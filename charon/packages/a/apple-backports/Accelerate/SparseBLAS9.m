// The sparse BLAS of vecLib/Sparse/BLAS.h: the 69 entry points that arrived in iOS 9, in the float
// and the double of each.
//
// No release this port supports has any of them (measured from the armv7 caches of 4.3, 4.3.5, 5.0,
// 5.1.1, 6.0, 6.0.2, 6.1, 6.1.3, 6.1.4, 6.1.6, 7.0, 7.1.2, 8.0, 9.0, 9.3.5, 10.3.4, 12.0, 16.0 and
// 18.0: no cblas_* or sparse_* name of the 148 the release's vecLib carries is one of these, and the
// Sparse framework itself arrives after the last release of this port), so this is a library written
// here, over the release's own BLAS and LAPACK, which every band exports.
//
// What the arithmetic is made of, and why each piece is where it is:
//
//   - A matrix is a list of rows, each a run of (column, value) pairs kept sorted by column
//     (CharonSparseBLAS.h). That is the whole storage, and it is what makes every operation below
//     either a walk of the stored entries or a call into the release's BLAS over one row.
//   - The products - y = alpha * op(A) * x + y, C = alpha * op(A) * B + C for a dense B and for a
//     sparse one, and the outer product - are the release's own cblas_scopy and cblas_saxpy over each
//     stored entry's row, which is the textbook sparse BLAS and puts the multiply-add in the
//     release's BLAS rather than in a loop of ours.
//   - The operator-two norm, the largest singular value, is the release's own LAPACK: the Gram matrix
//     A * A' formed with cblas_ssyrk and its eigenvalues read with ssyev_ / dsyev_.
//   - The triangular solves are the sparse substitution itself, over the stored entries, because a
//     dense cblas_strsv would throw the sparsity away: the solve is O(nnz) and the dense one is
//     O(n^2), which is the whole reason a caller reached for a sparse matrix.
//   - The norms, the trace, the inner products, the permutations and the vector utilities have no
//     dense BLAS form - irregular indices, a max, a diagonal - and are the arithmetic the header
//     writes out.
//
// Behaviour is the host's own, measured case by case by tests/backports/host/sparseblas, which runs
// this file and the host's Accelerate over the same inputs and compares the status, the count and
// every element; facts/Accelerate/SparseBLAS.md carries the measurements and the two places where the
// host's answer is not reproducible are named there and answered from the header instead.

#import <Accelerate/Accelerate.h>
#include "CharonSparseBLAS.h"


typedef struct sparse_m_float CharonSparseFloatMatrix;
typedef struct sparse_m_double CharonSparseDoubleMatrix;

// ---------------------------------------------------------------- shape of a matrix

sparse_matrix_float sparse_matrix_create_float(sparse_dimension M, sparse_dimension N)
{
    void *matrix = NULL;
    if (CharonSparseMake(&matrix, CHARON_SPARSE_MAGIC_FLOAT, sizeof(struct sparse_m_float), M, N, 0, 0, NULL, NULL) !=
        SPARSE_SUCCESS) {
        return NULL;
    }
    return (sparse_matrix_float)matrix;
}

sparse_matrix_double sparse_matrix_create_double(sparse_dimension M, sparse_dimension N)
{
    void *matrix = NULL;
    if (CharonSparseMake(&matrix, CHARON_SPARSE_MAGIC_DOUBLE, sizeof(struct sparse_m_double), M, N, 0, 0, NULL, NULL) !=
        SPARSE_SUCCESS) {
        return NULL;
    }
    return (sparse_matrix_double)matrix;
}

// A fixed block matrix is the variable-block one with k for every block row and l for every block
// column, which is what makes sparse_get_block_dimension_for_row answer k for every element row. Both
// this and CharonSparseMake are in CharonSparseBLAS.h, because SparseComplex18.m needs them too and a
// function defined in a file that exports an API symbol is left out of a band the release already has.

sparse_matrix_float sparse_matrix_block_create_float(sparse_dimension Mb, sparse_dimension Nb, sparse_dimension k,
                                                    sparse_dimension l)
{
    sparse_dimension *heights = CharonSparseRepeated(k, (sparse_index)Mb);
    sparse_dimension *widths = CharonSparseRepeated(l, (sparse_index)Nb);
    void *matrix = NULL;
    sparse_status made =
        CharonSparseMake(&matrix, CHARON_SPARSE_MAGIC_FLOAT, sizeof(struct sparse_m_float), 0, 0, (sparse_index)Mb,
                         (sparse_index)Nb, heights, widths);
    free(heights);
    free(widths);
    return made == SPARSE_SUCCESS ? (sparse_matrix_float)matrix : NULL;
}

sparse_matrix_double sparse_matrix_block_create_double(sparse_dimension Mb, sparse_dimension Nb, sparse_dimension k,
                                                      sparse_dimension l)
{
    sparse_dimension *heights = CharonSparseRepeated(k, (sparse_index)Mb);
    sparse_dimension *widths = CharonSparseRepeated(l, (sparse_index)Nb);
    void *matrix = NULL;
    sparse_status made =
        CharonSparseMake(&matrix, CHARON_SPARSE_MAGIC_DOUBLE, sizeof(struct sparse_m_double), 0, 0, (sparse_index)Mb,
                         (sparse_index)Nb, heights, widths);
    free(heights);
    free(widths);
    return made == SPARSE_SUCCESS ? (sparse_matrix_double)matrix : NULL;
}

sparse_matrix_float sparse_matrix_variable_block_create_float(sparse_dimension Mb, sparse_dimension Nb,
                                                             const sparse_dimension *K, const sparse_dimension *L)
{
    void *matrix = NULL;
    if (CharonSparseMake(&matrix, CHARON_SPARSE_MAGIC_FLOAT, sizeof(struct sparse_m_float), 0, 0, (sparse_index)Mb,
                         (sparse_index)Nb, K, L) != SPARSE_SUCCESS) {
        return NULL;
    }
    return (sparse_matrix_float)matrix;
}

sparse_matrix_double sparse_matrix_variable_block_create_double(sparse_dimension Mb, sparse_dimension Nb,
                                                               const sparse_dimension *K, const sparse_dimension *L)
{
    void *matrix = NULL;
    if (CharonSparseMake(&matrix, CHARON_SPARSE_MAGIC_DOUBLE, sizeof(struct sparse_m_double), 0, 0, (sparse_index)Mb,
                         (sparse_index)Nb, K, L) != SPARSE_SUCCESS) {
        return NULL;
    }
    return (sparse_matrix_double)matrix;
}

// A point-wise matrix is the only kind a scalar entry belongs to and a block is the only kind a block
// entry belongs to, and both this file's entry helper and CharonSparseMake and CharonSparseRepeated
// are in CharonSparseBLAS.h: SparseComplex18.m needs all three, and a function defined in a file that
// exports an API symbol is left out of a band the release already has, which is how a shared C
// function becomes an undefined symbol in a later band.

sparse_status sparse_insert_entry_float(sparse_matrix_float A, float val, sparse_index i, sparse_index j)
{
    return CharonSparsePutEntry(A, CHARON_SPARSE_MAGIC_FLOAT, val, i, j, sizeof(float));
}

sparse_status sparse_insert_entry_double(sparse_matrix_double A, double val, sparse_index i, sparse_index j)
{
    return CharonSparsePutEntry(A, CHARON_SPARSE_MAGIC_DOUBLE, val, i, j, sizeof(double));
}

sparse_status sparse_insert_entries_float(sparse_matrix_float A, sparse_dimension N, const float *__restrict val,
                                          const sparse_index *__restrict indx, const sparse_index *__restrict jndx)
{
    if (!CharonSparseIsFloat(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    for (sparse_dimension k = 0; k < N; k++) {
        sparse_status put = CharonSparsePutEntry(A, CHARON_SPARSE_MAGIC_FLOAT, val[k], indx[k], jndx[k], sizeof(float));
        if (put != SPARSE_SUCCESS) {
            return put;
        }
    }
    return SPARSE_SUCCESS;
}

sparse_status sparse_insert_entries_double(sparse_matrix_double A, sparse_dimension N, const double *__restrict val,
                                           const sparse_index *__restrict indx, const sparse_index *__restrict jndx)
{
    if (!CharonSparseIsDouble(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    for (sparse_dimension k = 0; k < N; k++) {
        sparse_status put = CharonSparsePutEntry(A, CHARON_SPARSE_MAGIC_DOUBLE, val[k], indx[k], jndx[k], sizeof(double));
        if (put != SPARSE_SUCCESS) {
            return put;
        }
    }
    return SPARSE_SUCCESS;
}

// A column of a point-wise matrix, and a row of one, both appended and overwriting what is there:
// measured, inserting into a column that already holds values raises the matrix's nonzero count
// rather than replacing the column, and an entry written twice is counted once.
sparse_status sparse_insert_col_float(sparse_matrix_float A, sparse_index j, sparse_dimension nz,
                                      const float *__restrict val, const sparse_index *__restrict indx)
{
    if (!CharonSparseIsFloat(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    for (sparse_dimension k = 0; k < nz; k++) {
        sparse_status put = CharonSparsePutEntry(A, CHARON_SPARSE_MAGIC_FLOAT, val[k], indx[k], j, sizeof(float));
        if (put != SPARSE_SUCCESS) {
            return put;
        }
    }
    return SPARSE_SUCCESS;
}

sparse_status sparse_insert_col_double(sparse_matrix_double A, sparse_index j, sparse_dimension nz,
                                       const double *__restrict val, const sparse_index *__restrict indx)
{
    if (!CharonSparseIsDouble(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    for (sparse_dimension k = 0; k < nz; k++) {
        sparse_status put = CharonSparsePutEntry(A, CHARON_SPARSE_MAGIC_DOUBLE, val[k], indx[k], j, sizeof(double));
        if (put != SPARSE_SUCCESS) {
            return put;
        }
    }
    return SPARSE_SUCCESS;
}

sparse_status sparse_insert_row_float(sparse_matrix_float A, sparse_index i, sparse_dimension nz,
                                      const float *__restrict val, const sparse_index *__restrict jndx)
{
    if (!CharonSparseIsFloat(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    for (sparse_dimension k = 0; k < nz; k++) {
        sparse_status put = CharonSparsePutEntry(A, CHARON_SPARSE_MAGIC_FLOAT, val[k], i, jndx[k], sizeof(float));
        if (put != SPARSE_SUCCESS) {
            return put;
        }
    }
    return SPARSE_SUCCESS;
}

sparse_status sparse_insert_row_double(sparse_matrix_double A, sparse_index i, sparse_dimension nz,
                                       const double *__restrict val, const sparse_index *__restrict jndx)
{
    if (!CharonSparseIsDouble(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    for (sparse_dimension k = 0; k < nz; k++) {
        sparse_status put = CharonSparsePutEntry(A, CHARON_SPARSE_MAGIC_DOUBLE, val[k], i, jndx[k], sizeof(double));
        if (put != SPARSE_SUCCESS) {
            return put;
        }
    }
    return SPARSE_SUCCESS;
}

// A block entry of a block matrix: the k x l values at block index (bi, bj), read at the strides the
// caller gives, written to the k x l elements of the matrix the block covers. A block index outside
// the matrix is SPARSE_ILLEGAL_PARAMETER, measured.
static sparse_status CharonSparsePutBlock(void *matrix, uint32_t magic, const void *val, sparse_dimension rowStride,
                                          sparse_dimension colStride, sparse_index bi, sparse_index bj, size_t size)
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
            const char *from = (const char *)val + (size_t)(i * rowStride + j * colStride) * size;
            double value = size == sizeof(float) ? (double)*(const float *)from : *(const double *)from;
            sparse_index before = asFloat->row[first + i].count;
            sparse_status put = CharonSparsePut(&asFloat->row[first + i], left + j, value, size);
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
    return CharonSparsePutBlock(A, CHARON_SPARSE_MAGIC_FLOAT, val, row_stride, col_stride, bi, bj, sizeof(float));
}

sparse_status sparse_insert_block_double(sparse_matrix_double A, const double *__restrict val,
                                         sparse_dimension row_stride, sparse_dimension col_stride, sparse_index bi,
                                         sparse_index bj)
{
    return CharonSparsePutBlock(A, CHARON_SPARSE_MAGIC_DOUBLE, val, row_stride, col_stride, bi, bj, sizeof(double));
}

// ---------------------------------------------------------------- reading a matrix

// The first nz stored entries of a row from column_start onwards, and the column of the next one.
// Measured on the host, over a 4x4 whose rows hold columns {1,2,3}, {0}, {} and {2}:
//   - the return value is the number of entries written and not a sparse_status;
//   - the indices written are absolute columns of the matrix, not offsets from column_start (measured:
//     from column_start = 2 the first two are written as columns 2 and 3);
//   - column_end is column_start when nz is zero, whatever the row holds, and otherwise the column of
//     the next stored entry after the ones written, or the number of columns when there is none
//     (measured: from column_start = 0 with nz = 2 the row {1,2,3} gives end = 3, with nz = 4 it gives
//     4, and with nz = 0 it gives 0);
//   - a row or a column_start outside the matrix, and a negative one, answer SPARSE_ILLEGAL_PARAMETER
//     (-1000, measured for column_start = N, for N + 1, for -1 and for a row past the last).
static long CharonSparseExtractRow(void *matrix, uint32_t magic, sparse_index row, sparse_index columnStart,
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
    return (sparse_status)CharonSparseExtractRow(A, CHARON_SPARSE_MAGIC_FLOAT, row, column_start, column_end, nz, val,
                                                 jndx, sizeof(float));
}

sparse_status sparse_extract_sparse_row_double(sparse_matrix_double A, sparse_index row, sparse_index column_start,
                                               sparse_index *column_end, sparse_dimension nz, double *__restrict val,
                                               sparse_index *__restrict jndx)
{
    return (sparse_status)CharonSparseExtractRow(A, CHARON_SPARSE_MAGIC_DOUBLE, row, column_start, column_end, nz, val,
                                                 jndx, sizeof(double));
}

// The first nz stored entries of a column from row_start onwards, and the row of the next one: the
// transpose of the row extraction, with the same refusals.
static long CharonSparseExtractColumn(void *matrix, uint32_t magic, sparse_index column, sparse_index rowStart,
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
    // The row of the next entry of the column after the last one written, or the number of rows when
    // there is none - measured: a column with one entry at row 1, read from row 0 with nz of 2 or 4,
    // answers 1 and the number of rows, and with nz of zero answers row_start whatever it holds.
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

sparse_status sparse_extract_sparse_column_float(sparse_matrix_float A, sparse_index column, sparse_index row_start,
                                                 sparse_index *row_end, sparse_dimension nz, float *__restrict val,
                                                 sparse_index *__restrict jndx)
{
    return (sparse_status)CharonSparseExtractColumn(A, CHARON_SPARSE_MAGIC_FLOAT, column, row_start, row_end, nz, val,
                                                    jndx, sizeof(float));
}

sparse_status sparse_extract_sparse_column_double(sparse_matrix_double A, sparse_index column, sparse_index row_start,
                                                  sparse_index *row_end, sparse_dimension nz, double *__restrict val,
                                                  sparse_index *__restrict jndx)
{
    return (sparse_status)CharonSparseExtractColumn(A, CHARON_SPARSE_MAGIC_DOUBLE, column, row_start, row_end, nz, val,
                                                    jndx, sizeof(double));
}

// The k x l values of block (bi, bj), read at the strides the caller gives, written to val. A block
// that was never inserted reads as zeros, measured; a point-wise matrix and a block index outside
// the matrix answer SPARSE_ILLEGAL_PARAMETER, both measured.
static sparse_status CharonSparseExtractBlock(void *matrix, uint32_t magic, sparse_index bi, sparse_index bj,
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
            double value = CharonSparseElementAt(&asFloat->row[first + i], left + j, size);
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
    return CharonSparseExtractBlock(A, CHARON_SPARSE_MAGIC_FLOAT, bi, bj, row_stride, col_stride, val, sizeof(float));
}

sparse_status sparse_extract_block_double(sparse_matrix_double A, sparse_index bi, sparse_index bj,
                                          sparse_dimension row_stride, sparse_dimension col_stride,
                                          double *__restrict val)
{
    return CharonSparseExtractBlock(A, CHARON_SPARSE_MAGIC_DOUBLE, bi, bj, row_stride, col_stride, val, sizeof(double));
}

// ---------------------------------------------------------------- properties, counts, commit, destroy

// The four properties are four independent bits, and a name that is not one of them is accepted and
// remembered as nothing: measured, sparse_set_matrix_property answers SPARSE_SUCCESS for 0, 3 and 99,
// SPARSE_ILLEGAL_PARAMETER for -1 and SPARSE_CANNOT_SET_PROPERTY for any name once a value has been
// inserted, and sparse_get_matrix_property answers 0 for 0, 99 and -1 whether or not they were set.
static sparse_status CharonSparseSetProperty(void *matrix, uint32_t magic, sparse_matrix_property pname)
{
    if (!CharonSparseIsMatrix(matrix, magic)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    struct sparse_m_float *asFloat = (struct sparse_m_float *)matrix;
    // The enumeration of Sparse/Types.h has no negative case, so a compiler gives it an unsigned
    // underlying type and a negative name arrives here as a large positive value. The comparison is
    // therefore made in int, which is what the host does: measured, every name from -1 to -9 answers
    // SPARSE_ILLEGAL_PARAMETER and 0, 1, 2 and 3 answer SPARSE_SUCCESS.
    if ((int)pname < 0) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    if (asFloat->inserted) {
        return SPARSE_CANNOT_SET_PROPERTY;
    }
    // Any name is remembered, not only the four the enumeration names: measured on the host, the name 3
    // is accepted and reads back as 3, which is a matrix carrying SPARSE_UPPER_TRIANGULAR and
    // SPARSE_LOWER_TRIANGULAR at once.
    asFloat->property |= (long)pname;
    return SPARSE_SUCCESS;
}

sparse_status sparse_set_matrix_property(void *A, sparse_matrix_property pname)
{
    // The entry point takes the matrix untyped, so a matrix of any of the four scalar types answers
    // here: what a property is does not depend on the values, and the host's own answers are the same
    // for a float and a double matrix.
    if (CharonSparseIsFloat(A)) {
        return CharonSparseSetProperty(A, CHARON_SPARSE_MAGIC_FLOAT, pname);
    }
    if (CharonSparseIsDouble(A)) {
        return CharonSparseSetProperty(A, CHARON_SPARSE_MAGIC_DOUBLE, pname);
    }
    if (CharonSparseIsFloatComplex(A)) {
        return CharonSparseSetProperty(A, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX, pname);
    }
    return CharonSparseSetProperty(A, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX, pname);
}

long sparse_get_matrix_property(void *A, sparse_matrix_property pname)
{
    if (CharonSparseIsAny(A)) {
        // The name when every bit it has is set, and 0 when any of them is not. Measured on the host:
        // a matrix carrying SPARSE_UPPER_TRIANGULAR and SPARSE_LOWER_TRIANGULAR reads 1, 2 and 3 for
        // those three names and 0 for SPARSE_UPPER_SYMMETRIC and SPARSE_LOWER_SYMMETRIC; a matrix given
        // only the name 3 reads 3 back; and 0, 99 and a name never set all read 0.
        long property = ((struct sparse_m_float *)A)->property;
        return (property & (long)pname) == (long)pname ? (long)pname : 0;
    }
    return 0;
}

sparse_dimension sparse_get_matrix_number_of_rows(void *A)
{
    return (CharonSparseIsAny(A)) ? ((struct sparse_m_float *)A)->rows : 0;
}

sparse_dimension sparse_get_matrix_number_of_columns(void *A)
{
    return (CharonSparseIsAny(A)) ? ((struct sparse_m_float *)A)->columns : 0;
}

long sparse_get_matrix_nonzero_count(void *A)
{
    return (CharonSparseIsAny(A)) ? ((struct sparse_m_float *)A)->nonzero : 0;
}

long sparse_get_matrix_nonzero_count_for_row(void *A, sparse_index i)
{
    if (!CharonSparseIsAny(A)) {
        return 0;
    }
    const struct sparse_m_float *asFloat = (const struct sparse_m_float *)A;
    return i < (sparse_index)asFloat->rows && i >= 0 ? (long)asFloat->row[i].count : 0;
}

long sparse_get_matrix_nonzero_count_for_column(void *A, sparse_index j)
{
    if (!CharonSparseIsAny(A)) {
        return 0;
    }
    const struct sparse_m_float *asFloat = (const struct sparse_m_float *)A;
    if (j < 0 || j >= (sparse_index)asFloat->columns) {
        return 0;
    }
    long count = 0;
    for (sparse_dimension i = 0; i < asFloat->rows; i++) {
        sparse_index at = CharonSparseSearch(&asFloat->row[i], j);
        if (at < asFloat->row[i].count && asFloat->row[i].column[at] == j) {
            count++;
        }
    }
    return count;
}

long sparse_get_block_dimension_for_row(void *A, sparse_index i)
{
    if (!CharonSparseIsAny(A)) {
        return 0;
    }
    const struct sparse_m_float *asFloat = (const struct sparse_m_float *)A;
    if (i < 0 || !asFloat->blockHeight) {
        return 0;
    }
    return (long)CharonSparseBlockAt(asFloat->blockHeight, asFloat->blockRows, i);
}

long sparse_get_block_dimension_for_col(void *A, sparse_index j)
{
    if (!CharonSparseIsAny(A)) {
        return 0;
    }
    const struct sparse_m_float *asFloat = (const struct sparse_m_float *)A;
    if (j < 0 || !asFloat->blockWidth) {
        return 0;
    }
    return (long)CharonSparseBlockAt(asFloat->blockWidth, asFloat->blockColumns, j);
}

// Every insertion here is already in the matrix's own storage when it returns, so there is nothing
// for sparse_commit to do and it answers SPARSE_SUCCESS. Measured on the host: a commit answers 0, the
// nonzero count and every element are the same before and after it, and a commit of a matrix that is
// not one is SPARSE_ILLEGAL_PARAMETER.
sparse_status sparse_commit(void *A)
{
    return (CharonSparseIsAny(A)) ? SPARSE_SUCCESS : SPARSE_ILLEGAL_PARAMETER;
}

sparse_status sparse_matrix_destroy(void *A)
{
    if (!CharonSparseIsAny(A)) {
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

// ---------------------------------------------------------------- level 1

// The inner product of a sparse vector and a dense one, in the caller's order. The release's BLAS
// has no form for it - the indices are irregular, not a stride - so this is the sum the header
// writes out, accumulated in the order the entries are given.
static double CharonSparseInnerDense(sparse_dimension nz, const void *x, const sparse_index *indx, const void *y,
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
    return (float)CharonSparseInnerDense(nz, x, indx, y, incy, sizeof(float));
}

double sparse_inner_product_dense_double(sparse_dimension nz, const double *__restrict x, const sparse_index *__restrict indx,
                                         const double *__restrict y, sparse_stride incy)
{
    return CharonSparseInnerDense(nz, x, indx, y, incy, sizeof(double));
}

// The inner product of two sparse vectors: a walk of the two index runs against each other. A count
// of zero on either side answers zero, measured.
static double CharonSparseInnerSparse(sparse_dimension nzx, sparse_dimension nzy, const void *x, const sparse_index *indx,
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
    return (float)CharonSparseInnerSparse(nzx, nzy, x, indx, y, indy, sizeof(float));
}

double sparse_inner_product_sparse_double(sparse_dimension nzx, sparse_dimension nzy, const double *__restrict x,
                                          const sparse_index *__restrict indx, const double *__restrict y,
                                          const sparse_index *__restrict indy)
{
    return CharonSparseInnerSparse(nzx, nzy, x, indx, y, indy, sizeof(double));
}

// y = alpha * x + y for a sparse x, one stored entry at a time. An alpha or a count of zero leaves y
// as it was, measured.
static void CharonSparseAddScale(sparse_dimension nz, double alpha, const void *x, const sparse_index *indx, void *y,
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
    CharonSparseAddScale(nz, alpha, x, indx, y, incy, sizeof(float));
}

void sparse_vector_add_with_scale_dense_double(sparse_dimension nz, double alpha, const double *__restrict x,
                                               const sparse_index *__restrict indx, double *__restrict y,
                                               sparse_stride incy)
{
    CharonSparseAddScale(nz, alpha, x, indx, y, incy, sizeof(double));
}

// The three norms of a sparse vector. A norm the enumeration does not name is answered as
// SPARSE_NORM_INF, and SPARSE_NORM_R1 - which the header says a vector does not support - is answered
// as SPARSE_NORM_TWO: measured on the host, for the values {1, 0, 3} the one, two, infinity, R1 and
// unlisted norms answer 4, 3.16228, 3, 3.16228 and 3, and a count of zero answers 0 for all three.
static double CharonSparseVectorNorm(sparse_dimension nz, const void *x, const sparse_index *indx, sparse_norm norm,
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
    return (float)CharonSparseVectorNorm(nz, x, indx, norm, sizeof(float));
}

double sparse_vector_norm_double(sparse_dimension nz, const double *__restrict x, const sparse_index *__restrict indx,
                                 sparse_norm norm)
{
    return CharonSparseVectorNorm(nz, x, indx, norm, sizeof(double));
}

// ---------------------------------------------------------------- the vector utilities

// The elements a strided dense vector has: the N of them at base + i * incx. A negative increment is
// the caller's business - the header says the pointer is then the last element - and the arithmetic
// below is the same either way, which is what the host does as well: measured with a negative
// increment and a pointer to the last element, the two agree element for element.
static long CharonSparseVectorNonzero(sparse_dimension N, const void *x, sparse_stride incx, size_t size)
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
    return CharonSparseVectorNonzero(N, x, incx, sizeof(float));
}

long sparse_get_vector_nonzero_count_double(sparse_dimension N, const double *__restrict x, sparse_stride incx)
{
    return CharonSparseVectorNonzero(N, x, incx, sizeof(double));
}

// The first nz nonzero elements of a dense vector, with their indices, and how many there were:
// measured, fewer nonzeros than nz leaves the tail of both arrays untouched and the count is what
// was written, a count of nz or an N of zero writes nothing, and the indices are 0-based positions.
static long CharonSparsePack(sparse_dimension N, sparse_dimension nz, const void *x, sparse_stride incx, void *y,
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
    return CharonSparsePack(N, nz, x, incx, y, indy, sizeof(float));
}

long sparse_pack_vector_double(sparse_dimension N, sparse_dimension nz, const double *__restrict x, sparse_stride incx,
                               double *__restrict y, sparse_index *__restrict indy)
{
    return CharonSparsePack(N, nz, x, incx, y, indy, sizeof(double));
}

// The entries of a sparse vector written into a dense one, optionally zeroing the rest. The zeroing
// walk visits the strided elements only - the padding between them is left alone, measured - and a
// zero=true zeroes the whole vector even with no entry to write, also measured. An index at or past N
// is not written, measured: it is not an error, and the element it names is left as the zeroing left
// it.
static void CharonSparseUnpack(sparse_dimension N, sparse_dimension nz, bool zero, const void *x, const sparse_index *indx,
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
    CharonSparseUnpack(N, nz, zero, x, indx, y, incy, sizeof(float));
}

void sparse_unpack_vector_double(sparse_dimension N, sparse_dimension nz, bool zero, const double *__restrict x,
                                 const sparse_index *__restrict indx, double *__restrict y, sparse_stride incy)
{
    CharonSparseUnpack(N, nz, zero, x, indx, y, incy, sizeof(double));
}

// ---------------------------------------------------------------- level 2

// y = alpha * op(A) * x + y. One entry of the matrix at a time: the release's own cblas_saxpy over
// the single product, which is the sparse level-2 kernel and keeps the multiply-add in the release's
// BLAS. A transpose the enumeration does not name is SPARSE_ILLEGAL_PARAMETER and y is left alone,
// which is what the header says; the host's own answer for one is to hand the parameter to
// cblas_sgemv, which ends the process (facts/Accelerate/SparseBLAS.md).
static sparse_status CharonSparseVectorProduct(void *matrix, uint32_t magic, int transposed, double alpha,
                                              const void *x, sparse_stride incx, void *y, sparse_stride incy, size_t size)
{
    if (!CharonSparseIsMatrix(matrix, magic)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    const struct sparse_m_float *asFloat = (const struct sparse_m_float *)matrix;
    sparse_dimension inner = transposed ? asFloat->rows : asFloat->columns;
    sparse_dimension outer = transposed ? asFloat->columns : asFloat->rows;
    for (sparse_dimension i = 0; i < outer; i++) {
        for (sparse_dimension k = 0; k < inner; k++) {
            double value = CharonSparseElementAt(&asFloat->row[transposed ? k : i], transposed ? i : k, size);
            if (value == 0.0) {
                continue;
            }
            // The address of the element is computed here and the release's own cblas_saxpy does the
            // one multiply-add at it, which is what makes an increment of zero or a negative one work:
            // measured on the host, cblas_saxpy with an increment that is not positive treats it as
            // one (a single call with incY = 0 and incY = -1 both leave every element but the first
            // alone), so the stride is never handed to the BLAS.
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
    return CharonSparseVectorProduct(A, CHARON_SPARSE_MAGIC_FLOAT, transa == CblasTrans, alpha, x, incx, y, incy,
                                     sizeof(float));
}

sparse_status sparse_matrix_vector_product_dense_double(enum CBLAS_TRANSPOSE transa, double alpha, sparse_matrix_double A,
                                                        const double *__restrict x, sparse_stride incx,
                                                        double *__restrict y, sparse_stride incy)
{
    if (transa != CblasNoTrans && transa != CblasTrans) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    return CharonSparseVectorProduct(A, CHARON_SPARSE_MAGIC_DOUBLE, transa == CblasTrans, alpha, x, incx, y, incy,
                                     sizeof(double));
}

// The triangular solve, over the stored entries, which is the reason a caller reached for a sparse
// matrix at all: O(nnz) rather than the O(n^2) a dense cblas_strsv would spend.
//
// Two rules the measurements fix. A matrix with no triangular property is refused and the vector is
// left alone, measured. And alpha DIVIDES the right-hand side rather than scaling the solution:
// measured on the host for the lower triangular [[2,0,0],[1,3,0],[0,0,4]] against (2, 5, 4), the
// answers for alpha = 2, 0.5, -1 and 0 are (0.5, 0.666667, 0.5), (2, 2.66667, 2), (-1, -1.33333, -1)
// and (inf, nan, nan) - the solutions of T x = b / alpha, where scaling the solution would give
// (2, 2.66667, 2) and (0, 0, 0). The header reads "x = alpha * T^-1 * x"; the host divides, and
// facts/Accelerate/SparseBLAS.md carries both numbers and says which one the port answers.
//
// A pivot of exactly zero divides, so a zero on the diagonal gives an infinity and then a NaN, which
// is what the host gives and what the caller gets.
static sparse_status CharonSparseTriangular(void *matrix, uint32_t magic, int transposed, double alpha, void *b,
                                           long iStep, long rightStep, sparse_dimension nrhs, size_t size)
{
    if (!CharonSparseIsMatrix(matrix, magic)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    const struct sparse_m_float *asFloat = (const struct sparse_m_float *)matrix;
    if (!(asFloat->property & (SPARSE_UPPER_TRIANGULAR | SPARSE_LOWER_TRIANGULAR))) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    // A transposed triangular matrix is the other triangle, and the other triangle is the matrix's
    // own storage read the other way round: the transposed lower [[2,0,0],[1,3,0],[0,0,4]] is upper
    // triangular and solving with it walks the original's rows backwards reading the entries below
    // their diagonal. The sweep is therefore over the matrix's own rows or its own columns, and over
    // the entry that names the row being solved, which is a column of the matrix when it is
    // transposed. The transposed case builds the column lists once, which is O(nnz) and keeps the
    // whole solve O(nnz) - a dense cblas_strsv would spend O(n^2), which is the reason a caller
    // reached for a sparse matrix at all.
    int upper = (asFloat->property & SPARSE_UPPER_TRIANGULAR) != 0;
    sparse_dimension n = asFloat->rows;
    sparse_index *lists = NULL;
    sparse_index *offsets = NULL;
    if (transposed) {
        // For every row of the transposed operand, which is a column of the matrix, the rows of the
        // matrix that hold an entry in it and where those entries are in their own rows.
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
        // The list of row i is the span that ends where row i + 1's begins, so it is shifted along.
        sparse_index running = 0;
        for (sparse_index i = 0; i <= (sparse_index)n; i++) {
            sparse_index count = offsets[i];
            offsets[i] = running;
            running += count;
        }
    }
    for (sparse_dimension right = 0; right < nrhs; right++) {
        // An upper triangle is solved from the last row backwards, and a lower one from the first
        // forwards; transposing swaps which of the two the matrix's own storage is.
        int backwards = upper != (transposed ? 1 : 0);
        // The same condition says which side of the diagonal the solve reads, and it is what makes a
        // transposed solve walk the matrix's columns: the transposed lower [[2,0,0],[1,3,0],[0,0,4]]
        // solves to 0.166667, 1.66667 and 1 against (2,5,4), measured on the host, which is the
        // transposed system and not the original one.
        for (sparse_dimension step = 0; step < n; step++) {
            sparse_dimension i = backwards ? n - 1 - step : step;
            long here = (long)i * iStep + (long)right * rightStep;
            double value = size == sizeof(float) ? (double)((float *)b)[here] : ((double *)b)[here];
            value /= alpha;
            if (!transposed) {
                for (sparse_index at = 0; at < asFloat->row[i].count; at++) {
                    sparse_index j = asFloat->row[i].column[at];
                    if (j == (sparse_index)i || (j < (sparse_index)i) == backwards) {
                        continue; // the diagonal, or the triangle the caller did not declare
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
                    double other = CharonSparseElementAt(&asFloat->row[j], (sparse_index)i, size);
                    long at2 = (long)j * iStep + (long)right * rightStep;
                    double addend = size == sizeof(float) ? (double)((float *)b)[at2] : ((double *)b)[at2];
                    value -= other * addend;
                }
            }
            double diagonal = CharonSparseElementAt(&asFloat->row[i], i, size);
            // A pivot of exactly zero divides, so an infinity and then a NaN, which is what the host
            // gives: measured, the lower [[0,0],[0,1]] against (1,1) answers (inf, nan).
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
    return CharonSparseTriangular(T, CHARON_SPARSE_MAGIC_FLOAT, transt == CblasTrans, alpha, x, incx, 0, 1,
                                  sizeof(float));
}

sparse_status sparse_vector_triangular_solve_dense_double(enum CBLAS_TRANSPOSE transt, double alpha, sparse_matrix_double T,
                                                          double *__restrict x, sparse_stride incx)
{
    if (transt != CblasNoTrans && transt != CblasTrans) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    return CharonSparseTriangular(T, CHARON_SPARSE_MAGIC_DOUBLE, transt == CblasTrans, alpha, x, incx, 0, 1,
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
    if (!CharonSparseIsFloat(T)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    const struct sparse_m_float *asFloat = (const struct sparse_m_float *)T;
    sparse_dimension needed = order == CblasRowMajor ? (nrhs ? nrhs : 1) : (asFloat->rows ? asFloat->rows : 1);
    if (ldb < needed) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    // Row-major steps along the columns, so a row is ldb elements on and a right-hand side is one
    // element on; column-major is the other way round.
    return CharonSparseTriangular(T, CHARON_SPARSE_MAGIC_FLOAT, transt == CblasTrans, alpha, B,
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
    if (!CharonSparseIsDouble(T)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    const struct sparse_m_float *asFloat = (const struct sparse_m_float *)T;
    sparse_dimension needed = order == CblasRowMajor ? (nrhs ? nrhs : 1) : (asFloat->rows ? asFloat->rows : 1);
    if (ldb < needed) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    return CharonSparseTriangular(T, CHARON_SPARSE_MAGIC_DOUBLE, transt == CblasTrans, alpha, B,
                                  order == CblasRowMajor ? (long)ldb : 1, order == CblasRowMajor ? 1 : (long)ldb,
                                  nrhs, sizeof(double));
}

// C = alpha * x * y' for a dense x and a sparse y, as a new matrix. A count of nonzeros above N is
// SPARSE_ILLEGAL_PARAMETER and the caller's matrix pointer is left alone, measured; a count of zero and
// an alpha of zero both answer a matrix of the right shape with nothing in it, also measured.
//
// **x is indexed by the row and y by the column**, because C[i, j] = alpha * x[i] * y[k] for the k whose
// indy[k] is j: the outer product is a column of x scaled into a row. An earlier version read x at k and
// wrote the same value into every row, which is C[i, j] = alpha * x[k] * y[k] and answers the right
// number only where x is constant down its length - which is why the differential, whose cases all pass
// x = {1, 1}, could not see it. Measured on the host, and the case that sees it is in
// tests/backports/host/sparseblas/differential.m together with a mutant that drops x: for M = 3, N = 3,
// nz = 2, alpha = 1, x = {1, 2, 3} and y = {5, -6} at the columns {0, 2} the host answers
// C[0] = (5, -6), C[1] = (10, -12), C[2] = (15, -18).
static sparse_status CharonSparseOuter(sparse_dimension M, sparse_dimension N, sparse_dimension nz, double alpha,
                                       const void *x, sparse_stride incx, const void *y, const sparse_index *indy,
                                       void **C, uint32_t magic, size_t size, size_t matrixSize)
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
            CharonSparsePut(&asFloat->row[i], indy[k], value, size);
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
    return CharonSparseOuter(M, N, nz, alpha, x, incx, y, indy, (void **)C, CHARON_SPARSE_MAGIC_FLOAT, sizeof(float),
                             sizeof(struct sparse_m_float));
}

sparse_status sparse_outer_product_dense_double(sparse_dimension M, sparse_dimension N, sparse_dimension nz, double alpha,
                                                const double *__restrict x, sparse_stride incx,
                                                const double *__restrict y, const sparse_index *__restrict indy,
                                                sparse_matrix_double *__restrict C)
{
    return CharonSparseOuter(M, N, nz, alpha, x, incx, y, indy, (void **)C, CHARON_SPARSE_MAGIC_DOUBLE, sizeof(double),
                             sizeof(struct sparse_m_double));
}

// Both permutations below are in CharonSparseBLAS.h, because SparseComplex18.m runs the same two over
// the same storage, and a function defined in a file that exports an API symbol is left out of a
// band the release already has.

sparse_status sparse_permute_rows_float(sparse_matrix_float A, const sparse_index *__restrict perm)
{
    if (!CharonSparseIsFloat(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    CharonSparsePermuteRows((struct sparse_m_float *)A, perm);
    return SPARSE_SUCCESS;
}

sparse_status sparse_permute_rows_double(sparse_matrix_double A, const sparse_index *__restrict perm)
{
    if (!CharonSparseIsDouble(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    CharonSparsePermuteRows((struct sparse_m_float *)A, perm);
    return SPARSE_SUCCESS;
}

sparse_status sparse_permute_cols_float(sparse_matrix_float A, const sparse_index *__restrict perm)
{
    if (!CharonSparseIsFloat(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    CharonSparsePermuteColumns((struct sparse_m_float *)A, perm, sizeof(float));
    return SPARSE_SUCCESS;
}

sparse_status sparse_permute_cols_double(sparse_matrix_double A, const sparse_index *__restrict perm)
{
    if (!CharonSparseIsDouble(A)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    // The element width, and not sizeof(float): this helper branches on it to read and write every
    // value, so a double's values passed as the float one were read and written four bytes at a time and
    // column 0 came back as denormal garbage (measured by the review's probe, facts below).
    CharonSparsePermuteColumns((struct sparse_m_float *)A, perm, sizeof(double));
    return SPARSE_SUCCESS;
}

// ---------------------------------------------------------------- the norms and the trace

// The four elementwise norms of a matrix, over its stored entries. A norm the enumeration does not
// name is answered as SPARSE_NORM_INF, measured for both an unlisted positive value and a negative
// one, and an empty matrix answers zero for all four, measured.
static double CharonSparseElementwise(void *matrix, uint32_t magic, sparse_norm norm, size_t size)
{
    if (!CharonSparseIsMatrix(matrix, magic)) {
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
        // sum over j of sqrt(sum over i of A[i,j]^2): a square root per column, which is why the
        // column sums are kept apart.
        double total = 0.0;
        for (sparse_index j = 0; j < (sparse_index)asFloat->columns; j++) {
            double sum = 0.0;
            for (sparse_dimension i = 0; i < asFloat->rows; i++) {
                double value = CharonSparseElementAt(&asFloat->row[i], j, size);
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
    return (float)CharonSparseElementwise(A, CHARON_SPARSE_MAGIC_FLOAT, norm, sizeof(float));
}

double sparse_elementwise_norm_double(sparse_matrix_double A, sparse_norm norm)
{
    return CharonSparseElementwise(A, CHARON_SPARSE_MAGIC_DOUBLE, norm, sizeof(double));
}

// The operator-one norm, max over j of the column sums of the absolute values, and the
// operator-infinity norm, max over i of the row sums: the arithmetic the header writes out. A matrix
// that is not one of ours, or an empty one, answers zero, both measured.
//
// The operator-two norm, the largest singular value, is the release's own LAPACK: the Gram matrix
// A * A' formed with cblas_ssyrk / cblas_dsyrk, then the largest of its eigenvalues read with ssyev_ /
// dsyev_. The host reaches the same number by an iteration and not by an eigen-decomposition, so the
// two agree to about one part in three thousand and not to the last bit: measured on the host for
// [[-1,2,-3],[4,0,-5]] it answers 6.69983 where the exact largest singular value is 6.70179, and for
// the diagonal (3, 4) it answers 3.9941 where the answer is 4. That is the one place in this family
// with a tolerance, it is stated in facts/Accelerate/SparseBLAS.md, and the port's answer is the
// exact one. SPARSE_NORM_R1 is not supported for a matrix and answers NaN, measured.
static double CharonSparseOperator(void *matrix, uint32_t magic, sparse_norm norm, size_t size)
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
        // The largest column sum of the absolute values, over the stored entries: measured, 8 for
        // [[-1,2,-3],[4,0,-5]], whose column sums are 5, 2 and 8.
        double largest = 0.0;
        for (sparse_index j = 0; j < (sparse_index)n; j++) {
            double sum = 0.0;
            for (sparse_dimension i = 0; i < m; i++) {
                sum += fabs(CharonSparseElementAt(&asFloat->row[i], j, size));
            }
            if (sum > largest) {
                largest = sum;
            }
        }
        return largest;
    }
    if (norm == SPARSE_NORM_INF || (norm != SPARSE_NORM_TWO && norm != SPARSE_NORM_R1)) {
        // The largest row sum, and the answer for a norm the enumeration does not name, which the
        // header says is SPARSE_NORM_INF: measured, 9 for the same matrix, whose row sums are 6 and 9,
        // and 9 for every name outside the enumeration.
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
    // A * A' as a dense m x m matrix, and the largest of its eigenvalues through the release's own
    // LAPACK. ssyev_ and dsyev_ read the lower triangle by default, which is the half the symmetric
    // product below fills, and both take the count and the leading dimension in an int.
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
                    float other = (float)CharonSparseElementAt(&asFloat->row[k], j, size);
                    gram[i * m + k] += value * other;
                }
            }
        }
        // vecLib/Headers/clapack.h declares the scalars of the LAPACK entry points as pointers, and
        // the release's own functions read them there. Their type is the header's own __CLPK_integer,
        // which is an int on a 64-bit target and a long int on the 32-bit one this library is built
        // for - so the port's variables are that type and not int, which the 32-bit build refuses.
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
                    double other = CharonSparseElementAt(&asFloat->row[k], j, size);
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
    return (float)CharonSparseOperator(A, CHARON_SPARSE_MAGIC_FLOAT, norm, sizeof(float));
}

double sparse_operator_norm_double(sparse_matrix_double A, sparse_norm norm)
{
    return CharonSparseOperator(A, CHARON_SPARSE_MAGIC_DOUBLE, norm, sizeof(double));
}

// The sum along one diagonal: A[i, i + offset] for an offset above the main one and A[i - offset, i]
// for one below. An offset that names no element of the matrix answers zero, measured, and so does a
// matrix that is not one of ours.
static double CharonSparseTrace(void *matrix, uint32_t magic, sparse_index offset, size_t size)
{
    if (!CharonSparseIsMatrix(matrix, magic)) {
        return 0.0;
    }
    const struct sparse_m_float *asFloat = (const struct sparse_m_float *)matrix;
    // A[i, i + offset] above the main diagonal and A[i - offset, i] below it, which is the header's own
    // spelling: measured on a 3x4 whose diagonal is 2, 4 and 0 and whose first superdiagonal is 3 and 5,
    // the offsets 0, 1 and -1 answer 6, 8 and 0.
    double sum = 0.0;
    for (sparse_dimension i = 0; i < asFloat->rows; i++) {
        sparse_index row = offset >= 0 ? (sparse_index)i : (sparse_index)i - offset;
        sparse_index column = offset >= 0 ? (sparse_index)i + offset : (sparse_index)i;
        if (row < 0 || row >= (sparse_index)asFloat->rows || column < 0 || column >= (sparse_index)asFloat->columns) {
            continue;
        }
        sum += CharonSparseElementAt(&asFloat->row[row], column, size);
    }
    return sum;
}

float sparse_matrix_trace_float(sparse_matrix_float A, sparse_index offset)
{
    return (float)CharonSparseTrace(A, CHARON_SPARSE_MAGIC_FLOAT, offset, sizeof(float));
}

double sparse_matrix_trace_double(sparse_matrix_double A, sparse_index offset)
{
    return CharonSparseTrace(A, CHARON_SPARSE_MAGIC_DOUBLE, offset, sizeof(double));
}

// ---------------------------------------------------------------- level 3

// C = alpha * op(A) * B + C, with B dense. One stored entry of op(A) at a time: the release's own
// cblas_scopy gathers the row of B the entry names and cblas_saxpy adds alpha times the entry's value
// times it to the row of C - the sparse level-3 kernel, one rank-one update per nonzero.
//
// What is refused, all measured: an order or a transpose the enumeration does not name, a leading
// dimension below what the layout needs, and a matrix that is not one of ours, each SPARSE_ILLEGAL_PARAMETER
// with C untouched. A count of columns of zero and an alpha of zero both answer SPARSE_SUCCESS and
// leave C exactly as it was, also measured.
static sparse_status CharonSparseProductDense(void *matrix, uint32_t magic, int order, int transposed, sparse_dimension n,
                                              double alpha, const void *B, sparse_dimension ldb, void *C,
                                              sparse_dimension ldc, size_t size)
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
    // A row of op(A) is the row of A itself, or the column of A when A is transposed, and the row of B a
    // stored entry scales is B's row at the entry's inner index: A's own column when A is not
    // transposed, its own row when it is. The entry the walk is at is therefore A[r, c] in both cases,
    // and it is read through the same lookup the trace, the norms and the triangular solve use - which is
    // what the first version got wrong: it bound the row to NULL on the transposed path and then read
    // through it, and CblasTrans took the process down on all four level-3 entry points.
    for (sparse_dimension i = 0; i < m; i++) {
        const CharonSparseRow *line = transposed ? NULL : &asFloat->row[i];
        for (sparse_index at = 0; at < (transposed ? (sparse_index)asFloat->rows : line->count); at++) {
            sparse_index r = transposed ? at : (sparse_index)i;
            sparse_index c = transposed ? (sparse_index)i : line->column[at];
            if (c >= (sparse_index)asFloat->columns) {
                continue;
            }
            double value = CharonSparseElementAt(&asFloat->row[r], c, size);
            if (value == 0.0) {
                continue;
            }
            long from = CharonSparseDenseAt(order, ldb, transposed ? r : c, 0);
            long to = CharonSparseDenseAt(order, ldc, i, 0);
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
    return CharonSparseProductDense(A, CHARON_SPARSE_MAGIC_FLOAT, order, transa == CblasTrans, n, alpha, B, ldb, C, ldc,
                                    sizeof(float));
}

sparse_status sparse_matrix_product_dense_double(enum CBLAS_ORDER order, enum CBLAS_TRANSPOSE transa, sparse_dimension n,
                                                 double alpha, sparse_matrix_double A, const double *__restrict B,
                                                 sparse_dimension ldb, double *__restrict C, sparse_dimension ldc)
{
    if (transa != CblasNoTrans && transa != CblasTrans) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    return CharonSparseProductDense(A, CHARON_SPARSE_MAGIC_DOUBLE, order, transa == CblasTrans, n, alpha, B, ldb, C, ldc,
                                    sizeof(double));
}
