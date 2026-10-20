#include <simd/simd.h>

#define REVENANT_INVERSE(SCALAR, TAG)                                                                                  \
    static SCALAR revenant_determinant_##TAG(const SCALAR m[4][4], int n)                                              \
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
            SCALAR term = m[0][column] * revenant_determinant_##TAG(minor, n - 1);                                     \
            sum += column % 2 ? -term : term;                                                                        \
        }                                                                                                            \
        return sum;                                                                                                  \
    }                                                                                                                \
                                                                                                                     \
                                       \
    static void revenant_inverse_##TAG(const SCALAR m[4][4], int n, SCALAR out[4][4])                                  \
    {                                                                                                                \
        SCALAR determinant = revenant_determinant_##TAG(m, n);                                                         \
        for (int row = 0; row < n; row++) {                                                                          \
            for (int column = 0; column < n; column++) {                                                             \
                                          \
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
                SCALAR cofactor = revenant_determinant_##TAG(minor, n - 1);                                           \
                out[row][column] = ((row + column) % 2 ? -cofactor : cofactor) / determinant;                        \
            }                                                                                                        \
        }                                                                                                            \
    }

#define REVENANT_INVERT_FUNCTION(NAME, MATRIX, SCALAR, TAG, N)                                                         \
    REVENANT_INVERSE(SCALAR, TAG)                                                                                      \
    __attribute__((visibility("hidden")))                                                                            \
    MATRIX NAME(MATRIX x)                                                                                            \
    {                                                                                                                \
        SCALAR in[4][4], out[4][4];                                                                                  \
        for (int row = 0; row < N; row++) {                                                                          \
            for (int column = 0; column < N; column++) {                                                             \
                in[row][column] = x.columns[column][row];                                                            \
            }                                                                                                        \
        }                                                                                                            \
        revenant_inverse_##TAG(in, N, out);                                                                            \
        MATRIX result;                                                                                               \
        for (int row = 0; row < N; row++) {                                                                          \
            for (int column = 0; column < N; column++) {                                                             \
                result.columns[column][row] = out[row][column];                                                      \
            }                                                                                                        \
        }                                                                                                            \
        return result;                                                                                               \
    }
