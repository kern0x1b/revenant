// The storage behind every sparse_matrix_float and sparse_matrix_double of vecLib/Sparse/BLAS.h, and
// the arithmetic the sparse_* entry points are made of.
//
// The two types are opaque in the header (`typedef struct sparse_m_float *sparse_matrix_float`), so
// completing them here is what the header leaves to an implementation. One shape of row, kept sorted
// by column, for both scalar types: a sparse matrix of this library is exactly a list of rows of
// (column, value) pairs, and every operation below is expressed on that, which is what makes a
// per-row BLAS call possible.
//
// The two structures have one layout, and a static assertion says so, because every helper below
// reads a matrix through one of them: what a value is differs, and the element size says which.
//
// Every name here carries a Charon prefix or is static, so the gate weighs none of it against a
// release or asks the registry about it (modules/apple/backports.lua, internal_symbol).

#pragma once

#import <Accelerate/Accelerate.h>
#include <math.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

// A row of a sparse matrix: the columns of its stored entries in ascending order, and their values.
// Both arrays are one allocation each, so a row is freed in one step and a shift is one memmove.
typedef struct CharonSparseRow {
    sparse_index count;
    sparse_index capacity;
    sparse_index *column;
    void *value;
} CharonSparseRow;

// The body both matrix types share. rows and columns count elements, not blocks: measured on the
// host, a matrix built by sparse_matrix_block_create_float(3, 3, 2, 2) reports 6 rows and 6 columns.
#define CHARON_SPARSE_MATRIX_BODY                                                                              \
    uint32_t magic;                                                                                            \
    sparse_dimension rows;                                                                                      \
    sparse_dimension columns;                                                                                   \
    sparse_index blockRows;                                                                                     \
    sparse_index blockColumns;                                                                                  \
    sparse_dimension *blockHeight; /* blockRows of them, for a block matrix, NULL for a point-wise one */       \
    sparse_dimension *blockWidth;  /* blockColumns of them */                                                   \
    long property;                                                                                             \
    int inserted;                                                                                              \
    long nonzero;                                                                                              \
    CharonSparseRow *row; /* rows of them, each sorted by column */

struct sparse_m_float {
    CHARON_SPARSE_MATRIX_BODY
};

struct sparse_m_double {
    CHARON_SPARSE_MATRIX_BODY
};

// The two complex matrix types of Sparse/Types.h carry the same body, so that one row, one search and
// one growth serve all four, and so that the entry points the header takes a void * matrix for - the
// counts, the block dimensions, the properties, the commit and the destroy - accept a complex matrix on
// the same terms as a real one. Their magic words are the two below and say which of the four it is.
struct sparse_m_float_complex {
    CHARON_SPARSE_MATRIX_BODY
};

struct sparse_m_double_complex {
    CHARON_SPARSE_MATRIX_BODY
};

// The four bytes every matrix of ours begins with, one per scalar type. A pointer handed to one of
// these entry points that does not begin with them is not a matrix this port made - a stale pointer,
// a foreign object, or a matrix already destroyed - and is answered with the status the header names
// for an argument that is not a matrix rather than read. That is the same answer a NULL gets,
// measured on the host for every entry point of the family that checks.
#define CHARON_SPARSE_MAGIC_FLOAT 0x53504630u
#define CHARON_SPARSE_MAGIC_DOUBLE 0x53504644u
#define CHARON_SPARSE_MAGIC_FLOAT_COMPLEX 0x53504643u
#define CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX 0x53504645u

static inline int CharonSparseIsMatrix(const void *matrix, uint32_t magic)
{
    return matrix && ((const struct sparse_m_float *)matrix)->magic == magic;
}

static inline int CharonSparseIsFloat(const void *matrix)
{
    return CharonSparseIsMatrix(matrix, CHARON_SPARSE_MAGIC_FLOAT);
}

static inline int CharonSparseIsDouble(const void *matrix)
{
    return CharonSparseIsMatrix(matrix, CHARON_SPARSE_MAGIC_DOUBLE);
}

static inline int CharonSparseIsFloatComplex(const void *matrix)
{
    return CharonSparseIsMatrix(matrix, CHARON_SPARSE_MAGIC_FLOAT_COMPLEX);
}

static inline int CharonSparseIsDoubleComplex(const void *matrix)
{
    return CharonSparseIsMatrix(matrix, CHARON_SPARSE_MAGIC_DOUBLE_COMPLEX);
}

// Any of the four. The entry points the header takes a void * matrix for answer on a matrix of any of
// them, because what they report - a count, a shape, a property, the commit, the destroy - does not
// depend on the type of the values.
static inline int CharonSparseIsAny(const void *matrix)
{
    return CharonSparseIsFloat(matrix) || CharonSparseIsDouble(matrix) || CharonSparseIsFloatComplex(matrix) ||
           CharonSparseIsDoubleComplex(matrix);
}

// The element of a dense matrix in the caller's own layout, so one loop covers both orders: a
// row-major matrix steps by one along a row, a column-major one by its leading dimension. It lives here
// and not in one of the two object files because both of them need it, and a function defined in a file
// that exports an API symbol is left out of a band the release already has, which is how a shared C
// function becomes an undefined symbol in a later band.
static inline long CharonSparseDenseAt(int order, sparse_dimension leading, sparse_dimension row, sparse_dimension column)
{
    return order == CblasRowMajor ? (long)(row * leading + column) : (long)(column * leading + row);
}

// The first stored column of a row that is not below the one looked for: where an entry for that
// column belongs, and where the search for it stops.
static inline sparse_index CharonSparseSearch(const CharonSparseRow *row, sparse_index column)
{
    sparse_index low = 0, high = row->count;
    while (low < high) {
        sparse_index middle = low + (high - low) / 2;
        if (row->column[middle] < column) {
            low = middle + 1;
        } else {
            high = middle;
        }
    }
    return low;
}

static inline int CharonSparseGrow(CharonSparseRow *row, sparse_index wanted, size_t size)
{
    if (wanted <= row->capacity) {
        return 1;
    }
    sparse_index capacity = row->capacity ? row->capacity : 4;
    while (capacity < wanted) {
        capacity *= 2;
    }
    sparse_index *column = (sparse_index *)realloc(row->column, (size_t)capacity * sizeof(sparse_index));
    if (!column) {
        return 0;
    }
    void *value = realloc(row->value, (size_t)capacity * size);
    if (!value) {
        free(column);
        return 0;
    }
    row->column = column;
    row->value = value;
    row->capacity = capacity;
    return 1;
}

// A[i, j] = value: an entry that is already there is replaced, a new one is put in its place in the
// row's order. A value of exactly zero is stored - measured on the host, inserting 0.0 into an empty
// matrix leaves its nonzero count at 1, and so does inserting over it - so a stored entry and a
// nonzero value are two different things and the count counts entries.
static inline sparse_status CharonSparsePut(CharonSparseRow *row, sparse_index column, double value, size_t size)
{
    sparse_index at = CharonSparseSearch(row, column);
    if (at < row->count && row->column[at] == column) {
        if (size == sizeof(float)) {
            ((float *)row->value)[at] = (float)value;
        } else {
            ((double *)row->value)[at] = value;
        }
        return SPARSE_SUCCESS;
    }
    if (!CharonSparseGrow(row, row->count + 1, size)) {
        return SPARSE_SYSTEM_ERROR;
    }
    memmove(row->column + at + 1, row->column + at, (size_t)(row->count - at) * sizeof(sparse_index));
    memmove((char *)row->value + (size_t)(at + 1) * size, (char *)row->value + (size_t)at * size,
            (size_t)(row->count - at) * size);
    row->column[at] = column;
    if (size == sizeof(float)) {
        ((float *)row->value)[at] = (float)value;
    } else {
        ((double *)row->value)[at] = value;
    }
    row->count++;
    return SPARSE_SUCCESS;
}

// The two complex matrix types below carry the same body, so a row, a search and a growth serve all four
// scalar types: what differs between them is the width a value occupies, and that is the last argument.

// A[i, j], read: the stored value, or zero for a column the row does not hold. A matrix of this
// library treats a column it has nothing for as a zero, which is what every operation below relies
// on and what the host's own answers show (a row with no entry in a column contributes nothing to a
// product and reads as a zero from a block extraction).
static inline double CharonSparseElementAt(const CharonSparseRow *row, sparse_index column, size_t size)
{
    sparse_index at = CharonSparseSearch(row, column);
    if (at >= row->count || row->column[at] != column) {
        return 0.0;
    }
    return size == sizeof(float) ? (double)((const float *)row->value)[at] : ((const double *)row->value)[at];
}

// The height of the block that holds element row, from the block heights and how many blocks there
// are. Measured on the host for a variable-block matrix built with row heights {2, 1, 3} and column
// widths {1, 2, 1}: sparse_get_block_dimension_for_row answers 2, 2, 1 for rows 0, 1 and 2, which is
// the height of the block the row is in and not the height of the block row i names, and 0 for a row
// past the last, for a point-wise matrix and for a NULL.
static inline sparse_dimension CharonSparseBlockAt(const sparse_dimension *sizes, sparse_index blocks, sparse_index element)
{
    sparse_dimension sum = 0;
    for (sparse_index b = 0; b < blocks; b++) {
        sum += sizes[b];
        if (element < sum) {
            return sizes[b];
        }
    }
    return 0;
}

// A matrix with rows and columns, and with either no block sizes at all (a point-wise one) or one per
// block row and block column. Every dimension of zero is accepted, as the host accepts it: measured,
// sparse_matrix_create_float(0, 5), (5, 0) and (0, 0) all answer a matrix, and so do
// sparse_matrix_block_create_float(0, 3, 2, 2) and sparse_matrix_block_create_float(3, 3, 0, 2).
//
// It lives here and not in one of the two object files that need it, because a function defined in a
// file that exports an API symbol is left out of a band the release already has, which is how a shared
// C function becomes an undefined symbol in a later band.
static inline sparse_status CharonSparseMake(void **out, uint32_t magic, size_t size, sparse_dimension rows,
                                             sparse_dimension columns, sparse_index blockRows, sparse_index blockColumns,
                                             const sparse_dimension *heights, const sparse_dimension *widths)
{
    // A point-wise matrix is the shape it was asked for; a block one is the sum of its block sizes,
    // which is what makes its row and column counts read in elements (measured: block(3,3,2,2) is 6x6).
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
    void *matrix = calloc(1, size);
    if (!matrix) {
        free(height);
        free(width);
        return SPARSE_SYSTEM_ERROR;
    }
    struct sparse_m_float *asFloat = (struct sparse_m_float *)matrix;
    asFloat->magic = magic;
    asFloat->rows = totalRows;
    asFloat->columns = totalColumns;
    asFloat->blockRows = blockRows;
    asFloat->blockColumns = blockColumns;
    asFloat->blockHeight = height;
    asFloat->blockWidth = width;
    asFloat->property = 0;
    asFloat->inserted = 0;
    asFloat->nonzero = 0;
    asFloat->row = totalRows > 0 ? (CharonSparseRow *)calloc((size_t)totalRows, sizeof(CharonSparseRow)) : NULL;
    if (totalRows > 0 && !asFloat->row) {
        free(matrix);
        free(height);
        free(width);
        return SPARSE_SYSTEM_ERROR;
    }
    *out = matrix;
    return SPARSE_SUCCESS;
}

// A fixed block matrix is the variable-block one with k for every block row and l for every block
// column, which is what makes sparse_get_block_dimension_for_row answer k for every element row.
static inline sparse_dimension *CharonSparseRepeated(sparse_dimension value, sparse_index count)
{
    sparse_dimension *sizes = (sparse_dimension *)calloc(count ? (size_t)count : 1, sizeof(sparse_dimension));
    for (sparse_index i = 0; sizes && i < count; i++) {
        sizes[i] = value;
    }
    return sizes;
}

// The two complex value helpers, the counterparts of CharonSparsePut and CharonSparseElementAt for a
// row whose values are complex. The parts travel as two doubles, because that is what one loop needs
// to be able to do to them and because the write below rounds the pair to the width the row stores:
// a float row's values come back as the float nearest the double that was computed, which is the same
// rule the real helpers follow when they store a float through a double.
//
// The width a row has is what size says: sizeof(float _Complex) is two floats and
// sizeof(double _Complex) two doubles. Nothing else in the library has to know which of the two it is
// looking at.
static inline void CharonSparseWriteComplexValue(void *values, sparse_index at, double re, double im, size_t size)
{
    char *to = (char *)values + (size_t)at * size;
    if (size == sizeof(float _Complex)) {
        float pair[2];
        pair[0] = (float)re;
        pair[1] = (float)im;
        memcpy(to, pair, sizeof(pair));
    } else {
        double pair[2];
        pair[0] = re;
        pair[1] = im;
        memcpy(to, pair, sizeof(pair));
    }
}

static inline void CharonSparseReadComplexValue(const void *values, sparse_index at, size_t size, double *re, double *im)
{
    const char *from = (const char *)values + (size_t)at * size;
    if (size == sizeof(float _Complex)) {
        float pair[2];
        memcpy(pair, from, sizeof(pair));
        *re = pair[0];
        *im = pair[1];
    } else {
        double pair[2];
        memcpy(pair, from, sizeof(pair));
        *re = pair[0];
        *im = pair[1];
    }
}

static inline sparse_status CharonSparsePutComplex(CharonSparseRow *row, sparse_index column, double re, double im,
                                                   size_t size)
{
    sparse_index at = CharonSparseSearch(row, column);
    if (at < row->count && row->column[at] == column) {
        CharonSparseWriteComplexValue(row->value, at, re, im, size);
        return SPARSE_SUCCESS;
    }
    if (!CharonSparseGrow(row, row->count + 1, size)) {
        return SPARSE_SYSTEM_ERROR;
    }
    memmove(row->column + at + 1, row->column + at, (size_t)(row->count - at) * sizeof(sparse_index));
    memmove((char *)row->value + (size_t)(at + 1) * size, (char *)row->value + (size_t)at * size,
            (size_t)(row->count - at) * size);
    row->column[at] = column;
    CharonSparseWriteComplexValue(row->value, at, re, im, size);
    row->count++;
    return SPARSE_SUCCESS;
}

// A[i, j] of a row whose values are complex: the stored pair, or a zero pair for a column the row
// does not hold, exactly as CharonSparseElementAt reads a row whose values are real.
static inline void CharonSparseElementComplexAt(const CharonSparseRow *row, sparse_index column, size_t size, double *re,
                                                double *im)
{
    sparse_index at = CharonSparseSearch(row, column);
    if (at >= row->count || row->column[at] != column) {
        *re = 0.0;
        *im = 0.0;
        return;
    }
    CharonSparseReadComplexValue(row->value, at, size, re, im);
}

// A point-wise matrix is the only kind a scalar entry belongs to and a block is the only kind a block
// entry belongs to: measured on the host, sparse_insert_entry_float into a matrix built by
// sparse_matrix_block_create_float and sparse_insert_block_float into one built by
// sparse_matrix_create_float both answer SPARSE_ILLEGAL_PARAMETER and change nothing. The same holds
// for the complex types, measured: sparse_insert_entry_float_complex into a matrix built by
// sparse_matrix_block_create_float_complex answers SPARSE_ILLEGAL_PARAMETER and changes nothing.
static inline sparse_status CharonSparseWritable(const void *matrix, uint32_t magic, int wantBlock,
                                                 struct sparse_m_float **out)
{
    if (!CharonSparseIsMatrix(matrix, magic)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    struct sparse_m_float *asFloat = (struct sparse_m_float *)matrix;
    if (wantBlock ? asFloat->blockRows <= 0 : asFloat->blockRows > 0) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    *out = asFloat;
    return SPARSE_SUCCESS;
}

// A[i, j] = value, for a row whose values are real and for one whose values are complex. A value of
// exactly zero is stored - measured on the host, inserting 0.0 into an empty matrix leaves its
// nonzero count at 1, and so does inserting a zero pair over one - so a stored entry and a nonzero
// value are two different things and the count counts entries.
static inline sparse_status CharonSparsePutEntry(void *matrix, uint32_t magic, double value, sparse_index i,
                                                 sparse_index j, size_t size)
{
    struct sparse_m_float *asFloat = NULL;
    sparse_status ready = CharonSparseWritable(matrix, magic, 0, &asFloat);
    if (ready != SPARSE_SUCCESS) {
        return ready;
    }
    if (i < 0 || j < 0 || i >= (sparse_index)asFloat->rows || j >= (sparse_index)asFloat->columns) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    sparse_index before = asFloat->row[i].count;
    sparse_status put = CharonSparsePut(&asFloat->row[i], j, value, size);
    if (put == SPARSE_SUCCESS) {
        asFloat->nonzero += (long)asFloat->row[i].count - (long)before;
        asFloat->inserted = 1;
    }
    return put;
}

static inline sparse_status CharonSparsePutEntryComplex(void *matrix, uint32_t magic, double re, double im, sparse_index i,
                                                        sparse_index j, size_t size)
{
    struct sparse_m_float *asFloat = NULL;
    sparse_status ready = CharonSparseWritable(matrix, magic, 0, &asFloat);
    if (ready != SPARSE_SUCCESS) {
        return ready;
    }
    if (i < 0 || j < 0 || i >= (sparse_index)asFloat->rows || j >= (sparse_index)asFloat->columns) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    sparse_index before = asFloat->row[i].count;
    sparse_status put = CharonSparsePutComplex(&asFloat->row[i], j, re, im, size);
    if (put == SPARSE_SUCCESS) {
        asFloat->nonzero += (long)asFloat->row[i].count - (long)before;
        asFloat->inserted = 1;
    }
    return put;
}

// The permutations of Sparse/BLAS.h are the swap loop the header writes out, run over every row in
// order: for each i, swap the row i with the row the permutation names. It is not a gather, and the
// two are not the same function - measured on the host on [[1,2,3],[4,5,6]], the permutations {1,0}
// and {0,1} leave the rows where they are, {0,0} and {1,1} swap them, and for the columns {1,0,0} and
// {0,1,0} reverse them, {2,0,1} gives [[2,1,3],[5,4,6]] and {0,2,1} and {2,1,0} and {0,1,2} leave them
// where they are. Both types run the loop.
//
// The row swap moves whole rows, so it is the same code for a row whose values are real and for one
// whose values are complex, which is why it is here and not in either object file: SparseComplex18.m
// needs it too, and a function defined in a file that exports an API symbol is left out of a band the
// release already has, which is how a shared C function becomes an undefined symbol in a later band.
static inline void CharonSparsePermuteRows(struct sparse_m_float *asFloat, const sparse_index *perm)
{
    for (sparse_dimension i = 0; i < asFloat->rows; i++) {
        sparse_index target = perm[i];
        if (target < 0 || target >= (sparse_index)asFloat->rows || target == (sparse_index)i) {
            continue;
        }
        CharonSparseRow held = asFloat->row[i];
        asFloat->row[i] = asFloat->row[target];
        asFloat->row[target] = held;
    }
}

// The column swap, for a row whose values are real. The one for a row whose values are complex is
// CharonSparsePermuteColumnsComplex below; the two are the same loop over the same storage and read
// and write through the accessors that suit the width, which is what size says.
static inline void CharonSparsePermuteColumns(struct sparse_m_float *asFloat, const sparse_index *perm, size_t size)
{
    for (sparse_dimension j = 0; j < asFloat->columns; j++) {
        sparse_index target = perm[j];
        if (target < 0 || target >= (sparse_index)asFloat->columns || target == (sparse_index)j) {
            continue;
        }
        for (sparse_dimension i = 0; i < asFloat->rows; i++) {
            double here = CharonSparseElementAt(&asFloat->row[i], j, size);
            double there = CharonSparseElementAt(&asFloat->row[i], target, size);
            // A swap of a stored entry with an empty one leaves the count where it was, and a swap of
            // two stored entries leaves it where it is too, so only the changes are counted.
            sparse_index atJ = CharonSparseSearch(&asFloat->row[i], j);
            sparse_index atT = CharonSparseSearch(&asFloat->row[i], target);
            int hadJ = atJ < asFloat->row[i].count && asFloat->row[i].column[atJ] == j;
            int hadT = atT < asFloat->row[i].count && asFloat->row[i].column[atT] == target;
            CharonSparsePut(&asFloat->row[i], j, there, size);
            CharonSparsePut(&asFloat->row[i], target, here, size);
            atJ = CharonSparseSearch(&asFloat->row[i], j);
            atT = CharonSparseSearch(&asFloat->row[i], target);
            int hasJ = atJ < asFloat->row[i].count && asFloat->row[i].column[atJ] == j;
            int hasT = atT < asFloat->row[i].count && asFloat->row[i].column[atT] == target;
            asFloat->nonzero += (hasJ + hasT) - (hadJ + hadT);
        }
    }
}

static inline void CharonSparsePermuteColumnsComplex(struct sparse_m_float *asFloat, const sparse_index *perm, size_t size)
{
    for (sparse_dimension j = 0; j < asFloat->columns; j++) {
        sparse_index target = perm[j];
        if (target < 0 || target >= (sparse_index)asFloat->columns || target == (sparse_index)j) {
            continue;
        }
        for (sparse_dimension i = 0; i < asFloat->rows; i++) {
            double hereRe = 0.0, hereIm = 0.0, thereRe = 0.0, thereIm = 0.0;
            CharonSparseElementComplexAt(&asFloat->row[i], j, size, &hereRe, &hereIm);
            CharonSparseElementComplexAt(&asFloat->row[i], target, size, &thereRe, &thereIm);
            sparse_index atJ = CharonSparseSearch(&asFloat->row[i], j);
            sparse_index atT = CharonSparseSearch(&asFloat->row[i], target);
            int hadJ = atJ < asFloat->row[i].count && asFloat->row[i].column[atJ] == j;
            int hadT = atT < asFloat->row[i].count && asFloat->row[i].column[atT] == target;
            CharonSparsePutComplex(&asFloat->row[i], j, thereRe, thereIm, size);
            CharonSparsePutComplex(&asFloat->row[i], target, hereRe, hereIm, size);
            atJ = CharonSparseSearch(&asFloat->row[i], j);
            atT = CharonSparseSearch(&asFloat->row[i], target);
            int hasJ = atJ < asFloat->row[i].count && asFloat->row[i].column[atJ] == j;
            int hasT = atT < asFloat->row[i].count && asFloat->row[i].column[atT] == target;
            asFloat->nonzero += (hasJ + hasT) - (hadJ + hadT);
        }
    }
}
