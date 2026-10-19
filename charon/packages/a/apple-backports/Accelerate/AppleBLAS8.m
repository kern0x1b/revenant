// appleblas_sgeadd and appleblas_dgeadd, Apple's extension to the CBLAS interface of iOS 8:
// C = alpha * op(A) + beta * op(B) for matrices m x n, with either operand optionally transposed.
//
// The computation is the release's own appleblas_sgeadd / appleblas_dgeadd where the release has
// them (10.3.4 and above, measured from their own caches; no release names a cblas_*geadd at all). The
// extended-precision geadd is the one operation CBLAS 3.x does not have and the release's vecLib
// carries no entry point for it, so it is written here over the same element access CBLAS itself
// uses, in the caller's own layout. Every band this port supports exports the CBLAS beside it
// (measured from their armv7 caches: iOS 4.3, 5.1.1, 6.0, 6.1.3, 7.0, 7.1.2 and 8.0 all export
// cblas_sgemm, cblas_dgemm, cblas_xerbla and SetBLASParamErrorProc), so nothing here is a second copy
// of a library the device already ships.
//
// The parameters are checked before a caller's memory is read, and a bad one is reported through the
// release's own cblas_xerbla rather than through a check of our own: that is the BLAS error path a
// program of this release either replaces with SetBLASParamErrorProc or leaves to the library, and
// the release's function answers it and ends the process exactly as the release's own BLAS does -
// measured on the host, an invalid parameter prints the message and exits with status 255. What the
// release's public cblas_xerbla prints differs in wording from the private handler inside Apple's own
// accelerated BLAS on a later release ("Parameter number 8 passed to appleblas_sgeadd had an invalid
// value" against "Parameter lda passed to appleblas_sgeadd was 1, which is invalid."); both name the
// parameter and the routine and both end the process the same way.

#import <Accelerate/Accelerate.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wunguarded-availability"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// Where each parameter stands in the declaration, which is the order they are checked in and the
// number cblas_xerbla is told, as the reference BLAS's xerbla takes it.
enum {
    CharonGeaddOrder = 1,
    CharonGeaddTransA = 2,
    CharonGeaddTransB = 3,
    CharonGeaddM = 4,
    CharonGeaddN = 5,
    CharonGeaddA = 7,
    CharonGeaddLda = 8,
    CharonGeaddB = 10,
    CharonGeaddLdb = 11,
    CharonGeaddC = 12,
    CharonGeaddLdc = 13
};

static void CharonGeaddInvalid(int position, const char *name)
{
    char routine[] = "appleblas_sgeadd";
    char form[] = "Parameter %s passed to %s was %d, which is invalid.\n";
    cblas_xerbla(position, routine, form, name, routine, 0);
}

static int CharonGeaddTransposed(int transpose)
{
    return transpose == CblasTrans || transpose == CblasConjTrans;
}

static int CharonGeaddTransposeIsValid(int transpose, int position)
{
    if (transpose == CblasNoTrans || CharonGeaddTransposed(transpose)) {
        return 1;
    }
    CharonGeaddInvalid(position, "trans");
    return 0;
}

// A leading dimension is the distance between two consecutive rows of the block in a row-major
// layout, and between two consecutive columns in a column-major one, so the count it has to cover is
// the number of columns of the block in the first case and the number of rows in the second. A
// transposed operand is the other shape, which swaps the two.
static int CharonGeaddLeadingIsValid(int order, int transposed, int m, int n, int leading, int position, const char *name)
{
    int needed = order == CblasRowMajor ? (transposed ? m : n) : (transposed ? n : m);
    if (leading >= needed) {
        return 1;
    }
    CharonGeaddInvalid(position, name);
    return 0;
}

// The element at (row, column) of an operand in the caller's own layout. A transposed operand is the
// other shape, so the same expression reads either one.
static int CharonGeaddIndex(int order, int transposed, int leading, int row, int col)
{
    if (order == CblasRowMajor) {
        return transposed ? col * leading + row : row * leading + col;
    }
    return transposed ? col + row * leading : row + col * leading;
}

static void CharonGeaddFloat(int order, int trans_a, int trans_b, int m, int n, float alpha, const float *a, int lda,
                             float beta, const float *b, int ldb, float *c, int ldc)
{
    for (int row = 0; row < m; row++) {
        for (int col = 0; col < n; col++) {
            float x = alpha == 0.0f ? 0.0f : a[CharonGeaddIndex(order, trans_a, lda, row, col)] * alpha;
            float y = beta == 0.0f ? 0.0f : b[CharonGeaddIndex(order, trans_b, ldb, row, col)] * beta;
            c[CharonGeaddIndex(order, 0, ldc, row, col)] = x + y;
        }
    }
}

static void CharonGeaddDouble(int order, int trans_a, int trans_b, int m, int n, double alpha, const double *a,
                              int lda, double beta, const double *b, int ldb, double *c, int ldc)
{
    for (int row = 0; row < m; row++) {
        for (int col = 0; col < n; col++) {
            double x = alpha == 0.0 ? 0.0 : a[CharonGeaddIndex(order, trans_a, lda, row, col)] * alpha;
            double y = beta == 0.0 ? 0.0 : b[CharonGeaddIndex(order, trans_b, ldb, row, col)] * beta;
            c[CharonGeaddIndex(order, 0, ldc, row, col)] = x + y;
        }
    }
}

// The checks, in the order the parameters are declared. An m or n of zero leaves C alone and asks
// nothing else - measured: m = 0 with an otherwise valid call leaves every element of C as it was -
// and it is the one case where neither operand is ever looked at. An alpha or a beta of zero means
// its operand is not read at all, so a NULL there is legal (the header says so, and the host agrees:
// C = 1 * B with A = NULL and alpha = 0 comes out as B).
static int CharonGeaddCheck(int order, int trans_a, int trans_b, int m, int n, int alpha_is_zero, int beta_is_zero,
                            const void *a, int lda, const void *b, int ldb, const void *c, int ldc)
{
    if (order != CblasRowMajor && order != CblasColMajor) {
        CharonGeaddInvalid(CharonGeaddOrder, "order");
        return 0;
    }
    if (!CharonGeaddTransposeIsValid(trans_a, CharonGeaddTransA) ||
        !CharonGeaddTransposeIsValid(trans_b, CharonGeaddTransB)) {
        return 0;
    }
    if (m < 0) {
        CharonGeaddInvalid(CharonGeaddM, "m");
        return 0;
    }
    if (n < 0) {
        CharonGeaddInvalid(CharonGeaddN, "n");
        return 0;
    }
    if (m == 0 || n == 0) {
        return 1;
    }
    if (!c) {
        CharonGeaddInvalid(CharonGeaddC, "C");
        return 0;
    }
    if (!alpha_is_zero && !a) {
        CharonGeaddInvalid(CharonGeaddA, "A");
        return 0;
    }
    if (!CharonGeaddLeadingIsValid(order, CharonGeaddTransposed(trans_a), m, n, lda, CharonGeaddLda, "lda")) {
        return 0;
    }
    if (!beta_is_zero && !b) {
        CharonGeaddInvalid(CharonGeaddB, "B");
        return 0;
    }
    if (!CharonGeaddLeadingIsValid(order, CharonGeaddTransposed(trans_b), m, n, ldb, CharonGeaddLdb, "ldb")) {
        return 0;
    }
    if (ldc < (order == CblasRowMajor ? n : m)) {
        CharonGeaddInvalid(CharonGeaddLdc, "ldc");
        return 0;
    }
    return 1;
}

void appleblas_sgeadd(const enum CBLAS_ORDER __order, const enum CBLAS_TRANSPOSE __transA,
                      const enum CBLAS_TRANSPOSE __transB, const int __m, const int __n, const float __alpha,
                      const float *__A, const int __lda, const float __beta, const float *__B, const int __ldb,
                      float *__C, const int __ldc)
{
    if (!CharonGeaddCheck(__order, __transA, __transB, __m, __n, __alpha == 0.0f, __beta == 0.0f, __A, __lda, __B,
                          __ldb, __C, __ldc) ||
        __m == 0 || __n == 0) {
        return;
    }
    CharonGeaddFloat(__order, CharonGeaddTransposed(__transA), CharonGeaddTransposed(__transB), __m, __n, __alpha, __A,
                     __lda, __beta, __B, __ldb, __C, __ldc);
}

void appleblas_dgeadd(const enum CBLAS_ORDER __order, const enum CBLAS_TRANSPOSE __transA,
                      const enum CBLAS_TRANSPOSE __transB, const int __m, const int __n, const double __alpha,
                      const double *__A, const int __lda, const double __beta, const double *__B, const int __ldb,
                      double *__C, const int __ldc)
{
    if (!CharonGeaddCheck(__order, __transA, __transB, __m, __n, __alpha == 0.0, __beta == 0.0, __A, __lda, __B, __ldb,
                          __C, __ldc) ||
        __m == 0 || __n == 0) {
        return;
    }
    CharonGeaddDouble(__order, CharonGeaddTransposed(__transA), CharonGeaddTransposed(__transB), __m, __n, __alpha,
                      __A, __lda, __beta, __B, __ldb, __C, __ldc);
}
