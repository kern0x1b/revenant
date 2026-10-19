// CharonSparseComplex26.h - the complex sparse BLAS of Sparse/BLAS.h, which the SDK this package
// compiles against does not have.
//
// The iPhoneOS 16.4 SDK is what this package compiles against, and it ends before the complex scalar
// type of the sparse BLAS: Sparse/Types.h declares sparse_matrix_float and sparse_matrix_double and
// nothing else, and Sparse/BLAS.h declares the sixty-nine entry points of the two real types and not
// one of the fifty-eight the complex types have. iOS 18.5 added them. They are transcribed here from
// the 26.2 headers, so that an application built against the 26.2 surface compiles at all, and every
// name below is an R4 item.
//
// Transcribed is not the same as implemented, and nothing here is a declaration only: all fifty-eight
// are implemented, in Accelerate/SparseComplex18.m, and each has its row in
// registry/Accelerate/ios18sparsecomplex.json. The implementation is measured against the host's own
// Accelerate, case by case, by tests/backports/host/sparseblas/differential-complex.m, and
// facts/Accelerate/SparseComplex.md carries the measurements.
//
// Transcribed from $SDK26/System/Library/Frameworks/Accelerate.framework/Frameworks/vecLib.framework/
// Headers/Sparse/Types.h and BLAS.h, read on 2026-10-03. Nothing here is invented: it is what 26.2
// says, copied. The API_AVAILABLE attributes of the original are dropped, because a declaration in a
// header of this package is not gated and nothing here is Apple's availability macro; the release
// each name arrived in is what the registry rows carry.

#ifndef CHARON_SPARSE_COMPLEX_26_H
#define CHARON_SPARSE_COMPLEX_26_H

#import <Accelerate/Accelerate.h>

// Sparse/Types.h, iOS 18.5: the two complex matrix types, opaque in the header, which is what an
// implementation completes. CharonSparseBLAS.h gives both the same body the two real types have.
typedef struct sparse_m_float_complex *sparse_matrix_float_complex;
typedef struct sparse_m_double_complex *sparse_matrix_double_complex;

// ---------------------------------------------------------------- the shape of a matrix

sparse_matrix_float_complex sparse_matrix_create_float_complex(sparse_dimension M, sparse_dimension N);
sparse_matrix_double_complex sparse_matrix_create_double_complex(sparse_dimension M, sparse_dimension N);
sparse_matrix_float_complex sparse_matrix_block_create_float_complex(sparse_dimension Mb, sparse_dimension Nb,
                                                                     sparse_dimension k, sparse_dimension l);
sparse_matrix_double_complex sparse_matrix_block_create_double_complex(sparse_dimension Mb, sparse_dimension Nb,
                                                                       sparse_dimension k, sparse_dimension l);
sparse_matrix_float_complex sparse_matrix_variable_block_create_float_complex(sparse_dimension Mb, sparse_dimension Nb,
                                                                             const sparse_dimension *K,
                                                                             const sparse_dimension *L);
sparse_matrix_double_complex sparse_matrix_variable_block_create_double_complex(sparse_dimension Mb, sparse_dimension Nb,
                                                                               const sparse_dimension *K,
                                                                               const sparse_dimension *L);

// ---------------------------------------------------------------- writing a matrix

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
sparse_status sparse_insert_col_float_complex(sparse_matrix_float_complex A, sparse_index j, sparse_dimension nz,
                                              const float _Complex *__restrict val,
                                              const sparse_index *__restrict indx);
sparse_status sparse_insert_col_double_complex(sparse_matrix_double_complex A, sparse_index j, sparse_dimension nz,
                                                const double _Complex *__restrict val,
                                                const sparse_index *__restrict indx);
sparse_status sparse_insert_row_float_complex(sparse_matrix_float_complex A, sparse_index i, sparse_dimension nz,
                                              const float _Complex *__restrict val,
                                              const sparse_index *__restrict jndx);
sparse_status sparse_insert_row_double_complex(sparse_matrix_double_complex A, sparse_index i, sparse_dimension nz,
                                                const double _Complex *__restrict val,
                                                const sparse_index *__restrict jndx);
sparse_status sparse_insert_block_float_complex(sparse_matrix_float_complex A, const float _Complex *__restrict val,
                                                sparse_dimension row_stride, sparse_dimension col_stride,
                                                sparse_index bi, sparse_index bj);
sparse_status sparse_insert_block_double_complex(sparse_matrix_double_complex A, const double _Complex *__restrict val,
                                                 sparse_dimension row_stride, sparse_dimension col_stride,
                                                 sparse_index bi, sparse_index bj);

// ---------------------------------------------------------------- reading a matrix

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
                                                         sparse_index *__restrict indx);
sparse_status sparse_extract_sparse_column_double_complex(sparse_matrix_double_complex A, sparse_index column,
                                                          sparse_index row_start, sparse_index *row_end,
                                                          sparse_dimension nz, double _Complex *__restrict val,
                                                          sparse_index *__restrict indx);
sparse_status sparse_extract_block_float_complex(sparse_matrix_float_complex A, sparse_index bi, sparse_index bj,
                                                 sparse_dimension row_stride, sparse_dimension col_stride,
                                                 float _Complex *__restrict val);
sparse_status sparse_extract_block_double_complex(sparse_matrix_double_complex A, sparse_index bi, sparse_index bj,
                                                  sparse_dimension row_stride, sparse_dimension col_stride,
                                                  double _Complex *__restrict val);

// ---------------------------------------------------------------- level 1

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

// ---------------------------------------------------------------- level 2

sparse_status sparse_matrix_vector_product_dense_float_complex(enum CBLAS_TRANSPOSE transa, float _Complex alpha,
                                                               sparse_matrix_float_complex A,
                                                               const float _Complex *__restrict x, sparse_stride incx,
                                                               float _Complex *__restrict y, sparse_stride incy);
sparse_status sparse_matrix_vector_product_dense_double_complex(enum CBLAS_TRANSPOSE transa, double _Complex alpha,
                                                                sparse_matrix_double_complex A,
                                                                const double _Complex *__restrict x, sparse_stride incx,
                                                                double _Complex *__restrict y, sparse_stride incy);
sparse_status sparse_vector_triangular_solve_dense_float_complex(enum CBLAS_TRANSPOSE transt, float _Complex alpha,
                                                                 sparse_matrix_float_complex T,
                                                                 float _Complex *__restrict x, sparse_stride incx);
sparse_status sparse_vector_triangular_solve_dense_double_complex(enum CBLAS_TRANSPOSE transt, double _Complex alpha,
                                                                  sparse_matrix_double_complex T,
                                                                  double _Complex *__restrict x, sparse_stride incx);

// ---------------------------------------------------------------- level 3

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

// ---------------------------------------------------------------- the permutations, the norms, the trace

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

#endif // CHARON_SPARSE_COMPLEX_26_H
