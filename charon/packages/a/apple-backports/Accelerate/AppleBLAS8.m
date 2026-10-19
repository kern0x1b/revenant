#import <Accelerate/Accelerate.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wunguarded-availability"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

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

static int CharonGeaddLeadingIsValid(int order, int transposed, int m, int n, int leading, int position, const char *name)
{
    int needed = order == CblasRowMajor ? (transposed ? m : n) : (transposed ? n : m);
    if (leading >= needed) {
        return 1;
    }
    CharonGeaddInvalid(position, name);
    return 0;
}

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
