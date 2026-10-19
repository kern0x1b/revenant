// A second, narrower probe: the two level-3 questions the first probe could not separate, each with
// a case small enough that every element of the answer is forced by the arithmetic, and each with a
// negative control - a dense cblas_sgemm over the same numbers, printed next to the sparse answer.

#import <Accelerate/Accelerate.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define P(...) printf(__VA_ARGS__)

static sparse_matrix_float build(sparse_dimension M, sparse_dimension N, sparse_dimension n, const float *v,
                                 const sparse_index *i, const sparse_index *j)
{
    sparse_matrix_float A = sparse_matrix_create_float(M, N);
    sparse_insert_entries_float(A, n, v, i, j);
    return A;
}

static void show(const char *tag, const float *c, int count)
{
    P("%s:", tag);
    for (int k = 0; k < count; k++) P(" %g", c[k]);
    P("\n");
}

// permute_rows and permute_cols, one permutation at a time, on a matrix whose six values are all
// different, printing after every single call so no step can hide behind another.
static void permute(void)
{
    P("== permute, one call at a time ==\n");
    sparse_index sets[][3] = {{1, 0, 0}, {0, 1, 0}, {2, 0, 1}, {0, 2, 1}, {2, 1, 0}, {0, 1, 2}, {0, 0, 0}, {2, 2, 2}};
    sparse_index rowsets[][3] = {{1, 0, 0}, {0, 1, 0}, {0, 0, 0}, {1, 1, 0}, {0, 1, 1}};
    for (size_t k = 0; k < sizeof(sets) / sizeof(sets[0]); k++) {
        for (int mode = 0; mode < 2; mode++) {
            // A row permutation has one entry per row and a column permutation one per column: the
            // header says an index outside the matrix is undefined, so each gets a list of its own length.
            const sparse_index *perm = mode ? sets[k] : rowsets[k < sizeof(rowsets) / sizeof(rowsets[0]) ? k : 0];
            if (mode == 0 && k >= sizeof(rowsets) / sizeof(rowsets[0])) continue;
            sparse_matrix_float B = build(2, 3, 6, (float[]){1, 2, 3, 4, 5, 6},
                                          (sparse_index[]){0, 0, 0, 1, 1, 1}, (sparse_index[]){0, 1, 2, 0, 1, 2});
            sparse_status s = mode ? sparse_permute_cols_float(B, perm) : sparse_permute_rows_float(B, perm);
            // read every element through the entry point the host offers, one at a time
            float got[6] = {9, 9, 9, 9, 9, 9};
            for (sparse_dimension r = 0; r < 2; r++) {
                sparse_index c = 0;
                float v = 0;
                sparse_index j = 0;
                while (c < 3) {
                    sparse_index e = 0;
                    if (sparse_extract_sparse_row_float(B, (sparse_index)r, c, &e, 1, &v, &j) != 1) { c++; continue; }
                    got[r * 3 + j] = v;
                    c = (e <= c) ? c + 1 : e;
                }
            }
            P("%s perm {%d,%d} = %d ->", mode ? "cols" : "rows", perm[0], perm[1], s);
            show("", got, 6);
            sparse_matrix_destroy(B);
        }
    }
}

// The 2x2 by 2x2 product, then the 2x3 by 3x2 one, each against cblas_sgemm over the same numbers.
static void gemm(void)
{
    P("== 2x2 by 2x2, ldb=ldc=2 ==\n");
    {
        sparse_matrix_float A = build(2, 2, 3, (float[]){1, 2, 3}, (sparse_index[]){0, 0, 1}, (sparse_index[]){0, 1, 1});
        float B[4] = {1, 2, 3, 4};
        float C[4] = {0, 0, 0, 0};
        sparse_status s = sparse_matrix_product_dense_float(CblasRowMajor, CblasNoTrans, 2, 1.0f, A, B, 2, C, 2);
        P("sparse = %d ->", s);
        show("", C, 4);
        float D[4] = {0, 0, 0, 0};
        cblas_sgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans, 2, 2, 2, 1.0f, (float[]){1, 0, 0, 3}, 2, B, 2, 0.0f, D, 2);
        P("cblas  ->");
        show("", D, 4);
        float E[4] = {0, 0, 0, 0};
        cblas_sgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans, 2, 2, 2, 1.0f, (float[]){1, 2, 0, 3}, 2, B, 2, 0.0f, E, 2);
        P("cblas with A(0,1)=2 ->");
        show("", E, 4);
        sparse_matrix_destroy(A);
    }
    P("== 2x3 by 3x2, ldb=3 ldc=2 ==\n");
    {
        sparse_matrix_float A = build(2, 3, 4, (float[]){1, 2, 3, 4}, (sparse_index[]){0, 0, 1, 1}, (sparse_index[]){0, 2, 1, 2});
        float B[6] = {1, 2, 3, 4, 5, 6};
        float C[4] = {0, 0, 0, 0};
        sparse_status s = sparse_matrix_product_dense_float(CblasRowMajor, CblasNoTrans, 2, 1.0f, A, B, 3, C, 2);
        P("sparse = %d ->", s);
        show("", C, 4);
        float D[4] = {0, 0, 0, 0};
        cblas_sgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans, 2, 2, 3, 1.0f, (float[]){1, 0, 2, 0, 3, 4}, 3, B, 3, 0.0f, D, 2);
        P("cblas  ->");
        show("", D, 4);
        sparse_matrix_destroy(A);
    }
    P("== 2x3 by 3x2 transposed, ldb=3 ldc=2 ==\n");
    {
        sparse_matrix_float A = build(2, 3, 4, (float[]){1, 2, 3, 4}, (sparse_index[]){0, 0, 1, 1}, (sparse_index[]){0, 2, 1, 2});
        float B[6] = {1, 2, 3, 4, 5, 6};
        float C[4] = {0, 0, 0, 0};
        sparse_status s = sparse_matrix_product_dense_float(CblasRowMajor, CblasTrans, 2, 1.0f, A, B, 3, C, 2);
        P("sparse = %d ->", s);
        show("", C, 4);
        float D[4] = {0, 0, 0, 0};
        cblas_sgemm(CblasRowMajor, CblasTrans, CblasNoTrans, 2, 2, 3, 1.0f, (float[]){1, 0, 2, 0, 3, 4}, 3, B, 3, 0.0f, D, 2);
        P("cblas  ->");
        show("", D, 4);
        sparse_matrix_destroy(A);
    }
    P("== col-major 2x3 by 3x2, ldb=3 ldc=2 ==\n");
    {
        sparse_matrix_float A = build(2, 3, 4, (float[]){1, 2, 3, 4}, (sparse_index[]){0, 0, 1, 1}, (sparse_index[]){0, 2, 1, 2});
        float B[6] = {1, 2, 3, 4, 5, 6};
        float C[4] = {0, 0, 0, 0};
        sparse_status s = sparse_matrix_product_dense_float(CblasColMajor, CblasNoTrans, 2, 1.0f, A, B, 3, C, 2);
        P("sparse = %d ->", s);
        show("", C, 4);
        float D[4] = {0, 0, 0, 0};
        cblas_sgemm(CblasColMajor, CblasNoTrans, CblasNoTrans, 2, 2, 3, 1.0f, (float[]){1, 0, 2, 0, 3, 4}, 3, B, 3, 0.0f, D, 2);
        P("cblas  ->");
        show("", D, 4);
        sparse_matrix_destroy(A);
    }
    P("== sparse x sparse, 2x3 by 3x2 ==\n");
    {
        sparse_matrix_float A = build(2, 3, 4, (float[]){1, 2, 3, 4}, (sparse_index[]){0, 0, 1, 1}, (sparse_index[]){0, 2, 1, 2});
        sparse_matrix_float S = build(3, 2, 4, (float[]){5, 6, 7, 8}, (sparse_index[]){0, 0, 1, 2}, (sparse_index[]){0, 1, 0, 1});
        float C[4] = {0, 0, 0, 0};
        sparse_status s = sparse_matrix_product_sparse_float(CblasRowMajor, CblasNoTrans, 1.0f, A, S, C, 2);
        P("sparse = %d ->", s);
        show("", C, 4);
        float D[4] = {0, 0, 0, 0};
        cblas_sgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans, 2, 2, 3, 1.0f, (float[]){1, 0, 2, 0, 3, 4}, 3, (float[]){5, 0, 7, 6, 0, 8}, 3, 0.0f, D, 2);
        P("cblas  ->");
        show("", D, 4);
        sparse_matrix_destroy(A);
        sparse_matrix_destroy(S);
    }
    P("== gemv against cblas_sgemv ==\n");
    {
        sparse_matrix_float A = build(2, 3, 4, (float[]){1, 2, 3, 4}, (sparse_index[]){0, 0, 1, 1}, (sparse_index[]){0, 2, 1, 2});
        float x[3] = {1, 1, 1}, y[3] = {0, 0, 0};
        P("sparse no-trans = %d ->", sparse_matrix_vector_product_dense_float(CblasNoTrans, 1.0f, A, x, 1, y, 1));
        show("", y, 3);
        float y2[3] = {0, 0, 0};
        cblas_sgemv(CblasRowMajor, CblasNoTrans, 2, 3, 1.0f, (float[]){1, 0, 2, 0, 3, 4}, 3, x, 1, 0.0f, y2, 1);
        P("cblas  ->");
        show("", y2, 3);
        float y3[3] = {0, 0, 0}, x3[3] = {1, 1, 1};
        P("sparse trans = %d ->", sparse_matrix_vector_product_dense_float(CblasTrans, 1.0f, A, x3, 1, y3, 1));
        show("", y3, 3);
        float y4[3] = {0, 0, 0};
        cblas_sgemv(CblasRowMajor, CblasTrans, 3, 2, 1.0f, (float[]){1, 0, 2, 0, 3, 4}, 3, x, 1, 0.0f, y4, 1);
        P("cblas  ->");
        show("", y4, 3);
        sparse_matrix_destroy(A);
    }
    // The trsv alpha question, with a right-hand side that is not a solution of its own right.
    P("== trsv alpha, a b that is not a solution ==\n");
    {
        sparse_matrix_float L = sparse_matrix_create_float(3, 3);
        sparse_set_matrix_property(L, SPARSE_LOWER_TRIANGULAR);
        sparse_insert_entry_float(L, 2, 0, 0);
        sparse_insert_entry_float(L, 1, 1, 0);
        sparse_insert_entry_float(L, 3, 1, 1);
        sparse_insert_entry_float(L, 4, 2, 2);
        float b1[3] = {2, 5, 4};
        P("alpha=1 -> %d ->", sparse_vector_triangular_solve_dense_float(CblasNoTrans, 1.0f, L, b1, 1));
        show("", b1, 3);
        float b2[3] = {2, 5, 4};
        P("alpha=2 -> %d ->", sparse_vector_triangular_solve_dense_float(CblasNoTrans, 2.0f, L, b2, 1));
        show("", b2, 3);
        float b3[3] = {2, 5, 4};
        P("alpha=0.5 -> %d ->", sparse_vector_triangular_solve_dense_float(CblasNoTrans, 0.5f, L, b3, 1));
        show("", b3, 3);
        float b4[3] = {2, 5, 4};
        P("alpha=0 -> %d ->", sparse_vector_triangular_solve_dense_float(CblasNoTrans, 0.0f, L, b4, 1));
        show("", b4, 3);
        float b5[3] = {2, 5, 4};
        P("alpha=-1 -> %d ->", sparse_vector_triangular_solve_dense_float(CblasNoTrans, -1.0f, L, b5, 1));
        show("", b5, 3);
        sparse_matrix_destroy(L);
    }
    // And the matrix form, same matrix, same b.
    P("== mat trsv alpha, a b that is not a solution ==\n");
    {
        sparse_matrix_float L = sparse_matrix_create_float(3, 3);
        sparse_set_matrix_property(L, SPARSE_LOWER_TRIANGULAR);
        sparse_insert_entry_float(L, 2, 0, 0);
        sparse_insert_entry_float(L, 1, 1, 0);
        sparse_insert_entry_float(L, 3, 1, 1);
        sparse_insert_entry_float(L, 4, 2, 2);
        float b1[6] = {2, 7, 5, 9, 4, 6};
        P("alpha=1 -> %d ->", sparse_matrix_triangular_solve_dense_float(CblasRowMajor, CblasNoTrans, 2, 1.0f, L, b1, 2));
        show("", b1, 6);
        float b2[6] = {2, 7, 5, 9, 4, 6};
        P("alpha=2 -> %d ->", sparse_matrix_triangular_solve_dense_float(CblasRowMajor, CblasNoTrans, 2, 2.0f, L, b2, 2));
        show("", b2, 6);
        sparse_matrix_destroy(L);
    }
    // The inner product with a negative stride, with values that separate the two readings.
    P("== negative strides, separable values ==\n");
    {
        float y[6] = {10, 20, 30, 40, 50, 60};
        float x[3] = {1, 5, 2};
        sparse_index ix[3] = {0, 1, 2};
        P("inner incy=1 = %g (expect 1*10+5*20+2*30 = 120)\n", sparse_inner_product_dense_float(3, x, ix, y, 1));
        P("inner incy=-1 = %g (last-element reading 1*60+5*50+2*40 = 190, abs reading 120)\n",
          sparse_inner_product_dense_float(3, x, ix, y, -1));
        P("inner incy=-2 = %g (last-element 1*60+5*40+2*20 = 200, abs 1*10+5*30+2*50 = 160)\n",
          sparse_inner_product_dense_float(3, x, ix, y, -2));
        float z[6] = {10, 20, 30, 40, 50, 60};
        sparse_vector_add_with_scale_dense_float(3, 1.0f, x, ix, z, -1);
        P("add_scale incy=-1 -> %g %g %g %g %g %g\n", z[0], z[1], z[2], z[3], z[4], z[5]);
        float w[6] = {10, 20, 30, 40, 50, 60};
        sparse_vector_add_with_scale_dense_float(3, 1.0f, x, ix, w, 2);
        P("add_scale incy=2 -> %g %g %g %g %g %g\n", w[0], w[1], w[2], w[3], w[4], w[5]);
        P("nonzero_count incy=1 = %ld, incy=-1 = %ld, incy=2 = %ld, incy=-2 = %ld (all six are nonzero)\n",
          sparse_get_vector_nonzero_count_float(6, z, 1), sparse_get_vector_nonzero_count_float(6, z, -1),
          sparse_get_vector_nonzero_count_float(6, z, 2), sparse_get_vector_nonzero_count_float(6, z, -2));
        float q[6] = {0, 1, 0, 1, 0, 1};
        P("nonzero_count of {0,1,0,1,0,1}: incy=1 = %ld, incy=2 = %ld, incy=-1 = %ld, incy=-2 = %ld\n",
          sparse_get_vector_nonzero_count_float(6, q, 1), sparse_get_vector_nonzero_count_float(6, q, 2),
          sparse_get_vector_nonzero_count_float(6, q, -1), sparse_get_vector_nonzero_count_float(6, q, -2));
        float pv[3]; sparse_index pi[3];
        P("pack of {0,1,0,1,0,1} incy=1 = %ld ->", sparse_pack_vector_float(6, 3, q, 1, pv, pi));
        P(" (%lld,%g) (%lld,%g) (%lld,%g)\n", (long long)pi[0], pv[0], (long long)pi[1], pv[1], (long long)pi[2], pv[2]);
        P("pack incy=2 = %ld ->", sparse_pack_vector_float(6, 3, q, 2, pv, pi));
        P(" (%lld,%g) (%lld,%g) (%lld,%g)\n", (long long)pi[0], pv[0], (long long)pi[1], pv[1], (long long)pi[2], pv[2]);
        P("pack incy=-1 = %ld ->", sparse_pack_vector_float(6, 3, q, -1, pv, pi));
        P(" (%lld,%g) (%lld,%g) (%lld,%g)\n", (long long)pi[0], pv[0], (long long)pi[1], pv[1], (long long)pi[2], pv[2]);
        P("pack incy=-2 = %ld ->", sparse_pack_vector_float(6, 3, q, -2, pv, pi));
        P(" (%lld,%g) (%lld,%g) (%lld,%g)\n", (long long)pi[0], pv[0], (long long)pi[1], pv[1], (long long)pi[2], pv[2]);
        float u[6] = {9, 9, 9, 9, 9, 9};
        sparse_unpack_vector_float(6, 2, true, (float[]){7, 8}, (sparse_index[]){0, 5}, u, -1);
        P("unpack incy=-1 indx 0,5 -> %g %g %g %g %g %g (last-element 7 8 at 5,0)\n", u[0], u[1], u[2], u[3], u[4], u[5]);
    }
    return;
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    permute();
    gemm();
    return 0;
}
