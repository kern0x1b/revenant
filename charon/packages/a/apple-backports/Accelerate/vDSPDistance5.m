// vDSP_distancesq, iOS 5.0. The ladder puts it at 5.0, so this is a 5.0 file and not one of the 6.0 files.
//
// **The whole specification is one line of the header's Maps comment**, which sits under the declaration:
//
//     C[0] = (A[0] - B[0])^2 + (A[1] - B[1])^2 + ... + (A[N-1] - B[N-1])^2;
//
// One scalar out. `IA` and `IB` are the strides of the two inputs and there is **no inner count because there
// is no inner dimension** - the window is N elements long. That is the part worth being explicit about: a
// reading of the signature alone, with two input strides, one output and no window width, invites a port that
// writes one C per element, and nothing in the signature would catch it. The formula settles it, and the
// differential checks it by pre-filling the whole of C and requiring every element outside C[0] to be
// untouched.
//
// The accumulation is left to right in the caller's own type. The oracle is the release's own vDSP on the
// **5.1.1** guest, which is the nearest release this emulator holds that exports the function; the macOS
// arm64 host is a candidate here and not the oracle, because it has been wrong twice on rows that are native
// on older releases.

#import <Accelerate/Accelerate.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wpointer-bool-conversion"
#pragma clang diagnostic ignored "-Wnonnull"

void vDSP_distancesq(const float *__A, vDSP_Stride __IA, const float *__B, vDSP_Stride __IB, float *__C,
                     vDSP_Length __N)
{
    if (!__A || !__B || !__C)
        return;
    // **N = 0 answers 0 at C[0].** The loop's initialiser writes it, so a zero-length call still answers, and
    // that is what the release does - measured on the guest, and recorded in facts/Accelerate/vDSPPlacement.md.
    const float *a = __A, *b = __B;
    float total = 0.0f;
    for (vDSP_Length n = 0; n < __N; n++) {
        const float difference = a[n * __IA] - b[n * __IB];
        total = total + difference * difference;
    }
    // One scalar, at C[0], and nothing else in C is touched - the formula names C[0] and no other element.
    *__C = total;
}
