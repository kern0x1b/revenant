#include <simd/simd.h>

/* The inverse of a square matrix of 2, 3 or 4 columns, by the adjugate over the determinant: what libsystem_m's
   __invert_f2 .. __invert_d4 answer from iOS 8, which no earlier release exports and which simd's inline simd_inverse
   calls. The cofactor form is what the system's own answers show for a matrix with no inverse: measured on macOS 26,
   the inverse of a singular 2x2 {{1,2},{2,4}} is {inf -inf -inf inf} and that of a 3x3 with two equal columns has inf
   and nan in the places a division of the adjugate by a zero determinant gives them, where an elimination with pivoting
   would have stopped at the first zero. The scalar is computed in its own precision, the way the system's functions
   take it, so a float matrix is not widened.

   Elements are read as m[row][column] from the columns the type holds. */
#define CHARON_INVERSE(SCALAR, TAG)                                                                                  \
    static SCALAR charon_determinant_##TAG(const SCALAR m[4][4], int n)                                              \
    {                                                                                                                \
        if (n == 1) {                                                                                                \
            return m[0][0];                                                                                          \
        }                                                                                                            \
        SCALAR sum = 0;                                                                                              \
        for (int column = 0; column < n; column++) {                                                                 \
            SCALAR minor[4][4];                                                                                      \
            for (int row = 1; row < n; row++) {                                                                      \
                for (int other = 0, taken = 0; other < n; other++) {                                                 \
                    if (other != column) {                                                                           \
                        minor[row - 1][taken++] = m[row][other];                                                     \
                    }                                                                                                \
                }                                                                                                    \
            }                                                                                                        \
            SCALAR term = m[0][column] * charon_determinant_##TAG(minor, n - 1);                                     \
            sum += column % 2 ? -term : term;                                                                        \
        }                                                                                                            \
        return sum;                                                                                                  \
    }                                                                                                                \
                                                                                                                     \
    /* the inverse of the n x n matrix in m, written to out as out[row][column] */                                   \
    static void charon_inverse_##TAG(const SCALAR m[4][4], int n, SCALAR out[4][4])                                  \
    {                                                                                                                \
        SCALAR determinant = charon_determinant_##TAG(m, n);                                                         \
        for (int row = 0; row < n; row++) {                                                                          \
            for (int column = 0; column < n; column++) {                                                             \
                /* the cofactor of (column, row) is the adjugate's element (row, column) */                          \
                SCALAR minor[4][4];                                                                                  \
                for (int i = 0, taken = 0; i < n; i++) {                                                             \
                    if (i == column) {                                                                               \
                        continue;                                                                                    \
                    }                                                                                                \
                    for (int j = 0, used = 0; j < n; j++) {                                                          \
                        if (j != row) {                                                                              \
                            minor[taken][used++] = m[i][j];                                                          \
                        }                                                                                            \
                    }                                                                                                \
                    taken++;                                                                                         \
                }                                                                                                    \
                SCALAR cofactor = charon_determinant_##TAG(minor, n - 1);                                           \
                out[row][column] = ((row + column) % 2 ? -cofactor : cofactor) / determinant;                        \
            }                                                                                                        \
        }                                                                                                            \
    }

/* One function: `MATRIX name(MATRIX x)`, over N columns of VECTOR. */
#define CHARON_INVERT_FUNCTION(NAME, MATRIX, SCALAR, TAG, N)                                                         \
    CHARON_INVERSE(SCALAR, TAG)                                                                                      \
    __attribute__((visibility("hidden")))                                                                            \
    MATRIX NAME(MATRIX x)                                                                                            \
    {                                                                                                                \
        SCALAR in[4][4], out[4][4];                                                                                  \
        for (int row = 0; row < N; row++) {                                                                          \
            for (int column = 0; column < N; column++) {                                                             \
                in[row][column] = x.columns[column][row];                                                            \
            }                                                                                                        \
        }                                                                                                            \
        charon_inverse_##TAG(in, N, out);                                                                            \
        MATRIX result;                                                                                               \
        for (int row = 0; row < N; row++) {                                                                          \
            for (int column = 0; column < N; column++) {                                                             \
                result.columns[column][row] = out[row][column];                                                      \
            }                                                                                                        \
        }                                                                                                            \
        return result;                                                                                               \
    }
