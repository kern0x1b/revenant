#import <Accelerate/Accelerate.h>
#include <complex.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <sys/wait.h>
#include <unistd.h>


#define RENAME(name) charon_host_##name

sparse_matrix_float RENAME(sparse_matrix_create_float)(sparse_dimension, sparse_dimension);
sparse_matrix_double RENAME(sparse_matrix_create_double)(sparse_dimension, sparse_dimension);
sparse_matrix_float RENAME(sparse_matrix_block_create_float)(sparse_dimension, sparse_dimension, sparse_dimension, sparse_dimension);
sparse_matrix_double RENAME(sparse_matrix_block_create_double)(sparse_dimension, sparse_dimension, sparse_dimension, sparse_dimension);
sparse_matrix_float RENAME(sparse_matrix_variable_block_create_float)(sparse_dimension, sparse_dimension, const sparse_dimension *, const sparse_dimension *);
sparse_matrix_double RENAME(sparse_matrix_variable_block_create_double)(sparse_dimension, sparse_dimension, const sparse_dimension *, const sparse_dimension *);
sparse_status RENAME(sparse_commit)(void *);
sparse_status RENAME(sparse_matrix_destroy)(void *);
sparse_status RENAME(sparse_set_matrix_property)(void *, sparse_matrix_property);
long RENAME(sparse_get_matrix_property)(void *, sparse_matrix_property);
sparse_dimension RENAME(sparse_get_matrix_number_of_rows)(void *);
sparse_dimension RENAME(sparse_get_matrix_number_of_columns)(void *);
long RENAME(sparse_get_matrix_nonzero_count)(void *);
long RENAME(sparse_get_matrix_nonzero_count_for_row)(void *, sparse_index);
long RENAME(sparse_get_matrix_nonzero_count_for_column)(void *, sparse_index);
long RENAME(sparse_get_block_dimension_for_row)(void *, sparse_index);
long RENAME(sparse_get_block_dimension_for_col)(void *, sparse_index);
sparse_status RENAME(sparse_insert_entry_float)(sparse_matrix_float, float, sparse_index, sparse_index);
sparse_status RENAME(sparse_insert_entry_double)(sparse_matrix_double, double, sparse_index, sparse_index);
sparse_status RENAME(sparse_insert_entries_float)(sparse_matrix_float, sparse_dimension, const float *, const sparse_index *, const sparse_index *);
sparse_status RENAME(sparse_insert_entries_double)(sparse_matrix_double, sparse_dimension, const double *, const sparse_index *, const sparse_index *);
sparse_status RENAME(sparse_insert_row_float)(sparse_matrix_float, sparse_index, sparse_dimension, const float *, const sparse_index *);
sparse_status RENAME(sparse_insert_row_double)(sparse_matrix_double, sparse_index, sparse_dimension, const double *, const sparse_index *);
sparse_status RENAME(sparse_insert_col_float)(sparse_matrix_float, sparse_index, sparse_dimension, const float *, const sparse_index *);
sparse_status RENAME(sparse_insert_col_double)(sparse_matrix_double, sparse_index, sparse_dimension, const double *, const sparse_index *);
sparse_status RENAME(sparse_insert_block_float)(sparse_matrix_float, const float *, sparse_dimension, sparse_dimension, sparse_index, sparse_index);
sparse_status RENAME(sparse_insert_block_double)(sparse_matrix_double, const double *, sparse_dimension, sparse_dimension, sparse_index, sparse_index);
sparse_status RENAME(sparse_extract_sparse_row_float)(sparse_matrix_float, sparse_index, sparse_index, sparse_index *, sparse_dimension, float *, sparse_index *);
sparse_status RENAME(sparse_extract_sparse_row_double)(sparse_matrix_double, sparse_index, sparse_index, sparse_index *, sparse_dimension, double *, sparse_index *);
sparse_status RENAME(sparse_extract_sparse_column_float)(sparse_matrix_float, sparse_index, sparse_index, sparse_index *, sparse_dimension, float *, sparse_index *);
sparse_status RENAME(sparse_extract_sparse_column_double)(sparse_matrix_double, sparse_index, sparse_index, sparse_index *, sparse_dimension, double *, sparse_index *);
sparse_status RENAME(sparse_extract_block_float)(sparse_matrix_float, sparse_index, sparse_index, sparse_dimension, sparse_dimension, float *);
sparse_status RENAME(sparse_extract_block_double)(sparse_matrix_double, sparse_index, sparse_index, sparse_dimension, sparse_dimension, double *);
float RENAME(sparse_inner_product_dense_float)(sparse_dimension, const float *, const sparse_index *, const float *, sparse_stride);
double RENAME(sparse_inner_product_dense_double)(sparse_dimension, const double *, const sparse_index *, const double *, sparse_stride);
float RENAME(sparse_inner_product_sparse_float)(sparse_dimension, sparse_dimension, const float *, const sparse_index *, const float *, const sparse_index *);
double RENAME(sparse_inner_product_sparse_double)(sparse_dimension, sparse_dimension, const double *, const sparse_index *, const double *, const sparse_index *);
void RENAME(sparse_vector_add_with_scale_dense_float)(sparse_dimension, float, const float *, const sparse_index *, float *, sparse_stride);
void RENAME(sparse_vector_add_with_scale_dense_double)(sparse_dimension, double, const double *, const sparse_index *, double *, sparse_stride);
float RENAME(sparse_vector_norm_float)(sparse_dimension, const float *, const sparse_index *, sparse_norm);
double RENAME(sparse_vector_norm_double)(sparse_dimension, const double *, const sparse_index *, sparse_norm);
long RENAME(sparse_get_vector_nonzero_count_float)(sparse_dimension, const float *, sparse_stride);
long RENAME(sparse_get_vector_nonzero_count_double)(sparse_dimension, const double *, sparse_stride);
long RENAME(sparse_pack_vector_float)(sparse_dimension, sparse_dimension, const float *, sparse_stride, float *, sparse_index *);
long RENAME(sparse_pack_vector_double)(sparse_dimension, sparse_dimension, const double *, sparse_stride, double *, sparse_index *);
void RENAME(sparse_unpack_vector_float)(sparse_dimension, sparse_dimension, bool, const float *, const sparse_index *, float *, sparse_stride);
void RENAME(sparse_unpack_vector_double)(sparse_dimension, sparse_dimension, bool, const double *, const sparse_index *, double *, sparse_stride);
sparse_status RENAME(sparse_matrix_vector_product_dense_float)(enum CBLAS_TRANSPOSE, float, sparse_matrix_float, const float *, sparse_stride, float *, sparse_stride);
sparse_status RENAME(sparse_matrix_vector_product_dense_double)(enum CBLAS_TRANSPOSE, double, sparse_matrix_double, const double *, sparse_stride, double *, sparse_stride);
sparse_status RENAME(sparse_vector_triangular_solve_dense_float)(enum CBLAS_TRANSPOSE, float, sparse_matrix_float, float *, sparse_stride);
sparse_status RENAME(sparse_vector_triangular_solve_dense_double)(enum CBLAS_TRANSPOSE, double, sparse_matrix_double, double *, sparse_stride);
sparse_status RENAME(sparse_matrix_triangular_solve_dense_float)(enum CBLAS_ORDER, enum CBLAS_TRANSPOSE, sparse_dimension, float, sparse_matrix_float, float *, sparse_dimension);
sparse_status RENAME(sparse_matrix_triangular_solve_dense_double)(enum CBLAS_ORDER, enum CBLAS_TRANSPOSE, sparse_dimension, double, sparse_matrix_double, double *, sparse_dimension);
sparse_status RENAME(sparse_outer_product_dense_float)(sparse_dimension, sparse_dimension, sparse_dimension, float, const float *, sparse_stride, const float *, const sparse_index *, sparse_matrix_float *);
sparse_status RENAME(sparse_outer_product_dense_double)(sparse_dimension, sparse_dimension, sparse_dimension, double, const double *, sparse_stride, const double *, const sparse_index *, sparse_matrix_double *);
sparse_status RENAME(sparse_permute_rows_float)(sparse_matrix_float, const sparse_index *);
sparse_status RENAME(sparse_permute_rows_double)(sparse_matrix_double, const sparse_index *);
sparse_status RENAME(sparse_permute_cols_float)(sparse_matrix_float, const sparse_index *);
sparse_status RENAME(sparse_permute_cols_double)(sparse_matrix_double, const sparse_index *);
float RENAME(sparse_elementwise_norm_float)(sparse_matrix_float, sparse_norm);
double RENAME(sparse_elementwise_norm_double)(sparse_matrix_double, sparse_norm);
float RENAME(sparse_operator_norm_float)(sparse_matrix_float, sparse_norm);
double RENAME(sparse_operator_norm_double)(sparse_matrix_double, sparse_norm);
float RENAME(sparse_matrix_trace_float)(sparse_matrix_float, sparse_index);
double RENAME(sparse_matrix_trace_double)(sparse_matrix_double, sparse_index);
sparse_status RENAME(sparse_matrix_product_dense_float)(enum CBLAS_ORDER, enum CBLAS_TRANSPOSE, sparse_dimension, float, sparse_matrix_float, const float *, sparse_dimension, float *, sparse_dimension);
sparse_status RENAME(sparse_matrix_product_dense_double)(enum CBLAS_ORDER, enum CBLAS_TRANSPOSE, sparse_dimension, double, sparse_matrix_double, const double *, sparse_dimension, double *, sparse_dimension);
sparse_status RENAME(sparse_matrix_product_sparse_float)(enum CBLAS_ORDER, enum CBLAS_TRANSPOSE, float, sparse_matrix_float, sparse_matrix_float, float *, sparse_dimension);
sparse_status RENAME(sparse_matrix_product_sparse_double)(enum CBLAS_ORDER, enum CBLAS_TRANSPOSE, double, sparse_matrix_double, sparse_matrix_double, double *, sparse_dimension);

static int failures;
static int checks;
static char detail[512];

static void report(int passed, const char *name, const char *why)
{
    checks++;
    if (passed) {
        printf("ok %s\n", name);
    } else {
        failures++;
        printf("FAIL %s: %s\n", name, why);
    }
}

static int same_double(double mine, double theirs, double tolerance)
{
    if (isnan(mine) && isnan(theirs)) return 1;
    if (isinf(mine) || isinf(theirs)) return mine == theirs;
    double difference = fabs(mine - theirs);
    double scale = fabs(theirs) > 1.0 ? fabs(theirs) : 1.0;
    return difference <= tolerance * scale;
}

static int same_floats(const float *mine, const float *theirs, int count, const char *name)
{
    for (int k = 0; k < count; k++) {
        if (!same_double(mine[k], theirs[k], 1e-6)) {
            snprintf(detail, sizeof detail, "element %d: port %g, host %g", k, mine[k], theirs[k]);
            report(0, name, detail);
            return 0;
        }
    }
    return 1;
}

static int same_doubles(const double *mine, const double *theirs, int count, double tolerance, const char *name)
{
    for (int k = 0; k < count; k++) {
        if (!same_double(mine[k], theirs[k], tolerance)) {
            size_t used = 0;
            used += snprintf(detail + used, sizeof detail - used, "element %d: port %g, host %g |", k, mine[k], theirs[k]);
            for (int j = 0; j < count && used + 16 < sizeof detail; j++) {
                used += snprintf(detail + used, sizeof detail - used, " %g", mine[j]);
            }
            used += snprintf(detail + used, sizeof detail - used, " |");
            for (int j = 0; j < count && used + 16 < sizeof detail; j++) {
                used += snprintf(detail + used, sizeof detail - used, " %g", theirs[j]);
            }
            report(0, name, detail);
            return 0;
        }
    }
    return 1;
}

static int differs(const double *one, const double *other, int count, double tolerance)
{
    for (int k = 0; k < count; k++) {
        if (!same_double(one[k], other[k], tolerance)) return 1;
    }
    return 0;
}

typedef struct Pair {
    void *mine;
    void *theirs;
} Pair;

static Pair pointwise(sparse_dimension M, sparse_dimension N, sparse_dimension count, const void *values,
                      const sparse_index *rows, const sparse_index *columns, int is_double)
{
    Pair pair;
    if (is_double) {
        sparse_matrix_double a = RENAME(sparse_matrix_create_double)(M, N);
        sparse_matrix_double b = sparse_matrix_create_double(M, N);
        double *v = (double *)malloc((size_t)(count ? count : 1) * sizeof(double));
        for (sparse_dimension k = 0; k < count; k++) v[k] = ((const double *)values)[k];
        if (count) RENAME(sparse_insert_entries_double)(a, count, v, rows, columns);
        if (count) sparse_insert_entries_double(b, count, v, rows, columns);
        free(v);
        pair.mine = a;
        pair.theirs = b;
    } else {
        sparse_matrix_float a = RENAME(sparse_matrix_create_float)(M, N);
        sparse_matrix_float b = sparse_matrix_create_float(M, N);
        if (count) sparse_insert_entries_float(b, count, (const float *)values, rows, columns);
        if (count) RENAME(sparse_insert_entries_float)(a, count, (const float *)values, rows, columns);
        pair.mine = a;
        pair.theirs = b;
    }
    return pair;
}

static void readf(void *matrix, int is_double, int mine, sparse_dimension M, sparse_dimension N, double *out)
{
    for (sparse_dimension i = 0; i < M * N; i++) out[i] = 0.0;
    for (sparse_dimension i = 0; i < M; i++) {
        sparse_index c = 0;
        while (c < (sparse_index)N) {
            sparse_index e = 0, j = 0;
            double value = 0.0;
            long got;
            if (is_double) {
                double v = 0.0;
                got = mine ? RENAME(sparse_extract_sparse_row_double)((sparse_matrix_double)matrix, (sparse_index)i, c, &e, 1, &v, &j)
                           : sparse_extract_sparse_row_double((sparse_matrix_double)matrix, (sparse_index)i, c, &e, 1, &v, &j);
                value = v;
            } else {
                float v = 0.0f;
                got = mine ? RENAME(sparse_extract_sparse_row_float)((sparse_matrix_float)matrix, (sparse_index)i, c, &e, 1, &v, &j)
                           : sparse_extract_sparse_row_float((sparse_matrix_float)matrix, (sparse_index)i, c, &e, 1, &v, &j);
                value = v;
            }
            if (got != 1) break;
            if (j >= 0 && j < (sparse_index)N) out[i * N + j] = value;
            if (e <= c) break;
            c = e;
        }
    }
}

static void compare_matrix(const char *name, Pair pair, sparse_dimension M, sparse_dimension N, int is_double)
{
    int count = (int)(M * N);
    double *mine = (double *)calloc((size_t)(count ? count : 1), sizeof(double));
    double *theirs = (double *)calloc((size_t)(count ? count : 1), sizeof(double));
    readf(pair.mine, is_double, 1, M, N, mine);
    readf(pair.theirs, is_double, 0, M, N, theirs);
    if (same_doubles(mine, theirs, count, 1e-6, name)) report(1, name, "");
    else {
        snprintf(detail, sizeof detail, "port");
        for (int k = 0; k < count; k++) snprintf(detail + strlen(detail), sizeof detail - strlen(detail), " %g", mine[k]);
        snprintf(detail + strlen(detail), sizeof detail - strlen(detail), ", host");
        for (int k = 0; k < count; k++) snprintf(detail + strlen(detail), sizeof detail - strlen(detail), " %g", theirs[k]);
    }
    free(mine);
    free(theirs);
}

static long count_of(void *matrix, int is_double)
{
    return is_double ? RENAME(sparse_get_matrix_nonzero_count)((sparse_matrix_double)matrix)
                     : RENAME(sparse_get_matrix_nonzero_count)((sparse_matrix_float)matrix);
}

static void creation(void)
{
    struct { sparse_dimension M, N, k, l; } shapes[] = {{4, 3, 0, 0}, {0, 5, 0, 0}, {5, 0, 0, 0}, {0, 0, 0, 0},
                                                        {1, 1, 0, 0}, {2, 2, 2, 2}, {2, 2, 1, 3}, {3, 2, 0, 2}};
    for (size_t s = 0; s < sizeof(shapes) / sizeof(shapes[0]); s++) {
        char name[128];
        sparse_matrix_float a = RENAME(sparse_matrix_block_create_float)(shapes[s].M, shapes[s].N, shapes[s].k, shapes[s].l);
        sparse_matrix_float b = sparse_matrix_block_create_float(shapes[s].M, shapes[s].N, shapes[s].k, shapes[s].l);
        snprintf(name, sizeof name, "block create %llu %llu %llu %llu: rows %llu vs %llu, cols %llu vs %llu, nz %ld vs %ld",
                 (unsigned long long)shapes[s].M, (unsigned long long)shapes[s].N, (unsigned long long)shapes[s].k,
                 (unsigned long long)shapes[s].l, (unsigned long long)RENAME(sparse_get_matrix_number_of_rows)(a),
                 (unsigned long long)sparse_get_matrix_number_of_rows(b),
                 (unsigned long long)RENAME(sparse_get_matrix_number_of_columns)(a),
                 (unsigned long long)sparse_get_matrix_number_of_columns(b), RENAME(sparse_get_matrix_nonzero_count)(a),
                 sparse_get_matrix_nonzero_count(b));
        int passed = RENAME(sparse_get_matrix_number_of_rows)(a) == sparse_get_matrix_number_of_rows(b) &&
                     RENAME(sparse_get_matrix_number_of_columns)(a) == sparse_get_matrix_number_of_columns(b) &&
                     RENAME(sparse_get_matrix_nonzero_count)(a) == sparse_get_matrix_nonzero_count(b);
        report(passed, "block create", name);
        for (sparse_index i = 0; i < 8; i++) {
            int passed = RENAME(sparse_get_block_dimension_for_row)(a, i) == sparse_get_block_dimension_for_row(b, i) &&
                         RENAME(sparse_get_block_dimension_for_col)(a, i) == sparse_get_block_dimension_for_col(b, i);
            if (!passed) {
                snprintf(name, sizeof name, "block create: block dimension at %lld: port row %ld col %ld, host row %ld col %ld",
                         (long long)i, RENAME(sparse_get_block_dimension_for_row)(a, i),
                         RENAME(sparse_get_block_dimension_for_col)(a, i), sparse_get_block_dimension_for_row(b, i),
                         sparse_get_block_dimension_for_col(b, i));
                report(0, "block dimensions", name);
                break;
            }
        }
        if (passed) report(1, "block dimensions", "");
        RENAME(sparse_matrix_destroy)(a);
        sparse_matrix_destroy(b);
    }
    {
        sparse_dimension K[3] = {2, 1, 3}, L[3] = {1, 2, 1};
        sparse_matrix_float a = RENAME(sparse_matrix_variable_block_create_float)(3, 3, K, L);
        sparse_matrix_float b = sparse_matrix_variable_block_create_float(3, 3, K, L);
        int passed = RENAME(sparse_get_matrix_number_of_rows)(a) == sparse_get_matrix_number_of_rows(b) &&
                     RENAME(sparse_get_matrix_number_of_columns)(a) == sparse_get_matrix_number_of_columns(b);
        for (sparse_index i = 0; passed && i < 8; i++) {
            passed = RENAME(sparse_get_block_dimension_for_row)(a, i) == sparse_get_block_dimension_for_row(b, i) &&
                     RENAME(sparse_get_block_dimension_for_col)(a, i) == sparse_get_block_dimension_for_col(b, i);
        }
        report(passed, "variable block create", "rows, columns and every block dimension");
        RENAME(sparse_matrix_destroy)(a);
        sparse_matrix_destroy(b);
        sparse_dimension zero[3] = {2, 0, 3};
        sparse_matrix_float c = RENAME(sparse_matrix_variable_block_create_float)(3, 3, zero, L);
        sparse_matrix_float d = sparse_matrix_variable_block_create_float(3, 3, zero, L);
        report(c != NULL && d != NULL && RENAME(sparse_get_matrix_number_of_rows)(c) == sparse_get_matrix_number_of_rows(d),
               "variable block with a zero", "both answer a matrix and the same row count");
        if (c) RENAME(sparse_matrix_destroy)(c);
        if (d) sparse_matrix_destroy(d);
        sparse_matrix_double e = RENAME(sparse_matrix_variable_block_create_double)(3, 3, K, L);
        sparse_matrix_double f = sparse_matrix_variable_block_create_double(3, 3, K, L);
        int both = RENAME(sparse_get_matrix_number_of_rows)(e) == sparse_get_matrix_number_of_rows(f) &&
                   RENAME(sparse_get_matrix_number_of_columns)(e) == sparse_get_matrix_number_of_columns(f);
        for (sparse_index i = 0; both && i < 8; i++) {
            both = RENAME(sparse_get_block_dimension_for_row)(e, i) == sparse_get_block_dimension_for_row(f, i) &&
                   RENAME(sparse_get_block_dimension_for_col)(e, i) == sparse_get_block_dimension_for_col(f, i);
        }
        report(both, "a double variable block matrix", "rows, columns and every block dimension");
        if (e) RENAME(sparse_matrix_destroy)(e);
        if (f) sparse_matrix_destroy(f);
    }
    {
        sparse_matrix_float a = RENAME(sparse_matrix_create_float)(3, 3);
        sparse_matrix_float b = sparse_matrix_create_float(3, 3);
        int passed = 1;
        for (sparse_index i = 0; i < 4; i++) {
            passed = passed && RENAME(sparse_get_block_dimension_for_row)(a, i) == sparse_get_block_dimension_for_row(b, i) &&
                     RENAME(sparse_get_block_dimension_for_col)(a, i) == sparse_get_block_dimension_for_col(b, i);
        }
        report(passed, "point-wise block dimensions", "every one of them zero on both sides");
        report(RENAME(sparse_get_block_dimension_for_row)(NULL, 0) == 0 &&
                   RENAME(sparse_get_matrix_nonzero_count)(NULL) == 0 &&
                   RENAME(sparse_get_matrix_number_of_rows)(NULL) == 0 &&
                   RENAME(sparse_get_matrix_number_of_columns)(NULL) == 0 &&
                   RENAME(sparse_get_matrix_property)(NULL, SPARSE_UPPER_TRIANGULAR) == 0 &&
                   RENAME(sparse_commit)(NULL) == SPARSE_ILLEGAL_PARAMETER &&
                   RENAME(sparse_matrix_destroy)(NULL) == SPARSE_ILLEGAL_PARAMETER,
               "a NULL matrix", "the counts zero, the commit and the destroy SPARSE_ILLEGAL_PARAMETER");
        RENAME(sparse_matrix_destroy)(a);
        sparse_matrix_destroy(b);
    }
}

static void properties(void)
{
    sparse_matrix_property names[4] = {SPARSE_UPPER_TRIANGULAR, SPARSE_LOWER_TRIANGULAR, SPARSE_UPPER_SYMMETRIC,
                                       SPARSE_LOWER_SYMMETRIC};
    for (int set = 0; set < 16; set++) {
        sparse_matrix_float a = RENAME(sparse_matrix_create_float)(3, 3);
        sparse_matrix_float b = sparse_matrix_create_float(3, 3);
        int passed = 1;
        for (int k = 0; k < 4; k++) {
            if (!(set & (1 << k))) continue;
            sparse_matrix_property p = names[k];
            sparse_status ma = RENAME(sparse_set_matrix_property)(a, p);
            sparse_status mb = sparse_set_matrix_property(b, p);
            if (ma != mb) {
                snprintf(detail, sizeof detail, "set %d: property %d gives %d on the port and %d on the host", set,
                         (int)p, ma, mb);
                passed = 0;
            }
        }
        sparse_matrix_property outside[3] = {0, 3, 99};
        for (int k = 0; k < 3 && passed; k++) {
            sparse_matrix_property p = outside[k];
            sparse_status ma = RENAME(sparse_set_matrix_property)(a, p);
            sparse_status mb = sparse_set_matrix_property(b, p);
            if (ma != mb) {
                snprintf(detail, sizeof detail, "set %d: the name %d gives %d on the port and %d on the host", set, (int)p, ma, mb);
                passed = 0;
            }
        }
        sparse_matrix_property absent[3] = {0, 3, 99};
        for (int k = 0; k < 3 && passed; k++) {
            sparse_matrix_property p = absent[k];
            long ma = RENAME(sparse_get_matrix_property)(a, p), mb = sparse_get_matrix_property(b, p);
            if (ma != mb) {
                snprintf(detail, sizeof detail, "set %d: reading %d gives %ld on the port and %ld on the host", set, (int)p, ma, mb);
                passed = 0;
            }
        }
        for (int k = 0; k < 4 && passed; k++) {
            sparse_matrix_property p = names[k];
            long ma = RENAME(sparse_get_matrix_property)(a, p), mb = sparse_get_matrix_property(b, p);
            if (ma != mb) {
                snprintf(detail, sizeof detail, "set %d: reading %d gives %ld on the port and %ld on the host", set, (int)p, ma, mb);
                passed = 0;
            }
        }
        if (!passed && !detail[0]) snprintf(detail, sizeof detail, "set %d, no single read or status named it", set);
        report(passed, "a property set", detail);
        sparse_status afterA = RENAME(sparse_insert_entry_float)(a, 1, 0, 0);
        sparse_status afterB = sparse_insert_entry_float(b, 1, 0, 0);
        report(afterA == afterB && RENAME(sparse_set_matrix_property)(a, SPARSE_LOWER_SYMMETRIC) ==
                                  sparse_set_matrix_property(b, SPARSE_LOWER_SYMMETRIC),
               "a property after an insertion", "the same status on both sides");
        RENAME(sparse_matrix_destroy)(a);
        sparse_matrix_destroy(b);
    }
    for (int p = -9; p < 0; p++) {
        sparse_matrix_float a = RENAME(sparse_matrix_create_float)(2, 2);
        sparse_matrix_float b = sparse_matrix_create_float(2, 2);
        report(RENAME(sparse_set_matrix_property)(a, (sparse_matrix_property)p) ==
                       sparse_set_matrix_property(b, (sparse_matrix_property)p) &&
                   RENAME(sparse_set_matrix_property)(NULL, (sparse_matrix_property)p) ==
                       sparse_set_matrix_property(NULL, (sparse_matrix_property)p),
               "a property name below zero", "SPARSE_ILLEGAL_PARAMETER on both sides");
        RENAME(sparse_matrix_destroy)(a);
        sparse_matrix_destroy(b);
    }
}

static void insertion(void)
{
    {
        sparse_matrix_float a = RENAME(sparse_matrix_create_float)(4, 4);
        sparse_matrix_float b = sparse_matrix_create_float(4, 4);
        struct { float v; sparse_index i, j; } points[] = {{0.0f, 1, 1}, {2.0f, 1, 1}, {3.0f, 1, 1}, {5.0f, 0, 3}, {-1.5f, 3, 0}};
        int passed = 1;
        for (size_t k = 0; k < sizeof(points) / sizeof(points[0]); k++) {
            passed = passed && RENAME(sparse_insert_entry_float)(a, points[k].v, points[k].i, points[k].j) ==
                                  sparse_insert_entry_float(b, points[k].v, points[k].i, points[k].j) &&
                     RENAME(sparse_get_matrix_nonzero_count)(a) == sparse_get_matrix_nonzero_count(b);
        }
        report(passed, "insert an entry five times over", "the statuses and the count on both sides");
        compare_matrix("insert an entry five times over, the matrix", (Pair){a, b}, 4, 4, 0);
        for (sparse_index i = 0; i < 4; i++) {
            passed = RENAME(sparse_get_matrix_nonzero_count_for_row)(a, i) == sparse_get_matrix_nonzero_count_for_row(b, i) &&
                     RENAME(sparse_get_matrix_nonzero_count_for_column)(a, i) ==
                         sparse_get_matrix_nonzero_count_for_column(b, i);
        }
        passed = passed && RENAME(sparse_get_matrix_nonzero_count_for_row)(a, 7) ==
                               sparse_get_matrix_nonzero_count_for_row(b, 7) &&
                 RENAME(sparse_get_matrix_nonzero_count_for_row)(a, -1) ==
                     sparse_get_matrix_nonzero_count_for_row(b, -1);
        report(passed, "the counts per row and column", "including an index outside the matrix");
        report(RENAME(sparse_commit)(a) == sparse_commit(b) && RENAME(sparse_get_matrix_nonzero_count)(a) ==
                   sparse_get_matrix_nonzero_count(b),
               "a commit", "the same status and the same count");
        compare_matrix("a commit, the matrix", (Pair){a, b}, 4, 4, 0);
        RENAME(sparse_matrix_destroy)(a);
        sparse_matrix_destroy(b);
    }
    {
        float values[3] = {1, 2, 3};
        sparse_index rows[3] = {0, 2, 1}, columns[3] = {3, 0, 2};
        sparse_matrix_float a = RENAME(sparse_matrix_create_float)(4, 4);
        sparse_matrix_float b = sparse_matrix_create_float(4, 4);
        static const float column1[2] = {5, 6}, column2[1] = {9}, rowValues[2] = {7, 8};
        static const sparse_index rowsOfColumn1[2] = {0, 2}, rowOfColumn2[1] = {3};
        int passed = 1;
        passed = passed && RENAME(sparse_insert_entries_float)(a, 3, values, rows, columns) ==
                                sparse_insert_entries_float(b, 3, values, rows, columns);
        passed = passed && RENAME(sparse_insert_entries_float)(a, 0, values, rows, columns) ==
                                sparse_insert_entries_float(b, 0, values, rows, columns);
        passed = passed && RENAME(sparse_insert_col_float)(a, 0, 2, column1, rowsOfColumn1) ==
                                sparse_insert_col_float(b, 0, 2, column1, rowsOfColumn1);
        passed = passed && RENAME(sparse_insert_col_float)(a, 0, 1, column2, rowOfColumn2) ==
                                sparse_insert_col_float(b, 0, 1, column2, rowOfColumn2);
        report(passed, "the batch insertions", "the statuses on both sides");
        report(RENAME(sparse_get_matrix_nonzero_count)(a) == sparse_get_matrix_nonzero_count(b), "the batch count",
               "the same nonzero count");
        RENAME(sparse_matrix_destroy)(a);
        sparse_matrix_destroy(b);
        {
            sparse_matrix_float c = RENAME(sparse_matrix_create_float)(4, 4);
            sparse_matrix_float d = sparse_matrix_create_float(4, 4);
            passed = RENAME(sparse_insert_row_float)(c, 1, 2, (float[]){1, 2}, (sparse_index[]){0, 1}) ==
                     sparse_insert_row_float(d, 1, 2, (float[]){1, 2}, (sparse_index[]){0, 1});
            passed = passed && RENAME(sparse_insert_row_float)(c, 1, 2, (float[]){3, 4}, (sparse_index[]){1, 3}) ==
                                    sparse_insert_row_float(d, 1, 2, (float[]){3, 4}, (sparse_index[]){1, 3});
            report(passed, "two insertions into one row", "the same status");
            compare_matrix("two insertions into one row, the matrix", (Pair){c, d}, 4, 4, 0);
            RENAME(sparse_matrix_destroy)(c);
            sparse_matrix_destroy(d);
        }
        {
            sparse_matrix_float c = RENAME(sparse_matrix_create_float)(4, 4);
            sparse_matrix_float d = sparse_matrix_create_float(4, 4);
            RENAME(sparse_insert_col_float)(c, 1, 2, column1, rowsOfColumn1);
            sparse_insert_col_float(d, 1, 2, column1, rowsOfColumn1);
            RENAME(sparse_insert_entries_float)(c, 1, rowValues, (sparse_index[]){1}, (sparse_index[]){1});
            sparse_insert_entries_float(d, 1, rowValues, (sparse_index[]){1}, (sparse_index[]){1});
            report(RENAME(sparse_get_matrix_nonzero_count)(c) == sparse_get_matrix_nonzero_count(d),
                   "a batch over a column", "the same nonzero count");
            compare_matrix("a batch over a column, the matrix", (Pair){c, d}, 4, 4, 0);
            RENAME(sparse_matrix_destroy)(c);
            sparse_matrix_destroy(d);
        }
    }
    {
        sparse_matrix_float point = RENAME(sparse_matrix_create_float)(4, 4);
        sparse_matrix_float hostpoint = sparse_matrix_create_float(4, 4);
        sparse_matrix_float block = RENAME(sparse_matrix_block_create_float)(2, 2, 2, 2);
        sparse_matrix_float hostblock = sparse_matrix_block_create_float(2, 2, 2, 2);
        report(RENAME(sparse_insert_block_float)(point, (float[]){1, 2, 3, 4}, 2, 1, 0, 0) ==
                   sparse_insert_block_float(hostpoint, (float[]){1, 2, 3, 4}, 2, 1, 0, 0) &&
                   RENAME(sparse_insert_entry_float)(block, 1, 0, 0) == sparse_insert_entry_float(hostblock, 1, 0, 0) &&
                   RENAME(sparse_get_matrix_nonzero_count)(block) == sparse_get_matrix_nonzero_count(hostblock),
               "an entry of the wrong kind", "SPARSE_ILLEGAL_PARAMETER on both sides and nothing stored");
        RENAME(sparse_matrix_destroy)(point);
        sparse_matrix_destroy(hostpoint);
        RENAME(sparse_matrix_destroy)(block);
        sparse_matrix_destroy(hostblock);
    }
    {
        sparse_matrix_float a = RENAME(sparse_matrix_block_create_float)(2, 2, 2, 3);
        sparse_matrix_float b = sparse_matrix_block_create_float(2, 2, 2, 3);
        float block[6] = {1, 2, 3, 4, 5, 6};
        int passed = RENAME(sparse_insert_block_float)(a, block, 3, 1, 0, 0) == sparse_insert_block_float(b, block, 3, 1, 0, 0) &&
                     RENAME(sparse_get_matrix_nonzero_count)(a) == sparse_get_matrix_nonzero_count(b) &&
                     RENAME(sparse_get_matrix_number_of_rows)(a) == sparse_get_matrix_number_of_rows(b) &&
                     RENAME(sparse_get_matrix_number_of_columns)(a) == sparse_get_matrix_number_of_columns(b);
        for (sparse_index i = 0; passed && i < 4; i++) {
            passed = RENAME(sparse_get_matrix_nonzero_count_for_row)(a, i) == sparse_get_matrix_nonzero_count_for_row(b, i) &&
                     RENAME(sparse_get_matrix_nonzero_count_for_column)(a, i) ==
                         sparse_get_matrix_nonzero_count_for_column(b, i);
        }
        passed = passed && RENAME(sparse_insert_block_float)(a, block, 3, 1, 5, 0) ==
                             sparse_insert_block_float(b, block, 3, 1, 5, 0);
        report(passed, "a block entry", "the status, the counts and an index outside the matrix");
        float mine[8] = {9, 9, 9, 9, 9, 9, 9, 9}, theirs[8] = {9, 9, 9, 9, 9, 9, 9, 9};
        RENAME(sparse_extract_block_float)(a, 0, 0, 3, 1, mine);
        sparse_extract_block_float(b, 0, 0, 3, 1, theirs);
        report(same_floats(mine, theirs, 8, "the block read back, row stride 3"),
               "the block read back, row stride 3", "every element, including the two past the block");
        memset(mine, 9, sizeof(mine));
        memset(theirs, 9, sizeof(theirs));
        RENAME(sparse_extract_block_float)(a, 1, 1, 3, 1, mine);
        sparse_extract_block_float(b, 1, 1, 3, 1, theirs);
        report(same_floats(mine, theirs, 8, "an absent block"), "an absent block", "zeros on both sides");
        memset(mine, 9, sizeof(mine));
        memset(theirs, 9, sizeof(theirs));
        RENAME(sparse_extract_block_float)(a, 0, 0, 1, 3, mine);
        sparse_extract_block_float(b, 0, 0, 1, 3, theirs);
        report(same_floats(mine, theirs, 8, "the block read back, row stride 1"),
               "the block read back, row stride 1", "every element, including the two gaps the strides leave");
        RENAME(sparse_matrix_destroy)(a);
        sparse_matrix_destroy(b);
    }
    {
        sparse_dimension K[2] = {2, 1}, L[2] = {2, 1};
        sparse_matrix_float a = RENAME(sparse_matrix_variable_block_create_float)(2, 2, K, L);
        sparse_matrix_float b = sparse_matrix_variable_block_create_float(2, 2, K, L);
        RENAME(sparse_insert_block_float)(a, (float[]){1, 2, 3, 4}, 2, 1, 0, 0);
        sparse_insert_block_float(b, (float[]){1, 2, 3, 4}, 2, 1, 0, 0);
        RENAME(sparse_insert_block_float)(a, (float[]){9}, 1, 1, 1, 1);
        sparse_insert_block_float(b, (float[]){9}, 1, 1, 1, 1);
        float mine[4] = {0}, theirs[4] = {0};
        RENAME(sparse_extract_block_float)(a, 0, 0, 2, 1, mine);
        sparse_extract_block_float(b, 0, 0, 2, 1, theirs);
        report(RENAME(sparse_get_matrix_nonzero_count)(a) == sparse_get_matrix_nonzero_count(b) &&
                   same_floats(mine, theirs, 4, "a variable block read back"),
               "a variable block", "the same count and every element");
        RENAME(sparse_matrix_destroy)(a);
        sparse_matrix_destroy(b);
    }
}

static void extraction(void)
{
    float values[5] = {1, 2, 3, 4, 5};
    sparse_index rows[5] = {0, 0, 0, 1, 3}, columns[5] = {1, 2, 3, 0, 2};
    sparse_matrix_float a = RENAME(sparse_matrix_create_float)(4, 4);
    sparse_matrix_float b = sparse_matrix_create_float(4, 4);
    RENAME(sparse_insert_entries_float)(a, 5, values, rows, columns);
    sparse_insert_entries_float(b, 5, values, rows, columns);
    for (sparse_index row = 0; row < 4; row++) {
        for (sparse_index start = 0; start < 4; start++) {
            for (int count = 0; count < 4; count += 3) {
                float mine[4] = {9, 9, 9, 9}, theirs[4] = {9, 9, 9, 9};
                sparse_index mineIndex[4] = {9, 9, 9, 9}, theirsIndex[4] = {9, 9, 9, 9};
                sparse_index mineEnd = 0, theirsEnd = 0;
                long got = RENAME(sparse_extract_sparse_row_float)(a, row, start, &mineEnd, count, mine, mineIndex);
                long want = sparse_extract_sparse_row_float(b, row, start, &theirsEnd, count, theirs, theirsIndex);
                char name[128];
                snprintf(name, sizeof name, "row %lld from %lld, %d values: %ld vs %ld, end %lld vs %lld", (long long)row,
                         (long long)start, count, got, want, (long long)mineEnd, (long long)theirsEnd);
                int passed = got == want && mineEnd == theirsEnd;
                for (int k = 0; passed && k < 4; k++) {
                    passed = mineIndex[k] == theirsIndex[k] && same_double(mine[k], theirs[k], 1e-6);
                }
                report(passed, "a row extracted", name);
            }
        }
    }
    {
        float mine[1] = {9}, theirs[1] = {9};
        sparse_index mi[1] = {9}, ti[1] = {9};
        sparse_index me = 0, te = 0;
        report(RENAME(sparse_extract_sparse_row_float)(a, 0, 4, &me, 1, mine, mi) ==
                       sparse_extract_sparse_row_float(b, 0, 4, &te, 1, theirs, ti) &&
                   RENAME(sparse_extract_sparse_row_float)(a, 0, 5, &me, 1, mine, mi) ==
                       sparse_extract_sparse_row_float(b, 0, 5, &te, 1, theirs, ti) &&
                   RENAME(sparse_extract_sparse_row_float)(a, 0, -1, &me, 1, mine, mi) ==
                       sparse_extract_sparse_row_float(b, 0, -1, &te, 1, theirs, ti) &&
                   RENAME(sparse_extract_sparse_row_float)(a, 9, 0, &me, 1, mine, mi) ==
                       sparse_extract_sparse_row_float(b, 9, 0, &te, 1, theirs, ti),
               "a row extracted outside the matrix", "the same status on both sides");
    }
    for (sparse_index column = 0; column < 4; column++) {
        for (sparse_index start = 0; start < 4; start++) {
            float mine[4] = {9, 9, 9, 9}, theirs[4] = {9, 9, 9, 9};
            sparse_index mi[4] = {9, 9, 9, 9}, ti[4] = {9, 9, 9, 9};
            sparse_index me = 0, te = 0;
            long got = RENAME(sparse_extract_sparse_column_float)(a, column, start, &me, 4, mine, mi);
            long want = sparse_extract_sparse_column_float(b, column, start, &te, 4, theirs, ti);
            int passed = got == want && me == te;
            for (int k = 0; passed && k < 4; k++) passed = mi[k] == ti[k] && same_double(mine[k], theirs[k], 1e-6);
            snprintf(detail, sizeof detail, "column %lld from %lld: %ld vs %ld, end %lld vs %lld", (long long)column,
                     (long long)start, got, want, (long long)me, (long long)te);
            report(passed, "a column extracted", detail);
        }
    }
    RENAME(sparse_matrix_destroy)(a);
    sparse_matrix_destroy(b);
}

static void vectors(void)
{
    float x[4] = {1, 0, 3, 4};
    sparse_index ix[4] = {0, 2, 3, 3};
    for (sparse_dimension nz = 0; nz <= 4; nz++) {
        for (sparse_stride stride = 1; stride <= 2; stride++) {
            float y[9] = {10, 20, 30, 40, 50, 60, 70, 80, 90};
            float mine = RENAME(sparse_inner_product_dense_float)(nz, x, ix, y, stride);
            float theirs = sparse_inner_product_dense_float(nz, x, ix, y, stride);
            report(same_double(mine, theirs, 1e-6), "an inner product with a dense vector",
                   "the same value to the precision of the type");
        }
    }
    {
        float y[6] = {10, 20, 30, 40, 50, 60};
        float mine = RENAME(sparse_inner_product_dense_float)(3, x, ix, y + 5, -1);
        float theirs = sparse_inner_product_dense_float(3, x, ix, y + 5, -1);
        report(same_double(mine, theirs, 1e-6), "an inner product, negative stride",
               "the pointer at the last element, as the header says");
    }
    {
        float y[2] = {4, 2};
        sparse_index iy[2] = {1, 3};
        struct { sparse_dimension nzx, nzy; } cases[] = {{3, 2}, {3, 0}, {0, 2}, {3, 1}, {2, 2}};
        for (size_t k = 0; k < sizeof(cases) / sizeof(cases[0]); k++) {
            float mine = RENAME(sparse_inner_product_sparse_float)(cases[k].nzx, cases[k].nzy, x, ix, y, iy);
            float theirs = sparse_inner_product_sparse_float(cases[k].nzx, cases[k].nzy, x, ix, y, iy);
            report(same_double(mine, theirs, 1e-6), "an inner product of two sparse vectors", "the same value");
        }
    }
    {
        for (sparse_dimension nz = 0; nz <= 3; nz++) {
            for (int alpha = 0; alpha <= 2; alpha++) {
                float y1[8] = {10, 20, 30, 40, 50, 60, 70, 80}, y2[8] = {10, 20, 30, 40, 50, 60, 70, 80};
                RENAME(sparse_vector_add_with_scale_dense_float)(nz, (float)alpha, x, ix, y1, 1);
                sparse_vector_add_with_scale_dense_float(nz, (float)alpha, x, ix, y2, 1);
                report(same_floats(y1, y2, 8, "a scaled addition"), "a scaled addition", "every element");
            }
        }
        float y1[8] = {10, 20, 30, 40, 50, 60, 70, 80}, y2[8] = {10, 20, 30, 40, 50, 60, 70, 80};
        RENAME(sparse_vector_add_with_scale_dense_float)(3, 1.0f, x, ix, y1, 2);
        sparse_vector_add_with_scale_dense_float(3, 1.0f, x, ix, y2, 2);
        report(same_floats(y1, y2, 8, "a scaled addition, stride 2"), "a scaled addition, stride 2", "every element");
        float y3[6] = {10, 20, 30, 40, 50, 60}, y4[6] = {10, 20, 30, 40, 50, 60};
        RENAME(sparse_vector_add_with_scale_dense_float)(3, 1.0f, x, ix, y3 + 5, -1);
        sparse_vector_add_with_scale_dense_float(3, 1.0f, x, ix, y4 + 5, -1);
        report(same_floats(y3, y4, 6, "a scaled addition, negative stride"),
               "a scaled addition, negative stride", "the pointer at the last element");
    }
    {
        sparse_norm norms[6] = {SPARSE_NORM_ONE, SPARSE_NORM_TWO, SPARSE_NORM_INF, SPARSE_NORM_R1, (sparse_norm)0,
                                (sparse_norm)-1};
        float v[3] = {-1, -2, 3};
        for (sparse_dimension nz = 0; nz <= 3; nz++) {
            for (int k = 0; k < 6; k++) {
                float mine = RENAME(sparse_vector_norm_float)(nz, v, ix, norms[k]);
                float theirs = sparse_vector_norm_float(nz, v, ix, norms[k]);
                report(same_double(mine, theirs, 1e-6), "a vector norm", "the same value");
            }
        }
    }
    {
        float v[6] = {0, 2, 0, 4, 5, 0};
        for (sparse_stride stride = 1; stride <= 2; stride++) {
            float buffer[12] = {0, 2, 0, 4, 5, 0, 0, 0, 0, 0, 0, 0};
            report(RENAME(sparse_get_vector_nonzero_count_float)(6, buffer, stride) ==
                       sparse_get_vector_nonzero_count_float(6, buffer, stride),
                   "a nonzero count", "the same count, over a buffer of N * stride elements");
        }
        for (sparse_dimension nz = 0; nz <= 5; nz++) {
            float mine[5], theirs[5];
            sparse_index mi[5], ti[5];
            memset(mine, 9, sizeof(mine));
            memset(theirs, 9, sizeof(theirs));
            long got = RENAME(sparse_pack_vector_float)(6, nz, v, 1, mine, mi);
            long want = sparse_pack_vector_float(6, nz, v, 1, theirs, ti);
            int passed = got == want;
            for (int k = 0; passed && k < 5; k++) {
                if (mi[k] != ti[k] || !same_double(mine[k], theirs[k], 1e-6)) {
                    snprintf(detail, sizeof detail, "entry %d: port (%lld, %g), host (%lld, %g), count %ld vs %ld", k,
                             (long long)mi[k], mine[k], (long long)ti[k], theirs[k], got, want);
                    break;
                }
            }
            report(passed, "a packed vector", "the count and every value and index");
        }
        {
            float mine[6] = {1, 1, 1, 1, 1, 1}, theirs[6] = {1, 1, 1, 1, 1, 1};
            RENAME(sparse_unpack_vector_float)(6, 2, false, (float[]){7, 8}, (sparse_index[]){1, 4}, mine, 1);
            sparse_unpack_vector_float(6, 2, false, (float[]){7, 8}, (sparse_index[]){1, 4}, theirs, 1);
            report(same_floats(mine, theirs, 6, "an unpacked vector, zero false"),
                   "an unpacked vector, zero false", "every element");
            memset(mine, 1, sizeof(mine));
            memset(theirs, 1, sizeof(theirs));
            RENAME(sparse_unpack_vector_float)(6, 2, true, (float[]){7, 8}, (sparse_index[]){1, 4}, mine, 1);
            sparse_unpack_vector_float(6, 2, true, (float[]){7, 8}, (sparse_index[]){1, 4}, theirs, 1);
            report(same_floats(mine, theirs, 6, "an unpacked vector, zero true"),
                   "an unpacked vector, zero true", "every element");
            memset(mine, 1, sizeof(mine));
            memset(theirs, 1, sizeof(theirs));
            RENAME(sparse_unpack_vector_float)(6, 0, true, (float[]){7, 8}, (sparse_index[]){1, 4}, mine, 1);
            sparse_unpack_vector_float(6, 0, true, (float[]){7, 8}, (sparse_index[]){1, 4}, theirs, 1);
            report(same_floats(mine, theirs, 6, "an unpacked vector with nothing to write"),
                   "an unpacked vector with nothing to write", "every element");
            memset(mine, 1, sizeof(mine));
            memset(theirs, 1, sizeof(theirs));
            RENAME(sparse_unpack_vector_float)(6, 2, true, (float[]){7, 8}, (sparse_index[]){1, 40}, mine, 1);
            sparse_unpack_vector_float(6, 2, true, (float[]){7, 8}, (sparse_index[]){1, 40}, theirs, 1);
            report(same_floats(mine, theirs, 6, "an unpacked vector with an index past N"),
                   "an unpacked vector with an index past N", "every element");
            memset(mine, 1, sizeof(mine));
            memset(theirs, 1, sizeof(theirs));
            RENAME(sparse_unpack_vector_float)(6, 2, true, (float[]){7, 8}, (sparse_index[]){1, 1}, mine, 1);
            sparse_unpack_vector_float(6, 2, true, (float[]){7, 8}, (sparse_index[]){1, 1}, theirs, 1);
            report(same_floats(mine, theirs, 6, "an unpacked vector with a repeated index"),
                   "an unpacked vector with a repeated index", "every element");
        }
    }
    {
        double v[2] = {3, 4};
        sparse_index ix2[2] = {0, 1};
        double y1[2] = {1, 1}, y2[2] = {1, 1};
        RENAME(sparse_inner_product_dense_double)(2, v, ix2, (double[]){1, 2}, 1);
        sparse_inner_product_dense_double(2, v, ix2, (double[]){1, 2}, 1);
        RENAME(sparse_vector_add_with_scale_dense_double)(2, 3.0, v, ix2, y1, 1);
        sparse_vector_add_with_scale_dense_double(2, 3.0, v, ix2, y2, 1);
        report(same_double(RENAME(sparse_vector_norm_double)(2, v, ix2, SPARSE_NORM_TWO),
                           sparse_vector_norm_double(2, v, ix2, SPARSE_NORM_TWO), 1e-12) &&
                   same_doubles(y1, y2, 2, 1e-12, "a double scaled addition"),
               "the double vector forms", "the norm and the scaled addition");
    }
}

static sparse_matrix_float host_lower(void)
{
    sparse_matrix_float L = sparse_matrix_create_float(3, 3);
    sparse_set_matrix_property(L, SPARSE_LOWER_TRIANGULAR);
    sparse_insert_entry_float(L, 2, 0, 0);
    sparse_insert_entry_float(L, 1, 1, 0);
    sparse_insert_entry_float(L, 3, 1, 1);
    sparse_insert_entry_float(L, 4, 2, 2);
    return L;
}

static sparse_matrix_float port_lower(void)
{
    sparse_matrix_float L = RENAME(sparse_matrix_create_float)(3, 3);
    RENAME(sparse_set_matrix_property)(L, SPARSE_LOWER_TRIANGULAR);
    RENAME(sparse_insert_entry_float)(L, 2, 0, 0);
    RENAME(sparse_insert_entry_float)(L, 1, 1, 0);
    RENAME(sparse_insert_entry_float)(L, 3, 1, 1);
    RENAME(sparse_insert_entry_float)(L, 4, 2, 2);
    return L;
}

static sparse_matrix_float host_upper(void)
{
    sparse_matrix_float U = sparse_matrix_create_float(3, 3);
    sparse_set_matrix_property(U, SPARSE_UPPER_TRIANGULAR);
    sparse_insert_entry_float(U, 2, 0, 0);
    sparse_insert_entry_float(U, 3, 0, 1);
    sparse_insert_entry_float(U, 1, 1, 1);
    sparse_insert_entry_float(U, 4, 2, 2);
    return U;
}

static sparse_matrix_float port_upper(void)
{
    sparse_matrix_float U = RENAME(sparse_matrix_create_float)(3, 3);
    RENAME(sparse_set_matrix_property)(U, SPARSE_UPPER_TRIANGULAR);
    RENAME(sparse_insert_entry_float)(U, 2, 0, 0);
    RENAME(sparse_insert_entry_float)(U, 3, 0, 1);
    RENAME(sparse_insert_entry_float)(U, 1, 1, 1);
    RENAME(sparse_insert_entry_float)(U, 4, 2, 2);
    return U;
}

static sparse_matrix_float host_plain(void)
{
    sparse_matrix_float A = sparse_matrix_create_float(3, 3);
    sparse_insert_entry_float(A, 1, 0, 0);
    sparse_insert_entry_float(A, 2, 0, 2);
    sparse_insert_entry_float(A, 3, 1, 1);
    sparse_insert_entry_float(A, 4, 2, 0);
    return A;
}

static sparse_matrix_float port_plain(void)
{
    sparse_matrix_float A = RENAME(sparse_matrix_create_float)(3, 3);
    RENAME(sparse_insert_entry_float)(A, 1, 0, 0);
    RENAME(sparse_insert_entry_float)(A, 2, 0, 2);
    RENAME(sparse_insert_entry_float)(A, 3, 1, 1);
    RENAME(sparse_insert_entry_float)(A, 4, 2, 0);
    return A;
}

static void level2(void)
{
    sparse_matrix_float ha = host_plain(), pa = port_plain();
    sparse_matrix_float hl = host_lower(), pl = port_lower();
    sparse_matrix_float hu = host_upper(), pu = port_upper();
    for (int which = 0; which < 3; which++) {
        sparse_matrix_float host = which == 0 ? ha : (which == 1 ? hl : hu);
        sparse_matrix_float port = which == 0 ? pa : (which == 1 ? pl : pu);
        sparse_dimension inner = which == 0 ? 3 : 3;
        for (int tr = 0; tr < 2; tr++) {
            for (int alpha = -1; alpha <= 2; alpha++) {
                float y1[3] = {1, 1, 1}, y2[3] = {1, 1, 1};
                float x[3] = {1, 2, 4};
                sparse_status ma = RENAME(sparse_matrix_vector_product_dense_float)((enum CBLAS_TRANSPOSE)(tr ? 112 : 111),
                                                                                     (float)alpha, port, x, 1, y1, 1);
                sparse_status mb = sparse_matrix_vector_product_dense_float((enum CBLAS_TRANSPOSE)(tr ? 112 : 111),
                                                                            (float)alpha, host, x, 1, y2, 1);
                report(ma == mb && same_floats(y1, y2, 3, "a matrix-vector product"),
                       "a matrix-vector product", "the same status and every element");
            }
        }
        {
            float x[9] = {1, 2, 3, 4, 5, 6, 7, 8, 9}, y1[9] = {0}, y2[9] = {0};
            sparse_status ma = RENAME(sparse_matrix_vector_product_dense_float)(CblasNoTrans, 1.0f, port, x, 3, y1, 3);
            sparse_status mb = sparse_matrix_vector_product_dense_float(CblasNoTrans, 1.0f, host, x, 3, y2, 3);
            report(ma == mb && same_floats(y1, y2, 9, "a matrix-vector product, stride 3"),
                   "a matrix-vector product, stride 3", "the same status and every element");
            memset(y1, 0, sizeof(y1));
            memset(y2, 0, sizeof(y2));
            float xs[3] = {5, 6, 7};
            RENAME(sparse_matrix_vector_product_dense_float)(CblasNoTrans, 1.0f, port, xs + 2, -1, y1 + 2, -1);
            sparse_matrix_vector_product_dense_float(CblasNoTrans, 1.0f, host, xs + 2, -1, y2 + 2, -1);
            static const float want[3][2] = {{17, 18}, {14, 25}, {32, 6}};
            snprintf(detail, sizeof detail, "port %g %g, wanted %g %g", y1[2], y1[1], want[which][0], want[which][1]);
            report(y1[2] == want[which][0] && y1[1] == want[which][1],
                   "a matrix-vector product, negative stride (header)", detail);
        }
        if (which > 0) {
            for (int tr = 0; tr < 2; tr++) {
                for (int alpha = 0; alpha <= 3; alpha++) {
                    float b1[3] = {2, 5, 4}, b2[3] = {2, 5, 4};
                    sparse_status ma = RENAME(sparse_vector_triangular_solve_dense_float)((enum CBLAS_TRANSPOSE)(tr ? 112 : 111),
                                                                                         (float)alpha / 2.0f, port, b1, 1);
                    sparse_status mb = sparse_vector_triangular_solve_dense_float((enum CBLAS_TRANSPOSE)(tr ? 112 : 111),
                                                                                  (float)alpha / 2.0f, host, b2, 1);
                    if (alpha == 0) {
                        int finite = 1;
                        for (int k = 0; k < 3; k++) {
                            finite = finite && !isfinite(b1[k]) && !isfinite(b2[k]);
                        }
                        report(ma == mb && finite, "a triangular solve with an alpha of zero",
                               "the same status and no element a number");
                        continue;
                    }
                    if (!(ma == mb && same_floats(b1, b2, 3, "x"))) {
                    snprintf(detail, sizeof detail, "matrix %d trans %d alpha %g: port %g %g %g, host %g %g %g",
                             which, tr, alpha / 2.0f, b1[0], b1[1], b1[2], b2[0], b2[1], b2[2]);
                    report(0, "a triangular solve of a vector", detail);
                } else {
                    report(1, "a triangular solve of a vector", "");
                }
                }
            }
    {
        float x[3] = {1, 1, 1}, y[3] = {1, 1, 1};
        sparse_status port = RENAME(sparse_matrix_vector_product_dense_float)((enum CBLAS_TRANSPOSE)9, 1.0f, pa, x, 1, y, 1);
        report(port == SPARSE_ILLEGAL_PARAMETER, "a transpose outside the enumeration, the vector product",
               "the port answers the status the header names, and y is left alone");
        float B[6] = {1, 2, 3, 4, 5, 6}, dy[4] = {1, 1, 1, 1};
        sparse_status dense = RENAME(sparse_matrix_product_dense_float)(CblasRowMajor, (enum CBLAS_TRANSPOSE)9, 2, 1.0f, pa, B,
                                                                       2, dy, 2);
        report(dense == SPARSE_ILLEGAL_PARAMETER, "a transpose outside the enumeration, the dense product",
               "the port answers the status the header names, and C is left alone");
        float b[3] = {2, 5, 4};
        sparse_status tri = RENAME(sparse_vector_triangular_solve_dense_float)((enum CBLAS_TRANSPOSE)9, 1.0f, pl, b, 1);
        report(tri == SPARSE_ILLEGAL_PARAMETER, "a transpose outside the enumeration, the triangular solve",
               "the port answers the status the header names, and x is left alone");
    }
            {
                float b1[3] = {2, 5, 4}, b2[3] = {2, 5, 4};
                sparse_status ma = RENAME(sparse_vector_triangular_solve_dense_float)(CblasNoTrans, 1.0f, pa, b1, 1);
                sparse_status mb = sparse_vector_triangular_solve_dense_float(CblasNoTrans, 1.0f, ha, b2, 1);
                report(ma == mb && same_floats(b1, b2, 3, "a triangular solve of a plain matrix"),
                       "a triangular solve of a plain matrix", "SPARSE_ILLEGAL_PARAMETER and the vector untouched");
            }
        }
        (void)inner;
    }
    {
        sparse_matrix_float hz = sparse_matrix_create_float(2, 2), pz = RENAME(sparse_matrix_create_float)(2, 2);
        sparse_set_matrix_property(hz, SPARSE_LOWER_TRIANGULAR);
        RENAME(sparse_set_matrix_property)(pz, SPARSE_LOWER_TRIANGULAR);
        sparse_insert_entry_float(hz, 0, 0, 0);
        sparse_insert_entry_float(hz, 1, 1, 1);
        RENAME(sparse_insert_entry_float)(pz, 0, 0, 0);
        RENAME(sparse_insert_entry_float)(pz, 1, 1, 1);
        float b1[2] = {1, 1}, b2[2] = {1, 1};
        sparse_status ma = RENAME(sparse_vector_triangular_solve_dense_float)(CblasNoTrans, 1.0f, pz, b1, 1);
        sparse_status mb = sparse_vector_triangular_solve_dense_float(CblasNoTrans, 1.0f, hz, b2, 1);
        snprintf(detail, sizeof detail, "port %g %g, host %g %g", b1[0], b1[1], b2[0], b2[1]);
        report(ma == mb && isinf(b1[0]) && isinf(b2[0]) && b1[0] == b2[0],
               "a triangular solve with a zero pivot", detail);
        RENAME(sparse_matrix_destroy)(pz);
        sparse_matrix_destroy(hz);
    }
    for (int which = 1; which <= 2; which++) {
        sparse_matrix_float host = which == 1 ? hl : hu;
        sparse_matrix_float port = which == 1 ? pl : pu;
        for (int order = 0; order < 2; order++) {
            for (int tr = 0; tr < 2; tr++) {
                for (sparse_dimension ldb = 3; ldb <= 5; ldb++) {
                    float b1[16], b2[16];
                    for (int k = 0; k < 16; k++) { b1[k] = (float)(k + 1); b2[k] = (float)(k + 1); }
                    sparse_status ma = RENAME(sparse_matrix_triangular_solve_dense_float)(
                        (enum CBLAS_ORDER)(order ? 102 : 101), (enum CBLAS_TRANSPOSE)(tr ? 112 : 111), 2, 1.5f, port, b1, ldb);
                    sparse_status mb = sparse_matrix_triangular_solve_dense_float((enum CBLAS_ORDER)(order ? 102 : 101),
                                                                                 (enum CBLAS_TRANSPOSE)(tr ? 112 : 111), 2, 1.5f,
                                                                                 host, b2, ldb);
                    report(ma == mb && same_floats(b1, b2, 16, "a triangular solve of a matrix"),
                           "a triangular solve of a matrix", "the same status and every element of the block");
                }
            }
        }
    }
    {
        float b1[6] = {2, 5, 4, 1, 2, 3};
        sparse_status ma = RENAME(sparse_matrix_triangular_solve_dense_float)(CblasRowMajor, CblasNoTrans, 2, 1.0f, pl, b1, 1);
        fflush(stdout);
        pid_t child = fork();
        if (child == 0) {
            freopen("/dev/null", "w", stdout);
            float b2[6] = {2, 5, 4, 1, 2, 3};
            sparse_matrix_triangular_solve_dense_float(CblasRowMajor, CblasNoTrans, 2, 1.0f, hl, b2, 1);
            _exit(0);
        }
        int status = 0;
        waitpid(child, &status, 0);
        int ended = WIFSIGNALED(status) || (WIFEXITED(status) && WEXITSTATUS(status) != 0);
        snprintf(detail, sizeof detail, "port %d, host child %s", ma,
                 WIFSIGNALED(status) ? "was killed" : (WIFEXITED(status) ? "exited" : "is unknown"));
        report(ma == SPARSE_ILLEGAL_PARAMETER && ended,
               "a triangular solve with a leading dimension of one (header)", detail);
    }
    RENAME(sparse_matrix_destroy)(pa); sparse_matrix_destroy(ha);
    RENAME(sparse_matrix_destroy)(pl); sparse_matrix_destroy(hl);
    RENAME(sparse_matrix_destroy)(pu); sparse_matrix_destroy(hu);
}

static void outer(void)
{
    struct { sparse_dimension M, N, nz; double alpha; sparse_index indy[3]; float y[3]; int expectMatrix; } cases[] = {
        {2, 3, 2, 2.0f, {0, 2, 0}, {3, 4, 0}, 1},
        {2, 3, 0, 1.0f, {0, 0, 0}, {0, 0, 0}, 1},
        {2, 3, 2, 0.0f, {0, 2, 0}, {3, 4, 0}, 1},
        {2, 3, 4, 1.0f, {0, 1, 2}, {3, 4, 5}, 0},
    };
    {
        const sparse_index indy[2] = {0, 2};
        const float x[3] = {1, 2, 3}, y[2] = {5, -6};
        float mutant[3][2];
        int differs = 0;
        for (int k = 0; k < 2; k++) {
            for (int i = 0; i < 3; i++) {
                mutant[i][k] = x[k] * y[k];
            }
        }
        for (int i = 0; i < 3 && !differs; i++) {
            for (int k = 0; k < 2 && !differs; k++) {
                differs = mutant[i][k] != x[i] * y[k];
            }
        }
        report(differs, "the outer-product mutant that indexes x by the nonzero differs from the header",
               "the mutant agrees with the header, so the case below cannot see that bug");

        sparse_matrix_float mine = NULL, theirs = NULL;
        sparse_status ma = RENAME(sparse_outer_product_dense_float)(3, 3, 2, 1.0f, x, 1, y, indy, &mine);
        sparse_status mb = sparse_outer_product_dense_float(3, 3, 2, 1.0f, x, 1, y, indy, &theirs);
        int passed = ma == mb;
        for (int i = 0; i < 3 && passed; i++) {
            sparse_index mineEnd = 0, theirsEnd = 0;
            float mineValues[4], theirsValues[4];
            sparse_index mineIndices[4], theirsIndices[4];
            ma = RENAME(sparse_extract_sparse_row_float)(mine, i, 0, &mineEnd, 4, mineValues, mineIndices);
            mb = sparse_extract_sparse_row_float(theirs, i, 0, &theirsEnd, 4, theirsValues, theirsIndices);
            passed = ma == mb && mineEnd == theirsEnd;
            for (int k = 0; k < 2 && passed; k++) {
                float want = x[i] * y[k];
                passed = mineValues[k] == want && theirsValues[k] == want;
            }
        }
        if (!passed) {
            snprintf(detail, sizeof detail, "row by row: the port and the host do not both answer x[i] * y[k]");
        }
        report(passed, "an outer product with x of three different values, against the header and the host",
               detail);
        RENAME(sparse_matrix_destroy)(mine);
        sparse_matrix_destroy(theirs);
    }
    for (size_t k = 0; k < sizeof(cases) / sizeof(cases[0]); k++) {
        float x[2] = {1, 1};
        sparse_matrix_float mine = NULL, theirs = NULL;
        sparse_status ma = RENAME(sparse_outer_product_dense_float)(cases[k].M, cases[k].N, cases[k].nz,
                                                                   (float)cases[k].alpha, x, 1, cases[k].y,
                                                                   cases[k].indy, &mine);
        sparse_status mb = sparse_outer_product_dense_float(cases[k].M, cases[k].N, cases[k].nz, (float)cases[k].alpha,
                                                            x, 1, cases[k].y, cases[k].indy, &theirs);
        int passed = ma == mb;
        if (passed && cases[k].expectMatrix) {
            passed = RENAME(sparse_get_matrix_number_of_rows)(mine) == sparse_get_matrix_number_of_rows(theirs) &&
                     RENAME(sparse_get_matrix_number_of_columns)(mine) == sparse_get_matrix_number_of_columns(theirs) &&
                     RENAME(sparse_get_matrix_nonzero_count)(mine) == sparse_get_matrix_nonzero_count(theirs);
            if (passed && RENAME(sparse_get_matrix_nonzero_count)(mine) > 0) {
                compare_matrix("an outer product, the matrix", (Pair){mine, theirs}, cases[k].M, cases[k].N, 0);
            }
        }
        report(passed, "an outer product", "the same status, the same shape and every element");
        if (mine) RENAME(sparse_matrix_destroy)(mine);
        if (theirs) sparse_matrix_destroy(theirs);
    }
}

static void permutations(void)
{
    sparse_index rowPerms[5][2] = {{1, 0}, {0, 1}, {0, 0}, {1, 1}, {0, 1}};
    for (int k = 0; k < 5; k++) {
        sparse_matrix_float h = sparse_matrix_create_float(2, 3), p = RENAME(sparse_matrix_create_float)(2, 3);
        float v[6] = {1, 2, 3, 4, 5, 6};
        sparse_index r[6] = {0, 0, 0, 1, 1, 1}, c[6] = {0, 1, 2, 0, 1, 2};
        sparse_insert_entries_float(h, 6, v, r, c);
        RENAME(sparse_insert_entries_float)(p, 6, v, r, c);
        sparse_status ma = RENAME(sparse_permute_rows_float)(p, rowPerms[k]);
        sparse_status mb = sparse_permute_rows_float(h, rowPerms[k]);
        report(ma == mb, "a row permutation", "the same status");
        compare_matrix("a row permutation, the matrix", (Pair){p, h}, 2, 3, 0);
        RENAME(sparse_matrix_destroy)(p);
        sparse_matrix_destroy(h);
    }
    sparse_index colPerms[8][3] = {{1, 0, 0}, {0, 1, 0}, {2, 0, 1}, {0, 2, 1}, {2, 1, 0}, {0, 1, 2}, {0, 0, 0}, {2, 2, 2}};
    for (int k = 0; k < 8; k++) {
        sparse_matrix_float h = sparse_matrix_create_float(2, 3), p = RENAME(sparse_matrix_create_float)(2, 3);
        float v[6] = {1, 2, 3, 4, 5, 6};
        sparse_index r[6] = {0, 0, 0, 1, 1, 1}, c[6] = {0, 1, 2, 0, 1, 2};
        sparse_insert_entries_float(h, 6, v, r, c);
        RENAME(sparse_insert_entries_float)(p, 6, v, r, c);
        sparse_status ma = RENAME(sparse_permute_cols_float)(p, colPerms[k]);
        sparse_status mb = sparse_permute_cols_float(h, colPerms[k]);
        report(ma == mb, "a column permutation", "the same status");
        compare_matrix("a column permutation, the matrix", (Pair){p, h}, 2, 3, 0);
        RENAME(sparse_matrix_destroy)(p);
        sparse_matrix_destroy(h);
    }
}

static void norms_and_trace(void)
{
    float values[5] = {-1, 2, -3, 4, -5};
    sparse_index rows[5] = {0, 0, 0, 1, 1}, columns[5] = {0, 1, 2, 0, 2};
    Pair pair = pointwise(2, 3, 5, values, rows, columns, 0);
    sparse_norm norms[5] = {SPARSE_NORM_ONE, SPARSE_NORM_TWO, SPARSE_NORM_INF, SPARSE_NORM_R1, (sparse_norm)999};
    for (int k = 0; k < 5; k++) {
        float mine = RENAME(sparse_elementwise_norm_float)((sparse_matrix_float)pair.mine, norms[k]);
        float theirs = sparse_elementwise_norm_float((sparse_matrix_float)pair.theirs, norms[k]);
        report(same_double(mine, theirs, 1e-6), "an elementwise norm", "the same value");
        float one = RENAME(sparse_operator_norm_float)((sparse_matrix_float)pair.mine, norms[k]);
        float other = sparse_operator_norm_float((sparse_matrix_float)pair.theirs, norms[k]);
        if (norms[k] == SPARSE_NORM_TWO) {
            report(same_double(one, other, 5e-3), "an operator norm, two", "within 5e-3, the stated tolerance");
        } else {
            snprintf(detail, sizeof detail, "norm %d: port %g, host %g", (int)norms[k], one, other);
            report(same_double(one, other, 1e-6), "an operator norm", detail);
        }
    }
    {
        Pair empty = pointwise(3, 3, 0, NULL, NULL, NULL, 0);
        for (int k = 0; k < 4; k++) {
            float ea = RENAME(sparse_elementwise_norm_float)((sparse_matrix_float)empty.mine, norms[k]);
            float eb = sparse_elementwise_norm_float((sparse_matrix_float)empty.theirs, norms[k]);
            float oa = RENAME(sparse_operator_norm_float)((sparse_matrix_float)empty.mine, norms[k]);
            float ob = sparse_operator_norm_float((sparse_matrix_float)empty.theirs, norms[k]);
            snprintf(detail, sizeof detail, "norm %d: elementwise %g against %g, operator %g against %g", (int)norms[k],
                     ea, eb, oa, ob);
            report(same_double(ea, eb, 1e-6) && same_double(oa, ob, 1e-6), "the norms of an empty matrix", detail);
        }
        RENAME(sparse_matrix_destroy)(empty.mine);
        sparse_matrix_destroy(empty.theirs);
        float d[2] = {3, 4};
        sparse_index dr[2] = {0, 1}, dc[2] = {0, 1};
        Pair diagonal = pointwise(2, 2, 2, d, dr, dc, 0);
        report(same_double(RENAME(sparse_operator_norm_float)((sparse_matrix_float)diagonal.mine, SPARSE_NORM_TWO),
                           sparse_operator_norm_float((sparse_matrix_float)diagonal.theirs, SPARSE_NORM_TWO), 5e-3),
               "the operator-two norm of a diagonal", "within 5e-3, the stated tolerance");
        RENAME(sparse_matrix_destroy)(diagonal.mine);
        sparse_matrix_destroy(diagonal.theirs);
    }
    {
        float v[6] = {1, 2, 3, 4, 5, 6};
        sparse_index r[6] = {0, 0, 0, 1, 1, 1}, c[6] = {0, 0, 1, 1, 2, 3};
        Pair p = pointwise(3, 4, 6, v, r, c, 0);
        for (sparse_index offset = -5; offset <= 4; offset++) {
            float ta = RENAME(sparse_matrix_trace_float)((sparse_matrix_float)p.mine, offset);
            float tb = sparse_matrix_trace_float((sparse_matrix_float)p.theirs, offset);
            snprintf(detail, sizeof detail, "offset %lld: port %g, host %g", (long long)offset, ta, tb);
            report(same_double(ta, tb, 1e-6), "a trace", detail);
        }
        int past = 1;
        for (sparse_index offset = 5; offset <= 9; offset++) {
            past = past && RENAME(sparse_matrix_trace_float)((sparse_matrix_float)p.mine, offset) == 0.0f;
        }
        for (sparse_index offset = -9; offset <= -6; offset++) {
            past = past && RENAME(sparse_matrix_trace_float)((sparse_matrix_float)p.mine, offset) == 0.0f;
        }
        report(past, "a trace past the last column", "0, as the header says");
        RENAME(sparse_matrix_destroy)(p.mine);
        sparse_matrix_destroy(p.theirs);
    }
    {
        double v[5] = {-1, 2, -3, 4, -5};
        sparse_index r[5] = {0, 0, 0, 1, 1}, c[5] = {0, 1, 2, 0, 2};
        Pair p = pointwise(2, 3, 5, v, r, c, 1);
        for (int k = 0; k < 4; k++) {
            double ea = RENAME(sparse_elementwise_norm_double)((sparse_matrix_double)p.mine, norms[k]);
            double eb = sparse_elementwise_norm_double((sparse_matrix_double)p.theirs, norms[k]);
            double oa = RENAME(sparse_operator_norm_double)((sparse_matrix_double)p.mine, norms[k]);
            double ob = sparse_operator_norm_double((sparse_matrix_double)p.theirs, norms[k]);
            snprintf(detail, sizeof detail, "norm %d: elementwise %g against %g, operator %g against %g", (int)norms[k], ea, eb, oa, ob);
            report(same_double(ea, eb, 1e-12) && same_double(oa, ob, norms[k] == SPARSE_NORM_TWO ? 5e-3 : 1e-12),
                   "a double norm", detail);
        }
        double da = RENAME(sparse_matrix_trace_double)((sparse_matrix_double)p.mine, 0);
        double db = sparse_matrix_trace_double((sparse_matrix_double)p.theirs, 0);
        snprintf(detail, sizeof detail, "port %g, host %g", da, db);
        report(same_double(da, db, 1e-12), "a double trace", detail);
        RENAME(sparse_matrix_destroy)(p.mine);
        sparse_matrix_destroy(p.theirs);
    }
}

static void level3(void)
{
    float aValues[4] = {1, 2, 3, 4};
    sparse_index aRows[4] = {0, 0, 1, 1}, aColumns[4] = {0, 2, 1, 2};
    Pair A = pointwise(2, 3, 4, aValues, aRows, aColumns, 0);
    float bValues[6] = {1, 2, 3, 4, 5, 6};
    sparse_index bRows[6] = {0, 0, 1, 1, 2, 2}, bColumns[6] = {0, 1, 0, 1, 0, 1};
    Pair S = pointwise(3, 2, 6, bValues, bRows, bColumns, 0);
    for (int order = 0; order < 2; order++) {
        float B[12] = {1, 2, 9, 9, 3, 4, 9, 9, 5, 6, 9, 9};
        for (int alpha = 0; alpha <= 2; alpha++) {
            float c1[8] = {7, 7, 7, 7, 7, 7, 7, 7}, c2[8] = {7, 7, 7, 7, 7, 7, 7, 7};
            sparse_status ma = RENAME(sparse_matrix_product_dense_float)((enum CBLAS_ORDER)(order ? 102 : 101), CblasNoTrans, 2,
                                                                          (float)alpha, (sparse_matrix_float)A.mine, B, 3, c1, 2);
            sparse_status mb = sparse_matrix_product_dense_float((enum CBLAS_ORDER)(order ? 102 : 101), CblasNoTrans, 2,
                                                                 (float)alpha, (sparse_matrix_float)A.theirs, B, 3, c2, 2);
            if (!(ma == mb && same_floats(c1, c2, 8, "x"))) {
                snprintf(detail, sizeof detail, "order %d alpha %d: port %d host %d |", order, alpha, ma, mb);
                for (int q = 0; q < 8; q++)
                    snprintf(detail + strlen(detail), sizeof detail - strlen(detail), " %g", c1[q]);
                snprintf(detail + strlen(detail), sizeof detail - strlen(detail), " |");
                for (int q = 0; q < 8; q++)
                    snprintf(detail + strlen(detail), sizeof detail - strlen(detail), " %g", c2[q]);
                report(0, "a dense product", detail);
            } else report(1, "a dense product", "");
        }
        {
            float c1[8] = {7, 7, 7, 7, 7, 7, 7, 7}, c2[8] = {7, 7, 7, 7, 7, 7, 7, 7};
            sparse_status ma = RENAME(sparse_matrix_product_dense_float)((enum CBLAS_ORDER)(order ? 102 : 101), CblasNoTrans, 0,
                                                                          1.0f, (sparse_matrix_float)A.mine, B, 3, c1, 2);
            sparse_status mb = sparse_matrix_product_dense_float((enum CBLAS_ORDER)(order ? 102 : 101), CblasNoTrans, 0,
                                                                 1.0f, (sparse_matrix_float)A.theirs, B, 3, c2, 2);
            report(ma == mb && same_floats(c1, c2, 8, "a dense product with no columns"),
                   "a dense product with no columns", "the same status and C untouched");
        }
        {
            float c1[8] = {7, 7, 7, 7, 7, 7, 7, 7}, c2[8] = {7, 7, 7, 7, 7, 7, 7, 7};
            sparse_status ma = RENAME(sparse_matrix_product_dense_float)((enum CBLAS_ORDER)9, CblasNoTrans, 2, 1.0f,
                                                                          (sparse_matrix_float)A.mine, B, 3, c1, 2);
            sparse_status mb = sparse_matrix_product_dense_float((enum CBLAS_ORDER)9, CblasNoTrans, 2, 1.0f,
                                                                 (sparse_matrix_float)A.theirs, B, 3, c2, 2);
            report(ma == mb && same_floats(c1, c2, 8, "a dense product with an order of 9"),
                   "a dense product with an order of 9", "the same status and C untouched");
            ma = RENAME(sparse_matrix_product_dense_float)((enum CBLAS_ORDER)(order ? 102 : 101), CblasNoTrans, 2, 1.0f,
                                                           (sparse_matrix_float)A.mine, B, 1, c1, 2);
            mb = sparse_matrix_product_dense_float((enum CBLAS_ORDER)(order ? 102 : 101), CblasNoTrans, 2, 1.0f,
                                                    (sparse_matrix_float)A.theirs, B, 1, c2, 2);
            report(ma == mb && same_floats(c1, c2, 8, "a dense product with a leading dimension of 1"),
                   "a dense product with a leading dimension of 1", "the same status and C untouched");
            ma = RENAME(sparse_matrix_product_dense_float)((enum CBLAS_ORDER)(order ? 102 : 101), CblasNoTrans, 2, 1.0f,
                                                           (sparse_matrix_float)A.mine, B, 3, c1, 1);
            mb = sparse_matrix_product_dense_float((enum CBLAS_ORDER)(order ? 102 : 101), CblasNoTrans, 2, 1.0f,
                                                    (sparse_matrix_float)A.theirs, B, 3, c2, 1);
            report(ma == mb && same_floats(c1, c2, 8, "a dense product with an output stride of 1"),
                   "a dense product with an output stride of 1", "the same status and C untouched");
        }
        for (int alpha = 0; alpha <= 2; alpha++) {
            float c1[4] = {7, 7, 7, 7}, c2[4] = {7, 7, 7, 7};
            sparse_status ma = RENAME(sparse_matrix_product_sparse_float)((enum CBLAS_ORDER)(order ? 102 : 101), CblasNoTrans,
                                                                           (float)alpha, (sparse_matrix_float)A.mine,
                                                                           (sparse_matrix_float)S.mine, c1, 2);
            sparse_status mb = sparse_matrix_product_sparse_float((enum CBLAS_ORDER)(order ? 102 : 101), CblasNoTrans,
                                                                    (float)alpha, (sparse_matrix_float)A.theirs,
                                                                    (sparse_matrix_float)S.theirs, c2, 2);
            if (!(ma == mb && same_floats(c1, c2, 4, "x"))) {
                snprintf(detail, sizeof detail, "order %d alpha %d: port %d host %d | %g %g %g %g | %g %g %g %g", order,
                         alpha, ma, mb, c1[0], c1[1], c1[2], c1[3], c2[0], c2[1], c2[2], c2[3]);
                report(0, "a sparse product", detail);
            } else report(1, "a sparse product", "");
        }
        {
            float c1[4] = {7, 7, 7, 7}, c2[4] = {7, 7, 7, 7};
            sparse_status ma = RENAME(sparse_matrix_product_sparse_float)((enum CBLAS_ORDER)(order ? 102 : 101), CblasNoTrans,
                                                                           1.0f, (sparse_matrix_float)A.mine,
                                                                           (sparse_matrix_float)S.mine, c1, 1);
            sparse_status mb = sparse_matrix_product_sparse_float((enum CBLAS_ORDER)(order ? 102 : 101), CblasNoTrans, 1.0f,
                                                                    (sparse_matrix_float)A.theirs,
                                                                    (sparse_matrix_float)S.theirs, c2, 1);
            report(ma == mb && same_floats(c1, c2, 4, "a sparse product with an output stride of 1"),
                   "a sparse product with an output stride of 1", "the same status and C untouched");
        }
    }
    {
        float tValues[6] = {1, 2, 3, 4, 5, 6};
        sparse_index tRows[6] = {0, 0, 0, 1, 1, 1}, tColumns[6] = {0, 1, 2, 0, 1, 2};
        Pair T = pointwise(2, 3, 6, tValues, tRows, tColumns, 0);
        float B[12] = {1, 2, 3, 9, 4, 5, 6, 9, 7, 8, 9, 9};
        for (int order = 0; order < 2; order++) {
            float c1[9] = {7, 7, 7, 7, 7, 7, 7, 7, 7}, c2[9] = {7, 7, 7, 7, 7, 7, 7, 7, 7};
            sparse_status ma = RENAME(sparse_matrix_product_dense_float)((enum CBLAS_ORDER)(order ? 102 : 101), CblasNoTrans, 3,
                                                                          1.0f, (sparse_matrix_float)T.mine, B, 3, c1, 3);
            sparse_status mb = sparse_matrix_product_dense_float((enum CBLAS_ORDER)(order ? 102 : 101), CblasNoTrans, 3,
                                                                 1.0f, (sparse_matrix_float)T.theirs, B, 3, c2, 3);
            if (!(ma == mb && same_floats(c1, c2, 9, "x"))) {
                snprintf(detail, sizeof detail, "order %d: port %d host %d |", order, ma, mb);
                for (int q = 0; q < 9; q++)
                    snprintf(detail + strlen(detail), sizeof detail - strlen(detail), " %g", c1[q]);
                snprintf(detail + strlen(detail), sizeof detail - strlen(detail), " |");
                for (int q = 0; q < 9; q++)
                    snprintf(detail + strlen(detail), sizeof detail - strlen(detail), " %g", c2[q]);
                report(0, "a dense product of a 2x3", detail);
            } else report(1, "a dense product of a 2x3", "");
        }
        RENAME(sparse_matrix_destroy)(T.mine);
        sparse_matrix_destroy(T.theirs);
    }
    {
        float tValues[6] = {1, 2, 3, 4, 5, 6};
        sparse_index tRows[6] = {0, 0, 1, 1, 2, 2}, tColumns[6] = {0, 1, 0, 1, 0, 1};
        Pair T = pointwise(3, 2, 6, tValues, tRows, tColumns, 0);
        {
            double seen[6] = {0, 0, 0, 0, 0, 0};
            readf(T.mine, 0, 1, 3, 2, seen);
            report(same_doubles(seen, (double[]){1, 2, 3, 4, 5, 6}, 6, 1e-6, "x"),
                   "the transposed operand's own six values", "1 2 3 / 4 5 6 on the port");
        }
        for (int order = 0; order < 2; order++) {
            float c1[4] = {7, 7, 7, 7}, c2[4] = {7, 7, 7, 7};
            sparse_status ma = RENAME(sparse_matrix_product_sparse_float)((enum CBLAS_ORDER)(order ? 102 : 101),
                                                                         CblasTrans, 1.0f,
                                                                         (sparse_matrix_float)T.mine,
                                                                         (sparse_matrix_float)S.mine, c1, 2);
            sparse_status mb = sparse_matrix_product_sparse_float((enum CBLAS_ORDER)(order ? 102 : 101), CblasTrans, 1.0f,
                                                                  (sparse_matrix_float)T.theirs,
                                                                  (sparse_matrix_float)S.theirs, c2, 2);
            snprintf(detail, sizeof detail, "order %d, CblasTrans: port %d host %d", order, ma, mb);
            report(ma == mb && same_floats(c1, c2, 4, "x"), "a sparse product, CblasTrans, both layouts", detail);
        }
        {
            float c1[4] = {7, 7, 7, 7}, c2[4] = {7, 7, 7, 7};
            sparse_status ma = RENAME(sparse_matrix_product_sparse_float)(CblasRowMajor, CblasNoTrans, 1.0f,
                                                                         (sparse_matrix_float)T.mine,
                                                                         (sparse_matrix_float)S.mine, c1, 2);
            sparse_status mb = sparse_matrix_product_sparse_float(CblasRowMajor, CblasNoTrans, 1.0f,
                                                                  (sparse_matrix_float)T.theirs,
                                                                  (sparse_matrix_float)S.theirs, c2, 2);
            snprintf(detail, sizeof detail, "inner dimensions 2 against 3: the port refuses with %d, the host "
                     "answers %d and writes a product of two matrices that do not conform", ma, mb);
            report(ma == SPARSE_ILLEGAL_PARAMETER && mb == SPARSE_SUCCESS,
                   "a sparse product whose inner dimensions do not conform", detail);
        }
        RENAME(sparse_matrix_destroy)(T.mine);
        sparse_matrix_destroy(T.theirs);
    }
    RENAME(sparse_matrix_destroy)(A.mine); sparse_matrix_destroy(A.theirs);
    RENAME(sparse_matrix_destroy)(S.mine); sparse_matrix_destroy(S.theirs);
}

static void theDoubleProduct(void)
{
    double aValues[5] = {1.1, 2.2, 3.3, 4.4, 5.5};
    sparse_index aRows[5] = {0, 0, 1, 1, 1}, aColumns[5] = {0, 2, 0, 1, 2};
    double sValues[6] = {6.6, 7.7, 8.8, 9.9, 1.1, 2.2};
    sparse_index sRows[6] = {0, 0, 1, 1, 2, 2}, sColumns[6] = {0, 1, 0, 1, 0, 1};
    Pair A = pointwise(2, 3, 5, aValues, aRows, aColumns, 1);
    Pair S = pointwise(3, 2, 6, sValues, sRows, sColumns, 1);
    const double start[4] = {7.0, 8.0, 9.0, 10.0};
    for (int alpha = 0; alpha <= 2; alpha++) {
        for (int order = 0; order < 2; order++) {
            sparse_dimension ldc = 2;
            double want[4] = {0, 0, 0, 0}, noAdd[4] = {0, 0, 0, 0}, noAlpha[4] = {0, 0, 0, 0}, transposed[4] = {0, 0, 0, 0};
            for (int i = 0; i < 2; i++) {
                for (int j = 0; j < 2; j++) {
                    sparse_dimension at = order ? (sparse_dimension)(i + j * ldc) : (sparse_dimension)(i * ldc + j);
                    double sum = 0.0, wrong = 0.0;
                    for (sparse_dimension k = 0; k < 3; k++) {
                        double left = 0.0, transposedLeft = 0.0, right = 0.0;
                        for (sparse_index q = 0; q < 5; q++) {
                            if (aRows[q] == i && aColumns[q] == k) left = aValues[q];
                            if (aRows[q] == (sparse_index)k && aColumns[q] == i) transposedLeft = aValues[q];
                        }
                        for (sparse_index q = 0; q < 6; q++) {
                            if (sRows[q] == k && sColumns[q] == j) right = sValues[q];
                        }
                        sum += left * right;
                        wrong += transposedLeft * right;
                    }
                    want[at] = start[at] + alpha * sum;
                    noAdd[at] = alpha * sum;
                    noAlpha[at] = start[at] + sum;
                    transposed[at] = start[at] + alpha * wrong;
                }
            }
            report(differs(noAdd, want, 4, 1e-12),
                   "the mutant that overwrites C instead of adding to it differs from the header",
                   "the mutant agrees with the header's rule, so the case cannot see that bug");
            if (alpha != 0) {
                report(differs(transposed, want, 4, 1e-12),
                       "the mutant that reads A at (k, i) instead of (i, k) differs from the header",
                       "the mutant agrees with the header's rule, so the case cannot see that bug");
                if (alpha != 1) {
                    report(differs(noAlpha, want, 4, 1e-12),
                           "the mutant that drops alpha differs from the header",
                           "the mutant agrees with the header's rule, so the case cannot see that bug");
                }
            }
            double c1[4] = {7, 8, 9, 10}, c2[4] = {7, 8, 9, 10};
            sparse_status ma = RENAME(sparse_matrix_product_sparse_double)((enum CBLAS_ORDER)(order ? 102 : 101),
                                                                             CblasNoTrans, (double)alpha,
                                                                             (sparse_matrix_double)A.mine,
                                                                             (sparse_matrix_double)S.mine, c1, ldc);
            sparse_status mb = sparse_matrix_product_sparse_double((enum CBLAS_ORDER)(order ? 102 : 101), CblasNoTrans,
                                                                    (double)alpha, (sparse_matrix_double)A.theirs,
                                                                    (sparse_matrix_double)S.theirs, c2, ldc);
            int ok = ma == mb;
            for (int k = 0; ok && k < 4; k++) {
                ok = same_double(c1[k], want[k], 1e-12) && same_double(c2[k], want[k], 1e-12);
            }
            snprintf(detail, sizeof detail, "order %d alpha %d: port %d host %d | port", order, alpha, ma, mb);
            for (int k = 0; k < 4; k++)
                snprintf(detail + strlen(detail), sizeof detail - strlen(detail), " %g", c1[k]);
            snprintf(detail + strlen(detail), sizeof detail - strlen(detail), " | host");
            for (int k = 0; k < 4; k++)
                snprintf(detail + strlen(detail), sizeof detail - strlen(detail), " %g", c2[k]);
            snprintf(detail + strlen(detail), sizeof detail - strlen(detail), " | the header's rule");
            for (int k = 0; k < 4; k++)
                snprintf(detail + strlen(detail), sizeof detail - strlen(detail), " %g", want[k]);
            report(ok, "a double sparse product against the header's rule and the host, both layouts", detail);
        }
    }
    for (int order = 0; order < 2; order++) {
        double c1[4] = {7, 8, 9, 10}, c2[4] = {7, 8, 9, 10};
        sparse_status ma = RENAME(sparse_matrix_product_sparse_double)((enum CBLAS_ORDER)(order ? 102 : 101), CblasNoTrans,
                                                                        1.0, (sparse_matrix_double)A.mine,
                                                                        (sparse_matrix_double)S.mine, c1, 1);
        sparse_status mb = sparse_matrix_product_sparse_double((enum CBLAS_ORDER)(order ? 102 : 101), CblasNoTrans, 1.0,
                                                                (sparse_matrix_double)A.theirs,
                                                                (sparse_matrix_double)S.theirs, c2, 1);
        snprintf(detail, sizeof detail, "order %d: port %d host %d, C untouched on both", order, ma, mb);
        report(ma == mb && same_doubles(c1, c2, 4, 1e-12, "x"), "a double sparse product with a leading dimension of 1",
               detail);
    }
    {
        double tValues[5] = {3.3, 4.4, 5.5, 6.6, 7.7};
        sparse_index tRows[5] = {0, 1, 2, 0, 2}, tColumns[5] = {0, 1, 0, 0, 1};
        Pair T = pointwise(3, 2, 5, tValues, tRows, tColumns, 1);
        for (int alpha = 0; alpha <= 2; alpha++) {
            for (int order = 0; order < 2; order++) {
                sparse_dimension ldc = 2;
                double want[4] = {0, 0, 0, 0};
                for (int i = 0; i < 2; i++) {
                    for (int j = 0; j < 2; j++) {
                        sparse_dimension at = order ? (sparse_dimension)(i + j * ldc) : (sparse_dimension)(i * ldc + j);
                        double sum = 0.0;
                        for (sparse_dimension k = 0; k < 3; k++) {
                            double left = 0.0, right = 0.0;
                            for (sparse_index q = 0; q < 5; q++) {
                                if (tRows[q] == k && tColumns[q] == i) left = tValues[q];
                            }
                            for (sparse_index q = 0; q < 6; q++) {
                                if (sRows[q] == k && sColumns[q] == j) right = sValues[q];
                            }
                            sum += left * right;
                        }
                        want[at] = start[at] + alpha * sum;
                    }
                }
                double c1[4] = {7, 8, 9, 10}, c2[4] = {7, 8, 9, 10};
                sparse_status ma = RENAME(sparse_matrix_product_sparse_double)((enum CBLAS_ORDER)(order ? 102 : 101),
                                                                                 CblasTrans, (double)alpha,
                                                                                 (sparse_matrix_double)T.mine,
                                                                                 (sparse_matrix_double)S.mine, c1, ldc);
                sparse_status mb = sparse_matrix_product_sparse_double((enum CBLAS_ORDER)(order ? 102 : 101), CblasTrans,
                                                                        (double)alpha, (sparse_matrix_double)T.theirs,
                                                                        (sparse_matrix_double)S.theirs, c2, ldc);
                int ok = ma == mb;
                for (int k = 0; ok && k < 4; k++) {
                    ok = same_double(c1[k], want[k], 1e-12) && same_double(c2[k], want[k], 1e-12);
                }
                snprintf(detail, sizeof detail, "order %d alpha %d: port %d host %d | port", order, alpha, ma, mb);
                for (int k = 0; k < 4; k++)
                    snprintf(detail + strlen(detail), sizeof detail - strlen(detail), " %g", c1[k]);
                snprintf(detail + strlen(detail), sizeof detail - strlen(detail), " | host");
                for (int k = 0; k < 4; k++)
                    snprintf(detail + strlen(detail), sizeof detail - strlen(detail), " %g", c2[k]);
                snprintf(detail + strlen(detail), sizeof detail - strlen(detail), " | the header's rule");
                for (int k = 0; k < 4; k++)
                    snprintf(detail + strlen(detail), sizeof detail - strlen(detail), " %g", want[k]);
                report(ok, "a double sparse product, CblasTrans, against the header's rule and the host", detail);
            }
        }
        double c1[4] = {7, 8, 9, 10}, c2[4] = {7, 8, 9, 10};
        sparse_status ma = RENAME(sparse_matrix_product_sparse_double)(CblasRowMajor, CblasNoTrans, 1.0,
                                                                        (sparse_matrix_double)T.mine,
                                                                        (sparse_matrix_double)S.mine, c1, 2);
        sparse_status mb = sparse_matrix_product_sparse_double(CblasRowMajor, CblasNoTrans, 1.0,
                                                                (sparse_matrix_double)T.theirs,
                                                                (sparse_matrix_double)S.theirs, c2, 2);
        snprintf(detail, sizeof detail, "inner dimensions 2 against 3: the port refuses with %d, the host "
                 "answers %d and writes a product of two matrices that do not conform", ma, mb);
        report(ma == SPARSE_ILLEGAL_PARAMETER && mb == SPARSE_SUCCESS,
               "a double sparse product whose inner dimensions do not conform", detail);
        RENAME(sparse_matrix_destroy)(T.mine); sparse_matrix_destroy(T.theirs);
    }
    RENAME(sparse_matrix_destroy)(A.mine); sparse_matrix_destroy(A.theirs);
    RENAME(sparse_matrix_destroy)(S.mine); sparse_matrix_destroy(S.theirs);
}

static void theSixteen(void)
{
    char detail[512];
    {
        double v[2] = {7, 8};
        sparse_index at[2] = {1, 3};
        Pair a = pointwise(4, 4, 0, NULL, NULL, NULL, 1);
        sparse_status ma = RENAME(sparse_insert_row_double)((sparse_matrix_double)a.mine, 0, 2, v, at);
        sparse_status mb = sparse_insert_row_double((sparse_matrix_double)a.theirs, 0, 2, v, at);
        ma |= RENAME(sparse_insert_col_double)((sparse_matrix_double)a.mine, 2, 2, v, at);
        mb |= sparse_insert_col_double((sparse_matrix_double)a.theirs, 2, 2, v, at);
        snprintf(detail, sizeof detail, "port %d, host %d", ma, mb);
        report(ma == mb, "a double row and a double column inserted", detail);
        compare_matrix("a double row and column inserted, the matrix", a, 4, 4, 1);
        RENAME(sparse_matrix_destroy)(a.mine); sparse_matrix_destroy(a.theirs);
    }
    {
        double block[6] = {1, 2, 3, 4, 5, 6};
        sparse_matrix_double a = RENAME(sparse_matrix_block_create_double)(2, 2, 2, 3);
        sparse_matrix_double b = sparse_matrix_block_create_double(2, 2, 2, 3);
        sparse_status ma = RENAME(sparse_insert_block_double)(a, block, 3, 1, 0, 0);
        sparse_status mb = sparse_insert_block_double(b, block, 3, 1, 0, 0);
        report(ma == mb, "a double block inserted", "the same status");
        report(RENAME(sparse_get_matrix_number_of_rows)(a) == sparse_get_matrix_number_of_rows(b) &&
                   RENAME(sparse_get_matrix_nonzero_count)(a) == sparse_get_matrix_nonzero_count(b),
               "a double block matrix's shape", "the same rows and the same count");
        double back[8], other[8];
        for (int pair = 0; pair < 2; pair++) {
            for (int k = 0; k < 8; k++) back[k] = other[k] = 9;
            ma = RENAME(sparse_extract_block_double)(a, 0, 0, pair ? 1 : 3, pair ? 3 : 1, back);
            mb = sparse_extract_block_double(b, 0, 0, pair ? 1 : 3, pair ? 3 : 1, other);
            report(ma == mb && same_doubles(back, other, 8, 1e-12, "x"), "a double block read back",
                   pair ? "row stride 1, column stride 3: eight elements, the two gaps left as they were"
                         : "row stride 3, column stride 1: six elements");
        }
        for (int k = 0; k < 8; k++) back[k] = other[k] = 9;
        ma = RENAME(sparse_extract_block_double)(a, 1, 1, 3, 1, back);
        mb = sparse_extract_block_double(b, 1, 1, 3, 1, other);
        report(ma == mb && same_doubles(back, other, 8, 1e-12, "x"), "a double block never inserted", "zeros");
        report(RENAME(sparse_insert_block_double)(a, block, 3, 1, 5, 0) ==
                   sparse_insert_block_double(b, block, 3, 1, 5, 0),
               "a double block outside the matrix", "the same status");
        report(RENAME(sparse_get_block_dimension_for_row)(a, 3) == sparse_get_block_dimension_for_row(b, 3) &&
                   RENAME(sparse_get_block_dimension_for_col)(a, 2) == sparse_get_block_dimension_for_col(b, 2),
               "a double block matrix's block dimensions", "the same on both sides");
        RENAME(sparse_matrix_destroy)(a); sparse_matrix_destroy(b);
    }
    {
        double v[5] = {1, 2, 3, 4, 5};
        sparse_index rows[5] = {0, 0, 1, 2, 3}, columns[5] = {1, 2, 0, 2, 1};
        Pair p = pointwise(4, 4, 5, v, rows, columns, 1);
        for (sparse_index column = 0; column < 4; column++) {
            for (sparse_index start = 0; start < 4; start++) {
                double back[4] = {9, 9, 9, 9}, other[4] = {9, 9, 9, 9};
                sparse_index mi[4] = {9, 9, 9, 9}, ti[4] = {9, 9, 9, 9};
                sparse_index me = 0, te = 0;
                long got = RENAME(sparse_extract_sparse_column_double)((sparse_matrix_double)p.mine, column, start, &me, 4, back, mi);
                long want = sparse_extract_sparse_column_double((sparse_matrix_double)p.theirs, column, start, &te, 4, other, ti);
                int ok = got == want && me == te;
                for (int k = 0; k < 4; k++) ok = ok && mi[k] == ti[k] && same_doubles(back, other, 4, 1e-12, "an entry");
                report(ok, "a double column extracted", "the count, the end and every value");
            }
        }
        RENAME(sparse_matrix_destroy)(p.mine); sparse_matrix_destroy(p.theirs);
    }
    {
        double x[3] = {1, 0, 3}, y[2] = {4, 2};
        sparse_index ix[3] = {0, 2, 3}, iy[2] = {1, 3};
        for (sparse_dimension nzx = 0; nzx <= 3; nzx++) {
            double mine = RENAME(sparse_inner_product_sparse_double)(nzx, 2, x, ix, y, iy);
            double theirs = sparse_inner_product_sparse_double(nzx, 2, x, ix, y, iy);
            report(same_double(mine, theirs, 1e-12), "a double inner product of two sparse vectors",
                   "the same value");
        }
        for (sparse_stride stride = 1; stride <= 2; stride++) {
            double buffer[12] = {0, 9, 2, 9, 0, 4, 5, 9, 0, 9, 0, 0};
            report(RENAME(sparse_get_vector_nonzero_count_double)(6, buffer, stride) ==
                       sparse_get_vector_nonzero_count_double(6, buffer, stride),
                   "a double nonzero count", "the same count, over a buffer of N * stride elements");
        }
        double v[6] = {0, 2, 0, 4, 5, 0};
        for (sparse_dimension nz = 0; nz <= 5; nz++) {
            double back[5], other[5];
            sparse_index mi[5], ti[5];
            memset(back, 0, sizeof(back));
            memset(other, 0, sizeof(other));
            memset(mi, 0, sizeof(mi));
            memset(ti, 0, sizeof(ti));
            long got = RENAME(sparse_pack_vector_double)(6, nz, v, 1, back, mi);
            long want = sparse_pack_vector_double(6, nz, v, 1, other, ti);
            int ok = got == want;
            for (int k = 0; k < 5; k++) ok = ok && mi[k] == ti[k] && same_doubles(back, other, 5, 1e-12, "a packed value");
            report(ok, "a double packed vector", "the count, every value and every index");
        }
        for (int zero = 0; zero <= 1; zero++) {
            double back[6], other[6];
            for (int k = 0; k < 6; k++) back[k] = other[k] = 1;
            RENAME(sparse_unpack_vector_double)(6, 2, zero, (double[]){7, 8}, (sparse_index[]){1, 4}, back, 1);
            sparse_unpack_vector_double(6, 2, zero, (double[]){7, 8}, (sparse_index[]){1, 4}, other, 1);
            report(same_doubles(back, other, 6, 1e-12, "an unpacked value"), "a double unpacked vector",
                   "every element");
        }
    }
    {
        double v[4] = {1, 2, 3, 4};
        sparse_index rows[4] = {0, 0, 1, 1}, columns[4] = {0, 1, 0, 1};
        Pair A = pointwise(2, 2, 4, v, rows, columns, 1);
        double x[2] = {1, 2};
        for (int tr = 0; tr < 2; tr++) {
            for (int alpha = 0; alpha <= 2; alpha++) {
                double a1[2] = {1, 1}, a2[2] = {1, 1};
                sparse_status ma = RENAME(sparse_matrix_vector_product_dense_double)(
                    (enum CBLAS_TRANSPOSE)(tr ? 112 : 111), alpha, (sparse_matrix_double)A.mine, x, 1, a1, 1);
                sparse_status mb = sparse_matrix_vector_product_dense_double((enum CBLAS_TRANSPOSE)(tr ? 112 : 111), alpha,
                                                                                 (sparse_matrix_double)A.theirs, x, 1, a2, 1);
                report(ma == mb && same_doubles(a1, a2, 2, 1e-12, "x"), "a double matrix-vector product, both transposes",
                       "the same status and every element");
            }
        }
        RENAME(sparse_matrix_destroy)(A.mine); sparse_matrix_destroy(A.theirs);
    }
    {
        double v[4] = {2, 1, 3, 4};
        sparse_index rows[4] = {0, 1, 1, 2}, columns[4] = {0, 0, 1, 2};
        Pair a = pointwise(3, 3, 4, v, rows, columns, 1), b = pointwise(3, 3, 4, v, rows, columns, 1);
        RENAME(sparse_set_matrix_property)(a.mine, SPARSE_LOWER_TRIANGULAR);
        sparse_set_matrix_property(b.theirs, SPARSE_LOWER_TRIANGULAR);
        for (int tr = 0; tr < 2; tr++) {
            for (int alpha = 1; alpha <= 2; alpha++) {
                double c1[3] = {2, 5, 4}, c2[3] = {2, 5, 4};
                sparse_status ma = RENAME(sparse_vector_triangular_solve_dense_double)(
                    (enum CBLAS_TRANSPOSE)(tr ? 112 : 111), alpha, (sparse_matrix_double)a.mine, c1, 1);
                sparse_status mb = sparse_vector_triangular_solve_dense_double((enum CBLAS_TRANSPOSE)(tr ? 112 : 111), alpha,
                                                                                 (sparse_matrix_double)b.theirs, c2, 1);
                report(ma == mb && same_doubles(c1, c2, 3, 1e-12, "x"),
                       "a double triangular solve of a vector, both transposes", "the same status and every element");
                for (int order = 0; order < 2; order++) {
                    for (sparse_dimension ldb = 3; ldb <= 5; ldb++) {
                        double d1[16], d2[16];
                        for (int k = 0; k < 16; k++) d1[k] = d2[k] = (double)(k + 1);
                        ma = RENAME(sparse_matrix_triangular_solve_dense_double)((enum CBLAS_ORDER)(order ? 102 : 101),
                                                                                 (enum CBLAS_TRANSPOSE)(tr ? 112 : 111), 2,
                                                                                 1.5, (sparse_matrix_double)a.mine, d1, ldb);
                        mb = sparse_matrix_triangular_solve_dense_double((enum CBLAS_ORDER)(order ? 102 : 101),
                                                                          (enum CBLAS_TRANSPOSE)(tr ? 112 : 111), 2, 1.5,
                                                                          (sparse_matrix_double)b.theirs, d2, ldb);
                        snprintf(detail, sizeof detail, "order %d trans %d ldb %llu: port %d host %d", order, tr,
                                 (unsigned long long)ldb, ma, mb);
                        report(ma == mb && same_doubles(d1, d2, 16, 1e-12, "x"),
                               "a double triangular solve of a matrix, both layouts and transposes", detail);
                    }
                }
            }
        }
        RENAME(sparse_matrix_destroy)(a.mine); sparse_matrix_destroy(b.theirs);
    }
    {
        double x[2] = {1, 2}, y[3] = {3, 4, 5};
        sparse_index indy[2] = {0, 2};
        sparse_matrix_double a = NULL, b = NULL;
        sparse_status ma = RENAME(sparse_outer_product_dense_double)(2, 3, 2, 2.0, x, 1, y, indy, &a);
        sparse_status mb = sparse_outer_product_dense_double(2, 3, 2, 2.0, x, 1, y, indy, &b);
        int ok = ma == mb;
        if (ok && a && b && RENAME(sparse_get_matrix_nonzero_count)(a) > 0) {
            compare_matrix("a double outer product, the matrix", (Pair){a, b}, 2, 3, 1);
        }
        snprintf(detail, sizeof detail, "port %d, host %d", ma, mb);
        report(ok, "a double outer product", detail);
        if (a) RENAME(sparse_matrix_destroy)(a);
        if (b) sparse_matrix_destroy(b);
        a = NULL; b = NULL;
        ma = RENAME(sparse_outer_product_dense_double)(2, 3, 4, 1.0, x, 1, y, (sparse_index[]){0, 1, 2, 3}, &a);
        mb = sparse_outer_product_dense_double(2, 3, 4, 1.0, x, 1, y, (sparse_index[]){0, 1, 2, 3}, &b);
        snprintf(detail, sizeof detail, "port %d, host %d", ma, mb);
        report(ma == mb && a == NULL && b == NULL, "a double outer product with more nonzeros than columns", detail);
        if (a) RENAME(sparse_matrix_destroy)(a);
        if (b) sparse_matrix_destroy(b);
    }
    {
        double v[6] = {1.1, 2.2, 3.3, 4.4, 5.5, 6.6};
        sparse_index rows[6] = {0, 0, 0, 1, 1, 1}, columns[6] = {0, 1, 2, 0, 1, 2};
        sparse_index colPerms[4][3] = {{2, 0, 1}, {1, 0, 2}, {0, 1, 2}, {0, 0, 0}};
        for (int k = 0; k < 4; k++) {
            Pair a = pointwise(2, 3, 6, v, rows, columns, 1);
            sparse_status ma = RENAME(sparse_permute_cols_double)((sparse_matrix_double)a.mine, colPerms[k]);
            sparse_status mb = sparse_permute_cols_double((sparse_matrix_double)a.theirs, colPerms[k]);
            report(ma == mb, "a double column permutation", "the same status");
            compare_matrix("a double column permutation, the matrix", a, 2, 3, 1);
            RENAME(sparse_matrix_destroy)(a.mine); sparse_matrix_destroy(a.theirs);
        }
        sparse_index rowPerms[3][2] = {{1, 0}, {0, 0}, {0, 1}};
        for (int k = 0; k < 3; k++) {
            Pair a = pointwise(2, 3, 6, v, rows, columns, 1);
            sparse_status ma = RENAME(sparse_permute_rows_double)((sparse_matrix_double)a.mine, rowPerms[k]);
            sparse_status mb = sparse_permute_rows_double((sparse_matrix_double)a.theirs, rowPerms[k]);
            report(ma == mb, "a double row permutation", "the same status");
            compare_matrix("a double row permutation, the matrix", a, 2, 3, 1);
            RENAME(sparse_matrix_destroy)(a.mine); sparse_matrix_destroy(a.theirs);
        }
    }
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    creation();
    properties();
    insertion();
    extraction();
    vectors();
    level2();
    outer();
    permutations();
    norms_and_trace();
    level3();
    theDoubleProduct();
    theSixteen();
    printf("%d checks, %d failures\n", checks, failures);
    return failures ? 1 : 0;
}
