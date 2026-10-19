// The port's LinearAlgebra8.m and AppleBLAS8.m held against the host's own Accelerate, case by case.
//
// The port's sources are compiled with every API name it defines renamed, so this translation unit
// can hold the port's objects and the host's side by side and compare what each answers: the status,
// the shape, and every element. The 42 la_* and the 2 appleblas_* prototypes are the ones of the
// headers of iOS 16.4, which is what the port's own translation units are compiled against; the types
// they use (la_object_t, la_count_t, la_index_t, la_status_t, la_norm_t, la_attribute_t) are the
// host's, so the two sides are called through one set of declarations.
//
// Nothing here reaches into an object: each side's own accessor reads its own objects, because the
// port's objects and the host's are different classes with different layouts.

#import <Accelerate/Accelerate.h>
#import <Foundation/Foundation.h>
#include <math.h>
#include <stdio.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

void charon_host_la_add_attributes(la_object_t object, la_attribute_t attributes);
void charon_host_la_remove_attributes(la_object_t object, la_attribute_t attributes);
la_status_t charon_host_la_status(la_object_t object);
la_object_t charon_host_la_retain(la_object_t object);
void charon_host_la_release(la_object_t object);
la_count_t charon_host_la_matrix_rows(la_object_t matrix);
la_count_t charon_host_la_matrix_cols(la_object_t matrix);
la_count_t charon_host_la_vector_length(la_object_t vector);
la_object_t charon_host_la_matrix_from_float_buffer(const float *buffer, la_count_t matrix_rows, la_count_t matrix_cols, la_count_t matrix_row_stride, la_hint_t matrix_hint, la_attribute_t attributes);
la_object_t charon_host_la_matrix_from_double_buffer(const double *buffer, la_count_t matrix_rows, la_count_t matrix_cols, la_count_t matrix_row_stride, la_hint_t matrix_hint, la_attribute_t attributes);
la_object_t charon_host_la_matrix_from_float_buffer_nocopy(float *buffer, la_count_t matrix_rows, la_count_t matrix_cols, la_count_t matrix_row_stride, la_hint_t matrix_hint, la_deallocator_t deallocator, la_attribute_t attributes);
la_object_t charon_host_la_matrix_from_double_buffer_nocopy(double *buffer, la_count_t matrix_rows, la_count_t matrix_cols, la_count_t matrix_row_stride, la_hint_t matrix_hint, la_deallocator_t deallocator, la_attribute_t attributes);
la_status_t charon_host_la_vector_to_float_buffer(float *buffer, la_index_t buffer_stride, la_object_t vector);
la_status_t charon_host_la_vector_to_double_buffer(double *buffer, la_index_t buffer_stride, la_object_t vector);
la_status_t charon_host_la_matrix_to_float_buffer(float *buffer, la_count_t buffer_row_stride, la_object_t matrix);
la_status_t charon_host_la_matrix_to_double_buffer(double *buffer, la_count_t buffer_row_stride, la_object_t matrix);
la_object_t charon_host_la_vector_slice(la_object_t vector, la_index_t vector_first, la_index_t vector_stride, la_count_t slice_length);
la_object_t charon_host_la_matrix_slice(la_object_t matrix, la_index_t matrix_first_row, la_index_t matrix_first_col, la_index_t matrix_row_stride, la_index_t matrix_col_stride, la_count_t slice_rows, la_count_t slice_cols);
la_object_t charon_host_la_identity_matrix(la_count_t matrix_size, la_scalar_type_t scalar_type, la_attribute_t attributes);
la_object_t charon_host_la_splat_from_float(float scalar_value, la_attribute_t attributes);
la_object_t charon_host_la_splat_from_double(double scalar_value, la_attribute_t attributes);
la_object_t charon_host_la_splat_from_vector_element(la_object_t vector, la_index_t vector_index);
la_object_t charon_host_la_splat_from_matrix_element(la_object_t matrix, la_index_t matrix_row, la_index_t matrix_col);
la_object_t charon_host_la_vector_from_splat(la_object_t splat, la_count_t vector_length);
la_object_t charon_host_la_matrix_from_splat(la_object_t splat, la_count_t matrix_rows, la_count_t matrix_cols);
la_object_t charon_host_la_vector_from_matrix_row(la_object_t matrix, la_count_t matrix_row);
la_object_t charon_host_la_vector_from_matrix_col(la_object_t matrix, la_count_t matrix_col);
la_object_t charon_host_la_vector_from_matrix_diagonal(la_object_t matrix, la_index_t matrix_diagonal);
la_object_t charon_host_la_diagonal_matrix_from_vector(la_object_t vector, la_index_t matrix_diagonal);
la_object_t charon_host_la_transpose(la_object_t matrix);
la_object_t charon_host_la_scale_with_float(la_object_t matrix, float scalar);
la_object_t charon_host_la_scale_with_double(la_object_t matrix, double scalar);
la_object_t charon_host_la_sum(la_object_t obj_left, la_object_t obj_right);
la_object_t charon_host_la_difference(la_object_t obj_left, la_object_t obj_right);
la_object_t charon_host_la_elementwise_product(la_object_t obj_left, la_object_t obj_right);
la_object_t charon_host_la_inner_product(la_object_t vector_left, la_object_t vector_right);
la_object_t charon_host_la_outer_product(la_object_t vector_left, la_object_t vector_right);
la_object_t charon_host_la_matrix_product(la_object_t matrix_left, la_object_t matrix_right);
float charon_host_la_norm_as_float(la_object_t vector, la_norm_t vector_norm);
double charon_host_la_norm_as_double(la_object_t vector, la_norm_t vector_norm);
la_object_t charon_host_la_normalized_vector(la_object_t vector, la_norm_t vector_norm);
la_object_t charon_host_la_solve(la_object_t matrix_system, la_object_t obj_rhs);

// The two entry points the release's own header reaches through macros are deliberately NOT renamed:
// vecLib/LinearAlgebra/object.h redefines them, which defeats a -D, so the port's own definitions keep
// their names and win the link against the host library's (measured: a definition of _la_retain in an
// object links against -framework Accelerate without a duplicate symbol and is the one that runs).
// Both are called here as the C functions they are.
#undef la_retain
#undef la_release
la_object_t la_retain(la_object_t object);
void la_release(la_object_t object);

void charon_host_appleblas_sgeadd(const enum CBLAS_ORDER order, const enum CBLAS_TRANSPOSE transA,
                                  const enum CBLAS_TRANSPOSE transB, const int m, const int n, const float alpha,
                                  const float *A, const int lda, const float beta, const float *B, const int ldb,
                                  float *C, const int ldc);
void charon_host_appleblas_dgeadd(const enum CBLAS_ORDER order, const enum CBLAS_TRANSPOSE transA,
                                  const enum CBLAS_TRANSPOSE transB, const int m, const int n, const double alpha,
                                  const double *A, const int lda, const double beta, const double *B, const int ldb,
                                  double *C, const int ldc);

static int failures;
static int checks;

static void report(int passed, const char *name, const char *detail)
{
    checks++;
    if (passed) {
        printf("ok %s\n", name);
    } else {
        failures++;
        printf("FAIL %s: %s\n", name, detail);
    }
    fflush(stdout);
}

static char detail[512];

// One float element of each side, through that side's own accessor. A side that cannot be read as
// float (a double object, a splat, an object carrying an error) reads as NAN, which is the answer
// either side gives, so a NaN on one side and not the other is a difference worth reporting.
static float element_of_mine(la_object_t object, la_count_t at)
{
    float buffer[64] = {0};
    la_count_t rows = charon_host_la_matrix_rows(object), cols = charon_host_la_matrix_cols(object);
    if (!rows || !cols || rows * cols > 64 || charon_host_la_matrix_to_float_buffer(buffer, cols, object) != LA_SUCCESS) {
        return NAN;
    }
    return buffer[at];
}

static float element_of_theirs(la_object_t object, la_count_t at)
{
    float buffer[64] = {0};
    la_count_t rows = la_matrix_rows(object), cols = la_matrix_cols(object);
    if (!rows || !cols || rows * cols > 64 || la_matrix_to_float_buffer(buffer, cols, object) != LA_SUCCESS) {
        return NAN;
    }
    return buffer[at];
}

// The same object, made twice: once by the port and once by the host, from the same inputs. The name
// is the case; the tolerance is how far the elements may differ, which is 0 everywhere except where
// a sum over a vector is the arithmetic itself and the two sides may sum in a different order.
static void same(const char *name, la_object_t mine, la_object_t theirs, double tolerance)
{
    long my_status = (long)charon_host_la_status(mine), their_status = (long)la_status(theirs);
    la_count_t my_rows = charon_host_la_matrix_rows(mine), their_rows = la_matrix_rows(theirs);
    la_count_t my_cols = charon_host_la_matrix_cols(mine), their_cols = la_matrix_cols(theirs);
    la_count_t my_length = charon_host_la_vector_length(mine), their_length = la_vector_length(theirs);
    if (my_status != their_status || my_rows != their_rows || my_cols != their_cols || my_length != their_length) {
        snprintf(detail, sizeof detail, "status %ld/%ld rows %lu/%lu cols %lu/%lu length %lu/%lu", my_status, their_status,
                 (unsigned long)my_rows, (unsigned long)their_rows, (unsigned long)my_cols, (unsigned long)their_cols,
                 (unsigned long)my_length, (unsigned long)their_length);
        report(0, name, detail);
        return;
    }
    la_count_t count = my_rows * my_cols;
    for (la_count_t at = 0; at < count && at < 64; at++) {
        float x = element_of_mine(mine, at), y = element_of_theirs(theirs, at);
        double difference = fabs((double)x - (double)y);
        double scale = fabs((double)y) > 1.0 ? fabs((double)y) : 1.0;
        if (isnan(x) && isnan(y)) {
            continue;   // neither side could be read as a float, which is the same answer twice
        }
        if (!(difference <= tolerance * scale)) {
            snprintf(detail, sizeof detail, "element %lu is %g, the host says %g", (unsigned long)at, x, y);
            report(0, name, detail);
            return;
        }
    }
    report(1, name, "");
}

// A case where the host does not answer the same thing twice, and the port answers what the header
// documents. la_solve of a matrix with an exactly zero pivot is LA_SINGULAR_ERROR in
// vecLib/LinearAlgebra/linear_systems.h, and the host answers LA_SUCCESS in a fresh process with a store
// that reports LA_SINGULAR_ERROR after filling the buffer with NaNs, and LA_SUCCESS with a store that
// succeeds and writes zeros once another solve has run in the same process. So the case passes while the
// port answers LA_SINGULAR_ERROR and the host answers either of its two, and fails on anything else -
// which is what tells us this note has gone stale.
static void diverges(const char *name, la_object_t mine, la_object_t theirs)
{
    long my_status = (long)charon_host_la_status(mine), their_status = (long)la_status(theirs);
    int agreed = (my_status == LA_SINGULAR_ERROR &&
                  (their_status == LA_SUCCESS || their_status == LA_SINGULAR_ERROR));
    snprintf(detail, sizeof detail, "the port says %ld, the host says %ld", my_status, their_status);
    report(agreed, name, agreed ? "" : detail);
    if (agreed) {
        printf("     %s: the port answers LA_SINGULAR_ERROR as the header documents, the host %ld\n", name, their_status);
    }
}

// A scalar answer, for the norms and for a buffer that is written rather than an object that is made.
static void scalar(const char *name, double mine, double theirs, double tolerance)
{
    double difference = fabs(mine - theirs);
    double scale = fabs(theirs) > 1.0 ? fabs(theirs) : 1.0;
    if (isnan(mine) && isnan(theirs)) {
        report(1, name, "");
        return;
    }
    if (difference <= tolerance * scale) {
        report(1, name, "");
        return;
    }
    snprintf(detail, sizeof detail, "the port says %.9g, the host says %.9g", mine, theirs);
    report(0, name, detail);
}

static la_object_t mine_float(const float *buffer, la_count_t rows, la_count_t cols)
{
    return charon_host_la_matrix_from_float_buffer(buffer, rows, cols, cols, LA_NO_HINT, LA_DEFAULT_ATTRIBUTES);
}

static la_object_t theirs_float(const float *buffer, la_count_t rows, la_count_t cols)
{
    return la_matrix_from_float_buffer(buffer, rows, cols, cols, LA_NO_HINT, LA_DEFAULT_ATTRIBUTES);
}

static la_object_t mine_double(const double *buffer, la_count_t rows, la_count_t cols)
{
    return charon_host_la_matrix_from_double_buffer(buffer, rows, cols, cols, LA_NO_HINT, LA_DEFAULT_ATTRIBUTES);
}

static la_object_t theirs_double(const double *buffer, la_count_t rows, la_count_t cols)
{
    return la_matrix_from_double_buffer(buffer, rows, cols, cols, LA_NO_HINT, LA_DEFAULT_ATTRIBUTES);
}

// Where a result is a sum over a vector, the two sides add the same terms in a different order and the
// answers differ in the last place a float has - the host answers 0.0909090787 and 0.636363685 for
// [[4,1],[1,3]] against [1,2] where this port answers 0.0909090936 and 0.636363626, both roundings of
// 1/11 and 7/11 (facts/Accelerate/LinearAlgebra.md). So a sum is compared to a thousandth of a place
// and everything else is compared exactly: a status, a shape, an element that is a sum of two values,
// a slice, a transpose, a norm, a dot product of whole numbers. A tolerance of zero here would be
// asserting that two independent summations produce the same bits.
#define TOLERANT 1e-5
#define EXACT 0.0

int main(void)
{
    const float six[6] = {1, 2, 3, 4, 5, 6};
    const float other_six[6] = {10, 20, 30, 40, 50, 60};
    const float four[4] = {1, 2, 3, 4};
    const float other_four[4] = {5, 6, 7, 8};
    const double four_d[4] = {1.5, 2.5, 3.5, 4.5};
    const float three[3] = {1, 2, 3};
    const float eight[8] = {1, 2, 3, 4, 5, 6, 7, 8};
    la_object_t v6 = mine_float(six, 6, 1), w6 = mine_float(other_six, 6, 1);
    la_object_t t6 = theirs_float(six, 6, 1), u6 = theirs_float(other_six, 6, 1);
    la_object_t m1 = mine_float(four, 2, 2), m2 = mine_float(other_four, 2, 2);
    la_object_t n1 = theirs_float(four, 2, 2), n2 = theirs_float(other_four, 2, 2);
    la_object_t d1 = mine_double(four_d, 2, 2), e1 = theirs_double(four_d, 2, 2);
    la_object_t sp_mine = charon_host_la_splat_from_float(3.0f, LA_DEFAULT_ATTRIBUTES);
    la_object_t sp_theirs = la_splat_from_float(3.0f, LA_DEFAULT_ATTRIBUTES);
    la_object_t spd_mine = charon_host_la_splat_from_double(3.0, LA_DEFAULT_ATTRIBUTES);
    la_object_t bad_mine = charon_host_la_matrix_from_float_buffer(three, 0, 0, 0, LA_NO_HINT, LA_DEFAULT_ATTRIBUTES);
    la_object_t bad_theirs = la_matrix_from_float_buffer(three, 0, 0, 0, LA_NO_HINT, LA_DEFAULT_ATTRIBUTES);
    la_object_t empty_mine = charon_host_la_vector_from_splat(sp_mine, 0);
    la_object_t empty_theirs = la_vector_from_splat(sp_theirs, 0);
    la_object_t spd_theirs = la_splat_from_double(3.0, LA_DEFAULT_ATTRIBUTES);

    // the shape a caller reads
    same("rows and cols of a 6x1", v6, t6, EXACT);
    same("rows and cols of a 2x2", m1, n1, EXACT);
    same("rows and cols of a 2x3", mine_float(eight, 2, 3), theirs_float(eight, 2, 3), EXACT);
    same("rows and cols of a 3x2", mine_float(eight, 3, 2), theirs_float(eight, 3, 2), EXACT);
    same("rows and cols of a 1x3", mine_float(three, 1, 3), theirs_float(three, 1, 3), EXACT);
    same("an empty shape from a buffer", mine_float(three, 0, 0), theirs_float(three, 0, 0), EXACT);
    same("no rows from a buffer", mine_float(three, 0, 3), theirs_float(three, 0, 3), EXACT);
    same("no columns from a buffer", mine_float(three, 3, 0), theirs_float(three, 3, 0), EXACT);
    same("a row stride that does not cover a row", charon_host_la_matrix_from_float_buffer(three, 3, 1, 0, LA_NO_HINT, 0),
         la_matrix_from_float_buffer(three, 3, 1, 0, LA_NO_HINT, 0), EXACT);
    same("an object carrying an error, on the left", charon_host_la_sum(bad_mine, v6), la_sum(bad_theirs, t6), EXACT);
    same("an object carrying an error, on the right", charon_host_la_sum(v6, bad_mine), la_sum(t6, bad_theirs), EXACT);
    same("scale of an object carrying an error", charon_host_la_scale_with_float(bad_mine, 1.0f),
         la_scale_with_float(bad_theirs, 1.0f), EXACT);
    same("transpose of an object carrying an error", charon_host_la_transpose(bad_mine), la_transpose(bad_theirs), EXACT);
    same("la_sum of two empty vectors", charon_host_la_sum(empty_mine, empty_mine), la_sum(empty_theirs, empty_theirs),
         EXACT);
    same("la_inner_product of two empty vectors", charon_host_la_inner_product(empty_mine, empty_mine),
         la_inner_product(empty_theirs, empty_theirs), EXACT);
    same("la_outer_product of two empty vectors", charon_host_la_outer_product(empty_mine, empty_mine),
         la_outer_product(empty_theirs, empty_theirs), EXACT);
    same("la_vector_slice of no elements", charon_host_la_vector_slice(empty_mine, 0, 1, 0),
         la_vector_slice(empty_theirs, 0, 1, 0), EXACT);
    same("la_matrix_slice of no rows", charon_host_la_matrix_slice(m1, 0, 0, 1, 1, 0, 2),
         la_matrix_slice(n1, 0, 0, 1, 1, 0, 2), EXACT);
    same("la_diagonal_matrix_from_vector of an empty vector", charon_host_la_diagonal_matrix_from_vector(empty_mine, 0),
         la_diagonal_matrix_from_vector(empty_theirs, 0), EXACT);
    same("la_splat_from_vector_element of an empty vector", charon_host_la_splat_from_vector_element(empty_mine, 0),
         la_splat_from_vector_element(empty_theirs, 0), EXACT);
    same("la_normalized_vector of an empty shape", charon_host_la_normalized_vector(bad_mine, LA_L2_NORM),
         la_normalized_vector(bad_theirs, LA_L2_NORM), EXACT);
    same("la_solve of a right-hand side of no rows", charon_host_la_solve(m1, bad_mine), la_solve(n1, bad_theirs), EXACT);
    same("la_matrix_product of a 0x1 by a 1x0", charon_host_la_matrix_product(bad_mine, bad_mine),
         la_matrix_product(bad_theirs, bad_theirs), EXACT);
    scalar("la_norm_as_float of an empty shape", charon_host_la_norm_as_float(bad_mine, LA_L2_NORM),
           la_norm_as_float(bad_theirs, LA_L2_NORM), EXACT);
    same("rows of a splat", sp_mine, sp_theirs, EXACT);
    same("rows of a double 2x2", d1, e1, EXACT);
    scalar("la_matrix_rows of NULL", charon_host_la_matrix_rows(NULL), la_matrix_rows(NULL), EXACT);
    scalar("la_matrix_cols of NULL", charon_host_la_matrix_cols(NULL), la_matrix_cols(NULL), EXACT);
    scalar("la_vector_length of NULL", charon_host_la_vector_length(NULL), la_vector_length(NULL), EXACT);
    scalar("la_status of NULL", (double)charon_host_la_status(NULL), (double)la_status(NULL), EXACT);
    scalar("la_status of a good object", (double)charon_host_la_status(v6), (double)la_status(t6), EXACT);

    // storage, both directions
    {
        float mine[8] = {0}, theirs[8] = {0};
        la_status_t a = charon_host_la_matrix_to_float_buffer(mine, 3, mine_float(eight, 2, 3));
        la_status_t b = la_matrix_to_float_buffer(theirs, 3, theirs_float(eight, 2, 3));
        int equal = a == b && memcmp(mine, theirs, sizeof mine) == 0;
        snprintf(detail, sizeof detail, "status %ld/%ld", (long)a, (long)b);
        report(equal, "la_matrix_to_float_buffer of a 2x3", equal ? "" : detail);
    }
    {
        float mine[8] = {0}, theirs[8] = {0};
        la_status_t a = charon_host_la_matrix_to_float_buffer(mine, 2, mine_float(eight, 2, 3));
        la_status_t b = la_matrix_to_float_buffer(theirs, 2, theirs_float(eight, 2, 3));
        int equal = a == b && memcmp(mine, theirs, sizeof mine) == 0;
        report(equal, "la_matrix_to_float_buffer with a wider row stride", equal ? "" : detail);
    }
    {
        double mine[8] = {0}, theirs[8] = {0};
        la_status_t a = charon_host_la_matrix_to_double_buffer(mine, 2, mine_double(four_d, 2, 2));
        la_status_t b = la_matrix_to_double_buffer(theirs, 2, theirs_double(four_d, 2, 2));
        int equal = a == b && memcmp(mine, theirs, sizeof mine) == 0;
        report(equal, "la_matrix_to_double_buffer of a double 2x2", equal ? "" : detail);
    }
    {
        // A float object in a double buffer, a double object in a float buffer, and an object
        // carrying an error, all three measured to be refused.
        float mine[4] = {7, 7, 7, 7}, theirs[4] = {7, 7, 7, 7};
        double dmine[4] = {7, 7, 7, 7}, dtheirs[4] = {7, 7, 7, 7};
        la_status_t a = charon_host_la_matrix_to_float_buffer(mine, 2, mine_double(four_d, 2, 2));
        la_status_t b = la_matrix_to_float_buffer(theirs, 2, theirs_double(four_d, 2, 2));
        report(a == b && memcmp(mine, theirs, sizeof mine) == 0, "a double object in a float buffer", "");
        a = charon_host_la_matrix_to_double_buffer(dmine, 2, mine_float(four, 2, 2));
        b = la_matrix_to_double_buffer(dtheirs, 2, theirs_float(four, 2, 2));
        report(a == b && memcmp(dmine, dtheirs, sizeof dmine) == 0, "a float object in a double buffer", "");
        la_object_t mismatch_mine = charon_host_la_sum(mine_float(six, 6, 1), mine_float(three, 3, 1));
        la_object_t mismatch_theirs = la_sum(theirs_float(six, 6, 1), theirs_float(three, 3, 1));
        a = charon_host_la_vector_to_float_buffer(mine, 1, mismatch_mine);
        b = la_vector_to_float_buffer(theirs, 1, mismatch_theirs);
        report(a == b, "an object carrying an error into a float buffer", "");
        same("the object that carries the error", mismatch_mine, mismatch_theirs, EXACT);
    }
    {
        float mine[8] = {0}, theirs[8] = {0};
        la_status_t a = charon_host_la_vector_to_float_buffer(mine, 1, mine_float(six, 6, 1));
        la_status_t b = la_vector_to_float_buffer(theirs, 1, theirs_float(six, 6, 1));
        report(a == b && memcmp(mine, theirs, sizeof mine) == 0, "la_vector_to_float_buffer of a 6x1", "");
        a = charon_host_la_vector_to_float_buffer(mine, 1, mine_float(four, 2, 2));
        b = la_vector_to_float_buffer(theirs, 1, theirs_float(four, 2, 2));
        report(a == b, "la_vector_to_float_buffer of a 2x2", "");
    }
    {
        // The sixteen refusals: each of the four stores of a float splat, a double splat and an object
        // carrying an error, in both scalar types. The host's order is the scalar type first and then
        // the shape, so a splat of the buffer's own type is refused for having no shape
        // (LA_INVALID_PARAMETER_ERROR) and a splat of the other type for its precision
        // (LA_PRECISION_MISMATCH_ERROR), while an object carrying an error has no scalar type of its own
        // and is refused for the precision in all four. The buffer is compared as well as the status, so
        // a refusal that wrote something would be a difference (facts/Accelerate/LinearAlgebra.md).
        la_object_t mine_splat = charon_host_la_splat_from_float(3.0f, LA_DEFAULT_ATTRIBUTES);
        la_object_t theirs_splat = la_splat_from_float(3.0f, LA_DEFAULT_ATTRIBUTES);
        la_object_t mine_double_splat = charon_host_la_splat_from_double(3.0, LA_DEFAULT_ATTRIBUTES);
        la_object_t theirs_double_splat = la_splat_from_double(3.0, LA_DEFAULT_ATTRIBUTES);
        la_object_t mine_failed = charon_host_la_matrix_slice(m1, 0, 0, 1, 1, 9, 9);
        la_object_t theirs_failed = la_matrix_slice(n1, 0, 0, 1, 1, 9, 9);
        struct {
            const char *what;
            la_object_t mine;
            la_object_t theirs;
        } refused[4] = {
            {"a float splat", mine_splat, theirs_splat},
            {"a double splat", mine_double_splat, theirs_double_splat},
            {"an object carrying an error", mine_failed, theirs_failed},
            {"an object made of an empty shape", bad_mine, bad_theirs},
        };
        for (int at = 0; at < 4; at++) {
            char label[96];
            float mf[4] = {7, 7, 7, 7}, tf[4] = {7, 7, 7, 7};
            double md[4] = {7, 7, 7, 7}, td[4] = {7, 7, 7, 7};
            la_status_t m = charon_host_la_vector_to_float_buffer(mf, 1, refused[at].mine);
            la_status_t t = la_vector_to_float_buffer(tf, 1, refused[at].theirs);
            snprintf(detail, sizeof detail, "the port says %ld, the host says %ld", (long)m, (long)t);
            snprintf(label, sizeof label, "la_vector_to_float_buffer of %s", refused[at].what);
            report(m == t && memcmp(mf, tf, sizeof mf) == 0, label, m == t ? "" : detail);
            m = charon_host_la_vector_to_double_buffer(md, 1, refused[at].mine);
            t = la_vector_to_double_buffer(td, 1, refused[at].theirs);
            snprintf(detail, sizeof detail, "the port says %ld, the host says %ld", (long)m, (long)t);
            snprintf(label, sizeof label, "la_vector_to_double_buffer of %s", refused[at].what);
            report(m == t && memcmp(md, td, sizeof md) == 0, label, m == t ? "" : detail);
            m = charon_host_la_matrix_to_float_buffer(mf, 2, refused[at].mine);
            t = la_matrix_to_float_buffer(tf, 2, refused[at].theirs);
            snprintf(detail, sizeof detail, "the port says %ld, the host says %ld", (long)m, (long)t);
            snprintf(label, sizeof label, "la_matrix_to_float_buffer of %s", refused[at].what);
            report(m == t && memcmp(mf, tf, sizeof mf) == 0, label, m == t ? "" : detail);
            m = charon_host_la_matrix_to_double_buffer(md, 2, refused[at].mine);
            t = la_matrix_to_double_buffer(td, 2, refused[at].theirs);
            snprintf(detail, sizeof detail, "the port says %ld, the host says %ld", (long)m, (long)t);
            snprintf(label, sizeof label, "la_matrix_to_double_buffer of %s", refused[at].what);
            report(m == t && memcmp(md, td, sizeof md) == 0, label, m == t ? "" : detail);
        }
    }

    // slices
    same("la_vector_slice(v6, 1, 2, 3)", charon_host_la_vector_slice(v6, 1, 2, 3), la_vector_slice(t6, 1, 2, 3), EXACT);
    same("la_vector_slice(v6, 5, -1, 6) backwards", charon_host_la_vector_slice(v6, 5, -1, 6),
         la_vector_slice(t6, 5, -1, 6), EXACT);
    same("la_vector_slice(v6, 2, 2, 3) out of bounds", charon_host_la_vector_slice(v6, 2, 2, 3),
         la_vector_slice(t6, 2, 2, 3), EXACT);
    same("la_vector_slice(m1) a matrix", charon_host_la_vector_slice(m1, 0, 1, 2), la_vector_slice(n1, 0, 1, 2), EXACT);
    same("la_vector_slice of a splat", charon_host_la_vector_slice(sp_mine, 0, 1, 1), la_vector_slice(sp_theirs, 0, 1, 1),
         EXACT);
    same("la_matrix_slice(m1, 0, 0, 1, 1, 2, 2)", charon_host_la_matrix_slice(m1, 0, 0, 1, 1, 2, 2),
         la_matrix_slice(n1, 0, 0, 1, 1, 2, 2), EXACT);
    same("la_matrix_slice(m1, 0, 1, 1, 1, 2, 1) a column", charon_host_la_matrix_slice(m1, 0, 1, 1, 1, 2, 1),
         la_matrix_slice(n1, 0, 1, 1, 1, 2, 1), EXACT);
    same("la_matrix_slice(m1, 1, 0, 1, 1, 2, 2) out of bounds", charon_host_la_matrix_slice(m1, 1, 0, 1, 1, 2, 2),
         la_matrix_slice(n1, 1, 0, 1, 1, 2, 2), EXACT);
    same("la_matrix_slice of a splat", charon_host_la_matrix_slice(sp_mine, 0, 0, 1, 1, 1, 1),
         la_matrix_slice(sp_theirs, 0, 0, 1, 1, 1, 1), EXACT);

    // the constructors that read one element
    same("la_identity_matrix(3) float", charon_host_la_identity_matrix(3, LA_SCALAR_TYPE_FLOAT, LA_DEFAULT_ATTRIBUTES),
         la_identity_matrix(3, LA_SCALAR_TYPE_FLOAT, LA_DEFAULT_ATTRIBUTES), EXACT);
    same("la_identity_matrix(3) double", charon_host_la_identity_matrix(3, LA_SCALAR_TYPE_DOUBLE, LA_DEFAULT_ATTRIBUTES),
         la_identity_matrix(3, LA_SCALAR_TYPE_DOUBLE, LA_DEFAULT_ATTRIBUTES), EXACT);
    same("la_identity_matrix(0)", charon_host_la_identity_matrix(0, LA_SCALAR_TYPE_FLOAT, LA_DEFAULT_ATTRIBUTES),
         la_identity_matrix(0, LA_SCALAR_TYPE_FLOAT, LA_DEFAULT_ATTRIBUTES), EXACT);
    same("la_identity_matrix(3, no such type)", charon_host_la_identity_matrix(3, 0x1234, LA_DEFAULT_ATTRIBUTES),
         la_identity_matrix(3, 0x1234, LA_DEFAULT_ATTRIBUTES), EXACT);
    same("la_splat_from_float", sp_mine, sp_theirs, EXACT);
    same("la_splat_from_double", spd_mine, spd_theirs, EXACT);
    same("la_splat_from_vector_element(v6, 2)", charon_host_la_splat_from_vector_element(v6, 2),
         la_splat_from_vector_element(t6, 2), EXACT);
    same("la_splat_from_vector_element(v6, 6) out of bounds", charon_host_la_splat_from_vector_element(v6, 6),
         la_splat_from_vector_element(t6, 6), EXACT);
    same("la_splat_from_matrix_element(m1, 1, 1)", charon_host_la_splat_from_matrix_element(m1, 1, 1),
         la_splat_from_matrix_element(n1, 1, 1), EXACT);
    same("la_splat_from_matrix_element(m1, 2, 0) out of bounds", charon_host_la_splat_from_matrix_element(m1, 2, 0),
         la_splat_from_matrix_element(n1, 2, 0), EXACT);
    same("la_splat_from_matrix_element of a splat", charon_host_la_splat_from_matrix_element(sp_mine, 0, 0),
         la_splat_from_matrix_element(sp_theirs, 0, 0), EXACT);
    same("la_vector_from_splat(3)", charon_host_la_vector_from_splat(sp_mine, 3), la_vector_from_splat(sp_theirs, 3), EXACT);
    same("la_vector_from_splat(0)", charon_host_la_vector_from_splat(sp_mine, 0), la_vector_from_splat(sp_theirs, 0),
         EXACT);
    same("la_vector_from_splat of a matrix", charon_host_la_vector_from_splat(m1, 3), la_vector_from_splat(n1, 3), EXACT);
    same("la_matrix_from_splat(2, 3)", charon_host_la_matrix_from_splat(sp_mine, 2, 3), la_matrix_from_splat(sp_theirs, 2, 3),
         EXACT);
    same("la_vector_from_matrix_row(m1, 1)", charon_host_la_vector_from_matrix_row(m1, 1), la_vector_from_matrix_row(n1, 1),
         EXACT);
    same("la_vector_from_matrix_row(m1, 9)", charon_host_la_vector_from_matrix_row(m1, 9), la_vector_from_matrix_row(n1, 9),
         EXACT);
    same("la_vector_from_matrix_row of a splat", charon_host_la_vector_from_matrix_row(sp_mine, 0),
         la_vector_from_matrix_row(sp_theirs, 0), EXACT);
    same("la_vector_from_matrix_col(m1, 1)", charon_host_la_vector_from_matrix_col(m1, 1), la_vector_from_matrix_col(n1, 1),
         EXACT);
    same("la_vector_from_matrix_diagonal(m1, 0)", charon_host_la_vector_from_matrix_diagonal(m1, 0),
         la_vector_from_matrix_diagonal(n1, 0), EXACT);
    same("la_vector_from_matrix_diagonal(m1, 1)", charon_host_la_vector_from_matrix_diagonal(m1, 1),
         la_vector_from_matrix_diagonal(n1, 1), EXACT);
    same("la_vector_from_matrix_diagonal(m1, -1)", charon_host_la_vector_from_matrix_diagonal(m1, -1),
         la_vector_from_matrix_diagonal(n1, -1), EXACT);
    same("la_vector_from_matrix_diagonal(m1, 9)", charon_host_la_vector_from_matrix_diagonal(m1, 9),
         la_vector_from_matrix_diagonal(n1, 9), EXACT);
    same("la_diagonal_matrix_from_vector(v6, 0)", charon_host_la_diagonal_matrix_from_vector(v6, 0),
         la_diagonal_matrix_from_vector(t6, 0), EXACT);
    same("la_diagonal_matrix_from_vector(v6, 1)", charon_host_la_diagonal_matrix_from_vector(v6, 1),
         la_diagonal_matrix_from_vector(t6, 1), EXACT);
    same("la_diagonal_matrix_from_vector(v6, -2)", charon_host_la_diagonal_matrix_from_vector(v6, -2),
         la_diagonal_matrix_from_vector(t6, -2), EXACT);
    same("la_diagonal_matrix_from_vector(v6, 9) past the end", charon_host_la_diagonal_matrix_from_vector(v6, 9),
         la_diagonal_matrix_from_vector(t6, 9), EXACT);
    same("la_diagonal_matrix_from_vector(m1) a matrix", charon_host_la_diagonal_matrix_from_vector(m1, 0),
         la_diagonal_matrix_from_vector(n1, 0), EXACT);
    same("la_diagonal_matrix_from_vector of a splat", charon_host_la_diagonal_matrix_from_vector(sp_mine, 0),
         la_diagonal_matrix_from_vector(sp_theirs, 0), EXACT);
    same("la_transpose(m1)", charon_host_la_transpose(m1), la_transpose(n1), EXACT);
    same("la_transpose(v6)", charon_host_la_transpose(v6), la_transpose(t6), EXACT);
    same("la_transpose of a 2x3", charon_host_la_transpose(mine_float(eight, 2, 3)), la_transpose(theirs_float(eight, 2, 3)),
         EXACT);
    same("la_transpose of a splat", charon_host_la_transpose(sp_mine), la_transpose(sp_theirs), EXACT);

    // scaling
    same("la_scale_with_float(m1, 0.5)", charon_host_la_scale_with_float(m1, 0.5f), la_scale_with_float(n1, 0.5f), EXACT);
    same("la_scale_with_double(m1, 0.5)", charon_host_la_scale_with_double(m1, 0.5), la_scale_with_double(n1, 0.5), EXACT);
    same("la_scale_with_float(d1) a double object", charon_host_la_scale_with_float(d1, 1.0f), la_scale_with_float(e1, 1.0f),
         EXACT);
    same("la_scale_with_double(v6) a float object", charon_host_la_scale_with_double(v6, 1.0), la_scale_with_double(t6, 1.0),
         EXACT);
    same("la_scale_with_float of a splat", charon_host_la_scale_with_float(sp_mine, 1.0f), la_scale_with_float(sp_theirs, 1.0f),
         EXACT);

    // the elementwise operations, and the refusals
    same("la_sum(v6, w6)", charon_host_la_sum(v6, w6), la_sum(t6, u6), EXACT);
    same("la_difference(v6, w6)", charon_host_la_difference(v6, w6), la_difference(t6, u6), EXACT);
    same("la_elementwise_product(v6, w6)", charon_host_la_elementwise_product(v6, w6), la_elementwise_product(t6, u6), EXACT);
    same("la_sum(m1, m2)", charon_host_la_sum(m1, m2), la_sum(n1, n2), EXACT);
    same("la_sum(v6, a splat)", charon_host_la_sum(v6, sp_mine), la_sum(t6, sp_theirs), EXACT);
    same("la_sum(a splat, v6)", charon_host_la_sum(sp_mine, v6), la_sum(sp_theirs, t6), EXACT);
    same("la_difference(a splat, v6)", charon_host_la_difference(sp_mine, v6), la_difference(sp_theirs, t6), EXACT);
    same("la_elementwise_product(v6, a splat)", charon_host_la_elementwise_product(v6, sp_mine),
         la_elementwise_product(t6, sp_theirs), EXACT);
    same("la_sum(two splats)", charon_host_la_sum(sp_mine, sp_mine), la_sum(sp_theirs, sp_theirs), EXACT);
    same("la_sum(a float splat, a double splat)", charon_host_la_sum(sp_mine, spd_mine), la_sum(sp_theirs, spd_theirs), EXACT);
    same("la_sum(v6, d1) a precision mismatch", charon_host_la_sum(v6, d1), la_sum(t6, e1), EXACT);
    same("la_sum(v6, a vector of another length)", charon_host_la_sum(v6, mine_float(three, 3, 1)),
         la_sum(t6, theirs_float(three, 3, 1)), EXACT);
    same("la_sum(v6, m1) a shape", charon_host_la_sum(v6, m1), la_sum(t6, n1), EXACT);

    // products
    same("la_inner_product(v6, w6)", charon_host_la_inner_product(v6, w6), la_inner_product(t6, u6), TOLERANT);
    same("la_inner_product(v6, a splat)", charon_host_la_inner_product(v6, sp_mine), la_inner_product(t6, sp_theirs), EXACT);
    same("la_inner_product(a splat, v6)", charon_host_la_inner_product(sp_mine, v6), la_inner_product(sp_theirs, t6), EXACT);
    same("la_inner_product(v6, a vector of another length)", charon_host_la_inner_product(v6, mine_float(four, 4, 1)),
         la_inner_product(t6, theirs_float(four, 4, 1)), EXACT);
    same("la_inner_product(v6, m1) not a vector", charon_host_la_inner_product(v6, m1), la_inner_product(t6, n1), EXACT);
    same("la_outer_product(v6, w6)", charon_host_la_outer_product(v6, w6), la_outer_product(t6, u6), TOLERANT);
    same("la_outer_product(a splat, v6)", charon_host_la_outer_product(sp_mine, v6), la_outer_product(sp_theirs, t6), EXACT);
    same("la_outer_product(v6, m1) not a vector", charon_host_la_outer_product(v6, m1), la_outer_product(t6, n1), EXACT);
    same("la_matrix_product(m1, m2)", charon_host_la_matrix_product(m1, m2), la_matrix_product(n1, n2), TOLERANT);
    same("la_matrix_product(m1, a splat)", charon_host_la_matrix_product(m1, sp_mine), la_matrix_product(n1, sp_theirs),
         TOLERANT);
    same("la_matrix_product(a splat, m1)", charon_host_la_matrix_product(sp_mine, m1), la_matrix_product(sp_theirs, n1),
         TOLERANT);
    same("la_matrix_product(v6, a splat)", charon_host_la_matrix_product(v6, sp_mine), la_matrix_product(t6, sp_theirs),
         TOLERANT);
    same("la_matrix_product(a splat, v6)", charon_host_la_matrix_product(sp_mine, v6), la_matrix_product(sp_theirs, t6),
         TOLERANT);
    same("la_matrix_product(v6, m1)", charon_host_la_matrix_product(v6, m1), la_matrix_product(t6, n1), EXACT);
    same("la_matrix_product(m1, v6)", charon_host_la_matrix_product(m1, v6), la_matrix_product(n1, t6), EXACT);
    same("la_matrix_product(m1, d1)", charon_host_la_matrix_product(m1, d1), la_matrix_product(n1, e1), EXACT);
    same("la_matrix_product of a 2x3 and a 3x2", charon_host_la_matrix_product(mine_float(eight, 2, 3), mine_float(eight, 3, 2)),
         la_matrix_product(theirs_float(eight, 2, 3), theirs_float(eight, 3, 2)), TOLERANT);
    same("la_matrix_product of two double matrices", charon_host_la_matrix_product(d1, mine_double(four_d, 2, 2)),
         la_matrix_product(e1, theirs_double(four_d, 2, 2)), TOLERANT);

    // the norms
    for (int which = 1; which <= 3; which++) {
        la_norm_t norm = (la_norm_t)which;
        char label[64];
        snprintf(label, sizeof label, "la_norm_as_float(v6, %d)", which);
        scalar(label, charon_host_la_norm_as_float(v6, norm), la_norm_as_float(t6, norm), TOLERANT);
        snprintf(label, sizeof label, "la_norm_as_float(d1, %d)", which);
        scalar(label, charon_host_la_norm_as_float(d1, norm), la_norm_as_float(e1, norm), TOLERANT);
        snprintf(label, sizeof label, "la_norm_as_double(v6, %d)", which);
        scalar(label, charon_host_la_norm_as_double(v6, norm), la_norm_as_double(t6, norm), TOLERANT);
        snprintf(label, sizeof label, "la_norm_as_double(d1, %d)", which);
        scalar(label, charon_host_la_norm_as_double(d1, norm), la_norm_as_double(e1, norm), TOLERANT);
        snprintf(label, sizeof label, "la_norm_as_float(a splat, %d)", which);
        scalar(label, charon_host_la_norm_as_float(sp_mine, norm), la_norm_as_float(sp_theirs, norm), EXACT);
    }
    scalar("la_norm_as_float(v6, no such norm)", charon_host_la_norm_as_float(v6, 99), la_norm_as_float(t6, 99), EXACT);
    {
        const float negative[3] = {-1, 2, -3};
        for (int which = 1; which <= 3; which++) {
            char label[64];
            snprintf(label, sizeof label, "la_norm_as_float([-1,2,-3], %d)", which);
            scalar(label, charon_host_la_norm_as_float(mine_float(negative, 3, 1), (la_norm_t)which),
                   la_norm_as_float(theirs_float(negative, 3, 1), (la_norm_t)which), TOLERANT);
        }
        same("la_normalized_vector(v6, L2)", charon_host_la_normalized_vector(v6, LA_L2_NORM),
             la_normalized_vector(t6, LA_L2_NORM), TOLERANT);
        same("la_normalized_vector(v6, L1)", charon_host_la_normalized_vector(v6, LA_L1_NORM),
             la_normalized_vector(t6, LA_L1_NORM), TOLERANT);
        same("la_normalized_vector(v6, Linf)", charon_host_la_normalized_vector(v6, LA_LINF_NORM),
             la_normalized_vector(t6, LA_LINF_NORM), TOLERANT);
        same("la_normalized_vector([-1,2,-3], Linf)", charon_host_la_normalized_vector(mine_float(negative, 3, 1), LA_LINF_NORM),
             la_normalized_vector(theirs_float(negative, 3, 1), LA_LINF_NORM), TOLERANT);
        same("la_normalized_vector(a zero vector, L2)", charon_host_la_normalized_vector(mine_float(four, 4, 0), LA_L2_NORM),
             la_normalized_vector(theirs_float(four, 4, 0), LA_L2_NORM), TOLERANT);
        same("la_normalized_vector(v6, no such norm)", charon_host_la_normalized_vector(v6, 99),
             la_normalized_vector(t6, 99), EXACT);
        same("la_normalized_vector of a splat", charon_host_la_normalized_vector(sp_mine, LA_L2_NORM),
             la_normalized_vector(sp_theirs, LA_L2_NORM), EXACT);
    }

    // the solve
    {
        const float system[4] = {4, 1, 1, 3};
        const float right[2] = {1, 2};
        const float general[4] = {1, 2, 3, 4};
        const float right2[2] = {5, 6};
        const float singular[4] = {1, 1, 1, 1};
        const float nilpotent[4] = {1, 0, 0, 0};
        const float three[9] = {2, 1, 1, 1, 3, 1, 1, 1, 4};
        const float right3[3] = {1, 2, 3};
        const double system_d[4] = {4, 1, 1, 3};
        const double right_d[2] = {1, 2};
        same("la_solve([[4,1],[1,3]], [1,2])", charon_host_la_solve(mine_float(system, 2, 2), mine_float(right, 2, 1)),
             la_solve(theirs_float(system, 2, 2), theirs_float(right, 2, 1)), TOLERANT);
        same("la_solve([[1,2],[3,4]], [5,6])", charon_host_la_solve(mine_float(general, 2, 2), mine_float(right2, 2, 1)),
             la_solve(theirs_float(general, 2, 2), theirs_float(right2, 2, 1)), TOLERANT);
        diverges("la_solve([[1,1],[1,1]], [1,2]) singular", charon_host_la_solve(mine_float(singular, 2, 2), mine_float(right, 2, 1)),
                 la_solve(theirs_float(singular, 2, 2), theirs_float(right, 2, 1)));
        diverges("la_solve([[1,0],[0,0]], [1,2]) singular", charon_host_la_solve(mine_float(nilpotent, 2, 2), mine_float(right, 2, 1)),
                 la_solve(theirs_float(nilpotent, 2, 2), theirs_float(right, 2, 1)));
        same("la_solve(a 3x3, a 3x1)", charon_host_la_solve(mine_float(three, 3, 3), mine_float(right3, 3, 1)),
             la_solve(theirs_float(three, 3, 3), theirs_float(right3, 3, 1)), TOLERANT);
        same("la_solve(a double system)", charon_host_la_solve(mine_double(system_d, 2, 2), mine_double(right_d, 2, 1)),
             la_solve(theirs_double(system_d, 2, 2), theirs_double(right_d, 2, 1)), TOLERANT);
        same("la_solve with a right-hand side of 1x2", charon_host_la_solve(mine_float(system, 2, 2), mine_float(right, 1, 2)),
             la_solve(theirs_float(system, 2, 2), theirs_float(right, 1, 2)), TOLERANT);
        same("la_solve with a right-hand side of 2x2", charon_host_la_solve(mine_float(system, 2, 2), mine_float(four, 2, 2)),
             la_solve(theirs_float(system, 2, 2), theirs_float(four, 2, 2)), TOLERANT);
        same("la_solve of a 3x2, a least-squares system", charon_host_la_solve(mine_float(eight, 3, 2), mine_float(three, 3, 1)),
             la_solve(theirs_float(eight, 3, 2), theirs_float(three, 3, 1)), EXACT);
        same("la_solve of a 6x1, not square", charon_host_la_solve(v6, v6), la_solve(t6, t6), EXACT);
        same("la_solve with a right-hand side of another length", charon_host_la_solve(mine_float(system, 2, 2), mine_float(three, 3, 1)),
             la_solve(theirs_float(system, 2, 2), theirs_float(three, 3, 1)), EXACT);
        same("la_solve of a double system with a float right-hand side", charon_host_la_solve(mine_double(system_d, 2, 2), v6),
             la_solve(theirs_double(system_d, 2, 2), t6), EXACT);
        same("la_solve with a splat on the right", charon_host_la_solve(mine_float(system, 2, 2), sp_mine),
             la_solve(theirs_float(system, 2, 2), sp_theirs), EXACT);
        same("la_solve with a splat on the left", charon_host_la_solve(sp_mine, mine_float(right, 2, 1)),
             la_solve(sp_theirs, theirs_float(right, 2, 1)), EXACT);
        same("la_solve of a 1x1", charon_host_la_solve(mine_float(four, 1, 1), mine_float(right, 1, 1)),
             la_solve(theirs_float(four, 1, 1), theirs_float(right, 1, 1)), TOLERANT);
        same("la_solve of a 0x0", charon_host_la_solve(mine_float(four, 0, 0), mine_float(four, 0, 0)),
             la_solve(theirs_float(four, 0, 0), theirs_float(four, 0, 0)), EXACT);
    }

    // the reference count, which the two shapes of la_object_t keep in two different places
    {
        __unsafe_unretained la_object_t kept = la_retain((id)v6);
        report(kept == (id)v6, "la_retain answers the object", "");
        la_release((id)v6);
        scalar("la_status after a balanced la_release", (double)charon_host_la_status(v6), (double)la_status(t6), EXACT);
        charon_host_la_add_attributes((id)v6, LA_ATTRIBUTE_ENABLE_LOGGING);
        la_add_attributes((id)t6, LA_ATTRIBUTE_ENABLE_LOGGING);
        same("an object with an attribute", v6, t6, EXACT);
        charon_host_la_remove_attributes((id)v6, LA_ATTRIBUTE_ENABLE_LOGGING);
        la_remove_attributes((id)t6, LA_ATTRIBUTE_ENABLE_LOGGING);
        same("the object after the attribute is removed", v6, t6, EXACT);
    }

    printf("%d checks, %d failures\n", checks, failures);
    return failures == 0 ? 0 : 1;
}
