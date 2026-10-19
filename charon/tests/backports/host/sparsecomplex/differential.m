// The port's complex sparse family held against the host's own Accelerate, from a table of cases.
//
// One loop. Every case is a row of the table below - an operation, the shape, the alpha, the
// transpose, the order, the leading dimensions, the strides, the norm, the expected status and a note -
// and the loop builds the matrix on both sides from that row, calls the operation on each and compares
// the status and then every element. The only place a case is read is the switch, which is the
// operation's own signature; there is no per-case code.
//
// The two sides are two separate libraries. The port's is dlopen'd with RTLD_LOCAL | RTLD_FIRST and
// reached through dlsym on that handle, so nothing of the port's can interpose the host's and the host's
// Accelerate is the one the process already has. The port's two halves are one dylib: the complex family,
// and the real half that owns the entry points the SDK declares with a void * matrix for, which a complex
// matrix answers on the same terms.
//
// Usage: sparsecomplex <path to libComplexPort.dylib>

#import <Accelerate/Accelerate.h>
#include <complex.h>
#include <dlfcn.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

#define MAX_DIM 6

typedef enum {
    OpGemv,        // y = alpha * op(A) * x + y
    OpTrsvVector,  // x = T^-1 (x / alpha)
    OpTrsvMatrix,  // B = T^-1 (B / alpha), nrhs right-hand sides
    OpGemm,        // C = alpha * op(A) * B + C, B dense
    OpOuter,       // C = alpha * x * y' as a new matrix
    OpTrace,       // the sum along one diagonal
    OpElementwise, // sparse_elementwise_norm_*
    OpOperator,    // sparse_operator_norm_*
    OpCount
} Op;

static const char *op_names[OpCount] = {"a matrix-vector product", "a triangular solve of a vector",
                                        "a triangular solve of a matrix", "a dense product", "an outer product",
                                        "a trace", "an elementwise norm", "an operator norm"};

// The entries every matrix is built from, as three dense 3x3 blocks in (re, im) pairs. The products and
// the trace use the first, the solves the second, so a case can name one by asking for its operation.
static const double dense_entries[3 * 3 * 2] = {
    1, 0,  0, 0,  2, 0,   // row 0
    0, 0,  3, 1,  0, 0,   // row 1
    4, -1, 0, 0,  0, 0,   // row 2
};
static const double lower_entries[3 * 3 * 2] = {
    2, 1,  0, 0,  0, 0,
    1, 0,  3, 0,  0, 0,
    0, 0,  0, 0,  4, 0,
};

typedef struct {
    Op op;
    int M, N;    // the matrix's shape
    int triangular;   // 1: the lower triangular block, 0: the dense one
    double alphaRe, alphaIm;
    int trans, order, ldb, ldc, incx, incy, nrhs;
    sparse_norm norm;
    int expectStatus;   // SPARSE_SUCCESS unless the case is a refusal
    const char *note;
} Case;

// Every complex case, as data.
static const Case cases[] = {
    // y = alpha * op(A) * x + y over the 2x3 [[1, 0, 2], [0, 3 + i, 0]]
    {OpGemv, 2, 3, 0, 1, 0, 111, 101, 3, 2, 1, 1, 0, 0, SPARSE_SUCCESS, "alpha 1"},
    {OpGemv, 2, 3, 0, 2, 0, 111, 101, 3, 2, 1, 1, 0, 0, SPARSE_SUCCESS, "alpha 2"},
    {OpGemv, 2, 3, 0, 0, 0, 111, 101, 3, 2, 1, 1, 0, 0, SPARSE_SUCCESS, "alpha 0 leaves y"},
    {OpGemv, 2, 3, 0, 1, 0, 111, 101, 3, 2, 2, 2, 0, 0, SPARSE_SUCCESS, "x and y with a stride of 2"},
    {OpGemv, 2, 3, 0, 1, 0, 112, 101, 3, 2, 1, 1, 0, 0, SPARSE_SUCCESS, "CblasTrans"},
    {OpGemv, 2, 3, 0, 2, 0, 112, 101, 3, 2, 1, 1, 0, 0, SPARSE_SUCCESS, "CblasTrans, alpha 2"},
    {OpGemv, 2, 3, 0, 1, 1, 111, 101, 3, 2, 1, 1, 0, 0, SPARSE_SUCCESS, "a complex alpha"},
    {OpGemv, 2, 3, 0, 1, 0, 9, 101, 3, 2, 1, 1, 0, 0, SPARSE_ILLEGAL_PARAMETER,
     "a transpose outside the enumeration"},
    // the triangular solves over [[2 + i, 0, 0], [1, 3, 0], [0, 0, 4]]
    {OpTrsvVector, 3, 3, 1, 1, 0, 111, 101, 1, 1, 1, 1, 0, 0, SPARSE_SUCCESS, "lower, alpha 1"},
    {OpTrsvVector, 3, 3, 1, 2, 0, 111, 101, 1, 1, 1, 1, 0, 0, SPARSE_SUCCESS, "lower, alpha 2"},
    {OpTrsvVector, 3, 3, 1, 0.5, 0, 111, 101, 1, 1, 1, 1, 0, 0, SPARSE_SUCCESS, "lower, alpha 0.5"},
    {OpTrsvVector, 3, 3, 1, 1, 0, 112, 101, 1, 1, 1, 1, 0, 0, SPARSE_SUCCESS, "lower transposed"},
    {OpTrsvVector, 3, 3, 1, 1, 1, 111, 101, 1, 1, 1, 1, 0, 0, SPARSE_SUCCESS, "a complex alpha"},
    {OpTrsvVector, 3, 3, 1, 1, 0, 9, 101, 1, 1, 1, 1, 0, 0, SPARSE_ILLEGAL_PARAMETER,
     "a transpose outside the enumeration"},
    {OpTrsvMatrix, 3, 3, 1, 1.5, 0, 111, 101, 3, 3, 1, 1, 2, 0, SPARSE_SUCCESS, "lower, row-major, ldb 3"},
    {OpTrsvMatrix, 3, 3, 1, 1.5, 0, 111, 102, 3, 3, 1, 1, 2, 0, SPARSE_SUCCESS, "lower, column-major, ldb 3"},
    {OpTrsvMatrix, 3, 3, 1, 1.5, 0, 112, 101, 3, 3, 1, 1, 2, 0, SPARSE_SUCCESS, "lower transposed, row-major"},
    {OpTrsvMatrix, 3, 3, 1, 1.5, 0, 111, 101, 5, 3, 1, 1, 2, 0, SPARSE_SUCCESS, "ldb 5"},
    {OpTrsvMatrix, 3, 3, 1, 1.5, 0, 111, 101, 1, 3, 1, 1, 2, 0, SPARSE_ILLEGAL_PARAMETER,
     "a leading dimension of one"},
    // C = alpha * op(A) * B + C, B a dense 3x3 read with a leading dimension of 3
    {OpGemm, 2, 3, 0, 1, 0, 111, 101, 3, 3, 1, 1, 0, 0, SPARSE_SUCCESS, "row-major"},
    {OpGemm, 2, 3, 0, 2, 0, 111, 101, 3, 3, 1, 1, 0, 0, SPARSE_SUCCESS, "row-major, alpha 2"},
    {OpGemm, 2, 3, 0, 1, 0, 111, 102, 3, 2, 1, 1, 0, 0, SPARSE_SUCCESS, "column-major"},
    {OpGemm, 2, 3, 0, 2, 0, 111, 102, 3, 2, 1, 1, 0, 0, SPARSE_SUCCESS, "column-major, alpha 2"},
    {OpGemm, 2, 3, 0, 1, 0, 111, 101, 1, 2, 1, 1, 0, 0, SPARSE_ILLEGAL_PARAMETER,
     "a leading dimension of one"},
    // the outer product
    {OpOuter, 2, 3, 0, 2, 1, 111, 101, 1, 1, 1, 1, 0, 0, SPARSE_SUCCESS, "two nonzeros of y"},
    {OpOuter, 2, 3, 0, 1, 0, 111, 101, 1, 1, 1, 1, 0, 0, SPARSE_SUCCESS, "alpha 1"},
    {OpOuter, 2, 3, 0, 0, 0, 111, 101, 1, 1, 1, 1, 0, 0, SPARSE_SUCCESS, "alpha 0"},
    // the trace, over the offsets that name elements and those that do not
    {OpTrace, 2, 3, 0, 0, 0, 111, 101, 1, 1, 1, 1, 0, 0, SPARSE_SUCCESS, "the main diagonal"},
    {OpTrace, 2, 3, 0, 0, 0, 111, 101, 1, 1, 1, 1, 1, 0, SPARSE_SUCCESS, "one above the main diagonal"},
    {OpTrace, 2, 3, 0, 0, 0, 111, 101, 1, 1, 1, 1, -1, 0, SPARSE_SUCCESS, "one below the main diagonal"},
    {OpTrace, 2, 3, 0, 0, 0, 111, 101, 1, 1, 1, 1, 3, 0, SPARSE_SUCCESS, "past the last column"},
    // the four norms and an unenumerated name, each of the two kinds
    {OpElementwise, 2, 3, 0, 0, 0, 111, 101, 1, 1, 1, 1, 0, SPARSE_NORM_ONE, SPARSE_SUCCESS, "SPARSE_NORM_ONE"},
    {OpElementwise, 2, 3, 0, 0, 0, 111, 101, 1, 1, 1, 1, 0, SPARSE_NORM_TWO, SPARSE_SUCCESS, "SPARSE_NORM_TWO"},
    {OpElementwise, 2, 3, 0, 0, 0, 111, 101, 1, 1, 1, 1, 0, SPARSE_NORM_INF, SPARSE_SUCCESS, "SPARSE_NORM_INF"},
    {OpElementwise, 2, 3, 0, 0, 0, 111, 101, 1, 1, 1, 1, 0, SPARSE_NORM_R1, SPARSE_SUCCESS, "SPARSE_NORM_R1"},
    {OpElementwise, 2, 3, 0, 0, 0, 111, 101, 1, 1, 1, 1, 0, (sparse_norm)999, SPARSE_SUCCESS,
     "a name outside the enumeration"},
    {OpOperator, 2, 3, 0, 0, 0, 111, 101, 1, 1, 1, 1, 0, SPARSE_NORM_ONE, SPARSE_SUCCESS, "SPARSE_NORM_ONE"},
    {OpOperator, 2, 3, 0, 0, 0, 111, 101, 1, 1, 1, 1, 0, SPARSE_NORM_TWO, SPARSE_SUCCESS, "SPARSE_NORM_TWO"},
    {OpOperator, 2, 3, 0, 0, 0, 111, 101, 1, 1, 1, 1, 0, SPARSE_NORM_INF, SPARSE_SUCCESS, "SPARSE_NORM_INF"},
    {OpOperator, 2, 3, 0, 0, 0, 111, 101, 1, 1, 1, 1, 0, SPARSE_NORM_R1, SPARSE_SUCCESS, "SPARSE_NORM_R1"},
    {OpOperator, 2, 3, 0, 0, 0, 111, 101, 1, 1, 1, 1, 0, (sparse_norm)999, SPARSE_SUCCESS,
     "a name outside the enumeration"},
};

static void *port;
static int checks;
static int failures;

// Which sides this run calls: 0 both, 1 the port alone, 2 the host alone. A refused case runs the port
// here and the host in a child, because the host does not always refuse what the port refuses (measured:
// an unnamed transpose goes into cblas_cgemv, which ends the process), and one switch with one set of cases
// has to serve both or it is a second copy of the loop.
static int side;

#define PORT(statement)                                                                                         \
    do {                                                                                                        \
        if (side != 2) {                                                                                        \
            statement;                                                                                          \
        }                                                                                                       \
    } while (0)

#define HOST(statement)                                                                                         \
    do {                                                                                                        \
        if (side != 1) {                                                                                        \
            statement;                                                                                          \
        }                                                                                                       \
    } while (0)

static void report(const char *name, const char *note, int passed, const char *detail)
{
    checks++;
    if (passed) {
        printf("ok %s: %s\n", name, note);
    } else {
        failures++;
        printf("FAIL %s: %s: %s\n", name, note, detail);
    }
}

static int same(double complex mine, double complex theirs, double tolerance)
{
    if (isnan(creal(mine)) && isnan(creal(theirs)) && isnan(cimag(mine)) && isnan(cimag(theirs))) return 1;
    if (isinf(creal(mine)) || isinf(creal(theirs))) {
        return creal(mine) == creal(theirs) && cimag(mine) == cimag(theirs);
    }
    double a = fabs(creal(mine) - creal(theirs));
    double b = fabs(cimag(mine) - cimag(theirs));
    double scale = fabs(creal(theirs)) > 1.0 ? fabs(creal(theirs)) : 1.0;
    return a <= tolerance * scale && b <= tolerance * scale;
}

// The one place a case is compared: the two statuses, then every element, both halves. The detail is
// built in a buffer of its own and its SIZE travels with it. The first version took a char * and wrote
// with sizeof on it, which is the size of the pointer and not of the buffer, so every mismatch was cut
// to seven characters and the offset snprintf returned pointed past the end.
static void compareComplex(const Case *c, sparse_status mine, sparse_status theirs, const float complex *a,
                           const float complex *b, int count, double tolerance)
{
    char text[512];
    size_t used = 0;
    int ok = mine == c->expectStatus && (side != 0 || theirs == c->expectStatus);
    for (int k = 0; k < count && ok; k++) {
        if (!same(a[k], b[k], tolerance)) {
            used = (size_t)snprintf(text + used, sizeof text - used, "element %d: port %g%+gi, host %g%+gi; ", k,
                                    crealf(a[k]), cimagf(a[k]), crealf(b[k]), cimagf(b[k]));
            ok = 0;
        }
    }
    snprintf(text + used, sizeof text - used, "status %d against %d, wanted %d", mine, theirs, c->expectStatus);
    report(op_names[c->op], c->note, ok, text);
}

// The entry points, resolved once at load, so the loop reads a case and calls through a pointer.
typedef sparse_status (*Gemv)(enum CBLAS_TRANSPOSE, float complex, void *, const float complex *, sparse_stride,
                              float complex *, sparse_stride);
typedef sparse_status (*TrsvVector)(enum CBLAS_TRANSPOSE, float complex, void *, float complex *, sparse_stride);
typedef sparse_status (*TrsvMatrix)(enum CBLAS_ORDER, enum CBLAS_TRANSPOSE, sparse_dimension, float complex, void *,
                                    float complex *, sparse_dimension);
typedef sparse_status (*Gemm)(enum CBLAS_ORDER, enum CBLAS_TRANSPOSE, sparse_dimension, float complex, void *,
                              const float complex *, sparse_dimension, float complex *, sparse_dimension);
typedef sparse_status (*Outer)(sparse_dimension, sparse_dimension, sparse_dimension, float complex,
                               const float complex *, sparse_stride, const float complex *, const sparse_index *,
                               sparse_matrix_float_complex *);
typedef float complex (*Trace)(sparse_matrix_float_complex, sparse_index);
typedef double (*Norm)(sparse_matrix_float_complex, sparse_norm);
typedef void *(*Create)(sparse_dimension, sparse_dimension);
typedef sparse_status (*Insert)(sparse_matrix_float_complex, float complex, sparse_index, sparse_index);
typedef sparse_status (*ExtractRow)(sparse_matrix_float_complex, sparse_index, sparse_index, sparse_index *,
                                  sparse_dimension, float complex *, sparse_index *);
typedef sparse_status (*SetProperty)(void *, sparse_matrix_property);
typedef sparse_status (*Destroy)(void *);
typedef long (*Nonzero)(void *);

static Create portCreate, hostCreate;
static Insert portInsert, hostInsert;
static SetProperty portSet, hostSet;
static Destroy portDestroy, hostDestroy;
static Nonzero portNonzero, hostNonzero;
static ExtractRow portExtractRow, hostExtractRow;
static Gemv portGemv, hostGemv;
static TrsvVector portTrsvVector, hostTrsvVector;
static TrsvMatrix portTrsvMatrix, hostTrsvMatrix;
static Gemm portGemm, hostGemm;
static Outer portOuter, hostOuter;
static Trace portTrace, hostTrace;
static Norm portElementwise, hostElementwise, portOperator, hostOperator;

static void *sym(const char *name)
{
    void *found = dlsym(port, name);
    if (!found) {
        fprintf(stderr, "the port's dylib has no %s: %s\n", name, dlerror());
        exit(2);
    }
    return found;
}

// One case. The switch is the operation's own signature and the only place a case is read.
static void runOne(const Case *c)
{
    const double *block = c->triangular ? lower_entries : dense_entries;
    int M = c->triangular ? 3 : c->M, N = c->triangular ? 3 : c->N;
    float complex alpha = (float)(c->alphaRe + c->alphaIm * I);
    char detail[512];

    void *portA = NULL;
    sparse_matrix_float_complex hostA = NULL;
    PORT(portA = portCreate(M, N));
    HOST(hostA = hostCreate(M, N));
    if (c->triangular) {
        PORT(portSet(portA, SPARSE_LOWER_TRIANGULAR));
        HOST(hostSet(hostA, SPARSE_LOWER_TRIANGULAR));
    }
    for (int k = 0; k < 9; k++) {
        float complex v = (float)(block[2 * k] + block[2 * k + 1] * I);
        if (creal(v) == 0.0f && cimag(v) == 0.0f) continue;
        int row = k / 3, column = k % 3;
        if (row >= M || column >= N) continue;
        PORT(portInsert(portA, v, row, column));
        HOST(hostInsert(hostA, v, row, column));
    }

    switch (c->op) {
        case OpGemv: {
            float complex x[MAX_DIM * 2], y1[MAX_DIM * 2], y2[MAX_DIM * 2];
            for (int k = 0; k < MAX_DIM * 2; k++) {
                x[k] = (float)(k + 1);
                y1[k] = y2[k] = (float)(k % 5);
            }
            sparse_status ma = SPARSE_SUCCESS, mb = SPARSE_SUCCESS;
            PORT(ma = portGemv((enum CBLAS_TRANSPOSE)c->trans, alpha, portA, x, c->incx, y1, c->incy));
            HOST(mb = hostGemv((enum CBLAS_TRANSPOSE)c->trans, alpha, hostA, x, c->incx, y2, c->incy));
            compareComplex(c, ma, mb, y1, y2, MAX_DIM * 2, 1e-5);
            break;
        }
        case OpTrsvVector: {
            float complex b1[MAX_DIM] = {2, 5 * I, 4, 0, 0, 0};
            float complex b2[MAX_DIM] = {2, 5 * I, 4, 0, 0, 0};
            sparse_status ma = SPARSE_SUCCESS, mb = SPARSE_SUCCESS;
            PORT(ma = portTrsvVector((enum CBLAS_TRANSPOSE)c->trans, alpha, portA, b1, 1));
            HOST(mb = hostTrsvVector((enum CBLAS_TRANSPOSE)c->trans, alpha, hostA, b2, 1));
            compareComplex(c, ma, mb, b1, b2, MAX_DIM, 1e-4);
            break;
        }
        case OpTrsvMatrix: {
            float complex B1[MAX_DIM * 3] = {2, 5 * I, 4, 3, 7, 6};
            float complex B2[MAX_DIM * 3] = {2, 5 * I, 4, 3, 7, 6};
            sparse_status ma = SPARSE_SUCCESS, mb = SPARSE_SUCCESS;
            PORT(ma = portTrsvMatrix((enum CBLAS_ORDER)c->order, (enum CBLAS_TRANSPOSE)c->trans, c->nrhs, alpha, portA,
                                    B1, c->ldb));
            HOST(mb = hostTrsvMatrix((enum CBLAS_ORDER)c->order, (enum CBLAS_TRANSPOSE)c->trans, c->nrhs, alpha, hostA,
                                    B2, c->ldb));
            compareComplex(c, ma, mb, B1, B2, MAX_DIM * 3, 1e-4);
            break;
        }
        case OpGemm: {
            float complex B[MAX_DIM * 3] = {1, 2, 9, 9, 3, 4, 9, 9, 5, 6, 9, 9};
            float complex C1[MAX_DIM * 3], C2[MAX_DIM * 3];
            for (int k = 0; k < MAX_DIM * 3; k++) C1[k] = C2[k] = (float)(k % 7);
            sparse_status ma = SPARSE_SUCCESS, mb = SPARSE_SUCCESS;
            PORT(ma = portGemm((enum CBLAS_ORDER)c->order, (enum CBLAS_TRANSPOSE)c->trans, c->N, alpha, portA, B, c->ldb, C1,
                               c->ldc));
            HOST(mb = hostGemm((enum CBLAS_ORDER)c->order, (enum CBLAS_TRANSPOSE)c->trans, c->N, alpha, hostA, B, c->ldb, C2,
                               c->ldc));
            compareComplex(c, ma, mb, C1, C2, MAX_DIM * 3, 1e-5);
            break;
        }
        case OpOuter: {
            float complex x[2] = {1, 1};
            float complex y[2] = {3, 4};
            sparse_index indy[2] = {0, 2};
            sparse_matrix_float_complex portC = NULL, hostC = NULL;
            sparse_status ma = SPARSE_SUCCESS, mb = SPARSE_SUCCESS;
            PORT(ma = portOuter(c->M, c->N, 2, alpha, x, 1, y, indy, &portC));
            HOST(mb = hostOuter(c->M, c->N, 2, alpha, x, 1, y, indy, &hostC));
            int ok = ma == c->expectStatus && (side != 0 || mb == c->expectStatus);
            long portCount = portC ? portNonzero(portC) : -1;
            long hostCount = hostC ? hostNonzero(hostC) : -1;
            if (ok && side == 0 && (portCount <= 0 || hostCount <= 0)) {
                // An empty matrix is compared by its count: an elementwise read of the host's empty
                // product is what takes the process down, and the count is what says the matrix is empty.
                ok = portCount == hostCount;
                snprintf(detail, sizeof detail, "an empty matrix: %ld entries on the port, %ld on the host", portCount,
                         hostCount);
            } else if (ok && side == 0 && portC && hostC) {
                for (int k = 0; k < c->M * c->N && ok; k++) {
                    float complex mine = 0, theirs = 0;
                    sparse_index end = 0, j = 0;
                    portExtractRow(portC, k / c->N, k % c->N, &end, 1, &mine, &j);
                    hostExtractRow(hostC, k / c->N, k % c->N, &end, 1, &theirs, &j);
                    ok = same(mine, theirs, 1e-5);
                }
                snprintf(detail, sizeof detail, "status %d against %d, wanted %d", ma, mb, c->expectStatus);
            } else {
                snprintf(detail, sizeof detail, "status %d against %d, wanted %d", ma, mb, c->expectStatus);
            }
            report(op_names[c->op], c->note, ok, detail);
            if (portC) portDestroy(portC);
            if (hostC) hostDestroy(hostC);
            break;
        }
        case OpTrace: {
            float complex mine = 0, theirs = 0;
            PORT(mine = portTrace(portA, c->nrhs));
            HOST(theirs = hostTrace(hostA, c->nrhs));
            int ok = side != 0 || same(mine, theirs, 1e-5);
            snprintf(detail, sizeof detail, "port %g%+gi, host %g%+gi", crealf(mine), cimagf(mine), crealf(theirs),
                     cimagf(theirs));
            report(op_names[c->op], c->note, ok, detail);
            break;
        }
        case OpElementwise:
        case OpOperator: {
            double mine = 0, theirs = 0;
            PORT(mine = c->op == OpElementwise ? portElementwise(portA, c->norm) : portOperator(portA, c->norm));
            HOST(theirs = c->op == OpElementwise ? hostElementwise(hostA, c->norm) : hostOperator(hostA, c->norm));
            // The operator-two norm is the largest singular value and the host reaches it by an
            // iteration, so it gets the stated tolerance and everything else gets none.
            double tolerance = (c->op == OpOperator && c->norm == SPARSE_NORM_TWO) ? 5e-3 : 1e-6;
            int ok = side != 0 || same(mine + 0.0 * I, theirs + 0.0 * I, tolerance);
            snprintf(detail, sizeof detail, "port %g, host %g", mine, theirs);
            report(op_names[c->op], c->note, ok, detail);
            break;
        }
        default:
            break;
    }
    if (portA) portDestroy(portA);
    if (hostA) hostDestroy(hostA);
}

// A refused case is asked of the host in a child, because the host does not always refuse what the port
// refuses: measured, an unnamed transpose goes into cblas_cgemv, which ends the process.
static void hostInAChild(const Case *c)
{
    fflush(stdout);
    pid_t child = fork();
    if (child == 0) {
        freopen("/dev/null", "w", stdout);
        freopen("/dev/null", "w", stderr);
        side = 2;
        runOne(c);
        _exit(0);
    }
    int status = 0;
    waitpid(child, &status, 0);
    printf("# %s: the host was asked the same refused call in a child (%s)\n", c->note,
           WIFSIGNALED(status) ? "was killed" : (WIFEXITED(status) && WEXITSTATUS(status) ? "exited nonzero" : "survived"));
    fflush(stdout);
}

static void run(const Case *c)
{
    if (c->expectStatus == SPARSE_SUCCESS) {
        side = 0;
        runOne(c);
        return;
    }
    side = 1;   // the port alone here; the host alone in the child, which may not come back
    runOne(c);
    hostInAChild(c);
}

int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    if (argc < 2) {
        fprintf(stderr, "usage: %s <libComplexPort.dylib>\n", argv[0]);
        return 2;
    }
    port = dlopen(argv[1], RTLD_LOCAL | RTLD_FIRST);
    if (!port) {
        fprintf(stderr, "dlopen: %s\n", dlerror());
        return 2;
    }
    portCreate = (Create)sym("sparse_matrix_create_float_complex");
    hostCreate = (Create)sparse_matrix_create_float_complex;
    portInsert = (Insert)sym("sparse_insert_entry_float_complex");
    hostInsert = sparse_insert_entry_float_complex;
    portSet = (SetProperty)sym("sparse_set_matrix_property");
    hostSet = (SetProperty)sparse_set_matrix_property;
    portDestroy = (Destroy)sym("sparse_matrix_destroy");
    hostDestroy = (Destroy)sparse_matrix_destroy;
    portNonzero = (Nonzero)sym("sparse_get_matrix_nonzero_count");
    hostNonzero = sparse_get_matrix_nonzero_count;
    portExtractRow = (ExtractRow)sym("sparse_extract_sparse_row_float_complex");
    hostExtractRow = sparse_extract_sparse_row_float_complex;
    portGemv = (Gemv)sym("sparse_matrix_vector_product_dense_float_complex");
    hostGemv = (Gemv)sparse_matrix_vector_product_dense_float_complex;
    portTrsvVector = (TrsvVector)sym("sparse_vector_triangular_solve_dense_float_complex");
    hostTrsvVector = (TrsvVector)sparse_vector_triangular_solve_dense_float_complex;
    portTrsvMatrix = (TrsvMatrix)sym("sparse_matrix_triangular_solve_dense_float_complex");
    hostTrsvMatrix = (TrsvMatrix)sparse_matrix_triangular_solve_dense_float_complex;
    portGemm = (Gemm)sym("sparse_matrix_product_dense_float_complex");
    hostGemm = (Gemm)sparse_matrix_product_dense_float_complex;
    portOuter = (Outer)sym("sparse_outer_product_dense_float_complex");
    hostOuter = (Outer)sparse_outer_product_dense_float_complex;
    portTrace = (Trace)sym("sparse_matrix_trace_float_complex");
    hostTrace = (Trace)sparse_matrix_trace_float_complex;
    portElementwise = (Norm)sym("sparse_elementwise_norm_float_complex");
    hostElementwise = (Norm)sparse_elementwise_norm_float_complex;
    portOperator = (Norm)sym("sparse_operator_norm_float_complex");
    hostOperator = (Norm)sparse_operator_norm_float_complex;

    for (size_t k = 0; k < sizeof(cases) / sizeof(cases[0]); k++) {
        run(&cases[k]);
    }
    printf("%d checks, %d failures\n", checks, failures);
    return failures ? 1 : 0;
}
