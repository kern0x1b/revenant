// What the host's own Accelerate answers for the sparse_* family of vecLib/Sparse/BLAS.h.
//
// A discovery probe, not a check. Every line is one measured case; tests/backports/host/sparseblas
// differential.m then runs the port's own SparseBLAS9.m through the same cases and compares. The
// cases that end the process (an invalid transpose reaches the release's cblas_xerbla, which exits)
// are each asked in a child, with a case name, so the probe can print the host's own exit status
// and message for them rather than dying in the middle of the rest.
//
// Usage: probe [case-name ...]   - with names, only those cases run. No names runs every safe case.

#import <Accelerate/Accelerate.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

#define P(...) printf(__VA_ARGS__)

static const char *only[64];
static int only_count;
static int checks;

static int wanted(const char *name)
{
    if (only_count == 0) return 1;
    for (int k = 0; k < only_count; k++)
        if (strcmp(only[k], name) == 0) return 1;
    return 0;
}

#define CASE(name) int run_##name(void)

// The matrix reader: one value at a time through the host's own extract, so nothing here knows
// anything about a layout of ours.
static long extract_row(sparse_matrix_float A, sparse_index i, sparse_index from, float *val, sparse_index *ind, long cap)
{
    sparse_index end = 0;
    long got = sparse_extract_sparse_row_float(A, i, from, &end, cap, val, ind);
    return got > 0 ? got : 0;
}

static void dumpf(sparse_matrix_float A, sparse_dimension M, sparse_dimension N, float *dst)
{
    memset(dst, 0, M * N * sizeof(float));
    for (sparse_dimension i = 0; i < M; i++) {
        sparse_index c = 0;
        float v = 0;
        sparse_index j = 0;
        while (c < (sparse_index)N) {
            sparse_index e = 0;
            if (sparse_extract_sparse_row_float(A, (sparse_index)i, c, &e, 1, &v, &j) != 1) { c++; continue; }
            if (j < (sparse_index)N) dst[i * N + j] = v;
            if (e <= c) c = c + 1; else c = e;
        }
    }
}

static void print_matrix(const char *tag, sparse_matrix_float A, sparse_dimension M, sparse_dimension N)
{
    float *d = calloc(M * N ? M * N : 1, sizeof(float));
    dumpf(A, M, N, d);
    P("%s:", tag);
    for (sparse_dimension k = 0; k < M * N; k++) P(" %g", d[k]);
    P("\n");
    free(d);
}

// A 3x3 point-wise matrix, [[1,0,2],[0,3,0],[4,0,0]].
static sparse_matrix_float make3(void)
{
    sparse_matrix_float A = sparse_matrix_create_float(3, 3);
    sparse_insert_entry_float(A, 1, 0, 0);
    sparse_insert_entry_float(A, 2, 0, 2);
    sparse_insert_entry_float(A, 3, 1, 1);
    sparse_insert_entry_float(A, 4, 2, 0);
    return A;
}

// A 3x3 lower triangular matrix, [[2,0,0],[1,3,0],[0,0,4]].
static sparse_matrix_float makelow(void)
{
    sparse_matrix_float L = sparse_matrix_create_float(3, 3);
    sparse_set_matrix_property(L, SPARSE_LOWER_TRIANGULAR);
    sparse_insert_entry_float(L, 2, 0, 0);
    sparse_insert_entry_float(L, 1, 1, 0);
    sparse_insert_entry_float(L, 3, 1, 1);
    sparse_insert_entry_float(L, 4, 2, 2);
    return L;
}

// ---------------------------------------------------------------- creation and shape

CASE(create_pointwise)
{
    P("create(0,5) null? %d\n", sparse_matrix_create_float(0, 5) == NULL);
    P("create(5,0) null? %d\n", sparse_matrix_create_float(5, 0) == NULL);
    P("create(0,0) null? %d\n", sparse_matrix_create_float(0, 0) == NULL);
    P("create(1,1) null? %d\n", sparse_matrix_create_float(1, 1) == NULL);
    sparse_matrix_float A = sparse_matrix_create_float(4, 3);
    P("create(4,3): rows=%llu cols=%llu nz=%ld\n", (unsigned long long)sparse_get_matrix_number_of_rows(A),
      (unsigned long long)sparse_get_matrix_number_of_columns(A), sparse_get_matrix_nonzero_count(A));
    sparse_matrix_destroy(A);
    sparse_matrix_float D = sparse_matrix_create_double(4, 3);
    P("create_d(4,3): rows=%llu cols=%llu nz=%ld\n", (unsigned long long)sparse_get_matrix_number_of_rows(D),
      (unsigned long long)sparse_get_matrix_number_of_columns(D), sparse_get_matrix_nonzero_count(D));
    sparse_matrix_destroy(D);
    A = sparse_matrix_create_float(0, 5);
    P("create(0,5): rows=%llu cols=%llu\n", (unsigned long long)sparse_get_matrix_number_of_rows(A),
      (unsigned long long)sparse_get_matrix_number_of_columns(A));
    if (A) sparse_matrix_destroy(A);
    A = sparse_matrix_create_float(5, 0);
    P("create(5,0): rows=%llu cols=%llu\n", (unsigned long long)sparse_get_matrix_number_of_rows(A),
      (unsigned long long)sparse_get_matrix_number_of_columns(A));
    if (A) sparse_matrix_destroy(A);
    return 0;
}

CASE(create_block)
{
    P("block(0,3,2,2) null? %d\n", sparse_matrix_block_create_float(0, 3, 2, 2) == NULL);
    P("block(3,3,0,2) null? %d\n", sparse_matrix_block_create_float(3, 3, 0, 2) == NULL);
    P("block(3,3,2,0) null? %d\n", sparse_matrix_block_create_float(3, 3, 2, 0) == NULL);
    sparse_matrix_float A = sparse_matrix_block_create_float(3, 3, 2, 2);
    P("block(3,3,2,2): rows=%llu cols=%llu\n", (unsigned long long)sparse_get_matrix_number_of_rows(A),
      (unsigned long long)sparse_get_matrix_number_of_columns(A));
    P("  blkdim row 0..3 = %ld %ld %ld %ld, col 0..3 = %ld %ld %ld %ld\n",
      sparse_get_block_dimension_for_row(A, 0), sparse_get_block_dimension_for_row(A, 1),
      sparse_get_block_dimension_for_row(A, 2), sparse_get_block_dimension_for_row(A, 3),
      sparse_get_block_dimension_for_col(A, 0), sparse_get_block_dimension_for_col(A, 1),
      sparse_get_block_dimension_for_col(A, 2), sparse_get_block_dimension_for_col(A, 3));
    sparse_matrix_destroy(A);
    P("blockdim out of range row=%ld col=%ld\n", sparse_get_block_dimension_for_row(sparse_matrix_block_create_float(2, 2, 3, 3), 7),
      sparse_get_block_dimension_for_col(sparse_matrix_block_create_float(2, 2, 3, 3), 7));
    sparse_matrix_float Pt = sparse_matrix_create_float(2, 2);
    P("pointwise blkdim row0=%ld col0=%ld\n", sparse_get_block_dimension_for_row(Pt, 0), sparse_get_block_dimension_for_col(Pt, 0));
    sparse_matrix_destroy(Pt);
    return 0;
}

CASE(create_varblock)
{
    sparse_dimension K[3] = {2, 1, 3}, L[3] = {1, 2, 1};
    sparse_matrix_float V = sparse_matrix_variable_block_create_float(3, 3, K, L);
    P("varblock(3,3,{2,1,3},{1,2,1}) null? %d\n", V == NULL);
    if (V) {
        P("  rows=%llu cols=%llu\n", (unsigned long long)sparse_get_matrix_number_of_rows(V),
          (unsigned long long)sparse_get_matrix_number_of_columns(V));
        P("  blkdim row 0..2 = %ld %ld %ld, col 0..2 = %ld %ld %ld\n",
          sparse_get_block_dimension_for_row(V, 0), sparse_get_block_dimension_for_row(V, 1), sparse_get_block_dimension_for_row(V, 2),
          sparse_get_block_dimension_for_col(V, 0), sparse_get_block_dimension_for_col(V, 1), sparse_get_block_dimension_for_col(V, 2));
        sparse_matrix_destroy(V);
    }
    P("varblock(0,3,...) null? %d\n", sparse_matrix_variable_block_create_float(0, 3, K, L) == NULL);
    P("varblock with a 0 in K null? %d\n",
      sparse_matrix_variable_block_create_float(3, 3, (sparse_dimension[]){2, 1, 0}, L) == NULL);
    P("varblock with a 0 in L null? %d\n",
      sparse_matrix_variable_block_create_float(3, 3, K, (sparse_dimension[]){1, 0, 1}) == NULL);
    P("varblock(1,1,{5},{7}) rows=%llu cols=%llu blkdim=%ld,%ld\n",
      (unsigned long long)sparse_get_matrix_number_of_rows(sparse_matrix_variable_block_create_float(1, 1, (sparse_dimension[]){5}, (sparse_dimension[]){7})),
      (unsigned long long)sparse_get_matrix_number_of_columns(sparse_matrix_variable_block_create_float(1, 1, (sparse_dimension[]){5}, (sparse_dimension[]){7})),
      sparse_get_block_dimension_for_row(sparse_matrix_variable_block_create_float(1, 1, (sparse_dimension[]){5}, (sparse_dimension[]){7}), 0),
      sparse_get_block_dimension_for_col(sparse_matrix_variable_block_create_float(1, 1, (sparse_dimension[]){5}, (sparse_dimension[]){7}), 0));
    return 0;
}

CASE(properties)
{
    sparse_matrix_float A = sparse_matrix_create_float(3, 3);
    P("get before set: up=%ld lo=%ld us=%ld ls=%ld\n", sparse_get_matrix_property(A, SPARSE_UPPER_TRIANGULAR),
      sparse_get_matrix_property(A, SPARSE_LOWER_TRIANGULAR), sparse_get_matrix_property(A, SPARSE_UPPER_SYMMETRIC),
      sparse_get_matrix_property(A, SPARSE_LOWER_SYMMETRIC));
    P("set upper = %d\n", sparse_set_matrix_property(A, SPARSE_UPPER_TRIANGULAR));
    P("get after set upper: up=%ld lo=%ld\n", sparse_get_matrix_property(A, SPARSE_UPPER_TRIANGULAR),
      sparse_get_matrix_property(A, SPARSE_LOWER_TRIANGULAR));
    P("set lower = %d, now up=%ld lo=%ld\n", sparse_set_matrix_property(A, SPARSE_LOWER_TRIANGULAR),
      sparse_get_matrix_property(A, SPARSE_UPPER_TRIANGULAR), sparse_get_matrix_property(A, SPARSE_LOWER_TRIANGULAR));
    P("set upper again = %d\n", sparse_set_matrix_property(A, SPARSE_UPPER_TRIANGULAR));
    P("set lower symmetric = %d, get us=%ld ls=%ld\n", sparse_set_matrix_property(A, SPARSE_LOWER_SYMMETRIC),
      sparse_get_matrix_property(A, SPARSE_UPPER_SYMMETRIC), sparse_get_matrix_property(A, SPARSE_LOWER_SYMMETRIC));
    P("set 0 = %d, set 3 = %d, set 99 = %d, set -1 = %d\n", sparse_set_matrix_property(sparse_matrix_create_float(2, 2), 0),
      sparse_set_matrix_property(sparse_matrix_create_float(2, 2), 3),
      sparse_set_matrix_property(sparse_matrix_create_float(2, 2), 99),
      sparse_set_matrix_property(sparse_matrix_create_float(2, 2), -1));
    P("get 0 = %ld, get 99 = %ld, get -1 = %ld\n", sparse_get_matrix_property(sparse_matrix_create_float(2, 2), 0),
      sparse_get_matrix_property(sparse_matrix_create_float(2, 2), 99), sparse_get_matrix_property(sparse_matrix_create_float(2, 2), -1));
    P("set on NULL = %d, get on NULL = %ld\n", sparse_set_matrix_property(NULL, SPARSE_UPPER_TRIANGULAR),
      sparse_get_matrix_property(NULL, SPARSE_UPPER_TRIANGULAR));
    P("rows on NULL=%llu cols on NULL=%llu nz on NULL=%ld nzrow=%ld nzcol=%ld\n",
      (unsigned long long)sparse_get_matrix_number_of_rows(NULL), (unsigned long long)sparse_get_matrix_number_of_columns(NULL),
      sparse_get_matrix_nonzero_count(NULL), sparse_get_matrix_nonzero_count_for_row(NULL, 0), sparse_get_matrix_nonzero_count_for_column(NULL, 0));
    sparse_matrix_float S = sparse_matrix_create_float(2, 2);
    P("nzrow out of range=%ld nzcol out of range=%ld nzrow negative=%ld\n",
      sparse_get_matrix_nonzero_count_for_row(S, 5), sparse_get_matrix_nonzero_count_for_column(S, 5),
      sparse_get_matrix_nonzero_count_for_row(S, -1));
    P("commit on NULL=%d, destroy on NULL=%d\n", sparse_commit(NULL), sparse_matrix_destroy(NULL));
    sparse_matrix_destroy(A);
    return 0;
}

CASE(insert_point)
{
    sparse_matrix_float A = sparse_matrix_create_float(4, 4);
    P("insert 0.0 at (1,1) = %d nz=%ld\n", sparse_insert_entry_float(A, 0.0f, 1, 1), sparse_get_matrix_nonzero_count(A));
    P("insert 2.0 at (1,1) = %d nz=%ld\n", sparse_insert_entry_float(A, 2.0f, 1, 1), sparse_get_matrix_nonzero_count(A));
    P("insert 3.0 at (1,1) = %d nz=%ld\n", sparse_insert_entry_float(A, 3.0f, 1, 1), sparse_get_matrix_nonzero_count(A));
    P("insert 5.0 at (0,3) = %d nz=%ld\n", sparse_insert_entry_float(A, 5.0f, 0, 3), sparse_get_matrix_nonzero_count(A));
    P("insert -1.5 at (3,0) = %d nz=%ld\n", sparse_insert_entry_float(A, -1.5f, 3, 0), sparse_get_matrix_nonzero_count(A));
    print_matrix("matrix", A, 4, 4);
    P("nzrow 0..3 = %ld %ld %ld %ld\n", sparse_get_matrix_nonzero_count_for_row(A, 0), sparse_get_matrix_nonzero_count_for_row(A, 1),
      sparse_get_matrix_nonzero_count_for_row(A, 2), sparse_get_matrix_nonzero_count_for_row(A, 3));
    P("nzcol 0..3 = %ld %ld %ld %ld\n", sparse_get_matrix_nonzero_count_for_column(A, 0), sparse_get_matrix_nonzero_count_for_column(A, 1),
      sparse_get_matrix_nonzero_count_for_column(A, 2), sparse_get_matrix_nonzero_count_for_column(A, 3));
    float v[4]; sparse_index j[4];
    sparse_index end = 0;
    P("extract row1 from 0 = %ld end=%lld\n", (long)sparse_extract_sparse_row_float(A, 1, 0, &end, 4, v, j), (long long)end);
    end = 0;
    P("extract row0 from 0 = %ld end=%lld v0=%g j0=%lld\n", (long)sparse_extract_sparse_row_float(A, 0, 0, &end, 4, v, j), (long long)end, v[0], (long long)j[0]);
    end = 0;
    P("extract row0 from 1 = %ld end=%lld\n", (long)sparse_extract_sparse_row_float(A, 0, 1, &end, 4, v, j), (long long)end);
    end = 0;
    P("extract row0 from 3 = %ld end=%lld\n", (long)sparse_extract_sparse_row_float(A, 0, 3, &end, 4, v, j), (long long)end);
    end = 0;
    P("extract row0 from 4 = %ld end=%lld\n", (long)sparse_extract_sparse_row_float(A, 0, 4, &end, 4, v, j), (long long)end);
    end = 0;
    P("extract row0 from 5 = %ld end=%lld\n", (long)sparse_extract_sparse_row_float(A, 0, 5, &end, 4, v, j), (long long)end);
    end = 0;
    P("extract row0 from -1 = %ld end=%lld\n", (long)sparse_extract_sparse_row_float(A, 0, -1, &end, 4, v, j), (long long)end);
    end = 0;
    P("extract row9 from 0 = %ld end=%lld\n", (long)sparse_extract_sparse_row_float(A, 9, 0, &end, 4, v, j), (long long)end);
    end = 0;
    P("extract row0 nz=0 = %ld end=%lld\n", (long)sparse_extract_sparse_row_float(A, 0, 0, &end, 0, v, j), (long long)end);
    end = 0;
    P("extract empty row2 from 0 = %ld end=%lld\n", (long)sparse_extract_sparse_row_float(A, 2, 0, &end, 4, v, j), (long long)end);
    P("commit = %d\n", sparse_commit(A));
    P("nz after commit = %ld\n", sparse_get_matrix_nonzero_count(A));
    print_matrix("after commit", A, 4, 4);
    P("insert into a block matrix = %d\n", sparse_insert_entry_float(sparse_matrix_block_create_float(2, 2, 2, 2), 1, 0, 0));
    P("insert_block into a point-wise matrix = %d\n", sparse_insert_block_float(sparse_matrix_create_float(4, 4), (float[]){1, 2, 3, 4}, 2, 1, 0, 0));
    P("insert_entry into a block matrix = %d nz=%ld\n",
      sparse_insert_entry_float(sparse_matrix_block_create_float(2, 2, 2, 2), 1, 0, 0),
      sparse_get_matrix_nonzero_count(sparse_matrix_block_create_float(2, 2, 2, 2)));
    sparse_matrix_destroy(A);
    return 0;
}

CASE(insert_batch)
{
    sparse_matrix_float A = sparse_matrix_create_float(4, 4);
    float v[3] = {1, 2, 3};
    sparse_index i[3] = {0, 2, 1}, j[3] = {3, 0, 2};
    P("insert_entries(3) = %d nz=%ld\n", sparse_insert_entries_float(A, 3, v, i, j), sparse_get_matrix_nonzero_count(A));
    print_matrix("after entries", A, 4, 4);
    P("insert_entries(0) = %d nz=%ld\n", sparse_insert_entries_float(A, 0, v, i, j), sparse_get_matrix_nonzero_count(A));
    P("insert_col(0, 5,6 at 0,2) = %d nz=%ld\n", sparse_insert_col_float(A, 0, 2, (float[]){5, 6}, (sparse_index[]){0, 2}),
      sparse_get_matrix_nonzero_count(A));
    print_matrix("after col", A, 4, 4);
    P("insert_row(0, 7,8 at 1,2) = %d nz=%ld\n", sparse_insert_row_float(A, 0, 2, (float[]){7, 8}, (sparse_index[]){1, 2}),
      sparse_get_matrix_nonzero_count(A));
    print_matrix("after row", A, 4, 4);
    P("insert_col again on j=0 = %d nz=%ld\n", sparse_insert_col_float(A, 0, 1, (float[]){9}, (sparse_index[]){3}),
      sparse_get_matrix_nonzero_count(A));
    print_matrix("after col2", A, 4, 4);
    P("commit = %d\n", sparse_commit(A));
    print_matrix("after commit", A, 4, 4);
    sparse_matrix_destroy(A);

    sparse_matrix_float B = sparse_matrix_create_float(4, 4);
    P("insert_row(1, {1,2} at 0,1) = %d\n", sparse_insert_row_float(B, 1, 2, (float[]){1, 2}, (sparse_index[]){0, 1}));
    P("insert_row(1, {3,4} at 1,3) = %d nz=%ld\n", sparse_insert_row_float(B, 1, 2, (float[]){3, 4}, (sparse_index[]){1, 3}),
      sparse_get_matrix_nonzero_count(B));
    print_matrix("merged row1", B, 4, 4);
    P("insert_entries over an existing pair = %d nz=%ld\n",
      sparse_insert_entries_float(B, 1, (float[]){99}, (sparse_index[]){1}, (sparse_index[]){3}), sparse_get_matrix_nonzero_count(B));
    print_matrix("after overwrite", B, 4, 4);
    sparse_matrix_destroy(B);
    return 0;
}

CASE(insert_block)
{
    sparse_matrix_float A = sparse_matrix_block_create_float(2, 2, 2, 3);
    float blk[6] = {1, 2, 3, 4, 5, 6};
    P("insert_block(0,0) = %d nz=%ld\n", sparse_insert_block_float(A, blk, 3, 1, 0, 0), sparse_get_matrix_nonzero_count(A));
    P("rows=%llu cols=%llu\n", (unsigned long long)sparse_get_matrix_number_of_rows(A),
      (unsigned long long)sparse_get_matrix_number_of_columns(A));
    P("nzrow 0..3 = %ld %ld %ld %ld\n", sparse_get_matrix_nonzero_count_for_row(A, 0), sparse_get_matrix_nonzero_count_for_row(A, 1),
      sparse_get_matrix_nonzero_count_for_row(A, 2), sparse_get_matrix_nonzero_count_for_row(A, 3));
    P("nzcol 0..5 = %ld %ld %ld %ld %ld %ld\n", sparse_get_matrix_nonzero_count_for_column(A, 0),
      sparse_get_matrix_nonzero_count_for_column(A, 1), sparse_get_matrix_nonzero_count_for_column(A, 2),
      sparse_get_matrix_nonzero_count_for_column(A, 3), sparse_get_matrix_nonzero_count_for_column(A, 4),
      sparse_get_matrix_nonzero_count_for_column(A, 5));
    float out[6] = {0};
    P("extract_block(0,0, rs=3 cs=1) = %d ->", sparse_extract_block_float(A, 0, 0, 3, 1, out));
    for (int k = 0; k < 6; k++) P(" %g", out[k]);
    P("\n");
    memset(out, 0, sizeof(out));
    P("extract_block(0,0, rs=1 cs=3) = %d ->", sparse_extract_block_float(A, 0, 0, 1, 3, out));
    for (int k = 0; k < 6; k++) P(" %g", out[k]);
    P("\n");
    memset(out, 0, sizeof(out));
    P("extract_block(1,1) absent = %d ->", sparse_extract_block_float(A, 1, 1, 3, 1, out));
    for (int k = 0; k < 6; k++) P(" %g", out[k]);
    P("\n");
    P("extract_block on a point-wise matrix = %d\n", sparse_extract_block_float(sparse_matrix_create_float(4, 4), 0, 0, 2, 1, out));
    P("insert_block out of range = %d\n", sparse_insert_block_float(A, blk, 3, 1, 5, 0));
    print_matrix("block matrix", A, 4, 6);
    sparse_matrix_destroy(A);

    sparse_matrix_float V = sparse_matrix_variable_block_create_float(2, 2, (sparse_dimension[]){2, 1}, (sparse_dimension[]){2, 1});
    P("var insert_block(1,1) = %d\n", sparse_insert_block_float(V, (float[]){9}, 1, 1, 1, 1));
    P("var rows=%llu cols=%llu nz=%ld\n", (unsigned long long)sparse_get_matrix_number_of_rows(V),
      (unsigned long long)sparse_get_matrix_number_of_columns(V), sparse_get_matrix_nonzero_count(V));
    float vout[4] = {0};
    P("var extract_block(0,0, rs=2 cs=1) = %d ->", sparse_extract_block_float(V, 0, 0, 2, 1, vout));
    for (int k = 0; k < 4; k++) P(" %g", vout[k]);
    P("\n");
    P("var insert_block(0,0) = %d\n", sparse_insert_block_float(V, (float[]){1, 2, 3, 4}, 2, 1, 0, 0));
    print_matrix("var block matrix", V, 3, 3);
    sparse_matrix_destroy(V);
    return 0;
}

// ---------------------------------------------------------------- level 1

CASE(vector_level1)
{
    float x[4] = {1, 0, 3, 4};
    sparse_index ix[4] = {0, 2, 3, 3};
    P("inner nz=0 = %g\n", sparse_inner_product_dense_float(0, x, ix, (float[]){1, 2, 3, 4}, 1));
    P("inner nz=3 incy=1 = %g\n", sparse_inner_product_dense_float(3, x, ix, (float[]){1, 2, 3, 4}, 1));
    P("inner nz=4 incy=1 = %g\n", sparse_inner_product_dense_float(4, x, ix, (float[]){1, 2, 3, 4}, 1));
    P("inner nz=3 incy=2 = %g\n", sparse_inner_product_dense_float(3, x, ix, (float[]){1, 2, 3, 4, 5, 6}, 2));
    P("inner nz=3 incy=0 = %g\n", sparse_inner_product_dense_float(3, x, ix, (float[]){1, 2, 3, 4}, 0));
    P("inner nz=3 incy=-1 from the end = %g\n", sparse_inner_product_dense_float(3, x, ix, (float[]){1, 2, 3, 4}, -1));
    P("inner nz=3 incy=-2 from the end = %g\n", sparse_inner_product_dense_float(3, x, ix, (float[]){1, 2, 3, 4, 5, 6}, -2));
    P("inner_sparse(3,2) = %g\n", sparse_inner_product_sparse_float(3, 2, x, ix, (float[]){4, 2}, (sparse_index[]){1, 3}));
    P("inner_sparse(3,0) = %g\n", sparse_inner_product_sparse_float(3, 0, x, ix, (float[]){4, 2}, (sparse_index[]){1, 3}));
    P("inner_sparse(0,2) = %g\n", sparse_inner_product_sparse_float(0, 2, x, ix, (float[]){4, 2}, (sparse_index[]){1, 3}));
    P("inner_sparse(3,2) disjoint = %g\n", sparse_inner_product_sparse_float(3, 2, x, ix, (float[]){4, 2}, (sparse_index[]){5, 7}));
    float y[6] = {10, 20, 30, 40, 50, 60};
    sparse_vector_add_with_scale_dense_float(3, 2.0f, x, ix, y, 1);
    P("add_scale incy=1 -> %g %g %g %g %g %g\n", y[0], y[1], y[2], y[3], y[4], y[5]);
    float y2[6] = {10, 20, 30, 40, 50, 60};
    sparse_vector_add_with_scale_dense_float(3, 2.0f, x, ix, y2, 2);
    P("add_scale incy=2 -> %g %g %g %g %g %g\n", y2[0], y2[1], y2[2], y2[3], y2[4], y2[5]);
    float y3[6] = {10, 20, 30, 40, 50, 60};
    sparse_vector_add_with_scale_dense_float(3, 0.0f, x, ix, y3, 1);
    P("add_scale alpha=0 -> %g %g %g %g %g %g\n", y3[0], y3[1], y3[2], y3[3], y3[4], y3[5]);
    float y4[6] = {10, 20, 30, 40, 50, 60};
    sparse_vector_add_with_scale_dense_float(0, 2.0f, x, ix, y4, 1);
    P("add_scale nz=0 -> %g %g %g %g %g %g\n", y4[0], y4[1], y4[2], y4[3], y4[4], y4[5]);
    P("norm one=%g two=%g inf=%g r1=%g other=%g\n", sparse_vector_norm_float(3, x, ix, SPARSE_NORM_ONE),
      sparse_vector_norm_float(3, x, ix, SPARSE_NORM_TWO), sparse_vector_norm_float(3, x, ix, SPARSE_NORM_INF),
      sparse_vector_norm_float(3, x, ix, SPARSE_NORM_R1), sparse_vector_norm_float(3, x, ix, (sparse_norm)0));
    P("norm nz=0 one=%g two=%g inf=%g\n", sparse_vector_norm_float(0, x, ix, SPARSE_NORM_ONE),
      sparse_vector_norm_float(0, x, ix, SPARSE_NORM_TWO), sparse_vector_norm_float(0, x, ix, SPARSE_NORM_INF));
    P("norm of a negative vector one=%g two=%g inf=%g\n", sparse_vector_norm_float(3, (float[]){-1, -2, 3}, ix, SPARSE_NORM_ONE),
      sparse_vector_norm_float(3, (float[]){-1, -2, 3}, ix, SPARSE_NORM_TWO), sparse_vector_norm_float(3, (float[]){-1, -2, 3}, ix, SPARSE_NORM_INF));
    return 0;
}

CASE(utilities)
{
    float x[6] = {0, 2, 0, 4, 5, 0};
    P("vector_nonzero_count incy=1 = %ld\n", sparse_get_vector_nonzero_count_float(6, x, 1));
    P("vector_nonzero_count incy=2 = %ld\n", sparse_get_vector_nonzero_count_float(6, x, 2));
    P("vector_nonzero_count incy=-1 = %ld\n", sparse_get_vector_nonzero_count_float(6, x, -1));
    P("vector_nonzero_count incy=-2 = %ld\n", sparse_get_vector_nonzero_count_float(6, x, -2));
    P("vector_nonzero_count N=0 = %ld\n", sparse_get_vector_nonzero_count_float(0, x, 1));
    P("vector_nonzero_count all nonzero = %ld\n",
      sparse_get_vector_nonzero_count_float(3, (float[]){1, 2, 3}, 1));
    float y[4]; sparse_index iy[4];
    P("pack(6,3) = %ld ->", sparse_pack_vector_float(6, 3, x, 1, y, iy));
    for (int k = 0; k < 4; k++) P(" (%lld,%g)", (long long)iy[k], y[k]);
    P("\n");
    P("pack(6,5) = %ld ->", sparse_pack_vector_float(6, 5, x, 1, y, iy));
    for (int k = 0; k < 5; k++) P(" (%lld,%g)", (long long)iy[k], y[k]);
    P("\n");
    P("pack(6,0) = %ld\n", sparse_pack_vector_float(6, 0, x, 1, y, iy));
    P("pack(0,3) = %ld\n", sparse_pack_vector_float(0, 3, x, 1, y, iy));
    P("pack incy=2 = %ld ->", sparse_pack_vector_float(6, 3, x, 2, y, iy));
    for (int k = 0; k < 3; k++) P(" (%lld,%g)", (long long)iy[k], y[k]);
    P("\n");
    P("pack incy=-1 = %ld ->", sparse_pack_vector_float(6, 3, x, -1, y, iy));
    for (int k = 0; k < 3; k++) P(" (%lld,%g)", (long long)iy[k], y[k]);
    P("\n");
    float u[6] = {1, 1, 1, 1, 1, 1};
    sparse_unpack_vector_float(6, 2, false, (float[]){7, 8}, (sparse_index[]){1, 4}, u, 1);
    P("unpack zero=false -> %g %g %g %g %g %g\n", u[0], u[1], u[2], u[3], u[4], u[5]);
    sparse_unpack_vector_float(6, 2, true, (float[]){7, 8}, (sparse_index[]){1, 4}, u, 1);
    P("unpack zero=true -> %g %g %g %g %g %g\n", u[0], u[1], u[2], u[3], u[4], u[5]);
    for (int k = 0; k < 6; k++) u[k] = 1;
    sparse_unpack_vector_float(6, 0, true, (float[]){7, 8}, (sparse_index[]){1, 4}, u, 1);
    P("unpack nz=0 zero=true -> %g %g %g %g %g %g\n", u[0], u[1], u[2], u[3], u[4], u[5]);
    for (int k = 0; k < 6; k++) u[k] = 1;
    sparse_unpack_vector_float(6, 0, false, (float[]){7, 8}, (sparse_index[]){1, 4}, u, 1);
    P("unpack nz=0 zero=false -> %g %g %g %g %g %g\n", u[0], u[1], u[2], u[3], u[4], u[5]);
    for (int k = 0; k < 6; k++) u[k] = 1;
    sparse_unpack_vector_float(6, 2, true, (float[]){7, 8}, (sparse_index[]){1, 40}, u, 1);
    P("unpack index past N -> %g %g %g %g %g %g\n", u[0], u[1], u[2], u[3], u[4], u[5]);
    for (int k = 0; k < 6; k++) u[k] = 1;
    sparse_unpack_vector_float(6, 2, true, (float[]){7, 8}, (sparse_index[]){1, 1}, u, 1);
    P("unpack a repeated index -> %g %g %g %g %g %g\n", u[0], u[1], u[2], u[3], u[4], u[5]);
    for (int k = 0; k < 6; k++) u[k] = 1;
    sparse_unpack_vector_float(6, 2, true, (float[]){7, 8}, (sparse_index[]){1, 4}, u, 2);
    P("unpack incy=2 -> %g %g %g %g %g %g\n", u[0], u[1], u[2], u[3], u[4], u[5]);
    float w[12];
    for (int k = 0; k < 12; k++) w[k] = 1;
    sparse_unpack_vector_float(6, 2, true, (float[]){7, 8}, (sparse_index[]){1, 4}, w, -2);
    P("unpack incy=-2 over 12 -> %g %g %g %g %g %g | %g %g %g %g %g %g\n", w[0], w[1], w[2], w[3], w[4], w[5], w[6], w[7], w[8], w[9], w[10], w[11]);
    return 0;
}

// ---------------------------------------------------------------- level 2

CASE(level2)
{
    sparse_matrix_float A = make3();
    float x[3] = {1, 1, 1}, y[3] = {1, 1, 1};
    P("gemv no-trans = %d -> %g %g %g\n", sparse_matrix_vector_product_dense_float(CblasNoTrans, 1.0f, A, x, 1, y, 1), y[0], y[1], y[2]);
    y[0] = y[1] = y[2] = 0;
    P("gemv trans = %d -> %g %g %g\n", sparse_matrix_vector_product_dense_float(CblasTrans, 1.0f, A, x, 1, y, 1), y[0], y[1], y[2]);
    y[0] = y[1] = y[2] = 1;
    P("gemv alpha=0.5 = %d -> %g %g %g\n", sparse_matrix_vector_product_dense_float(CblasNoTrans, 0.5f, A, x, 1, y, 1), y[0], y[1], y[2]);
    y[0] = y[1] = y[2] = 1;
    P("gemv alpha=0 = %d -> %g %g %g\n", sparse_matrix_vector_product_dense_float(CblasNoTrans, 0.0f, A, x, 1, y, 1), y[0], y[1], y[2]);
    y[0] = y[1] = y[2] = 1;
    P("gemv alpha=-1 = %d -> %g %g %g\n", sparse_matrix_vector_product_dense_float(CblasNoTrans, -1.0f, A, x, 1, y, 1), y[0], y[1], y[2]);
    float xs[9] = {1, 2, 3, 4, 5, 6, 7, 8, 9}, ys[9] = {0};
    P("gemv incx=3 incy=3 = %d ->", sparse_matrix_vector_product_dense_float(CblasNoTrans, 1.0f, A, xs, 3, ys, 3));
    P(" %g %g %g", ys[0], ys[3], ys[6]);
    P("\n");
    float xt[3] = {1, 1, 1}, yt[3] = {0};
    P("gemv incx=-1 incy=-1 = %d ->", sparse_matrix_vector_product_dense_float(CblasNoTrans, 1.0f, A, xt, -1, yt, -1));
    P(" %g %g %g\n", yt[0], yt[1], yt[2]);
    P("gemv on an empty 3x3 = %d ->", sparse_matrix_vector_product_dense_float(CblasNoTrans, 1.0f, sparse_matrix_create_float(3, 3), x, 1, y, 1));
    P(" %g %g %g\n", y[0], y[1], y[2]);
    P("gemv on a 0x0 = %d\n", sparse_matrix_vector_product_dense_float(CblasNoTrans, 1.0f, sparse_matrix_create_float(0, 0), x, 1, y, 1));

    sparse_matrix_float L = makelow();
    float b[3] = {2, 4, 4};
    P("trsv lower = %d -> %g %g %g\n", sparse_vector_triangular_solve_dense_float(CblasNoTrans, 1.0f, L, b, 1), b[0], b[1], b[2]);
    float b2[3] = {2, 4, 4};
    P("trsv lower trans = %d -> %g %g %g\n", sparse_vector_triangular_solve_dense_float(CblasTrans, 1.0f, L, b2, 1), b2[0], b2[1], b2[2]);
    float b3[3] = {2, 4, 4};
    P("trsv alpha=2 = %d -> %g %g %g\n", sparse_vector_triangular_solve_dense_float(CblasNoTrans, 2.0f, L, b3, 1), b3[0], b3[1], b3[2]);
    float b4[3] = {2, 4, 4};
    P("trsv alpha=0 = %d -> %g %g %g\n", sparse_vector_triangular_solve_dense_float(CblasNoTrans, 0.0f, L, b4, 1), b4[0], b4[1], b4[2]);
    float b5[3] = {2, 4, 4};
    P("trsv on a non-triangular matrix = %d -> %g %g %g\n", sparse_vector_triangular_solve_dense_float(CblasNoTrans, 1.0f, A, b5, 1), b5[0], b5[1], b5[2]);
    float b6[3] = {2, 4, 4};
    P("trsv on a matrix with no property = %d -> %g %g %g\n",
      sparse_vector_triangular_solve_dense_float(CblasNoTrans, 1.0f, sparse_matrix_create_float(3, 3), b6, 1), b6[0], b6[1], b6[2]);
    float b7[3] = {2, 4, 4};
    P("trsv incx=-1 = %d -> %g %g %g\n", sparse_vector_triangular_solve_dense_float(CblasNoTrans, 1.0f, L, b7, -1), b7[0], b7[1], b7[2]);
    sparse_matrix_float U = sparse_matrix_create_float(3, 3);
    sparse_set_matrix_property(U, SPARSE_UPPER_TRIANGULAR);
    sparse_insert_entry_float(U, 2, 0, 0);
    sparse_insert_entry_float(U, 3, 0, 1);
    sparse_insert_entry_float(U, 1, 1, 1);
    sparse_insert_entry_float(U, 4, 2, 2);
    float b8[3] = {2, 5, 4};
    P("trsv upper = %d -> %g %g %g\n", sparse_vector_triangular_solve_dense_float(CblasNoTrans, 1.0f, U, b8, 1), b8[0], b8[1], b8[2]);
    float b9[3] = {2, 5, 4};
    P("trsv upper trans = %d -> %g %g %g\n", sparse_vector_triangular_solve_dense_float(CblasTrans, 1.0f, U, b9, 1), b9[0], b9[1], b9[2]);
    sparse_matrix_float S = sparse_matrix_create_float(2, 2);
    sparse_set_matrix_property(S, SPARSE_LOWER_TRIANGULAR);
    sparse_insert_entry_float(S, 0, 0, 0);
    sparse_insert_entry_float(S, 1, 1, 1);
    float b10[2] = {1, 1};
    P("trsv with a zero pivot = %d -> %g %g\n", sparse_vector_triangular_solve_dense_float(CblasNoTrans, 1.0f, S, b10, 1), b10[0], b10[1]);
    sparse_matrix_destroy(S);
    sparse_matrix_destroy(U);
    sparse_matrix_destroy(L);
    sparse_matrix_destroy(A);
    return 0;
}

// ---------------------------------------------------------------- norms, trace, permutations, outer

CASE(norms)
{
    sparse_matrix_float A = sparse_matrix_create_float(2, 3);
    sparse_insert_entry_float(A, -1, 0, 0);
    sparse_insert_entry_float(A, 2, 0, 1);
    sparse_insert_entry_float(A, -3, 0, 2);
    sparse_insert_entry_float(A, 4, 1, 0);
    sparse_insert_entry_float(A, -5, 1, 2);
    P("elementwise one=%g two=%g inf=%g r1=%g other=%g neg=%d\n", sparse_elementwise_norm_float(A, SPARSE_NORM_ONE),
      sparse_elementwise_norm_float(A, SPARSE_NORM_TWO), sparse_elementwise_norm_float(A, SPARSE_NORM_INF),
      sparse_elementwise_norm_float(A, SPARSE_NORM_R1), sparse_elementwise_norm_float(A, (sparse_norm)999), (int)sparse_elementwise_norm_float(A, (sparse_norm)-1));
    P("operator one=%g two=%g inf=%g r1=%g other=%g\n", sparse_operator_norm_float(A, SPARSE_NORM_ONE),
      sparse_operator_norm_float(A, SPARSE_NORM_TWO), sparse_operator_norm_float(A, SPARSE_NORM_INF),
      sparse_operator_norm_float(A, SPARSE_NORM_R1), sparse_operator_norm_float(A, (sparse_norm)999));
    sparse_matrix_float E = sparse_matrix_create_float(3, 3);
    P("empty elementwise one=%g two=%g inf=%g r1=%g\n", sparse_elementwise_norm_float(E, SPARSE_NORM_ONE),
      sparse_elementwise_norm_float(E, SPARSE_NORM_TWO), sparse_elementwise_norm_float(E, SPARSE_NORM_INF),
      sparse_elementwise_norm_float(E, SPARSE_NORM_R1));
    P("empty operator one=%g two=%g inf=%g\n", sparse_operator_norm_float(E, SPARSE_NORM_ONE),
      sparse_operator_norm_float(E, SPARSE_NORM_TWO), sparse_operator_norm_float(E, SPARSE_NORM_INF));
    sparse_matrix_destroy(E);
    sparse_matrix_float Sq = sparse_matrix_create_float(2, 2);
    sparse_insert_entry_float(Sq, 3, 0, 0);
    sparse_insert_entry_float(Sq, 4, 1, 1);
    P("diagonal operator two=%g (max eigenvalue 4)\n", sparse_operator_norm_float(Sq, SPARSE_NORM_TWO));
    sparse_matrix_destroy(Sq);
    P("elementwise of a 0x0 = %g, operator of a 0x0 = %g\n",
      sparse_elementwise_norm_float(sparse_matrix_create_float(0, 0), SPARSE_NORM_ONE),
      sparse_operator_norm_float(sparse_matrix_create_float(0, 0), SPARSE_NORM_ONE));
    sparse_matrix_double D = sparse_matrix_create_double(2, 3);
    sparse_insert_entry_double(D, -1, 0, 0);
    sparse_insert_entry_double(D, 2, 0, 1);
    sparse_insert_entry_double(D, -3, 0, 2);
    sparse_insert_entry_double(D, 4, 1, 0);
    sparse_insert_entry_double(D, -5, 1, 2);
    P("double elementwise one=%g two=%g inf=%g r1=%g\n", sparse_elementwise_norm_double(D, SPARSE_NORM_ONE),
      sparse_elementwise_norm_double(D, SPARSE_NORM_TWO), sparse_elementwise_norm_double(D, SPARSE_NORM_INF),
      sparse_elementwise_norm_double(D, SPARSE_NORM_R1));
    P("double operator one=%g two=%g inf=%g r1=%g\n", sparse_operator_norm_double(D, SPARSE_NORM_ONE),
      sparse_operator_norm_double(D, SPARSE_NORM_TWO), sparse_operator_norm_double(D, SPARSE_NORM_INF),
      sparse_operator_norm_double(D, SPARSE_NORM_R1));
    sparse_matrix_destroy(D);
    sparse_matrix_destroy(A);
    return 0;
}

CASE(trace)
{
    sparse_matrix_float A = sparse_matrix_create_float(3, 4);
    sparse_insert_entry_float(A, 1, 0, 0);
    sparse_insert_entry_float(A, 2, 1, 1);
    sparse_insert_entry_float(A, 3, 2, 2);
    sparse_insert_entry_float(A, 4, 0, 1);
    sparse_insert_entry_float(A, 5, 1, 2);
    sparse_insert_entry_float(A, 6, 2, 3);
    sparse_index offs[7] = {0, 1, 2, 3, 4, -1, -2};
    for (int k = 0; k < 7; k++) P("trace offset %lld = %g\n", (long long)offs[k], sparse_matrix_trace_float(A, offs[k]));
    P("trace of an empty 2x2 = %g\n", sparse_matrix_trace_float(sparse_matrix_create_float(2, 2), 5));
    sparse_matrix_double D = sparse_matrix_create_double(3, 3);
    sparse_insert_entry_double(D, 1, 0, 0);
    sparse_insert_entry_double(D, 2, 1, 1);
    sparse_insert_entry_double(D, 4, 2, 2);
    sparse_insert_entry_double(D, 8, 0, 2);
    P("double trace 0=%g 2=%g 5=%g\n", sparse_matrix_trace_double(D, 0), sparse_matrix_trace_double(D, 2),
      sparse_matrix_trace_double(D, 5));
    sparse_matrix_destroy(D);
    sparse_matrix_destroy(A);
    return 0;
}

CASE(permute)
{
    sparse_matrix_float B = sparse_matrix_create_float(2, 3);
    float v[6] = {1, 2, 3, 4, 5, 6};
    sparse_insert_entries_float(B, 6, v, (sparse_index[]){0, 0, 0, 1, 1, 1}, (sparse_index[]){0, 1, 2, 0, 1, 2});
    print_matrix("before", B, 2, 3);
    P("permute_rows {1,0} = %d\n", sparse_permute_rows_float(B, (sparse_index[]){1, 0}));
    print_matrix("after rows", B, 2, 3);
    P("permute_rows {0,0} = %d\n", sparse_permute_rows_float(B, (sparse_index[]){0, 0}));
    print_matrix("after rows {0,0}", B, 2, 3);
    sparse_matrix_float C = sparse_matrix_create_float(2, 3);
    sparse_insert_entries_float(C, 6, v, (sparse_index[]){0, 0, 0, 1, 1, 1}, (sparse_index[]){0, 1, 2, 0, 1, 2});
    P("permute_cols {2,0,1} = %d\n", sparse_permute_cols_float(C, (sparse_index[]){2, 0, 1}));
    print_matrix("after cols", C, 2, 3);
    P("permute_cols identity = %d\n", sparse_permute_cols_float(C, (sparse_index[]){0, 1, 2}));
    print_matrix("after identity", C, 2, 3);
    P("permute_cols {0,0,0} = %d\n", sparse_permute_cols_float(C, (sparse_index[]){0, 0, 0}));
    print_matrix("after {0,0,0}", C, 2, 3);
    sparse_matrix_destroy(B);
    sparse_matrix_destroy(C);
    return 0;
}

CASE(outer)
{
    sparse_matrix_float C = NULL;
    P("outer(2,3,nz=2,alpha=2) = %d C=%s\n", sparse_outer_product_dense_float(2, 3, 2, 2.0f, (float[]){1, 1}, 1,
                                                                    (float[]){3, 4}, (sparse_index[]){0, 2}, &C),
          C ? "matrix" : "NULL");
    if (C) {
        P("  rows=%llu cols=%llu nz=%ld\n", (unsigned long long)sparse_get_matrix_number_of_rows(C),
          (unsigned long long)sparse_get_matrix_number_of_columns(C), sparse_get_matrix_nonzero_count(C));
        print_matrix("  outer", C, 2, 3);
        sparse_matrix_destroy(C);
    }
    sparse_matrix_float C2 = NULL;
    P("outer nz>N = %d C=%s\n", sparse_outer_product_dense_float(2, 3, 4, 1.0f, (float[]){1, 1}, 1, (float[]){3, 4, 5, 6},
                                                                 (sparse_index[]){0, 1, 2, 3}, &C2),
          C2 ? "matrix" : "NULL");
    if (C2) { print_matrix("  outer nz>N", C2, 2, 3); sparse_matrix_destroy(C2); }
    sparse_matrix_float C3 = NULL;
    P("outer nz=0 = %d C=%s\n", sparse_outer_product_dense_float(2, 3, 0, 1.0f, (float[]){1, 1}, 1, (float[]){0},
                                                                   (sparse_index[]){0}, &C3),
          C3 ? "matrix" : "NULL");
    if (C3) {
        P("  rows=%llu cols=%llu nz=%ld\n", (unsigned long long)sparse_get_matrix_number_of_rows(C3),
          (unsigned long long)sparse_get_matrix_number_of_columns(C3), sparse_get_matrix_nonzero_count(C3));
        sparse_matrix_destroy(C3);
    }
    sparse_matrix_float C4 = NULL;
    P("outer alpha=0 = %d C=%s\n", sparse_outer_product_dense_float(2, 3, 2, 0.0f, (float[]){1, 1}, 1, (float[]){3, 4},
                                                                     (sparse_index[]){0, 2}, &C4),
          C4 ? "matrix" : "NULL");
    if (C4) {
        P("  rows=%llu nz=%ld\n", (unsigned long long)sparse_get_matrix_number_of_rows(C4), sparse_get_matrix_nonzero_count(C4));
        print_matrix("  outer alpha=0", C4, 2, 3);
        sparse_matrix_destroy(C4);
    }
    sparse_matrix_float C5 = NULL;
    P("outer incx=2 = %d C=%s\n", sparse_outer_product_dense_float(2, 3, 2, 1.0f, (float[]){1, 2, 3, 4}, 2, (float[]){3, 4},
                                                                   (sparse_index[]){0, 2}, &C5),
          C5 ? "matrix" : "NULL");
    if (C5) { print_matrix("  outer incx=2", C5, 2, 3); sparse_matrix_destroy(C5); }
    sparse_matrix_double D = NULL;
    P("outer double = %d D=%s\n", sparse_outer_product_dense_double(2, 2, 2, 1.0, (double[]){1, 1}, 1, (double[]){5, 6},
                                                                     (sparse_index[]){1, 0}, &D),
          D ? "matrix" : "NULL");
    if (D) { print_matrix("  outer double", D, 2, 2); sparse_matrix_destroy(D); }
    return 0;
}

// ---------------------------------------------------------------- level 3

CASE(level3_dense)
{
    sparse_matrix_float A = sparse_matrix_create_float(2, 3);
    sparse_insert_entry_float(A, 1, 0, 0);
    sparse_insert_entry_float(A, 2, 0, 2);
    sparse_insert_entry_float(A, 3, 1, 1);
    sparse_insert_entry_float(A, 4, 1, 2);
    float B[6] = {1, 2, 3, 4, 5, 6};
    float C[4] = {0, 0, 0, 0};
    P("gemm row = %d ->", sparse_matrix_product_dense_float(CblasRowMajor, CblasNoTrans, 2, 1.0f, A, B, 3, C, 2));
    for (int k = 0; k < 4; k++) P(" %g", C[k]);
    P("\n");
    float C1[4] = {0, 0, 0, 0};
    P("gemm row trans = %d ->", sparse_matrix_product_dense_float(CblasRowMajor, CblasTrans, 2, 2.0f, A, B, 3, C1, 2));
    for (int k = 0; k < 4; k++) P(" %g", C1[k]);
    P("\n");
    float C2[4] = {7, 7, 7, 7};
    P("gemm adds into C = %d ->", sparse_matrix_product_dense_float(CblasRowMajor, CblasNoTrans, 2, 1.0f, A, B, 3, C2, 2));
    for (int k = 0; k < 4; k++) P(" %g", C2[k]);
    P("\n");
    float C3[4] = {0, 0, 0, 0};
    P("gemm colmajor = %d ->", sparse_matrix_product_dense_float(CblasColMajor, CblasNoTrans, 2, 1.0f, A, B, 3, C3, 2));
    for (int k = 0; k < 4; k++) P(" %g", C3[k]);
    P("\n");
    float C3t[4] = {0, 0, 0, 0};
    P("gemm colmajor trans = %d ->", sparse_matrix_product_dense_float(CblasColMajor, CblasTrans, 2, 1.0f, A, B, 3, C3t, 2));
    for (int k = 0; k < 4; k++) P(" %g", C3t[k]);
    P("\n");
    float C4[4] = {7, 7, 7, 7};
    P("gemm bad order = %d ->", sparse_matrix_product_dense_float((enum CBLAS_ORDER)9, CblasNoTrans, 2, 1.0f, A, B, 3, C4, 2));
    for (int k = 0; k < 4; k++) P(" %g", C4[k]);
    P("\n");
    float C5[4] = {7, 7, 7, 7};
    P("gemm ldb=1 < 3 = %d ->", sparse_matrix_product_dense_float(CblasRowMajor, CblasNoTrans, 2, 1.0f, A, B, 1, C5, 2));
    for (int k = 0; k < 4; k++) P(" %g", C5[k]);
    P("\n");
    float C6[4] = {7, 7, 7, 7};
    P("gemm ldb=2 < 3 = %d ->", sparse_matrix_product_dense_float(CblasRowMajor, CblasNoTrans, 2, 1.0f, A, B, 2, C6, 2));
    for (int k = 0; k < 4; k++) P(" %g", C6[k]);
    P("\n");
    float C7[4] = {7, 7, 7, 7};
    P("gemm ldc=1 < 2 = %d ->", sparse_matrix_product_dense_float(CblasRowMajor, CblasNoTrans, 2, 1.0f, A, B, 3, C7, 1));
    for (int k = 0; k < 4; k++) P(" %g", C7[k]);
    P("\n");
    float C8[4] = {7, 7, 7, 7};
    P("gemm n=0 = %d ->", sparse_matrix_product_dense_float(CblasRowMajor, CblasNoTrans, 0, 1.0f, A, B, 3, C8, 2));
    for (int k = 0; k < 4; k++) P(" %g", C8[k]);
    P("\n");
    float C9[6] = {0, 0, 0, 0, 0, 0};
    P("gemm n=3, ldb=3, ldc=3 = %d ->", sparse_matrix_product_dense_float(CblasRowMajor, CblasNoTrans, 3, 1.0f, A, B, 3, C9, 3));
    for (int k = 0; k < 6; k++) P(" %g", C9[k]);
    P("\n");
    float CA[12] = {1, 2, 3, 9, 4, 5, 6, 9, 7, 8, 9, 9};
    float C10[4] = {7, 7, 7, 7};
    P("gemm ldb=4 = %d ->", sparse_matrix_product_dense_float(CblasRowMajor, CblasNoTrans, 2, 1.0f, A, CA, 4, C10, 2));
    for (int k = 0; k < 4; k++) P(" %g", C10[k]);
    P("\n");
    float C11[4] = {0, 0, 0, 0};
    P("gemm alpha=-1.5 = %d ->", sparse_matrix_product_dense_float(CblasRowMajor, CblasNoTrans, 2, -1.5f, A, B, 3, C11, 2));
    for (int k = 0; k < 4; k++) P(" %g", C11[k]);
    P("\n");
    float C12[4] = {0, 0, 0, 0};
    P("gemm on an empty A = %d ->", sparse_matrix_product_dense_float(CblasRowMajor, CblasNoTrans, 2, 1.0f, sparse_matrix_create_float(2, 3), B, 3, C12, 2));
    for (int k = 0; k < 4; k++) P(" %g", C12[k]);
    P("\n");
    float CD[4] = {0, 0, 0, 0};
    P("gemm double row = %d ->", sparse_matrix_product_dense_double(CblasRowMajor, CblasNoTrans, 2, 0.5, A,
                                                                      (double[]){1, 2, 3, 4, 5, 6}, 3, CD, 2));
    for (int k = 0; k < 4; k++) P(" %g", CD[k]);
    P("\n");
    sparse_matrix_destroy(A);
    return 0;
}

CASE(level3_sparse)
{
    sparse_matrix_float A = sparse_matrix_create_float(2, 3);
    sparse_insert_entry_float(A, 1, 0, 0);
    sparse_insert_entry_float(A, 2, 0, 2);
    sparse_insert_entry_float(A, 3, 1, 1);
    sparse_insert_entry_float(A, 4, 1, 2);
    sparse_matrix_float S = sparse_matrix_create_float(3, 2);
    sparse_insert_entry_float(S, 1, 0, 0);
    sparse_insert_entry_float(S, 1, 0, 1);
    sparse_insert_entry_float(S, 1, 1, 0);
    sparse_insert_entry_float(S, 2, 2, 1);
    float C[4] = {0, 0, 0, 0};
    P("A x S row = %d ->", sparse_matrix_product_sparse_float(CblasRowMajor, CblasNoTrans, 1.0f, A, S, C, 2));
    for (int k = 0; k < 4; k++) P(" %g", C[k]);
    P("\n");
    float C1[4] = {0, 0, 0, 0};
    P("A x S row trans = %d ->", sparse_matrix_product_sparse_float(CblasRowMajor, CblasTrans, 1.0f, A, S, C1, 2));
    for (int k = 0; k < 4; k++) P(" %g", C1[k]);
    P("\n");
    float C2[4] = {0, 0, 0, 0};
    P("A x S col = %d ->", sparse_matrix_product_sparse_float(CblasColMajor, CblasNoTrans, 1.0f, A, S, C2, 2));
    for (int k = 0; k < 4; k++) P(" %g", C2[k]);
    P("\n");
    float C2t[4] = {0, 0, 0, 0};
    P("A x S col trans = %d ->", sparse_matrix_product_sparse_float(CblasColMajor, CblasTrans, 1.0f, A, S, C2t, 2));
    for (int k = 0; k < 4; k++) P(" %g", C2t[k]);
    P("\n");
    float C3[4] = {0, 0, 0, 0};
    P("A x S alpha=0.5 = %d ->", sparse_matrix_product_sparse_float(CblasRowMajor, CblasNoTrans, 0.5f, A, S, C3, 2));
    for (int k = 0; k < 4; k++) P(" %g", C3[k]);
    P("\n");
    float C4[4] = {0, 0, 0, 0};
    P("A x S alpha=0 = %d ->", sparse_matrix_product_sparse_float(CblasRowMajor, CblasNoTrans, 0.0f, A, S, C4, 2));
    for (int k = 0; k < 4; k++) P(" %g", C4[k]);
    P("\n");
    float C5[4] = {0, 0, 0, 0};
    P("A x S bad order = %d ->", sparse_matrix_product_sparse_float((enum CBLAS_ORDER)9, CblasNoTrans, 1.0f, A, S, C5, 2));
    for (int k = 0; k < 4; k++) P(" %g", C5[k]);
    P("\n");
    float C6[4] = {0, 0, 0, 0};
    P("A x A (inner 3 != 2) = %d ->", sparse_matrix_product_sparse_float(CblasRowMajor, CblasNoTrans, 1.0f, A, A, C6, 2));
    for (int k = 0; k < 4; k++) P(" %g", C6[k]);
    P("\n");
    float C7[4] = {0, 0, 0, 0};
    P("A x S ldc=1 = %d ->", sparse_matrix_product_sparse_float(CblasRowMajor, CblasNoTrans, 1.0f, A, S, C7, 1));
    for (int k = 0; k < 4; k++) P(" %g", C7[k]);
    P("\n");
    float C8[4] = {0, 0, 0, 0};
    P("A x empty S = %d ->", sparse_matrix_product_sparse_float(CblasRowMajor, CblasNoTrans, 1.0f, A, sparse_matrix_create_float(3, 2), C8, 2));
    for (int k = 0; k < 4; k++) P(" %g", C8[k]);
    P("\n");
    sparse_matrix_double Ad = sparse_matrix_create_double(1, 1);
    sparse_insert_entry_double(Ad, 6, 0, 0);
    double Cd[1] = {0};
    P("A x S double 1x1 = %d ->", sparse_matrix_product_sparse_double(CblasRowMajor, CblasNoTrans, 1.0, Ad, Ad, Cd, 1));
    P(" %g\n", Cd[0]);
    sparse_matrix_destroy(Ad);
    sparse_matrix_destroy(A);
    sparse_matrix_destroy(S);
    return 0;
}

CASE(level3_trsv)
{
    sparse_matrix_float L = makelow();
    float B[6] = {2, 1, 4, 1, 4, 2};
    P("mat trsv row = %d ->", sparse_matrix_triangular_solve_dense_float(CblasRowMajor, CblasNoTrans, 2, 1.0f, L, B, 2));
    for (int k = 0; k < 6; k++) P(" %g", B[k]);
    P("\n");
    float B1[6] = {2, 1, 4, 1, 4, 2};
    P("mat trsv col = %d ->", sparse_matrix_triangular_solve_dense_float(CblasColMajor, CblasNoTrans, 2, 1.0f, L, B1, 3));
    for (int k = 0; k < 6; k++) P(" %g", B1[k]);
    P("\n");
    float B2[6] = {2, 1, 4, 1, 4, 2};
    P("mat trsv col ldb=2 = %d ->", sparse_matrix_triangular_solve_dense_float(CblasColMajor, CblasNoTrans, 2, 1.0f, L, B2, 2));
    for (int k = 0; k < 6; k++) P(" %g", B2[k]);
    P("\n");
    float B3[6] = {2, 1, 4, 1, 4, 2};
    P("mat trsv row trans = %d ->", sparse_matrix_triangular_solve_dense_float(CblasRowMajor, CblasTrans, 2, 1.0f, L, B3, 2));
    for (int k = 0; k < 6; k++) P(" %g", B3[k]);
    P("\n");
    float B4[6] = {2, 1, 4, 1, 4, 2};
    P("mat trsv alpha=2 = %d ->", sparse_matrix_triangular_solve_dense_float(CblasRowMajor, CblasNoTrans, 2, 2.0f, L, B4, 2));
    for (int k = 0; k < 6; k++) P(" %g", B4[k]);
    P("\n");
    float B5[6] = {2, 1, 4, 1, 4, 2};
    P("mat trsv alpha=0 = %d ->", sparse_matrix_triangular_solve_dense_float(CblasRowMajor, CblasNoTrans, 2, 0.0f, L, B5, 2));
    for (int k = 0; k < 6; k++) P(" %g", B5[k]);
    P("\n");
    sparse_matrix_float A = make3();
    float B6[6] = {2, 1, 4, 1, 4, 2};
    P("mat trsv on a non-triangular matrix = %d ->", sparse_matrix_triangular_solve_dense_float(CblasRowMajor, CblasNoTrans, 2, 1.0f, A, B6, 2));
    for (int k = 0; k < 6; k++) P(" %g", B6[k]);
    P("\n");
    float B7[6] = {2, 1, 4, 1, 4, 2};
    P("mat trsv ldb=1 < 2 = %d ->", sparse_matrix_triangular_solve_dense_float(CblasRowMajor, CblasNoTrans, 2, 1.0f, L, B7, 1));
    for (int k = 0; k < 6; k++) P(" %g", B7[k]);
    P("\n");
    float B8[6] = {2, 1, 4, 1, 4, 2};
    P("mat trsv nrhs=0 = %d ->", sparse_matrix_triangular_solve_dense_float(CblasRowMajor, CblasNoTrans, 0, 1.0f, L, B8, 2));
    for (int k = 0; k < 6; k++) P(" %g", B8[k]);
    P("\n");
    float B9[6] = {2, 1, 4, 1, 4, 2};
    P("mat trsv nrhs=1 = %d ->", sparse_matrix_triangular_solve_dense_float(CblasRowMajor, CblasNoTrans, 1, 1.0f, L, B9, 2));
    for (int k = 0; k < 6; k++) P(" %g", B9[k]);
    P("\n");
    float B10[6] = {2, 1, 4, 1, 4, 2};
    P("mat trsv col ldb=1 = %d ->", sparse_matrix_triangular_solve_dense_float(CblasColMajor, CblasNoTrans, 2, 1.0f, L, B10, 1));
    for (int k = 0; k < 6; k++) P(" %g", B10[k]);
    P("\n");
    sparse_matrix_float U = sparse_matrix_create_float(3, 3);
    sparse_set_matrix_property(U, SPARSE_UPPER_TRIANGULAR);
    sparse_insert_entry_float(U, 2, 0, 0);
    sparse_insert_entry_float(U, 3, 0, 1);
    sparse_insert_entry_float(U, 1, 1, 1);
    sparse_insert_entry_float(U, 4, 2, 2);
    float B11[6] = {2, 5, 4, 1, 2, 3};
    P("mat trsv upper = %d ->", sparse_matrix_triangular_solve_dense_float(CblasRowMajor, CblasNoTrans, 2, 1.0f, U, B11, 2));
    for (int k = 0; k < 6; k++) P(" %g", B11[k]);
    P("\n");
    float B12[6] = {2, 5, 4, 1, 2, 3};
    P("mat trsv upper trans = %d ->", sparse_matrix_triangular_solve_dense_float(CblasRowMajor, CblasTrans, 2, 1.0f, U, B12, 2));
    for (int k = 0; k < 6; k++) P(" %g", B12[k]);
    P("\n");
    sparse_matrix_double Ld = sparse_matrix_create_double(3, 3);
    sparse_set_matrix_property(Ld, SPARSE_LOWER_TRIANGULAR);
    sparse_insert_entry_double(Ld, 2, 0, 0);
    sparse_insert_entry_double(Ld, 1, 1, 0);
    sparse_insert_entry_double(Ld, 3, 1, 1);
    sparse_insert_entry_double(Ld, 4, 2, 2);
    double B13[6] = {2, 1, 4, 1, 4, 2};
    P("mat trsv double = %d ->", sparse_matrix_triangular_solve_dense_double(CblasRowMajor, CblasNoTrans, 2, 1.0, Ld, B13, 2));
    for (int k = 0; k < 6; k++) P(" %g", B13[k]);
    P("\n");
    sparse_matrix_destroy(Ld);
    sparse_matrix_destroy(U);
    sparse_matrix_destroy(A);
    sparse_matrix_destroy(L);
    return 0;
}

CASE(double_level)
{
    sparse_matrix_double A = sparse_matrix_create_double(2, 2);
    sparse_insert_entry_double(A, 1, 0, 0);
    sparse_insert_entry_double(A, 2, 0, 1);
    sparse_insert_entry_double(A, 3, 1, 0);
    sparse_insert_entry_double(A, 4, 1, 1);
    double Cd[4] = {0, 0, 0, 0};
    P("gemm double = %d ->", sparse_matrix_product_dense_double(CblasRowMajor, CblasNoTrans, 2, 0.5, A, (double[]){1, 2, 3, 4}, 2, Cd, 2));
    P(" %g %g %g %g\n", Cd[0], Cd[1], Cd[2], Cd[3]);
    P("elementwise double one=%g two=%g inf=%g r1=%g\n", sparse_elementwise_norm_double(A, SPARSE_NORM_ONE),
      sparse_elementwise_norm_double(A, SPARSE_NORM_TWO), sparse_elementwise_norm_double(A, SPARSE_NORM_INF),
      sparse_elementwise_norm_double(A, SPARSE_NORM_R1));
    P("operator double one=%g two=%g inf=%g\n", sparse_operator_norm_double(A, SPARSE_NORM_ONE),
      sparse_operator_norm_double(A, SPARSE_NORM_TWO), sparse_operator_norm_double(A, SPARSE_NORM_INF));
    P("trace double = %g\n", sparse_matrix_trace_double(A, 0));
    P("vector_norm double two=%g\n", sparse_vector_norm_double(2, (double[]){3, 4}, (sparse_index[]){0, 1}, SPARSE_NORM_TWO));
    P("inner double = %g\n", sparse_inner_product_dense_double(2, (double[]){3, 4}, (sparse_index[]){0, 1}, (double[]){1, 2}, 1));
    P("inner_sparse double = %g\n", sparse_inner_product_sparse_double(2, 2, (double[]){3, 4}, (sparse_index[]){0, 1},
                                                                        (double[]){5, 6}, (sparse_index[]){1, 0}));
    double yd[2] = {1, 1};
    sparse_vector_add_with_scale_dense_double(2, 3.0, (double[]){1, 2}, (sparse_index[]){0, 1}, yd, 1);
    P("add_scale double -> %g %g\n", yd[0], yd[1]);
    P("gemv double = %d ->", sparse_matrix_vector_product_dense_double(CblasNoTrans, 1.0, A, (double[]){1, 1}, 1, yd, 1));
    P(" %g %g\n", yd[0], yd[1]);
    sparse_matrix_double L = sparse_matrix_create_double(2, 2);
    sparse_set_matrix_property(L, SPARSE_LOWER_TRIANGULAR);
    sparse_insert_entry_double(L, 2, 0, 0);
    sparse_insert_entry_double(L, 3, 1, 1);
    double b[2] = {4, 9};
    P("trsv double = %d -> %g %g\n", sparse_vector_triangular_solve_dense_double(CblasNoTrans, 1.0, L, b, 1), b[0], b[1]);
    double Bd[4] = {4, 1, 9, 2};
    P("mat trsv double = %d ->", sparse_matrix_triangular_solve_dense_double(CblasRowMajor, CblasNoTrans, 2, 1.0, L, Bd, 2));
    P(" %g %g %g %g\n", Bd[0], Bd[1], Bd[2], Bd[3]);
    sparse_index perm[2] = {1, 0};
    P("permute_rows double = %d\n", sparse_permute_rows_double(A, perm));
    P("permute_cols double = %d\n", sparse_permute_cols_double(A, (sparse_index[]){1, 0}));
    P("vector_nonzero_count double = %ld\n", sparse_get_vector_nonzero_count_double(3, (double[]){0, 1, 2}, 1));
    double py[3]; sparse_index pi[3];
    P("pack double = %ld ->", sparse_pack_vector_double(3, 2, (double[]){0, 5, 6}, 1, py, pi));
    P(" (%lld,%g) (%lld,%g)\n", (long long)pi[0], py[0], (long long)pi[1], py[1]);
    double uy[3] = {9, 9, 9};
    sparse_unpack_vector_double(3, 2, true, (double[]){7, 8}, (sparse_index[]){0, 2}, uy, 1);
    P("unpack double -> %g %g %g\n", uy[0], uy[1], uy[2]);
    sparse_matrix_destroy(L);
    sparse_matrix_destroy(A);
    return 0;
}

struct table { const char *name; int (*fn)(void); };
static struct table table[] = {
    {"create_pointwise", run_create_pointwise},
    {"create_block", run_create_block},
    {"create_varblock", run_create_varblock},
    {"properties", run_properties},
    {"insert_point", run_insert_point},
    {"insert_batch", run_insert_batch},
    {"insert_block", run_insert_block},
    {"vector_level1", run_vector_level1},
    {"utilities", run_utilities},
    {"level2", run_level2},
    {"norms", run_norms},
    {"trace", run_trace},
    {"permute", run_permute},
    {"outer", run_outer},
    {"level3_dense", run_level3_dense},
    {"level3_sparse", run_level3_sparse},
    {"level3_trsv", run_level3_trsv},
    {"double_level", run_double_level},
};

int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    for (int k = 1; k < argc && only_count < 64; k++) only[only_count++] = argv[k];
    for (size_t k = 0; k < sizeof(table) / sizeof(table[0]); k++) {
        if (wanted(table[k].name)) {
            checks++;
            P("--- %s\n", table[k].name);
            table[k].fn();
        }
    }
    P("--- done, %d cases\n", checks);
    return 0;
}
