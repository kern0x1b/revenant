// Apple's cblas_sgemm takes fourteen arguments - the standard thirteen plus a K of its own - and
// this measures what it does with them, because the port builds its level-3 products on it.

#import <Accelerate/Accelerate.h>
#include <stdio.h>
#include <string.h>

static void show(const char *tag, const float *c, int count)
{
    printf("%s:", tag);
    for (int k = 0; k < count; k++) printf(" %g", c[k]);
    printf("\n");
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    // A is 2x3 row-major, B is 3x2 row-major, so the product is 2x2: [[11,14],[29,36]].
    float A[6] = {1, 0, 2, 0, 3, 4};
    float B[6] = {1, 2, 3, 4, 5, 6};
    float C[4] = {0, 0, 0, 0};
    cblas_sgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans, 2, 2, 3, 1.0f, A, 3, B, 3, 0.0f, C, 2);
    show("M=2 N=2 K=3 lda=3 ldb=3 ldc=2", C, 4);

    memset(C, 0, sizeof(C));
    cblas_sgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans, 2, 2, 2, 1.0f, A, 3, B, 3, 0.0f, C, 2);
    show("K=2", C, 4);

    memset(C, 0, sizeof(C));
    cblas_sgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans, 2, 3, 2, 1.0f, A, 3, B, 3, 0.0f, C, 2);
    show("N=3", C, 4);

    memset(C, 0, sizeof(C));
    cblas_sgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans, 3, 2, 2, 1.0f, A, 3, B, 3, 0.0f, C, 2);
    show("M=3", C, 4);

    memset(C, 0, sizeof(C));
    cblas_sgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans, 2, 2, 3, 1.0f, A, 2, B, 2, 0.0f, C, 2);
    show("lda=2 ldb=2", C, 4);

    // And a 2x2 by 2x2, whose product is unambiguous: [[7,10],[9,12]].
    float A2[4] = {1, 2, 0, 3};
    float B2[4] = {1, 2, 3, 4};
    memset(C, 0, sizeof(C));
    cblas_sgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans, 2, 2, 2, 1.0f, A2, 2, B2, 2, 0.0f, C, 2);
    show("2x2 by 2x2, expect 7 10 9 12", C, 4);

    // cblas_sgemv, cblas_sger and cblas_strsv, the three the port leans on.
    float x[3] = {1, 1, 1}, y[3] = {0, 0, 0};
    cblas_sgemv(CblasRowMajor, CblasNoTrans, 2, 3, 1.0f, A, 3, x, 1, 0.0f, y, 1);
    show("sgemv no-trans, expect 3 7 0", y, 3);
    memset(y, 0, sizeof(y));
    cblas_sgemv(CblasRowMajor, CblasTrans, 3, 2, 1.0f, A, 3, (float[]){1, 1}, 1, 0.0f, y, 1);
    show("sgemv trans, expect 1 3 6", y, 3);
    float Cg[4] = {0, 0, 0, 0};
    cblas_sger(CblasRowMajor, 2, 1, 1.0f, (float[]){1, 3}, 1, (float[]){1, 2}, 1, Cg, 2);
    show("sger, expect 1 2 3 6", Cg, 4);
    float Ct[4] = {0, 0, 0, 0};
    cblas_sger(CblasRowMajor, 2, 1, 1.0f, (float[]){1, 3}, 1, (float[]){1, 2}, 2, Ct, 2);
    show("sger with incy=2, expect 1 2 3 12", Ct, 4);
    float L[9] = {2, 0, 0, 1, 3, 0, 0, 0, 4};
    float b[3] = {2, 5, 4};
    cblas_strsv(CblasRowMajor, CblasLower, CblasNoTrans, CblasNonUnit, 3, L, 3, b, 1);
    show("strsv, expect 1 1.33333 1", b, 3);
    float bt[3] = {2, 5, 4};
    cblas_strsv(CblasRowMajor, CblasLower, CblasTrans, CblasNonUnit, 3, L, 3, bt, 1);
    show("strsv trans, expect 0.333333 1.33333 1", bt, 3);
    return 0;
}
