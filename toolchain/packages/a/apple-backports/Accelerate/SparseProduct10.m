#import <Accelerate/Accelerate.h>
#include "RevenantSparseBLAS.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wunguarded-availability"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static sparse_status RevenantSparseProductSparse(void *A, uint32_t magicA, int order, int transposed, double alpha, void *B,
                                               uint32_t magicB, void *C, sparse_dimension ldc, size_t size)
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
    double *row = (double *)calloc(n ? n : 1, sizeof(double));
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
            double value = RevenantSparseElementAt(&asA->row[r], c, size);
            if (value == 0.0) {
                continue;
            }
            memset(row, 0, (size_t)(n ? n : 1) * sizeof(double));
            const RevenantSparseRow *from = &asB->row[transposed ? r : c];
            for (sparse_index b = 0; b < from->count; b++) {
                if (from->column[b] < (sparse_index)n) {
                    row[from->column[b]] = RevenantSparseElementAt(from, from->column[b], size);
                }
            }
            long to = RevenantSparseDenseAt(order, ldc, i, 0);
            for (sparse_dimension j = 0; j < n; j++) {
                if (row[j] == 0.0) {
                    continue;
                }
                long at2 = to + (long)(j * cStep);
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
    return RevenantSparseProductSparse(A, REVENANT_SPARSE_MAGIC_FLOAT, order, transa == CblasTrans, alpha, B,
                                     REVENANT_SPARSE_MAGIC_FLOAT, C, ldc, sizeof(float));
}

sparse_status sparse_matrix_product_sparse_double(enum CBLAS_ORDER order, enum CBLAS_TRANSPOSE transa, double alpha,
                                                  sparse_matrix_double A, sparse_matrix_double B, double *__restrict C,
                                                  sparse_dimension ldc)
{
    if (transa != CblasNoTrans && transa != CblasTrans) {
        return SPARSE_ILLEGAL_PARAMETER;
    }
    return RevenantSparseProductSparse(A, REVENANT_SPARSE_MAGIC_DOUBLE, order, transa == CblasTrans, alpha, B,
                                     REVENANT_SPARSE_MAGIC_DOUBLE, C, ldc, sizeof(double));
}
