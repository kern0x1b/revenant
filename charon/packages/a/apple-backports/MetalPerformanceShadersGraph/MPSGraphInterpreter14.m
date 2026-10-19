// The interpreter: what each operation kind does to its operands, and the walk that runs them.
//
// It is here rather than in MPSGraph14.m because the operations of a family are one kind each and a
// family lands by adding a case and a function; the graph itself is only the list of them and the walk.

#import "CharonMPSGraph.h"

// A value that is a denormal in the type it is stored as is a value the release's arithmetic never sees:
// it reads one as a zero of the same sign, and it leaves no denormal behind. Measured on macOS 27.0
// build 26A428 (M4 Pro, Metal 4) over the sixteen classes tests/backports/host/mpsgraph/graph-cases.m
// feeds, against -[MPSGraph squareRootWithTensor:name:] and its siblings on this host's own MPSGraph:
// square root of 0x00000001 is 0x00000000 and of 0x80000001 is 0x80000000, sign of 0x00000001 is 0,
// division of 0x00000001 by 0x00000001 is a NaN because both sides are read as zeros, and square of
// 0x00800000 - whose square is a denormal - is 0x00000000 while square of 0x3f7fffff is 0x3f7ffffe.
// A half is not flushed: the same host answers the sign of a half 0x0001 with 0x3c00 and its square root
// with 0x0c00, which is why this is the float type's answer and the other floating point type's is left
// as it is. facts/MetalPerformanceShadersGraph/Core.md carries the tables.
static double CharonMPSGraphAsZero(double value, MPSDataType type)
{
    if (type != MPSDataTypeFloat32)
        return value;
    float narrowed = (float)value;
    if (narrowed != 0.0f && fabsf(narrowed) < FLT_MIN)
        return copysign(0.0, narrowed);
    return value;
}

// A NaN that leaves the release's arithmetic is the arithmetic's own NaN and not the one it was given: a
// propagated sign and a propagated payload are both gone, and every kind that computes does it. Measured
// on the same host and the same sixteen classes, over a feed carrying 0xffc00000 and 0x7f800001: addition
// answers 0x7fc00000 for each of them, and so does every other kind that computes, while the two kinds
// that copy are the two that keep them - identity answers 0x7f800001 with 0x7f800001.
static double CharonMPSGraphOwnNaN(double value)
{
    return isnan(value) ? NAN : value;
}

// The kinds that read an operand as it is stored rather than as the release's float32 arithmetic reads
// it. Measured on this host's own MPSGraph over the sixteen classes the case file feeds, and each of
// these answers a denormal as itself: absolute of 0x00000001 is 0x00000001 and identity of 0x007fffff
// is 0x007fffff, the sign of an operand is its sign bit, the negation of 0x00000001 is 0x80000001,
// round of 0x00000001 is 0x00000000 and the sign of a zero result is dropped, modulo of 0x00000001 by
// -2.0 is 0x00000001, a minimum and a maximum of 0x00000001 and 0x7e00 is 0x00000001, a select whose
// predicate is a NaN takes the branch it takes for any other non-zero, and a clamp of a NaN is its
// bounds. Every other kind reads a denormal as a zero of the same sign, which is CharonMPSGraphAsZero.
static int CharonMPSGraphReadsOperandAsStored(CharonMPSGraphOperationKind kind)
{
    switch (kind) {
    case CharonMPSGraphOperationKindAbs:
    case CharonMPSGraphOperationKindIdentity:
    case CharonMPSGraphOperationKindSignBit:
    case CharonMPSGraphOperationKindNegate:
    case CharonMPSGraphOperationKindRound:
    case CharonMPSGraphOperationKindModulo:
    case CharonMPSGraphOperationKindFloorModulo:
    case CharonMPSGraphOperationKindMinimum:
    case CharonMPSGraphOperationKindMaximum:
    case CharonMPSGraphOperationKindSelect:
    case CharonMPSGraphOperationKindClamp3:
    // Five more, all measured the same way and all of them the same kind of case: the release answers a
    // denormal with the denormal, because for these five its own answer for a tiny argument is the
    // argument. sin, sinh, arcsine, asinh and the hyperbolic arc-tangent of 0x00000001 are 0x00000001 and
    // of 0x80000001 are 0x80000001, where a kernel that read the operand as a zero would answer a zero.
    // arctangent, the hyperbolic tangent and erf do not: measured, each of the three answers 0x00000000
    // for 0x00000001 and 0x80000001 for 0x80000001, and they are left out of this list for that reason.
    case CharonMPSGraphOperationKindSin:
    case CharonMPSGraphOperationKindSinh:
    case CharonMPSGraphOperationKindAsin:
    case CharonMPSGraphOperationKindAsinh:
    case CharonMPSGraphOperationKindAtanh:
        return 1;
    default:
        return 0;
    }
}

// The three kinds that copy an operand's bits and therefore answer the NaN they were given: measured,
// the identity of 0xffc00000 is 0xffc00000 where the square of it is 0x7fc00000.
static int CharonMPSGraphCopiesTheOperand(CharonMPSGraphOperationKind kind)
{
    return kind == CharonMPSGraphOperationKindAbs || kind == CharonMPSGraphOperationKindIdentity ||
           kind == CharonMPSGraphOperationKindSignBit;
}

// The kinds that answer the NaN they were given rather than the arithmetic's own. Measured on the same
// host and the same classes: the negation of 0x7fc00000 is 0xffc00000 and of 0xffc00000 is 0x7fc00000,
// which is what a sign-bit flip answers; round, arcsine, arctangent, the hyperbolic arc-sine and the
// hyperbolic arc-tangent each answer a negative NaN with a negative NaN; and a select whose chosen
// operand is a NaN answers that NaN, so a select over a source of 0xffc00000 is 0xffc00000. Every other
// kind that computes answers 0x7fc00000 for either sign, which is CharonMPSGraphOwnNaN.
static int CharonMPSGraphKeepsTheNaNItWasGiven(CharonMPSGraphOperationKind kind)
{
    switch (kind) {
    case CharonMPSGraphOperationKindNegate:
    case CharonMPSGraphOperationKindRound:
    case CharonMPSGraphOperationKindSelect:
    case CharonMPSGraphOperationKindAsin:
    case CharonMPSGraphOperationKindAtan:
    case CharonMPSGraphOperationKindAsinh:
    case CharonMPSGraphOperationKindAtanh:
        return 1;
    default:
        return 0;
    }
}

// The kinds whose half answer this host gives itself rather than IEEE's. Measured over the sixteen
// classes in MPSDataTypeFloat16, and each of them is in the table in
// facts/MetalPerformanceShadersGraph/Core.md: a zero leaves the half path without its sign, a NaN is an
// infinity or a zero by kind, a negative argument to a square root or a reverse square root is a zero, a
// zero to a logarithm is -45440, and so on. A kind that is not in this list has no measured half rule of
// its own, so its result is the arithmetic's and the store narrows it - which is what the differential
// then measures, and what recorded-cells.txt records where the two still differ.
// What a kind's answer is in MPSDataTypeFloat16 when an operand is a NaN, measured for each of them over
// the case file's thirty-two classes and written down in facts/MetalPerformanceShadersGraph/Core.md. The
// release's half kernels do not agree with each other here, which is the whole of what this table is: the
// arithmetic family answers an infinity of the NaN's own sign, the sine and the cosine answer a zero, the
// inverse hyperbolics answer the canonical positive NaN, the error function and the hyperbolic tangent
// saturate at the sign of the NaN, a power saturates at one whatever the sign, and a sigmoid answers one
// for a positive NaN and a zero for a negative one.
typedef NS_ENUM(NSInteger, CharonMPSGraphHalfNaN) {
    CharonMPSGraphHalfNaNNone = 0,
    // An infinity of the NaN's own sign: the arithmetic family's own rule, and the one `ceil`, `floor`,
    // `round`, `select` and a ReLU's gradient follow. Measured: each of 0x7e00 and 0xfe00 answers an
    // infinity of that sign, 0x7c00 and 0xfc00.
    CharonMPSGraphHalfNaNInfinityOfSign,
    // The same with the sign of the operand turned over first, which is what a negation does to a NaN
    // before it becomes an infinity: measured, the negation of 0x7e00 is 0xfc00 and of 0xfe00 is 0x7c00.
    CharonMPSGraphHalfNaNInfinityOfFlippedSign,
    // A zero. Measured: the sine and the cosine of 0x7e00 and of 0xfe00 are each 0x0000, and so is each
    // of them of an infinity of either sign.
    CharonMPSGraphHalfNaNZero,
    // The canonical positive NaN, 0x7e00, whichever sign the operand carried: measured, the arcsine, the
    // hyperbolic arc-sine and the hyperbolic arc-tangent of 0xfe00 are 0x7e00.
    CharonMPSGraphHalfNaNCanonical,
    // A saturation at the sign of the NaN: the error function and the hyperbolic tangent answer 0x3c00
    // for 0x7e00 and 0xbc00 for 0xfe00.
    CharonMPSGraphHalfNaNSaturates,
    // A saturation at one whatever the sign: a power of an infinity, a NaN or a negative number is
    // 0x3c00, measured, and so is a power of a negative ordinary value.
    CharonMPSGraphHalfNaNSaturatesAtOne,
    // One for a positive NaN and a zero for a negative one: measured, that is what a sigmoid answers.
    CharonMPSGraphHalfNaNSigmoid
};

static CharonMPSGraphHalfNaN CharonMPSGraphHalfNaNOf(CharonMPSGraphOperationKind kind)
{
    switch (kind) {
    case CharonMPSGraphOperationKindAbs:
    case CharonMPSGraphOperationKindIdentity:
    case CharonMPSGraphOperationKindAdd:
    case CharonMPSGraphOperationKindSubtract:
    case CharonMPSGraphOperationKindSquare:
    case CharonMPSGraphOperationKindReciprocal:
    case CharonMPSGraphOperationKindSqrt:
    case CharonMPSGraphOperationKindRsqrt:
    case CharonMPSGraphOperationKindLog:
    case CharonMPSGraphOperationKindSign:
    case CharonMPSGraphOperationKindCeil:
    case CharonMPSGraphOperationKindFloor:
    case CharonMPSGraphOperationKindRound:
    case CharonMPSGraphOperationKindSelect:
    case CharonMPSGraphOperationKindReLUGradient:
        return CharonMPSGraphHalfNaNInfinityOfSign;
    case CharonMPSGraphOperationKindNegate:
        return CharonMPSGraphHalfNaNInfinityOfFlippedSign;
    case CharonMPSGraphOperationKindSin:
    case CharonMPSGraphOperationKindCos:
    case CharonMPSGraphOperationKindLogBase2:
        return CharonMPSGraphHalfNaNZero;
    case CharonMPSGraphOperationKindAsin:
    case CharonMPSGraphOperationKindAcos:
    case CharonMPSGraphOperationKindAsinh:
    case CharonMPSGraphOperationKindAcosh:
    case CharonMPSGraphOperationKindAtanh:
        return CharonMPSGraphHalfNaNCanonical;
    case CharonMPSGraphOperationKindErf:
    case CharonMPSGraphOperationKindTanh:
        return CharonMPSGraphHalfNaNSaturates;
    case CharonMPSGraphOperationKindPower:
        return CharonMPSGraphHalfNaNSaturatesAtOne;
    case CharonMPSGraphOperationKindSigmoid:
        return CharonMPSGraphHalfNaNSigmoid;
    case CharonMPSGraphOperationKindReLU:
        // Measured, and it is neither of the two above: a ReLU of 0x7e00 is 0x7c00 and of 0xfe00 is
        // 0x0000, so a positive NaN is a positive infinity and a negative one is a zero.
        return CharonMPSGraphHalfNaNInfinityOfSign;
    default:
        return CharonMPSGraphHalfNaNNone;
    }
}

static int CharonMPSGraphHalfRule(CharonMPSGraphOperationKind kind)
{
    return CharonMPSGraphHalfNaNOf(kind) != CharonMPSGraphHalfNaNNone;
}

// One element of an arithmetic operation. The data type of the operands decides the arithmetic, as it
// does everywhere else in this framework: an integer type rounds on store and a floating point one
// rounds on store too, through the same store both families use. The store is asked for the release's
// own rounding of a halfway half - CharonMPSStoreRounded with the last argument set - which is this
// family's measured behaviour and no other family's: see CharonMPSFloatToHalfRounded.
//
// The third operand is 0.0 for a kind that takes fewer than three: a select and a clamp are the only
// kinds that read it, and passing a zero for the rest keeps one signature for the whole family.
//
// `latch` is the one rule that is not the kind's own: an operation that latches a NaN answers a NaN if
// any operand is one, and the arithmetic below otherwise. It is read out of the operation's parameters
// rather than out of its kind for the same reason the fold table is - the method that asks for it
// arrived in a later release than the object this is, and what it asks for is "this arithmetic, and a
// NaN on either side wins", which is two things this object can say without naming that release.
static double CharonMPSGraphApply(CharonMPSGraphOperationKind kind, double a, double b, double c,
                                  MPSDataType operandType, MPSDataType resultType, int latch)
{
    if (latch && (isnan(a) || isnan(b) || isnan(c)))
        return CharonMPSGraphOwnNaN(NAN);
    int stored = CharonMPSGraphReadsOperandAsStored(kind);
    if (!stored) {
        a = CharonMPSGraphAsZero(a, operandType);
        b = CharonMPSGraphAsZero(b, operandType);
        c = CharonMPSGraphAsZero(c, operandType);
    }
    // An integer type has no infinity and no NaN, so the three questions about a value are asked of the
    // integer as it is: an integer is finite, is not infinite and is not a NaN. Measured on this host's
    // own MPSGraph with an int32 operand, where isNaN answers false for every element including the
    // largest negative one.
    int integral = operandType != MPSDataTypeFloat32 && operandType != MPSDataTypeFloat16;
    double result;
    switch (kind) {
    case CharonMPSGraphOperationKindAbs:
        result = integral ? a : fabs(a);
        break;
    case CharonMPSGraphOperationKindIdentity:
        result = a;
        break;
    // A division, a reciprocal, a square root and a logarithm are the arithmetic itself and nothing
    // else: what the release answers for a zero, a negative and an infinity is what IEEE answers, so a
    // branch that decided it separately answered a negative zero with the wrong infinity.
    case CharonMPSGraphOperationKindAdd:
        result = a + b;
        break;
    case CharonMPSGraphOperationKindSubtract:
        result = a - b;
        break;
    case CharonMPSGraphOperationKindMultiply:
        result = a * b;
        break;
    case CharonMPSGraphOperationKindDivide:
        result = a / b;
        break;
    case CharonMPSGraphOperationKindNegate:
        result = -a;
        break;
    case CharonMPSGraphOperationKindSquare:
        result = a * a;
        break;
    case CharonMPSGraphOperationKindReciprocal:
        result = 1.0 / a;
        break;
    case CharonMPSGraphOperationKindRsqrt:
        result = 1.0 / sqrt(a);
        break;
    // The square root of a negative is a NaN, which is the whole of what the header's own operation
    // means and what the release answers: a feed of (1, 2, 3, 4, -1, -2, -3, -4) comes back as
    // 1, 1.41421, 1.73205, 2 and then four NaNs, byte for byte on this host.
    case CharonMPSGraphOperationKindSqrt:
        result = sqrt(a);
        break;
    case CharonMPSGraphOperationKindExp:
        result = exp(a);
        break;
    case CharonMPSGraphOperationKindLog:
        result = log(a);
        break;
    case CharonMPSGraphOperationKindSign:
        result = a > 0.0 ? 1.0 : (a < 0.0 ? -1.0 : 0.0);
        break;
    case CharonMPSGraphOperationKindMinimum:
        // fmin and fmax, which answer the operand that is not a NaN: measured on this host's own MPSGraph,
        // a minimum of +inf and a NaN is +inf and of a NaN and 0x00000001 is 0x00000001, where an operator
        // that only compares would answer a NaN for both.
        result = fmin(a, b);
        break;
    case CharonMPSGraphOperationKindMaximum:
        result = fmax(a, b);
        break;
    case CharonMPSGraphOperationKindClamp:
        result = a < b ? a : b;
        break;
    case CharonMPSGraphOperationKindExpBase2:
        result = exp2(a);
        break;
    case CharonMPSGraphOperationKindExpBase10:
        // pow(10, x) and not exp10(x): the C library declares no exp10 for this target (a syntax check
        // with -target armv7-apple-ios6.0 answers "call to undeclared function 'exp10'"), and pow is the
        // spelling every one of them agrees with. The differential measures whether it agrees to the
        // byte over the sixteen classes.
        result = pow(10.0, a);
        break;
    case CharonMPSGraphOperationKindLogBase2:
        result = log2(a);
        break;
    case CharonMPSGraphOperationKindLogBase10:
        result = log10(a);
        break;
    case CharonMPSGraphOperationKindSin:
        result = sin(a);
        break;
    case CharonMPSGraphOperationKindCos:
        result = cos(a);
        break;
    case CharonMPSGraphOperationKindTan:
        result = tan(a);
        break;
    case CharonMPSGraphOperationKindSinh:
        result = sinh(a);
        break;
    case CharonMPSGraphOperationKindCosh:
        result = cosh(a);
        break;
    case CharonMPSGraphOperationKindTanh:
        result = tanh(a);
        break;
    case CharonMPSGraphOperationKindAsin:
        result = asin(a);
        break;
    case CharonMPSGraphOperationKindAcos:
        result = acos(a);
        break;
    case CharonMPSGraphOperationKindAtan:
        result = atan(a);
        break;
    case CharonMPSGraphOperationKindAsinh:
        result = asinh(a);
        break;
    case CharonMPSGraphOperationKindAcosh:
        result = acosh(a);
        break;
    case CharonMPSGraphOperationKindAtanh:
        result = atanh(a);
        break;
    case CharonMPSGraphOperationKindErf:
        result = erf(a);
        break;
    // The sign bit, read as a bit: a NaN compares false against everything, so a comparison would answer
    // a NaN's sign as neither, and the release answers the bit it carries.
    case CharonMPSGraphOperationKindSignBit:
        result = signbit(a) ? 1.0 : 0.0;
        break;
    case CharonMPSGraphOperationKindFloor:
        result = integral ? a : floor(a);
        break;
    case CharonMPSGraphOperationKindCeil:
        result = integral ? a : ceil(a);
        break;
    // The two roundings the header separates: round is the half away from zero and rint is the one the
    // C library rounds to even with, which is what the two names in MPSGraphArithmeticOps.h mean.
    case CharonMPSGraphOperationKindRound:
        result = integral ? a : round(a);
        // A round that lands on zero is a positive zero: measured, round of -0.0, of -0x1p-126 and of
        // -0x1p-20 are each 0x00000000 where round(-0.0) in C is -0.0.
        if (result == 0.0)
            result = 0.0;
        break;
    case CharonMPSGraphOperationKindRint:
        result = integral ? a : rint(a);
        break;
    case CharonMPSGraphOperationKindIsNaN:
        result = integral ? 0.0 : (isnan(a) ? 1.0 : 0.0);
        break;
    case CharonMPSGraphOperationKindIsFinite:
        result = integral ? 1.0 : (isfinite(a) ? 1.0 : 0.0);
        break;
    case CharonMPSGraphOperationKindIsInfinite:
        result = integral ? 0.0 : (isinf(a) ? 1.0 : 0.0);
        break;
    case CharonMPSGraphOperationKindLogicalNot:
        result = a == 0.0 ? 1.0 : 0.0;
        break;
    // A comparison against a NaN is false and a comparison against something equal is true: that is what
    // the operators are, and the release's six predicates over the sixteen classes agree with it cell by
    // cell, so no branch of its own is written for them.
    case CharonMPSGraphOperationKindEqual:
        result = a == b ? 1.0 : 0.0;
        break;
    case CharonMPSGraphOperationKindNotEqual:
        result = a != b ? 1.0 : 0.0;
        break;
    case CharonMPSGraphOperationKindLessThan:
        result = a < b ? 1.0 : 0.0;
        break;
    case CharonMPSGraphOperationKindLessThanOrEqualTo:
        result = a <= b ? 1.0 : 0.0;
        break;
    case CharonMPSGraphOperationKindGreaterThan:
        result = a > b ? 1.0 : 0.0;
        break;
    case CharonMPSGraphOperationKindGreaterThanOrEqualTo:
        result = a >= b ? 1.0 : 0.0;
        break;
    case CharonMPSGraphOperationKindLogicalAnd:
        result = (a != 0.0 && b != 0.0) ? 1.0 : 0.0;
        break;
    case CharonMPSGraphOperationKindLogicalOr:
        result = (a != 0.0 || b != 0.0) ? 1.0 : 0.0;
        break;
    case CharonMPSGraphOperationKindLogicalNand:
        result = !(a != 0.0 && b != 0.0) ? 1.0 : 0.0;
        break;
    case CharonMPSGraphOperationKindLogicalNor:
        result = !(a != 0.0 || b != 0.0) ? 1.0 : 0.0;
        break;
    case CharonMPSGraphOperationKindLogicalXor:
        result = (a != 0.0) != (b != 0.0) ? 1.0 : 0.0;
        break;
    case CharonMPSGraphOperationKindLogicalXnor:
        result = (a != 0.0) == (b != 0.0) ? 1.0 : 0.0;
        break;
    // C's two remainders: fmod truncates towards zero and the floor modulo answers the remainder of
    // the same sign as the divisor, which is what "floor" in the name means.
    case CharonMPSGraphOperationKindModulo:
        result = fmod(a, b);
        break;
    case CharonMPSGraphOperationKindFloorModulo:
        result = fmod(fmod(a, b) + b, b);
        break;
    case CharonMPSGraphOperationKindPower:
        result = pow(a, b);
        break;
    case CharonMPSGraphOperationKindAtan2:
        result = atan2(a, b);
        break;
    // A division that answers a zero where IEEE would answer a NaN, which is what the "NoNaN" in its own
    // name says. It is the divisor that decides, and a NaN divisor is not one of them: measured over the
    // sixteen classes on this host's own MPSGraph, a zero divisor answers 0x00000000 for every numerator
    // while a NaN divisor answers the arithmetic's NaN - an infinity over a NaN is 0x7fc00000 and a NaN
    // over 2.0 is 0x7fc00000 - and a NaN numerator over an ordinary divisor is that NaN.
    case CharonMPSGraphOperationKindDivisionNoNaN:
        result = b == 0.0 ? 0.0 : a / b;
        break;
    case CharonMPSGraphOperationKindSelect:
        result = a != 0.0 ? b : c;
        break;
    // fmin(fmax(a, lo), hi), which is what answers a NaN with a bound rather than with a NaN: measured,
    // a clamp of a NaN between two equal bounds is that bound.
    case CharonMPSGraphOperationKindClamp3:
        result = fmin(fmax(a, b), c);
        break;
    case CharonMPSGraphOperationKindReLU:
        result = a > 0.0 ? a : 0.0;
        break;
    // A gradient passes the incoming gradient through where the source is on the other side of the
    // activation's own branch and answers the gradient itself times a zero of the same sign where it is
    // not, which is what the two gradient operations are. Measured over the sixteen classes: a ReLU
    // gradient of an incoming gradient of 1.0 over a source of -0.0 is 0x80000000, so the sign is the
    // incoming gradient's and not a positive zero, and a source that is a NaN is a NaN rather than the
    // gradient - an infinity over a NaN is 0x7fc00000 where the gradient itself would be 0x7f800000.
    case CharonMPSGraphOperationKindReLUGradient:
        result = isnan(b) ? NAN : (b > 0.0 ? a : a * 0.0);
        break;
    case CharonMPSGraphOperationKindSigmoid:
        result = 1.0 / (1.0 + exp(-a));
        break;
    // A sigmoid's gradient reads the source as the value that was activated, not as its answer: measured
    // over the sixteen classes, a sigmoidGradient of an incoming gradient of 1.0 over a source of 0.0 is
    // 0x3e800000, which is 1.0 times the sigmoid of 0.0 times one minus the sigmoid of 0.0.
    case CharonMPSGraphOperationKindSigmoidGradient: {
        double s = 1.0 / (1.0 + exp(-b));
        result = a * s * (1.0 - s);
        break;
    }
    default:
        result = a;
        break;
    }
    if (resultType == MPSDataTypeFloat16 && CharonMPSGraphHalfRule(kind)) {
        /* A half is a different arithmetic on this host, and this is the half of it that is a rule
         * rather than an approximation. Measured on macOS 27.0 build 26A428 (M4 Pro, Metal 4) over
         * the sixteen classes tests/backports/host/mpsgraph/graph-cases.m feeds, against the same
         * operations on this host's own MPSGraph; facts/MetalPerformanceShadersGraph/Core.md carries
         * the whole table and what is left of it that no rule reaches.
         *
         * A zero leaves the half path without its sign: the identity of a half -0.0 is 0x0000, a
         * square root of -0.0 is 0x0000, and the reciprocal of -inf is 0x0000 where the reciprocal of
         * +inf is 0x0000 too. A NaN operand is an infinity of that NaN's own sign for the three kinds
         * that carry the sign - the identity, an addition and a subtraction - and a positive infinity
         * for the two that drop it, the square and the absolute value, while the square root answers
         * an infinity for a positive NaN and a zero for a negative one, the reverse square root and
         * the logarithm answer a zero for either, and the sign answers the NaN's sign. A negative
         * argument is a zero to a square root and to a reverse square root, a logarithm of a zero is
         * -45440 (0xf98c) and of anything else that is not a positive number is a zero.
         */
        if (isnan(a) || isnan(b) || isnan(c)) {
            double sign = isnan(a) ? a : (isnan(b) ? b : c);
            switch (CharonMPSGraphHalfNaNOf(kind)) {
            case CharonMPSGraphHalfNaNInfinityOfSign:
                result = copysign(INFINITY, sign);
                break;
            case CharonMPSGraphHalfNaNInfinityOfFlippedSign:
                result = copysign(INFINITY, -sign);
                break;
            case CharonMPSGraphHalfNaNZero:
                result = 0.0;
                break;
            case CharonMPSGraphHalfNaNCanonical:
                result = NAN;
                break;
            case CharonMPSGraphHalfNaNSaturates:
                result = copysign(1.0, sign);
                break;
            case CharonMPSGraphHalfNaNSaturatesAtOne:
                result = 1.0;
                break;
            case CharonMPSGraphHalfNaNSigmoid:
                result = signbit(sign) ? 0.0 : 1.0;
                break;
            default:
                // The two the arithmetic family has and the table above does not: the square and the
                // absolute value answer a positive infinity for a NaN of either sign, and a reciprocal
                // answers a zero of either sign.
                result = (kind == CharonMPSGraphOperationKindReciprocal) ? 0.0 : INFINITY;
                break;
            }
            // The square root and the sign are the two the table cannot hold, because their answer is
            // read off the bit and not off the class: measured, the square root of a positive NaN is
            // 0x7c00 and of a negative one 0x0000, and the sign of a NaN is the sign of the NaN.
            if (kind == CharonMPSGraphOperationKindSqrt)
                result = signbit(sign) ? 0.0 : INFINITY;
            else if (kind == CharonMPSGraphOperationKindSign)
                result = copysign(1.0, sign);
            if (kind == CharonMPSGraphOperationKindSquare || kind == CharonMPSGraphOperationKindAbs)
                result = INFINITY;
        } else if (isinf(a) && (kind == CharonMPSGraphOperationKindSin || kind == CharonMPSGraphOperationKindCos)) {
            // Measured: the sine and the cosine of an infinity of either sign are 0x0000, where the
            // arithmetic of an infinity is a NaN.
            result = 0.0;
        } else {
            switch (kind) {
            case CharonMPSGraphOperationKindSqrt:
                // A negative argument is a zero, measured: the square root of a half -1.0 is 0x0000,
                // and of -inf and of a negative NaN and of a negative denormal too. A negative zero
                // is answered by the zero rule below.
                if (a < 0.0) {
                    result = 0.0;
                }
                break;
            case CharonMPSGraphOperationKindRsqrt:
                // The same zero for a negative argument, and a positive infinity for a zero of either
                // sign, where the reciprocal of one is a negative infinity and this is not: measured,
                // the reverse square root of a half -0.0 is 0x7c00 and of 0x0000 is 0x7c00.
                result = a < 0.0 ? 0.0 : (a == 0.0 ? INFINITY : result);
                break;
            case CharonMPSGraphOperationKindReciprocal:
                // A zero of either sign is a positive infinity, where the reciprocal of a negative zero
                // is a negative infinity in IEEE and 0x7c00 here.
                result = a == 0.0 ? INFINITY : result;
                break;
            case CharonMPSGraphOperationKindLog:
                // The measured -45440 of a logarithm of a zero, and a zero for everything else that
                // is not a positive number: -1, an infinity of either sign and a NaN all answer 0x0000.
                // An infinity is a zero here too, measured: the logarithm of a half +inf is 0x0000.
                result = a == 0.0 ? -45440.0 : (isinf(a) ? 0.0 : (a > 0.0 ? log(a) : 0.0));
                break;
            case CharonMPSGraphOperationKindSign:
                // The sign of the value and not a comparison of it: a NaN is answered with the sign
                // bit it carries, which is why the two NaN classes are 0x3c00 and 0xbc00 here and a
                // zero with either sign is 0x0000.
                result = a != 0.0 ? copysign(1.0, a) : 0.0;
                break;
            default:
                break;
            }
        }
    }
    // A zero is a positive zero in half as it is in the float types, and it is one rule for every kind
    // rather than one per operation: measured, the ceiling of a positive zero, the floor of a positive
    // zero, the sine of a positive zero, a product of a negative zero, the negation of a negative zero, a
    // maximum of -1.0 and -0.0, a select whose value is a negative zero, a ReLU's gradient of a negative
    // ordinary source and an error function of a positive zero are each 0x0000, where IEEE answers a
    // zero of the operand's own sign.
    //
    // The one kernel of this family that does not have it is the latching one of 15.0, and that is
    // measured rather than assumed: over the same sixteen classes in float16, its maximum of -1.0 and
    // -0.0 answers 0x8000 and its maximum of +0.0 and -inf answers 0x8000, where the kernel above answers
    // 0x0000 for the same two pairs and where the port's float32 answer is -0.0 for both. So the rule
    // belongs to the kernel that has it, and which kernel an operation is comes out of its parameters.
    if (resultType == MPSDataTypeFloat16 && result == 0.0 && !latch)
        result = 0.0;
    // A boolean is a truth and not a number, so a predicate's result goes through the store as the one
    // or the zero it is and the two rules above - the release's own NaN and the flush - do not touch it.
    if (resultType == MPSDataTypeBool)
        return result != 0.0 ? 1.0 : 0.0;
    // A zero is a positive zero for two of the transcendentals, which is a rule and not IEEE's: measured
    // over the same sixteen classes, the arctangent and the hyperbolic tangent of -0.0 are 0x00000000
    // where IEEE answers -0.0, and the hyperbolic tangent of a negative denormal is 0x00000000 as well.
    // It is applied after the flush, so a denormal that flushed to a zero of either sign comes out
    // positive, and only for those two: the identity, a reciprocal, a square root, a remainder and a
    // minimum all answer -0.0 for a negative zero on this host, measured, and are left alone.
    if ((kind == CharonMPSGraphOperationKindAtan || kind == CharonMPSGraphOperationKindTanh) &&
        result == 0.0)
        result = 0.0;
    if (CharonMPSGraphCopiesTheOperand(kind))
        return stored ? result : CharonMPSGraphAsZero(result, resultType);
    double narrowed = stored ? result : CharonMPSGraphAsZero(result, resultType);
    // A kind that keeps the NaN it was given keeps it only when it WAS given one: the arcsine of a NaN
    // is that NaN, measured, and the arcsine of -inf is 0x7fc00000 and not a NaN of a negative sign.
    if (CharonMPSGraphKeepsTheNaNItWasGiven(kind) && (isnan(a) || isnan(b)))
        return narrowed;
    return CharonMPSGraphOwnNaN(narrowed);
}

// The reduction family is not element by element. Every element of the operand contributes to one
// element of the result, and which one is the operand's shape with the reduced axes taken out, so the
// walk here is over the OPERAND and folds into the result, which is the one place in this interpreter
// where that is true.
//
// The walk is a TABLE, and the table is keyed by the operation's own parameters rather than by which
// kind of operation it is. That is what lets every release's reduction - 14.0's eight here, 15.0's two
// argument reductions and two binary NaN-propagating extremes, 15.3's two truth folds - share one walk
// while every one of those objects names only its own SDK methods: an operation says which fold it is
// (@"combination"), whether a NaN latches (@"propagateNaN"), whether the answer is an index rather than
// a value (@"index"), and none of those words is a name of any release's framework.
//
// The result buffer is the accumulator, so every fold is written back through the type the result is
// stored as and each partial answer is the value that type can hold - which is what a reduction that
// accumulates in its own storage type does. Measured on this host's own MPSGraph over the feeds
// .agent-work/runs/probe-reduction.out carries: the sum of (1, 2, 3, 4) in float16 is 0x4900 = 10 and
// in float32 0x41200000 = 10, and the mean of the same four in float16 is 0x4100 = 2.5.
//
// One fold, and its seed and the shape of its step. The seeds are measured rather than reasoned: a sum
// starts at the zero of the type and a product at its one, the two extremes start at the infinities (a
// maximum at negative infinity and a minimum at positive), and the two truth folds start at the identity
// of their own fold - one for the "and" and zero for the "or" - which is why a fold over any number of
// elements is right and which is measured over rows that hold a zero and rows that do not.
typedef struct {
    const char *combination;
    double seed;
    int isExtreme;   // a comparison decides each fold, so a NaN loses it
    int isLesser;    // the minimum rather than the maximum
    int isTruth;     // the operand is a question about nonzeroness, not a number to add up
    int isOr;        // within a truth fold: any element rather than every one
    int multiplies;  // the step is a product rather than a sum
    int divides;     // the answer is over the count of the reduced set
} CharonMPSGraphFold;

static const CharonMPSGraphFold CharonMPSGraphFolds[] = {
    // seed, isExtreme, isLesser, isTruth, isOr, multiplies, divides
    {"sum", 0.0, 0, 0, 0, 0, 0, 0},
    {"product", 1.0, 0, 0, 0, 0, 1, 0},
    {"maximum", -INFINITY, 1, 0, 0, 0, 0, 0},
    {"minimum", INFINITY, 1, 1, 0, 0, 0, 0},
    {"and", 1.0, 0, 0, 1, 0, 0, 0},
    {"or", 0.0, 0, 0, 1, 1, 0, 0},
    // The mean and the variance are the sum over the reduced set and the sum of the squared deviations
    // about it, both taken over the count: the difference between them is in the second walk, not in the
    // fold, so the two share the sum's row here.
    {"mean", 0.0, 0, 0, 0, 0, 0, 1},
    {"variance", 0.0, 0, 0, 0, 0, 0, 1},
};

static const CharonMPSGraphFold *CharonMPSGraphFoldNamed(const char *combination)
{
    if (combination == NULL)
        return NULL;
    for (unsigned i = 0; i < sizeof(CharonMPSGraphFolds) / sizeof(CharonMPSGraphFolds[0]); i++)
        if (strcmp(CharonMPSGraphFolds[i].combination, combination) == 0)
            return &CharonMPSGraphFolds[i];
    return NULL;
}

// Which output element one input element folds into. A tensor is row-major with its FIRST axis the
// slowest moving, so the coordinates come out by dividing from the LAST axis backwards - reading them the
// other way is what made this port answer the transpose of every reduction at first, because the
// coordinates of a 2x4's elements 0 and 2 were read as one row and one column when they are both of the
// first row. `stride` is each kept axis's own stride in the RESULT, computed once by the caller, so that
// the coordinates can be folded into an index as they are met.
static NSUInteger CharonMPSGraphReductionIndex(NSArray<NSNumber *> *shape, const unsigned char *dropped,
                                               const unsigned long long *stride, NSUInteger element)
{
    NSUInteger rank = shape.count;
    NSUInteger index = element, out = 0;
    for (NSUInteger axis = rank; axis-- > 0;) {
        NSUInteger extent = (NSUInteger)shape[axis].unsignedIntegerValue;
        NSUInteger coordinate = extent ? index % extent : 0;
        if (extent)
            index /= extent;
        if (!dropped[axis])
            out += (NSUInteger)(coordinate * stride[axis]);
    }
    return out;
}

// The coordinate of one element along one axis, which is the index an argument reduction answers. The
// same dividing from the last axis backwards, read out for the axis itself.
static long CharonMPSGraphCoordinate(NSArray<NSNumber *> *shape, NSUInteger axis, NSUInteger element)
{
    NSUInteger rank = shape.count, index = element;
    for (NSUInteger i = rank; i-- > 0;) {
        NSUInteger extent = (NSUInteger)shape[i].unsignedIntegerValue;
        if (i == axis)
            return (long)(extent ? index % extent : 0);
        if (extent)
            index /= extent;
    }
    return 0;
}

// One step of a fold: the held answer and the value that has just been read, and the answer after it. It
// is one function because the reduction walk and the cumulative walk fold with the same four steps and the
// same seeds, and a second copy of these rules would be a second thing to keep measured - the NaN that
// loses a comparison and therefore skips, the truth fold's test against zero, and the arithmetic's own NaN
// for the sum and the product.
// `propagates` and `tiesToValue` are the two rules that belong to a kernel rather than to a fold, and both
// are measured: the two propagating reductions of 14.0 latch a NaN and every other fold skips one, and the
// reduction family's comparison is strict - a row of (0, -0, 0, -0) answers 0 for a maximum, the first of
// the equal elements - where a scan's is not: over the same row scanned in reverse, the release answers a
// NEGATIVE zero where a strict comparison keeps the zero it already held, and answers a positive zero where
// a strict comparison would take the negative one it was handed. So the reduction passes (1, 0) here and
// the scan (0, 1).
static double CharonMPSGraphFoldStep(const CharonMPSGraphFold *fold, double held, double value, int propagates,
                                     int tiesToValue)
{
    if (fold->isExtreme) {
        // One comparison, and every rule of the four extremes is in it. A NaN loses the comparison against
        // anything including another NaN, so it is skipped - which is how a maximum that does not propagate
        // ignores one, and which is every cumulative extreme (measured: a NaN in a scan of either extreme is
        // skipped in both directions). The propagating variant latches instead: a NaN that has reached this
        // element is its answer, a NaN that arrives puts it there, and nothing after it can move it, because
        // a comparison against a NaN also loses. Only the two reductions of 14.0 latch.
        if (isnan(value))
            return propagates ? CharonMPSGraphOwnNaN(NAN) : held;
        if (propagates && isnan(held))
            return held;
        if (fold->isLesser)
            return tiesToValue ? (value <= held ? value : held) : (value < held ? value : held);
        return tiesToValue ? (value >= held ? value : held) : (value > held ? value : held);
    }
    if (fold->isTruth) {
        // The two truth folds, which are a question about every element rather than an arithmetic over it,
        // and the answer is written in the operand's own type: measured, an "and" of a row holding a zero
        // answers 0 and of a row of nothing but NaNs answers 1, so the test is against zero and a NaN is a
        // nonzero like any other value. The held answer is the one or the zero the buffer holds.
        int truth = value != 0.0;
        int was = held != 0.0;
        return (fold->isOr ? (truth || was) : (truth && was)) ? 1.0 : 0.0;
    }
    // A NaN that leaves the sum or the product is the arithmetic's own NaN and not the one it was handed,
    // as everywhere else in this interpreter: measured, the product of a row of (infinity, -infinity, NaN,
    // -NaN) is 0x7fc00000 on this host and was a negative NaN here until the fold was put through this rule.
    return CharonMPSGraphOwnNaN(fold->multiplies ? held * value : held + value);
}

static void CharonMPSGraphReduce(MPSGraphOperation *operation, MPSGraphTensorData *source,
                                  MPSGraphTensorData *meanGiven, MPSGraphTensorData *result)
{
    NSDictionary *parameters = operation.charon_mps_parameters;
    NSArray<NSNumber *> *shape = source.shape;
    NSArray<NSNumber *> *axes = parameters[@"axes"];
    NSUInteger sourceCount = [source charon_mps_elementCount];
    NSUInteger resultCount = [result charon_mps_elementCount];
    NSUInteger rank = shape.count;
    MPSDataType type = source.dataType;
    MPSDataType resultType = result.dataType;
    size_t resultSize = MPSSizeofMPSDataType(resultType);
    void *in = [source charon_mps_bytes];
    void *out = [result charon_mps_bytes];
    const CharonMPSGraphFold *fold = CharonMPSGraphFoldNamed([parameters[@"combination"] UTF8String]);
    if (fold == NULL || !axes || sourceCount == 0 || resultCount == 0)
        return;

    // A reduction over no axis at all is the identity: the operand, byte for byte, and no fold. Measured
    // on this host's own MPSGraph over the sixteen classes, axes:@[] answers the 2x4 the operand already
    // was for a sum, for a product, and for the two truth folds of 15.3 - and the last two are what say
    // so, because a sum and a product of the identity are the identity either way: an "and" of the set of
    // elements a single element contributes would answer 1 and 0, and answers -1.0 and +inf instead.
    if (axes.count == 0) {
        size_t elementSize = MPSSizeofMPSDataType(type);
        for (NSUInteger i = 0; i < resultCount && i < sourceCount; i++)
            memcpy((char *)out + i * resultSize, (const char *)in + i * elementSize,
                   MIN(resultSize, elementSize));
        return;
    }

    unsigned char *dropped = calloc(rank ? rank : 1, 1);
    unsigned long long *stride = calloc(rank ? rank : 1, sizeof(unsigned long long));
    double count = 1.0;
    for (NSUInteger i = 0; i < axes.count; i++) {
        NSUInteger axis = (NSUInteger)axes[i].integerValue;
        dropped[axis] = 1;
        count *= (double)shape[axis].unsignedIntegerValue;
    }
    // Each kept axis's own stride in the result, which is the product of the kept extents after it.
    {
        unsigned long long running = 1;
        for (NSUInteger axis = rank; axis-- > 0;) {
            if (!dropped[axis]) {
                stride[axis] = running;
                running *= (unsigned long long)shape[axis].unsignedIntegerValue;
            }
        }
    }

    // Everything the walk needs to know about the operation is in these three, and none of them is a
    // name of any release's framework: whether a NaN latches (the two propagating extremes of 14.0, and
    // nothing else in the family), whether the answer is an index rather than a value (the two argument
    // reductions of 15.0), and which fold to run.
    int propagates = [parameters[@"propagateNaN"] boolValue];
    int isIndex = [parameters[@"index"] boolValue];

    if (isIndex) {
        // THE ARGUMENT REDUCTIONS. What is measured, over the sixteen classes of the arithmetic cases in
        // this file and over rows chosen for their ties, in float32, float16 and int32 alike:
        //
        //  - the answer is the index of the FIRST element holding the extreme, so a row of (4, 4, 4, 9)
        //    answers 3 for a maximum and a row of (9, 9, 1, 1) answers 0 and 2, and a comparison that
        //    replaced on equality would answer the last of them.
        //  - a NaN loses every comparison and so is never the answer, wherever it sits: (nan, 1, 2, 3)
        //    answers 3 for a maximum and 1 for a minimum, (1, 2, 3, nan) answers 2 and 0, and a row of
        //    nine with a NaN at either end answers 8 and 7 for a maximum.
        //  - a reduced set of nothing but NaNs answers -1 in both, which is the "nothing was found"
        //    answer rather than an index into an empty set.
        //  - the result is stored as MPSDataTypeInt32 whatever the operand's own type is, and the two
        //    signed zeros compare equal, so (0, -0, 0, -0) answers 0 for both.
        //
        // The held extreme is kept beside the result rather than read back out of it, because the result
        // holds an index rather than a value and the comparison needs the value it belongs to.
        double *held = calloc(resultCount, sizeof(double));
        long *found = calloc(resultCount, sizeof(long));
        // The axis whose coordinate an index is a coordinate of: the argument reductions of 15.0 take one
        // axis, which is what the release's own methods hand over, so there is one to read.
        NSUInteger reducedAxis = (NSUInteger)axes.firstObject.integerValue;
        for (NSUInteger i = 0; i < resultCount; i++)
            found[i] = -1;
        for (NSUInteger i = 0; i < sourceCount; i++) {
            NSUInteger index = CharonMPSGraphReductionIndex(shape, dropped, stride, i);
            if (index >= resultCount)
                continue;
            double value = CharonMPSLoad(in, type, i);
            if (isnan(value))
                continue;
            if (found[index] < 0 || (fold->isLesser ? value < held[index] : value > held[index])) {
                found[index] = CharonMPSGraphCoordinate(shape, reducedAxis, i);
                held[index] = value;
            }
        }
        for (NSUInteger i = 0; i < resultCount; i++)
            CharonMPSStoreRounded(out, resultType, i, (double)found[i], 1);
        free(found);
        free(held);
        free(stride);
        free(dropped);
        return;
    }

    // What each fold starts from, and this is measured rather than reasoned: the seeds are the table's
    // own, and the two extremes' infinities are what says what a reduced set of nothing but NaNs answers
    // last: measured on this host's own MPSGraph over a 2x4 whose eight elements are all NaN, over the
    // sixteen classes of the arithmetic cases in this file, reductionMaximumWithTensor:axis:1 answers
    // (0xff800000, 0xff800000) - negative infinity of each - and reductionMinimumWithTensor:axis:1 answers
    // (0x7f800000, 0x7f800000). So the kernel seeds an infinity and lets a comparison decide the rest,
    // and a NaN loses every comparison and is therefore skipped: a maximum over a row of (1, NaN, 3, 4)
    // answers 4, measured, and one over a row of nothing but NaNs answers what it was seeded with.
    //
    // The buffer is written before the walk rather than read from: a sum that began from whatever the
    // result buffer happened to hold would answer that plus the sum, which is how this port answered
    // 3 for a sum of 11 until the seed was measured.
    memset(out, 0, resultCount * resultSize);
    // The seed is written wherever it is not the zero the buffer was just cleared to, which is the
    // product's one, the two extremes' infinities and the two truth folds' identities. A sum's zero, the
    // mean's and the variance's are what the clearing already wrote.
    if (fold->multiplies || fold->isExtreme || fold->isTruth)
        for (NSUInteger i = 0; i < resultCount; i++)
            CharonMPSStoreRounded(out, resultType, i, fold->seed, 1);
    for (NSUInteger i = 0; i < sourceCount; i++) {
        NSUInteger index = CharonMPSGraphReductionIndex(shape, dropped, stride, i);
        if (index >= resultCount)
            continue;
        double value = CharonMPSLoad(in, type, i);
        double held = CharonMPSLoad(out, resultType, index);
        CharonMPSStoreRounded(out, resultType, index, CharonMPSGraphFoldStep(fold, held, value, propagates, 0), 1);
    }
    if (fold->divides) {
        // The mean of the reduced set. Where it came from is the only difference between the two
        // variance forms and none at all for the mean: the sum above is already in the result buffer, so
        // the mean is that over the count, written back through the type so that an integer mean is the
        // truncated quotient - measured on this host's own MPSGraph, the mean of (-3, -2, -1, 0) as int32
        // is -1 and not -2, and the mean of (1, 2, 3, 4) as float16 is 0x4100 = 2.5.
        // It goes into a buffer of its own rather than into the result, because the variance needs it
        // again after the sum is no longer there.
        int isVariance = strcmp(fold->combination, "variance") == 0;
        unsigned char *mean = meanGiven ? (unsigned char *)[meanGiven charon_mps_bytes]
                                        : malloc(resultCount * resultSize);
        if (!meanGiven) {
            for (NSUInteger i = 0; i < resultCount; i++)
                CharonMPSStoreRounded(mean, resultType, i, CharonMPSLoad(out, resultType, i) / count, 1);
        }
        MPSDataType meanType = meanGiven ? meanGiven.dataType : resultType;
        if (isVariance) {
            // The mean of the squared deviations, taken about that mean: a second walk over the operand,
            // because a result element's mean is only known once the first has been through every axis of
            // the element it belongs to.
            memset(out, 0, resultCount * resultSize);
            for (NSUInteger i = 0; i < sourceCount; i++) {
                NSUInteger index = CharonMPSGraphReductionIndex(shape, dropped, stride, i);
                if (index >= resultCount)
                    continue;
                double deviation = CharonMPSLoad(in, type, i) - CharonMPSLoad(mean, meanType, index);
                CharonMPSStoreRounded(out, resultType, index,
                                      CharonMPSLoad(out, resultType, index) + deviation * deviation, 1);
            }
            // Over the count, written back through the type, as the mean is: the variance is a mean of
            // the squared deviations and not their sum. Measured on this host's own MPSGraph, the
            // variance of a row of (1, 2, 3, 4) is 0x3fa00000 = 1.25 and the sum of the squares about the
            // mean is five times that.
            for (NSUInteger i = 0; i < resultCount; i++)
                CharonMPSStoreRounded(out, resultType, i, CharonMPSLoad(out, resultType, i) / count, 1);
        }
        // The mean itself is the result of the mean; for the variance the result is what the second walk
        // above wrote, and copying the mean over it would answer the mean for a variance.
        if (!isVariance)
            for (NSUInteger i = 0; i < resultCount; i++)
                CharonMPSStoreRounded(out, resultType, i, CharonMPSLoad(mean, meanType, i), 1);
        if (!meanGiven)
            free(mean);
    }
    free(stride);
    free(dropped);
}

// THE CUMULATIVE FAMILY, which is the fold above walked along an axis instead of across a set: the result
// is the operand's own shape, and each element holds a fold of the elements on one side of it. Everything
// the walk needs is in the operation's parameters - which fold, which axis, which way, and whether an
// element is in its own answer - so 16.0's sixteen methods share this one walk and name none of it.
//
// The rule is one sentence and every part of it is measured on this host's own MPSGraph over rows of
// ordinary values, over rows chosen for their ties, over the sixteen classes and over a row of nothing but
// NaNs, in float32, int32 and float16 alike:
//
//   the accumulator is the result buffer and starts at the fold's own seed, the walk goes along the axis in
//   the direction the flag says, and at each position the element is folded into the answer BEFORE that
//   answer is written - unless the answer is exclusive, in which case the answer is written first and the
//   element is folded into the position after it.
//
// Measured over the 2x4 of (1, 2, 3, 4 | 10, 20, 30, 40), axis 1: a cumulative sum answers
// (1, 3, 6, 10 | 10, 30, 60, 100), a reverse one (10, 9, 7, 4 | 100, 90, 70, 40) and an exclusive reverse one
// (9, 7, 4, 0 | 90, 70, 40, 0); a cumulative product answers (1, 2, 6, 24 | 10, 200, 6000, 240000) and a
// reverse one (24, 24, 12, 4 | 240000, 24000, 1200, 40), which is the same rule and not a second one; a
// cumulative maximum is the row itself, (1, 2, 3, 4 | 10, 20, 30, 40), and an exclusive reverse maximum is
// (4, 4, 4, -inf | 40, 40, 40, -inf) - the seed where the walk starts, and the mirror of a forward
// exclusive maximum's (-inf, 1, 2, 3). A negative axis is the axis counted from the end, measured: axis:-1
// answers what axis:1 answers.
//
// A NaN loses every comparison and is skipped, as in the reduction family, so the position whose whole side
// of the walk is NaN answers the seed: measured over a row of (1, 2, 3, NaN), a reverse exclusive maximum
// answers (3, 3, -inf, -inf) and a reverse exclusive minimum (2, 3, +inf, +inf), and a forward exclusive
// maximum over the same row answers (-inf, 1, 2, 3). The accumulator is the result's own storage, so every
// partial answer is the value that type can hold: measured, the cumulative sum of (1, 2, 3, 4) in float16
// is 0x4900 = 10 and the cumulative product of four halves of 65504 is an infinity from the second step.
// The seed a scan of the two extremes starts from, and it is NOT the reduction family's infinity: measured,
// an exclusive cumulative maximum of a 2x4 answers 0xff7fffff at the position the walk starts and an
// exclusive cumulative minimum answers 0x7f7fffff there, in float32; in float16 they are 0xfbff and 0x7bff,
// the largest finite half of each sign, and in int32 they are INT32_MIN and INT32_MAX. So the seed is the
// type's own extreme FINITE value - the identity of a comparison over the values that type can hold - while
// the reduction family of 14.0 seeds an infinity, which is a different kernel and a different measurement and
// is left as it is. A sum's seed is the zero of the type and a product's its one, in every type measured.
static double CharonMPSGraphScanSeed(const CharonMPSGraphFold *fold, MPSDataType type)
{
    if (!fold->isExtreme)
        return fold->seed;
    double magnitude = 0.0;
    switch (type) {
    case MPSDataTypeFloat32:
        magnitude = (double)FLT_MAX;
        break;
    case MPSDataTypeFloat16:
        magnitude = 65504.0;          // 0x7bff, the largest finite half
        break;
    case MPSDataTypeInt8:
        magnitude = fold->isLesser ? 127.0 : 128.0;
        break;
    case MPSDataTypeInt16:
        magnitude = fold->isLesser ? 32767.0 : 32768.0;
        break;
    case MPSDataTypeInt32:
        magnitude = fold->isLesser ? 2147483647.0 : 2147483648.0;
        break;
    case MPSDataTypeInt64:
        magnitude = fold->isLesser ? 9223372036854775807.0 : 9223372036854775808.0;
        break;
    case MPSDataTypeUInt8:
        magnitude = 255.0;
        break;
    case MPSDataTypeUInt16:
        magnitude = 65535.0;
        break;
    case MPSDataTypeUInt32:
        magnitude = 4294967295.0;
        break;
    case MPSDataTypeUInt64:
        magnitude = 18446744073709551615.0;
        break;
    default:
        // A boolean has no ordering to seed: it is the same answer whatever the walk starts from, and the
        // zero is the false that a fold of nothing over it is.
        magnitude = 1.0;
        break;
    }
    return fold->isLesser ? magnitude : -magnitude;
}

static void CharonMPSGraphScan(MPSGraphOperation *operation, MPSGraphTensorData *source,
                               MPSGraphTensorData *axisData, MPSGraphTensorData *result)
{
    NSDictionary *parameters = operation.charon_mps_parameters;
    const CharonMPSGraphFold *fold = CharonMPSGraphFoldNamed([parameters[@"scanCombination"] UTF8String]);
    NSArray<NSNumber *> *shape = source.shape;
    NSUInteger rank = shape.count;
    NSUInteger count = rank ? [source charon_mps_elementCount] : 0;
    if (fold == NULL || count == 0)
        return;
    MPSDataType type = source.dataType;
    MPSDataType resultType = result.dataType;
    void *in = [source charon_mps_bytes];
    void *out = [result charon_mps_bytes];

    // The axis is the caller's or the feed's, and both go through the same normalisation: negative counted
    // from the end, and an axis outside the rank refused. The refusal is the same one the reduction family
    // raises when its graph is built - the release destroys the process over one (MPSGraphNDArrayScan.mm:253
    // asserts "This class only supports axis = 0, 1, 2, 3" and the process is gone), so this is the one form
    // of "this graph cannot run" a caller can handle. A fed axis is only known here, at run time.
    NSInteger axis;
    if (parameters[@"scanAxisTensor"]) {
        if (axisData == nil || ![axisData isKindOfClass:[MPSGraphTensorData class]]) {
            CharonMPSGraphRefuse(@"MPSGraph: the cumulative operation named %@ was fed no value for its "
                                 @"axis, so nothing was written to its output", [operation name]);
            return;
        }
        NSInteger fed = (NSInteger)CharonMPSLoad([axisData charon_mps_bytes], axisData.dataType, 0);
        axis = fed < 0 ? fed + (NSInteger)rank : fed;
        if (axis < 0 || axis >= (NSInteger)rank) {
            [NSException raise:NSInvalidArgumentException
                        format:@"MPSGraph: %@ was fed an axis of %ld for a rank-%lu tensor, and axis 0 to "
                               @"%lu is all it has",
                                [operation name], (long)fed, (unsigned long)rank, (unsigned long)rank];
        }
    } else {
        axis = [parameters[@"scanAxis"] integerValue];
    }
    int exclusive = [parameters[@"scanExclusive"] boolValue];
    int reverse = [parameters[@"scanReverse"] boolValue];

    // Each axis's own stride in the operand's layout, which is the result's layout too, and the extent of
    // the one being walked. A position of the scan axis is a whole run of the other axes, so the walk is
    // over the positions and each position owns one element per run - a lane - and the lanes are walked one
    // after another, which is what makes the whole of this O(elements) rather than O(elements * positions).
    unsigned long long *stride = calloc(rank, sizeof(unsigned long long));
    unsigned long long extent = 1;
    {
        unsigned long long running = 1;
        for (NSUInteger i = rank; i-- > 0;) {
            stride[i] = running;
            running *= (unsigned long long)shape[i].unsignedIntegerValue;
            if ((NSInteger)i == axis)
                extent = (unsigned long long)shape[i].unsignedIntegerValue;
        }
    }
    unsigned long long laneStride = stride[axis];
    double seed = CharonMPSGraphScanSeed(fold, type);
    for (NSUInteger base = 0; base < count; base++) {
        if (CharonMPSGraphCoordinate(shape, (NSUInteger)axis, base) != 0)
            continue;                       // one lane: the elements whose axis coordinate is zero
        double accumulator = seed;
        for (unsigned long long step = 0; step < extent; step++) {
            unsigned long long at = reverse ? extent - 1 - step : step;
            NSUInteger here = base + (NSUInteger)(at * laneStride);
            double value = CharonMPSLoad(in, type, here);
            // The element at this position joins the answer before the answer is written, unless the answer
            // is exclusive - and either way the answer goes out through the result's own type and is read
            // back from it, so the accumulator is that type and not a wider one.
            if (!exclusive)
                accumulator = CharonMPSGraphFoldStep(fold, accumulator, value, 0, 1);
            CharonMPSStoreRounded(out, resultType, here, accumulator, 1);
            accumulator = CharonMPSLoad(out, resultType, here);
            if (exclusive)
                accumulator = CharonMPSGraphFoldStep(fold, accumulator, value, 0, 1);
        }
    }
    free(stride);
}

// The integers out of a fed tensor of any integer type, which is how a flatten's axis, a reverse's axes, a
// broadcast's shape and a squeeze's or an expanded dimension's axes arrive when the caller fed them rather
// than writing them down. How many of them there are is the fed tensor's own element count, so nothing has to
// carry the count as well, and nil for no fed tensor at all is what tells the plan the parameter has not
// arrived yet.
static NSMutableArray<NSNumber *> *CharonMPSGraphGatherIntegers(MPSGraphTensorData *parameter)
{
    if (parameter == nil)
        return nil;
    NSUInteger count = CharonMPSGraphElementCount(parameter.shape);
    NSMutableArray<NSNumber *> *values = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger i = 0; i < count; i++)
        [values addObject:@((NSInteger)CharonMPSLoad([parameter charon_mps_bytes], parameter.dataType, i))];
    return values;
}

// THE GATHER FAMILY: the operations whose result is the operand's elements in some other order or some other
// extent. Every one of them is one walk here, because every one of them is the same question - for each axis
// of the result, which axis of the operand feeds it, how many of the operand's axes it covers, and whether
// that one is reversed, and whether the coordinate has an element of the operand behind it at all - and the
// operation's parameters are the answer. This function is the plan: the result's shape and that mapping,
// both derived from the transformation the operation names, and asked both when the graph is built (through
// -[MPSGraph charon_mps_gatherShapeOfTensor:parameters:named:], so that a caller can read the result's shape
// off the tensor) and when the operation runs (where a parameter the caller fed can be read).
//
// Every rule is measured on this host's own MPSGraph over a 2x4 of (1, 2, 3, 4 | 10, 20, 30, 40):
//
//   - a transpose is the row-major transpose, in both forms: (1, 10, 2, 20, 3, 30, 4, 40) into a 4x2, and a
//     negative axis is counted from the end, so `dimension:-1 withDimension:0` answers what
//     `dimension:0 withDimension:1` answers. The two-axis form keeps the operand's RANK at a rank above two
//     - measured, `dimension:0 withDimension:2` of a 2x3x4 answers a 4x3x2 and `dimension:0 withDimension:0`
//     answers the operand itself - and the permutation form must have one entry per axis of the operand,
//     measured: a shorter one is refused by the release's own compiler ("perm tensor length must equal input
//     tensor rank, 1 != 3").
//   - a squeeze drops the unit axes it is given - every unit axis when it is given none - and an expanded
//     dimension adds an axis of extent one, whose negative axis is counted from the end AND MAY BE THE RANK
//     ITSELF (measured: axis -1 of a 2x4 is the trailing unit axis of a 2x4x1). All three answer the
//     operand's own bytes in the operand's own order, which is what makes them one gather with the axes left
//     alone: a 1x2x4 squeezed is a 2x4 of the same bytes, a 2x4 expanded at axis 0 is a 1x2x4 of the same
//     bytes, and a 2x3x4 flattened at axis 0 is a 1x24 of them.
//   - a reshape is the same walk with the axes left alone and the result's shape the caller's: a 2x4 into a
//     4x2 answers (1, 2, 3, 4, 10, 20, 30, 40) and a 2x4 into a 1x8 the operand's own eight values, neither of
//     which moves an element, and a dynamic extent (the header's -1) is the element count over the product of
//     the extents written down (measured: a 2x4 into @[@4, -1] answers a 4x2).
//   - a flatten collapses every axis from its axis on into one.
//   - a broadcast aligns the operand to the RIGHT of the shape given, takes the LARGER of the two extents on
//     every axis they share (measured: a 2x4 into a 4x4 answers a 4x4 and a 2x4 into a 1x4 answers the 2x4
//     itself), repeats the whole operand for each axis the shape adds at the front (measured: a 2x4 into a
//     2x2x4 answers the 2x4 twice) and DOES NOT WRAP: past the operand's own extent the result is a zero,
//     measured over a destination filled with a pattern, where a 2x4 into a 4x4 answers (1, 2, 3, 4, 10, 20,
//     30, 40) and then eight zeros rather than the pattern and rather than the row twice.
//   - a reverse flips the axes it is given and nothing else, counting a negative axis from the end (measured:
//     axes @[@-1] answers what axes @[@1] answers) and taking no axes at all as every axis.
//
// An axis or an extent the release refuses is refused here too, with NSInvalidArgumentException: a squeeze of
// an axis whose extent is not one is a graph it cannot build (measured: "squeezed axis must have length 1,
// input.shape[1] == 2", then "LLVM ERROR: Failed to infer result type(s)" takes the process down), an axis or
// a permutation outside the rank is the same refusal the reduction family raises (measured for the reverse:
// "invalid axis: 5, axis must be in range - rank <= axis < rank, rank = 2"), and an extent of zero is a shape
// with no elements in it.
//
// Two questions this function is asked twice, and both are the same code: the factory asks it when the graph
// is built so that the result tensor carries its shape before anything runs - which is what the release does,
// since it infers the result's type at build time and aborts there over an axis it cannot use - and the
// interpreter asks it when the operation runs, which is the only time a FED parameter can be read. A fed
// parameter, and an operand whose own shape is not known yet (a gather of a fed gather), give nil here, and
// the interpreter puts the shape on when it walks the operation.
//
// `fed` is one entry per parameter the caller fed rather than wrote down, in the order the operation's own
// inputs carry them after the ones the walk reads as the operand: the gathers above take one (an axis, a set
// of axes, a shape), and the slice family takes up to three (the starts, the ends or the sizes, and the
// strides), which is why it is a list and not a single array. Its first entry is what the branches above read
// as the fed parameter, so they are unchanged by it.
static NSDictionary *CharonMPSGraphGatherPlan(NSString *name, NSArray<NSNumber *> *sourceShape,
                                              NSDictionary *parameters,
                                              NSArray<NSArray<NSNumber *> *> *fed)
{
    const char *gather = [parameters[@"gather"] UTF8String];
    NSUInteger sourceRank = sourceShape.count;
    NSArray<NSNumber *> *fedOne = fed.firstObject;

    if (fed == nil && (parameters[@"gatherOperand"] != nil || sourceShape == nil))
        return nil;

    NSMutableArray<NSNumber *> *shape = [NSMutableArray array];
    NSMutableArray<NSNumber *> *sourceAxes = [NSMutableArray array];
    NSMutableArray<NSNumber *> *sourceCounts = [NSMutableArray array];
    NSMutableArray<NSNumber *> *reversed = [NSMutableArray array];

    if (gather == NULL || sourceRank == 0) {
        CharonMPSGraphRefuse(@"MPSGraph: the operation named %@ asked for a gather this interpreter does not "
                             @"know, so nothing was written to its output", name);
        return nil;
    }
    if (strcmp(gather, "squeeze") == 0 || strcmp(gather, "expand") == 0) {
        // The squeeze and the expanded dimension, which are the same gather with the axes left alone - every
        // one of the seven methods of 15.4 answers the operand's own bytes in the operand's own order. What
        // differs between them is which axes are dropped and which are added, and the factory is what knows
        // that: it names them in @gatherDrop and @gatherAdd, or says with @gatherOperand that the caller fed
        // them and they are read out of the operation's second input here.
        int expanding = strcmp(gather, "expand") == 0;
        NSArray<NSNumber *> *declared = [parameters[@"gatherOperand"] isEqual:@"axes"] ? fedOne
            : (expanding ? parameters[@"gatherAdd"] : parameters[@"gatherDrop"]);
        NSMutableIndexSet *named = [NSMutableIndexSet indexSet];
        for (NSNumber *axis in declared) {
            NSInteger where = axis.integerValue;
            // An expanded dimension's negative axis is counted from the end and MAY BE THE RANK ITSELF -
            // measured, axis -1 of a 2x4 is the trailing unit axis of a 2x4x1 - so its count from the end is
            // one past the last axis, while a squeeze drops an axis that is there and its count is the rank.
            if (where < 0)
                where += (NSInteger)sourceRank + (expanding ? 1 : 0);
            if (where < 0 || (NSUInteger)where > sourceRank || (!expanding && (NSUInteger)where >= sourceRank)) {
                [NSException raise:NSInvalidArgumentException
                            format:@"MPSGraph: %@ was asked to %@ axis %ld of a rank-%lu tensor, and %@",
                                name, expanding ? @"expand" : @"squeeze", (long)axis.integerValue,
                                (unsigned long)sourceRank,
                                expanding ? @"axis 0 to the rank is all it has"
                                          : @"only an axis of extent one can be squeezed"];
            }
            if (!expanding && sourceShape[(NSUInteger)where].integerValue != 1) {
                [NSException raise:NSInvalidArgumentException
                            format:@"MPSGraph: %@ was asked to squeeze axis %ld of a %s tensor, and only an "
                                   @"axis of extent one can be squeezed",
                                name, (long)axis.integerValue,
                                [[sourceShape componentsJoinedByString:@"x"] UTF8String]];
            }
            [named addIndex:(NSUInteger)where];
        }
        if (expanding) {
            // An axis of extent one goes AT EACH INDEX NAMED, so the result's axis at a position is the
            // operand's axis there unless that index was named - measured, axes @[@0, @2] of a 2x4 answers a
            // 1x2x1x4 and @[@0, @1] a 1x1x2x4, where adding one axis and then the next into the result of the
            // last would answer a 1x2x4x1 and a 1x1x2x4. The operand's own axis of a result axis is therefore
            // its position less the number of named indices before it, and an index past the last of the
            // operand's is the trailing axis of the release's own answer.
            NSUInteger added = 0;
            for (NSUInteger index = 0; index <= sourceRank; index++)
                if ([named containsIndex:index])
                    added++;
            for (NSUInteger position = 0; position < sourceRank + added; position++) {
                if ([named containsIndex:position]) {
                    [shape addObject:@1];
                    [sourceAxes addObject:@0];
                    [sourceCounts addObject:@0];
                    [reversed addObject:@0];
                    continue;
                }
                NSUInteger before = 0;
                for (NSUInteger index = 0; index < position; index++)
                    if ([named containsIndex:index])
                        before++;
                [shape addObject:sourceShape[position - before]];
                [sourceAxes addObject:@(position - before)];
                [sourceCounts addObject:@1];
                [reversed addObject:@0];
            }
        } else {
            // Every axis the caller did not name is kept, in order, and the extents are the operand's own.
            for (NSUInteger position = 0; position < sourceRank; position++) {
                if ([named containsIndex:position])
                    continue;
                [shape addObject:sourceShape[position]];
                [sourceAxes addObject:@(position)];
                [sourceCounts addObject:@1];
                [reversed addObject:@0];
            }
        }
    } else if (strcmp(gather, "flatten") == 0) {
        // A flatten's axis is NOT normalised the way the family's other axes are, and that is measured: the
        // release takes it as the unsigned number it is given, so axis:-1 of a 2x4 is a dimension length of
        // 4294967295 and the framework refuses it outright ("Error: NDArray dimension length > INT_MAX",
        // MPSNDArray.mm:831) and takes the process down. An expanded dimension and a transpose do count a
        // negative axis from the end - measured, both answer - so the rule is this operation's and not the
        // family's, and it is here rather than in a shared normaliser.
        NSInteger axis = [parameters[@"gatherOperand"] isEqual:@"axis"]
            ? (NSInteger)fedOne.firstObject.integerValue
            : [parameters[@"gatherAxis"] integerValue];
        if (axis < 0 || (NSUInteger)axis >= sourceRank) {
            [NSException raise:NSInvalidArgumentException
                        format:@"MPSGraph: %@ was asked to flatten at axis %ld of a rank-%lu tensor, and axis 0 "
                               @"to %lu is all it has: the release takes that axis as the unsigned number it "
                               @"is given, so a negative one is a dimension length past what it can build",
                                name, (long)axis, (unsigned long)sourceRank, (unsigned long)sourceRank];
        }
        // The result is of rank TWO, which is what the method's own name says and what the release answers:
        // measured, axis 0 of a 2x4 is a 1x8, axis 1 of a 2x3x4 is a 2x12 and axis 2 of a 2x3x4 is a 6x4 - so
        // the extents before the axis named collapse into one axis of their product and the rest into
        // another. The elements are the operand's own in order whichever way that is spelled, because the
        // product of the extents is a collapse in the operand's own row-major order, which is why only the
        // shape line of such a case can see it.
        NSUInteger from = (NSUInteger)axis;
        unsigned long long after = 1, before = 1;
        for (NSUInteger i = from; i < sourceRank; i++)
            after *= (unsigned long long)sourceShape[i].unsignedIntegerValue;
        for (NSUInteger i = 0; i < from; i++)
            before *= (unsigned long long)sourceShape[i].unsignedIntegerValue;
        [shape addObject:@(before)];
        [sourceAxes addObject:@0];
        [sourceCounts addObject:@(from)];
        [reversed addObject:@0];
        [shape addObject:@(after)];
        [sourceAxes addObject:@(from)];
        [sourceCounts addObject:@(sourceRank - from)];
        [reversed addObject:@0];
    } else if (strcmp(gather, "broadcast") == 0) {
        NSArray<NSNumber *> *declared = [parameters[@"gatherOperand"] isEqual:@"shape"] ? fedOne
                                                                                      : parameters[@"gatherShape"];
        for (NSUInteger k = 0; k < declared.count; k++) {
            NSInteger extent = declared[k].integerValue;
            if (extent < 1) {
                [NSException raise:NSInvalidArgumentException
                            format:@"MPSGraph: %@ was asked to broadcast into a shape holding %ld, and every "
                                   @"extent of a shape is one or more", name, (long)extent];
            }
            // The operand aligns to the right of the shape, so axis k of the result reads axis k - (the
            // difference in ranks) of the operand, and an axis the shape adds at the front repeats the whole
            // operand and so covers none of its axes. The extent is the LARGER of the two: the release takes
            // the operand's own extent where the shape asks for less (measured, a 2x4 into a 1x4 answers the
            // 2x4 itself) and the shape's where it asks for more.
            NSInteger which = (NSInteger)k - ((NSInteger)declared.count - (NSInteger)sourceRank);
            NSUInteger axis = which < 0 ? 0 : (NSUInteger)which;
            if (axis < sourceRank &&
                sourceShape[axis].unsignedIntegerValue > (NSUInteger)extent)
                extent = sourceShape[axis].integerValue;
            [shape addObject:@(extent)];
            [sourceAxes addObject:@(axis)];
            [sourceCounts addObject:@(which < 0 ? 0 : 1)];
            [reversed addObject:@0];
        }
    } else if (strcmp(gather, "reverse") == 0) {
        NSMutableIndexSet *flipped = [NSMutableIndexSet indexSet];
        NSArray<NSNumber *> *named = [parameters[@"gatherOperand"] isEqual:@"axes"] ? fedOne
                                                                                  : parameters[@"gatherAxes"];
        if (named.count)
            for (NSNumber *axis in named) {
                // A negative axis is counted from the end here as it is everywhere else in this family except
                // the flatten, and an axis outside the rank is the refusal the release's own compiler gives:
                // "invalid axis: 5, axis must be in range - rank <= axis < rank, rank = 2".
                NSInteger where = axis.integerValue;
                if (where < 0)
                    where += (NSInteger)sourceRank;
                if (where < 0 || (NSUInteger)where >= sourceRank) {
                    [NSException raise:NSInvalidArgumentException
                                format:@"MPSGraph: %@ was asked to reverse axis %ld of a rank-%lu tensor, and "
                                       @"axis 0 to %lu is all it has", name, (long)axis.integerValue,
                                        (unsigned long)sourceRank, (unsigned long)sourceRank];
                }
                [flipped addIndex:(NSUInteger)where];
            }
        else
            for (NSUInteger i = 0; i < sourceRank; i++)
                [flipped addIndex:i];
        for (NSUInteger i = 0; i < sourceRank; i++) {
            [shape addObject:sourceShape[i]];
            [sourceAxes addObject:@(i)];
            [sourceCounts addObject:@1];
            [reversed addObject:([flipped containsIndex:i] ? @YES : @NO)];
        }
    } else if (strcmp(gather, "slice") == 0 || strcmp(gather, "sliceGradient") == 0
               || strcmp(gather, "sliceUpdate") == 0) {
        // THE SLICE FAMILY, which is one piece of arithmetic in three directions. What all three share is the
        // per-axis region: a start, an end (or a size), a stride and a count, with the three masks applied.
        // The header's two plain forms are the same region too - `sliceTensor:dimension:start:length:name:` is
        // one axis with a length (a stride of one and an end of start + length) and the strided form is every
        // axis at once with TensorFlow's strided-slice semantics, which is what the header says it is based on.
        //
        // A NEGATIVE start, end or stride counts from the end of that axis, measured: axis 1 of a 2x4 sliced
        // from -2 with a length of two answers (3, 4) and a stride of -1 from the end answers the row the
        // other way round. The count of the axis is how many steps of the stride from the start reach the end,
        // and a result coordinate with no element of the operand behind it is a zero, as it is for a broadcast
        // (measured over a destination filled with a pattern).
        //
        // THE THREE MASKS, each measured on this host's own MPSGraph over a 2x4 of (1, 2, 3, 4 | 10, 20, 30, 40):
        //
        //   - startMask: the start written down is NOT read, and the axis starts at ZERO. A start of 5 and a
        //     start of -3 both answer what a start of 0 answers, and a start of 9 with an end of 0 - which is
        //     then before the start - answers a result of no elements, which the release builds and then
        //     cannot make an NDArray for ("device may not be nil", MPSNDArray.mm:759).
        //   - endMask: the end written down is NOT read either, and the axis runs to its own last element. For
        //     a positive stride the count is therefore the whole of the axis from the start (measured, an
        //     endMask over axis 1 from a start of 1 answers three elements, 2, 3 and 4, and a written end of
        //     -9 answers the same three), and for a NEGATIVE stride the end is the one before the axis begins,
        //     so the count reaches index 0 (measured, an endMask over axis 1 with a stride of -1 from 3
        //     answers four elements, 4, 3, 2 and 1).
        //   - squeezeMask: the axis is dropped from the RESULT's shape whatever its extent, and the elements
        //     are the mapped walk's own in order, so a result of fewer axes holds the first of them. Measured:
        //     axis 0 of a 2x4 with its bit set answers a rank of one holding (1, 2, 3, 4); with two rows
        //     selected it answers the same rank of one over the same four values; and both axes together
        //     answer a rank of zero holding the first element. That is why the plan keeps the full shape of the
        //     walk as well as the shape of the result, and why the walk writes into the first of the one into
        //     the other.
        NSArray<NSNumber *> *starts = parameters[@"sliceStarts"];
        NSArray<NSNumber *> *ends = parameters[@"sliceEnds"];
        NSArray<NSNumber *> *strides = parameters[@"sliceStrides"];
        NSUInteger startMask = [parameters[@"sliceStartMask"] unsignedIntegerValue];
        NSUInteger endMask = [parameters[@"sliceEndMask"] unsignedIntegerValue];
        NSUInteger squeezeMask = [parameters[@"sliceSqueezeMask"] unsignedIntegerValue];
        BOOL sizes = [parameters[@"sliceSizes"] boolValue];
        // The rank the region is over. For the slice it is the operand's own rank, and for the gradient and
        // the update it is the rank of the tensor the region selects elements OF - the forward input for the
        // gradient, the data tensor for the update - which is not the rank of the gradient or of the update:
        // those have the shape of the REGION, and the release refuses a gradient or an update whose shape is
        // not it (measured: a gradient of a shape that is not the region's writes one element and nothing
        // else, and an update that is wider than the region is refused by its own compiler).
        NSArray<NSNumber *> *regionShape = sourceShape;
        NSUInteger fedFrom = [parameters[@"sliceFedFrom"] unsignedIntegerValue];
        if (fedFrom != 0) {
            // The caller fed the parameters instead of writing them down, and they are the operation's own
            // inputs from `fedFrom` on: the starts, then the ends or the sizes, then the strides. A shape
            // that is fed is one the release cannot build a graph over at all (measured: the fed slice of
            // 18.2 dies in its own NDArray whatever the fed tensor is made of), so the plan cannot be
            // derived here at build time, and the refusal those rows carry is the named divergence; the port
            // reads the fed values when the graph runs and answers the header.
            NSUInteger wanted = 3 - (sizes ? 1 : 0);
            if (fed.count < wanted)
                return nil;
            starts = fed[0];
            ends = fed[1];
            strides = wanted > 2 ? fed[2] : nil;
            // A stride is not fed by the SIZE form at all - a size is a count along the axis - so the region
            // of that axis is the size from the start, one pace at a time.
            if (sizes)
                strides = nil;
        }
        if (strcmp(gather, "sliceGradient") == 0) {
            // The gradient's result is a tensor of the shape the forward pass's INPUT had, which arrives as
            // the operation's second input. Where that tensor is a CONSTANT the factory read its value when
            // the graph was built and put it in the parameters, and where it is a feed it is the last of the
            // values read here, when the graph runs - which is the only time the release cannot be asked at
            // all (measured: fed, its result tensor carries no shape and it writes one element).
            NSArray<NSNumber *> *forward = parameters[@"sliceForwardShape"];
            if (forward == nil)
                forward = fed.lastObject;
            if (forward == nil)
                return nil;
            regionShape = forward;
        }
        NSUInteger rank = regionShape.count;
        if (sizes ? (starts.count != rank || ends.count != rank)
                  : (starts.count != rank || ends.count != rank || strides.count != rank)) {
            [NSException raise:NSInvalidArgumentException
                        format:@"MPSGraph: %@ was asked to slice a rank-%lu tensor with %lu starts, %lu %@ and "
                               @"%lu strides, and the release wants one of each per axis", name,
                        (unsigned long)rank, (unsigned long)starts.count, (unsigned long)ends.count,
                        sizes ? @"sizes" : @"ends", (unsigned long)strides.count];
        }
        NSMutableArray<NSNumber *> *counts = [NSMutableArray arrayWithCapacity:rank];
        NSMutableArray<NSNumber *> *offsets = [NSMutableArray arrayWithCapacity:rank];
        NSMutableArray<NSNumber *> *steps = [NSMutableArray arrayWithCapacity:rank];
        for (NSUInteger k = 0; k < rank; k++) {
            NSInteger extentOfSource = regionShape[k].integerValue;
            BOOL maskStart = (startMask >> k & 1) != 0;
            BOOL maskEnd = (endMask >> k & 1) != 0;
            // A size is the count itself, so there is no end to count the steps to and no stride to count
            // them by: the region of that axis is the size from the start, one pace at a time.
            NSInteger step = sizes ? 1 : strides[k].integerValue;
            NSInteger from = maskStart ? 0 : starts[k].integerValue;
            if (from < 0)
                from += extentOfSource;
            if (step == 0) {
                [NSException raise:NSInvalidArgumentException
                            format:@"MPSGraph: %@ was asked to slice axis %lu with a stride of zero, which "
                                   @"never leaves the start", name, (unsigned long)k];
            }
            if (from < 0 || from >= extentOfSource) {
                [NSException raise:NSInvalidArgumentException
                            format:@"MPSGraph: %@ was asked to slice axis %lu from %ld, and the release's own "
                                   @"compiler wants a start value that fits the dimension size %ld", name,
                            (unsigned long)k, (long)starts[k].integerValue, (long)extentOfSource];
            }
            // The simple form is one axis with a LENGTH, the strided form is every axis with an END and the
            // size form is every axis with a SIZE; all three are how many steps of the stride from the start
            // reach it, and the release takes the SMALLER of that and the number of steps the axis's own
            // extent allows - measured, a 2x4 sliced from 2 with an end of 9 answers a 2x2 and not a 2x7.
            NSInteger length = [parameters[@"sliceLength"] integerValue];
            // A masked end is already relative: the axis's own extent for a positive stride, and the one
            // BEFORE the axis begins for a negative one, which is why counting from the end does not apply
            // to it (measured: an endMask with a stride of -1 from 3 answers four elements, 4, 3, 2 and 1).
            NSInteger end = ends[k].integerValue;
            if (maskEnd)
                end = step > 0 ? extentOfSource : -1;
            else if (end < 0)
                end += extentOfSource;
            // The simple form writes the length down and the strided form does not, so the LENGTH's presence
            // is what tells them apart - a length of zero is a form of its own, refused below, and not the
            // strided form's absence of one.
            NSInteger asked = (parameters[@"sliceLength"] != nil && k == [parameters[@"sliceAxis"] unsignedIntegerValue])
                ? length
                : sizes ? ends[k].integerValue
                        : (NSInteger)ceil((double)(end - from) / (double)step);
            NSInteger step_ = step < 0 ? -step : step;
            NSInteger available = step > 0 ? (extentOfSource - from + step_ - 1) / step_
                                            : (from + step_) / step_;
            NSInteger howMany = asked < available ? asked : available;
            if (howMany <= 0) {
                [NSException raise:NSInvalidArgumentException
                            format:@"MPSGraph: %@ was asked to slice axis %lu into a result of no elements, and "
                                   @"the release builds that shape and then cannot make an NDArray for it",
                            name, (unsigned long)k];
            }
            [counts addObject:@(howMany)];
            [offsets addObject:@(from)];
            [steps addObject:@(step)];
        }

        if (strcmp(gather, "sliceGradient") == 0 || strcmp(gather, "sliceUpdate") == 0) {
            // The two directions that SCATTER rather than gather: the result is bigger than what is read into
            // it - the whole forward input for the gradient, the whole data tensor for the update - and what
            // is read is the gradient or the update, whose own shape IS the region's shape. The release
            // refuses the two that differ (measured: an update wider than the region, and an update narrower
            // than it, are both refused by its own compiler, "Optimize Original Module MLIR pass manager
            // failed"; a gradient that is not the region's shape is not refused but writes one element and
            // nothing else, which is the degenerate answer the row names).
            NSArray<NSNumber *> *scattered = parameters[@"sliceScatteredShape"];
            for (NSUInteger k = 0; k < counts.count; k++) {
                if (scattered == nil || scattered.count != counts.count
                    || scattered[k].integerValue != counts[k].integerValue) {
                    [NSException raise:NSInvalidArgumentException
                                format:@"MPSGraph: %@ was asked for a shape of %@ where the region it %@ is of "
                                       @"rank %lu, and the release refuses the two that differ", name,
                                [scattered componentsJoinedByString:@"x"],
                                strcmp(gather, "sliceUpdate") == 0 ? @"writes" : @"is the gradient of",
                                (unsigned long)counts.count];
                }
            }
            // The result is the whole tensor the region selects elements OF, which is the forward input's
            // shape for the gradient and the data tensor's own shape for the update - the first input of each
            // of them, and the same shape in both cases.
            return @{@"shape": regionShape, @"counts": counts, @"offsets": offsets, @"strides": steps,
                     @"scatter": @YES, @"update": @(strcmp(gather, "sliceUpdate") == 0)};
        }

        // The slice itself is a gather, so the mapping is the region's axes one for one, and the axes the
        // squeezeMask names are dropped from the result's shape and not from the walk.
        NSMutableArray<NSNumber *> *mapped = [NSMutableArray arrayWithCapacity:rank];
        NSUInteger dropped = 0;
        for (NSUInteger k = 0; k < rank; k++) {
            [mapped addObject:counts[k]];
            [sourceAxes addObject:@(k)];
            [sourceCounts addObject:@1];
            [reversed addObject:@0];
            if ((squeezeMask >> k & 1) != 0) {
                dropped++;
                continue;
            }
            [shape addObject:counts[k]];
        }
        if (dropped == 0)
            return @{@"shape": shape, @"sourceAxes": sourceAxes, @"sourceCounts": sourceCounts,
                     @"reversed": reversed, @"offsets": offsets, @"strides": steps};
        // A squeezed axis is dropped from the RESULT's shape and not from the walk, which is why the plan
        // carries the shape the walk is over as well: the elements are the walk's own in order, and the
        // result holds as many of them as its own shape asks for.
        return @{@"shape": shape, @"mappedShape": mapped, @"sourceAxes": sourceAxes,
                 @"sourceCounts": sourceCounts, @"reversed": reversed, @"offsets": offsets, @"strides": steps};
    } else if (strcmp(gather, "scatter") == 0) {
        // A SCATTER THE CALLER DESCRIBES DIRECTLY: the result's shape is the tensor the region selects
        // elements OF, and the region is given as an offset and a stride per axis - or as a DIVISOR per axis,
        // which is the tile's gradient, where several copies of one element land on the same element of the
        // result and are summed because the gradient of a sum is a sum. The pad's gradient is the same thing
        // with the left padding as its offset and a stride of one, and the slice's own update is the same walk
        // with a region derived from starts, ends and strides - which is why this branch carries no starts,
        // ends or strides of its own and why nothing here reads one.
        NSArray<NSNumber *> *resultShape = parameters[@"shape"];
        NSUInteger rank = resultShape.count;
        NSArray<NSNumber *> *offsets = parameters[@"offsets"] ?: @[];
        NSArray<NSNumber *> *strides = parameters[@"strides"] ?: @[];
        NSArray<NSNumber *> *divisors = parameters[@"divisors"];
        NSUInteger asked = divisors != nil ? rank : offsets.count;
        if (asked != rank || (divisors == nil && strides.count != rank)) {
            [NSException raise:NSInvalidArgumentException
                        format:@"MPSGraph: %@ was asked to scatter into a rank-%lu tensor with %lu offsets, "
                               @"%lu strides and %lu divisors, and it wants one of each per axis", name,
                        (unsigned long)rank, (unsigned long)offsets.count, (unsigned long)strides.count,
                        (unsigned long)divisors.count];
        }
        // A dictionary literal takes no nil, and the divisors are absent unless the caller sums.
        return @{@"shape": resultShape, @"offsets": offsets, @"strides": strides,
                 @"divisors": divisors ?: @[], @"scatter": @YES,
                 @"update": parameters[@"scatterUpdate"] ?: @NO};
    } else if (strcmp(gather, "tile") == 0) {
        // A TILE is the gather walk with every axis REPEATED: the result's axis k is the operand's axis k at
        // `multiplier[k]` times its extent, and the coordinate of the result counts the operand's own extent
        // over again. Measured over a 2x4 of (1, 2, 3, 4 | 10, 20, 30, 40): a multiplier of (2, 3) answers a
        // 4x12 holding the operand three times over, twice down, and a multiplier of (1, 3) a 2x12 holding it
        // three times across. The multiplier is one entry per axis and a multiplier of one is that axis alone.
        NSArray<NSNumber *> *multiplier = parameters[@"tileMultiplier"];
        if (multiplier.count != sourceRank) {
            [NSException raise:NSInvalidArgumentException
                        format:@"MPSGraph: %@ was asked to tile a rank-%lu tensor with %lu multipliers, and "
                               @"the release wants one per axis", name, (unsigned long)sourceRank,
                        (unsigned long)multiplier.count];
        }
        for (NSUInteger k = 0; k < sourceRank; k++) {
            NSInteger copies = multiplier[k].integerValue;
            if (copies < 1) {
                [NSException raise:NSInvalidArgumentException
                            format:@"MPSGraph: %@ was asked for %ld copies of axis %lu, and a tile makes one "
                                   @"or more of every axis", name, (long)copies, (unsigned long)k];
            }
            [shape addObject:@(sourceShape[k].integerValue * copies)];
            [sourceAxes addObject:@(k)];
            [sourceCounts addObject:@1];
            [reversed addObject:@0];
        }
        return @{@"shape": shape, @"sourceAxes": sourceAxes, @"sourceCounts": sourceCounts,
                 @"reversed": reversed, @"repeat": @YES};
    } else if (strcmp(gather, "pad") == 0) {
        // A PAD is the gather walk with an OFFSET per axis and the elements outside the operand's own extent
        // filled by the padding mode. The inside is exactly the gather: the result's axis k reads the
        // operand's axis k from the left padding, so the offset is the left padding and the stride is one,
        // and every coordinate outside the operand's extent is left for the fill below - which is where the
        // five modes the release answers differ, and the two it refuses never reach.
        NSArray<NSNumber *> *left = parameters[@"padLeft"];
        NSArray<NSNumber *> *right = parameters[@"padRight"];
        if (left.count != sourceRank || right.count != sourceRank) {
            [NSException raise:NSInvalidArgumentException
                        format:@"MPSGraph: %@ was asked to pad a rank-%lu tensor with %lu left and %lu right "
                               @"paddings, and the header wants one of each per axis", name,
                        (unsigned long)sourceRank, (unsigned long)left.count, (unsigned long)right.count];
        }
        for (NSUInteger k = 0; k < sourceRank; k++) {
            NSInteger extent = sourceShape[k].integerValue;
            NSInteger before = left[k].integerValue;
            NSInteger after = right[k].integerValue;
            if (before < 0 || after < 0) {
                [NSException raise:NSInvalidArgumentException
                            format:@"MPSGraph: %@ was asked for %ld elements of padding before axis %lu, and "
                                   @"padding is a count of elements that exists or does not", name,
                            (long)(before < 0 ? before : after), (unsigned long)k];
            }
            // HOW FAR EACH MIRROR REACHES, which is the two modes' own limit and not one number for both.
            // Measured on this host's own MPSGraph at extents one, two and three, on the left and on the
            // right, over every padding from one to five: a REFLECT answers up to the axis LESS ONE and a
            // SYMMETRIC up to the axis ITSELF, and one element more of either is refused by the release's
            // own compiler with its own words - "'mps.pad' op padding values too large at axis 0, max
            // padding is 1, got 3" (MPSGraphUtilities.mm:956), where the maximum it prints is 1 for a
            // reflect on an axis of two and 2 for a symmetric on the same axis. So a symmetric padding
            // equal to the extent answers - measured, a 2x4 of (1, 2, 3, 4 | 10, 20, 30, 40) with a left
            // padding of (2, 0) answers (5, 6, 7, 8 | 1, 2, 3, 4 | 1, 2, 3, 4 | 5, 6, 7, 8) - and refusing
            // it was this seam refusing an answer the release gives.
            NSInteger mode = [parameters[@"padMode"] integerValue];
            NSInteger reach = mode == 1 ? extent - 1 : extent;
            if ((mode == 1 || mode == 2) && (before > reach || after > reach)) {
                [NSException raise:NSInvalidArgumentException
                            format:@"MPSGraph: %@ was asked for %ld elements of %@ padding on axis %lu, which "
                                   @"is %lu long, and the release's mirror reaches %ld there: measured, the "
                                   @"two have their own limits and one element more of either is refused by "
                                   @"the release's compiler",
                              name, (long)(before > reach ? before : after),
                              mode == 1 ? @"reflected" : @"symmetric", (unsigned long)k, (unsigned long)extent,
                              (long)reach];
            }
            [shape addObject:@(extent + before + after)];
            [sourceAxes addObject:@(k)];
            [sourceCounts addObject:@1];
            [reversed addObject:@0];
        }
        NSMutableArray<NSNumber *> *oneEach = [NSMutableArray arrayWithCapacity:sourceRank];
        for (NSUInteger k = 0; k < sourceRank; k++)
            [oneEach addObject:@1];
        // The mode and the caller's constant go into the plan with it, because the fill below is what reads
        // them: which mode it is decides what an element outside the operand's box holds, and for the constant
        // mode that is a number the caller wrote down and not the operand's.
        return @{@"shape": shape, @"sourceAxes": sourceAxes, @"sourceCounts": sourceCounts, @"reversed": reversed,
                 @"offsets": left, @"strides": oneEach,
                 @"padMode": parameters[@"padMode"] ?: @0,
                 @"padConstant": parameters[@"padConstant"] ?: @0};
    } else if (strcmp(gather, "reshape") == 0) {
        // A reshape is the same walk with the axes left alone and the result's shape the caller's: the operand
        // and the result hold the same elements in the same row-major order, so the result's axes consume the
        // operand's in turn - a 2x4 into a 4x2 answers (1, 2, 3, 4, 10, 20, 30, 40) and a 2x4 into a 1x8 the
        // operand's own eight values, and neither moves an element. An axis of the result covers the operand's
        // axes from the first one not yet consumed to the last one that fits inside it, which is the split the
        // walk already does for a flatten's collapse.
        //
        // A DYNAMIC extent, the header's -1, is resolved here: the shape is allowed to hold one when the
        // result type can be inferred unambiguously, so the product of the extents written down divides the
        // operand's element count and the answer is the quotient. Two of them, or a shape whose product does
        // not divide, is a shape this cannot answer and the port refuses it where the graph is built.
        NSArray<NSNumber *> *written = [parameters[@"gatherOperand"] isEqual:@"shape"] ? fedOne
                                                                                     : parameters[@"gatherShape"];
        if (written == nil)
            return nil;
        NSUInteger elementCount = CharonMPSGraphElementCount(sourceShape);
        NSMutableArray<NSNumber *> *declared = [NSMutableArray arrayWithCapacity:written.count];
        NSInteger dynamic = 0;
        unsigned long long writtenProduct = 1;
        for (NSNumber *extent in written) {
            NSInteger value = extent.integerValue;
            if (value == -1) {
                dynamic++;
                [declared addObject:@(-1)];
                continue;
            }
            if (value < 1) {
                [NSException raise:NSInvalidArgumentException
                            format:@"MPSGraph: %@ was asked to reshape into a shape holding %ld, and every "
                                   @"extent of a shape is one or more", name, (long)value];
            }
            writtenProduct *= (unsigned long long)value;
            [declared addObject:@(value)];
        }
        if (dynamic > 1) {
            [NSException raise:NSInvalidArgumentException
                        format:@"MPSGraph: %@ was asked to reshape into a shape with %ld dynamic extents, and "
                               @"the release's own header allows one only where the result type can be "
                               @"inferred unambiguously", name, (long)dynamic];
        }
        if (dynamic == 1) {
            if (writtenProduct == 0 || elementCount % writtenProduct != 0) {
                [NSException raise:NSInvalidArgumentException
                            format:@"MPSGraph: %@ was asked to reshape %lu elements into a shape whose written "
                                   @"extents are a product of %llu, which does not divide them", name,
                                    (unsigned long)elementCount, writtenProduct];
            }
            [declared replaceObjectAtIndex:[declared indexOfObject:@(-1)] withObject:@(elementCount / writtenProduct)];
        }
        unsigned long long total = 1;
        for (NSNumber *extent in declared)
            total *= (unsigned long long)extent.unsignedIntegerValue;
        if (total != (unsigned long long)elementCount) {
            [NSException raise:NSInvalidArgumentException
                        format:@"MPSGraph: %@ was asked to reshape %lu elements into %llu, and the release's "
                               @"own header wants the volumes to match", name, (unsigned long)elementCount, total];
        }
        // The result's element at a flat index is the operand's element at the SAME flat index, which is what
        // the two row-major orders and the volumes matching are, and which the per-axis mapping cannot express
        // when the two shapes share no boundary - a 2x4 into a 4x2 puts one axis of the result across half of
        // an axis of the operand. So the plan says the walk is flat and the walk reads the index, and the
        // measured answers are the operand's own bytes in order: a 2x4 into a 4x2 and into a 2x4 and into a 1x8
        // all answer (1, 2, 3, 4, 10, 20, 30, 40).
        return @{@"shape": declared, @"flat": @YES};
    } else if (strcmp(gather, "transpose") == 0) {
        NSArray<NSNumber *> *permutation = parameters[@"gatherPermutation"];
        if (permutation.count != sourceRank) {
            [NSException raise:NSInvalidArgumentException
                        format:@"MPSGraph: %@ was asked to transpose with a permutation of %lu entries for a "
                               @"rank-%lu tensor, and the release's own compiler wants one entry per axis: "
                               @"perm tensor length must equal input tensor rank, %lu != %lu",
                                name, (unsigned long)permutation.count, (unsigned long)sourceRank,
                                (unsigned long)permutation.count, (unsigned long)sourceRank];
        }
        for (NSUInteger k = 0; k < permutation.count; k++) {
            // The header's spelling of the two-axis transpose is NSUInteger and the release's permutation
            // form is an array of them, and it still counts a negative value from the end - measured,
            // dimension:(NSUInteger)-1 withDimension:0 answers what dimension:0 withDimension:1 answers - so
            // the value is read back as the signed number it was written as, which is what the header's own
            // type makes a caller of a negative axis write.
            NSInteger which = (NSInteger)(int32_t)permutation[k].unsignedIntegerValue;
            if (which < 0)
                which += (NSInteger)sourceRank;
            if (which < 0 || (NSUInteger)which >= sourceRank) {
                [NSException raise:NSInvalidArgumentException
                            format:@"MPSGraph: %@ was asked to transpose with axis %ld of a rank-%lu tensor, "
                                   @"and axis 0 to %lu is all it has",
                                name, (long)which, (unsigned long)sourceRank, (unsigned long)sourceRank];
            }
            [shape addObject:sourceShape[(NSUInteger)which]];
            [sourceAxes addObject:@(which)];
            [sourceCounts addObject:@1];
            [reversed addObject:@0];
        }
    } else {
        CharonMPSGraphRefuse(@"MPSGraph: the operation named %@ asked for a gather this interpreter does not "
                             @"know, so nothing was written to its output", name);
        return nil;
    }
    return @{@"shape": shape, @"sourceAxes": sourceAxes, @"sourceCounts": sourceCounts,
             @"reversed": reversed, @"flat": @NO};
}

// The walk itself: each element of the result, its coordinates read from the last axis backwards (the operand
// is row-major with its FIRST axis the slowest moving), each coordinate turned into a coordinate of the
// operand's axes that axis of the result covers and weighted by that axis's stride. An element the plan maps
// to no element of the operand - which is what an axis the shape made wider than the operand's comes to - is
// left as the result buffer's own zero, which is what the release answers there.
static void CharonMPSGraphGather(MPSGraphOperation *operation, MPSGraphTensorData *source,
                                  MPSGraphTensorData *result, NSDictionary *plan)
{
    NSArray<NSNumber *> *sourceShape = source.shape;
    NSArray<NSNumber *> *resultShape = result.shape;
    NSArray<NSNumber *> *sourceAxes = plan[@"sourceAxes"];
    NSArray<NSNumber *> *sourceCounts = plan[@"sourceCounts"];
    NSArray<NSNumber *> *reversed = plan[@"reversed"];
    // The two keys a slice's plan carries and every other gather's does not; a gather without them reads an
    // offset of zero and a stride of one, which is what its own axes already say.
    NSArray<NSNumber *> *offsets = plan[@"offsets"];
    NSArray<NSNumber *> *strides = plan[@"strides"];
    // A TILE is this walk with every axis REPEATED: the coordinate of the result counts the operand's extent
    // over again rather than running past its end. Measured: a 2x4 tiled by (2, 3) answers (1, 2, 3, 4 |
    // 10, 20, 30, 40) three times over, twice down, and by (1, 3) once down and three across.
    BOOL repeated = [plan[@"repeat"] boolValue];
    NSUInteger sourceRank = sourceShape.count;
    NSUInteger resultRank = resultShape.count;
    NSUInteger count = CharonMPSGraphElementCount(resultShape);
    NSUInteger sourceCount = CharonMPSGraphElementCount(sourceShape);
    if (count == 0)
        return;
    MPSDataType type = source.dataType;
    void *in = [source charon_mps_bytes];
    void *out = [result charon_mps_bytes];

    // A reshape, whose answer is the operand's elements at the same flat index - see the plan.
    if ([plan[@"flat"] boolValue]) {
        for (NSUInteger element = 0; element < count && element < sourceCount; element++)
            CharonMPSStoreRounded(out, result.dataType, element,
                                  CharonMPSLoad(in, type, element), 1);
        return;
    }

    // The last axis's stride is one and every earlier axis's is the next one's weighted by the next axis's
    // extent, which is the row-major order the operand's own bytes are in.
    unsigned long long *sourceStride = calloc(sourceRank ? sourceRank : 1, sizeof(unsigned long long));
    for (NSUInteger i = sourceRank; i-- > 0;)
        sourceStride[i] = (i + 1 < sourceRank
                           ? sourceStride[i + 1] * (unsigned long long)sourceShape[i + 1].unsignedIntegerValue
                           : 1);
    for (NSUInteger element = 0; element < count; element++) {
        unsigned long long rest = element, sourceIndex = 0;
        BOOL unsourced = NO;
        for (NSUInteger k = resultRank; k-- > 0;) {
            NSUInteger extent = (NSUInteger)resultShape[k].unsignedIntegerValue;
            unsigned long long coordinate = extent ? rest % extent : 0;
            if (extent)
                rest /= extent;
            NSUInteger first = (NSUInteger)sourceAxes[k].unsignedIntegerValue;
            NSUInteger covered = (NSUInteger)sourceCounts[k].unsignedIntegerValue;
            if (covered > 0) {
                // How many of the operand's coordinates this axis of the result covers. A coordinate past that
                // has NO element of the operand behind it, and there the release answers a zero rather than
                // wrapping round to the start - measured, a 2x4 into a 4x4 answers its own eight values and
                // then eight zeros where the destination was filled with a pattern, and not the row twice.
                // One available coordinate is the broadcast's own rule and is not that case: an operand axis of
                // extent one is REPEATED along a result axis of any extent, which is what a 1x2x4 broadcast into
                // a 2x2x4 answers as the operand twice (measured), and taking the modulo of one below reads
                // the operand's single element for every coordinate of it.
                unsigned long long available = 1;
                for (NSUInteger c = 0; c < covered && first + c < sourceRank; c++)
                    available *= (unsigned long long)sourceShape[first + c].unsignedIntegerValue;
                if (repeated) {
                    // The whole of a repeated axis: every coordinate of the result is inside the operand's,
                    // because it counts its extent over again. So the check below is skipped for it and the
                    // component below takes the coordinate modulo the operand's own extent.
                }
                NSInteger step = offsets != nil ? [strides[k] integerValue] : 1;
                NSInteger from = offsets != nil ? [offsets[k] integerValue] : 0;
                unsigned long long last = (unsigned long long)(from + step * (NSInteger)(coordinate ? coordinate - 1 : 0));
                if (!repeated && available > 1 && coordinate >= available) {
                    unsourced = YES;
                    break;
                }
                if (!repeated && (step > 0 ? (NSInteger)last >= (NSInteger)available : (NSInteger)last < 0)) {
                    unsourced = YES;
                    break;
                }
            }
            // The covered axes are walked from the LAST of them, because the first of them is the slowest
            // moving: the coordinate of one axis of the result over several of the operand's is the coordinate
            // divided into them from the last, which is the same row-major order one axis carries.
            unsigned long long place = coordinate;
            for (NSUInteger c = covered; c-- > 0;) {
                NSUInteger axis = first + c;
                if (axis >= sourceRank)
                    break;
                unsigned long long extentOfSource = sourceShape[axis].unsignedIntegerValue;
                if (extentOfSource == 0)
                    continue;
                unsigned long long component = place % extentOfSource;
                place /= extentOfSource;
                if (repeated)
                    component = coordinate % extentOfSource;
                if ([reversed[k] boolValue])
                    component = extentOfSource - 1 - component;
                // A slice's OFFSET and STRIDE, which no other gather of the family has: the coordinate of the
                // result is the caller's start plus so many steps of the caller's stride.
                if (offsets != nil)
                    component = (unsigned long long)((NSInteger)component * [strides[k] integerValue] +
                                                     [offsets[k] integerValue]);
                sourceIndex += component * sourceStride[axis];
            }
        }
        if (!unsourced && sourceIndex < (unsigned long long)sourceCount)
            CharonMPSStoreRounded(out, result.dataType, element,
                                  CharonMPSLoad(in, type, (NSUInteger)sourceIndex), 1);
    }
    free(sourceStride);
}

// THE CONCAT AND STACK PLAN, which is the one plan of this library whose result is SEVERAL operands, so it
// cannot be the gather's: every axis but the one named has to hold the same extent in every operand, and
// the extent of the one named is the sum of theirs (or, for a stack, the number of operands). What the walk
// needs afterwards is, per operand, where its region of the result starts and how many elements of the axis
// it is long, plus whether the regions interleave.
//
// Everything here is measured on this host's own MPSGraph; see the seam's own comment in CharonMPSGraph.h
// for the answers and for the two refusals, which are the release's own.
static NSDictionary *CharonMPSGraphConcatPlan(NSString *name, NSArray<NSArray<NSNumber *> *> *shapes,
                                              NSInteger axis, BOOL interleave, BOOL stacked)
{
    NSUInteger operands = shapes.count;
    if (operands == 0) {
        // An EMPTY ARRAY OF TENSORS, and here the release's own answer, which is not a refusal and is why
        // this is not one: measured on this host's own MPSGraph over the whole path, `[MPSGraph
        // concatTensors:@[] dimension:0]` and `[MPSGraph stackTensors:@[] axis:0]` both BUILD the result
        // tensor, its shape is NIL, `compileWithDevice:` returns an executable and the run survives with the
        // destination left as the caller had it. So the plan here carries no shape either, the same shape the
        // gather's plan carries when its operand's own is not known yet, and the tensor the factory builds is
        // the release's: no shape on it and nothing written to it. An operation that cannot answer must not
        // take the application down over an array the caller passed - which is what raising here did.
        return @{};
    }
    NSArray<NSNumber *> *first = shapes.firstObject;
    NSUInteger rank = first.count;
    // Every operand has the same RANK, which the release's own words are about when they are not: a
    // concatenation of a rank-two tensor beside a rank-three one is a rank it cannot build at all, and a
    // stack is one operation per operand and so is refused the same way.
    for (NSArray<NSNumber *> *shapeOfOperand in shapes) {
        if (shapeOfOperand.count != rank) {
            [NSException raise:NSInvalidArgumentException
                        format:@"MPSGraph: %@ was asked to %@ a rank-%lu tensor beside a rank-%lu one, and "
                               @"every operand has to have the same rank", name,
                               stacked ? @"stack" : @"concatenate", (unsigned long)rank,
                               (unsigned long)shapeOfOperand.count];
        }
    }
    // The result's rank is the operands' own, or one more for a stack: its axis of extent as many operands
    // is the one that says which operand an element came from. So the axis the caller wrote down is counted
    // from the end of the RESULT's rank, which is what the header's own range says for a stack
    // (`-rank + 1 <= dimension < rank + 1`) and is the same walk for a concat (`-rank <= dimension < rank`).
    NSInteger resultRank = stacked ? (NSInteger)rank + 1 : (NSInteger)rank;
    NSInteger where = axis;
    if (where < 0)
        where += resultRank;
    if (where < 0 || where >= resultRank) {
        [NSException raise:NSInvalidArgumentException
                    format:@"MPSGraph: %@ was asked for axis %ld of a rank-%ld tensor, and axis 0 to %ld is "
                           @"all it has: measured, the release's own compiler refuses it with \"invalid axis "
                           "tensor: [%ld], axis must be in range -rank <= axis < rank\" (a concat) or "
                           "\"invalid axis: %ld, axis must be in range -|rank| <= axis < |rank|\" (a stack)",
                          name, (long)axis, (long)resultRank, (long)resultRank - 1, (long)axis, (long)axis];
    }

    NSMutableArray<NSNumber *> *shape = [NSMutableArray arrayWithCapacity:(NSUInteger)resultRank];
    long long total = 0;
    for (NSInteger k = 0; k < resultRank; k++) {
        if (k == where) {
            // The axis the operands are laid along: its extent is every operand's own added up, which for a
            // stack is the number of them - each operand being one element of it.
            for (NSArray<NSNumber *> *shapeOfOperand in shapes)
                total += stacked ? 1 : shapeOfOperand[(NSUInteger)where].longLongValue;
            [shape addObject:@(stacked ? (long long)operands : total)];
            continue;
        }
        // Every other axis of the result is one of the operands' own axes - the ones before the one named
        // and the ones after it - and it must hold the SAME extent in every operand. The header says the
        // inputs must be "broadcast compatible" and the release does not take it: measured, a 1x4 beside a
        // 2x4 with the concat on axis 1 is refused by its own compiler with "'mps.concat' op invalid input
        // tensor shapes, all input shapes must match except at axis" (MPSGraphUtilities.mm:748), and a stack
        // is refused the same way over inputs whose shapes differ at all.
        NSUInteger operandAxis = stacked ? (NSUInteger)(k < where ? k : k - 1) : (NSUInteger)k;
        long long extent = -1;
        for (NSArray<NSNumber *> *shapeOfOperand in shapes) {
            long long own = shapeOfOperand[operandAxis].longLongValue;
            if (extent < 0)
                extent = own;
            else if (extent != own) {
                [NSException raise:NSInvalidArgumentException
                            format:@"MPSGraph: %@ was asked to %@ tensors whose axis %ld holds %lld in one of "
                                   @"them and %lld in another, and the release wants every axis but the one it "
                                   @"lays them along to match: measured, its own compiler refuses this with "
                                   "\"'mps.concat' op invalid input tensor shapes, all input shapes must "
                                   "match except at axis\"",
                              name, stacked ? @"stack" : @"concatenate", (long)operandAxis, extent, own];
            }
        }
        [shape addObject:@(extent)];
    }

    // Where each operand's region of the result starts, and how many elements of the axis it is long. The
    // regions are the operands' own order either way - interleaving changes which element of the axis a
    // given operand's coordinate lands at, not the order the regions are read in - so the offset is the sum
    // of the extents before it, and the walk below divides the coordinate by the number of operands when it
    // interleaves.
    NSMutableArray<NSNumber *> *starts = [NSMutableArray arrayWithCapacity:operands];
    long long at = 0;
    for (NSArray<NSNumber *> *shapeOfOperand in shapes) {
        [starts addObject:@(at)];
        at += stacked ? 1 : shapeOfOperand[(NSUInteger)where].longLongValue;
    }
    // AN INTERLEAVED CONCATENATION IS THE ONE FORM THAT NEEDS THE OPERANDS TO AGREE ON THE AXIS, and this
    // is that check; it is why the walk below may divide the coordinate by the number of operands without
    // asking how long the operand it lands on is. Measured on this host's own MPSGraph: a 2x4 beside a 2x1
    // laid along axis 1 answers a 2x5 when they are laid end to end, and is REFUSED when they interleave, by
    // the release's own compiler with "'mps.concat' op all input shapes must match along axis dimension when
    // interleaving" (MPSGraphUtilities.mm:748). That refusal is the whole of the invariant: with every
    // operand E long on the axis, the coordinate divided by the number of operands is below E for every
    // coordinate of the result, because the result's extent there is the number of operands times E. Without
    // it the shorter operand is read past its end - a 2x4 beside a 2x1 would answer its operand 1's element 2,
    // 3 and 4 for three coordinates of the result - so this is refused here rather than checked per element
    // in the walk, which is where a check would be three orders of magnitude more expensive for the same
    // answer. It is refusals.txt's concat-interleave-unequal.

    if (interleave) {
        NSArray<NSNumber *> *first = shapes.firstObject;
        for (NSArray<NSNumber *> *shapeOfOperand in shapes) {
            long long own = shapeOfOperand[(NSUInteger)where].longLongValue;
            long long theirs = first[(NSUInteger)where].longLongValue;
            if (own != theirs) {
                [NSException raise:NSInvalidArgumentException
                            format:@"MPSGraph: %@ was asked to interleave tensors that are %lld and %lld long "
                                   @"on axis %ld, and an interleaved concatenation needs every one of them the "
                                   "same length there: measured, the release's own compiler refuses it with "
                                   "\"'mps.concat' op all input shapes must match along axis dimension when "
                                   "interleaving\"", name, theirs, own, (long)where];
            }
        }
    }
    // AN OPERAND OF EXTENT ZERO ON THE AXIS LAID ALONG, which is the other shape this walk's arithmetic does
    // not bound and the last one: the offsets of the regions collapse, so two operands start at the same
    // place and the search that picks one has no way to say which of them an element belongs to. The release
    // has no answer for it either - measured, it BUILDS the result tensor of the other operands' length and
    // then fails inside its own NDArray with "failed assertion `[MPSNDArray initWithDevice:descriptor:
    // isTextureBacked:] Error: device may not be nil'", taking the process down with it. So this is refused
    // where the graph is built, in the order the release names it: the interleave rule first, because an
    // interleaved pair of extents that differ is refused with THAT sentence whether or not one of them is
    // zero - measured over a 2x0 beside a 2x4 - and only then this one. A stack cannot reach it: its axis is
    // a new one, of extent as many operands, and an operand of extent zero on some axis of its own is
    // ordinary. refusals.txt's concat-zero-extent.
    if (!stacked) {
        NSUInteger i = 0;
        for (NSArray<NSNumber *> *shapeOfOperand in shapes) {
            if (shapeOfOperand[(NSUInteger)where].longLongValue == 0) {
                [NSException raise:NSInvalidArgumentException
                            format:@"MPSGraph: %@ was asked to concatenate operand %lu, which is of extent "
                                   @"ZERO on axis %ld, and the regions of the axis cannot be laid out when "
                                   @"one of them is: measured, the release builds the result tensor and then "
                                   @"fails inside its own array with \"failed assertion `[MPSNDArray "
                                   "initWithDevice:descriptor:isTextureBacked:] Error: device may not be "
                                   @"nil'\", taking the process down", name, (unsigned long)i, (long)where];
            }
            i++;
        }
    }
    return @{@"shape": shape, @"concatAxis": @(where), @"concatStarts": starts,
             @"concatInterleave": @(interleave), @"concatStacked": @(stacked)};
}

// THE SIZES OF A SPLIT, asked both when the graph is built (so that every output tensor carries its shape
// before anything runs) and when the operation runs (where the operand's value may have a shape of its own).
// One function for both, so a graph whose operand is fed is cut the way the value says.
//
// Written sizes are the caller's own, and the two rules about them are the release's:
//
//   - they must ADD UP to the extent of the axis they are cut from. Measured, @[@1, @1] and @[@3, @3] of a
//     2x4 along axis 1 both BUILD their result tensors and are then refused by the release's own compiler,
//     "'mps.split' op sum of result dimension lengths along split axis must equal input dimension length
//     along split axis" (MPSGraphUtilities.mm:1543), after which "Pass failed: MPSCopyDataFiles" takes the
//     process down; so is @[@1, @2] along axis 2 of a 2x3x4, whose results are a 2x3x1 and a 2x3x2.
//   - none of them may be ZERO and none may be NEGATIVE. A zero builds the result tensor of no elements
//     (the shape line prints 2x0) and is refused as the release assembles the results, with
//     NSInvalidArgumentException "object cannot be nil" from -[__NSArrayM insertObject:atIndex:]; a negative
//     one takes the process down where the graph is built, with SIGSEGV and no word at all (measured,
//     @[@1, @(-1)] of a 2x4 along axis 1).
//
// A COUNT instead of a list is turned into one by the release's own rule, measured over every pair of an
// extent E in 1..8 and a count N in 1..4 and then over (9,3), (9,4), (10,3), (10,4), (11,4), (12,5), (13,5),
// (9,5), (16,5) and (17,6): the first N-1 sizes are ceil(E/N) and the LAST is what is left. So E=5 N=2 is
// 3 2, E=7 N=3 is 3 3 1, E=8 N=3 is 3 3 2, E=17 N=6 is 3 3 3 3 3 2, and the count is refused exactly when
// that last size would not be positive - which is when (N-1)*ceil(E/N) is not less than E, and so for E=4
// N=3, E=6 N=4, E=9 N=4, E=12 N=5, E=16 N=5 and every N above E. The release's words for it are "infer split
// sizes from total size=E and num_splits=N failed." (MPSGraphUtilities.mm:1543) and then "LLVM ERROR: Failed
// to infer result type(s):" - and a count of ZERO is refused the same way.
static NSArray<NSNumber *> *CharonMPSGraphSplitSizes(NSString *name, NSArray<NSNumber *> *written,
                                                     NSUInteger numSplits, NSInteger axis,
                                                     NSArray<NSNumber *> *operandShape)
{
    NSInteger rank = (NSInteger)operandShape.count;
    if (axis < 0 || axis >= rank) {
        [NSException raise:NSInvalidArgumentException
                    format:@"MPSGraph: %@ was asked to split axis %ld of a rank-%ld tensor, and axis 0 to %ld is "
                           @"all it has: measured, the release's own compiler refuses it with \"invalid axis "
                           @"tensor: [%ld], axis must be in range -rank <= axis < rank, rank = %ld\" "
                           @"(MPSGraphUtilities.mm:1543) and then \"LLVM ERROR: Failed to infer result type(s)\" "
                           @"takes the process down",
                          name, (long)axis, (long)rank, (long)rank - 1, (long)axis, (long)rank];
    }
    long long extent = operandShape[(NSUInteger)axis].longLongValue;
    NSMutableArray<NSNumber *> *sizes = [NSMutableArray array];
    if (numSplits == 0) {
        for (NSUInteger i = 0; i < written.count; i++) {
            long long size = written[i].longLongValue;
            if (size <= 0) {
                [NSException raise:NSInvalidArgumentException
                            format:@"MPSGraph: %@ was asked to split a rank-%ld tensor into a region of %lld "
                                   @"elements of axis %ld, and a region of no elements is not one the release can "
                                   @"take: measured, a size of zero builds the result tensor of no elements "
                                   @"(the shape line prints 2x0) and is refused as the results are assembled "
                                   @"with \"object cannot be nil\" from -[__NSArrayM insertObject:atIndex:], and "
                                   @"a NEGATIVE size takes the process down with SIGSEGV where the graph is "
                                   @"built, with no word at all",
                              name, (long)rank, size, (long)axis];
            }
            [sizes addObject:@(size)];
        }
    } else {
        // ceil(E/N), and the last size is what is left of the axis after the other N-1 have taken theirs.
        long long each = (extent + (long long)numSplits - 1) / (long long)numSplits;
        long long last = extent - each * ((long long)numSplits - 1);
        if (each == 0 || last <= 0) {
            [NSException raise:NSInvalidArgumentException
                        format:@"MPSGraph: %@ was asked to split an axis of %lld elements into %lu, and the "
                               @"release cannot divide those: measured, its own compiler refuses it with "
                               @"\"infer split sizes from total size=%lld and num_splits=%lu failed.\" "
                               @"(MPSGraphUtilities.mm:1543) and then \"LLVM ERROR: Failed to infer result "
                               @"type(s):\" takes the process down. Its own rule is measured and is not "
                               @"dividing evenly: the first N-1 sizes are ceil(E/N) and the last is what is "
                               @"left, so E=5 N=2 is 3 2, E=7 N=3 is 3 3 1 and E=8 N=3 is 3 3 2",
                              name, extent, (unsigned long)numSplits, extent, (unsigned long)numSplits];
        }
        for (NSUInteger i = 1; i < numSplits; i++)
            [sizes addObject:@(each)];
        [sizes addObject:@(last)];
    }
    long long total = 0;
    for (NSNumber *size in sizes)
        total += size.longLongValue;
    if (total != extent) {
        [NSException raise:NSInvalidArgumentException
                    format:@"MPSGraph: %@ was asked to split an axis of %lld elements into regions of %lld in "
                           @"total, and the release wants them to add up: measured, it BUILDS the result "
                           @"tensors anyway and then its own compiler refuses the graph with \"'mps.split' op "
                           @"sum of result dimension lengths along split axis must equal input dimension length "
                           @"along split axis\" (MPSGraphUtilities.mm:1543), after which \"Pass failed: "
                           @"MPSCopyDataFiles\" takes the process down",
                      name, extent, total];
    }
    return sizes;
}

// THE PLAN OF THE BLOCK-MOVING FAMILY of 15.0 and 16.1: the three shapes the family's chain of three walks
// carries - the shape the first reshape splits the operand into, the permutation the transpose reads and the
// shape the last reshape merges it back into - together with every refusal of the family, which are asked
// here because both the written-down form and the fed one come through this function and must refuse the
// same things in the same words.
//
// It is asked twice over, and that is the whole of why it is here rather than in the factory: the written-
// down form asks it when the graph is BUILT, because the axes are numbers the caller wrote down and the
// chain's three operations carry these three shapes from the start, and the FED form of the 2D pair of 15.0
// asks it when the graph RUNS, because its three axes arrive as data and nothing about the result's type can
// be known before then - measured: the release builds a graph whose result carries NO SHAPE over three fed
// axes, hands back an executable, and its run answers exactly what the written-down axes answer over the same
// operand. Every measurement of the family is in -charon_mps_blockShuffle:spatial:batch:block:toBatch:shuffle:
// and in facts/MetalPerformanceShadersGraph/Core.md.
static NSDictionary *CharonMPSGraphBlockShufflePlan(NSString *name, NSArray<NSNumber *> *operandShape,
                                                    NSArray<NSNumber *> *spatial, NSInteger batch,
                                                    NSArray<NSNumber *> *block, BOOL toBatch, BOOL shuffle)
{
    NSUInteger rank = operandShape.count;
    NSUInteger count = spatial.count;

    // The axes as the release takes them: a negative one counted from the end, and every refusal of this
    // family asked here where the graph is built rather than left to be discovered as a wrong number.
    // Measured, and each sentence is the release's own (MPSGraphUtilities.mm:748 and :1171):
    //   - an axis outside the rank: "'mps.space_to_batch' op invalid axis: 3, axis must be in range - rank <=
    //     axis < rank, rank = 3", and for the 2D form its own with the axis's NAME: "invalid width_axis (3) for
    //     shape of rank 3" - a negative one lands there too, the release printing the value it was handed
    //     ("invalid width_axis (2147483647) for shape of rank 3");
    //   - the same axis twice in the list: "'mps.space_to_batch' op axis must be unique";
    //   - the batch axis among the spatial ones: "'mps.batch_to_space' op `batch_axis` = 0 must be unique
    //     from `spatial_axes`", and the same sentence from 'mps.space_to_batch';
    //   - as many block dimensions as spatial axes: "`spatial_axes` ... must have sam[e number of elements
    //     as]", said for both operations;
    //   - and a block that does not divide the extent it is a block of: "Invalid `block_dimensions[1] = 3
    //     for input size[2] = 4" for the general form, and "block_size (4) must be multiple of height 2" for
    //     the 2D form, which is the same rule in the words of an operation that has ONE block size for two
    //     axes.
    NSMutableArray<NSNumber *> *spatialAxes = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger i = 0; i < count; i++) {
        NSInteger axis = spatial[i].integerValue;
        if (axis < 0)
            axis += (NSInteger)rank;
        if (axis < 0 || (NSUInteger)axis >= rank) {
            [NSException raise:NSInvalidArgumentException
                        format:@"MPSGraph: %@ was given spatial axis %ld of a rank-%lu tensor, and axis 0 to %lu "
                               @"is all it has: measured, the release's own compiler refuses it with \"invalid "
                               @"axis: %ld, axis must be in range - rank <= axis < rank, rank = %lu\"", name,
                  (long)spatial[i].integerValue, (unsigned long)rank, (unsigned long)rank - 1, (long)axis,
                  (unsigned long)rank];
        }
        for (NSNumber *seen in spatialAxes) {
            if (seen.integerValue == axis) {
                [NSException raise:NSInvalidArgumentException
                            format:@"MPSGraph: %@ was given axis %ld of its spatial axes twice, and each of them "
                                   @"has to be an axis of its own: measured, the release's own compiler refuses "
                                   @"it with \"'mps.space_to_batch' op axis must be unique\"", name, (long)axis];
            }
        }
        [spatialAxes addObject:@(axis)];
    }
    NSInteger where = batch;
    if (where < 0)
        where += (NSInteger)rank;
    if (where < 0 || (NSUInteger)where >= rank) {
        // The sentence is the release's own, and it prints the axis AS IT WAS GIVEN - a batch axis of -4 over a
        // rank of three is refused with "invalid axis: -4" and not with the -1 it counts to (measured, both
        // directions, refusals.m's block-s2b-batch-negoutside and block-b2s-batch-negoutside), and its range is
        // -rank to rank-1 rather than 0 to rank-1, because a negative axis inside that range is one the family
        // counts from the end.
        [NSException raise:NSInvalidArgumentException
                    format:@"MPSGraph: %@ was given batch axis %ld of a rank-%lu tensor, and -%lu to %lu is all "
                           @"it has: measured, the release's own compiler refuses it with \"invalid axis: %ld, "
                           @"axis must be in range - rank <= axis < rank, rank = %lu\"", name, (long)batch,
                  (unsigned long)rank, (unsigned long)rank, (unsigned long)rank - 1, (long)batch,
                  (unsigned long)rank];
    }
    for (NSNumber *axisOfBlock in spatialAxes) {
        if (axisOfBlock.integerValue == where) {
            [NSException raise:NSInvalidArgumentException
                        format:@"MPSGraph: %@ was given batch axis %ld, which is one of its spatial axes (@%@), "
                               @"and the batch axis has to be an axis of its own: measured, the release's own "
                               @"compiler refuses it with \"`batch_axis` = %ld must be unique from "
                               @"`spatial_axes`\"", name, (long)where,
                      [spatialAxes componentsJoinedByString:@", @"], (long)where];
        }
    }
    if (block.count != count) {
        [NSException raise:NSInvalidArgumentException
                    format:@"MPSGraph: %@ was given %lu block dimensions for %lu spatial axes, one each: "
                           @"measured, the release's own compiler refuses it with \"`spatial_axes` ... must have "
                           @"sam\" - and it says the same for the batch axis", name, (unsigned long)block.count,
                  (unsigned long)count];
    }
    // Read the batch axis and the blocks only once the checks above have said they are there to be read.
    long long product = 1;
    for (NSUInteger i = 0; i < count; i++)
        product *= block[i].longLongValue;
    long long batchExtent = operandShape[(NSUInteger)where].longLongValue;
    // A BLOCK HAS TO BE AN EXTENT OF ONE AND TO FIT THE AXIS IT IS A BLOCK OF - and which of the two rules
    // that is depends on the direction, measured, because the two directions move the blocks opposite ways:
    // moving them TO the batch axis makes every spatial axis extent/block, so each block must DIVIDE its own
    // extent ("Invalid `block_dimensions[1] = 3 for input size[2] = 4", and the 2D form's "block_size (4) must
    // be multiple of height 2"), while moving them FROM the batch axis makes every spatial axis extent times
    // its own and so asks for nothing of that kind - measured, a block of @[@2, @3] over spatial axes of
    // extents 2 and 2 answers - and what it does ask for is that the PRODUCT of the blocks divide the batch
    // axis, which is the axis that shrinks here ("Invalid prod(`block_dimensions`) = 4 for input[2] = 2").
    if (!toBatch && product > 0 && batchExtent % product != 0) {
        [NSException raise:NSInvalidArgumentException
                    format:@"MPSGraph: %@ was given block dimensions @%@, whose product is %lld, for a batch "
                           @"axis of %lld elements, and this direction divides the batch axis by the product: "
                           @"measured, the release's own compiler refuses it with \"Invalid prod(`block_"
                           @"dimensions`) = %lld for input[%ld] = %lld\"", name,
                  [block componentsJoinedByString:@", @"], product, batchExtent, product, (long)where, batchExtent];
    }
    for (NSUInteger i = 0; i < count; i++) {
        long long size = block[i].longLongValue;
        long long extent = operandShape[spatialAxes[i].unsignedIntegerValue].longLongValue;
        if (size <= 0 || (toBatch && extent % size != 0)) {
            [NSException raise:NSInvalidArgumentException
                        format:@"MPSGraph: %@ was given a block of %lld elements for axis %lu, whose extent is "
                               @"%lld, and a block has to divide the axis it is a block of: measured, the "
                               @"release's own compiler refuses it with \"Invalid `block_dimensions[%lu] = %lld "
                               @"for input size[%lu] = %lld\", and the 2D form says the same rule in the words "
                               @"of an operation with one block size for two axes - \"block_size (%lld) must be "
                               @"multiple of height %lld\"", name, size,
                      (unsigned long)spatialAxes[i].integerValue, extent, (unsigned long)i, size,
                      (unsigned long)spatialAxes[i].integerValue, extent, size, extent];
        }
    }

    // THE ORDER THE BATCH AXIS IS HELD IN, over the pieces of the split tensor: the block's own coordinates in
    // the spatial list's order and the batch coordinate, and the flag says which of the two comes first.
    // The block's coordinates run with the LAST spatial axis fastest, so with the flag on the batch
    // coordinate is the slowest of the two - which is the header's "the values of the spatial blocks
    // contiguously within the depthAxis dimension" - and with the flag off it is the fastest, which is the
    // "interleaved with existing values" of the same sentence. Measured over the [3, 4, 6]: with the flag on,
    // the operand's (0, 0, w even) is at the result's d' = 0, its (0, 0, w odd) at 1 and its (1, 0, w even) at
    // 4, while with the flag off the same three are at 0, 3 and 1 - the batch coordinate leading in one case
    // and following in the other, and the block's own coordinates in the same order in both.
    NSMutableArray<NSString *> *keys = [NSMutableArray array];
    NSMutableDictionary *indexOf = [NSMutableDictionary dictionary];
    NSUInteger next = 0;
    for (NSUInteger axis = 0; axis < rank; axis++) {
        NSUInteger which = [spatialAxes indexOfObject:@(axis)];
        if (which == NSNotFound) {
            [keys addObject:[NSString stringWithFormat:@"ax%lu", (unsigned long)axis]];
            indexOf[[NSString stringWithFormat:@"ax%lu", (unsigned long)axis]] = @(next++);
            continue;
        }
        [keys addObject:[NSString stringWithFormat:@"hi%lu", (unsigned long)which]];
        indexOf[[NSString stringWithFormat:@"hi%lu", (unsigned long)which]] = @(next++);
        [keys addObject:[NSString stringWithFormat:@"ki%lu", (unsigned long)which]];
        indexOf[[NSString stringWithFormat:@"ki%lu", (unsigned long)which]] = @(next++);
    }
    NSString *batchKey = [NSString stringWithFormat:@"ax%ld", (long)where];
    NSMutableArray<NSNumber *> *woven = [NSMutableArray arrayWithCapacity:count + 1];
    if (shuffle) {
        [woven addObject:indexOf[batchKey]];
        for (NSUInteger i = 0; i < count; i++)
            [woven addObject:indexOf[[NSString stringWithFormat:@"ki%lu", (unsigned long)i]]];
    } else {
        for (NSUInteger i = 0; i < count; i++)
            [woven addObject:indexOf[[NSString stringWithFormat:@"ki%lu", (unsigned long)i]]];
        [woven addObject:indexOf[batchKey]];
    }
    // The group holds ITS OWN pieces and nothing else - the block's own coordinates and the batch axis's -
    // because the loop below puts one entry in beside it for every other axis of the operand, including
    // each spatial axis's block ROWS. An earlier version of this appended those rows here as well, which
    // made the permutation one entry per spatial axis longer than the split tensor has axes: measured, the
    // very first case of the family, a space-to-depth of a [3, 4, 6] with a 2x2 block, was refused with
    // "transpose with a permutation of 7 entries for a rank-5 tensor" and the family's own process died on
    // it, so that no case of the family past the first was ever compared against the release.

    // THE EXTENT OF EVERY PIECE, which is what tells the two directions apart: moving the blocks TO the batch
    // axis splits each spatial axis into its rows and its columns and leaves the batch axis whole, and moving
    // them FROM it is the same statement the other way round.
    long long *piece = calloc(keys.count, sizeof(long long));
    for (NSUInteger i = 0; i < count; i++) {
        long long extent = operandShape[spatialAxes[i].unsignedIntegerValue].longLongValue;
        piece[[indexOf[[NSString stringWithFormat:@"hi%lu", (unsigned long)i]] unsignedIntegerValue]] =
            toBatch ? extent / block[i].longLongValue : extent;
        piece[[indexOf[[NSString stringWithFormat:@"ki%lu", (unsigned long)i]] unsignedIntegerValue]] =
            block[i].longLongValue;
    }
    piece[[indexOf[batchKey] unsignedIntegerValue]] = toBatch ? batchExtent : batchExtent / product;
    // And every axis that is neither a spatial one nor the batch axis keeps its own extent throughout, which
    // is what the orderings above carry past the woven group: the first version of this gave an extent only to
    // the spatial pieces and to the batch axis, so a graph with an axis of its own - one spatial axis out of a
    // rank of three - carried a zero into the reshape and was refused with "a shape holding 0".
    for (NSUInteger axis = 0; axis < rank; axis++)
        if ([spatialAxes indexOfObject:@(axis)] == NSNotFound && axis != (NSUInteger)where)
            piece[[indexOf[[NSString stringWithFormat:@"ax%lu", (unsigned long)axis]] unsignedIntegerValue]] =
                operandShape[axis].longLongValue;
    // The three shapes of the chain, named for the three operations that carry them, so both directions fill
    // the same three: `splitShape` is what the FIRST reshape splits the operand into (the unmerged tensor's
    // own shape in the direction that moves the blocks out of the batch axis), `permutation` is what the
    // transpose reads, and `resultShape` is what the LAST reshape merges it back into.
    NSMutableArray<NSNumber *> *splitShape = [NSMutableArray array];
    NSMutableArray<NSNumber *> *permutation = [NSMutableArray array];
    NSMutableArray<NSNumber *> *resultShape = [NSMutableArray array];
    if (toBatch) {
        for (NSUInteger j = 0; j < keys.count; j++)
            [splitShape addObject:@(piece[j])];
        // THE ORDERING THE TRANSPOSE READS, and the result's axes are the OPERAND'S OWN in the operand's own
        // order - measured, which is what says a spatial list written the other way round answers a result
        // whose axes are still the operand's, and what the two cases that put the block rows before an axis of
        // the operand's own got wrong at first. The batch axis is the one that is replaced: by the woven
        // group, whose pieces the merge below collapses into the single axis the result has.
        long long merged = 1;
        for (NSUInteger j = 0; j < count + 1; j++)
            merged *= piece[woven[j].unsignedIntegerValue];
        for (NSUInteger axis = 0; axis < rank; axis++) {
            if (axis == (NSUInteger)where) {
                [permutation addObjectsFromArray:woven];
                [resultShape addObject:@(merged)];
                continue;
            }
            NSUInteger which = [spatialAxes indexOfObject:@(axis)];
            if (which == NSNotFound) {
                [permutation addObject:indexOf[[NSString stringWithFormat:@"ax%lu", (unsigned long)axis]]];
                [resultShape addObject:operandShape[axis]];
                continue;
            }
            NSUInteger rows = [indexOf[[NSString stringWithFormat:@"hi%lu", (unsigned long)which]] unsignedIntegerValue];
            [permutation addObject:@(rows)];
            [resultShape addObject:@(piece[rows])];
        }
    } else {
        // THE SAME CHAIN BACKWARDS, which is not the chain un-done step by step but its own three steps read
        // the other way round: the batch axis - which holds the blocks here - is split into the pieces the
        // other direction weaves together, the transpose carries each block coordinate next to the spatial
        // axis it belongs to, and the merge is of each spatial axis' own two pieces. Measured, this direction
        // is the inverse of the other with the same flag and the round trip is the identity, which is what
        // says the two are one chain and not two.
        //
        // Where each piece sits inside the batch axis is the flag's own question again: with it on the block
        // coordinates are contiguous in the result's batch axis - so the destination coordinate is the SLOWEST
        // of the pieces here - and with it off they are interleaved with it, so it is the fastest.
        NSMutableArray<NSNumber *> *sizes = [NSMutableArray arrayWithCapacity:count + 1];
        for (NSUInteger j = 0; j < count + 1; j++)
            [sizes addObject:@(piece[woven[j].unsignedIntegerValue])];
        // The index of each piece inside the axis the batch axis was split into: the destination coordinate's,
        // and the block coordinate of the i-th spatial axis'.
        NSUInteger destination = shuffle ? 0 : count;
        NSMutableArray<NSNumber *> *blockAt = [NSMutableArray arrayWithCapacity:count];
        for (NSUInteger i = 0; i < count; i++)
            [blockAt addObject:@(shuffle ? i + 1 : i)];
        // The unmerged shape is the operand's own with the batch axis replaced by those pieces, and the
        // ordering the transpose reads is the operand's axes in its own order with each spatial axis's block
        // coordinate beside it - so the merge below has the two of each adjacent.
        // The unmerged tensor's axes are the operand's own with the batch axis replaced by the pieces, so the
        // pieces sit at the batch axis's own position and every axis after it moves along by their number.
        NSUInteger base = (NSUInteger)where;
        for (NSUInteger axis = 0; axis < rank; axis++) {
            if (axis == base) {
                [splitShape addObjectsFromArray:sizes];
                [permutation addObject:@(base + destination)];
                continue;
            }
            NSUInteger own = axis + (axis > base ? count : 0);
            [splitShape addObject:operandShape[axis]];
            [permutation addObject:@(own)];
            NSUInteger which = [spatialAxes indexOfObject:@(axis)];
            if (which != NSNotFound) {
                // The spatial axis keeps its own extent here - this direction makes it extent times its block
                // - and the block coordinate of it, which lives in the batch group, follows it into the merge.
                [permutation addObject:@(base + [blockAt[which] unsignedIntegerValue])];
            }
        }
        // The result's shape: the batch axis over the product of the block and every spatial axis times its
        // own - the same statement the other direction is, the other way round.
        for (NSUInteger axis = 0; axis < rank; axis++) {
            NSUInteger which = [spatialAxes indexOfObject:@(axis)];
            if (axis == (NSUInteger)where) {
                [resultShape addObject:@(operandShape[axis].longLongValue / product)];
            } else if (which != NSNotFound) {
                [resultShape addObject:@(operandShape[axis].longLongValue * block[which].longLongValue)];
            } else {
                [resultShape addObject:operandShape[axis]];
            }
        }
    }
    free(piece);
    return @{@"splitShape": splitShape, @"permutation": permutation, @"resultShape": resultShape};
}

// The walk itself, and the reason it is not the gather above: for each element of the RESULT the coordinate
// along the axis the operands were laid along says which operand it came from, and the other coordinates
// are that operand's own - the one below the axis is the result's axis below it and the one above it is the
// result's axis one further up, because the axis itself belongs to no operand of a stack.
static void CharonMPSGraphConcat(NSString *name, NSArray<MPSGraphTensorData *> *sources,
                                 MPSGraphTensorData *result, NSDictionary *plan)
{
    NSArray<NSNumber *> *resultShape = result.shape;
    NSInteger axis = [plan[@"concatAxis"] integerValue];
    NSArray<NSNumber *> *starts = plan[@"concatStarts"];
    BOOL interleave = [plan[@"concatInterleave"] boolValue];
    BOOL stacked = [plan[@"concatStacked"] boolValue];
    NSUInteger operands = starts.count;
    NSUInteger rank = resultShape.count;
    NSUInteger count = CharonMPSGraphElementCount(resultShape);
    if (count == 0)
        return;
    MPSDataType type = result.dataType;
    void *out = [result charon_mps_bytes];

NSUInteger across = rank ? (NSUInteger)resultShape[(NSUInteger)axis].unsignedIntegerValue : 1;
    // The stride of the axis the operands were laid along, in the RESULT's own row-major order. It is not the
    // axis the result ends with in general - a concatenation on axis 0 of a 4x4 lays its regions along the
    // SLOWEST-moving axis and a stack at axis 0 lays them along the slowest of the result too - so it is
    // computed rather than assumed, and it is what says which coordinate of an element is the one that picks
    // the operand.
    unsigned long long axisStride = 1;
    for (NSUInteger a = (NSUInteger)axis + 1; a < rank; a++)
        axisStride *= (unsigned long long)resultShape[a].unsignedIntegerValue;
    for (NSUInteger element = 0; element < count; element++) {
        unsigned long long coordinate = axisStride ? (element / axisStride) % across : 0;
        // WHICH OPERAND: the one whose region of the axis this coordinate is in, which is the coordinate
        // divided by the number of operands when the regions interleave and a search of the offsets when they
        // do not. A stack's regions are one element each, so the coordinate IS the operand's index there.
        // Both leave the coordinate INSIDE that operand: a search of the offsets picks the last region that
        // starts at or before it, and the plan has refused an interleaved form whose operands are not all the
        // same length on this axis - see CharonMPSGraphConcatPlan - so the division cannot land past the end.
        NSUInteger which = 0;
        if (interleave) {
            which = (NSUInteger)(coordinate % operands);
        } else {
            for (NSUInteger i = operands; i-- > 0;) {
                if (coordinate >= (unsigned long long)[starts[i] longLongValue]) { which = i; break; }
            }
        }
        // The coordinate this element has INSIDE the operand that answered it. For a stack the axis belongs
        // to no operand at all - it is the one that says which operand this is - so the answer is zero there;
        // for a concat it is the coordinate divided by the number of operands when the regions interleave, and
        // the coordinate less where that operand's own region starts when they do not.
        long long own = 0;
        if (!stacked)
            own = interleave ? (long long)(coordinate / operands)
                             : (long long)(coordinate - [starts[which] longLongValue]);
        MPSGraphTensorData *source = sources[which];
        NSArray<NSNumber *> *sourceShape = source.shape;
        // The stride of that axis in the operand, which is where the element sits inside it. For a stack the
        // axis belongs to no operand, so `own` is zero and this is only ever multiplying zero.
        unsigned long long sourceIndex = (unsigned long long)(own < 0 ? 0 : own);
        unsigned long long stride = 1;
        for (NSUInteger a = (NSUInteger)axis + 1; a < sourceShape.count; a++)
            stride *= (unsigned long long)sourceShape[a].unsignedIntegerValue;
        sourceIndex *= stride;
        // The remaining coordinates of the result are the operand's own - the one below the axis is the
        // result's axis below it and the one above it is the result's axis one further up, because the axis
        // itself belongs to no operand of a stack - so they are read off the flat index in the result's own
        // row-major order, which has the FIRST axis the slowest moving and so reads them from the last back.
        unsigned long long rest = element;
        for (NSInteger k = (NSInteger)rank; k-- > 0;) {
            NSUInteger extentOfResult = resultShape[(NSUInteger)k].unsignedIntegerValue;
            unsigned long long at = extentOfResult ? rest % extentOfResult : 0;
            if (extentOfResult)
                rest /= extentOfResult;
            if (k == axis)
                continue;
            NSUInteger operandAxis = stacked ? ((NSUInteger)k < (NSUInteger)axis ? (NSUInteger)k : (NSUInteger)k - 1)
                                             : (NSUInteger)k;
            unsigned long long step = 1;
            for (NSUInteger a = operandAxis + 1; a < sourceShape.count; a++)
                step *= (unsigned long long)sourceShape[a].unsignedIntegerValue;
            sourceIndex += at * step;
        }
        // The plan cannot produce an index the operand does not hold: every axis but the one named was
        // checked above to hold the same extent in every operand, and the coordinate along the one named is
        // inside that operand's own region by construction. The check is here so that a defect in that
        // arithmetic writes a known zero and says which operation it was, rather than reading past the end of
        // a buffer the port does not own - which is what the release itself does for a window of a tile
        // gradient that runs off its axis, and what no port reproduces.
        NSUInteger sourceCount = CharonMPSGraphElementCount(sourceShape);
        if (sourceIndex >= sourceCount) {
            CharonMPSGraphRefuse(@"MPSGraph: the operation named %@ wanted element %lu of its result at "
                                 "index %llu of a %lu-element operand, which its own plan cannot ask for",
                                 name, (unsigned long)element, sourceIndex, (unsigned long)sourceCount);
            CharonMPSStoreRounded(out, type, element, 0.0, 1);
            continue;
        }
        CharonMPSStoreRounded(out, type, element,
                              CharonMPSLoad([source charon_mps_bytes], source.dataType, (NSUInteger)sourceIndex), 1);
    }
}

// WHAT A PAD PUTS WHERE THE OPERAND HAS NO ELEMENT, which is the whole of the padding mode and the reason the
// pad is a gather plus this and not one walk: the gather above fills the inside of the padding and leaves
// every other element of the result alone, and the five modes the release answers each answer that space
// differently. Measured on this host's own MPSGraph over a 2x4 of (1, 2, 3, 4 | 10, 20, 30, 40):
//
//   - CONSTANT and ZERO: the caller's constantValue, which is read in the result's own type, and zero.
//   - CLAMP TO EDGE: the nearest element of the axis, so a left padding of one repeats the first element and
//     a right padding of one the last - measured (1, 1, 1, 2, 3, 4) for one at each end of axis 1.
//   - REFLECT: the mirror ACROSS THE EDGE of the axis, so the element at index -1 is the one at index +1 and
//     the element at index -2 the one at index +2 - measured (2, 1, 2, 3, 4, 3) for one at each end, which is
//     not the mirror about the last element (that one answers (3, 1, 2, 3, 4, 3)) and not the one that repeats
//     the edge either.
//   - SYMMETRIC: the mirror that DOES repeat the edge, so index -1 is index 0 and index +1 is the last -
//     measured (1, 1, 2, 3, 4, 4) for one at each end.
//   - PERIODIC and ANTI-PERIODIC: the release refuses both, with its own words, "Unsupported paddingMode",
//     after it has built the result tensor - which is why the two are refused where the graph is built.
//
// Each axis is chosen on its own, because a pad is applied to every axis at once: an element outside the
// operand's box on any axis is filled from the mirrored or clamped coordinate of EVERY axis.
static void CharonMPSGraphPad(MPSGraphTensorData *source, MPSGraphTensorData *result, NSDictionary *plan)
{
    NSArray<NSNumber *> *sourceShape = source.shape;
    NSArray<NSNumber *> *resultShape = result.shape;
    NSArray<NSNumber *> *left = plan[@"offsets"];
    NSInteger mode = [plan[@"padMode"] integerValue];
    double constant = [plan[@"padConstant"] doubleValue];
    NSUInteger rank = resultShape.count;
    NSUInteger count = CharonMPSGraphElementCount(resultShape);
    if (count == 0)
        return;
    MPSDataType type = source.dataType;
    void *in = [source charon_mps_bytes];
    void *out = [result charon_mps_bytes];
    unsigned long long *resultStride = calloc(rank ? rank : 1, sizeof(unsigned long long));
    unsigned long long *sourceStride = calloc(rank ? rank : 1, sizeof(unsigned long long));
    for (NSUInteger i = rank; i-- > 0;) {
        resultStride[i] = (i + 1 < rank ? resultStride[i + 1] * (unsigned long long)resultShape[i + 1].unsignedIntegerValue : 1);
        sourceStride[i] = (i + 1 < rank ? sourceStride[i + 1] * (unsigned long long)sourceShape[i + 1].unsignedIntegerValue : 1);
    }
    // EVERY element of the result is written, because a fresh MTLBuffer holds no answer at all: an element
    // this walk leaves alone is whatever the allocator gave it, which is not the release's zero and not
    // anything else. Each axis is brought back inside the operand's own extent by the mode - a constant and a
    // zero do not bring it back at all, because they do not read the operand - and an element whose coordinate
    // no mode brings inside is the mode's own value.
    for (NSUInteger element = 0; element < count; element++) {
        unsigned long long rest = element, index = 0;
        BOOL mapped = YES;
        for (NSUInteger k = rank; k-- > 0;) {
            NSUInteger extent = resultShape[k].unsignedIntegerValue;
            long long coordinate = extent ? (long long)(rest % extent) : 0;
            if (extent)
                rest /= extent;
            long long ofSource = coordinate - [left[k] integerValue];
            long long extentOfSource = sourceShape[k].integerValue;
            if (ofSource < 0 || ofSource >= extentOfSource) {
                if (mode == 3)
                    ofSource = ofSource < 0 ? 0 : extentOfSource - 1;                            // clamp
                else if (mode == 1)
                    ofSource = ofSource < 0 ? -ofSource : 2 * extentOfSource - 2 - ofSource;      // reflect
                else if (mode == 2)
                    ofSource = ofSource < 0 ? -ofSource - 1 : 2 * extentOfSource - 1 - ofSource;  // symmetric
                else {
                    mapped = NO;
                    break;
                }
            }
            if (ofSource < 0 || ofSource >= extentOfSource) {
                mapped = NO;
                break;
            }
            index += (unsigned long long)ofSource * sourceStride[k];
        }
        double value = 0.0;
        if (mapped)
            value = CharonMPSLoad(in, type, (NSUInteger)index);
        else if (mode == 0)
            value = constant;
        CharonMPSStoreRounded(out, result.dataType, element, value, 1);
    }
    free(resultStride);
    free(sourceStride);
}

// THE OTHER DIRECTION, which the slice's family needs and the gather above cannot be: a scatter writes the
// SOURCE's elements into a result that is BIGGER than the source, at the coordinates the slice's own start
// and stride give - which is what a gradient is (the gradient of a slice, written back into a tensor of the
// forward input's shape) and what an update is (the update's elements written over the region of the data
// tensor). The walk is the gather's coordinate arithmetic with the roles exchanged: here the source's own
// coordinates are read and the result's are computed, so the stride table is the RESULT's.
//
// The result is zeroed first, because an element of it that the source does not reach is a zero and not the
// bytes the caller left in the buffer - measured, over a destination filled with the byte 0xbd the zeros of a
// gradient are written and the pattern is not among them.
static void CharonMPSGraphScatter(MPSGraphTensorData *source, MPSGraphTensorData *result, NSDictionary *plan)
{
    NSArray<NSNumber *> *sourceShape = source.shape;
    NSArray<NSNumber *> *resultShape = result.shape;
    NSArray<NSNumber *> *offsets = plan[@"offsets"];
    NSArray<NSNumber *> *strides = plan[@"strides"];
    // A tile's GRADIENT is the one scatter whose several source elements land on the same element of the
    // result: the copies of one element are summed, because the gradient of a sum is a sum. That is the
    // divisor the plan carries, and with it the walk divides the source's coordinate instead of stepping it,
    // and ADDS into the result rather than writing over it.
    NSArray<NSNumber *> *divisors = plan[@"divisors"];
    NSUInteger rank = resultShape.count;
    // The divisors are there when there is one per axis, and the plan carries an empty array when there are
    // none at all - a dictionary takes no nil, so their absence is an empty list and not a missing key.
    BOOL summed = divisors.count == rank;
    NSUInteger count = CharonMPSGraphElementCount(sourceShape);
    if (count == 0)
        return;
    MPSDataType type = source.dataType;
    void *in = [source charon_mps_bytes];
    void *out = [result charon_mps_bytes];
    size_t width = MPSSizeofMPSDataType(result.dataType);

    unsigned long long *resultStride = calloc(rank ? rank : 1, sizeof(unsigned long long));
    for (NSUInteger i = rank; i-- > 0;)
        resultStride[i] = (i + 1 < rank
                           ? resultStride[i + 1] * (unsigned long long)resultShape[i + 1].unsignedIntegerValue
                           : 1);
    // The zero the result starts at, which is the zero of its own type rather than of the source's. A
    // GRADIENT's result is zeroed over its whole shape - every element the gradient does not reach is a
    // written zero, measured over a destination filled with the byte 0xbd - and an UPDATE's is not, because
    // its result is the data tensor's own elements with one region written over them, which the interpreter
    // has copied in already and which this walk must leave alone outside the region.
    if (![plan[@"update"] boolValue])
        memset(out, 0, CharonMPSGraphElementCount(resultShape) * width);
    for (NSUInteger element = 0; element < count; element++) {
        unsigned long long rest = element, index = 0;
        BOOL outside = NO;
        for (NSUInteger k = rank; k-- > 0;) {
            NSUInteger extent = (NSUInteger)sourceShape[k].unsignedIntegerValue;
            unsigned long long coordinate = extent ? rest % extent : 0;
            if (extent)
                rest /= extent;
            NSInteger from = summed ? 0 : [offsets[k] integerValue];
            NSInteger step = [strides[k] integerValue];
            long long place = summed ? (long long)coordinate / (long long)[divisors[k] integerValue]
                                     : (long long)coordinate * (long long)step + (long long)from;
            // A coordinate the region does not reach is left as the zero above, which is what a region the
            // release itself would refuse leaves here: the plan has already refused a region that does not
            // fit, so this can only be an extent of zero, and there is nothing to write.
            if (place < 0 || (NSUInteger)place >= (NSUInteger)resultShape[k].unsignedIntegerValue) {
                outside = YES;
                break;
            }
            index += (unsigned long long)place * resultStride[k];
        }
        if (outside || index >= CharonMPSGraphElementCount(resultShape))
            continue;
        double value = CharonMPSLoad(in, type, element);
        if (summed)
            value += CharonMPSLoad(out, result.dataType, (NSUInteger)index);
        CharonMPSStoreRounded(out, result.dataType, (NSUInteger)index, value, 1);
    }
    free(resultStride);
}

// THE NON-ZERO INDICES of 17.0: the answer is a LIST rather than a tensor of the operand's shape, so it is a
// walk of its own and its length is only known here. Two passes over the operand, because the count decides
// how much of the result there is: the first counts the elements that are not a zero, which is the count the
// result's own shape carries, and the second writes their coordinates.
//
// WHAT COUNTS AS NON-ZERO is the operand read through the SAME load every other walk of this interpreter
// reads it with, and it is measured rather than argued, one candidate at a time at element 30 of a [3, 4, 6]
// so that an answer of one row - which the release writes into every row of the destination - cannot be
// mistaken for the zeros an answer of no rows is given:
//
//   element                     float32          float16
//   0x7fc00000, a NaN           non-zero         non-zero
//   0x7f800000, an infinity     non-zero         -
//   0x00000001, a denormal      ZERO             non-zero
//   0x80000000, a NEGATIVE zero ZERO             ZERO
//   0x00000000, a positive zero ZERO             ZERO
//
// So a float32 denormal is a zero because this library reads a denormal as a zero of the same sign (see
// CharonMPSGraphAsZero and facts/MetalPerformanceShadersGraph/Core.md), a half denormal is not because the
// half path keeps one, and a NEGATIVE zero is a zero in both because -0.0 == 0.0 is true and that is the
// test. Every other class is what `!= 0` says it is, and the answer is a double either way.
static NSUInteger CharonMPSGraphNonZeroCount(NSString *name, MPSGraphTensorData *source)
{
    void *in = [source charon_mps_bytes];
    if (in == NULL) {
        CharonMPSGraphRefuse(@"MPSGraph: the non-zero operation named %@ has nowhere to read its operand "
                             @"from, so its indices were not written", name);
        return 0;
    }
    NSUInteger total = CharonMPSGraphElementCount(source.shape);
    MPSDataType type = source.dataType;
    NSUInteger count = 0;
    for (NSUInteger element = 0; element < total; element++)
        if (CharonMPSGraphAsZero(CharonMPSLoad(in, type, element), type) != 0.0)
            count++;
    return count;
}

static void CharonMPSGraphNonZero(NSString *name, MPSGraphTensorData *source, MPSGraphTensorData *result,
                                 NSUInteger count)
{
    NSArray<NSNumber *> *shape = source.shape;
    NSUInteger rank = shape.count;
    NSUInteger total = CharonMPSGraphElementCount(shape);
    void *in = [source charon_mps_bytes];
    void *out = [result charon_mps_bytes];
    if (in == NULL || (out == NULL && count != 0)) {
        CharonMPSGraphRefuse(@"MPSGraph: the non-zero operation named %@ has nowhere to read its operand from "
                             @"or to write its indices to, so its indices were not written", name);
        return;
    }
    MPSDataType type = source.dataType;
    NSUInteger written = 0;
    for (NSUInteger element = 0; element < total; element++) {
        if (CharonMPSGraphAsZero(CharonMPSLoad(in, type, element), type) == 0.0)
            continue;
        // The row-major order every walk of this library uses: the FIRST axis is the slowest moving, so the
        // coordinate on an axis is what is left after the axes below it have been divided out. The
        // coordinates go out through the same store every other kernel of this library writes through, so
        // the harness's planted build reaches them and the differential is shown a wrong walk.
        unsigned long long at = element;
        for (NSUInteger axis = rank; axis-- > 0;) {
            NSUInteger extent = (NSUInteger)shape[axis].unsignedIntegerValue;
            CharonMPSStore(out, MPSDataTypeInt32, written * rank + axis,
                           (double)(extent ? at % extent : 0));
            if (extent)
                at /= extent;
        }
        written++;
    }
}

@implementation MPSGraph (CharonMPSGraphInterpreter)

// The shape of a gather's result, asked when the graph is BUILT so that the output tensor carries it before
// anything runs. The release infers the result's type when the graph is built - which is why an axis it
// cannot use aborts there rather than at the run - so a caller can read the shape off the tensor it was
// given, and this is where the port answers that. It is the same plan the interpreter walks, asked with the
// operand's own shape and with no fed parameter: a parameter the caller fed, or an operand whose own shape is
// not known yet (a gather of a fed gather), gives nil here and the interpreter puts the shape on when it runs.
- (NSArray<NSNumber *> *)charon_mps_gatherShapeOfTensor:(MPSGraphTensor *)tensor
                                             parameters:(NSDictionary *)parameters
                                                    named:(NSString *)name
{
    NSDictionary *plan = CharonMPSGraphGatherPlan(name, tensor.shape, parameters, nil);
    return plan[@"shape"];
}

// The shape of a concat's or a stack's result, asked when the graph is BUILT so that the output tensor
// carries it before anything runs - the same reason as the gather's shape above, and the same arrangement:
// the walk's own plan over the INPUTS' shapes, with the axis the caller wrote down and whether the operands
// interleave along it. The interpreter below asks the same function when the operation runs.
// The split's sizes, which is the rule and the three refusals of the function above, asked through the
// factory's own seam so that the graph is cut the same way when it is built and when it runs.
- (NSArray<NSNumber *> *)charon_mps_splitSizes:(NSArray<NSNumber *> *)written
                                    numSplits:(NSUInteger)numSplits
                                         axis:(NSInteger)axis
                                  ofShape:(NSArray<NSNumber *> *)operandShape
                                       named:(NSString *)name
{
    return CharonMPSGraphSplitSizes(name, written, numSplits, axis, operandShape);
}

// The plan of the block-moving family, asked of the interpreter - where the rule and every refusal of it live
// - both when the graph is built, by the written-down forms of the four operations, and when it runs, by the
// fed pair of 15.0 whose three axes arrive as data. `operandShape` is the shape the extents are measured
// against: the tensor's own when the graph is built, and the value's own when it runs, which is what lets a
// graph whose operand is a feed be cut the way its value says.
- (NSDictionary *)charon_mps_blockShufflePlan:(NSString *)name
                                       ofShape:(NSArray<NSNumber *> *)operandShape
                                       spatial:(NSArray<NSNumber *> *)spatial
                                         batch:(NSInteger)batch
                                         block:(NSArray<NSNumber *> *)block
                                       toBatch:(BOOL)toBatch
                                       shuffle:(BOOL)shuffle
{
    return CharonMPSGraphBlockShufflePlan(name, operandShape, spatial, batch, block, toBatch, shuffle);
}

- (NSArray<NSNumber *> *)charon_mps_concatShapeOfTensors:(NSArray<MPSGraphTensor *> *)tensors
                                                    axis:(NSInteger)axis
                                              interleave:(BOOL)interleave
                                                stacked:(BOOL)stacked
                                                   named:(NSString *)name
{
    NSMutableArray<NSArray<NSNumber *> *> *shapes = [NSMutableArray arrayWithCapacity:tensors.count];
    for (MPSGraphTensor *tensor in tensors)
        [shapes addObject:tensor.shape];
    return CharonMPSGraphConcatPlan(name, shapes, axis, interleave, stacked)[@"shape"];
}

// THE CHAIN of the block-moving family at RUN time, over a plan the graph could not be built from: a reshape
// into the split shape, the permutation transpose and the merge back - the very three walks
// -charon_mps_blockShuffle: builds into the graph when the axes are numbers the caller wrote down. Each of the
// three is the gather of its own kind with the shape or the permutation the plan carries, so the walk is the
// gather walk and not a second one, and the 2D form's fed pair and 16.1's fed general form both come through
// here. The result's shape is the last step's own and it goes on the output tensor, because it was not known
// when the graph was built: the caller's destination is sized by the caller, and this is what the answer is
// copied into.
- (void)charon_mps_runBlockShuffleChain:(NSDictionary *)chain
                                     into:(MPSGraphTensor *)output
                                     from:(MPSGraphTensorData *)source
                               operation:(MPSGraphOperation *)operation
                                  values:(NSMutableDictionary *)values
{
    MPSGraphTensorData *carrying = source;
    NSArray *transforms = @[@"reshape", @"transpose", @"reshape"];
    NSArray *carried = @[chain[@"splitShape"], chain[@"permutation"], chain[@"resultShape"]];
    NSArray *keys = @[@"gatherShape", @"gatherPermutation", @"gatherShape"];
    MPSDataType dataType = output.dataType;
    for (NSUInteger step = 0; step < transforms.count; step++) {
        NSDictionary *walk = CharonMPSGraphGatherPlan([operation name], carrying.shape,
                                                      @{@"gather": transforms[step], keys[step]: carried[step]},
                                                      nil);
        if (walk == nil) {
            CharonMPSGraphRefuse(@"MPSGraph: the block-moving operation named %@ wanted a step of its chain "
                                 @"the gather does not know, so nothing was written to its output",
                                 [operation name]);
            return;
        }
        MPSGraphTensorData *next = [[MPSGraphTensorData alloc] initWithDevice:source.device
                                                                 elementCount:CharonMPSGraphElementCount(walk[@"shape"])
                                                                        shape:walk[@"shape"]
                                                                     dataType:dataType];
        [next charon_mps_bytes];
        CharonMPSGraphGather(operation, carrying, next, walk);
        carrying = next;
    }
    [output charon_mps_setShape:carrying.shape];
    values[output] = carrying;
}

- (void)charon_mps_runOperation:(MPSGraphOperation *)operation values:(NSMutableDictionary *)values
{
    CharonMPSGraphOperationKind kind = [operation charon_mps_kind];
    if (kind == CharonMPSGraphOperationKindPlaceholder)
        return;
    MPSGraphTensor *output = operation.outputTensors.firstObject;
    if (!output)
        return;
    NSArray<MPSGraphTensor *> *inputs = operation.inputTensors;
    NSUInteger count = [output charon_mps_elementCount];
    MPSDataType dataType = output.dataType;
    MPSGraphTensorData *first = values[inputs.firstObject];
    id<MTLDevice> device = [first isKindOfClass:[MPSGraphTensorData class]] ? first.device.metalDevice
                                                                        : self.charon_mps_device.metalDevice;

    // The reduction family folds many elements into one, so it is walked before the loop below: the loop
    // reads the element of an operand that is written at the same index of the result, which is what an
    // elementwise operation wants and not what a reduction wants. Which family an operation belongs to is
    // read out of its own parameters and not out of its kind, because a kind names the release the
    // operation came from and the walk here is one walk for every release: a reduction says which fold it
    // is in @"combination", and nothing else in this interpreter knows that a fold exists by its name.
    //
    // The CONCAT and STACK family, the one walk of this library whose result is SEVERAL operands, is asked
    // first because it is the only one that reads every input: the gather below reads the operation's FIRST
    // input and a concat has no single operand to read.
    // The SPLIT, the one walk of this library whose result is SEVERAL TENSORS: its regions are cut OUT of
    // the operand rather than laid into a result, so every output of the operation is filled here and not
    // only the first. Each output is the slice walk asked over one region - a start, an end and a stride of
    // one on the axis named and the operand's own extent on every other axis - with the region's start being
    // the sum of the sizes before it, which is what puts them in the order the caller wrote them.
    if (operation.charon_mps_parameters[@"splitAxis"]) {
        NSDictionary *parameters = operation.charon_mps_parameters;
        NSInteger axis = [parameters[@"splitAxis"] integerValue];
        MPSGraphTensorData *source = values[inputs.firstObject];
        if (![source isKindOfClass:[MPSGraphTensorData class]]) {
            CharonMPSGraphRefuse(@"MPSGraph: the split named %@ has no value for its operand, so none of its "
                                 @"results was written", [operation name]);
            return;
        }
        NSArray<NSNumber *> *sizes = CharonMPSGraphSplitSizes([operation name], parameters[@"splitSizes"],
                                                              [parameters[@"splitNumSplits"] unsignedIntegerValue],
                                                              axis, source.shape);
        NSArray<MPSGraphTensor *> *outputs = operation.outputTensors;
        if (outputs.count != sizes.count) {
            CharonMPSGraphRefuse(@"MPSGraph: the split named %@ has %lu results and %lu regions, so none of "
                                 @"them was written", [operation name], (unsigned long)outputs.count,
                                 (unsigned long)sizes.count);
            return;
        }
        long long at = 0;
        for (NSUInteger i = 0; i < outputs.count; i++) {
            MPSGraphTensor *output = outputs[i];
            // The region is a start and an end per axis and a stride of one: on the axis the regions are cut
            // from, the start is where this one begins and the end is where the next begins, and on every
            // other axis the region is the WHOLE of the operand - which is a start of zero and an end of the
            // axis's own extent, not a start of the extent.
            NSMutableArray<NSNumber *> *starts = [NSMutableArray arrayWithCapacity:source.shape.count];
            NSMutableArray<NSNumber *> *ends = [source.shape mutableCopy];
            NSMutableArray<NSNumber *> *strides = [NSMutableArray arrayWithCapacity:source.shape.count];
            for (NSUInteger k = 0; k < source.shape.count; k++) {
                [starts addObject:@0];
                [strides addObject:@1];
            }
            starts[(NSUInteger)axis] = @(at);
            ends[(NSUInteger)axis] = @(at + sizes[i].longLongValue);
            // The slice's own plan over that one region - the walk every shape operation of this library
            // that is a gather of one operand already is, asked here once per output.
            NSDictionary *region = CharonMPSGraphGatherPlan([operation name], source.shape,
                                                             @{@"gather": @"slice",
                                                               @"sliceStarts": starts,
                                                               @"sliceEnds": ends,
                                                               @"sliceStrides": strides,
                                                               @"sliceStartMask": @0,
                                                               @"sliceEndMask": @0,
                                                               @"sliceSqueezeMask": @0}, nil);
            if (region == nil) {
                CharonMPSGraphRefuse(@"MPSGraph: the split named %@ wanted a region its own plan cannot ask "
                                     @"for, so none of its results was written", [operation name]);
                return;
            }
            MPSGraphTensorData *result = [[MPSGraphTensorData alloc] initWithDevice:source.device
                                                                     elementCount:[output charon_mps_elementCount]
                                                                            shape:output.shape
                                                                         dataType:output.dataType];
            [result charon_mps_bytes];
            CharonMPSGraphGather(operation, source, result, region);
            values[output] = result;
            at += sizes[i].longLongValue;
        }
        return;
    }
    // The COORDINATE ALONG AN AXIS, which is the one walk here with NO OPERAND: every element of the result
    // holds the coordinate of the axis named, and the shape is the one the factory resolved when the graph
    // was built - from what the caller wrote down, or out of a constant the graph holds, since a fed
    // parameter is refused there (measured: the release builds a graph over a fed axis or a fed shape and
    // then takes the process down, so there is nothing here to read at run time).
    if (operation.charon_mps_parameters[@"coordinateAxis"]) {
        MPSGraphTensor *output = operation.outputTensors.firstObject;
        NSArray<NSNumber *> *shape = operation.charon_mps_parameters[@"coordinateShape"];
        NSInteger axis = [operation.charon_mps_parameters[@"coordinateAxis"] integerValue];
        NSUInteger rank = shape.count;
        NSUInteger count = [output charon_mps_elementCount];
        // A shape with no axes, an axis outside the rank and a shape with an extent of zero are all refused
        // where the graph is built, above, so none of the three reaches here; what is left is the answer of a
        // result of no elements, which has no element to write and is a case the harness cannot ask (the
        // release refuses the run over one too).
        if (rank == 0 || axis < 0 || (NSUInteger)axis >= rank || count == 0)
            return;
        [output charon_mps_setShape:shape];
        MPSGraphTensorData *result = [[MPSGraphTensorData alloc] initWithDevice:[MPSGraphDevice deviceWithMTLDevice:device]
                                                                  elementCount:count
                                                                         shape:shape
                                                                      dataType:MPSDataTypeInt32];
        int32_t *out = [result charon_mps_bytes];
        if (out == NULL) {
            CharonMPSGraphRefuse(@"MPSGraph: the coordinate named %@ has nowhere to write its %lu elements, so "
                                 @"nothing was written to its output", [operation name],
                                 (unsigned long)count);
            return;
        }
        // The row-major order this library's walks all use: the FIRST axis is the slowest moving, so the
        // coordinate of the axis named is the one that steps every stride of the axes above it.
        unsigned long long stride = 1;
        for (NSUInteger k = (NSUInteger)axis + 1; k < rank; k++)
            stride *= (unsigned long long)shape[k].unsignedIntegerValue;
        unsigned long long extent = (unsigned long long)shape[(NSUInteger)axis].unsignedLongLongValue;
        for (NSUInteger element = 0; element < count; element++)
            out[element] = (int32_t)(stride ? (element / stride) % (extent ? extent : 1) : 0);
        values[output] = result;
        return;
    }
    if (operation.charon_mps_parameters[@"concatAxis"]) {
        NSMutableArray<MPSGraphTensorData *> *sources = [NSMutableArray arrayWithCapacity:inputs.count];
        NSMutableArray<NSArray<NSNumber *> *> *shapes = [NSMutableArray arrayWithCapacity:inputs.count];
        for (MPSGraphTensor *input in inputs) {
            MPSGraphTensorData *value = values[input];
            if (![value isKindOfClass:[MPSGraphTensorData class]]) {
                CharonMPSGraphRefuse(@"MPSGraph: the operation named %@ has no value for one of its operands, "
                                     @"so nothing was written to its output", [operation name]);
                return;
            }
            [sources addObject:value];
            [shapes addObject:value.shape];
        }
        NSDictionary *plan = CharonMPSGraphConcatPlan([operation name], shapes,
                                                      [operation.charon_mps_parameters[@"concatAxis"] integerValue],
                                                      [operation.charon_mps_parameters[@"concatInterleave"] boolValue],
                                                      [operation.charon_mps_parameters[@"concatStacked"] boolValue]);
        // A plan with NO SHAPE is the empty array of operands, which the release answers with a result
        // tensor of nil shape and nothing written to it - see CharonMPSGraphConcatPlan. There is nothing to
        // allocate here, and refusing and returning leaves the output with no value at all, which is what the
        // run's own copy-out then leaves the caller's destination as.
        if (plan[@"shape"] == nil) {
            CharonMPSGraphRefuse(@"MPSGraph: the operation named %@ was given no tensors, so its result "
                                 "carries no shape and nothing was written to it", [operation name]);
            return;
        }
        [output charon_mps_setShape:plan[@"shape"]];
        MPSGraphTensorData *concatenated = [[MPSGraphTensorData alloc] initWithDevice:sources.firstObject.device
                                                                          elementCount:CharonMPSGraphElementCount(plan[@"shape"])
                                                                                 shape:plan[@"shape"]
                                                                              dataType:dataType];
        [concatenated charon_mps_bytes];
        CharonMPSGraphConcat([operation name], sources, concatenated, plan);
        values[output] = concatenated;
        return;
    }
    if (operation.charon_mps_parameters[@"blockShuffle"]) {
        // THE FED PAIR of 15.0, whose THREE axes arrive as data and whose block size is still written down,
        // which is why this is a walk of its own rather than a gather: the chain of three walks the written-
        // down forms build into the graph is asked HERE, once, over shapes that cannot be known before the run.
        //
        // Measured, and it is the whole reason the pair is here rather than refused where the graph is built:
        // the release builds a graph whose result carries NO shape over three fed axes, -compileWithDevice:
        // still hands back an executable, and the run then answers exactly what the written-down axes answer
        // over the same operand - for both directions and under both flags (the [3, 4, 6] of 1 to 72 with the
        // axes of 2, 1 and 0 and a block of 2 is a 12x2x3 of (1, 3, 5, 13, 15, 17, 25, ...) and a 3x4x6 of
        // (1, 19, 2, 20, 3, 21, 37, ...)), which is the walk below asking the plan and then running the very
        // three walks -charon_mps_blockShuffle: builds the graph out of, with the shapes the plan hands it.
        //
        // The three axes are the operation's own second, third and fourth inputs in the order the header
        // declares them (width, height, depth), and the two spatial axes of the general form are those in
        // the order the block's coordinates run in, which the 2D form's own names make (height, width).
        MPSGraphTensorData *source = values[inputs.firstObject];
        if (![source isKindOfClass:[MPSGraphTensorData class]]) {
            CharonMPSGraphRefuse(@"MPSGraph: the block-moving operation named %@ has no value for its operand, "
                                 @"so nothing was written to its output", [operation name]);
            return;
        }
        NSMutableArray<NSNumber *> *axes = [NSMutableArray arrayWithCapacity:3];
        // THE GENERAL FORM of 16.1, whose THREE LISTS arrive as data: the spatial axes are a list of any
        // length, the batch axis is one number and the block is one extent per spatial axis. Measured on this
        // host's own MPSGraph over the [3, 4, 6] of 1 to 72, both directions and each of the three parameters
        // fed in turn, the release builds a graph whose result carries NO shape, -compileWithDevice: hands back
        // an executable, and the run writes exactly what the written-down axes write over the same operand (the
        // 12x2x3 of (1, 3, 5, 13, ... | 2, 4, 6, 14, ...) and the 3x4x6 of (1, 19, 2, 20, 3, 21, 37, ...)) -
        // so this is the 2D pair's own arrangement with the lists the general form hands over, and the plan
        // takes them as it takes the 2D form's two.
        if ([operation.charon_mps_parameters[@"blockShuffleGeneral"] boolValue]) {
            NSArray<NSNumber *> *spatial = CharonMPSGraphGatherIntegers(values[inputs[1]]);
            NSArray<NSNumber *> *where = CharonMPSGraphGatherIntegers(values[inputs[2]]);
            NSArray<NSNumber *> *sizes = CharonMPSGraphGatherIntegers(values[inputs[3]]);
            NSArray<NSArray<NSNumber *> *> *fed = @[spatial ?: @[], where ?: @[], sizes ?: @[]];
            for (NSUInteger i = 0; i < 3; i++) {
                if (fed[i].count != 0)
                    continue;
                CharonMPSGraphRefuse(@"MPSGraph: the block-moving operation named %@ was fed nothing at all for "
                                     @"its parameter %lu, and every one of the three is a list of numbers the "
                                     @"plan reads, so nothing was written to its output",
                                     [operation name], (unsigned long)i + 1);
                return;
            }
            if (where.count != 1) {
                CharonMPSGraphRefuse(@"MPSGraph: the block-moving operation named %@ was fed %lu numbers as its "
                                     @"batch axis, and the batch axis is one of them: measured, the release "
                                     @"takes it as a 0D tensor or one of shape [1]",
                                     [operation name], (unsigned long)where.count);
                return;
            }
            NSDictionary *general = [self charon_mps_blockShufflePlan:[operation name]
                                                              ofShape:source.shape
                                                              spatial:spatial
                                                                batch:where.firstObject.integerValue
                                                                block:sizes
                                                              toBatch:[operation.charon_mps_parameters[@"blockShuffleToBatch"] boolValue]
                                                              shuffle:[operation.charon_mps_parameters[@"blockShuffleShuffle"] boolValue]];
            [self charon_mps_runBlockShuffleChain:general into:output from:source operation:operation
                                            values:values];
            return;
        }
        for (NSUInteger i = 1; i < 4 && i < inputs.count; i++) {
            NSArray<NSNumber *> *read = CharonMPSGraphGatherIntegers(values[inputs[i]]);
            // The axis is ONE number, and the release's own rule for the tensor that carries it is quoted by
            // the factory where the graph is built - over a constant of two numbers the release answers
            // nothing at all, and over a FEED of two numbers it refuses the graph there with "operand #1 must
            // be 0D tensor of mps index type values or static-shape defined tensor with shape equal to [1]".
            // What arrives here is the caller's own bytes for a feed whose shape the graph already accepted,
            // so a value that is not one number is a caller who fed a different tensor than it declared.
            if (read.count != 1) {
                CharonMPSGraphRefuse(@"MPSGraph: the block-moving operation named %@ was fed %lu numbers for "
                                     @"its axis of input %lu, and an axis is one of them, so nothing was "
                                     @"written to its output",
                                     [operation name], (unsigned long)read.count, (unsigned long)i);
                return;
            }
            [axes addObject:read.firstObject];
        }
        if (axes.count != 3) {
            CharonMPSGraphRefuse(@"MPSGraph: the block-moving operation named %@ carries %lu axes and the "
                                 @"family's fed form has three, so nothing was written to its output",
                                 [operation name], (unsigned long)axes.count);
            return;
        }
        NSUInteger oneBlock = [operation.charon_mps_parameters[@"blockShuffleBlock"] unsignedIntegerValue];
        NSArray<NSNumber *> *block = @[@(oneBlock), @(oneBlock)];
        NSDictionary *chain = [self charon_mps_blockShufflePlan:[operation name]
                                                       ofShape:source.shape
                                                       spatial:@[axes[1], axes[0]]
                                                         batch:axes[2].integerValue
                                                         block:block
                                                       toBatch:[operation.charon_mps_parameters[@"blockShuffleToBatch"] boolValue]
                                                       shuffle:[operation.charon_mps_parameters[@"blockShuffleShuffle"] boolValue]];
        [self charon_mps_runBlockShuffleChain:chain into:output from:source operation:operation values:values];
        return;
    }
    if (operation.charon_mps_parameters[@"gather"]) {
        // The gather family, whose result is ONE operand's elements in another order or another extent. The
        // operation carries which transformation it is and the parameter of it the caller wrote down or fed;
        // see CharonMPSGraphGather.
        MPSGraphTensorData *source = values[inputs.firstObject];
        if (![source isKindOfClass:[MPSGraphTensorData class]]) {
            CharonMPSGraphRefuse(@"MPSGraph: the gather named %@ has no value for its first input, so "
                                 @"nothing was written to its output", [operation name]);
            return;
        }
        // Every fed parameter of this operation, in the order the plan reads them: one for the gathers above,
        // and for the slice family the starts, the ends (or the sizes) and the strides - and for the slice's
        // gradient the shape of its forward input last, which is the one parameter the release cannot be
        // asked at all and this port reads when the graph runs.
        NSMutableArray<NSArray<NSNumber *> *> *fed = [NSMutableArray array];
        NSString *gather = operation.charon_mps_parameters[@"gather"];
        BOOL sliceFamily = [gather hasPrefix:@"slice"];
        if (sliceFamily) {
            NSUInteger from = [operation.charon_mps_parameters[@"sliceFedFrom"] unsignedIntegerValue];
            if (from != 0)
                for (NSUInteger i = from; i < inputs.count; i++)
                    [fed addObject:CharonMPSGraphGatherIntegers(values[inputs[i]]) ?: @[]];
            if ([gather isEqualToString:@"sliceGradient"] && inputs.count > 1)
                // The forward input's shape is the operation's second input, whether the caller made it a
                // constant - whose value the factory read when the graph was built, and which is in the
                // values here as well - or a feed, which arrives now and is read now.
                [fed addObject:CharonMPSGraphGatherIntegers(values[inputs[1]]) ?: @[]];
        } else if (inputs.count > 1) {
            [fed addObject:CharonMPSGraphGatherIntegers(values[inputs[1]])];
        }
        NSDictionary *plan = CharonMPSGraphGatherPlan([operation name], source.shape,
                                                      operation.charon_mps_parameters, fed);
        if (plan == nil)
            return;
        // The result's own shape can be the caller's to feed, so it comes out of the plan and is put on the
        // output tensor before anything is allocated for it. The factory put it there too when it could be
        // known at build time, which is what a caller reads off the tensor before it runs the graph.
        [output charon_mps_setShape:plan[@"shape"]];
        NSUInteger gathered_ = CharonMPSGraphElementCount(plan[@"shape"]);
        MPSGraphTensorData *gathered = [[MPSGraphTensorData alloc] initWithDevice:source.device
                                                                     elementCount:gathered_
                                                                            shape:plan[@"shape"]
                                                                         dataType:dataType];
        [gathered charon_mps_bytes];
        if ([plan[@"scatter"] boolValue]) {
            // The two directions that write into a result bigger than what they read. A gradient's source is
            // its first input; an update's source is its SECOND, because its first input is the data tensor
            // the result is a copy of.
            MPSGraphTensorData *scattered = [plan[@"update"] boolValue] && inputs.count > 1 ? values[inputs[1]]
                                                                                          : source;
            if (![scattered isKindOfClass:[MPSGraphTensorData class]]) {
                CharonMPSGraphRefuse(@"MPSGraph: the slice operation named %@ has no value for the tensor it "
                                     @"writes, so nothing was written to its output", [operation name]);
                return;
            }
            if ([plan[@"update"] boolValue]) {
                // The update REPLACES what the region of the data tensor held, so the result starts as the
                // data's own elements - measured: a 1x2 region of a 2x4 updated with four new values answers
                // the data everywhere else, byte for byte, and the update's own four inside the region.
                // The whole of the data, not the update's own count of elements: the result is the data
                // tensor's shape and its elements, and the update is written over one region of it.
                NSUInteger available = CharonMPSGraphElementCount(source.shape);
                NSUInteger room = CharonMPSGraphElementCount(gathered.shape);
                void *out = [gathered charon_mps_bytes];
                void *in = [source charon_mps_bytes];
                for (NSUInteger i = 0; i < available && i < room; i++)
                    CharonMPSStoreRounded(out, dataType, i, CharonMPSLoad(in, source.dataType, i), 1);
            }
            CharonMPSGraphScatter(scattered, gathered, plan);
        } else {
            // The result of a slice whose squeezeMask dropped an axis is smaller than the walk: the elements
            // are the walk's own in order, so the walk goes over the full shape and the first of them fill the
            // result - measured, axis 0 of a 2x4 squeezed answers the first row, over two selected rows too,
            // and both axes squeezed answer the first element.
            NSArray<NSNumber *> *mapped = plan[@"mappedShape"];
            if (mapped != nil) {
                NSUInteger walked = CharonMPSGraphElementCount(mapped);
                MPSGraphTensorData *full = [[MPSGraphTensorData alloc] initWithDevice:source.device
                                                                          elementCount:walked
                                                                                 shape:mapped
                                                                              dataType:dataType];
                [full charon_mps_bytes];
                CharonMPSGraphGather(operation, source, full, plan);
                memcpy([gathered charon_mps_bytes], [full charon_mps_bytes],
                       MIN(walked, gathered_) * MPSSizeofMPSDataType(dataType));
            } else if ([gather isEqualToString:@"pad"]) {
                // A pad is its own walk: the gather's bounds check is about a coordinate that has no element
                // of the operand behind it, and in a pad that space is what the mode fills rather than an
                // error, so the one function below answers every element of the result.
                CharonMPSGraphPad(source, gathered, plan);
            } else {
                CharonMPSGraphGather(operation, source, gathered, plan);
            }
        }
        values[output] = gathered;
        return;
    }
    if (kind == CharonMPSGraphOperationKindNonZero) {
        // THE LIST OF COORDINATES, the one walk of this library whose result is neither the operand's shape nor
        // a shape the caller wrote down: its own LENGTH is the count of the elements of the operand that are
        // not a zero, which is data, so the result tensor carries -1 for it until now (measured: -1x3 over a
        // [3, 4, 6], and the same before the run and after it). The count is asked first because it is what
        // the result's own shape and its storage are, and the shape goes on the output tensor here - the one
        // moment a caller can read it.
        MPSGraphTensorData *source = values[inputs.firstObject];
        if (![source isKindOfClass:[MPSGraphTensorData class]]) {
            CharonMPSGraphRefuse(@"MPSGraph: the non-zero operation named %@ has no value for its operand, so "
                                 @"its indices were not written", [operation name]);
            return;
        }
        NSUInteger rank = source.shape.count;
        NSUInteger count = CharonMPSGraphNonZeroCount([operation name], source);
        NSArray<NSNumber *> *answer = @[@(count), @(rank)];
        [output charon_mps_setShape:answer];
        MPSGraphTensorData *indices = [[MPSGraphTensorData alloc] initWithDevice:source.device
                                                                    elementCount:count * rank
                                                                           shape:answer
                                                                        dataType:MPSDataTypeInt32];
        [indices charon_mps_bytes];
        CharonMPSGraphNonZero([operation name], source, indices, count);
        values[output] = indices;
        return;
    }
    if (operation.charon_mps_parameters[@"scanCombination"]) {
        // The cumulative family, which is the reduction family's fold walked along an axis: the result is the
        // operand's own shape, so this cannot be the elementwise loop below either, and it is asked for the
        // same reason. Which fold, which axis, which way and whether an element is in its own answer are all
        // in the operation's parameters, so nothing here names 16.0 - see CharonMPSGraphScan.
        MPSGraphTensorData *source = values[inputs.firstObject];
        if (![source isKindOfClass:[MPSGraphTensorData class]]) {
            CharonMPSGraphRefuse(@"MPSGraph: a cumulative operation named %@ has no value for its first "
                                 @"input, so nothing was written to its output", [operation name]);
            return;
        }
        MPSGraphTensorData *axisData = inputs.count > 1 ? values[inputs[1]] : nil;
        MPSGraphTensorData *scanned = [[MPSGraphTensorData alloc] initWithDevice:source.device
                                                                     elementCount:count
                                                                            shape:output.shape
                                                                         dataType:dataType];
        [scanned charon_mps_bytes];
        CharonMPSGraphScan(operation, source, axisData, scanned);
        values[output] = scanned;
        return;
    }
    if (operation.charon_mps_parameters[@"combination"]) {
        MPSGraphTensorData *source = values[inputs.firstObject];
        MPSGraphTensor *meanTensor = operation.charon_mps_parameters[@"mean"];
        if (![source isKindOfClass:[MPSGraphTensorData class]]) {
            CharonMPSGraphRefuse(@"MPSGraph: a reduction named %@ has no value for its first input, so "
                                 @"nothing was written to its output", [operation name]);
            return;
        }
        MPSGraphTensorData *result = [[MPSGraphTensorData alloc] initWithDevice:source.device
                                                                    elementCount:count
                                                                           shape:output.shape
                                                                        dataType:dataType];
        [result charon_mps_bytes];
        MPSGraphTensorData *mean = [meanTensor isKindOfClass:[MPSGraphTensor class]] ? values[meanTensor]
                                                                                     : nil;
        CharonMPSGraphReduce(operation, source, [mean isKindOfClass:[MPSGraphTensorData class]] ? mean : nil,
                            result);
        values[output] = result;
        return;
    }

    if (kind == CharonMPSGraphOperationKindConstant) {
        NSData *values_ = [operation charon_mps_parameters][@"values"];
        if (!values_)
            return;
        MPSGraphTensorData *data = [[MPSGraphTensorData alloc] initWithDevice:[MPSGraphDevice deviceWithMTLDevice:device]
                                                                  elementCount:count
                                                                         shape:output.shape
                                                                      dataType:dataType];
        memcpy([data charon_mps_bytes], values_.bytes, MIN(values_.length, count * MPSSizeofMPSDataType(dataType)));
        values[output] = data;
        return;
    }

    // A value is tensor data, or the operation has nothing to read and is skipped rather than run on
    // something else: the two are different classes and a message to the wrong one is a crash, not an
    // answer. A caller whose feeds and inputs do not line up is told so here.
    MPSGraphTensorData *left = values[inputs.firstObject];
    MPSGraphTensorData *right = inputs.count > 1 ? values[inputs[1]] : nil;
    MPSGraphTensorData *third = inputs.count > 2 ? values[inputs[2]] : nil;
    if (left && ![left isKindOfClass:[MPSGraphTensorData class]])
        left = nil;
    if (right && ![right isKindOfClass:[MPSGraphTensorData class]])
        right = nil;
    if (third && ![third isKindOfClass:[MPSGraphTensorData class]])
        third = nil;
    if (!left) {
        CharonMPSGraphRefuse(@"MPSGraph: an operation named %@ has no value for its first input, so nothing was written to its output", [operation name]);
        return;
    }
    MPSGraphTensorData *result = [[MPSGraphTensorData alloc] initWithDevice:left.device
                                                             elementCount:count
                                                                    shape:output.shape
                                                                 dataType:dataType];
    // A tensor's storage is a buffer of its own, made when the tensor is first read, so that a run
    // never writes into a buffer the caller fed it.
    [result charon_mps_bytes];
    void *out = [result charon_mps_bytes];
    MPSDataType operandType = left.dataType;
    // Whether this operation latches a NaN is its own parameter and not its kind: see
    // CharonMPSGraphApply above.
    int latch = [operation.charon_mps_parameters[@"latchNaN"] boolValue];
    if (right) {
        if (third) {
            for (NSUInteger i = 0; i < count; i++)
                CharonMPSStoreRounded(out, dataType, i,
                           CharonMPSGraphApply(kind, CharonMPSLoad([left charon_mps_bytes], operandType, i),
                                               CharonMPSLoad([right charon_mps_bytes], right.dataType, i),
                                               CharonMPSLoad([third charon_mps_bytes], third.dataType, i),
                                               operandType, dataType, latch), 1);
        } else {
            for (NSUInteger i = 0; i < count; i++)
                CharonMPSStoreRounded(out, dataType, i,
                           CharonMPSGraphApply(kind, CharonMPSLoad([left charon_mps_bytes], operandType, i),
                                               CharonMPSLoad([right charon_mps_bytes], right.dataType, i), 0.0,
                                               operandType, dataType, latch), 1);
        }
    } else {
        for (NSUInteger i = 0; i < count; i++)
            CharonMPSStoreRounded(out, dataType, i,
                       CharonMPSGraphApply(kind, CharonMPSLoad([left charon_mps_bytes], operandType, i), 0.0, 0.0,
                                           operandType, dataType, latch), 1);
    }
    values[output] = result;
}

@end