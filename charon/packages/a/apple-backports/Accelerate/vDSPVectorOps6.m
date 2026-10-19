// vDSP_vsmsma, iOS 6.0. The ladder puts it at 6.0.
//
// **The whole specification is one line of the header's Maps comment**, under the declaration:
//
//     out[i] = in1[i] * s1 + in2[i] * s2, with s1 = B[0] and s2 = D[0];
//
// **B and D are one scalar each.** `__B` and `__D` are typed as `const float *` because that is how a scalar is
// spelled, and reading the signature alone invites an array of per-channel scalars with an index that the
// signature nowhere supplies. The formula names `B[0]` and `D[0]`, so each is read once and every element
// multiplies and adds by the same two numbers.
//
// The arithmetic is left to right in the caller's own type: the product is formed in float and the add is a
// float add, so nothing is accumulated in a wider type. The differential pre-fills **the whole of E** over an
// array longer than any call here and compares every element of it, so the gaps between the stride's steps
// are required to come back exactly as they went in — a port that wrote E densely would pass a test that only
// looked at the elements it meant to write.
//
// **A 6.0 row in a file named for 6.0**, and the load cap and the empty-image install defect mean this is
// measured on the host so far: the guest is the oracle and has not run yet, so the registry row is inert.

#import <Accelerate/Accelerate.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wpointer-bool-conversion"
#pragma clang diagnostic ignored "-Wnonnull"

void vDSP_vsmsma(const float *__A, vDSP_Stride __IA, const float *__B, const float *__C, vDSP_Stride __IC,
                 const float *__D, float *__E, vDSP_Stride __IE, vDSP_Length __N)
{
    if (!__A || !__B || !__C || !__D || !__E)
        return;
    // **B and D are one scalar each, read once** - the formula's B[0] and D[0], not a per-channel array.
    const float b = __B[0], d = __D[0];
    for (vDSP_Length n = 0; n < __N; n++) {
        const float product_a = __A[n * __IA] * b;
        const float product_c = __C[n * __IC] * d;
        __E[n * __IE] = product_a + product_c;
    }
    // Nothing outside the stride's steps is touched: E is the caller's, and the gaps belong to the caller.
}
