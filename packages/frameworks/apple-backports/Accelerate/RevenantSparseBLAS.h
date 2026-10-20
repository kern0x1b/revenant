#pragma once

#import <Accelerate/Accelerate.h>
#include <math.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef struct RevenantSparseRow {
    sparse_index count;
    sparse_index capacity;
    sparse_index *column;
    void *value;
} RevenantSparseRow;

#define REVENANT_SPARSE_MATRIX_BODY                                                                              \
    uint32_t magic;                                                                                            \
    sparse_dimension rows;                                                                                      \
    sparse_dimension columns;                                                                                   \
    sparse_index blockRows;                                                                                     \
    sparse_index blockColumns;                                                                                  \
    sparse_dimension *blockHeight;        \
    sparse_dimension *blockWidth;                                                     \
    long property;                                                                                             \
    int inserted;                                                                                              \
    long nonzero;                                                                                              \
    RevenantSparseRow *row;

struct sparse_m_float {
    REVENANT_SPARSE_MATRIX_BODY
};

struct sparse_m_double {
    REVENANT_SPARSE_MATRIX_BODY
};

struct sparse_m_float_complex {
    REVENANT_SPARSE_MATRIX_BODY
};

struct sparse_m_double_complex {
    REVENANT_SPARSE_MATRIX_BODY
};

#define REVENANT_SPARSE_MAGIC_FLOAT 0x53504630u
#define REVENANT_SPARSE_MAGIC_DOUBLE 0x53504644u
#define REVENANT_SPARSE_MAGIC_FLOAT_COMPLEX 0x53504643u
#define REVENANT_SPARSE_MAGIC_DOUBLE_COMPLEX 0x53504645u

static inline int RevenantSparseIsMatrix(const void *matrix, uint32_t magic)
{
    return matrix && ((const struct sparse_m_float *)matrix)->magic == magic;
}

static inline int RevenantSparseIsFloat(const void *matrix)
{
    return RevenantSparseIsMatrix(matrix, REVENANT_SPARSE_MAGIC_FLOAT);
}

static inline int RevenantSparseIsDouble(const void *matrix)
{
    return RevenantSparseIsMatrix(matrix, REVENANT_SPARSE_MAGIC_DOUBLE);
}

static inline int RevenantSparseIsFloatComplex(const void *matrix)
{
    return RevenantSparseIsMatrix(matrix, REVENANT_SPARSE_MAGIC_FLOAT_COMPLEX);
}

static inline int RevenantSparseIsDoubleComplex(const void *matrix)
{
    return RevenantSparseIsMatrix(matrix, REVENANT_SPARSE_MAGIC_DOUBLE_COMPLEX);
}

static inline int RevenantSparseIsAny(const void *matrix)
{
    return RevenantSparseIsFloat(matrix) || RevenantSparseIsDouble(matrix) || RevenantSparseIsFloatComplex(matrix) ||
           RevenantSparseIsDoubleComplex(matrix);
}

static inline long RevenantSparseDenseAt(int order, sparse_dimension leading, sparse_dimension row, sparse_dimension column)
{
    return order == CblasRowMajor ? (long)(row * leading + column) : (long)(column * leading + row);
}

static inline sparse_index RevenantSparseSearch(const RevenantSparseRow *row, sparse_index column)
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

static inline int RevenantSparseGrow(RevenantSparseRow *row, sparse_index wanted, size_t size)
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

static inline sparse_status RevenantSparsePut(RevenantSparseRow *row, sparse_index column, double value, size_t size)
{
    sparse_index at = RevenantSparseSearch(row, column);
    if (at < row->count && row->column[at] == column) {
        if (size == sizeof(float)) {
            ((float *)row->value)[at] = (float)value;
        } else {
            ((double *)row->value)[at] = value;
        }
        return SPARSE_SUCCESS;
    }
    if (!RevenantSparseGrow(row, row->count + 1, size)) {
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

static inline double RevenantSparseElementAt(const RevenantSparseRow *row, sparse_index column, size_t size)
{
    sparse_index at = RevenantSparseSearch(row, column);
    if (at >= row->count || row->column[at] != column) {
        return 0.0;
    }
    return size == sizeof(float) ? (double)((const float *)row->value)[at] : ((const double *)row->value)[at];
}

static inline sparse_dimension RevenantSparseBlockAt(const sparse_dimension *sizes, sparse_index blocks, sparse_index element)
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

static inline sparse_status RevenantSparseMake(void **out, uint32_t magic, size_t size, sparse_dimension rows,
                                             sparse_dimension columns, sparse_index blockRows, sparse_index blockColumns,
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
    asFloat->row = totalRows > 0 ? (RevenantSparseRow *)calloc((size_t)totalRows, sizeof(RevenantSparseRow)) : NULL;
    if (totalRows > 0 && !asFloat->row) {
        free(matrix);
        free(height);
        free(width);
        return SPARSE_SYSTEM_ERROR;
    }
    *out = matrix;
    return SPARSE_SUCCESS;
}

static inline sparse_dimension *RevenantSparseRepeated(sparse_dimension value, sparse_index count)
{
    sparse_dimension *sizes = (sparse_dimension *)calloc(count ? (size_t)count : 1, sizeof(sparse_dimension));
    for (sparse_index i = 0; sizes && i < count; i++) {
        sizes[i] = value;
    }
    return sizes;
}

static inline void RevenantSparseWriteComplexValue(void *values, sparse_index at, double re, double im, size_t size)
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

static inline void RevenantSparseReadComplexValue(const void *values, sparse_index at, size_t size, double *re, double *im)
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

static inline sparse_status RevenantSparsePutComplex(RevenantSparseRow *row, sparse_index column, double re, double im,
                                                   size_t size)
{
    sparse_index at = RevenantSparseSearch(row, column);
    if (at < row->count && row->column[at] == column) {
        RevenantSparseWriteComplexValue(row->value, at, re, im, size);
        return SPARSE_SUCCESS;
    }
    if (!RevenantSparseGrow(row, row->count + 1, size)) {
        return SPARSE_SYSTEM_ERROR;
    }
    memmove(row->column + at + 1, row->column + at, (size_t)(row->count - at) * sizeof(sparse_index));
    memmove((char *)row->value + (size_t)(at + 1) * size, (char *)row->value + (size_t)at * size,
            (size_t)(row->count - at) * size);
    row->column[at] = column;
    RevenantSparseWriteComplexValue(row->value, at, re, im, size);
    row->count++;
    return SPARSE_SUCCESS;
}

static inline void RevenantSparseElementComplexAt(const RevenantSparseRow *row, sparse_index column, size_t size, double *re,
                                                double *im)
{
    sparse_index at = RevenantSparseSearch(row, column);
    if (at >= row->count || row->column[at] != column) {
        *re = 0.0;
        *im = 0.0;
        return;
    }
    RevenantSparseReadComplexValue(row->value, at, size, re, im);
}

static inline sparse_status RevenantSparseWritable(const void *matrix, uint32_t magic, int wantBlock,
                                                 struct sparse_m_float **out)
{
    if (!RevenantSparseIsMatrix(matrix, magic)) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    struct sparse_m_float *asFloat = (struct sparse_m_float *)matrix;
    if (wantBlock ? asFloat->blockRows <= 0 : asFloat->blockRows > 0) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    *out = asFloat;
    return SPARSE_SUCCESS;
}

static inline sparse_status RevenantSparsePutEntry(void *matrix, uint32_t magic, double value, sparse_index i,
                                                 sparse_index j, size_t size)
{
    struct sparse_m_float *asFloat = NULL;
    sparse_status ready = RevenantSparseWritable(matrix, magic, 0, &asFloat);
    if (ready != SPARSE_SUCCESS) {
        return ready;
    }
    if (i < 0 || j < 0 || i >= (sparse_index)asFloat->rows || j >= (sparse_index)asFloat->columns) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    sparse_index before = asFloat->row[i].count;
    sparse_status put = RevenantSparsePut(&asFloat->row[i], j, value, size);
    if (put == SPARSE_SUCCESS) {
        asFloat->nonzero += (long)asFloat->row[i].count - (long)before;
        asFloat->inserted = 1;
    }
    return put;
}

static inline sparse_status RevenantSparsePutEntryComplex(void *matrix, uint32_t magic, double re, double im, sparse_index i,
                                                        sparse_index j, size_t size)
{
    struct sparse_m_float *asFloat = NULL;
    sparse_status ready = RevenantSparseWritable(matrix, magic, 0, &asFloat);
    if (ready != SPARSE_SUCCESS) {
        return ready;
    }
    if (i < 0 || j < 0 || i >= (sparse_index)asFloat->rows || j >= (sparse_index)asFloat->columns) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    sparse_index before = asFloat->row[i].count;
    sparse_status put = RevenantSparsePutComplex(&asFloat->row[i], j, re, im, size);
    if (put == SPARSE_SUCCESS) {
        asFloat->nonzero += (long)asFloat->row[i].count - (long)before;
        asFloat->inserted = 1;
    }
    return put;
}

static inline void RevenantSparsePermuteRows(struct sparse_m_float *asFloat, const sparse_index *perm)
{
    for (sparse_dimension i = 0; i < asFloat->rows; i++) {
        sparse_index target = perm[i];
        if (target < 0 || target >= (sparse_index)asFloat->rows || target == (sparse_index)i) {
            continue;
        }
        RevenantSparseRow held = asFloat->row[i];
        asFloat->row[i] = asFloat->row[target];
        asFloat->row[target] = held;
    }
}

static inline void RevenantSparsePermuteColumns(struct sparse_m_float *asFloat, const sparse_index *perm, size_t size)
{
    for (sparse_dimension j = 0; j < asFloat->columns; j++) {
        sparse_index target = perm[j];
        if (target < 0 || target >= (sparse_index)asFloat->columns || target == (sparse_index)j) {
            continue;
        }
        for (sparse_dimension i = 0; i < asFloat->rows; i++) {
            double here = RevenantSparseElementAt(&asFloat->row[i], j, size);
            double there = RevenantSparseElementAt(&asFloat->row[i], target, size);
            sparse_index atJ = RevenantSparseSearch(&asFloat->row[i], j);
            sparse_index atT = RevenantSparseSearch(&asFloat->row[i], target);
            int hadJ = atJ < asFloat->row[i].count && asFloat->row[i].column[atJ] == j;
            int hadT = atT < asFloat->row[i].count && asFloat->row[i].column[atT] == target;
            RevenantSparsePut(&asFloat->row[i], j, there, size);
            RevenantSparsePut(&asFloat->row[i], target, here, size);
            atJ = RevenantSparseSearch(&asFloat->row[i], j);
            atT = RevenantSparseSearch(&asFloat->row[i], target);
            int hasJ = atJ < asFloat->row[i].count && asFloat->row[i].column[atJ] == j;
            int hasT = atT < asFloat->row[i].count && asFloat->row[i].column[atT] == target;
            asFloat->nonzero += (hasJ + hasT) - (hadJ + hadT);
        }
    }
}

static inline void RevenantSparsePermuteColumnsComplex(struct sparse_m_float *asFloat, const sparse_index *perm, size_t size)
{
    for (sparse_dimension j = 0; j < asFloat->columns; j++) {
        sparse_index target = perm[j];
        if (target < 0 || target >= (sparse_index)asFloat->columns || target == (sparse_index)j) {
            continue;
        }
        for (sparse_dimension i = 0; i < asFloat->rows; i++) {
            double hereRe = 0.0, hereIm = 0.0, thereRe = 0.0, thereIm = 0.0;
            RevenantSparseElementComplexAt(&asFloat->row[i], j, size, &hereRe, &hereIm);
            RevenantSparseElementComplexAt(&asFloat->row[i], target, size, &thereRe, &thereIm);
            sparse_index atJ = RevenantSparseSearch(&asFloat->row[i], j);
            sparse_index atT = RevenantSparseSearch(&asFloat->row[i], target);
            int hadJ = atJ < asFloat->row[i].count && asFloat->row[i].column[atJ] == j;
            int hadT = atT < asFloat->row[i].count && asFloat->row[i].column[atT] == target;
            RevenantSparsePutComplex(&asFloat->row[i], j, thereRe, thereIm, size);
            RevenantSparsePutComplex(&asFloat->row[i], target, hereRe, hereIm, size);
            atJ = RevenantSparseSearch(&asFloat->row[i], j);
            atT = RevenantSparseSearch(&asFloat->row[i], target);
            int hasJ = atJ < asFloat->row[i].count && asFloat->row[i].column[atJ] == j;
            int hasT = atT < asFloat->row[i].count && asFloat->row[i].column[atT] == target;
            asFloat->nonzero += (hasJ + hasT) - (hadJ + hadT);
        }
    }
}
