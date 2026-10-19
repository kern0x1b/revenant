// The port's AppleBLAS8.m held against the host's own Accelerate, case by case.
//
// C = alpha * op(A) + beta * op(B) in the caller's own layout. The port's two entry points are compiled
// with their names renamed, so this one can run both on the same inputs and compare every element of C.
//
// A bad parameter ends the process - that is what the release's own cblas_xerbla does, and what the
// host's own accelerated BLAS does too (measured: a child given lda = 1 with m = 2 prints a BLAS error
// and exits with status 255) - so each of those cases runs in a child and the two messages and the two
// statuses are compared there.

#import <Accelerate/Accelerate.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

void charon_host_appleblas_sgeadd(const enum CBLAS_ORDER order, const enum CBLAS_TRANSPOSE transA,
                                  const enum CBLAS_TRANSPOSE transB, int m, int n, float alpha, const float *A, int lda,
                                  float beta, const float *B, int ldb, float *C, int ldc);
void charon_host_appleblas_dgeadd(const enum CBLAS_ORDER order, const enum CBLAS_TRANSPOSE transA,
                                  const enum CBLAS_TRANSPOSE transB, int m, int n, double alpha, const double *A, int lda,
                                  double beta, const double *B, int ldb, double *C, int ldc);

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
    fflush(stdout);
}

static int close_enough(double x, double y)
{
    double difference = fabs(x - y);
    double scale = fabs(y) > 1.0 ? fabs(y) : 1.0;
    return difference <= 1e-6 * scale;
}

// One case, run through both. C starts as the same bytes on both sides, so a call that reads less than
// the other - an alpha of zero, an m of zero - shows up as a difference in what was left alone.
//
// When both sides are handed the *same* buffer - which fifteen of the eighteen call sites do, to keep the
// case in one - that is not an oracle at all: the array is compared with itself and any arithmetic that
// differs on the two sides cancels. So when the two buffers are one, each side gets a copy of it and the
// comparison is between two different arrays. Measured: with the two sharing one buffer, dropping the
// multiplication by beta in AppleBLAS8.m leaves the run at 22 checks and 0 failures; with a copy each, the
// same mutation fails.
static void same(const char *name, int is_double, int order, int trans_a, int trans_b, int m, int n, double alpha,
                 const void *a, int lda, double beta, const void *b, int ldb, const void *before, void *mine, void *theirs,
                 int ldc, int count)
{
    int copied = 0;
    if (mine == theirs) {
        size_t each = (size_t)count * (is_double ? sizeof(double) : sizeof(float));
        void *first = malloc(each);
        void *second = malloc(each);
        memcpy(first, theirs, each);
        memcpy(second, theirs, each);
        mine = first;
        theirs = second;
        copied = 1;
    }
    if (is_double) {
        charon_host_appleblas_dgeadd((enum CBLAS_ORDER)order, (enum CBLAS_TRANSPOSE)trans_a, (enum CBLAS_TRANSPOSE)trans_b,
                                     m, n, alpha, a, lda, beta, b, ldb, mine, ldc);
        appleblas_dgeadd((enum CBLAS_ORDER)order, (enum CBLAS_TRANSPOSE)trans_a, (enum CBLAS_TRANSPOSE)trans_b, m, n, alpha,
                         a, lda, beta, b, ldb, theirs, ldc);
    } else {
        charon_host_appleblas_sgeadd((enum CBLAS_ORDER)order, (enum CBLAS_TRANSPOSE)trans_a, (enum CBLAS_TRANSPOSE)trans_b,
                                     m, n, (float)alpha, a, lda, (float)beta, b, ldb, mine, ldc);
        appleblas_sgeadd((enum CBLAS_ORDER)order, (enum CBLAS_TRANSPOSE)trans_a, (enum CBLAS_TRANSPOSE)trans_b, m, n,
                         (float)alpha, a, lda, (float)beta, b, ldb, theirs, ldc);
    }
    for (int at = 0; at < count; at++) {
        double x = is_double ? ((double *)mine)[at] : ((float *)mine)[at];
        double y = is_double ? ((double *)theirs)[at] : ((float *)theirs)[at];
        if (!close_enough(x, y)) {
            snprintf(detail, sizeof detail, "element %d is %.9g, the host says %.9g (C started as %.9g)", at, x, y,
                     is_double ? ((double *)before)[at] : ((float *)before)[at]);
            report(0, name, detail);
            if (copied) {
                free((void *)mine);
                free((void *)theirs);
            }
            return;
        }
    }
    if (copied) {
        free((void *)mine);
        free((void *)theirs);
    }
    report(1, name, "");
}

// A case where the process must not survive: a child runs each side, and the two statuses and the two
// messages are what is compared. The two messages differ in wording - the release's public cblas_xerbla
// against the private handler inside Apple's own accelerated BLAS - so what is compared is that both
// ended the same way and that both named the routine.
static int run_child(void (*body)(void), char *message, size_t room)
{
    int pipe_fds[2];
    pid_t child;
    int status = 0;
    message[0] = 0;
    if (pipe(pipe_fds) != 0) {
        return -1;
    }
    child = fork();
    if (child == 0) {
        close(pipe_fds[0]);
        dup2(pipe_fds[1], STDERR_FILENO);
        dup2(pipe_fds[1], STDOUT_FILENO);
        close(pipe_fds[1]);
        body();
        _exit(0);
    }
    close(pipe_fds[1]);
    {
        size_t used = 0;
        ssize_t got;
        while (used + 1 < room && (got = read(pipe_fds[0], message + used, room - used - 1)) > 0) {
            used += (size_t)got;
        }
        message[used] = 0;
    }
    close(pipe_fds[0]);
    waitpid(child, &status, 0);
    return status;
}

static const float *bad_a;
static const float *bad_b;

static void port_bad_lda(void)
{
    float c[6] = {0, 0, 0, 0, 0, 0};
    charon_host_appleblas_sgeadd(CblasRowMajor, CblasNoTrans, CblasNoTrans, 2, 3, 1.0f, bad_a, 1, 1.0f, bad_b, 3, c, 3);
}

static void host_bad_lda(void)
{
    float c[6] = {0, 0, 0, 0, 0, 0};
    appleblas_sgeadd(CblasRowMajor, CblasNoTrans, CblasNoTrans, 2, 3, 1.0f, bad_a, 1, 1.0f, bad_b, 3, c, 3);
}

static void port_bad_trans(void)
{
    float c[6] = {0, 0, 0, 0, 0, 0};
    charon_host_appleblas_sgeadd(CblasRowMajor, (enum CBLAS_TRANSPOSE)999, CblasNoTrans, 2, 3, 1.0f, bad_a, 3, 1.0f,
                                 bad_b, 3, c, 3);
}

static void host_bad_trans(void)
{
    float c[6] = {0, 0, 0, 0, 0, 0};
    appleblas_sgeadd(CblasRowMajor, (enum CBLAS_TRANSPOSE)999, CblasNoTrans, 2, 3, 1.0f, bad_a, 3, 1.0f, bad_b, 3, c, 3);
}

static void port_bad_ldb(void)
{
    float c[6] = {0, 0, 0, 0, 0, 0};
    charon_host_appleblas_sgeadd(CblasColMajor, CblasNoTrans, CblasNoTrans, 3, 2, 1.0f, bad_a, 3, 1.0f, bad_b, 2, c, 3);
}

static void host_bad_ldb(void)
{
    float c[6] = {0, 0, 0, 0, 0, 0};
    appleblas_sgeadd(CblasColMajor, CblasNoTrans, CblasNoTrans, 3, 2, 1.0f, bad_a, 3, 1.0f, bad_b, 2, c, 3);
}

static void port_bad_ldc(void)
{
    float c[6] = {0, 0, 0, 0, 0, 0};
    charon_host_appleblas_sgeadd(CblasRowMajor, CblasNoTrans, CblasNoTrans, 2, 3, 1.0f, bad_a, 3, 1.0f, bad_b, 3, c, 2);
}

static void host_bad_ldc(void)
{
    float c[6] = {0, 0, 0, 0, 0, 0};
    appleblas_sgeadd(CblasRowMajor, CblasNoTrans, CblasNoTrans, 2, 3, 1.0f, bad_a, 3, 1.0f, bad_b, 3, c, 2);
}

static void both_end_the_process(const char *name, void (*port)(void), void (*theirs)(void))
{
    char mine[512], other[512];
    int my_status = run_child(port, mine, sizeof mine);
    int their_status = run_child(theirs, other, sizeof other);
    int both_exited = WIFEXITED(my_status) && WIFEXITED(their_status);
    int same_status = both_exited && WEXITSTATUS(my_status) == WEXITSTATUS(their_status);
    int mine_spoke = strstr(mine, "appleblas_sgeadd") != NULL;
    int theirs_spoke = strstr(other, "appleblas_sgeadd") != NULL;
    if (both_exited && same_status && mine_spoke && theirs_spoke) {
        report(1, name, "");
        printf("     both: exit %d, the port says \"%s\", the host says \"%s\"\n", WEXITSTATUS(my_status),
               strtok(mine, "\n"), strtok(other, "\n"));
        return;
    }
    snprintf(detail, sizeof detail, "the port exited %d saying \"%s\", the host exited %d saying \"%s\"", my_status,
             mine, their_status, other);
    report(0, name, detail);
}

int main(void)
{
    const float a[6] = {1, 2, 3, 4, 5, 6};
    const float b[6] = {10, 20, 30, 40, 50, 60};
    const double ad[4] = {1, 2, 3, 4};
    const double bd[4] = {10, 20, 30, 40};
    float start[6];
    double startd[4];
    bad_a = a;
    bad_b = b;

    // row major, no transpose, in place over B
    memcpy(start, b, sizeof start);
    same("row major 2x3, 2*A + 1*B, in place over B", 0, CblasRowMajor, CblasNoTrans, CblasNoTrans, 2, 3, 2.0, a, 3, 1.0, b,
         3, start, start, start, 3, 6);
    {
        float mine[6], theirs[6];
        memcpy(mine, b, sizeof mine);
        memcpy(theirs, b, sizeof theirs);
        same("row major 2x3, 2*A + 1*B, C separate from B", 0, CblasRowMajor, CblasNoTrans, CblasNoTrans, 2, 3, 2.0, a,
             3, 1.0, b, 3, b, mine, theirs, 3, 6);
    }
    // a padded row stride, and the padding left alone
    {
        float mine[8], theirs[8];
        memset(mine, 0, sizeof mine);
        memset(theirs, 0, sizeof theirs);
        same("row major 2x3 with a row stride of 4", 0, CblasRowMajor, CblasNoTrans, CblasNoTrans, 2, 3, 2.0, a, 3, 1.0, b, 3,
             mine, mine, theirs, 4, 8);
    }
    // transposed operands
    memcpy(start, b, sizeof start);
    same("row major 3x2 with A transposed", 0, CblasRowMajor, CblasTrans, CblasNoTrans, 3, 2, 1.0, a, 3, 1.0, b, 2, start,
         start, start, 2, 6);
    memcpy(start, b, sizeof start);
    same("row major 2x3 with B transposed", 0, CblasRowMajor, CblasNoTrans, CblasTrans, 2, 3, 1.0, a, 3, 1.0, b, 2, start,
         start, start, 3, 6);
    memcpy(start, b, sizeof start);
    same("row major 3x2 with both transposed", 0, CblasRowMajor, CblasTrans, CblasTrans, 3, 2, 1.0, a, 3, 1.0, b, 3,
         start, start, start, 3, 6);
    // column major, in its own layout
    memcpy(start, b, sizeof start);
    same("column major 3x2", 0, CblasColMajor, CblasNoTrans, CblasNoTrans, 3, 2, 1.0, a, 3, 1.0, b, 3, start, start,
         start, 3, 6);
    memcpy(start, b, sizeof start);
    same("column major 3x2 with A transposed", 0, CblasColMajor, CblasTrans, CblasNoTrans, 3, 2, 1.0, a, 2, 1.0, b, 3,
         start, start, start, 3, 6);
    // an operand that is not read at all
    memcpy(start, b, sizeof start);
    same("alpha zero with A NULL", 0, CblasRowMajor, CblasNoTrans, CblasNoTrans, 2, 3, 0.0, NULL, 3, 1.0, b, 3, start,
         start, start, 3, 6);
    memcpy(start, b, sizeof start);
    same("beta zero with B NULL", 0, CblasRowMajor, CblasNoTrans, CblasNoTrans, 2, 3, 1.0, a, 3, 0.0, NULL, 3, start,
         start, start, 3, 6);
    memcpy(start, b, sizeof start);
    same("alpha and beta zero with both NULL", 0, CblasRowMajor, CblasNoTrans, CblasNoTrans, 2, 3, 0.0, NULL, 3, 0.0,
         NULL, 3, start, start, start, 3, 6);
    // nothing to do
    memcpy(start, a, sizeof start);
    same("m of zero leaves C alone", 0, CblasRowMajor, CblasNoTrans, CblasNoTrans, 0, 3, 1.0, a, 3, 1.0, b, 3, start,
         start, start, 3, 6);
    memcpy(start, a, sizeof start);
    same("n of zero leaves C alone", 0, CblasRowMajor, CblasNoTrans, CblasNoTrans, 2, 0, 1.0, a, 3, 1.0, b, 3, start,
         start, start, 3, 6);
    // in place, which the header allows when the pointers and the leading dimensions all match
    memcpy(start, a, sizeof start);
    same("in place over A, square", 0, CblasRowMajor, CblasNoTrans, CblasNoTrans, 2, 2, 2.0, a, 2, 0.0, NULL, 2, start,
         start, start, 2, 4);
    {
        const float square[4] = {1, 2, 3, 4};
        float mine[4], theirs[4];
        memcpy(mine, square, sizeof mine);
        memcpy(theirs, square, sizeof theirs);
        same("in place over A and B at once, square", 0, CblasRowMajor, CblasNoTrans, CblasNoTrans, 2, 2, 1.0, square, 2,
             1.0, square, 2, square, mine, theirs, 2, 4);
    }
    // the double version
    memcpy(startd, bd, sizeof startd);
    same("double 2x2, 3*A + 0.5*B", 1, CblasRowMajor, CblasNoTrans, CblasNoTrans, 2, 2, 3.0, ad, 2, 0.5, bd, 2, startd,
         startd, startd, 2, 4);
    memcpy(startd, bd, sizeof startd);
    same("double column major 2x2", 1, CblasColMajor, CblasNoTrans, CblasNoTrans, 2, 2, 1.0, ad, 2, 1.0, bd, 2, startd,
         startd, startd, 2, 4);
    memcpy(startd, bd, sizeof startd);
    same("double 2x2 with A transposed", 1, CblasRowMajor, CblasTrans, CblasNoTrans, 2, 2, 1.0, ad, 2, 1.0, bd, 2, startd,
         startd, startd, 2, 4);

    // a bad parameter, in a child each
    both_end_the_process("a leading dimension too short ends the process", port_bad_lda, host_bad_lda);
    both_end_the_process("a transpose outside the four values ends the process", port_bad_trans, host_bad_trans);
    both_end_the_process("a column-major leading dimension too short ends the process", port_bad_ldb, host_bad_ldb);
    both_end_the_process("a leading dimension for C too short ends the process", port_bad_ldc, host_bad_ldc);

    printf("%d checks, %d failures\n", checks, failures);
    return failures == 0 ? 0 : 1;
}
