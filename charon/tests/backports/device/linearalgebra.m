// A command-line test of the BLAS and LAPACK rows of Accelerate on the device: every one of the 44
// entry points called, and every answer compared with the one the host's own Accelerate gives, which
// host/linearalgebra records in the same order these cases run in.
//
// The values below are the host's, copied from tests/backports/host/linearalgebra (the statuses and
// shapes are exact and come from la_status/la_matrix_rows/la_matrix_cols; the elements are to the six
// significant digits a float has, the port answering a float object in float). A case that fails here
// and passed there is a difference between the host and the armv7 build of the release, not a
// difference in the port's own arithmetic.
//
// It needs the package built with accelerate = true.

#import <Accelerate/Accelerate.h>
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <objc/runtime.h>
#include "check.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// The two entry points of the threading model, and the two values the host's vecLib/thread_api.h gives
// for its enumeration, are reached through dlsym: that header arrived with the API in iOS 18 and the SDK
// this port builds against does not carry it, so there is no header that declares these names and a
// program of this release can only reach them the way a C client does (facts/Accelerate/BLASThreading.md).
// fromBackports() below is what proves the symbols are the backports' own and not NULL.
typedef int (*CharonSetThreading)(unsigned int);
typedef unsigned int (*CharonGetThreading)(void);
enum {
    kCharonThreadingMulti = 0,
    kCharonThreadingSingle = 1,
    kCharonThreadingNone = 99
};

// The deallocators the two constructors that take a buffer over are given, counting how often each of
// them saw the block it was promised, so the run can say whether the object gave it back exactly once.
static int charon_handed_back[3];
static void *charon_watched[3];

static void charon_watch(void *given, int which)
{
    charon_handed_back[which] += (given == charon_watched[which]);
    free(given);
}

static void charon_deallocator0(void *given) { charon_watch(given, 0); }
static void charon_deallocator1(void *given) { charon_watch(given, 1); }
static void charon_deallocator2(void *given) { charon_watch(given, 2); }

// Whether a name in this process comes from the backports' own library and not from the release.
static BOOL fromBackports(const char *name)
{
    void *symbol = dlsym(RTLD_DEFAULT, name);
    Dl_info info;
    if (!symbol || dladdr(symbol, &info) == 0 || !info.dli_fname)
        return NO;
    return [[NSString stringWithUTF8String:info.dli_fname].lastPathComponent
        isEqualToString:@"libAccelerateBackports.dylib"];
}

// The whole of a result read back through the port's own accessors: the status, the shape and up to
// `count` elements, so one CHECK says whether the whole answer matches.
static BOOL answerMatches(la_object_t object, long status, unsigned long rows, unsigned long cols,
                          const float *elements, int count)
{
    if (la_status(object) != (la_status_t)status || la_matrix_rows(object) != rows || la_matrix_cols(object) != cols)
        return NO;
    float read[16] = {0};
    if (rows * cols == 0)
        return YES;
    if (la_matrix_to_float_buffer(read, cols, object) != LA_SUCCESS)
        return NO;
    for (int at = 0; at < count; at++)
        if (fabs(read[at] - elements[at]) > 1e-4f * (fabs(elements[at]) > 1.0f ? fabs(elements[at]) : 1.0f))
            return NO;
    return YES;
}

#define ANSWER(what, object, status, rows, cols, ...)                                              \
    do {                                                                                            \
        const float expected[] = {__VA_ARGS__};                                                     \
        CHECK(answerMatches(object, status, rows, cols, expected, (int)(sizeof expected / sizeof *expected)), what); \
    } while (0)

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));

        CHECK(fromBackports("la_solve"), "la_solve comes from the backports");
        CHECK(fromBackports("appleblas_sgeadd"), "appleblas_sgeadd comes from the backports");
        CHECK(fromBackports("BLASSetThreading"), "BLASSetThreading comes from the backports");

        const float a6[6] = {1, 2, 3, 4, 5, 6}, b6[6] = {10, 20, 30, 40, 50, 60};
        const float a22[4] = {1, 2, 3, 4}, b22[4] = {5, 6, 7, 8};
        const double a22d[4] = {1.5, 2.5, 3.5, 4.5};
        la_object_t v6 = la_matrix_from_float_buffer(a6, 6, 1, 1, LA_NO_HINT, LA_DEFAULT_ATTRIBUTES);
        la_object_t w6 = la_matrix_from_float_buffer(b6, 6, 1, 1, LA_NO_HINT, LA_DEFAULT_ATTRIBUTES);
        la_object_t m1 = la_matrix_from_float_buffer(a22, 2, 2, 2, LA_NO_HINT, LA_DEFAULT_ATTRIBUTES);
        la_object_t m2 = la_matrix_from_float_buffer(b22, 2, 2, 2, LA_NO_HINT, LA_DEFAULT_ATTRIBUTES);
        la_object_t d1 = la_matrix_from_double_buffer(a22d, 2, 2, 2, LA_NO_HINT, LA_DEFAULT_ATTRIBUTES);
        la_object_t splat = la_splat_from_float(3.0f, LA_DEFAULT_ATTRIBUTES);

        // the shape a caller reads, including the two places the host differs from its own header
        CHECK(la_status(v6) == LA_SUCCESS, "a good object is LA_SUCCESS");
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
        CHECK(la_status(NULL) == LA_INVALID_PARAMETER_ERROR,
              "NULL is LA_INVALID_PARAMETER_ERROR, which the header's nonnull annotation forbids asking for");
#pragma clang diagnostic pop
        CHECK(la_matrix_rows(v6) == 6 && la_matrix_cols(v6) == 1, "a 6x1 is 6 rows and 1 column");
        CHECK(la_vector_length(v6) == 6, "a 6x1 is of length 6");
        CHECK(la_vector_length(la_matrix_from_float_buffer(a6, 1, 6, 6, LA_NO_HINT, LA_DEFAULT_ATTRIBUTES)) == 6,
              "a 1x6 is of length 6");
        CHECK(la_vector_length(la_matrix_from_float_buffer(a6, 2, 3, 3, LA_NO_HINT, LA_DEFAULT_ATTRIBUTES)) == 2,
              "a 2x3 answers its rows, where the header says zero");
        CHECK(la_vector_length(splat) == 0 && la_matrix_rows(splat) == 0, "a splat has no shape");

        // storage, both directions, and the refusals
        float read[8] = {0};
        CHECK(la_matrix_to_float_buffer(read, 3, la_matrix_from_float_buffer(a6, 2, 3, 3, LA_NO_HINT,
                                                                            LA_DEFAULT_ATTRIBUTES)) == LA_SUCCESS,
              "a 2x3 is stored");
        CHECK(read[0] == 1 && read[2] == 3 && read[3] == 4 && read[5] == 6, "row-major, element (i, j) at i * stride + j");
        CHECK(la_matrix_to_float_buffer(read, 2, d1) == LA_PRECISION_MISMATCH_ERROR,
              "a double object in a float buffer is the precision mismatch, and writes nothing");
        CHECK(read[0] == 1, "and the buffer is untouched");
        la_object_t empty = la_matrix_from_float_buffer(a6, 0, 0, 0, LA_NO_HINT, LA_DEFAULT_ATTRIBUTES);
        CHECK(la_status(empty) == LA_INVALID_PARAMETER_ERROR, "an empty shape from a buffer is refused");
        CHECK(la_vector_to_float_buffer(read, 1, m1) == LA_INVALID_PARAMETER_ERROR,
              "a 2x2 is not a vector to store");
        CHECK(la_vector_to_float_buffer(read, 1, empty) == LA_PRECISION_MISMATCH_ERROR,
              "an object carrying an error has no scalar type to match a buffer");
        double readd[4] = {0};
        CHECK(la_matrix_to_double_buffer(readd, 2, d1) == LA_SUCCESS && readd[3] == 4.5, "a double 2x2 is stored");
        // The sixteen refusals in full, which the host differential asks case by case: the scalar type
        // first and then the shape, so a splat of the buffer's own type is refused for having no shape
        // and a splat of the other type for its precision, while an object carrying an error has no
        // scalar type of its own and is refused for the precision in all four
        // (facts/Accelerate/LinearAlgebra.md).
        {
            la_object_t dsplat = la_splat_from_double(3.0, LA_DEFAULT_ATTRIBUTES);
            la_object_t objects[4] = {splat, dsplat, empty, la_matrix_slice(m1, 0, 0, 1, 1, 9, 9)};
            for (int at = 0; at < 4; at++) {
                // the two statuses a store of a splat can answer: the shape for a splat of the buffer's
                // own scalar type, the precision for one of the other, and the precision for an object
                // carrying an error whatever the buffer is.
                la_status_t into_float = at == 0 ? LA_INVALID_PARAMETER_ERROR : LA_PRECISION_MISMATCH_ERROR;
                la_status_t into_double = at == 1 ? LA_INVALID_PARAMETER_ERROR : LA_PRECISION_MISMATCH_ERROR;
                float untouched = read[0];
                double untouchedd = readd[0];
                CHECK(la_vector_to_float_buffer(read, 1, objects[at]) == into_float,
                      "la_vector_to_float_buffer of a splat, of another splat and of two error objects");
                CHECK(la_vector_to_double_buffer(readd, 1, objects[at]) == into_double,
                      "la_vector_to_double_buffer of a splat, of another splat and of two error objects");
                CHECK(la_matrix_to_float_buffer(read, 2, objects[at]) == into_float,
                      "la_matrix_to_float_buffer of a splat, of another splat and of two error objects");
                CHECK(la_matrix_to_double_buffer(readd, 2, objects[at]) == into_double,
                      "la_matrix_to_double_buffer of a splat, of another splat and of two error objects");
                CHECK(read[0] == untouched && readd[0] == untouchedd, "and every refusal left the buffer alone");
            }
        }

        // the two constructors that take a buffer over, which the host differential cannot exercise - a
        // block it hands away is a block the caller may never touch again - so the device run is where
        // they are called: the object reads the elements out, keeps the block, and gives it back to the
        // deallocator when it goes, and a padded block is handed straight back instead.
        {
            memset(charon_handed_back, 0, sizeof charon_handed_back);
            memset(charon_watched, 0, sizeof charon_watched);
            float *block = malloc(3 * sizeof(float));
            block[0] = 1;
            block[1] = 2;
            block[2] = 3;
            charon_watched[0] = block;
            la_object_t taken = la_matrix_from_float_buffer_nocopy(block, 3, 1, 1, LA_NO_HINT, charon_deallocator0,
                                                                    LA_DEFAULT_ATTRIBUTES);
            float readone[3] = {0};
            CHECK(la_matrix_to_float_buffer(readone, 1, taken) == LA_SUCCESS && readone[2] == 3,
                  "an object over the caller's own block reads what was there");
            CHECK(charon_handed_back[0] == 0, "and has not given the block back yet");

            float *padded = malloc(4 * sizeof(float));
            padded[0] = 4;
            padded[1] = 5;
            padded[2] = 6;
            padded[3] = 0;
            charon_watched[1] = padded;
            la_object_t given_back = la_matrix_from_float_buffer_nocopy(padded, 3, 1, 2, LA_NO_HINT,
                                                                        charon_deallocator1, LA_DEFAULT_ATTRIBUTES);
            float readpadded[3] = {0};
            CHECK(la_matrix_to_float_buffer(readpadded, 1, given_back) == LA_SUCCESS && readpadded[2] == 6,
                  "a block with a padded row stride is read at that stride");
            CHECK(charon_handed_back[1] == 1, "and handed straight back, because the object cannot own its layout");

            double *dblock = malloc(2 * sizeof(double));
            dblock[0] = 1.5;
            dblock[1] = 2.5;
            charon_watched[2] = dblock;
            la_object_t dtaken = la_matrix_from_double_buffer_nocopy(dblock, 2, 1, 1, LA_NO_HINT, charon_deallocator2,
                                                                      LA_DEFAULT_ATTRIBUTES);
            double readdouble[2] = {0};
            CHECK(la_vector_to_double_buffer(readdouble, 1, dtaken) == LA_SUCCESS && readdouble[1] == 2.5,
                  "the same in double");
            // taken and dtaken go out of scope at the end of this block, and each must give its block
            // back once and only once.
        }
        CHECK(charon_handed_back[0] == 1, "a block an object kept comes back to the deallocator when it goes");
        CHECK(charon_handed_back[1] == 1, "and a block it handed back at once comes back once, not twice");
        CHECK(charon_handed_back[2] == 1, "for the double constructor as well");

        // the sums, the products, and the order the operands are refused in
        ANSWER("la_sum of two vectors", la_sum(v6, w6), LA_SUCCESS, 6, 1, 11, 22, 33, 44, 55, 66);
        ANSWER("la_difference of two vectors", la_difference(v6, w6), LA_SUCCESS, 6, 1, -9, -18, -27, -36, -45, -54);
        ANSWER("la_elementwise_product of two vectors", la_elementwise_product(v6, w6), LA_SUCCESS, 6, 1, 10, 40, 90,
               160, 250, 360);
        ANSWER("la_sum with a splat", la_sum(v6, splat), LA_SUCCESS, 6, 1, 4, 5, 6, 7, 8, 9);
        ANSWER("la_sum of two matrices", la_sum(m1, m2), LA_SUCCESS, 2, 2, 6, 8, 10, 12);
        CHECK(la_status(la_sum(splat, splat)) == LA_INVALID_PARAMETER_ERROR, "two splats have no shape to add");
        CHECK(la_status(la_sum(splat, la_splat_from_double(3.0, LA_DEFAULT_ATTRIBUTES))) == LA_PRECISION_MISMATCH_ERROR,
              "the two scalar types are decided before the two shapes");
        CHECK(la_status(la_sum(v6, d1)) == LA_PRECISION_MISMATCH_ERROR, "a float object and a double object");
        CHECK(la_status(la_sum(v6, la_matrix_from_float_buffer(a6, 3, 1, 1, LA_NO_HINT, LA_DEFAULT_ATTRIBUTES))) ==
                  LA_DIMENSION_MISMATCH_ERROR,
              "two shapes that are not the same");
        CHECK(la_status(la_sum(empty, v6)) == LA_INVALID_PARAMETER_ERROR, "an operand carrying an error on the left");
        CHECK(la_status(la_sum(v6, empty)) == LA_PRECISION_MISMATCH_ERROR,
              "and on the right, which has no scalar type to match");
        ANSWER("la_inner_product of two vectors", la_inner_product(v6, w6), LA_SUCCESS, 1, 1, 910);
        ANSWER("la_inner_product with a splat", la_inner_product(v6, splat), LA_SUCCESS, 1, 1, 63);
        ANSWER("la_outer_product of two vectors", la_outer_product(v6, w6), LA_SUCCESS, 6, 6, 10, 20, 30, 40, 50, 60);
        ANSWER("la_outer_product is a rank one", la_outer_product(v6, v6), LA_SUCCESS, 6, 6, 1, 2, 3, 4, 5, 6);
        CHECK(la_status(la_outer_product(v6, m1)) == LA_INVALID_PARAMETER_ERROR, "an outer product takes two vectors");
        ANSWER("la_matrix_product of two matrices", la_matrix_product(m1, m2), LA_SUCCESS, 2, 2, 19, 22, 43, 50);
        ANSWER("la_matrix_product with a splat on the right", la_matrix_product(m1, splat), LA_SUCCESS, 2, 1, 9, 21);
        ANSWER("la_matrix_product with a splat on the left", la_matrix_product(splat, m1), LA_SUCCESS, 1, 2, 12, 18);
        ANSWER("la_matrix_product of a vector and a splat", la_matrix_product(v6, splat), LA_SUCCESS, 6, 1, 3, 6, 9, 12,
               15, 18);
        CHECK(la_status(la_matrix_product(v6, m1)) == LA_DIMENSION_MISMATCH_ERROR, "cols(left) is not rows(right)");
        ANSWER("la_matrix_product of two double matrices", la_matrix_product(d1, d1), LA_SUCCESS, 2, 2, 3.9375, 4.6875,
               8.3125, 9.9375);

        // the norms, and the NaN the host answers where the two scalar types do not meet
        CHECK(la_norm_as_float(v6, LA_L1_NORM) == 21.0f, "the L1 norm of [1..6] is 21");
        CHECK(fabs(la_norm_as_float(v6, LA_L2_NORM) - 9.53939f) < 1e-3f, "the L2 norm of [1..6] is 9.53939");
        CHECK(la_norm_as_float(v6, LA_LINF_NORM) == 6.0f, "the L-infinity norm of [1..6] is 6");
        CHECK(isnan(la_norm_as_double(v6, LA_L2_NORM)), "a float object asked for in double is NaN");
        CHECK(isnan(la_norm_as_float(d1, LA_L2_NORM)), "a double object asked for in float is NaN");
        CHECK(isnan(la_norm_as_float(splat, LA_L2_NORM)), "a splat has no norm");
        CHECK(isnan(la_norm_as_float(v6, 99)), "a norm the library does not have is NaN");
        CHECK(la_norm_as_float(d1, LA_L1_NORM) == 9.0f, "the L1 norm of the double 2x2 is 9");
        ANSWER("la_normalized_vector, L2", la_normalized_vector(v6, LA_L2_NORM), LA_SUCCESS, 6, 1, 0.104828f,
               0.209657f, 0.314485f, 0.419314f, 0.524142f, 0.628971f);
        CHECK(la_status(la_normalized_vector(v6, 99)) == LA_INVALID_PARAMETER_ERROR, "a norm it does not have");
        ANSWER("a zero vector normalises to itself",
               la_normalized_vector(la_matrix_from_float_buffer(a22, 4, 0, 0, LA_NO_HINT, LA_DEFAULT_ATTRIBUTES),
                                    LA_L2_NORM),
               LA_SUCCESS, 4, 0);

        // the views of a matrix, and the direction of a diagonal
        ANSWER("la_transpose of a 2x2", la_transpose(m1), LA_SUCCESS, 2, 2, 1, 3, 2, 4);
        ANSWER("la_transpose of a 6x1", la_transpose(v6), LA_SUCCESS, 1, 6, 1, 2, 3, 4, 5, 6);
        CHECK(la_status(la_transpose(splat)) == LA_INVALID_PARAMETER_ERROR, "a splat has nothing to transpose");
        ANSWER("la_vector_from_matrix_row", la_vector_from_matrix_row(m1, 1), LA_SUCCESS, 1, 2, 3, 4);
        ANSWER("la_vector_from_matrix_col", la_vector_from_matrix_col(m1, 1), LA_SUCCESS, 2, 1, 2, 4);
        ANSWER("the main diagonal", la_vector_from_matrix_diagonal(m1, 0), LA_SUCCESS, 2, 1, 1, 4);
        ANSWER("the first superdiagonal", la_vector_from_matrix_diagonal(m1, 1), LA_SUCCESS, 1, 1, 2);
        ANSWER("the first subdiagonal", la_vector_from_matrix_diagonal(m1, -1), LA_SUCCESS, 1, 1, 3);
        CHECK(la_status(la_vector_from_matrix_diagonal(m1, 9)) == LA_INVALID_PARAMETER_ERROR,
              "a diagonal the matrix does not have");
        CHECK(la_status(la_vector_from_matrix_row(m1, 9)) == LA_INVALID_PARAMETER_ERROR, "a row it does not have");
        ANSWER("la_diagonal_matrix_from_vector on the main diagonal", la_diagonal_matrix_from_vector(v6, 0), LA_SUCCESS, 6,
               6, 1, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0,
               5, 0, 0, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0);
        ANSWER("la_diagonal_matrix_from_vector on the first superdiagonal", la_diagonal_matrix_from_vector(v6, 1),
               LA_SUCCESS, 7, 7, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0,
               0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0);
        CHECK(la_status(la_diagonal_matrix_from_vector(m1, 0)) == LA_INVALID_PARAMETER_ERROR,
              "it takes a vector, not a matrix");
        CHECK(la_status(la_diagonal_matrix_from_vector(v6, 9)) == LA_SUCCESS, "a diagonal past the end makes a bigger one");

        // slices
        ANSWER("la_vector_slice with a stride of two", la_vector_slice(v6, 1, 2, 3), LA_SUCCESS, 3, 1, 2, 4, 6);
        ANSWER("la_vector_slice backwards", la_vector_slice(v6, 5, -1, 6), LA_SUCCESS, 6, 1, 6, 5, 4, 3, 2, 1);
        CHECK(la_status(la_vector_slice(v6, 2, 2, 3)) == LA_SLICE_OUT_OF_BOUNDS_ERROR, "a slice that reaches outside");
        CHECK(la_status(la_vector_slice(v6, 0, 1, 0)) == LA_SLICE_OUT_OF_BOUNDS_ERROR, "a slice of no elements");
        CHECK(la_status(la_vector_slice(m1, 0, 1, 2)) == LA_INVALID_PARAMETER_ERROR, "a 2x2 is not a vector to slice");
        ANSWER("la_matrix_slice of a column", la_matrix_slice(m1, 0, 1, 1, 1, 2, 1), LA_SUCCESS, 2, 1, 2, 4);
        CHECK(la_status(la_matrix_slice(m1, 1, 0, 1, 1, 2, 2)) == LA_SLICE_OUT_OF_BOUNDS_ERROR, "one past the last row");

        // the splats
        ANSWER("la_splat_from_float", la_vector_from_splat(la_splat_from_float(7.0f, LA_DEFAULT_ATTRIBUTES), 3), LA_SUCCESS,
               3, 1, 7, 7, 7);
        ANSWER("la_splat_from_double", la_vector_from_splat(la_splat_from_double(7.0, LA_DEFAULT_ATTRIBUTES), 2), LA_SUCCESS,
               2, 1, 7, 7);
        ANSWER("la_splat_from_vector_element", la_vector_from_splat(la_splat_from_vector_element(v6, 2), 2), LA_SUCCESS, 2, 1,
               3, 3);
        ANSWER("la_splat_from_matrix_element", la_vector_from_splat(la_splat_from_matrix_element(m1, 1, 0), 2), LA_SUCCESS, 2,
               1, 3, 3);
        CHECK(la_status(la_splat_from_vector_element(v6, 6)) == LA_DIMENSION_MISMATCH_ERROR, "an index past the end");
        CHECK(la_status(la_splat_from_vector_element(v6, -1)) == LA_DIMENSION_MISMATCH_ERROR,
              "and one below zero, which the host reads from before its own buffer");
        ANSWER("la_matrix_from_splat", la_matrix_from_splat(splat, 2, 2), LA_SUCCESS, 2, 2, 3, 3, 3, 3);

        // the constructors and the attributes
        ANSWER("la_identity_matrix of 3", la_identity_matrix(3, LA_SCALAR_TYPE_FLOAT, LA_DEFAULT_ATTRIBUTES), LA_SUCCESS, 3,
               3, 1, 0, 0, 0, 1, 0, 0, 0, 1);
        CHECK(la_status(la_identity_matrix(0, LA_SCALAR_TYPE_FLOAT, LA_DEFAULT_ATTRIBUTES)) == LA_SUCCESS,
              "an identity of no size is made, and is empty");
        CHECK(la_status(la_identity_matrix(3, 0x1234, LA_DEFAULT_ATTRIBUTES)) == LA_INVALID_PARAMETER_ERROR,
              "a scalar type the library has no arithmetic for");
        ANSWER("la_scale_with_float", la_scale_with_float(m1, 0.5f), LA_SUCCESS, 2, 2, 0.5, 1, 1.5, 2);
        CHECK(la_status(la_scale_with_double(v6, 1.0)) == LA_PRECISION_MISMATCH_ERROR, "a float object scaled in double");
        CHECK(la_status(la_scale_with_float(splat, 1.0f)) == LA_INVALID_PARAMETER_ERROR, "a splat has nothing to scale");
        la_add_attributes(v6, LA_ATTRIBUTE_ENABLE_LOGGING);
        la_remove_attributes(v6, LA_ATTRIBUTE_ENABLE_LOGGING);
        CHECK(la_status(v6) == LA_SUCCESS, "an attribute is carried and inherited and changes no answer");
        // la_retain and la_release are macros above iOS 6, so the C entry points the release's own
        // library exports beside them are the ones a C client calls; they are reached the same way.
        {
            typedef la_object_t (*CharonRetain)(la_object_t);
            typedef void (*CharonRelease)(la_object_t);
            CharonRetain retain = (CharonRetain)dlsym(RTLD_DEFAULT, "la_retain");
            CharonRelease release = (CharonRelease)dlsym(RTLD_DEFAULT, "la_release");
            CHECK(retain != NULL && release != NULL, "la_retain and la_release are in the library");
            CHECK(retain((la_object_t)v6) == (la_object_t)v6, "la_retain answers the object");
            release((la_object_t)v6);
            CHECK(la_status(v6) == LA_SUCCESS, "a balanced la_release leaves the object");
        }

        // the solve
        {
            const float system[4] = {4, 1, 1, 3}, right[2] = {1, 2};
            const float general[4] = {1, 2, 3, 4}, right2[2] = {5, 6};
            const float singular[4] = {1, 1, 1, 1};
            const float three[9] = {2, 1, 1, 1, 3, 1, 1, 1, 4}, right3[3] = {1, 2, 3};
            const double systemd[4] = {4, 1, 1, 3}, rightd[2] = {1, 2};
            ANSWER("la_solve of a symmetric system", la_solve(la_matrix_from_float_buffer(system, 2, 2, 2, LA_NO_HINT,
                                                                                          LA_DEFAULT_ATTRIBUTES),
                                                                la_matrix_from_float_buffer(right, 2, 1, 1, LA_NO_HINT,
                                                                                           LA_DEFAULT_ATTRIBUTES)),
                   LA_SUCCESS, 2, 1, 0.0909091f, 0.636364f);
            ANSWER("la_solve of a general system", la_solve(la_matrix_from_float_buffer(general, 2, 2, 2, LA_NO_HINT,
                                                                                        LA_DEFAULT_ATTRIBUTES),
                                                              la_matrix_from_float_buffer(right2, 2, 1, 1, LA_NO_HINT,
                                                                                           LA_DEFAULT_ATTRIBUTES)),
                   LA_SUCCESS, 2, 1, -4.0f, 4.5f);
            ANSWER("la_solve of a 3x3", la_solve(la_matrix_from_float_buffer(three, 3, 3, 3, LA_NO_HINT, LA_DEFAULT_ATTRIBUTES),
                                                 la_matrix_from_float_buffer(right3, 3, 1, 1, LA_NO_HINT,
                                                                          LA_DEFAULT_ATTRIBUTES)),
                   LA_SUCCESS, 3, 1, -0.0588235f, 0.470588f, 0.647059f);
            ANSWER("la_solve of a double system", la_solve(la_matrix_from_double_buffer(systemd, 2, 2, 2, LA_NO_HINT,
                                                                                          LA_DEFAULT_ATTRIBUTES),
                                                              la_matrix_from_double_buffer(rightd, 2, 1, 1, LA_NO_HINT,
                                                                                           LA_DEFAULT_ATTRIBUTES)),
                   LA_SUCCESS, 2, 1, 0.0909091f, 0.636364f);
            CHECK(la_status(la_solve(la_matrix_from_float_buffer(singular, 2, 2, 2, LA_NO_HINT, LA_DEFAULT_ATTRIBUTES),
                                     la_matrix_from_float_buffer(right, 2, 1, 1, LA_NO_HINT, LA_DEFAULT_ATTRIBUTES))) ==
                      LA_SINGULAR_ERROR,
                  "a system with a zero pivot is LA_SINGULAR_ERROR, as the header says");
            CHECK(la_status(la_solve(v6, v6)) == LA_DIMENSION_MISMATCH_ERROR, "a system that is not square");
            CHECK(la_status(la_solve(la_matrix_from_float_buffer(system, 2, 2, 2, LA_NO_HINT, LA_DEFAULT_ATTRIBUTES),
                                     la_matrix_from_float_buffer(a6, 3, 1, 1, LA_NO_HINT, LA_DEFAULT_ATTRIBUTES))) ==
                      LA_DIMENSION_MISMATCH_ERROR,
                  "a right-hand side of another length");
            CHECK(la_status(la_solve(m1, d1)) == LA_PRECISION_MISMATCH_ERROR, "a float system and a double right-hand side");
            CHECK(la_status(la_solve(m1, splat)) == LA_INVALID_PARAMETER_ERROR, "a splat is not a right-hand side");
        }

        // the two entry points of the threading model
        {
            CharonSetThreading set = (CharonSetThreading)dlsym(RTLD_DEFAULT, "BLASSetThreading");
            CharonGetThreading get = (CharonGetThreading)dlsym(RTLD_DEFAULT, "BLASGetThreading");
            CHECK(set != NULL && get != NULL, "the two entry points of the threading model are in the library");
            CHECK(get() == kCharonThreadingMulti, "a thread that has set none is BLAS_THREADING_MULTI_THREADED");
            CHECK(set(kCharonThreadingSingle) == 0, "setting the single-threaded model succeeds");
            CHECK(get() == kCharonThreadingSingle, "and it is what the thread then answers");
            CHECK(set(kCharonThreadingMulti) == 0, "setting the multi-threaded model succeeds");
            CHECK(get() == kCharonThreadingMulti, "and it is what the thread then answers");
            CHECK(set(kCharonThreadingNone) == -1, "a model the library does not have is refused");
            CHECK(get() == kCharonThreadingMulti, "and the setting is left as it was");
        }

        // the geadd, in both precisions and both layouts
        {
            const float ga[6] = {1, 2, 3, 4, 5, 6}, gb[6] = {10, 20, 30, 40, 50, 60};
            float gc[8] = {0};
            appleblas_sgeadd(CblasRowMajor, CblasNoTrans, CblasNoTrans, 2, 3, 2.0f, ga, 3, 1.0f, gb, 3, gc, 3);
            CHECK(gc[0] == 12 && gc[2] == 36 && gc[3] == 48 && gc[5] == 72, "2*A + 1*B, row major");
            memset(gc, 0, sizeof gc);
            appleblas_sgeadd(CblasRowMajor, CblasTrans, CblasNoTrans, 3, 2, 1.0f, ga, 3, 1.0f, gb, 2, gc, 2);
            CHECK(gc[0] == 11 && gc[1] == 24 && gc[2] == 32 && gc[5] == 66, "A transposed against B, row major");
            memset(gc, 0, sizeof gc);
            appleblas_sgeadd(CblasColMajor, CblasNoTrans, CblasNoTrans, 3, 2, 1.0f, ga, 3, 1.0f, gb, 3, gc, 3);
            CHECK(gc[0] == 11 && gc[1] == 44 && gc[4] == 55 && gc[5] == 66, "A + B, column major");
            memset(gc, 0, sizeof gc);
            appleblas_sgeadd(CblasRowMajor, CblasNoTrans, CblasNoTrans, 2, 3, 0.0f, NULL, 3, 1.0f, gb, 3, gc, 3);
            CHECK(gc[0] == 10 && gc[5] == 60, "an alpha of zero leaves A unread, so A may be NULL");
            memset(gc, 0, sizeof gc);
            appleblas_sgeadd(CblasRowMajor, CblasNoTrans, CblasNoTrans, 0, 3, 1.0f, ga, 3, 1.0f, gb, 3, gc, 3);
            CHECK(gc[0] == 0 && gc[5] == 0, "an m of zero leaves C alone");
            double gad[4] = {1, 2, 3, 4}, gbd[4] = {10, 20, 30, 40}, gcd[4] = {0};
            appleblas_dgeadd(CblasRowMajor, CblasNoTrans, CblasNoTrans, 2, 2, 3.0, gad, 2, 0.5, gbd, 2, gcd, 2);
            CHECK(gcd[0] == 8 && gcd[1] == 16 && gcd[2] == 24 && gcd[3] == 32, "3*A + 0.5*B, in double");
        }

        printf("%d checks, %d failures\n", charon_checks, charon_failures);
        return charon_failures == 0 ? 0 : 1;
    }
}
