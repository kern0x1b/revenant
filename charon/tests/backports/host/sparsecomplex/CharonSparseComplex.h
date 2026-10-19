// The complex half of vecLib/Sparse/BLAS.h: the fifty-eight entry points of iOS 18.5, and the
// declarations they are written against.
//
// The declarations below are transcribed from the header of iOS 26.2, at
// $HOME/Git/projects/ios/charon/.agent-work/sdk-26.2/iPhoneOS26.2.sdk,
// System/Library/Frameworks/Accelerate.framework/Frameworks/vecLib.framework/Headers/Sparse/BLAS.h, with
// the API_AVAILABLE annotations left off because this is the port's own header and the port's build
// already compiles with -Wno-unguarded-availability. Nothing here is an interface of the port's own
// invention: every prototype is the one the SDK declares, and every one is `ios(18.5)`.
//
// Sparse/Types.h of iOS 26.2 adds two more opaque matrix types to the two the real half completes:
//
//   typedef struct sparse_m_float_complex*  sparse_matrix_float_complex;
//   typedef struct sparse_m_double_complex* sparse_matrix_double_complex;
//
// and CharonSparseBLAS.h carries the same body for both, with a magic word of its own for each, which is
// what lets the entry points the SDK takes a void * matrix for - sparse_matrix_destroy, sparse_commit,
// sparse_get_matrix_number_of_rows and the rest of the counts, sparse_get_block_dimension_for_row and
// _col, sparse_set_matrix_property and sparse_get_matrix_property - answer on a complex matrix on the
// same terms as on a real one. There is no second row structure, no second search and no second growth
// here: the complex half below walks the rows CharonSparseBLAS.h defines.

#pragma once

#import <Accelerate/Accelerate.h>
#include "CharonSparseBLAS.h"   // the carried real half's shared storage, found through -I"$ACCELERATE"

typedef struct sparse_m_float_complex *sparse_matrix_float_complex;
typedef struct sparse_m_double_complex *sparse_matrix_double_complex;

// The value of a stored entry, read or written. A complex value is two adjacent scalars, and which two
// says whether the matrix is of float or of double complex, so a row's value array is addressed through
// the element size alone - 2 * sizeof(float) or 2 * sizeof(double) - and the two halves are named here.
static inline void CharonComplexStore(void *at, int isDouble, double re, double im)
{
    if (isDouble) {
        ((double *)at)[0] = re;
        ((double *)at)[1] = im;
    } else {
        ((float *)at)[0] = (float)re;
        ((float *)at)[1] = (float)im;
    }
}

static inline void CharonComplexLoad(const void *at, int isDouble, double *re, double *im)
{
    if (isDouble) {
        *re = ((const double *)at)[0];
        *im = ((const double *)at)[1];
    } else {
        *re = (double)((const float *)at)[0];
        *im = (double)((const float *)at)[1];
    }
}

static inline size_t CharonComplexSize(int isDouble)
{
    return isDouble ? 2 * sizeof(double) : 2 * sizeof(float);
}

// A[i, j] = re + i * im, the complex form of CharonSparsePut - and the one place the complex half does
// NOT answer as the real half does. Measured on the host: a batch of five distinct entries of which one
// is exactly zero leaves a real matrix's nonzero count at 5 and a complex one's at 4, so the complex
// half does not keep a value of exactly zero in the structure at all. The real half does (measured: an
// entry of 0.0 inserted into an empty matrix leaves its count at 1) and answers SPARSE_SUCCESS either
// way, so the only difference a caller sees is the count and what a later extraction walks.
//
// Writing a value of exactly zero therefore leaves the entry out, and writing zero over an entry that
// is there leaves it out too - the one rule that gives the measured count in both directions. The
// overwrite case is not separately measured and is answered by the same rule, which is the reading
// that makes the count the host's.
static inline sparse_status CharonComplexPut(CharonSparseRow *row, sparse_index column, double re, double im,
                                             size_t size)
{
    sparse_index at = CharonSparseSearch(row, column);
    if (at < row->count && row->column[at] == column) {
        if (re == 0.0 && im == 0.0) {
            memmove(row->column + at, row->column + at + 1, (size_t)(row->count - at - 1) * sizeof(sparse_index));
            memmove((char *)row->value + (size_t)at * size, (char *)row->value + (size_t)(at + 1) * size,
                    (size_t)(row->count - at - 1) * size);
            row->count--;
            return SPARSE_SUCCESS;
        }
        CharonComplexStore((char *)row->value + (size_t)at * size, size == 2 * sizeof(double), re, im);
        return SPARSE_SUCCESS;
    }
    if (re == 0.0 && im == 0.0) {
        return SPARSE_SUCCESS;
    }
    if (!CharonSparseGrow(row, row->count + 1, size)) {
        return SPARSE_SYSTEM_ERROR;
    }
    memmove(row->column + at + 1, row->column + at, (size_t)(row->count - at) * sizeof(sparse_index));
    memmove((char *)row->value + (size_t)(at + 1) * size, (char *)row->value + (size_t)at * size,
            (size_t)(row->count - at) * size);
    row->column[at] = column;
    CharonComplexStore((char *)row->value + (size_t)at * size, size == 2 * sizeof(double), re, im);
    row->count++;
    return SPARSE_SUCCESS;
}

// A[i, j], read: the stored value, or zero for a column the row does not hold.
static inline void CharonComplexElementAt(const CharonSparseRow *row, sparse_index column, size_t size, double *re,
                                          double *im)
{
    sparse_index at = CharonSparseSearch(row, column);
    if (at >= row->count || row->column[at] != column) {
        *re = 0.0;
        *im = 0.0;
        return;
    }
    CharonComplexLoad((const char *)row->value + (size_t)at * size, size == 2 * sizeof(double), re, im);
}

// ---------------------------------------------------------------- the fifty-eight declarations

sparse_matrix_float_complex sparse_matrix_create_float_complex(sparse_dimension M, sparse_dimension N);
sparse_matrix_double_complex sparse_matrix_create_double_complex(sparse_dimension M, sparse_dimension N);
sparse_matrix_float_complex sparse_matrix_block_create_float_complex(sparse_dimension Mb, sparse_dimension Nb,
                                                                     sparse_dimension k, sparse_dimension l);
sparse_matrix_double_complex sparse_matrix_block_create_double_complex(sparse_dimension Mb, sparse_dimension Nb,
                                                                       sparse_dimension k, sparse_dimension l);
sparse_matrix_float_complex sparse_matrix_variable_block_create_float_complex(sparse_dimension Mb, sparse_dimension Nb,
                                                                             const sparse_dimension *K,
                                                                             const sparse_dimension *L);
sparse_matrix_double_complex sparse_matrix_variable_block_create_double_complex(sparse_dimension Mb,
                                                                               sparse_dimension Nb,
                                                                               const sparse_dimension *K,
                                                                               const sparse_dimension *L);

sparse_status sparse_insert_entry_float_complex(sparse_matrix_float_complex A, float _Complex val, sparse_index i,
                                                sparse_index j);
sparse_status sparse_insert_entry_double_complex(sparse_matrix_double_complex A, double _Complex val, sparse_index i,
                                                 sparse_index j);
sparse_status sparse_insert_entries_float_complex(sparse_matrix_float_complex A, sparse_dimension N,
                                                  const float _Complex *__restrict val,
                                                  const sparse_index *__restrict indx,
                                                  const sparse_index *__restrict jndx);
sparse_status sparse_insert_entries_double_complex(sparse_matrix_double_complex A, sparse_dimension N,
                                                   const double _Complex *__restrict val,
                                                   const sparse_index *__restrict indx,
                                                   const sparse_index *__restrict jndx);
sparse_status sparse_insert_row_float_complex(sparse_matrix_float_complex A, sparse_index i, sparse_dimension nz,
                                              const float _Complex *__restrict val,
                                              const sparse_index *__restrict jndx);
sparse_status sparse_insert_row_double_complex(sparse_matrix_double_complex A, sparse_index i, sparse_dimension nz,
                                               const double _Complex *__restrict val,
                                               const sparse_index *__restrict jndx);
sparse_status sparse_insert_col_float_complex(sparse_matrix_float_complex A, sparse_index j, sparse_dimension nz,
                                              const float _Complex *__restrict val,
                                              const sparse_index *__restrict indx);
sparse_status sparse_insert_col_double_complex(sparse_matrix_double_complex A, sparse_index j, sparse_dimension nz,
                                               const double _Complex *__restrict val,
                                               const sparse_index *__restrict indx);
sparse_status sparse_insert_block_float_complex(sparse_matrix_float_complex A, const float _Complex *__restrict val,
                                                sparse_dimension row_stride, sparse_dimension col_stride,
                                                sparse_index bi, sparse_index bj);
sparse_status sparse_insert_block_double_complex(sparse_matrix_double_complex A, const double _Complex *__restrict val,
                                                 sparse_dimension row_stride, sparse_dimension col_stride,
                                                 sparse_index bi, sparse_index bj);

sparse_status sparse_extract_sparse_row_float_complex(sparse_matrix_float_complex A, sparse_index row,
                                                      sparse_index column_start, sparse_index *column_end,
                                                      sparse_dimension nz, float _Complex *__restrict val,
                                                      sparse_index *__restrict jndx);
sparse_status sparse_extract_sparse_row_double_complex(sparse_matrix_double_complex A, sparse_index row,
                                                       sparse_index column_start, sparse_index *column_end,
                                                       sparse_dimension nz, double _Complex *__restrict val,
                                                       sparse_index *__restrict jndx);
sparse_status sparse_extract_sparse_column_float_complex(sparse_matrix_float_complex A, sparse_index column,
                                                         sparse_index row_start, sparse_index *row_end,
                                                         sparse_dimension nz, float _Complex *__restrict val,
                                                         sparse_index *__restrict jndx);
sparse_status sparse_extract_sparse_column_double_complex(sparse_matrix_double_complex A, sparse_index column,
                                                          sparse_index row_start, sparse_index *row_end,
                                                          sparse_dimension nz, double _Complex *__restrict val,
                                                          sparse_index *__restrict jndx);
sparse_status sparse_extract_block_float_complex(sparse_matrix_float_complex A, sparse_index bi, sparse_index bj,
                                                 sparse_dimension row_stride, sparse_dimension col_stride,
                                                 float _Complex *__restrict val);
sparse_status sparse_extract_block_double_complex(sparse_matrix_double_complex A, sparse_index bi, sparse_index bj,
                                                  sparse_dimension row_stride, sparse_dimension col_stride,
                                                  double _Complex *__restrict val);

float _Complex sparse_inner_product_dense_float_complex(sparse_dimension nz, const float _Complex *__restrict x,
                                                        const sparse_index *__restrict indx,
                                                        const float _Complex *__restrict y, sparse_stride incy);
double _Complex sparse_inner_product_dense_double_complex(sparse_dimension nz, const double _Complex *__restrict x,
                                                          const sparse_index *__restrict indx,
                                                          const double _Complex *__restrict y, sparse_stride incy);
float _Complex sparse_inner_product_sparse_float_complex(sparse_dimension nzx, sparse_dimension nzy,
                                                         const float _Complex *__restrict x,
                                                         const sparse_index *__restrict indx,
                                                         const float _Complex *__restrict y,
                                                         const sparse_index *__restrict indy);
double _Complex sparse_inner_product_sparse_double_complex(sparse_dimension nzx, sparse_dimension nzy,
                                                          const double _Complex *__restrict x,
                                                          const sparse_index *__restrict indx,
                                                          const double _Complex *__restrict y,
                                                          const sparse_index *__restrict indy);
void sparse_vector_add_with_scale_dense_float_complex(sparse_dimension nz, float _Complex alpha,
                                                       const float _Complex *__restrict x,
                                                       const sparse_index *__restrict indx,
                                                       float _Complex *__restrict y, sparse_stride incy);
void sparse_vector_add_with_scale_dense_double_complex(sparse_dimension nz, double _Complex alpha,
                                                      const double _Complex *__restrict x,
                                                      const sparse_index *__restrict indx,
                                                      double _Complex *__restrict y, sparse_stride incy);
float sparse_vector_norm_float_complex(sparse_dimension nz, const float _Complex *__restrict x,
                                       const sparse_index *__restrict indx, sparse_norm norm);
double sparse_vector_norm_double_complex(sparse_dimension nz, const double _Complex *__restrict x,
                                         const sparse_index *__restrict indx, sparse_norm norm);
long sparse_get_vector_nonzero_count_float_complex(sparse_dimension N, const float _Complex *__restrict x,
                                                    sparse_stride incx);
long sparse_get_vector_nonzero_count_double_complex(sparse_dimension N, const double _Complex *__restrict x,
                                                     sparse_stride incx);
long sparse_pack_vector_float_complex(sparse_dimension N, sparse_dimension nz, const float _Complex *__restrict x,
                                      sparse_stride incx, float _Complex *__restrict y,
                                      sparse_index *__restrict indy);
long sparse_pack_vector_double_complex(sparse_dimension N, sparse_dimension nz, const double _Complex *__restrict x,
                                       sparse_stride incx, double _Complex *__restrict y,
                                       sparse_index *__restrict indy);
void sparse_unpack_vector_float_complex(sparse_dimension N, sparse_dimension nz, bool zero,
                                        const float _Complex *__restrict x, const sparse_index *__restrict indx,
                                        float _Complex *__restrict y, sparse_stride incy);
void sparse_unpack_vector_double_complex(sparse_dimension N, sparse_dimension nz, bool zero,
                                         const double _Complex *__restrict x, const sparse_index *__restrict indx,
                                         double _Complex *__restrict y, sparse_stride incy);

sparse_status sparse_matrix_vector_product_dense_float_complex(enum CBLAS_TRANSPOSE transa, float _Complex alpha,
                                                               sparse_matrix_float_complex A,
                                                               const float _Complex *__restrict x,
                                                               sparse_stride incx, float _Complex *__restrict y,
                                                               sparse_stride incy);
sparse_status sparse_matrix_vector_product_dense_double_complex(enum CBLAS_TRANSPOSE transa, double _Complex alpha,
                                                                sparse_matrix_double_complex A,
                                                                const double _Complex *__restrict x,
                                                                sparse_stride incx, double _Complex *__restrict y,
                                                                sparse_stride incy);
sparse_status sparse_vector_triangular_solve_dense_float_complex(enum CBLAS_TRANSPOSE transt, float _Complex alpha,
                                                                sparse_matrix_float_complex T,
                                                                float _Complex *__restrict x, sparse_stride incx);
sparse_status sparse_vector_triangular_solve_dense_double_complex(enum CBLAS_TRANSPOSE transt, double _Complex alpha,
                                                                 sparse_matrix_double_complex T,
                                                                 double _Complex *__restrict x, sparse_stride incx);
sparse_status sparse_matrix_triangular_solve_dense_float_complex(enum CBLAS_ORDER order, enum CBLAS_TRANSPOSE transt,
                                                                 sparse_dimension nrhs, float _Complex alpha,
                                                                 sparse_matrix_float_complex T,
                                                                 float _Complex *__restrict B, sparse_dimension ldb);
sparse_status sparse_matrix_triangular_solve_dense_double_complex(enum CBLAS_ORDER order, enum CBLAS_TRANSPOSE transt,
                                                                  sparse_dimension nrhs, double _Complex alpha,
                                                                  sparse_matrix_double_complex T,
                                                                  double _Complex *__restrict B, sparse_dimension ldb);
sparse_status sparse_outer_product_dense_float_complex(sparse_dimension M, sparse_dimension N, sparse_dimension nz,
                                                        float _Complex alpha, const float _Complex *__restrict x,
                                                        sparse_stride incx, const float _Complex *__restrict y,
                                                        const sparse_index *__restrict indy,
                                                        sparse_matrix_float_complex *__restrict C);
sparse_status sparse_outer_product_dense_double_complex(sparse_dimension M, sparse_dimension N, sparse_dimension nz,
                                                         double _Complex alpha, const double _Complex *__restrict x,
                                                         sparse_stride incx, const double _Complex *__restrict y,
                                                         const sparse_index *__restrict indy,
                                                         sparse_matrix_double_complex *__restrict C);
sparse_status sparse_permute_rows_float_complex(sparse_matrix_float_complex A, const sparse_index *__restrict perm);
sparse_status sparse_permute_rows_double_complex(sparse_matrix_double_complex A, const sparse_index *__restrict perm);
sparse_status sparse_permute_cols_float_complex(sparse_matrix_float_complex A, const sparse_index *__restrict perm);
sparse_status sparse_permute_cols_double_complex(sparse_matrix_double_complex A, const sparse_index *__restrict perm);
float sparse_elementwise_norm_float_complex(sparse_matrix_float_complex A, sparse_norm norm);
double sparse_elementwise_norm_double_complex(sparse_matrix_double_complex A, sparse_norm norm);
float sparse_operator_norm_float_complex(sparse_matrix_float_complex A, sparse_norm norm);
double sparse_operator_norm_double_complex(sparse_matrix_double_complex A, sparse_norm norm);
float _Complex sparse_matrix_trace_float_complex(sparse_matrix_float_complex A, sparse_index offset);
double _Complex sparse_matrix_trace_double_complex(sparse_matrix_double_complex A, sparse_index offset);
sparse_status sparse_matrix_product_dense_float_complex(enum CBLAS_ORDER order, enum CBLAS_TRANSPOSE transa,
                                                        sparse_dimension n, float _Complex alpha,
                                                        sparse_matrix_float_complex A,
                                                        const float _Complex *__restrict B, sparse_dimension ldb,
                                                        float _Complex *__restrict C, sparse_dimension ldc);
sparse_status sparse_matrix_product_dense_double_complex(enum CBLAS_ORDER order, enum CBLAS_TRANSPOSE transa,
                                                         sparse_dimension n, double _Complex alpha,
                                                         sparse_matrix_double_complex A,
                                                         const double _Complex *__restrict B, sparse_dimension ldb,
                                                         double _Complex *__restrict C, sparse_dimension ldc);
sparse_status sparse_matrix_product_sparse_float_complex(enum CBLAS_ORDER order, enum CBLAS_TRANSPOSE transa,
                                                         float _Complex alpha, sparse_matrix_float_complex A,
                                                         sparse_matrix_float_complex B,
                                                         float _Complex *__restrict C, sparse_dimension ldc);
sparse_status sparse_matrix_product_sparse_double_complex(enum CBLAS_ORDER order, enum CBLAS_TRANSPOSE transa,
                                                          double _Complex alpha, sparse_matrix_double_complex A,
                                                          sparse_matrix_double_complex B,
                                                          double _Complex *__restrict C, sparse_dimension ldc);
