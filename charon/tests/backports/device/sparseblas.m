// Every entry point of the sparse BLAS of vecLib/Sparse/BLAS.h, called on the device against the
// answers facts/Accelerate/SparseBLAS.md records from the host's own Accelerate.
//
// The port's objects are linked into this test, so the calls below are the port's own. Nothing here
// reads a matrix's internals: every answer is read back through the same entry points a caller has.

#import <Accelerate/Accelerate.h>
#include <math.h>
#include <stdio.h>
#include <string.h>

static int failures;
static int checks;

static void expect(int passed, const char *name, const char *detail)
{
    checks++;
    if (passed) {
        printf("ok %s\n", name);
    } else {
        failures++;
        printf("FAIL %s: %s\n", name, detail);
    }
}

static int near(double mine, double theirs, double tolerance)
{
    double difference = fabs(mine - theirs);
    double scale = fabs(theirs) > 1.0 ? fabs(theirs) : 1.0;
    return difference <= tolerance * scale;
}

static void matrix_is(sparse_matrix_float A, sparse_dimension rows, sparse_dimension columns, long nonzero)
{
    char detail[256];
    snprintf(detail, sizeof detail, "%llu x %llu with %ld entries, asked %llu x %llu with %ld", (unsigned long long)rows,
             (unsigned long long)columns, nonzero, (unsigned long long)sparse_get_matrix_number_of_rows(A),
             (unsigned long long)sparse_get_matrix_number_of_columns(A), sparse_get_matrix_nonzero_count(A));
    expect(sparse_get_matrix_number_of_rows(A) == rows && sparse_get_matrix_number_of_columns(A) == columns &&
               sparse_get_matrix_nonzero_count(A) == nonzero,
           "the shape of a matrix", detail);
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    char detail[256];

    // A dimension of zero is accepted, measured: create(0, 5) answers a matrix of 0 rows and 5 columns.
    sparse_matrix_float zero = sparse_matrix_create_float(0, 5);
    expect(zero != NULL, "a matrix of no rows", "create(0,5) answers a matrix");
    matrix_is(zero, 0, 5, 0);
    expect(sparse_matrix_destroy(zero) == SPARSE_SUCCESS, "destroying it", "SPARSE_SUCCESS");
    expect(sparse_matrix_destroy(NULL) == SPARSE_ILLEGAL_PARAMETER, "destroying nothing",
           "SPARSE_ILLEGAL_PARAMETER");
    expect(sparse_commit(NULL) == SPARSE_ILLEGAL_PARAMETER, "committing nothing", "SPARSE_ILLEGAL_PARAMETER");
    expect(sparse_get_matrix_nonzero_count(NULL) == 0 && sparse_get_matrix_number_of_rows(NULL) == 0,
           "asking a matrix that is not there", "zero for both");
    expect(sparse_get_block_dimension_for_row(NULL, 0) == 0, "a block dimension of nothing", "zero");

    // A block matrix counts its rows and columns in elements, measured: block(3,3,2,2) is 6 by 6.
    // Two block rows of two elements and two block columns of three, so the matrix is 4 by 6 and a
    // block entry is 2 by 3 - the shape the host was measured on.
    sparse_matrix_float block = sparse_matrix_block_create_float(2, 2, 2, 3);
    matrix_is(block, 4, 6, 0);
    expect(sparse_get_block_dimension_for_row(block, 0) == 2 && sparse_get_block_dimension_for_row(block, 3) == 2 &&
               sparse_get_block_dimension_for_row(block, 9) == 0,
           "a fixed block matrix's block dimensions", "two for every element row, zero past the last");
    expect(sparse_get_block_dimension_for_col(block, 0) == 3 && sparse_get_block_dimension_for_col(block, 2) == 3 &&
               sparse_get_block_dimension_for_col(block, 3) == 3,
           "a fixed block matrix's column block dimensions", "three for every element column");
    float patch[6] = {1, 2, 3, 4, 5, 6};
    expect(sparse_insert_block_float(block, patch, 3, 1, 0, 0) == SPARSE_SUCCESS, "a block entry", "SPARSE_SUCCESS");
    matrix_is(block, 4, 6, 6);
    expect(sparse_get_matrix_nonzero_count_for_row(block, 0) == 3 && sparse_get_matrix_nonzero_count_for_row(block, 1) == 3 &&
               sparse_get_matrix_nonzero_count_for_row(block, 2) == 0,
           "a block matrix's row counts", "three in each of the two rows the block covers");
    float back[6] = {0};
    expect(sparse_extract_block_float(block, 0, 0, 3, 1, back) == SPARSE_SUCCESS &&
               back[0] == 1 && back[1] == 2 && back[2] == 3 && back[3] == 4 && back[4] == 5 && back[5] == 6,
           "the block read back", "1, 2, 3, 4, 5, 6");
    expect(sparse_insert_block_float(block, patch, 3, 1, 5, 0) == SPARSE_ILLEGAL_PARAMETER,
           "a block entry outside the matrix", "SPARSE_ILLEGAL_PARAMETER");
    expect(sparse_extract_block_float(block, 1, 1, 3, 1, (float[6]){0}) == SPARSE_SUCCESS,
           "a block that was never inserted", "SPARSE_SUCCESS with zeros");
    sparse_matrix_destroy(block);

    // A variable-block matrix's block dimension is the size of the block the element is in, measured.
    sparse_dimension heights[3] = {2, 1, 3}, widths[3] = {1, 2, 1};
    sparse_matrix_float variable = sparse_matrix_variable_block_create_float(3, 3, heights, widths);
    matrix_is(variable, 6, 4, 0);
    long rowDims[3] = {sparse_get_block_dimension_for_row(variable, 0), sparse_get_block_dimension_for_row(variable, 1),
                       sparse_get_block_dimension_for_row(variable, 2)};
    long colDims[3] = {sparse_get_block_dimension_for_col(variable, 0), sparse_get_block_dimension_for_col(variable, 1),
                       sparse_get_block_dimension_for_col(variable, 2)};
    expect(rowDims[0] == 2 && rowDims[1] == 2 && rowDims[2] == 1, "a variable matrix's row block dimensions", "2, 2, 1");
    expect(colDims[0] == 1 && colDims[1] == 2 && colDims[2] == 2, "a variable matrix's column block dimensions", "1, 2, 2");
    sparse_matrix_destroy(variable);

    // A stored entry and a nonzero value are two different things, measured: an exact zero is stored.
    sparse_matrix_float A = sparse_matrix_create_float(4, 4);
    sparse_insert_entry_float(A, 0.0f, 1, 1);
    expect(sparse_get_matrix_nonzero_count(A) == 1, "an entry of exactly zero", "the count is 1");
    sparse_insert_entry_float(A, 2.0f, 1, 1);
    expect(sparse_get_matrix_nonzero_count(A) == 1, "the same entry again", "the count is still 1");
    sparse_insert_entry_float(A, 5.0f, 0, 3);
    sparse_insert_entry_float(A, -1.5f, 3, 0);
    matrix_is(A, 4, 4, 3);
    expect(sparse_get_matrix_nonzero_count_for_row(A, 1) == 1 && sparse_get_matrix_nonzero_count_for_column(A, 0) == 1 &&
               sparse_get_matrix_nonzero_count_for_row(A, 7) == 0 && sparse_get_matrix_nonzero_count_for_row(A, -1) == 0,
           "the counts per row and column", "one each, and zero outside the matrix");
    expect(sparse_commit(A) == SPARSE_SUCCESS, "a commit", "SPARSE_SUCCESS with nothing left to do");

    // The row extraction returns a count and leaves column_end where the next entry is.
    sparse_index end = 0;
    float values[4] = {0};
    sparse_index indices[4] = {0};
    long got = sparse_extract_sparse_row_float(A, 0, 0, &end, 4, values, indices);
    expect(got == 1 && end == 4 && indices[0] == 3 && values[0] == 5.0f, "a row extracted",
           "one entry at column 3, end 4");
    end = 0;
    got = sparse_extract_sparse_row_float(A, 0, 0, &end, 0, values, indices);
    expect(got == 0 && end == 0, "a row extracted with nothing asked for", "zero entries and end 0");
    expect(sparse_extract_sparse_row_float(A, 0, 4, &end, 4, values, indices) == SPARSE_ILLEGAL_PARAMETER,
           "a row extracted past the last column", "SPARSE_ILLEGAL_PARAMETER");
    expect(sparse_extract_sparse_row_float(A, 0, -1, &end, 4, values, indices) == SPARSE_ILLEGAL_PARAMETER,
           "a row extracted from a negative column", "SPARSE_ILLEGAL_PARAMETER");
    end = 0;
    got = sparse_extract_sparse_column_float(A, 0, 0, &end, 4, values, indices);
    expect(got == 1 && end == 4 && indices[0] == 3 && values[0] == -1.5f, "a column extracted",
           "one entry at row 3, end 4");

    // The properties are bits, and any name is remembered.
    sparse_matrix_float triangle = sparse_matrix_create_float(3, 3);
    expect(sparse_set_matrix_property(triangle, SPARSE_UPPER_TRIANGULAR) == SPARSE_SUCCESS &&
               sparse_get_matrix_property(triangle, SPARSE_UPPER_TRIANGULAR) == SPARSE_UPPER_TRIANGULAR,
           "the upper triangular property", "set and read back");
    expect(sparse_set_matrix_property(triangle, (sparse_matrix_property)3) == SPARSE_SUCCESS &&
               sparse_get_matrix_property(triangle, (sparse_matrix_property)3) == 3,
           "a name the enumeration does not name", "3 is remembered and reads back");
    expect(sparse_set_matrix_property(triangle, (sparse_matrix_property)-1) == SPARSE_ILLEGAL_PARAMETER,
           "a negative name", "SPARSE_ILLEGAL_PARAMETER");
    sparse_insert_entry_float(triangle, 1, 0, 0);
    expect(sparse_set_matrix_property(triangle, SPARSE_LOWER_SYMMETRIC) == SPARSE_CANNOT_SET_PROPERTY,
           "a property after an insertion", "SPARSE_CANNOT_SET_PROPERTY");

    // The vector forms. A norm the enumeration does not name is the infinity norm, measured.
    float sparseVector[3] = {1, 0, 3};
    sparse_index where[3] = {0, 2, 3};
    expect(near(sparse_vector_norm_float(3, sparseVector, where, SPARSE_NORM_ONE), 4.0, 1e-6), "the one norm",
           "4");
    expect(near(sparse_vector_norm_float(3, sparseVector, where, SPARSE_NORM_TWO), 3.16228, 1e-4), "the two norm",
           "3.16228");
    expect(near(sparse_vector_norm_float(3, sparseVector, where, SPARSE_NORM_INF), 3.0, 1e-6), "the infinity norm",
           "3");
    expect(near(sparse_vector_norm_float(3, sparseVector, where, SPARSE_NORM_R1), 3.16228, 1e-4),
           "the R1 norm of a vector", "the two norm, as the host answers");
    expect(near(sparse_vector_norm_float(3, sparseVector, where, (sparse_norm)0), 3.0, 1e-6),
           "a vector norm outside the enumeration", "the infinity norm");
    expect(sparse_vector_norm_float(0, sparseVector, where, SPARSE_NORM_ONE) == 0.0, "the norm of nothing", "0");
    float dense[4] = {10, 20, 30, 40};
    // The entries are at columns 0, 2 and 3, so the product is 1*10 + 0*20 + 3*40.
    expect(near(sparse_inner_product_dense_float(3, sparseVector, where, dense, 1), 130.0, 1e-6),
           "an inner product with a dense vector", "1*10 + 0*20 + 3*40 = 130");
    expect(near(sparse_inner_product_dense_float(0, sparseVector, where, dense, 1), 0.0, 1e-6),
           "an inner product of nothing", "0");
    float twoSparse[2] = {4, 2};
    sparse_index twoWhere[2] = {1, 3};
    // The first vector's columns are 0, 2 and 3 and the second's are 1 and 3, so only column 3 meets.
    expect(near(sparse_inner_product_sparse_float(3, 2, sparseVector, where, twoSparse, twoWhere), 6.0, 1e-6),
           "an inner product of two sparse vectors", "3*2 = 6");
    float scaled[4] = {10, 20, 30, 40};
    sparse_vector_add_with_scale_dense_float(3, 2.0f, sparseVector, where, scaled, 1);
    snprintf(detail, sizeof detail, "%g, %g, %g, %g", scaled[0], scaled[1], scaled[2], scaled[3]);
    expect(scaled[0] == 12.0f && scaled[1] == 20.0f && scaled[2] == 30.0f && scaled[3] == 46.0f, "a scaled addition", detail);
    float notScaled[4] = {10, 20, 30, 40};
    sparse_vector_add_with_scale_dense_float(3, 0.0f, sparseVector, where, notScaled, 1);
    expect(notScaled[0] == 10.0f && notScaled[3] == 40.0f, "a scaled addition by nothing", "unchanged");
    float packed[3];
    sparse_index packedAt[3];
    long packedCount = sparse_pack_vector_float(4, 2, (float[]){0, 2, 0, 4}, 1, packed, packedAt);
    expect(packedCount == 2 && packedAt[0] == 1 && packed[0] == 2.0f && packedAt[1] == 3 && packed[1] == 4.0f,
           "a packed vector", "two entries at columns 1 and 3");
    float unpacked[4] = {1, 1, 1, 1};
    sparse_unpack_vector_float(4, 2, true, (float[]){7, 8}, (sparse_index[]){1, 3}, unpacked, 1);
    expect(unpacked[0] == 0.0f && unpacked[1] == 7.0f && unpacked[2] == 0.0f && unpacked[3] == 8.0f,
           "an unpacked vector", "0, 7, 0, 8");
    expect(sparse_get_vector_nonzero_count_float(4, (float[]){0, 2, 0, 4}, 1) == 2, "a nonzero count", "2");

    // The matrix-vector product, over a strided vector with a stride the BLAS would not take.
    sparse_matrix_float plain = sparse_matrix_create_float(3, 3);
    sparse_insert_entry_float(plain, 1, 0, 0);
    sparse_insert_entry_float(plain, 2, 0, 2);
    sparse_insert_entry_float(plain, 3, 1, 1);
    sparse_insert_entry_float(plain, 4, 2, 0);
    float x[3] = {1, 1, 1}, y[3] = {1, 1, 1};
    expect(sparse_matrix_vector_product_dense_float(CblasNoTrans, 1.0f, plain, x, 1, y, 1) == SPARSE_SUCCESS &&
               y[0] == 4.0f && y[1] == 4.0f && y[2] == 5.0f,
           "a matrix-vector product", "4, 4, 5");
    // A transposed operand takes x over the matrix's own rows and y over its own columns, so for this
    // 3x3 both are three: 1*1 + 0*1 + 4*1, 0*1 + 3*1 + 0*1 and 2*1 + 0*1 + 0*1, added to a y of ones.
    y[0] = y[1] = y[2] = 1.0f;
    sparse_status transposed = sparse_matrix_vector_product_dense_float(CblasTrans, 1.0f, plain, (float[]){1, 1, 1}, 1, y, 1);
    snprintf(detail, sizeof detail, "status %d, %g, %g, %g", transposed, y[0], y[1], y[2]);
    expect(transposed == SPARSE_SUCCESS && y[0] == 6.0f && y[1] == 4.0f && y[2] == 3.0f,
           "a transposed matrix-vector product", detail);
    expect(sparse_matrix_vector_product_dense_float((enum CBLAS_TRANSPOSE)9, 1.0f, plain, x, 1, y, 1) ==
               SPARSE_ILLEGAL_PARAMETER,
           "a transpose outside the enumeration", "SPARSE_ILLEGAL_PARAMETER");
    sparse_matrix_destroy(plain);

    // The triangular solve, whose alpha divides the right-hand side, measured.
    sparse_matrix_float lower = sparse_matrix_create_float(3, 3);
    sparse_set_matrix_property(lower, SPARSE_LOWER_TRIANGULAR);
    sparse_insert_entry_float(lower, 2, 0, 0);
    sparse_insert_entry_float(lower, 1, 1, 0);
    sparse_insert_entry_float(lower, 3, 1, 1);
    sparse_insert_entry_float(lower, 4, 2, 2);
    float b[3] = {2, 5, 4};
    expect(sparse_vector_triangular_solve_dense_float(CblasNoTrans, 1.0f, lower, b, 1) == SPARSE_SUCCESS &&
               near(b[0], 1.0, 1e-6) && near(b[1], 1.33333, 1e-5) && near(b[2], 1.0, 1e-6),
           "a triangular solve of a vector", "1, 1.33333, 1");
    float b2[3] = {2, 5, 4};
    expect(sparse_vector_triangular_solve_dense_float(CblasNoTrans, 2.0f, lower, b2, 1) == SPARSE_SUCCESS &&
               near(b2[0], 0.5, 1e-6) && near(b2[1], 0.666667, 1e-5) && near(b2[2], 0.5, 1e-6),
           "a triangular solve that divides by alpha", "0.5, 0.666667, 0.5");
    sparse_matrix_float noTriangle = sparse_matrix_create_float(3, 3);
    sparse_insert_entry_float(noTriangle, 1, 0, 0);
    sparse_insert_entry_float(noTriangle, 3, 1, 1);
    sparse_insert_entry_float(noTriangle, 4, 2, 0);
    float b3[3] = {2, 5, 4};
    expect(sparse_vector_triangular_solve_dense_float(CblasNoTrans, 1.0f, noTriangle, b3, 1) ==
                   SPARSE_ILLEGAL_PARAMETER && b3[0] == 2.0f && b3[1] == 5.0f,
           "a triangular solve of a matrix that is not triangular", "refused, and the vector untouched");
    sparse_matrix_destroy(noTriangle);
    float b4[6] = {2, 7, 5, 9, 4, 6};
    expect(sparse_matrix_triangular_solve_dense_float(CblasRowMajor, CblasNoTrans, 2, 1.0f, lower, b4, 2) ==
                   SPARSE_SUCCESS && near(b4[0], 1.0, 1e-6) && near(b4[1], 3.5, 1e-6) &&
               near(b4[2], 1.33333, 1e-5) && near(b4[3], 1.83333, 1e-5) && near(b4[4], 1.0, 1e-6) &&
               near(b4[5], 1.5, 1e-6),
           "a triangular solve of a matrix", "1, 3.5, 1.33333, 1.83333, 1, 1.5");
    float b5[6] = {2, 7, 5, 9, 4, 6};
    expect(sparse_matrix_triangular_solve_dense_float(CblasRowMajor, CblasNoTrans, 2, 1.0f, lower, b5, 1) ==
               SPARSE_ILLEGAL_PARAMETER,
           "a triangular solve with a leading dimension of one", "SPARSE_ILLEGAL_PARAMETER, not a crash");
    sparse_matrix_destroy(lower);

    // The norms and the trace, measured.
    sparse_matrix_float norms = sparse_matrix_create_float(2, 3);
    sparse_insert_entry_float(norms, -1, 0, 0);
    sparse_insert_entry_float(norms, 2, 0, 1);
    sparse_insert_entry_float(norms, -3, 0, 2);
    sparse_insert_entry_float(norms, 4, 1, 0);
    sparse_insert_entry_float(norms, -5, 1, 2);
    expect(near(sparse_elementwise_norm_float(norms, SPARSE_NORM_ONE), 15.0, 1e-6), "the elementwise one norm", "15");
    expect(near(sparse_elementwise_norm_float(norms, SPARSE_NORM_TWO), 7.4162, 1e-4), "the elementwise two norm",
           "7.4162");
    expect(near(sparse_elementwise_norm_float(norms, SPARSE_NORM_INF), 5.0, 1e-6), "the elementwise infinity norm",
           "5");
    expect(near(sparse_elementwise_norm_float(norms, SPARSE_NORM_R1), 11.9541, 1e-4), "the elementwise R1 norm",
           "11.9541");
    expect(near(sparse_elementwise_norm_float(norms, (sparse_norm)999), 5.0, 1e-6),
           "an elementwise norm outside the enumeration", "the infinity norm");
    expect(near(sparse_operator_norm_float(norms, SPARSE_NORM_ONE), 8.0, 1e-6), "the operator one norm", "8");
    expect(near(sparse_operator_norm_float(norms, SPARSE_NORM_INF), 9.0, 1e-6), "the operator infinity norm", "9");
    expect(near(sparse_operator_norm_float(norms, SPARSE_NORM_TWO), 6.70179, 5e-3), "the operator two norm",
           "6.70179, the exact largest singular value, against the host's 6.69983");
    expect(isnan(sparse_operator_norm_float(norms, SPARSE_NORM_R1)), "the operator R1 norm", "NaN");
    expect(near(sparse_matrix_trace_float(norms, 0), -1.0, 1e-6), "the trace", "-1");
    expect(near(sparse_matrix_trace_float(norms, 5), 0.0, 1e-6), "a trace past the last column", "0");
    sparse_matrix_destroy(norms);

    // The double side of the three that have one, and of the levels 1 to 3.
    sparse_matrix_double D = sparse_matrix_create_double(2, 2);
    sparse_insert_entry_double(D, 1, 0, 0);
    sparse_insert_entry_double(D, 2, 0, 1);
    sparse_insert_entry_double(D, 3, 1, 0);
    sparse_insert_entry_double(D, 4, 1, 1);
    double Cd[4] = {0, 0, 0, 0};
    expect(sparse_matrix_product_dense_double(CblasRowMajor, CblasNoTrans, 2, 0.5, D, (double[]){1, 2, 3, 4}, 2, Cd,
                                              2) == SPARSE_SUCCESS && Cd[0] == 3.5 && Cd[1] == 5.0 && Cd[2] == 7.5 &&
               Cd[3] == 11.0,
           "a double dense product", "3.5, 5, 7.5, 11");
    expect(near(sparse_elementwise_norm_double(D, SPARSE_NORM_ONE), 10.0, 1e-12), "the double one norm", "10");
    expect(near(sparse_matrix_trace_double(D, 0), 5.0, 1e-12), "the double trace", "5");
    expect(near(sparse_vector_norm_double(2, (double[]){3, 4}, (sparse_index[]){0, 1}, SPARSE_NORM_TWO), 5.0, 1e-12),
           "the double two norm", "5");
    double yd[2] = {1, 1};
    sparse_vector_add_with_scale_dense_double(2, 3.0, (double[]){1, 2}, (sparse_index[]){0, 1}, yd, 1);
    expect(yd[0] == 4.0 && yd[1] == 7.0, "a double scaled addition", "4, 7");
    expect(near(sparse_inner_product_dense_double(2, (double[]){3, 4}, (sparse_index[]){0, 1}, (double[]){1, 2}, 1), 11.0,
               1e-12),
           "a double inner product", "11");
    sparse_matrix_destroy(D);

    // The level-3 forms, and the permutations, and the outer product.
    sparse_matrix_float A3 = sparse_matrix_create_float(2, 3);
    sparse_insert_entry_float(A3, 1, 0, 0);
    sparse_insert_entry_float(A3, 2, 0, 2);
    sparse_insert_entry_float(A3, 3, 1, 1);
    sparse_insert_entry_float(A3, 4, 1, 2);
    float B3[12] = {1, 2, 9, 9, 3, 4, 9, 9, 5, 6, 9, 9};
    float C3[6] = {0, 0, 0, 0, 0, 0};
    // B is 3x2 with a leading dimension of 3, so its rows are (1,2), (9,3) and (9,5) and the product is
    // 1*1 + 0*9 + 2*9, 1*2 + 0*3 + 2*5, 0*1 + 3*9 + 4*9 and 0*2 + 3*3 + 4*5.
    sparse_status denseStatus = sparse_matrix_product_dense_float(CblasRowMajor, CblasNoTrans, 2, 1.0f, A3, B3, 3, C3, 2);
    snprintf(detail, sizeof detail, "status %d, %g, %g, %g, %g", denseStatus, C3[0], C3[1], C3[2], C3[3]);
    expect(denseStatus == SPARSE_SUCCESS && C3[0] == 19.0f && C3[1] == 20.0f && C3[2] == 63.0f && C3[3] == 45.0f,
           "a dense product", detail);
    expect(sparse_matrix_product_dense_float(CblasRowMajor, CblasNoTrans, 2, 1.0f, A3, B3, 1, C3, 2) ==
               SPARSE_ILLEGAL_PARAMETER,
           "a dense product with a leading dimension of one", "SPARSE_ILLEGAL_PARAMETER, C untouched");
    sparse_matrix_float S3 = sparse_matrix_create_float(3, 2);
    sparse_insert_entry_float(S3, 1, 0, 0);
    sparse_insert_entry_float(S3, 1, 0, 1);
    sparse_insert_entry_float(S3, 1, 1, 0);
    sparse_insert_entry_float(S3, 2, 2, 1);
    float C4[4] = {0, 0, 0, 0};
    expect(sparse_matrix_product_sparse_float(CblasRowMajor, CblasNoTrans, 1.0f, A3, S3, C4, 2) == SPARSE_SUCCESS &&
               C4[0] == 1.0f && C4[1] == 5.0f && C4[2] == 3.0f && C4[3] == 8.0f,
           "a sparse product", "1, 5, 3, 8");
    sparse_matrix_destroy(S3);
    sparse_matrix_destroy(A3);

    sparse_matrix_float rows = sparse_matrix_create_float(2, 3);
    sparse_insert_entries_float(rows, 6, (float[]){1, 2, 3, 4, 5, 6}, (sparse_index[]){0, 0, 0, 1, 1, 1},
                               (sparse_index[]){0, 1, 2, 0, 1, 2});
    expect(sparse_permute_cols_float(rows, (sparse_index[]){1, 0, 0}) == SPARSE_SUCCESS, "a column permutation",
           "SPARSE_SUCCESS");
    {
        float seen[6] = {0};
        for (sparse_index r = 0; r < 2; r++) {
            sparse_index c = 0;
            while (c < 3) {
                sparse_index e = 0, j = 0;
                float v = 0.0f;
                if (sparse_extract_sparse_row_float(rows, r, c, &e, 1, &v, &j) != 1) { c++; continue; }
                seen[r * 3 + j] = v;
                c = e > c ? e : c + 1;
            }
        }
        expect(seen[0] == 3.0f && seen[1] == 2.0f && seen[2] == 1.0f && seen[3] == 6.0f && seen[4] == 5.0f &&
                   seen[5] == 4.0f,
               "a column permutation's result", "3, 2, 1, 6, 5, 4");
    }
    sparse_matrix_destroy(rows);

    sparse_matrix_float outer = NULL;
    expect(sparse_outer_product_dense_float(2, 3, 2, 2.0f, (float[]){1, 1}, 1, (float[]){3, 4},
                                            (sparse_index[]){0, 2}, &outer) == SPARSE_SUCCESS && outer != NULL,
           "an outer product", "SPARSE_SUCCESS and a matrix");
    if (outer) {
        expect(sparse_get_matrix_number_of_rows(outer) == 2 && sparse_get_matrix_number_of_columns(outer) == 3 &&
                   sparse_get_matrix_nonzero_count(outer) == 4,
               "the outer product's shape", "2 x 3 with four entries");
        sparse_matrix_destroy(outer);
    }
    outer = NULL;
    expect(sparse_outer_product_dense_float(2, 3, 4, 1.0f, (float[]){1, 1}, 1, (float[]){3, 4, 5, 6},
                                            (sparse_index[]){0, 1, 2, 3}, &outer) == SPARSE_ILLEGAL_PARAMETER &&
               outer == NULL,
           "an outer product with more nonzeros than columns", "SPARSE_ILLEGAL_PARAMETER and no matrix");

    // And the batch insertions, measured: appending, overwriting, and a count of zero.
    sparse_matrix_float batch = sparse_matrix_create_float(4, 4);
    expect(sparse_insert_entries_float(batch, 3, (float[]){1, 2, 3}, (sparse_index[]){0, 2, 1},
                                       (sparse_index[]){3, 0, 2}) == SPARSE_SUCCESS &&
               sparse_get_matrix_nonzero_count(batch) == 3,
           "a batch of entries", "three entries");
    expect(sparse_insert_entries_float(batch, 0, (float[]){1, 2, 3}, (sparse_index[]){0, 2, 1},
                                       (sparse_index[]){3, 0, 2}) == SPARSE_SUCCESS &&
               sparse_get_matrix_nonzero_count(batch) == 3,
           "a batch of nothing", "three entries still");
    expect(sparse_insert_col_float(batch, 0, 2, (float[]){5, 6}, (sparse_index[]){0, 2}) == SPARSE_SUCCESS &&
               sparse_get_matrix_nonzero_count(batch) == 4,
           "a column inserted over what is there", "four entries");
    expect(sparse_insert_row_float(batch, 0, 2, (float[]){7, 8}, (sparse_index[]){1, 2}) == SPARSE_SUCCESS &&
               sparse_get_matrix_nonzero_count(batch) == 6,
           "a row inserted over what is there", "six entries");
    sparse_matrix_float blockOnly = sparse_matrix_block_create_float(2, 2, 2, 2);
    expect(sparse_insert_entry_float(blockOnly, 1, 0, 0) == SPARSE_ILLEGAL_PARAMETER,
           "a point entry into a block matrix", "SPARSE_ILLEGAL_PARAMETER");
    expect(sparse_insert_block_float(sparse_matrix_create_float(4, 4), (float[]){1, 2, 3, 4}, 2, 1, 0, 0) ==
               SPARSE_ILLEGAL_PARAMETER,
           "a block entry into a point-wise matrix", "SPARSE_ILLEGAL_PARAMETER");
    sparse_matrix_destroy(blockOnly);
    sparse_matrix_destroy(batch);
    sparse_matrix_destroy(A);
    sparse_matrix_destroy(triangle);

    snprintf(detail, sizeof detail, "%d checks, %d failures", checks, failures);
    printf("%s\n", detail);
    return failures ? 1 : 0;
}
