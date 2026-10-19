// The port's SparseComplex18.m held against the host's own Accelerate, case by case.
//
// The port's translation unit is compiled with every API name it defines renamed, so this one holds the
// port's objects and the host's side by side and compares what each answers: a status, a count, and
// every element of a matrix or a vector. The declarations here are the ones of the header the port is
// compiled against (CharonSparseComplex26.h, which is the 26.2 one transcribed), so the two sides are
// called through one set of prototypes.
//
// The rules the cases follow are the real family's, from differential.m and its header comment:
//
//   - Nothing is asked through a pointer the host would read outside of. A strided vector is given a
//     buffer of N * |stride| elements, and a dense B in a level-3 product a buffer of the size its
//     leading dimension and shape require.
//   - A negative stride is asked the way the header says to ask it: the pointer is the LAST element.
//   - The port's matrices are its own objects, so every query about one is asked through the port's own
//     untyped entry points, which take a void * matrix and are renamed with the rest.
//   - No matrix that is not one of ours is handed to either side: the host dereferences a foreign
//     pointer and the run dies (measured: sparse_elementwise_norm_float_complex on 0x1234 is a SIGBUS),
//     so the refusal cases below are the header's own rather than the host's.
//
// The one case where the host's answer is not reproducible is the last element of a triangular solve,
// where the host answers a zero real part and the correct answer in its imaginary part while its own
// first elements follow the rule below. That one is checked against the header's rule instead and is
// marked "header" in its name; facts/Accelerate/SparseComplex.md carries both numbers.

#import <Accelerate/Accelerate.h>
#include "CharonSparseComplex26.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>


#define RENAME(name) charon_host_##name

// ---------------------------------------------------------------- the port's own entry points

sparse_matrix_float_complex RENAME(sparse_matrix_create_float_complex)(sparse_dimension, sparse_dimension);
sparse_matrix_double_complex RENAME(sparse_matrix_create_double_complex)(sparse_dimension, sparse_dimension);
sparse_matrix_float_complex RENAME(sparse_matrix_block_create_float_complex)(sparse_dimension, sparse_dimension, sparse_dimension, sparse_dimension);
sparse_matrix_double_complex RENAME(sparse_matrix_block_create_double_complex)(sparse_dimension, sparse_dimension, sparse_dimension, sparse_dimension);
sparse_matrix_float_complex RENAME(sparse_matrix_variable_block_create_float_complex)(sparse_dimension, sparse_dimension, const sparse_dimension *, const sparse_dimension *);
sparse_matrix_double_complex RENAME(sparse_matrix_variable_block_create_double_complex)(sparse_dimension, sparse_dimension, const sparse_dimension *, const sparse_dimension *);
sparse_status RENAME(sparse_insert_entry_float_complex)(sparse_matrix_float_complex, float _Complex, sparse_index, sparse_index);
sparse_status RENAME(sparse_insert_entry_double_complex)(sparse_matrix_double_complex, double _Complex, sparse_index, sparse_index);
sparse_status RENAME(sparse_insert_entries_float_complex)(sparse_matrix_float_complex, sparse_dimension, const float _Complex *, const sparse_index *, const sparse_index *);
sparse_status RENAME(sparse_insert_entries_double_complex)(sparse_matrix_double_complex, sparse_dimension, const double _Complex *, const sparse_index *, const sparse_index *);
sparse_status RENAME(sparse_insert_row_float_complex)(sparse_matrix_float_complex, sparse_index, sparse_dimension, const float _Complex *, const sparse_index *);
sparse_status RENAME(sparse_insert_row_double_complex)(sparse_matrix_double_complex, sparse_index, sparse_dimension, const double _Complex *, const sparse_index *);
sparse_status RENAME(sparse_insert_col_float_complex)(sparse_matrix_float_complex, sparse_index, sparse_dimension, const float _Complex *, const sparse_index *);
sparse_status RENAME(sparse_insert_col_double_complex)(sparse_matrix_double_complex, sparse_index, sparse_dimension, const double _Complex *, const sparse_index *);
sparse_status RENAME(sparse_insert_block_float_complex)(sparse_matrix_float_complex, const float _Complex *, sparse_dimension, sparse_dimension, sparse_index, sparse_index);
sparse_status RENAME(sparse_insert_block_double_complex)(sparse_matrix_double_complex, const double _Complex *, sparse_dimension, sparse_dimension, sparse_index, sparse_index);
sparse_status RENAME(sparse_extract_sparse_row_float_complex)(sparse_matrix_float_complex, sparse_index, sparse_index, sparse_index *, sparse_dimension, float _Complex *, sparse_index *);
sparse_status RENAME(sparse_extract_sparse_row_double_complex)(sparse_matrix_double_complex, sparse_index, sparse_index, sparse_index *, sparse_dimension, double _Complex *, sparse_index *);
sparse_status RENAME(sparse_extract_sparse_column_float_complex)(sparse_matrix_float_complex, sparse_index, sparse_index, sparse_index *, sparse_dimension, float _Complex *, sparse_index *);
sparse_status RENAME(sparse_extract_sparse_column_double_complex)(sparse_matrix_double_complex, sparse_index, sparse_index, sparse_index *, sparse_dimension, double _Complex *, sparse_index *);
sparse_status RENAME(sparse_extract_block_float_complex)(sparse_matrix_float_complex, sparse_index, sparse_index, sparse_dimension, sparse_dimension, float _Complex *);
sparse_status RENAME(sparse_extract_block_double_complex)(sparse_matrix_double_complex, sparse_index, sparse_index, sparse_dimension, sparse_dimension, double _Complex *);
float _Complex RENAME(sparse_inner_product_dense_float_complex)(sparse_dimension, const float _Complex *, const sparse_index *, const float _Complex *, sparse_stride);
double _Complex RENAME(sparse_inner_product_dense_double_complex)(sparse_dimension, const double _Complex *, const sparse_index *, const double _Complex *, sparse_stride);
float _Complex RENAME(sparse_inner_product_sparse_float_complex)(sparse_dimension, sparse_dimension, const float _Complex *, const sparse_index *, const float _Complex *, const sparse_index *);
double _Complex RENAME(sparse_inner_product_sparse_double_complex)(sparse_dimension, sparse_dimension, const double _Complex *, const sparse_index *, const double _Complex *, const sparse_index *);
void RENAME(sparse_vector_add_with_scale_dense_float_complex)(sparse_dimension, float _Complex, const float _Complex *, const sparse_index *, float _Complex *, sparse_stride);
void RENAME(sparse_vector_add_with_scale_dense_double_complex)(sparse_dimension, double _Complex, const double _Complex *, const sparse_index *, double _Complex *, sparse_stride);
float RENAME(sparse_vector_norm_float_complex)(sparse_dimension, const float _Complex *, const sparse_index *, sparse_norm);
double RENAME(sparse_vector_norm_double_complex)(sparse_dimension, const double _Complex *, const sparse_index *, sparse_norm);
long RENAME(sparse_get_vector_nonzero_count_float_complex)(sparse_dimension, const float _Complex *, sparse_stride);
long RENAME(sparse_get_vector_nonzero_count_double_complex)(sparse_dimension, const double _Complex *, sparse_stride);
long RENAME(sparse_pack_vector_float_complex)(sparse_dimension, sparse_dimension, const float _Complex *, sparse_stride, float _Complex *, sparse_index *);
long RENAME(sparse_pack_vector_double_complex)(sparse_dimension, sparse_dimension, const double _Complex *, sparse_stride, double _Complex *, sparse_index *);
void RENAME(sparse_unpack_vector_float_complex)(sparse_dimension, sparse_dimension, bool, const float _Complex *, const sparse_index *, float _Complex *, sparse_stride);
void RENAME(sparse_unpack_vector_double_complex)(sparse_dimension, sparse_dimension, bool, const double _Complex *, const sparse_index *, double _Complex *, sparse_stride);
sparse_status RENAME(sparse_matrix_vector_product_dense_float_complex)(enum CBLAS_TRANSPOSE, float _Complex, sparse_matrix_float_complex, const float _Complex *, sparse_stride, float _Complex *, sparse_stride);
sparse_status RENAME(sparse_matrix_vector_product_dense_double_complex)(enum CBLAS_TRANSPOSE, double _Complex, sparse_matrix_double_complex, const double _Complex *, sparse_stride, double _Complex *, sparse_stride);
sparse_status RENAME(sparse_vector_triangular_solve_dense_float_complex)(enum CBLAS_TRANSPOSE, float _Complex, sparse_matrix_float_complex, float _Complex *, sparse_stride);
sparse_status RENAME(sparse_vector_triangular_solve_dense_double_complex)(enum CBLAS_TRANSPOSE, double _Complex, sparse_matrix_double_complex, double _Complex *, sparse_stride);
sparse_status RENAME(sparse_matrix_triangular_solve_dense_float_complex)(enum CBLAS_ORDER, enum CBLAS_TRANSPOSE, sparse_dimension, float _Complex, sparse_matrix_float_complex, float _Complex *, sparse_dimension);
sparse_status RENAME(sparse_matrix_triangular_solve_dense_double_complex)(enum CBLAS_ORDER, enum CBLAS_TRANSPOSE, sparse_dimension, double _Complex, sparse_matrix_double_complex, double _Complex *, sparse_dimension);
sparse_status RENAME(sparse_matrix_product_dense_float_complex)(enum CBLAS_ORDER, enum CBLAS_TRANSPOSE, sparse_dimension, float _Complex, sparse_matrix_float_complex, const float _Complex *, sparse_dimension, float _Complex *, sparse_dimension);
sparse_status RENAME(sparse_matrix_product_dense_double_complex)(enum CBLAS_ORDER, enum CBLAS_TRANSPOSE, sparse_dimension, double _Complex, sparse_matrix_double_complex, const double _Complex *, sparse_dimension, double _Complex *, sparse_dimension);
sparse_status RENAME(sparse_outer_product_dense_float_complex)(sparse_dimension, sparse_dimension, sparse_dimension, float _Complex, const float _Complex *, sparse_stride, const float _Complex *, const sparse_index *, sparse_matrix_float_complex *);
sparse_status RENAME(sparse_outer_product_dense_double_complex)(sparse_dimension, sparse_dimension, sparse_dimension, double _Complex, const double _Complex *, sparse_stride, const double _Complex *, const sparse_index *, sparse_matrix_double_complex *);
sparse_status RENAME(sparse_matrix_product_sparse_float_complex)(enum CBLAS_ORDER, enum CBLAS_TRANSPOSE, float _Complex, sparse_matrix_float_complex, sparse_matrix_float_complex, float _Complex *, sparse_dimension);
sparse_status RENAME(sparse_matrix_product_sparse_double_complex)(enum CBLAS_ORDER, enum CBLAS_TRANSPOSE, double _Complex, sparse_matrix_double_complex, sparse_matrix_double_complex, double _Complex *, sparse_dimension);
sparse_status RENAME(sparse_permute_rows_float_complex)(sparse_matrix_float_complex, const sparse_index *);
sparse_status RENAME(sparse_permute_rows_double_complex)(sparse_matrix_double_complex, const sparse_index *);
sparse_status RENAME(sparse_permute_cols_float_complex)(sparse_matrix_float_complex, const sparse_index *);
sparse_status RENAME(sparse_permute_cols_double_complex)(sparse_matrix_double_complex, const sparse_index *);
float RENAME(sparse_elementwise_norm_float_complex)(sparse_matrix_float_complex, sparse_norm);
double RENAME(sparse_elementwise_norm_double_complex)(sparse_matrix_double_complex, sparse_norm);
float RENAME(sparse_operator_norm_float_complex)(sparse_matrix_float_complex, sparse_norm);
double RENAME(sparse_operator_norm_double_complex)(sparse_matrix_double_complex, sparse_norm);
float _Complex RENAME(sparse_matrix_trace_float_complex)(sparse_matrix_float_complex, sparse_index);
double _Complex RENAME(sparse_matrix_trace_double_complex)(sparse_matrix_double_complex, sparse_index);

// The untyped queries, which take a void * matrix and answer on a complex one on the same terms as on a
// real one (SparseBLAS9.m already routes all four types through them).
sparse_dimension RENAME(sparse_get_matrix_number_of_rows)(void *);
sparse_dimension RENAME(sparse_get_matrix_number_of_columns)(void *);
long RENAME(sparse_get_matrix_nonzero_count)(void *);
long RENAME(sparse_get_matrix_nonzero_count_for_row)(void *, sparse_index);
long RENAME(sparse_get_matrix_nonzero_count_for_column)(void *, sparse_index);
long RENAME(sparse_get_block_dimension_for_row)(void *, sparse_index);
long RENAME(sparse_get_block_dimension_for_col)(void *, sparse_index);
sparse_status RENAME(sparse_commit)(void *);
sparse_status RENAME(sparse_matrix_destroy)(void *);
sparse_status RENAME(sparse_set_matrix_property)(void *, sparse_matrix_property);

// ---------------------------------------------------------------- the report

static int failures;
static int checks;
static char detail[512];

static void report(int passed, const char *name, const char *why)
{
    checks++;
    detail[0] = 0;
    if (passed) {
        printf("ok %s\n", name);
    } else {
        failures++;
        printf("FAIL %s: %s\n", name, detail[0] ? detail : why);
    }
}

static int same_real(double mine, double theirs, double tolerance)
{
    if (isnan(mine) && isnan(theirs)) return 1;
    if (isinf(mine) || isinf(theirs)) return mine == theirs;
    double difference = fabs(mine - theirs);
    double scale = fabs(theirs) > 1.0 ? fabs(theirs) : 1.0;
    return difference <= tolerance * scale;
}

static void complex_text(const char *label, double re, double im, char *into, size_t room)
{
    snprintf(into, room, "%s %g%+gi", label, re, im);
}

static int same_complex(double mre, double mim, double tre, double tim, double tolerance, const char *what)
{
    if (same_real(mre, tre, tolerance) && same_real(mim, tim, tolerance)) return 1;
    char mine[128], theirs[128];
    complex_text("mine", mre, mim, mine, sizeof(mine));
    complex_text("theirs", tre, tim, theirs, sizeof(theirs));
    snprintf(detail, sizeof(detail), "%s %s against %s", what, mine, theirs);
    return 0;
}

#define REAL_OF(x) ((double)__real__(x))
#define IMAG_OF(x) ((double)__imag__(x))

// ---------------------------------------------------------------- one description, both sides

// Every case builds a matrix on each side from one list of entries, so the two sides are always given
// the same values in the same places.
typedef struct CharonEntry {
    sparse_index row;
    sparse_index column;
    double re;
    double im;
} CharonEntry;

// ---------------------------------------------------------------- the cases

static void shape_cases(void)
{
    struct {
        sparse_dimension rows, columns;
        const char *name;
    } shapes[] = {{0, 5}, {5, 0}, {0, 0}, {3, 4}};
    for (unsigned s = 0; s < sizeof(shapes) / sizeof(shapes[0]); s++) {
        sparse_matrix_float_complex host = sparse_matrix_create_float_complex(shapes[s].rows, shapes[s].columns);
        sparse_matrix_float_complex port = RENAME(sparse_matrix_create_float_complex)(shapes[s].rows, shapes[s].columns);
        char name[128];
        snprintf(name, sizeof(name), "a point-wise %llux%llu matrix, the host and the port",
                 (unsigned long long)shapes[s].rows, (unsigned long long)shapes[s].columns);
        report(host != NULL && port != NULL &&
                   (unsigned long long)sparse_get_matrix_number_of_rows(host) ==
                       (unsigned long long)RENAME(sparse_get_matrix_number_of_rows)(port) &&
                   (unsigned long long)sparse_get_matrix_number_of_columns(host) ==
                       (unsigned long long)RENAME(sparse_get_matrix_number_of_columns)(port),
               name, "the shape one of the two did not answer");
        sparse_matrix_destroy(host);
        RENAME(sparse_matrix_destroy)(port);
    }

    // A block matrix: the block sizes and the element counts both.
    sparse_matrix_float_complex hostB = sparse_matrix_block_create_float_complex(2, 2, 2, 3);
    sparse_matrix_float_complex portB = RENAME(sparse_matrix_block_create_float_complex)(2, 2, 2, 3);
    report(sparse_get_matrix_number_of_rows(hostB) == RENAME(sparse_get_matrix_number_of_rows)(portB) &&
               sparse_get_matrix_number_of_columns(hostB) == RENAME(sparse_get_matrix_number_of_columns)(portB) &&
               sparse_get_block_dimension_for_row(hostB, 0) == RENAME(sparse_get_block_dimension_for_row)(portB, 0) &&
               sparse_get_block_dimension_for_col(hostB, 0) == RENAME(sparse_get_block_dimension_for_col)(portB, 0) &&
               sparse_get_block_dimension_for_row(hostB, 4) == RENAME(sparse_get_block_dimension_for_row)(portB, 4),
           "a block matrix 2x2 of 2x3 blocks", "the shape one of the two did not answer");
    sparse_matrix_destroy(hostB);
    RENAME(sparse_matrix_destroy)(portB);

    const sparse_dimension k[2] = {2, 3};
    const sparse_dimension l[2] = {1, 2};
    sparse_matrix_double_complex hostV = sparse_matrix_variable_block_create_double_complex(2, 2, k, l);
    sparse_matrix_double_complex portV = RENAME(sparse_matrix_variable_block_create_double_complex)(2, 2, k, l);
    report(sparse_get_matrix_number_of_rows(hostV) == RENAME(sparse_get_matrix_number_of_rows)(portV) &&
               sparse_get_matrix_number_of_columns(hostV) == RENAME(sparse_get_matrix_number_of_columns)(portV) &&
               sparse_get_block_dimension_for_row(hostV, 1) == RENAME(sparse_get_block_dimension_for_row)(portV, 1) &&
               sparse_get_block_dimension_for_row(hostV, 2) == RENAME(sparse_get_block_dimension_for_row)(portV, 2) &&
               sparse_get_block_dimension_for_row(hostV, 5) == RENAME(sparse_get_block_dimension_for_row)(portV, 5),
           "a variable-block matrix with row heights {2,3} and column widths {1,2}",
           "the block dimensions one of the two did not answer");
    sparse_matrix_destroy(hostV);
    RENAME(sparse_matrix_destroy)(portV);

    // A commit answers SPARSE_SUCCESS and changes nothing.
    sparse_matrix_float_complex hostC = sparse_matrix_create_float_complex(2, 2);
    sparse_matrix_float_complex portC = RENAME(sparse_matrix_create_float_complex)(2, 2);
    sparse_insert_entry_float_complex(hostC, 3.0f + 4.0fi, 0, 0);
    RENAME(sparse_insert_entry_float_complex)(portC, 3.0f + 4.0fi, 0, 0);
    sparse_status hc = sparse_commit(hostC), pc = RENAME(sparse_commit)(portC);
    report(hc == pc && sparse_get_matrix_nonzero_count(hostC) == RENAME(sparse_get_matrix_nonzero_count)(portC),
           "a commit", "the statuses differ");
    sparse_matrix_destroy(hostC);
    RENAME(sparse_matrix_destroy)(portC);
}

static void insert_cases(void)
{
    // One entry at a time, with the refusals around it.
    const CharonEntry three[3] = {{0, 0, 3.0, 4.0}, {1, 0, 1.0, 0.0}, {1, 2, -2.0, 1.0}};
    sparse_matrix_float_complex host = sparse_matrix_create_float_complex(3, 3);
    sparse_matrix_float_complex port = RENAME(sparse_matrix_create_float_complex)(3, 3);
    int same = 1;
    for (int k = 0; k < 3; k++) {
        sparse_status a = sparse_insert_entry_float_complex(host, (float)three[k].re + (float)three[k].im * 1.0fi,
                                                             three[k].row, three[k].column);
        sparse_status b = RENAME(sparse_insert_entry_float_complex)(port, (float)three[k].re + (float)three[k].im * 1.0fi,
                                                                    three[k].row, three[k].column);
        same = same && a == b;
    }
    report(same, "an entry at a time", "a status differs");
    report(sparse_get_matrix_nonzero_count(host) == RENAME(sparse_get_matrix_nonzero_count)(port) &&
               sparse_get_matrix_nonzero_count_for_row(host, 1) == RENAME(sparse_get_matrix_nonzero_count_for_row)(port, 1) &&
               sparse_get_matrix_nonzero_count_for_column(host, 0) == RENAME(sparse_get_matrix_nonzero_count_for_column)(port, 0),
           "the nonzero counts after three entries", "a count differs");

    // A value of exactly zero is stored and counted, and writing it over an entry does not count again.
    sparse_matrix_float_complex hostZ = sparse_matrix_create_float_complex(2, 2);
    sparse_matrix_float_complex portZ = RENAME(sparse_matrix_create_float_complex)(2, 2);
    sparse_insert_entry_float_complex(hostZ, 0.0f + 0.0fi, 0, 1);
    RENAME(sparse_insert_entry_float_complex)(portZ, 0.0f + 0.0fi, 0, 1);
    sparse_insert_entry_float_complex(hostZ, 2.0f + 0.0fi, 1, 0);
    RENAME(sparse_insert_entry_float_complex)(portZ, 2.0f + 0.0fi, 1, 0);
    sparse_insert_entry_float_complex(hostZ, 0.0f + 0.0fi, 1, 0);
    RENAME(sparse_insert_entry_float_complex)(portZ, 0.0f + 0.0fi, 1, 0);
    // The host's answer for a stored zero is not one answer on this machine: measured with sequenced
    // statements in a fresh process it stores the zero and counts it (2 here, and the row holds it), and
    // measured inside this run it answers as if the zero were dropped (1, and row 0 is empty). The real
    // family answers the dropped one. facts/Accelerate/SparseComplex.md carries all three numbers, and
    // the port follows the real family's own rule - the entry is stored and counted - which is what the
    // header says sparse_insert_entry_float_complex does.
    report(RENAME(sparse_get_matrix_nonzero_count)(portZ) == 2 &&
               RENAME(sparse_get_matrix_nonzero_count_for_row)(portZ, 0) == 1 &&
               RENAME(sparse_get_matrix_nonzero_count_for_row)(portZ, 1) == 1,
           "a stored zero, then an entry written over (header)", "the port did not store and count both entries");

    // Every refusal, and the matrix is untouched in each.
    const sparse_index outside[2][2] = {{3, 0}, {0, 3}};
    for (int k = 0; k < 2; k++) {
        sparse_status a = sparse_insert_entry_float_complex(host, 1.0f, outside[k][0], outside[k][1]);
        sparse_status b = RENAME(sparse_insert_entry_float_complex)(port, 1.0f, outside[k][0], outside[k][1]);
        char name[96];
        snprintf(name, sizeof(name), "an entry outside the matrix at (%lld,%lld)", (long long)outside[k][0],
                 (long long)outside[k][1]);
        report(a == b && a == SPARSE_ILLEGAL_PARAMETER, name, "the statuses differ or are not a refusal");
    }
    sparse_status negativeA = sparse_insert_entry_float_complex(host, 1.0f, -1, 0);
    sparse_status negativeB = RENAME(sparse_insert_entry_float_complex)(port, 1.0f, -1, 0);
    report(negativeA == negativeB && negativeA == SPARSE_ILLEGAL_PARAMETER,
           "an entry at a negative row", "the statuses differ or are not a refusal");
    negativeA = sparse_insert_entry_float_complex(host, 1.0f, 0, -1);
    negativeB = RENAME(sparse_insert_entry_float_complex)(port, 1.0f, 0, -1);
    report(negativeA == negativeB && negativeA == SPARSE_ILLEGAL_PARAMETER,
           "an entry at a negative column", "the statuses differ or are not a refusal");

    // A scalar entry into a block matrix is refused by both.
    sparse_matrix_float_complex hostB = sparse_matrix_block_create_float_complex(2, 2, 2, 2);
    sparse_matrix_float_complex portB = RENAME(sparse_matrix_block_create_float_complex)(2, 2, 2, 2);
    sparse_status hostS = sparse_insert_entry_float_complex(hostB, 1.0f, 0, 0);
    sparse_status portS = RENAME(sparse_insert_entry_float_complex)(portB, 1.0f, 0, 0);
    report(hostS == portS && hostS == SPARSE_ILLEGAL_PARAMETER, "a scalar entry into a block matrix",
           "the statuses differ or are not a refusal");
    sparse_matrix_destroy(hostB);
    RENAME(sparse_matrix_destroy)(portB);

    // The double twins of the same entry, so a width read wrong is caught.
    sparse_matrix_double_complex hostD = sparse_matrix_create_double_complex(3, 3);
    sparse_matrix_double_complex portD = RENAME(sparse_matrix_create_double_complex)(3, 3);
    for (int k = 0; k < 3; k++) {
        sparse_status a = sparse_insert_entry_double_complex(hostD, three[k].re + three[k].im * 1.0i, three[k].row,
                                                             three[k].column);
        sparse_status b = RENAME(sparse_insert_entry_double_complex)(portD, three[k].re + three[k].im * 1.0i,
                                                                     three[k].row, three[k].column);
        same = same && a == b;
    }
    report(same && sparse_get_matrix_nonzero_count(hostD) == RENAME(sparse_get_matrix_nonzero_count)(portD),
           "an entry at a time, in the double complex", "a status or a count differs");

    // A row, a column and a list of entries.
    float _Complex rowValues[2] = {1.0f + 1.0fi, 2.0f - 2.0fi};
    const sparse_index rowColumns[2] = {0, 2};
    sparse_status hostRow = sparse_insert_row_float_complex(host, 2, 2, rowValues, rowColumns);
    sparse_status portRow = RENAME(sparse_insert_row_float_complex)(port, 2, 2, rowValues, rowColumns);
    report(hostRow == portRow && sparse_get_matrix_nonzero_count(host) == RENAME(sparse_get_matrix_nonzero_count)(port),
           "a whole row", "the statuses or the counts differ");

    float _Complex colValues[2] = {5.0f + 5.0fi, 6.0f - 6.0fi};
    const sparse_index colRows[2] = {0, 1};
    hostRow = sparse_insert_col_float_complex(host, 1, 2, colValues, colRows);
    portRow = RENAME(sparse_insert_col_float_complex)(port, 1, 2, colValues, colRows);
    report(hostRow == portRow && sparse_get_matrix_nonzero_count(host) == RENAME(sparse_get_matrix_nonzero_count)(port),
           "a whole column", "the statuses or the counts differ");

    float _Complex listValues[2] = {7.0f + 1.0fi, 8.0f - 3.0fi};
    const sparse_index listRows[2] = {2, 2};
    const sparse_index listColumns[2] = {0, 1};
    hostRow = sparse_insert_entries_float_complex(host, 2, listValues, listRows, listColumns);
    portRow = RENAME(sparse_insert_entries_float_complex)(port, 2, listValues, listRows, listColumns);
    report(hostRow == portRow && sparse_get_matrix_nonzero_count(host) == RENAME(sparse_get_matrix_nonzero_count)(port),
           "a list of entries", "the statuses or the counts differ");

    double _Complex doubleList[2] = {1.25 + 2.5i, -3.75 + 0.5i};
    hostRow = sparse_insert_entries_double_complex(hostD, 2, doubleList, listRows, listColumns);
    portRow = RENAME(sparse_insert_entries_double_complex)(portD, 2, doubleList, listRows, listColumns);
    report(hostRow == portRow && sparse_get_matrix_nonzero_count(hostD) == RENAME(sparse_get_matrix_nonzero_count)(portD),
           "a list of entries, in the double complex", "the statuses or the counts differ");

    // A block, inserted and read back at a stride that is neither 1 nor the width.
    sparse_matrix_float_complex hostBlock = sparse_matrix_block_create_float_complex(2, 2, 2, 2);
    sparse_matrix_float_complex portBlock = RENAME(sparse_matrix_block_create_float_complex)(2, 2, 2, 2);
    float _Complex block[4] = {1.0f + 1.0fi, 2.0f + 2.0fi, 3.0f + 3.0fi, 4.0f + 4.0fi};
    hostRow = sparse_insert_block_float_complex(hostBlock, block, 2, 1, 0, 0);
    portRow = RENAME(sparse_insert_block_float_complex)(portBlock, block, 2, 1, 0, 0);
    float _Complex gotHost[4] = {{0, 0}, {0, 0}, {0, 0}, {0, 0}};
    float _Complex gotPort[4] = {{0, 0}, {0, 0}, {0, 0}, {0, 0}};
    sparse_status hostE = sparse_extract_block_float_complex(hostBlock, 0, 0, 2, 1, gotHost);
    sparse_status portE = RENAME(sparse_extract_block_float_complex)(portBlock, 0, 0, 2, 1, gotPort);
    int blockSame = hostRow == portRow && hostE == portE;
    for (int k = 0; k < 4 && blockSame; k++) {
        blockSame = same_complex(REAL_OF(gotPort[k]), IMAG_OF(gotPort[k]), REAL_OF(gotHost[k]), IMAG_OF(gotHost[k]), 1e-6,
                                 "a value of the block");
    }
    report(blockSame, "a block inserted at a stride and read back", "the statuses or a value differs");
    // The block that was never inserted reads as zeros on both sides.
    float _Complex emptyHost[4] = {{9, 9}, {9, 9}, {9, 9}, {9, 9}};
    float _Complex emptyPort[4] = {{9, 9}, {9, 9}, {9, 9}, {9, 9}};
    hostE = sparse_extract_block_float_complex(hostBlock, 1, 1, 2, 1, emptyHost);
    portE = RENAME(sparse_extract_block_float_complex)(portBlock, 1, 1, 2, 1, emptyPort);
    int emptySame = hostE == portE;
    for (int k = 0; k < 4 && emptySame; k++) {
        emptySame = REAL_OF(emptyPort[k]) == 0.0 && IMAG_OF(emptyPort[k]) == 0.0;
    }
    report(emptySame, "a block that was never inserted", "the statuses or a value differ");
    // A block index outside the matrix, and a block out of a point-wise one.
    hostE = sparse_extract_block_float_complex(hostBlock, 2, 0, 2, 1, emptyHost);
    portE = RENAME(sparse_extract_block_float_complex)(portBlock, 2, 0, 2, 1, emptyPort);
    report(hostE == portE && hostE == SPARSE_ILLEGAL_PARAMETER, "a block index outside the matrix",
           "the statuses differ or are not a refusal");
    hostE = sparse_extract_block_float_complex(host, 0, 0, 2, 1, emptyHost);
    portE = RENAME(sparse_extract_block_float_complex)(port, 0, 0, 2, 1, emptyPort);
    report(hostE == portE && hostE == SPARSE_ILLEGAL_PARAMETER, "a block out of a point-wise matrix",
           "the statuses differ or are not a refusal");

    sparse_matrix_destroy(host);
    RENAME(sparse_matrix_destroy)(port);
    sparse_matrix_destroy(hostD);
    RENAME(sparse_matrix_destroy)(portD);
    sparse_matrix_destroy(hostBlock);
    RENAME(sparse_matrix_destroy)(portBlock);
}

// The 4x4 the header comment names: rows holding columns {1,2,3}, {0}, {} and {2}.
static void extract_cases(void)
{
    const CharonEntry pattern[6] = {{0, 1, 1.0, 0.0}, {0, 2, 2.0, 0.0}, {0, 3, 3.0, 1.0},
                                    {1, 0, 4.0, 0.0}, {3, 2, 5.0, -1.0}};
    sparse_matrix_float_complex host = sparse_matrix_create_float_complex(4, 4);
    sparse_matrix_float_complex port = RENAME(sparse_matrix_create_float_complex)(4, 4);
    for (int k = 0; k < 5; k++) {
        sparse_insert_entry_float_complex(host, (float)pattern[k].re + (float)pattern[k].im * 1.0fi, pattern[k].row,
                                           pattern[k].column);
        RENAME(sparse_insert_entry_float_complex)(port, (float)pattern[k].re + (float)pattern[k].im * 1.0fi, pattern[k].row,
                                                  pattern[k].column);
    }
    const struct {
        sparse_index row, columnStart;
        sparse_dimension nz;
        const char *name;
    } reads[] = {{0, 0, 2, "a row from 0, nz of 2"}, {0, 0, 4, "a row from 0, nz of 4"},
                 {0, 0, 0, "a row from 0, nz of 0"}, {0, 2, 2, "a row from 2, nz of 2"},
                 {1, 0, 4, "a row with one entry"}, {2, 0, 4, "an empty row"}, {3, 1, 4, "a row read from 1"}};
    for (unsigned r = 0; r < sizeof(reads) / sizeof(reads[0]); r++) {
        sparse_index hostEnd = -99, portEnd = -99;
        float _Complex hostValues[8], portValues[8];
        sparse_index hostIndices[8], portIndices[8];
        memset(hostValues, 0, sizeof(hostValues));
        memset(portValues, 0, sizeof(portValues));
        memset(hostIndices, 0, sizeof(hostIndices));
        memset(portIndices, 0, sizeof(portIndices));
        sparse_status hostS = sparse_extract_sparse_row_float_complex(host, reads[r].row, reads[r].columnStart,
                                                                       &hostEnd, reads[r].nz, hostValues, hostIndices);
        sparse_status portS = RENAME(sparse_extract_sparse_row_float_complex)(port, reads[r].row, reads[r].columnStart,
                                                                             &portEnd, reads[r].nz, portValues,
                                                                             portIndices);
        int ok = hostS == portS && hostEnd == portEnd;
        for (int k = 0; k < (int)reads[r].nz && ok; k++) {
            ok = hostIndices[k] == portIndices[k] &&
                 same_complex(REAL_OF(portValues[k]), IMAG_OF(portValues[k]), REAL_OF(hostValues[k]),
                              IMAG_OF(hostValues[k]), 1e-6, "a value of the row");
        }
        if (!ok) {
            snprintf(detail, sizeof(detail), "status %d against %d, end %lld against %lld", (int)hostS, (int)portS,
                     (long long)hostEnd, (long long)portEnd);
        }
        report(ok, reads[r].name, detail);
    }
    // The refusals.
    sparse_index hostEnd = 0, portEnd = 0;
    float _Complex values[8];
    float _Complex hostValues[8], portValues[8];
    sparse_index hostIndices[8], portIndices[8];
    sparse_status hostS = sparse_extract_sparse_row_float_complex(host, 4, 0, &hostEnd, 4, values, NULL);
    sparse_status portS = RENAME(sparse_extract_sparse_row_float_complex)(port, 4, 0, &portEnd, 4, values, NULL);
    report(hostS == portS && hostS == SPARSE_ILLEGAL_PARAMETER, "a row past the last", "the statuses differ");
    hostS = sparse_extract_sparse_row_float_complex(host, 0, -1, &hostEnd, 4, values, NULL);
    portS = RENAME(sparse_extract_sparse_row_float_complex)(port, 0, -1, &portEnd, 4, values, NULL);
    report(hostS == portS && hostS == SPARSE_ILLEGAL_PARAMETER, "a row from a negative column", "the statuses differ");
    hostS = sparse_extract_sparse_row_float_complex(host, 0, 4, &hostEnd, 4, values, NULL);
    portS = RENAME(sparse_extract_sparse_row_float_complex)(port, 0, 4, &portEnd, 4, values, NULL);
    report(hostS == portS && hostS == SPARSE_ILLEGAL_PARAMETER, "a row from a column past the last",
           "the statuses differ");

    // The double twin, so a width read wrong is caught.
    sparse_matrix_double_complex hostD = sparse_matrix_create_double_complex(4, 4);
    sparse_matrix_double_complex portD = RENAME(sparse_matrix_create_double_complex)(4, 4);
    for (int k = 0; k < 5; k++) {
        sparse_insert_entry_double_complex(hostD, pattern[k].re + pattern[k].im * 1.0i, pattern[k].row, pattern[k].column);
        RENAME(sparse_insert_entry_double_complex)(portD, pattern[k].re + pattern[k].im * 1.0i, pattern[k].row,
                                                   pattern[k].column);
    }
    hostEnd = -99;
    portEnd = -99;
    double _Complex hostDValues[8], portDValues[8];
    sparse_index hostDIndices[8], portDIndices[8];
    hostS = sparse_extract_sparse_row_double_complex(hostD, 0, 0, &hostEnd, 3, hostDValues, hostDIndices);
    portS = RENAME(sparse_extract_sparse_row_double_complex)(portD, 0, 0, &portEnd, 3, portDValues, portDIndices);
    int ok = hostS == portS && hostEnd == portEnd;
    for (int k = 0; k < 3 && ok; k++) {
        ok = hostDIndices[k] == portDIndices[k] &&
             same_complex(REAL_OF(portDValues[k]), IMAG_OF(portDValues[k]), REAL_OF(hostDValues[k]),
                          IMAG_OF(hostDValues[k]), 1e-12, "a value of the row");
    }
    report(ok, "a row from 0, nz of 3, in the double complex", detail);

    // A column is the transpose of the row, with the same refusals.
    hostS = sparse_extract_sparse_column_float_complex(host, 0, 0, &hostEnd, 4, hostValues, hostIndices);
    portS = RENAME(sparse_extract_sparse_column_float_complex)(port, 0, 0, &portEnd, 4, portValues, portIndices);
    // Only the slots the return value says were written are compared: both sides leave the rest alone,
    // and what is in them is whatever the buffer held.
    long written = (long)hostS;
    ok = hostS == portS && hostEnd == portEnd;
    for (long k = 0; k < written && ok; k++) {
        ok = hostIndices[k] == portIndices[k] &&
             same_complex(REAL_OF(portValues[k]), IMAG_OF(portValues[k]), REAL_OF(hostValues[k]), IMAG_OF(hostValues[k]),
                          1e-6, "a value of the column");
    }
    snprintf(detail, sizeof(detail), "status %d against %d, end %lld against %lld, first row %lld against %lld",
             (int)hostS, (int)portS, (long long)hostEnd, (long long)portEnd, (long long)hostIndices[0],
             (long long)portIndices[0]);
    report(ok, "a column from row 0", detail);
    hostS = sparse_extract_sparse_column_float_complex(host, 2, 0, &hostEnd, 4, hostValues, hostIndices);
    portS = RENAME(sparse_extract_sparse_column_float_complex)(port, 2, 0, &portEnd, 4, portValues, portIndices);
    written = (long)hostS;
    ok = hostS == portS && hostEnd == portEnd;
    for (long k = 0; k < written && ok; k++) {
        ok = hostIndices[k] == portIndices[k] &&
             same_complex(REAL_OF(portValues[k]), IMAG_OF(portValues[k]), REAL_OF(hostValues[k]), IMAG_OF(hostValues[k]),
                          1e-6, "a value of the column");
    }
    report(ok, "a column with three entries", detail);
    hostS = sparse_extract_sparse_column_float_complex(host, 0, 0, &hostEnd, 0, hostValues, hostIndices);
    portS = RENAME(sparse_extract_sparse_column_float_complex)(port, 0, 0, &portEnd, 0, hostValues, hostIndices);
    report(hostS == portS && hostEnd == portEnd && hostEnd == 0, "a column with nz of 0", "the ends differ");
    hostS = sparse_extract_sparse_column_float_complex(host, 4, 0, &hostEnd, 4, hostValues, hostIndices);
    portS = RENAME(sparse_extract_sparse_column_float_complex)(port, 4, 0, &portEnd, 4, hostValues, hostIndices);
    report(hostS == portS && hostS == SPARSE_ILLEGAL_PARAMETER, "a column past the last", "the statuses differ");
    hostS = sparse_extract_sparse_column_float_complex(host, 0, -1, &hostEnd, 4, hostValues, hostIndices);
    portS = RENAME(sparse_extract_sparse_column_float_complex)(port, 0, -1, &portEnd, 4, hostValues, hostIndices);
    report(hostS == portS && hostS == SPARSE_ILLEGAL_PARAMETER, "a column from a negative row", "the statuses differ");

    sparse_matrix_destroy(host);
    RENAME(sparse_matrix_destroy)(port);
    sparse_matrix_destroy(hostD);
    RENAME(sparse_matrix_destroy)(portD);
}

static void level_one_cases(void)
{
    float _Complex x[2] = {3.0f + 4.0fi, 1.0f + 0.0fi};
    float _Complex y[2] = {1.0f + 1.0fi, 2.0f + 0.0fi};
    const sparse_index indx[2] = {0, 1};
    float _Complex theirs = sparse_inner_product_dense_float_complex(2, x, indx, y, 1);
    float _Complex mine = RENAME(sparse_inner_product_dense_float_complex)(2, x, indx, y, 1);
    report(same_complex(REAL_OF(mine), IMAG_OF(mine), REAL_OF(theirs), IMAG_OF(theirs), 1e-6,
                        "the inner product of a sparse and a dense vector"),
           "an inner product of a sparse and a dense vector", detail);
// A negative stride, asked the way the header says to ask it: the pointer is the last element. The
    // buffers hold every element the two sides read, which the pair above did not: the sparse vector
    // has no increment of its own, so the pointer is its first element and nz elements follow it, and a
    // negative increment on the dense side reaches one element below the pointer. Passing x + 1 and
    // y + 1 into two-element arrays read x[2] and y[-1] - AddressSanitizer's stack-buffer-overflow at
    // CharonSparseBLAS.h:328 through this very call - and both sides then answered the bytes that
    // happened to be there.
    {
        float _Complex xStore[4] = {-100.0f + 0.0fi, 3.0f + 4.0fi, 1.0f + 0.0fi, -200.0f + 0.0fi};
        float _Complex yStore[4] = {-300.0f + 0.0fi, 1.0f + 1.0fi, 2.0f + 0.0fi, -400.0f + 0.0fi};
        const float _Complex *xs = xStore + 1, *ys = yStore + 1;
        for (int stride = -1; stride <= 1; stride += 2) {
            // The header's rule, computed here from the same buffers: sum over k of X[k] * Y[indx[k] *
            // incy], with the element at dense index i at (y + i * incy).
            float _Complex want = 0.0f + 0.0fi;
            for (int k = 0; k < 2; k++) {
                want += xs[k] * ys[indx[k] * stride];
            }
            float _Complex theirsBack = sparse_inner_product_dense_float_complex(2, xs, indx, ys, stride);
            float _Complex mineBack = RENAME(sparse_inner_product_dense_float_complex)(2, xs, indx, ys, stride);
            char nameBack[128];
            snprintf(nameBack, sizeof(nameBack), "an inner product with an increment of %d", stride);
            report(same_complex(REAL_OF(mineBack), IMAG_OF(mineBack), REAL_OF(theirsBack), IMAG_OF(theirsBack), 1e-6,
                                "the port against the host") &&
                       same_complex(REAL_OF(mineBack), IMAG_OF(mineBack), REAL_OF(want), IMAG_OF(want), 1e-6,
                                    "the port against the header's rule") &&
                       same_complex(REAL_OF(theirsBack), IMAG_OF(theirsBack), REAL_OF(want), IMAG_OF(want), 1e-6,
                                    "the host against the header's rule"),
                   nameBack, detail);
        }
    }
    // The count of zero.
    theirs = sparse_inner_product_dense_float_complex(0, x, indx, y, 1);
    mine = RENAME(sparse_inner_product_dense_float_complex)(0, x, indx, y, 1);
    report(REAL_OF(mine) == 0.0 && IMAG_OF(mine) == 0.0, "an inner product of a count of zero",
           "the port did not answer zero");

    float _Complex sx[1] = {3.0f + 4.0fi}, sy[1] = {1.0f + 1.0fi};
    const sparse_index six[1] = {0}, siy[1] = {0};
    theirs = sparse_inner_product_sparse_float_complex(1, 1, sx, six, sy, siy);
    mine = RENAME(sparse_inner_product_sparse_float_complex)(1, 1, sx, six, sy, siy);
    report(same_complex(REAL_OF(mine), IMAG_OF(mine), REAL_OF(theirs), IMAG_OF(theirs), 1e-6,
                        "the inner product of two sparse vectors"),
           "an inner product of two sparse vectors", detail);
    // Index runs that share nothing answer zero, and one of them empty answers zero.
    const sparse_index other[1] = {5};
    theirs = sparse_inner_product_sparse_float_complex(1, 1, sx, six, sy, other);
    mine = RENAME(sparse_inner_product_sparse_float_complex)(1, 1, sx, six, sy, other);
    report(same_complex(REAL_OF(mine), IMAG_OF(mine), REAL_OF(theirs), IMAG_OF(theirs), 1e-6,
                        "two sparse vectors with nothing in common"),
           "two sparse vectors with nothing in common", detail);
    theirs = sparse_inner_product_sparse_float_complex(0, 1, sx, six, sy, siy);
    mine = RENAME(sparse_inner_product_sparse_float_complex)(0, 1, sx, six, sy, siy);
    report(REAL_OF(mine) == 0.0 && IMAG_OF(mine) == 0.0, "an inner product of two sparse vectors, one empty",
           "the port did not answer zero");

    double _Complex dx[2] = {3.0 + 4.0i, 1.0 + 0.0i}, dy[2] = {1.0 + 1.0i, 2.0 + 0.0i};
    double _Complex dTheirs = sparse_inner_product_dense_double_complex(2, dx, indx, dy, 1);
    double _Complex dMine = RENAME(sparse_inner_product_dense_double_complex)(2, dx, indx, dy, 1);
    report(same_complex(REAL_OF(dMine), IMAG_OF(dMine), REAL_OF(dTheirs), IMAG_OF(dTheirs), 1e-12,
                        "the inner product in the double complex"),
           "an inner product in the double complex", detail);

    // y += alpha * x, over the strided dense vector.
    float _Complex hostY[4] = {10.0f + 0.0fi, 20.0f + 0.0fi, 30.0f + 0.0fi, 40.0f + 0.0fi};
    float _Complex portY[4];
    memcpy(portY, hostY, sizeof(hostY));
    const sparse_index which[2] = {0, 2};
    sparse_vector_add_with_scale_dense_float_complex(2, 2.0f + 0.0fi, x, which, hostY, 1);
    RENAME(sparse_vector_add_with_scale_dense_float_complex)(2, 2.0f + 0.0fi, x, which, portY, 1);
    int ok = 1;
    for (int k = 0; k < 4 && ok; k++) {
        ok = same_complex(REAL_OF(portY[k]), IMAG_OF(portY[k]), REAL_OF(hostY[k]), IMAG_OF(hostY[k]), 1e-6,
                         "an element of y");
    }
    report(ok, "a scaled addition into a dense vector", detail);
    // An alpha of exactly zero, and a count of zero, leave y alone.
    memcpy(portY, hostY, sizeof(hostY));
    RENAME(sparse_vector_add_with_scale_dense_float_complex)(2, 0.0f + 0.0fi, x, which, portY, 1);
    RENAME(sparse_vector_add_with_scale_dense_float_complex)(0, 2.0f + 0.0fi, x, which, portY, 1);
    ok = 1;
    for (int k = 0; k < 4 && ok; k++) {
        ok = same_complex(REAL_OF(portY[k]), IMAG_OF(portY[k]), REAL_OF(hostY[k]), IMAG_OF(hostY[k]), 1e-6,
                         "an element of y");
    }
    report(ok, "a scaled addition by zero and of a count of zero", detail);
    // A negative stride, the pointer at the last element.
    float _Complex hostBack[4] = {1.0f + 1.0fi, 2.0f + 2.0fi, 3.0f + 3.0fi, 4.0f + 4.0fi};
    float _Complex portBack[4];
    memcpy(portBack, hostBack, sizeof(hostBack));
    const sparse_index backWhich[2] = {3, 1};
    sparse_vector_add_with_scale_dense_float_complex(2, 1.0f + 1.0fi, x, backWhich, hostBack + 3, -1);
    RENAME(sparse_vector_add_with_scale_dense_float_complex)(2, 1.0f + 1.0fi, x, backWhich, portBack + 3, -1);
    ok = 1;
    for (int k = 0; k < 4 && ok; k++) {
        ok = same_complex(REAL_OF(portBack[k]), IMAG_OF(portBack[k]), REAL_OF(hostBack[k]), IMAG_OF(hostBack[k]),
                         1e-6, "an element of y");
    }
    report(ok, "a scaled addition with a negative stride", detail);

    // The three norms and the two fallbacks.
    const sparse_norm norms[5] = {SPARSE_NORM_ONE, SPARSE_NORM_TWO, SPARSE_NORM_INF, SPARSE_NORM_R1,
                                  (sparse_norm)99};
    const char *normNames[5] = {"one", "two", "infinity", "R1", "an unlisted name"};
    for (int n = 0; n < 5; n++) {
        float theirs2 = sparse_vector_norm_float_complex(2, x, indx, norms[n]);
        float mine2 = RENAME(sparse_vector_norm_float_complex)(2, x, indx, norms[n]);
        char name[96];
        snprintf(name, sizeof(name), "the %s norm of a vector of complex values", normNames[n]);
        report(same_real(mine2, theirs2, 1e-6), name, "the values differ");
    }
    // A count of zero answers 0 for every norm.
    float mine2 = RENAME(sparse_vector_norm_float_complex)(0, x, indx, SPARSE_NORM_TWO);
    report(mine2 == 0.0f, "a norm of a count of zero", "the port did not answer zero");

    // The count of the nonzero elements, where one part being zero is not enough.
    float _Complex mixed[3] = {0.0f + 0.0fi, 0.0f + 1.0fi, 2.0f + 0.0fi};
    long theirsLong = sparse_get_vector_nonzero_count_float_complex(3, mixed, 1);
    long mineLong = RENAME(sparse_get_vector_nonzero_count_float_complex)(3, mixed, 1);
    report(mineLong == theirsLong, "the count of nonzero elements, one of them with only an imaginary part",
           "the counts differ");
    theirsLong = sparse_get_vector_nonzero_count_float_complex(0, mixed, 1);
    mineLong = RENAME(sparse_get_vector_nonzero_count_float_complex)(0, mixed, 1);
    report(mineLong == theirsLong && mineLong == 0, "the count of nonzero elements of a count of zero",
           "the counts differ");

    // Packing, with fewer nonzeros than the count asked for.
    float _Complex packHost[4], packPort[4];
    sparse_index hostIndy[4], portIndy[4];
    memset(packHost, 0x5a, sizeof(packHost));
    memset(packPort, 0x5a, sizeof(packPort));
    memset(hostIndy, 0x5a, sizeof(hostIndy));
    memset(portIndy, 0x5a, sizeof(portIndy));
    const float _Complex toPack[4] = {0.0f + 1.0fi, 3.0f + 0.0fi, 0.0f + 0.0fi, -1.0f - 1.0fi};
    long hostWritten = sparse_pack_vector_float_complex(4, 4, toPack, 1, packHost, hostIndy);
    long portWritten = RENAME(sparse_pack_vector_float_complex)(4, 4, toPack, 1, packPort, portIndy);
    ok = hostWritten == portWritten;
    for (int k = 0; k < 4 && ok; k++) {
        ok = hostIndy[k] == portIndy[k] &&
             same_complex(REAL_OF(packPort[k]), IMAG_OF(packPort[k]), REAL_OF(packHost[k]), IMAG_OF(packHost[k]), 1e-6,
                          "a packed element");
    }
    report(ok, "packing a vector of complex values", detail);
    // Fewer nonzeros than the count asked for leaves the tail untouched.
    memset(packHost, 0x5a, sizeof(packHost));
    memset(packPort, 0x5a, sizeof(packPort));
    memset(hostIndy, 0x5a, sizeof(hostIndy));
    memset(portIndy, 0x5a, sizeof(portIndy));
    hostWritten = sparse_pack_vector_float_complex(4, 1, toPack, 1, packHost, hostIndy);
    portWritten = RENAME(sparse_pack_vector_float_complex)(4, 1, toPack, 1, packPort, portIndy);
    ok = hostWritten == portWritten;
    for (int k = 0; k < 4 && ok; k++) {
        ok = hostIndy[k] == portIndy[k] &&
             same_complex(REAL_OF(packPort[k]), IMAG_OF(packPort[k]), REAL_OF(packHost[k]), IMAG_OF(packHost[k]),
                          1e-6, "a packed element");
    }
    report(ok, "packing fewer nonzeros than the count asked for", detail);

    // Unpacking, with the zeroing and with an index past N.
    float _Complex hostU[4] = {7.0f + 7.0fi, 8.0f + 8.0fi, 9.0f + 9.0fi, 1.0f + 1.0fi};
    float _Complex portU[4];
    memcpy(portU, hostU, sizeof(hostU));
    const sparse_index entries[2] = {1, 9};
    float _Complex values[2] = {2.0f + 0.0fi, 3.0f + 0.0fi};
    sparse_unpack_vector_float_complex(4, 2, true, values, entries, hostU, 1);
    RENAME(sparse_unpack_vector_float_complex)(4, 2, true, values, entries, portU, 1);
    ok = 1;
    for (int k = 0; k < 4 && ok; k++) {
        ok = same_complex(REAL_OF(portU[k]), IMAG_OF(portU[k]), REAL_OF(hostU[k]), IMAG_OF(hostU[k]), 1e-6,
                         "an element of y");
    }
    report(ok, "unpacking with the zeroing and an index past N", detail);
    memcpy(portU, hostU, sizeof(hostU));
    sparse_unpack_vector_float_complex(4, 0, true, values, entries, hostU, 1);
    RENAME(sparse_unpack_vector_float_complex)(4, 0, true, values, entries, portU, 1);
    ok = 1;
    for (int k = 0; k < 4 && ok; k++) {
        ok = same_complex(REAL_OF(portU[k]), IMAG_OF(portU[k]), REAL_OF(hostU[k]), IMAG_OF(hostU[k]), 1e-6,
                         "an element of y");
    }
    report(ok, "unpacking no entry, with the zeroing", detail);
}

// ---------------------------------------------------------------- level 2 and 3

// A 3x3 matrix with the entries the norms and the trace cases name, and its double twin.
static void build_pair(const CharonEntry *entries, int count, sparse_matrix_float_complex *host,
                       sparse_matrix_float_complex *port, sparse_matrix_double_complex *hostD,
                       sparse_matrix_double_complex *portD)
{
    *host = sparse_matrix_create_float_complex(3, 3);
    *port = RENAME(sparse_matrix_create_float_complex)(3, 3);
    for (int k = 0; k < count; k++) {
        sparse_insert_entry_float_complex(*host, (float)entries[k].re + (float)entries[k].im * 1.0fi, entries[k].row,
                                           entries[k].column);
        RENAME(sparse_insert_entry_float_complex)(*port, (float)entries[k].re + (float)entries[k].im * 1.0fi, entries[k].row,
                                                  entries[k].column);
    }
    *hostD = sparse_matrix_create_double_complex(3, 3);
    *portD = RENAME(sparse_matrix_create_double_complex)(3, 3);
    for (int k = 0; k < count; k++) {
        sparse_insert_entry_double_complex(*hostD, entries[k].re + entries[k].im * 1.0i, entries[k].row,
                                            entries[k].column);
        RENAME(sparse_insert_entry_double_complex)(*portD, entries[k].re + entries[k].im * 1.0i, entries[k].row,
                                                   entries[k].column);
    }
}

static void matrix_vector_cases(void)
{
    const CharonEntry entries[4] = {{0, 0, 3.0, 4.0}, {0, 1, 1.0, 0.0}, {1, 0, 2.0, -1.0}, {2, 2, -1.0, 0.5}};
    sparse_matrix_float_complex host, port;
    sparse_matrix_double_complex hostD, portD;
    build_pair(entries, 4, &host, &port, &hostD, &portD);

    const enum CBLAS_TRANSPOSE transposes[3] = {CblasNoTrans, CblasTrans, (enum CBLAS_TRANSPOSE)77};
    const char *transposeNames[3] = {"without a transpose", "with a transpose", "with a transpose the enumeration does not name"};
    float _Complex x[3] = {1.0f + 0.0fi, 2.0f + 1.0fi, -1.0f + 0.0fi};
    for (int t = 0; t < 3; t++) {
        float _Complex hostY[3] = {0.5f + 0.5fi, -2.0f + 1.0fi, 3.0f + 0.0fi};
        float _Complex portY[3];
        memcpy(portY, hostY, sizeof(hostY));
        sparse_status hostS = SPARSE_SUCCESS, portS = SPARSE_SUCCESS;
        // The host hands a transpose the enumeration does not name to cblas_cgemv, which prints a BLAS
        // error and ends the process, so that one name is asked of the port alone (the facts file).
        if (t != 2) {
            hostS = sparse_matrix_vector_product_dense_float_complex(transposes[t], 2.0f + 1.0fi, host, x, 1, hostY, 1);
        }
        portS = RENAME(sparse_matrix_vector_product_dense_float_complex)(transposes[t], 2.0f + 1.0fi, port, x, 1, portY,
                                                                         1);
        int ok = t == 2 || hostS == portS;
        for (int k = 0; k < 3 && ok; k++) {
            ok = same_complex(REAL_OF(portY[k]), IMAG_OF(portY[k]), REAL_OF(hostY[k]), IMAG_OF(hostY[k]), 1e-5,
                             "an element of y");
        }
        char name[128];
        snprintf(name, sizeof(name), "a matrix-vector product %s", transposeNames[t]);
        char vectors[256];
        snprintf(vectors, sizeof(vectors), "mine %g%+gi %g%+gi %g%+gi against theirs %g%+gi %g%+gi %g%+gi",
                 (double)__real__ portY[0], (double)__imag__ portY[0], (double)__real__ portY[1],
                 (double)__imag__ portY[1], (double)__real__ portY[2], (double)__imag__ portY[2],
                 (double)__real__ hostY[0], (double)__imag__ hostY[0], (double)__real__ hostY[1],
                 (double)__imag__ hostY[1], (double)__real__ hostY[2], (double)__imag__ hostY[2]);
        report(ok, name, vectors);
        if (t == 2) {
            report(portS == SPARSE_ILLEGAL_PARAMETER, "a matrix-vector product with a bad transpose is refused (header)",
                   "the port did not refuse it");
        }
    }
    // A stride of 2, and a stride of zero. The host hands a zero increment to cblas_cgemv, which prints
    // a BLAS error and ends the process, so that one stride is asked of the port alone.
    for (int stride = 2; stride >= 0; stride--) {
        float _Complex hostY[6] = {0.5f + 0.5fi, 9.0f + 9.0fi, -2.0f + 1.0fi, 9.0f + 9.0fi, 3.0f + 0.0fi, 9.0f + 9.0fi};
        float _Complex portY[6];
        memcpy(portY, hostY, sizeof(hostY));
        sparse_status hostS = SPARSE_SUCCESS, portS = SPARSE_SUCCESS;
        if (stride != 0) {
            hostS = sparse_matrix_vector_product_dense_float_complex(CblasNoTrans, 1.0f + 0.0fi, host, x, 1, hostY,
                                                                       stride);
        }
        portS = RENAME(sparse_matrix_vector_product_dense_float_complex)(CblasNoTrans, 1.0f + 0.0fi, port, x, 1, portY,
                                                                         stride);
        int ok = hostS == portS;
        for (int k = 0; k < 3 && ok; k++) {
            ok = same_complex(REAL_OF(portY[k * stride]), IMAG_OF(portY[k * stride]), REAL_OF(hostY[k * stride]),
                             IMAG_OF(hostY[k * stride]), 1e-5, "an element of y");
        }
        char name[96];
        snprintf(name, sizeof(name), "a matrix-vector product with a stride of %d", stride);
        if (stride != 0) {
            report(ok, name, detail);
        }
        if (stride == 0) {
            // The host hands an increment of zero to cblas_cgemv, which prints a BLAS error and ends the
            // process, so there is no host to ask and the oracle is the header's own rule: every row's
            // result lands on the one element the increment names and the elements in between are left
            // alone. The expected value is written out here as a sum of three products over the matrix
            // and the vector this case built, which is a different expression from the loop the port runs.
            const float _Complex start[3] = {0.5f + 0.5fi, 9.0f + 9.0fi, -2.0f + 1.0fi};
            float _Complex want = start[0] + ((3.0f + 4.0fi) * (1.0f + 0.0fi) + (1.0f + 0.0fi) * (2.0f + 1.0fi)) +
                                  ((2.0f - 1.0fi) * (1.0f + 0.0fi)) + ((-1.0f + 0.5fi) * (-1.0f + 0.0fi));
            ok = same_complex(REAL_OF(portY[0]), IMAG_OF(portY[0]), REAL_OF(want), IMAG_OF(want), 1e-5,
                             "the element the increment names");
            for (int k = 1; k < 3 && ok; k++) {
                ok = REAL_OF(portY[k]) == REAL_OF(start[k]) && IMAG_OF(portY[k]) == IMAG_OF(start[k]);
            }
            snprintf(name, sizeof(name), "a matrix-vector product with a stride of zero (header)");
            report(ok, name, detail);
        }
    }
    double _Complex dx[3] = {1.0 + 0.0i, 2.0 + 1.0i, -1.0 + 0.0i};
    double _Complex hostDY[3] = {0.5 + 0.5i, -2.0 + 1.0i, 3.0 + 0.0i}, portDY[3];
    memcpy(portDY, hostDY, sizeof(hostDY));
    sparse_status hostS = sparse_matrix_vector_product_dense_double_complex(CblasTrans, 2.0 + 1.0i, hostD, dx, 1, hostDY, 1);
    sparse_status portS = RENAME(sparse_matrix_vector_product_dense_double_complex)(CblasTrans, 2.0 + 1.0i, portD, dx, 1,
                                                                                   portDY, 1);
    int ok = hostS == portS;
    for (int k = 0; k < 3 && ok; k++) {
        ok = same_complex(REAL_OF(portDY[k]), IMAG_OF(portDY[k]), REAL_OF(hostDY[k]), IMAG_OF(hostDY[k]), 1e-12,
                         "an element of y");
    }
    report(ok, "a matrix-vector product in the double complex", detail);

    sparse_matrix_destroy(host);
    RENAME(sparse_matrix_destroy)(port);
    sparse_matrix_destroy(hostD);
    RENAME(sparse_matrix_destroy)(portD);
}

// The lower triangular [[2,0,0],[1,3,0],[0,0,4]] the facts file names, and its upper twin.
static void build_triangle(sparse_matrix_property property, const CharonEntry *entries, int count,
                           sparse_matrix_float_complex *host, sparse_matrix_float_complex *port)
{
    *host = sparse_matrix_create_float_complex(3, 3);
    *port = RENAME(sparse_matrix_create_float_complex)(3, 3);
    sparse_set_matrix_property(*host, property);
    RENAME(sparse_set_matrix_property)(*port, property);
    for (int k = 0; k < count; k++) {
        sparse_insert_entry_float_complex(*host, (float)entries[k].re + (float)entries[k].im * 1.0fi, entries[k].row,
                                           entries[k].column);
        RENAME(sparse_insert_entry_float_complex)(*port, (float)entries[k].re + (float)entries[k].im * 1.0fi, entries[k].row,
                                                  entries[k].column);
    }
}

static void triangular_cases(void)
{
    const CharonEntry lower[4] = {{0, 0, 2.0, 0.0}, {1, 0, 1.0, 0.0}, {1, 1, 3.0, 0.0}, {2, 2, 4.0, 0.0}};
    const CharonEntry upper[4] = {{0, 0, 2.0, 0.0}, {0, 1, 1.0, 0.0}, {1, 1, 3.0, 0.0}, {2, 2, 4.0, 0.0}};
    const float _Complex rhs[3] = {2.0f + 0.0fi, 5.0f + 0.0fi, 4.0f + 0.0fi};
    const float _Complex alphas[3] = {1.0f + 0.0fi, 2.0f + 0.0fi, 0.5f + 1.0fi};
    const char *alphaNames[3] = {"an alpha of 1", "an alpha of 2", "an alpha of 0.5+1i"};

    for (int side = 0; side < 2; side++) {
        sparse_matrix_float_complex host, port;
        build_triangle(side == 0 ? SPARSE_LOWER_TRIANGULAR : SPARSE_UPPER_TRIANGULAR, side == 0 ? lower : upper, 4,
                       &host, &port);
        for (int a = 0; a < 3; a++) {
            for (int t = 0; t < 2; t++) {
                float _Complex hostX[3], portX[3];
                memcpy(hostX, rhs, sizeof(rhs));
                memcpy(portX, rhs, sizeof(rhs));
                sparse_status hostS = sparse_vector_triangular_solve_dense_float_complex(
                    t == 0 ? CblasNoTrans : CblasTrans, alphas[a], host, hostX, 1);
                sparse_status portS = RENAME(sparse_vector_triangular_solve_dense_float_complex)(
                    t == 0 ? CblasNoTrans : CblasTrans, alphas[a], port, portX, 1);
                // The host's own answer loses the real part of its last element, so only the elements
                // before it are compared here; the last one is checked against the header's rule in the
                // case marked "header" below and facts/Accelerate/SparseComplex.md carries both numbers.
                int ok = hostS == portS;
                for (int k = 0; k < 2 && ok; k++) {
                    ok = same_complex(REAL_OF(portX[k]), IMAG_OF(portX[k]), REAL_OF(hostX[k]), IMAG_OF(hostX[k]),
                                     1e-5, "an element of x");
                }
                char name[160];
                snprintf(name, sizeof(name), "a %s triangular solve, %s, %s", side == 0 ? "lower" : "upper",
                         alphaNames[a], t == 0 ? "without a transpose" : "with a transpose");
                report(ok, name, detail);
                if (side == 0 && a == 1 && t == 0) {
                    // T x = b / alpha with the entries written out: 2/2 = 1, (5 - 1*1)/2/3 = 0.666667 and
                    // 4/2/4 = 0.5. The host answers 0.5 + 0.5i for the last of them.
                    report(same_complex(REAL_OF(portX[2]), IMAG_OF(portX[2]), 0.5, 0.0, 1e-6,
                                        "the last element of a lower triangular solve at an alpha of 2"),
                           "a triangular solve, the element the host's answer loses (header)", detail);
                }
            }
        }
        sparse_matrix_destroy(host);
        RENAME(sparse_matrix_destroy)(port);
    }

    // A matrix with no triangular property is refused, and x is left alone.
    sparse_matrix_float_complex host, port;
    build_triangle(0, lower, 4, &host, &port);
    float _Complex hostX[3], portX[3];
    memcpy(hostX, rhs, sizeof(rhs));
    memcpy(portX, rhs, sizeof(rhs));
    sparse_status hostS = sparse_vector_triangular_solve_dense_float_complex(CblasNoTrans, 1.0f + 0.0fi, host, hostX, 1);
    sparse_status portS = RENAME(sparse_vector_triangular_solve_dense_float_complex)(CblasNoTrans, 1.0f + 0.0fi, port,
                                                                                   portX, 1);
    int ok = hostS == portS && hostS == SPARSE_ILLEGAL_PARAMETER;
    for (int k = 0; k < 3 && ok; k++) {
        ok = REAL_OF(portX[k]) == REAL_OF(rhs[k]) && IMAG_OF(portX[k]) == IMAG_OF(rhs[k]);
    }
    report(ok, "a triangular solve with no triangular property", "the statuses differ or x was written");
    hostS = sparse_vector_triangular_solve_dense_float_complex((enum CBLAS_TRANSPOSE)77, 1.0f + 0.0fi, host, hostX, 1);
    portS = RENAME(sparse_vector_triangular_solve_dense_float_complex)((enum CBLAS_TRANSPOSE)77, 1.0f + 0.0fi, port,
                                                                       portX, 1);
    report(hostS == portS && hostS == SPARSE_ILLEGAL_PARAMETER, "a triangular solve with a bad transpose",
           "the statuses differ or are not a refusal");
    sparse_matrix_destroy(host);
    RENAME(sparse_matrix_destroy)(port);

    // A pivot of exactly zero divides, and both parts become a NaN.
    const CharonEntry zeroPivot[2] = {{0, 0, 0.0, 0.0}, {1, 1, 1.0, 0.0}};
    build_triangle(SPARSE_LOWER_TRIANGULAR, zeroPivot, 2, &host, &port);
    // Three elements: build_triangle always makes a 3x3, so the solve reads three of them whatever the
    // entries are. Two left the port reading one element past the array - AddressSanitizer's
    // stack-buffer-overflow at CharonSparseBLAS.h:328 through this very call.
    const float _Complex ones[3] = {1.0f + 0.0fi, 1.0f + 0.0fi, 1.0f + 0.0fi};
    float _Complex hostZ[3], portZ[3];
    memcpy(hostZ, ones, sizeof(ones));
    memcpy(portZ, ones, sizeof(ones));
    hostS = sparse_vector_triangular_solve_dense_float_complex(CblasNoTrans, 1.0f + 0.0fi, host, hostZ, 1);
    portS = RENAME(sparse_vector_triangular_solve_dense_float_complex)(CblasNoTrans, 1.0f + 0.0fi, port, portZ, 1);
    // What is compared is what both sides define. Measured over this three-element right-hand side with
    // the port and the host on it (zeroPivot as above, so the matrix has no entry at (2, 2)):
    //
    //   port  0  nan+nani   1+0i   nan+nani
    //   host  0  inf+nani   1+0i   5.99348e+36-5.03372e+28i
    //
    // The host's third row is the bytes it was handed - it never wrote it - and its first row answers
    // +inf in the real part where the port answers NaN, so neither is a number to compare. The row the
    // matrix does define, row 1, is 1+0i on both sides and is compared exactly.
    ok = hostS == portS && isfinite(REAL_OF(portZ[0])) == 0 && isfinite(IMAG_OF(portZ[0])) == 0 &&
         isfinite(REAL_OF(hostZ[0])) == 0 && isfinite(IMAG_OF(hostZ[0])) == 0;
    for (int k = 1; k < 2 && ok; k++) {
        char here[128];
        snprintf(here, sizeof(here), "row %d: port %g%+gi, host %g%+gi", k, (double)REAL_OF(portZ[k]),
                 (double)IMAG_OF(portZ[k]), (double)REAL_OF(hostZ[k]), (double)IMAG_OF(hostZ[k]));
        ok = same_complex(REAL_OF(portZ[k]), IMAG_OF(portZ[k]), REAL_OF(hostZ[k]), IMAG_OF(hostZ[k]), 1e-6, here);
    }
    // Row 1 is the one the matrix defines, so it is the one that has to be equal; rows 0 and 2 are only
    // required to be the non-numbers both sides answer. `why` carries the reason because report() clears
    // detail before it prints.
    char whyPivot[160];
    snprintf(whyPivot, sizeof(whyPivot), "row 1: port %g%+gi, host %g%+gi; row 0: port %g%+gi, host %g%+gi", 
             (double)REAL_OF(portZ[1]), (double)IMAG_OF(portZ[1]), (double)REAL_OF(hostZ[1]), (double)IMAG_OF(hostZ[1]),
             (double)REAL_OF(portZ[0]), (double)IMAG_OF(portZ[0]), (double)REAL_OF(hostZ[0]), (double)IMAG_OF(hostZ[0]));
    report(ok, "a triangular solve with a pivot of zero", whyPivot);
    sparse_matrix_destroy(host);
    RENAME(sparse_matrix_destroy)(port);

    // The matrix form, in both layouts, and its leading-dimension refusal.
    build_triangle(SPARSE_LOWER_TRIANGULAR, lower, 4, &host, &port);
    const enum CBLAS_ORDER orders[2] = {CblasRowMajor, CblasColMajor};
    const char *orderNames[2] = {"row-major", "column-major"};
    for (int o = 0; o < 2; o++) {
        float _Complex hostB[9], portB[9];
        for (int k = 0; k < 9; k++) {
            hostB[k] = (float)(k + 1) + (float)k * 1.0fi;
            portB[k] = hostB[k];
        }
        // A leading dimension of 3 is what both layouts need: two right-hand sides for a row-major
        // matrix, three rows for a column-major one.
        hostS = sparse_matrix_triangular_solve_dense_float_complex(orders[o], CblasNoTrans, 2, 2.0f + 0.0fi, host,
                                                                   hostB, 3);
        portS = RENAME(sparse_matrix_triangular_solve_dense_float_complex)(orders[o], CblasNoTrans, 2, 2.0f + 0.0fi,
                                                                           port, portB, 3);
        ok = hostS == portS;
        for (int k = 0; k < 9 && ok; k++) {
            ok = same_complex(REAL_OF(portB[k]), IMAG_OF(portB[k]), REAL_OF(hostB[k]), IMAG_OF(hostB[k]), 1e-5,
                             "an element of B");
        }
        char name[128];
        snprintf(name, sizeof(name), "a triangular solve of two right-hand sides, %s", orderNames[o]);
        report(ok, name, detail);
        // A leading dimension below what the layout needs. The host hands it to cblas_ctrsm, which prints
        // a BLAS error and then walks off the caller's buffer (the run stops there), so this one is the
        // header's own rule and only the port is asked - which is what the real family's differential does
        // with the same case, where it never asks the host for an ldb below what the layout needs.
        for (int k = 0; k < 9; k++) {
            hostB[k] = (float)(k + 1);
            portB[k] = (float)(k + 1);
        }
        portS = RENAME(sparse_matrix_triangular_solve_dense_float_complex)(orders[o], CblasNoTrans, 2, 2.0f + 0.0fi,
                                                                           port, portB, 1);
        snprintf(name, sizeof(name), "a triangular solve with a leading dimension of 1, %s (header)", orderNames[o]);
        report(portS == SPARSE_ILLEGAL_PARAMETER, name, "the port did not refuse it");
    }
    // The host hands an order it does not know to cblas_ctrsm and walks off the caller's buffer, so this
    // one is the header's rule and only the port is asked.
    float _Complex outOfRange[9] = {0};
    portS = RENAME(sparse_matrix_triangular_solve_dense_float_complex)((enum CBLAS_ORDER)77, CblasNoTrans, 2, 2.0f + 0.0fi,
                                                                       port, outOfRange, 3);
    report(portS == SPARSE_ILLEGAL_PARAMETER, "a triangular solve with a bad order (header)",
           "the port did not refuse it");
    sparse_matrix_destroy(host);
    RENAME(sparse_matrix_destroy)(port);

    // The double twin of the matrix form.
    sparse_matrix_double_complex hostD = sparse_matrix_create_double_complex(3, 3);
    sparse_matrix_double_complex portD = RENAME(sparse_matrix_create_double_complex)(3, 3);
    sparse_set_matrix_property(hostD, SPARSE_LOWER_TRIANGULAR);
    RENAME(sparse_set_matrix_property)(portD, SPARSE_LOWER_TRIANGULAR);
    for (int k = 0; k < 4; k++) {
        sparse_insert_entry_double_complex(hostD, lower[k].re + lower[k].im * 1.0i, lower[k].row, lower[k].column);
        RENAME(sparse_insert_entry_double_complex)(portD, lower[k].re + lower[k].im * 1.0i, lower[k].row,
                                                   lower[k].column);
    }
    double _Complex hostDB[9], portDB[9];
    for (int k = 0; k < 9; k++) {
        hostDB[k] = (double)(k + 1) + (double)k * 1.0i;
        portDB[k] = hostDB[k];
    }
    hostS = sparse_matrix_triangular_solve_dense_double_complex(CblasColMajor, CblasNoTrans, 2, 1.0 + 0.0i, hostD,
                                                                hostDB, 3);
    portS = RENAME(sparse_matrix_triangular_solve_dense_double_complex)(CblasColMajor, CblasNoTrans, 2, 1.0 + 0.0i, portD,
                                                                  portDB, 3);
    ok = hostS == portS;
    for (int k = 0; k < 9 && ok; k++) {
        ok = same_complex(REAL_OF(portDB[k]), IMAG_OF(portDB[k]), REAL_OF(hostDB[k]), IMAG_OF(hostDB[k]), 1e-12,
                         "an element of B");
    }
    report(ok, "a triangular solve in the double complex", detail);
    sparse_matrix_destroy(hostD);
    RENAME(sparse_matrix_destroy)(portD);
}

static void level_three_cases(void)
{
    const CharonEntry entries[4] = {{0, 0, 3.0, 4.0}, {0, 1, 1.0, 0.0}, {1, 0, 2.0, -1.0}, {2, 2, -1.0, 0.5}};
    sparse_matrix_float_complex host, port;
    sparse_matrix_double_complex hostD, portD;
    build_pair(entries, 4, &host, &port, &hostD, &portD);

    // Nine elements, not six: B is 3x2 and C is 3x2, both at a leading dimension of 3, so a row-major
    // call reaches nine of them and a column-major one six. Six left the port copying past b and past
    // C - AddressSanitizer's stack-buffer-overflow at SparseComplex18.m:816 through this very call.
    float _Complex b[9], c[9];
    for (int k = 0; k < 9; k++) {
        b[k] = (float)(k + 1) + (float)k * 0.5fi;
        c[k] = 0.25f * (float)(k + 1) - (float)k * 0.25fi;
    }
    const enum CBLAS_ORDER orders[2] = {CblasRowMajor, CblasColMajor};
    const enum CBLAS_TRANSPOSE transposes[2] = {CblasNoTrans, CblasTrans};
    const char *orderNames[2] = {"row-major", "column-major"};
    sparse_status hostS, portS;
    const char *transposeNames[2] = {"without a transpose", "with a transpose"};
    for (int o = 0; o < 2; o++) {
        for (int t = 0; t < 2; t++) {
            float _Complex hostC[9], portC[9];
            memcpy(hostC, c, sizeof(c));
            memcpy(portC, c, sizeof(c));
            hostS = sparse_matrix_product_dense_float_complex(orders[o], transposes[t], 2, 2.0f + 1.0fi, host, b, 3,
                                                               hostC, 3);
            portS = RENAME(sparse_matrix_product_dense_float_complex)(orders[o], transposes[t], 2, 2.0f + 1.0fi, port, b,
                                                                      3, portC, 3);
            int ok = hostS == portS;
            for (int k = 0; k < 9 && ok; k++) {
                ok = same_complex(REAL_OF(portC[k]), IMAG_OF(portC[k]), REAL_OF(hostC[k]), IMAG_OF(hostC[k]), 1e-5,
                                 "an element of C");
            }
            char name[160];
            snprintf(name, sizeof(name), "a sparse-dense product, %s, %s", orderNames[o], transposeNames[t]);
            report(ok, name, detail);
        }
        // The refusals, with C untouched.
        for (int which = 0; which < 3; which++) {
            float _Complex hostC[9], portC[9];
            memcpy(hostC, c, sizeof(c));
            memcpy(portC, c, sizeof(c));
            sparse_dimension hostLdb = 3, portLdb = 3, hostLdc = 3, portLdc = 3;
            enum CBLAS_ORDER hostOrder = orders[o], portOrder = orders[o];
            enum CBLAS_TRANSPOSE hostTrans = CblasNoTrans, portTrans = CblasNoTrans;
            if (which == 0) {
                hostLdb = portLdb = 1;
            } else if (which == 1) {
                hostLdc = portLdc = 1;
            } else {
                hostOrder = portOrder = (enum CBLAS_ORDER)77;
            }
            hostS = sparse_matrix_product_dense_float_complex(hostOrder, hostTrans, 2, 2.0f + 1.0fi, host, b, hostLdb,
                                                               hostC, hostLdc);
            portS = RENAME(sparse_matrix_product_dense_float_complex)(portOrder, portTrans, 2, 2.0f + 1.0fi, port, b,
                                                                      portLdb, portC, portLdc);
            int ok = hostS == portS && hostS == SPARSE_ILLEGAL_PARAMETER;
            for (int k = 0; k < 9 && ok; k++) {
                ok = REAL_OF(portC[k]) == REAL_OF(c[k]) && IMAG_OF(portC[k]) == IMAG_OF(c[k]);
            }
            const char *refusalNames[3] = {"a leading dimension of 1 for B", "a leading dimension of 1 for C",
                                           "an order the enumeration does not name"};
            char name[160];
            snprintf(name, sizeof(name), "a sparse-dense product refused for %s, %s", refusalNames[which], orderNames[o]);
            report(ok, name, "the statuses differ, or C was written");
        }
        // An alpha of exactly zero, and a count of columns of zero, leave C exactly as it was.
        float _Complex hostC[9], portC[9];
        memcpy(hostC, c, sizeof(c));
        memcpy(portC, c, sizeof(c));
        hostS = sparse_matrix_product_dense_float_complex(orders[o], CblasNoTrans, 2, 0.0f + 0.0fi, host, b, 3, hostC,
                                                           3);
        portS = RENAME(sparse_matrix_product_dense_float_complex)(orders[o], CblasNoTrans, 2, 0.0f + 0.0fi, port, b, 3,
                                                                  portC, 3);
        int ok = hostS == portS;
        for (int k = 0; k < 9 && ok; k++) {
            ok = REAL_OF(portC[k]) == REAL_OF(c[k]) && IMAG_OF(portC[k]) == IMAG_OF(c[k]);
        }
        char name[128];
        snprintf(name, sizeof(name), "a sparse-dense product by an alpha of zero, %s", orderNames[o]);
        report(ok, name, "the statuses differ or C was written");
    }
    hostS = sparse_matrix_product_dense_float_complex(CblasRowMajor, (enum CBLAS_TRANSPOSE)77, 2, 1.0f, host, b, 3, c, 3);
    portS = RENAME(sparse_matrix_product_dense_float_complex)(CblasRowMajor, (enum CBLAS_TRANSPOSE)77, 2, 1.0f, port, b, 3,
                                                              c, 3);
    report(hostS == portS && hostS == SPARSE_ILLEGAL_PARAMETER, "a sparse-dense product with a bad transpose",
           "the statuses differ or are not a refusal");

    // The double twin.
    double _Complex db[9], dc[9];
    for (int k = 0; k < 9; k++) {
        db[k] = (double)(k + 1) + (double)k * 0.5i;
        dc[k] = 0.25 * (double)(k + 1) - (double)k * 0.25i;
    }
    double _Complex hostDC[9], portDC[9];
    for (int k = 0; k < 9; k++) {
        hostDC[k] = (double)k + (double)k * 0.25i;
        portDC[k] = hostDC[k];
    }
    hostS = sparse_matrix_product_dense_double_complex(CblasRowMajor, CblasTrans, 2, 2.0 + 1.0i, hostD, db, 3, hostDC, 3);
    portS = RENAME(sparse_matrix_product_dense_double_complex)(CblasRowMajor, CblasTrans, 2, 2.0 + 1.0i, portD, db, 3,
                                                                portDC, 3);
    int ok = hostS == portS;
    for (int k = 0; k < 9 && ok; k++) {
        ok = same_complex(REAL_OF(portDC[k]), IMAG_OF(portDC[k]), REAL_OF(hostDC[k]), IMAG_OF(hostDC[k]), 1e-12,
                         "an element of C");
    }
    report(ok, "a sparse-dense product in the double complex", detail);
    sparse_matrix_destroy(host);
    RENAME(sparse_matrix_destroy)(port);
    sparse_matrix_destroy(hostD);
    RENAME(sparse_matrix_destroy)(portD);
}

static void outer_and_sparse_product_cases(void)
{
    const CharonEntry entries[3] = {{0, 0, 3.0, 4.0}, {0, 1, 1.0, 0.0}, {1, 0, 2.0, -1.0}};
    float _Complex x[3] = {1.0f + 0.0fi, 2.0f + 1.0fi, -1.0f + 0.0fi};
    const sparse_index indy[3] = {0, 2};
    float _Complex y[2] = {5.0f + 1.0fi, -6.0f + 2.0fi};

    // C = alpha * x * y' over the x, y and indy this function already built: x = {1, 2+i, -1} over three
    // rows, y = {5+i, -6+2i} at the columns indy = {0, 2}. x is indexed by the row and y by the column,
    // C[i, indy[k]] = alpha * x[i] * y[k], so at alpha = 2+i the three rows are
    //
    //   C[0] = (9+7i, -14-2i)    C[1] = (11+8i, -18-3i)    C[2] = (8+6i, -12+4i)
    //
    // and the host answers exactly those. The case is here because every earlier one passed x = {1, 1},
    // where reading x at the wrong index gives the same number: the mutant below is that wrong index - it
    // reads x at k and writes alpha * x[k] * y[k] into every row - and the case asserts that the mutant
    // does not agree with the header, so a port carrying that bug goes red here.
    const float _Complex alpha = 2.0f + 1.0fi;
    float _Complex mutant[3][2];
    int mutantDiffers = 0;
    for (int k = 0; k < 2; k++) {
        for (int i = 0; i < 3; i++) {
            mutant[i][k] = alpha * x[k] * y[k];
        }
    }
    for (int i = 0; i < 3 && !mutantDiffers; i++) {
        for (int k = 0; k < 2 && !mutantDiffers; k++) {
            const float _Complex right = alpha * x[i] * y[k];
            mutantDiffers = REAL_OF(mutant[i][k]) != REAL_OF(right) || IMAG_OF(mutant[i][k]) != IMAG_OF(right);
        }
    }
    report(mutantDiffers, "the outer-product mutant that indexes x by the nonzero differs from the header",
           "the mutant agrees with the header, so the case below cannot see that bug");

    sparse_matrix_float_complex hostC = NULL, portC = NULL;
    sparse_status hostS = sparse_outer_product_dense_float_complex(3, 3, 2, alpha, x, 1, y, indy, &hostC);
    sparse_status portS = RENAME(sparse_outer_product_dense_float_complex)(3, 3, 2, alpha, x, 1, y, indy, &portC);
    int ok = hostS == portS && hostS == SPARSE_SUCCESS && hostC != NULL && portC != NULL &&
             sparse_get_matrix_number_of_rows(hostC) == RENAME(sparse_get_matrix_number_of_rows)(portC) &&
             sparse_get_matrix_nonzero_count(hostC) == RENAME(sparse_get_matrix_nonzero_count)(portC);
    for (sparse_index r = 0; r < 3 && ok; r++) {
        sparse_index hostEnd = 0, portEnd = 0;
        float _Complex hostValues[4], portValues[4];
        sparse_index hostIndices[4], portIndices[4];
        memset(hostValues, 0x5a, sizeof(hostValues));
        memset(portValues, 0x5a, sizeof(portValues));
        memset(hostIndices, 0x5a, sizeof(hostIndices));
        memset(portIndices, 0x5a, sizeof(portIndices));
        hostS = sparse_extract_sparse_row_float_complex(hostC, r, 0, &hostEnd, 4, hostValues, hostIndices);
        portS = RENAME(sparse_extract_sparse_row_float_complex)(portC, r, 0, &portEnd, 4, portValues, portIndices);
        // Only the slots the return value says were written are compared; both sides leave the rest alone.
        ok = hostS == portS && portS == (long)2 && portEnd == 3 && hostEnd == 3 && portIndices[0] == 0 &&
             portIndices[1] == 2;
        for (int k = 0; k < 2 && ok; k++) {
            // The expectation, computed by the compiler here from the same inputs and with the indices
            // named: row r, nonzero k.
            const float _Complex want = alpha * x[r] * y[k];
            ok = same_complex(REAL_OF(portValues[k]), IMAG_OF(portValues[k]), REAL_OF(want), IMAG_OF(want), 1e-5,
                             "an entry of the product against the header") &&
                 same_complex(REAL_OF(portValues[k]), IMAG_OF(portValues[k]), REAL_OF(hostValues[k]),
                              IMAG_OF(hostValues[k]), 1e-5, "an entry of the product against the host");
        }
    }
    if (!ok) {
        snprintf(detail, sizeof(detail), "status %d against %d, or an entry of the product differs", (int)hostS,
                 (int)portS);
    }
    report(ok, "an outer product with x of three different values, against the header and the host", detail);
    if (hostC) sparse_matrix_destroy(hostC);
    if (portC) RENAME(sparse_matrix_destroy)(portC);

    // More nonzeros than N is refused, and the caller's pointer is left alone.
    sparse_matrix_float_complex heldHost = sparse_matrix_create_float_complex(1, 1);
    sparse_matrix_float_complex heldPort = RENAME(sparse_matrix_create_float_complex)(1, 1);
    sparse_matrix_float_complex keepHost = heldHost, keepPort = heldPort;
    hostS = sparse_outer_product_dense_float_complex(3, 3, 4, 1.0f + 0.0fi, x, 1, y, indy, &heldHost);
    portS = RENAME(sparse_outer_product_dense_float_complex)(3, 3, 4, 1.0f + 0.0fi, x, 1, y, indy, &heldPort);
    report(hostS == portS && hostS == SPARSE_ILLEGAL_PARAMETER && heldHost == keepHost && heldPort == keepPort,
           "an outer product with more nonzeros than columns", "the statuses differ or the pointer was written");
    sparse_matrix_destroy(heldHost);
    RENAME(sparse_matrix_destroy)(heldPort);

    // A count of zero and an alpha of exactly zero answer a matrix of the right shape with nothing in it.
    hostC = NULL;
    portC = NULL;
    hostS = sparse_outer_product_dense_float_complex(3, 3, 0, 2.0f + 1.0fi, x, 1, y, indy, &hostC);
    portS = RENAME(sparse_outer_product_dense_float_complex)(3, 3, 0, 2.0f + 1.0fi, x, 1, y, indy, &portC);
    ok = hostS == portS && hostC != NULL && portC != NULL &&
         sparse_get_matrix_nonzero_count(hostC) == RENAME(sparse_get_matrix_nonzero_count)(portC);
    report(ok, "an outer product of a count of zero", "the statuses or the counts differ");
    if (hostC) sparse_matrix_destroy(hostC);
    if (portC) RENAME(sparse_matrix_destroy)(portC);

    // C = alpha * op(A) * B + C with B sparse too.
    sparse_matrix_float_complex hostA, portA, hostB, portB;
    sparse_matrix_double_complex hostAD, portAD;
    build_pair(entries, 3, &hostA, &portA, &hostAD, &portAD);
    hostB = sparse_matrix_create_float_complex(3, 2);
    portB = RENAME(sparse_matrix_create_float_complex)(3, 2);
    const sparse_index bRows[2] = {0, 2};
    const sparse_index bColumns[2] = {0, 1};
    float _Complex bValues[2] = {1.0f + 1.0fi, 2.0f - 2.0fi};
    for (int k = 0; k < 2; k++) {
        sparse_insert_entry_float_complex(hostB, bValues[k], bRows[k], bColumns[k]);
        RENAME(sparse_insert_entry_float_complex)(portB, bValues[k], bRows[k], bColumns[k]);
    }
    // Nine elements, not six: C is 3x2 with a leading dimension of 3, so a row-major call writes three
    // rows of three and a column-major one writes two columns of three. Six is what the column-major
    // layout reaches, and the row-major layout wrote three elements past it.
    float _Complex dense[9];
    for (int k = 0; k < 9; k++) {
        dense[k] = 0.5f * (float)(k + 1) - (float)k * 0.5fi;
    }
    const enum CBLAS_ORDER bothOrders[2] = {CblasRowMajor, CblasColMajor};
    const enum CBLAS_TRANSPOSE bothTransposes[2] = {CblasNoTrans, CblasTrans};
    for (int o = 0; o < 2; o++) {
        for (int t = 0; t < 2; t++) {
            float _Complex hostC2[9], portC2[9];
            memcpy(hostC2, dense, sizeof(dense));
            memcpy(portC2, dense, sizeof(dense));
            hostS = sparse_matrix_product_sparse_float_complex(bothOrders[o], bothTransposes[t], 1.0f + 1.0fi, hostA, hostB,
                                                                hostC2, 3);
            portS = RENAME(sparse_matrix_product_sparse_float_complex)(bothOrders[o], bothTransposes[t], 1.0f + 1.0fi,
                                                                       portA, portB, portC2, 3);
            int ok2 = hostS == portS;
            for (int k = 0; k < 9 && ok2; k++) {
                ok2 = same_complex(REAL_OF(portC2[k]), IMAG_OF(portC2[k]), REAL_OF(hostC2[k]), IMAG_OF(hostC2[k]),
                                  1e-5, "an element of C");
            }
            char name[160];
            snprintf(name, sizeof(name), "a sparse-sparse product, %s, transpose %d", o == 0 ? "row-major" : "column-major",
                     (int)bothTransposes[t]);
            report(ok2, name, detail);
        }
        // An ldc of 1 against two columns: the port refuses it below what the layout needs, and the host
        // hands it to cblas_cgemm, which prints a BLAS error and ends the process, so it is not asked.
        float _Complex hostC2[9], portC2[9];
        memcpy(hostC2, dense, sizeof(dense));
        memcpy(portC2, dense, sizeof(dense));
        portS = RENAME(sparse_matrix_product_sparse_float_complex)(bothOrders[o], CblasNoTrans, 1.0f, portA, portB,
                                                                    portC2, 1);
        report(portS == SPARSE_ILLEGAL_PARAMETER, "a sparse-sparse product with an ldc of 1 (header)",
               "the port did not refuse it");
        // A B whose row count is not A's column count.
        sparse_matrix_float_complex wrongB = sparse_matrix_create_float_complex(2, 2);
        sparse_matrix_float_complex wrongBPort = RENAME(sparse_matrix_create_float_complex)(2, 2);
        portS = RENAME(sparse_matrix_product_sparse_float_complex)(bothOrders[o], CblasNoTrans, 1.0f, portA, wrongBPort,
                                                                    portC2, 3);
        report(portS == SPARSE_ILLEGAL_PARAMETER, "a sparse-sparse product with a B of the wrong shape (header)",
               "the port did not refuse it");
        sparse_matrix_destroy(wrongB);
        RENAME(sparse_matrix_destroy)(wrongBPort);
    }
    hostS = sparse_matrix_product_sparse_float_complex(CblasRowMajor, (enum CBLAS_TRANSPOSE)77, 1.0f, hostA, hostB, dense, 3);
    portS = RENAME(sparse_matrix_product_sparse_float_complex)(CblasRowMajor, (enum CBLAS_TRANSPOSE)77, 1.0f, portA, portB,
                                                               dense, 3);
    report(hostS == portS && hostS == SPARSE_ILLEGAL_PARAMETER, "a sparse-sparse product with a bad transpose",
           "the statuses differ or are not a refusal");

    // sparse_matrix_product_sparse_double_complex, the double twin of the case above. Its declaration
    // was in this file and nothing called it: build_pair had already built the two double matrices this
    // needs, and they were destroyed at the end of the block unused.
    {
        sparse_matrix_double_complex hostBD = sparse_matrix_create_double_complex(3, 2);
        sparse_matrix_double_complex portBD = RENAME(sparse_matrix_create_double_complex)(3, 2);
        const double _Complex bdValues[2] = {1.25 + 0.5i, -2.5 - 1.75i};
        for (int k = 0; k < 2; k++) {
            sparse_insert_entry_double_complex(hostBD, bdValues[k], bRows[k], bColumns[k]);
            RENAME(sparse_insert_entry_double_complex)(portBD, bdValues[k], bRows[k], bColumns[k]);
        }
        // The entries hostAD holds: the list this function built both sides from, at the top of the
        // function, so the expectation below is computed from the numbers the matrices hold.
        const CharonEntry aEntries[3] = {{0, 0, 3.0, 4.0}, {0, 1, 1.0, 0.0}, {1, 0, 2.0, -1.0}};
        // Nine elements, not six: C is 3x2 with a leading dimension of 3, so a row-major call writes
        // three rows of three and a column-major one writes two columns of three. Six is what the
        // column-major layout reaches, and the row-major layout wrote three elements past it.
        double denseD[9][2];
        const double denseValues[9][2] = {{0.5, 0.25},  {-0.5, 1.0},   {1.5, -0.75}, {2.0, 0.5},
                                          {-1.25, 0.0}, {0.75, -2.0},  {3.5, 1.25},  {-0.5, 0.75},
                                          {1.25, -0.5}};
        for (int k = 0; k < 9; k++) {
            denseD[k][0] = denseValues[k][0];
            denseD[k][1] = denseValues[k][1];
        }
        const double _Complex alpha = 0.75 - 0.25i;
        for (int o = 0; o < 2; o++) {
            for (int t = 0; t < 2; t++) {
                double hostOut[9][2], portOut[9][2];
                memcpy(hostOut, denseD, sizeof(denseD));
                memcpy(portOut, denseD, sizeof(denseD));
                hostS = sparse_matrix_product_sparse_double_complex(bothOrders[o], bothTransposes[t], alpha, hostAD, hostBD,
                                                                     (double _Complex *)hostOut, 3);
                portS = RENAME(sparse_matrix_product_sparse_double_complex)(bothOrders[o], bothTransposes[t], alpha, portAD,
                                                                           portBD, (double _Complex *)portOut, 3);
                // The header's rule for this call (BLAS.h:1009, the same sentence the real family has):
                // C = alpha * op(A) * B + C, with A 3x3, B 3x2, C 3x2. The inner index k runs over the three
                // rows, and the layout decides where element (i, j) of C goes.
                double want[9][2];
                memcpy(want, denseD, sizeof(denseD));
                for (int i = 0; i < 3; i++) {
                    for (int j = 0; j < 2; j++) {
                        int at = o == 0 ? i * 3 + j : i + j * 3;
                        double re = 0.0, im = 0.0;
                        for (sparse_dimension k = 0; k < 3; k++) {
                            double aRe = 0.0, aIm = 0.0, bRe = 0.0, bIm = 0.0;
                            // `t` is this file's 0 or 1 for the two transposes, not the enumeration's value.
                            if (t == 0) {
                                for (int q = 0; q < 3; q++) {
                                    if (aEntries[q].row == i && aEntries[q].column == k) {
                                        aRe = aEntries[q].re;
                                        aIm = aEntries[q].im;
                                    }
                                }
                            } else {
                                for (int q = 0; q < 3; q++) {
                                    if (aEntries[q].row == k && aEntries[q].column == i) {
                                        aRe = aEntries[q].re;
                                        aIm = aEntries[q].im;
                                    }
                                }
                            }
                            for (int q = 0; q < 2; q++) {
                                if (bRows[q] == k && bColumns[q] == j) {
                                    bRe = REAL_OF(bdValues[q]);
                                    bIm = IMAG_OF(bdValues[q]);
                                }
                            }
                            re += aRe * bRe - aIm * bIm;
                            im += aRe * bIm + aIm * bRe;
                        }
                        double scaleRe = REAL_OF(alpha) * re - IMAG_OF(alpha) * im;
                        double scaleIm = REAL_OF(alpha) * im + IMAG_OF(alpha) * re;
                        want[at][0] = denseD[at][0] + scaleRe;
                        want[at][1] = denseD[at][1] + scaleIm;
                    }
                }
                int okD = hostS == portS;
                for (int k = 0; k < 9 && okD; k++) {
                    okD = same_complex(portOut[k][0], portOut[k][1], want[k][0], want[k][1], 1e-12, "the port against the rule") &&
                          same_complex(hostOut[k][0], hostOut[k][1], want[k][0], want[k][1], 1e-12, "the host against the rule");
                }
                char nameD[160];
                snprintf(nameD, sizeof(nameD), "a double sparse-sparse product, %s, transpose %d against the header's rule",
                         o == 0 ? "row-major" : "column-major", (int)bothTransposes[t]);
                // report() clears detail before it prints, so the reason goes in the argument.
                char whyD[256];
                if (detail[0]) {
                    snprintf(whyD, sizeof(whyD), "%s", detail);
                } else {
                    snprintf(whyD, sizeof(whyD), "the statuses differ: port %d, host %d", portS, hostS);
                }
                report(okD, nameD, whyD);
            }
        }
        // The refusal the port makes and the host does not, and the bad transpose name, as for the float
        // twin above.
        double hostOut2[9][2], portOut2[9][2];
        memcpy(hostOut2, denseD, sizeof(denseD));
        memcpy(portOut2, denseD, sizeof(denseD));
        hostS = sparse_matrix_product_sparse_double_complex(CblasRowMajor, (enum CBLAS_TRANSPOSE)77, alpha, hostAD, hostBD,
                                                             (double _Complex *)hostOut2, 3);
        portS = RENAME(sparse_matrix_product_sparse_double_complex)(CblasRowMajor, (enum CBLAS_TRANSPOSE)77, alpha, portAD,
                                                                   portBD, (double _Complex *)portOut2, 3);
        report(hostS == portS && hostS == SPARSE_ILLEGAL_PARAMETER,
               "a double sparse-sparse product with a bad transpose", "the statuses differ or are not a refusal");
        sparse_matrix_destroy(hostBD);
        RENAME(sparse_matrix_destroy)(portBD);
    }

    sparse_matrix_destroy(hostA);
    RENAME(sparse_matrix_destroy)(portA);
    sparse_matrix_destroy(hostAD);
    RENAME(sparse_matrix_destroy)(portAD);
    sparse_matrix_destroy(hostB);
    RENAME(sparse_matrix_destroy)(portB);
}

// The two permutations of a 2x3 matrix, against the swap loop Sparse/BLAS.h writes out.
//
// The oracle is that loop, run here over a plain array of the six entries, and not the host for two of
// the cases: with a row target outside the matrix the host writes through its own row array and the
// matrix comes back damaged (measured: sparse_permute_rows_float_complex with {5,5} on a 2x3 matrix
// answers SPARSE_SUCCESS and leaves row 0 holding denormals and a 1e29), and with a target that is the
// row itself it answers the same and leaves the matrix changed. Every other permutation is compared with
// the host as well.
static void permutation_cases(void)
{
    const CharonEntry entries[6] = {{0, 0, 1.0, 1.0}, {0, 1, 2.0, -2.0}, {0, 2, 3.0, 0.0},
                                    {1, 0, 4.0, 3.0}, {1, 1, 5.0, 0.0}, {1, 2, 6.0, -6.0}};
    const sparse_index rowPermutations[6][2] = {{1, 0}, {0, 1}, {0, 0}, {1, 1}, {5, 5}, {-1, 1}};
    const char *rowNames[6] = {"the rows {1,0}", "the rows {0,1}", "the rows {0,0}", "the rows {1,1}",
                               "a target outside the matrix", "a negative target"};
    const sparse_index colPermutations[6][3] = {{1, 0, 2}, {2, 1, 0}, {2, 0, 1}, {0, 2, 1}, {0, 1, 2}, {7, 1, 2}};
    const char *colNames[6] = {"the columns {1,0,2}", "the columns {2,1,0}", "the columns {2,0,1}",
                               "the columns {0,2,1}", "the columns {0,1,2}", "a target outside the matrix"};
    sparse_status portS = SPARSE_SUCCESS;

    for (int which = 0; which < 6; which++) {
        sparse_matrix_float_complex host = sparse_matrix_create_float_complex(2, 3);
        sparse_matrix_float_complex port = RENAME(sparse_matrix_create_float_complex)(2, 3);
        sparse_matrix_double_complex hostD = sparse_matrix_create_double_complex(2, 3);
        sparse_matrix_double_complex portD = RENAME(sparse_matrix_create_double_complex)(2, 3);
        for (int k = 0; k < 6; k++) {
            sparse_insert_entry_float_complex(host, (float)entries[k].re + (float)entries[k].im * 1.0fi, entries[k].row,
                                               entries[k].column);
            RENAME(sparse_insert_entry_float_complex)(port, (float)entries[k].re + (float)entries[k].im * 1.0fi,
                                                      entries[k].row, entries[k].column);
            sparse_insert_entry_double_complex(hostD, entries[k].re + entries[k].im * 1.0i, entries[k].row,
                                               entries[k].column);
            RENAME(sparse_insert_entry_double_complex)(portD, entries[k].re + entries[k].im * 1.0i, entries[k].row,
                                                       entries[k].column);
        }
        // The swap loop, over a plain array: for each i, swap the row i with the row the name gives, and
        // for each j the same over the columns. A target outside the matrix or a target that is the row
        // itself is a no-op, which is what the loop above does and what the port has to match.
        double want[2][3][2];
        for (int r = 0; r < 2; r++) {
            for (int c = 0; c < 3; c++) {
                want[r][c][0] = 0.0;
                want[r][c][1] = 0.0;
            }
        }
        for (int k = 0; k < 6; k++) {
            want[entries[k].row][entries[k].column][0] = entries[k].re;
            want[entries[k].row][entries[k].column][1] = entries[k].im;
        }
        for (int r = 0; r < 2; r++) {
            int target = (int)rowPermutations[which][r];
            if (target < 0 || target >= 2 || target == r) {
                continue;
            }
            for (int c = 0; c < 3; c++) {
                double held0 = want[r][c][0], held1 = want[r][c][1];
                want[r][c][0] = want[target][c][0];
                want[r][c][1] = want[target][c][1];
                want[target][c][0] = held0;
                want[target][c][1] = held1;
            }
        }
        char name[128];
        snprintf(name, sizeof(name), "a row permutation, %s%s", rowNames[which],
                 (which == 4 || which == 5) ? " (header)" : "");
        const int rowsHeaderOnly = which == 4 || which == 5;
        sparse_status permHS = SPARSE_SUCCESS, permPS = SPARSE_SUCCESS, permHDS = SPARSE_SUCCESS,
                        permPDS = SPARSE_SUCCESS;
        if (!rowsHeaderOnly) {
            permHS = sparse_permute_rows_float_complex(host, rowPermutations[which]);
            permHDS = sparse_permute_rows_double_complex(hostD, rowPermutations[which]);
        }
        permPS = RENAME(sparse_permute_rows_float_complex)(port, rowPermutations[which]);
        permPDS = RENAME(sparse_permute_rows_double_complex)(portD, rowPermutations[which]);
        int ok = permPS == SPARSE_SUCCESS && permPDS == SPARSE_SUCCESS;
        if (!rowsHeaderOnly) {
            ok = ok && permHS == permPS && permHDS == permPDS;
        }
        for (int r = 0; r < 2 && ok; r++) {
            sparse_index portEnd = 0;
            float _Complex portValues[3];
            sparse_index portIndices[3];
            portS = RENAME(sparse_extract_sparse_row_float_complex)(port, r, 0, &portEnd, 3, portValues,
                                                                     portIndices);
            ok = portS == (long)3 && portEnd == 3;
            for (int c = 0; c < 3 && ok; c++) {
                ok = portIndices[c] == c && REAL_OF(portValues[c]) == want[r][c][0] &&
                     IMAG_OF(portValues[c]) == want[r][c][1];
            }
        }
        if (!ok) {
            snprintf(detail, sizeof(detail), "status %d against %d, the rows of the swapped matrix differ", (int)permHS,
                     (int)permPS);
        }
        report(ok, name, detail);

        // The columns, on the matrix the rows left.
        for (int j = 0; j < 3; j++) {
            int target = (int)colPermutations[which][j];
            if (target < 0 || target >= 3 || target == j) {
                continue;
            }
            for (int r = 0; r < 2; r++) {
                double held0 = want[r][j][0], held1 = want[r][j][1];
                want[r][j][0] = want[r][target][0];
                want[r][j][1] = want[r][target][1];
                want[r][target][0] = held0;
                want[r][target][1] = held1;
            }
        }
        const int headerOnly = which == 5;
        snprintf(name, sizeof(name), "a column permutation, %s%s", colNames[which], headerOnly ? " (header)" : "");
        sparse_status colHS = SPARSE_SUCCESS, colPS = SPARSE_SUCCESS, colHDS = SPARSE_SUCCESS,
                        colPDS = SPARSE_SUCCESS;
        if (!headerOnly) {
            colHS = sparse_permute_cols_float_complex(host, colPermutations[which]);
            colHDS = sparse_permute_cols_double_complex(hostD, colPermutations[which]);
        }
        colPS = RENAME(sparse_permute_cols_float_complex)(port, colPermutations[which]);
        colPDS = RENAME(sparse_permute_cols_double_complex)(portD, colPermutations[which]);
        ok = colPS == SPARSE_SUCCESS && colPDS == SPARSE_SUCCESS;
        if (!headerOnly) {
            ok = ok && colHS == colPS && colHDS == colPDS;
        }
        for (int r = 0; r < 2 && ok; r++) {
            sparse_index portEnd = 0;
            float _Complex portValues[3];
            sparse_index portIndices[3];
            portS = RENAME(sparse_extract_sparse_row_float_complex)(port, r, 0, &portEnd, 3, portValues,
                                                                     portIndices);
            ok = portS == (long)3 && portEnd == 3;
            for (int c = 0; c < 3 && ok; c++) {
                ok = portIndices[c] == c && REAL_OF(portValues[c]) == want[r][c][0] &&
                     IMAG_OF(portValues[c]) == want[r][c][1];
            }
        }
        report(ok, name, detail);
        // The nonzero count is part of the answer: six entries come in and six go out.
        report(RENAME(sparse_get_matrix_nonzero_count)(port) == 6 &&
                   RENAME(sparse_get_matrix_nonzero_count)(portD) == 6,
               "the nonzero counts after a permutation", "a count differs");

        sparse_matrix_destroy(host);
        RENAME(sparse_matrix_destroy)(port);
        sparse_matrix_destroy(hostD);
        RENAME(sparse_matrix_destroy)(portD);
    }
}

static void norm_and_trace_cases(void)
{
    const CharonEntry entries[3] = {{0, 0, 3.0, 4.0}, {1, 0, 1.0, 0.0}, {1, 2, -2.0, 1.0}};
    sparse_matrix_float_complex host, port;
    sparse_matrix_double_complex hostD, portD;
    build_pair(entries, 3, &host, &port, &hostD, &portD);

    const sparse_norm norms[5] = {SPARSE_NORM_ONE, SPARSE_NORM_TWO, SPARSE_NORM_INF, SPARSE_NORM_R1,
                                  (sparse_norm)99};
    const char *normNames[5] = {"one", "two", "infinity", "R1", "an unlisted name"};
    for (int n = 0; n < 5; n++) {
        float hostValue = sparse_elementwise_norm_float_complex(host, norms[n]);
        float mineValue = RENAME(sparse_elementwise_norm_float_complex)(port, norms[n]);
        char name[128];
        snprintf(name, sizeof(name), "the elementwise %s norm of a matrix of complex values", normNames[n]);
        report(same_real(mineValue, hostValue, 1e-5), name, "the values differ");
        hostValue = sparse_operator_norm_float_complex(host, norms[n]);
        mineValue = RENAME(sparse_operator_norm_float_complex)(port, norms[n]);
        snprintf(name, sizeof(name), "the operator %s norm of a matrix of complex values", normNames[n]);
        // The two-norm is the one case with a tolerance, and for the reason the real family gives: the port
        // answers the largest eigenvalue of the Hermitian Gram matrix through the release's own LAPACK and
        // the host reaches the same number by an iteration, so the two agree to about one part in a
        // hundred thousand and not to the last bit. Measured here: the host answers 5.12196 and the port
        // 5.12206, where the exact largest singular value of the matrix is 5.12206 (the square root of the
        // larger root of t^2 - 31t + 125), so it is the host that is the approximation.
        report(same_real(mineValue, hostValue, norms[n] == SPARSE_NORM_TWO ? 3e-3 : 1e-5), name, "the values differ");
        double hostDValue = sparse_elementwise_norm_double_complex(hostD, norms[n]);
        double mineDValue = RENAME(sparse_elementwise_norm_double_complex)(portD, norms[n]);
        snprintf(name, sizeof(name), "the elementwise %s norm, in the double complex", normNames[n]);
        report(same_real(mineDValue, hostDValue, 1e-12), name, "the values differ");
        hostDValue = sparse_operator_norm_double_complex(hostD, norms[n]);
        mineDValue = RENAME(sparse_operator_norm_double_complex)(portD, norms[n]);
        snprintf(name, sizeof(name), "the operator %s norm, in the double complex", normNames[n]);
        report(same_real(mineDValue, hostDValue, norms[n] == SPARSE_NORM_TWO ? 3e-3 : 1e-12), name,
               "the values differ");
    }
    // An empty matrix answers zero for every norm.
    sparse_matrix_float_complex emptyHost = sparse_matrix_create_float_complex(0, 0);
    sparse_matrix_float_complex emptyPort = RENAME(sparse_matrix_create_float_complex)(0, 0);
    report(RENAME(sparse_elementwise_norm_float_complex)(emptyPort, SPARSE_NORM_TWO) == 0.0f &&
               RENAME(sparse_operator_norm_float_complex)(emptyPort, SPARSE_NORM_TWO) == 0.0f,
           "the norms of an empty matrix", "the port did not answer zero");
    sparse_matrix_destroy(emptyHost);
    RENAME(sparse_matrix_destroy)(emptyPort);

    // The trace along three offsets.
    // The offsets the host answers. It reads past the end of its own storage for an offset of 4 and more on
    // a 3x3 and the process ends (measured: offsets -6 to 3 answer, 4 is a SIGBUS), so the two offsets that
    // name no element of the matrix at all are the header's rule below and only the port is asked.
    const sparse_index offsets[5] = {0, 1, -1, 2, -2};
    char name[96];
    for (int k = 0; k < 5; k++) {
        float _Complex hostValue = sparse_matrix_trace_float_complex(host, offsets[k]);
        float _Complex mineValue = RENAME(sparse_matrix_trace_float_complex)(port, offsets[k]);
        snprintf(name, sizeof(name), "the trace at an offset of %lld", (long long)offsets[k]);
        report(same_complex(REAL_OF(mineValue), IMAG_OF(mineValue), REAL_OF(hostValue), IMAG_OF(hostValue), 1e-6,
                            "the trace"),
               name, detail);
        double _Complex hostDValue = sparse_matrix_trace_double_complex(hostD, offsets[k]);
        double _Complex mineDValue = RENAME(sparse_matrix_trace_double_complex)(portD, offsets[k]);
        snprintf(name, sizeof(name), "the trace at an offset of %lld, in the double complex", (long long)offsets[k]);
        report(same_complex(REAL_OF(mineDValue), IMAG_OF(mineDValue), REAL_OF(hostDValue), IMAG_OF(hostDValue), 1e-12,
                            "the trace"),
               name, detail);
    }
    for (int k = 0; k < 2; k++) {
        const sparse_index offset = k == 0 ? 5 : -5;
        float _Complex mineValue = RENAME(sparse_matrix_trace_float_complex)(port, offset);
        snprintf(name, sizeof(name), "the trace at an offset of %lld, naming no element (header)",
                 (long long)offset);
        report(REAL_OF(mineValue) == 0.0 && IMAG_OF(mineValue) == 0.0, name, "the port did not answer a zero pair");
    }
    sparse_matrix_destroy(host);
    RENAME(sparse_matrix_destroy)(port);
    sparse_matrix_destroy(hostD);
    RENAME(sparse_matrix_destroy)(portD);
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    shape_cases();
    insert_cases();
    extract_cases();
    level_one_cases();
    matrix_vector_cases();
    triangular_cases();
    level_three_cases();
    outer_and_sparse_product_cases();
    permutation_cases();
    norm_and_trace_cases();
    printf("%d checks, %d failures\n", checks, failures);
    return failures == 0 ? 0 : 1;
}
