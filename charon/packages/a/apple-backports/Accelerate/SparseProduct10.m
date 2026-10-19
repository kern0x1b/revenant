// The two sparse-times-sparse products of vecLib/Sparse/BLAS.h, and the object file of their own.
//
// They are here alone because of what the release ladder measured and no header says: of the sixty-nine
// names of this family sixty-seven are first exported by iOS 9.0 and these two by 10.0.1, measured symbol
// by symbol over the armv7 and armv7s caches this port holds, with the whole ladder as the control -
// every cblas_ and LAPACK name the port imports is exported from 4.0, the oldest rung held. One object
// file may not carry two releases' symbols: the gate refuses a file that does and tools/release-split.lua
// names it. So these two are 10.0.1 and the other sixty-seven are 9.0.
// facts/Accelerate/SparseBLAS.md carries the measurement.

#import <Accelerate/Accelerate.h>
#include "CharonSparseBLAS.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wunguarded-availability"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// C = alpha * op(A) * B + C with B sparse too, written out into a dense C. The same rank-one update
// per nonzero, with the row of B taken from its own stored entries. A leading dimension below what
// the layout needs and a matrix that is not one of ours are SPARSE_ILLEGAL_PARAMETER, measured.
static sparse_status CharonSparseProductSparse(void *A, uint32_t magicA, int order, int transposed, double alpha, void *B,
                                               uint32_t magicB, void *C, sparse_dimension ldc, size_t size)
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
    double *row = (double *)calloc(n ? n : 1, sizeof(double));
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
            // A[r, c] in both cases, read through the same lookup the rest of the family uses: the
            // first version bound the row to NULL on the transposed path and then read through it.
            double value = CharonSparseElementAt(&asA->row[r], c, size);
            if (value == 0.0) {
                continue;
            }
            memset(row, 0, (size_t)(n ? n : 1) * sizeof(double));
            const CharonSparseRow *from = &asB->row[transposed ? r : c];
            for (sparse_index b = 0; b < from->count; b++) {
                if (from->column[b] < (sparse_index)n) {
                    row[from->column[b]] = CharonSparseElementAt(from, from->column[b], size);
                }
            }
            long to = CharonSparseDenseAt(order, ldc, i, 0);
            for (sparse_dimension j = 0; j < n; j++) {
                if (row[j] == 0.0) {
                    continue;
                }
                long at2 = to + (long)(j * cStep);
                // The release's own cblas_saxpy does the one multiply-add: the gathered value is the
                // vector and alpha times the entry's own value is the factor, so the product is formed
                // once and by the release's BLAS rather than here.
                if (size == sizeof(float)) {
                    float one = (float)row[j];
                    cblas_saxpy(1, (float)(alpha * value), &one, 1, (float *)C + at2, 1);
                } else {
                    cblas_daxpy(1, alpha * value, &row[j], 1, (double *)C + at2, 1);
                }
            }
        }
    }
    free(row);
    return SPARSE_SUCCESS;
}

sparse_status sparse_matrix_product_sparse_float(enum CBLAS_ORDER order, enum CBLAS_TRANSPOSE transa, float alpha,
                                                 sparse_matrix_float A, sparse_matrix_float B, float *__restrict C,
                                                 sparse_dimension ldc)
{
    if (transa != CblasNoTrans && transa != CblasTrans) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    return CharonSparseProductSparse(A, CHARON_SPARSE_MAGIC_FLOAT, order, transa == CblasTrans, alpha, B,
                                     CHARON_SPARSE_MAGIC_FLOAT, C, ldc, sizeof(float));
}

sparse_status sparse_matrix_product_sparse_double(enum CBLAS_ORDER order, enum CBLAS_TRANSPOSE transa, double alpha,
                                                  sparse_matrix_double A, sparse_matrix_double B, double *__restrict C,
                                                  sparse_dimension ldc)
{
    if (transa != CblasNoTrans && transa != CblasTrans) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    return CharonSparseProductSparse(A, CHARON_SPARSE_MAGIC_DOUBLE, order, transa == CblasTrans, alpha, B,
                                     CHARON_SPARSE_MAGIC_DOUBLE, C, ldc, sizeof(double));
}
