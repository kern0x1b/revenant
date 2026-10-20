#import "RevenantMPSGraph.h"

static double RevenantMPSGraphAsZero(double value, MPSDataType type)
{
    if (type != MPSDataTypeFloat32)
        return value;
    float narrowed = (float)value;
    if (narrowed != 0.0f && fabsf(narrowed) < FLT_MIN)
        return copysign(0.0, narrowed);
    return value;
}

static double RevenantMPSGraphOwnNaN(double value)
{
    return isnan(value) ? NAN : value;
}

static int RevenantMPSGraphReadsOperandAsStored(RevenantMPSGraphOperationKind kind)
{
    switch (kind) {
    case RevenantMPSGraphOperationKindAbs:
    case RevenantMPSGraphOperationKindIdentity:
    case RevenantMPSGraphOperationKindSignBit:
    case RevenantMPSGraphOperationKindNegate:
    case RevenantMPSGraphOperationKindRound:
    case RevenantMPSGraphOperationKindModulo:
    case RevenantMPSGraphOperationKindFloorModulo:
    case RevenantMPSGraphOperationKindMinimum:
    case RevenantMPSGraphOperationKindMaximum:
    case RevenantMPSGraphOperationKindSelect:
    case RevenantMPSGraphOperationKindClamp3:
    case RevenantMPSGraphOperationKindSin:
    case RevenantMPSGraphOperationKindSinh:
    case RevenantMPSGraphOperationKindAsin:
    case RevenantMPSGraphOperationKindAsinh:
    case RevenantMPSGraphOperationKindAtanh:
        return 1;
    default:
        return 0;
    }
}

static int RevenantMPSGraphCopiesTheOperand(RevenantMPSGraphOperationKind kind)
{
    return kind == RevenantMPSGraphOperationKindAbs || kind == RevenantMPSGraphOperationKindIdentity ||
           kind == RevenantMPSGraphOperationKindSignBit;
}

static int RevenantMPSGraphKeepsTheNaNItWasGiven(RevenantMPSGraphOperationKind kind)
{
    switch (kind) {
    case RevenantMPSGraphOperationKindNegate:
    case RevenantMPSGraphOperationKindRound:
    case RevenantMPSGraphOperationKindSelect:
    case RevenantMPSGraphOperationKindAsin:
    case RevenantMPSGraphOperationKindAtan:
    case RevenantMPSGraphOperationKindAsinh:
    case RevenantMPSGraphOperationKindAtanh:
        return 1;
    default:
        return 0;
    }
}

typedef NS_ENUM(NSInteger, RevenantMPSGraphHalfNaN) {
    RevenantMPSGraphHalfNaNNone = 0,
    RevenantMPSGraphHalfNaNInfinityOfSign,
    RevenantMPSGraphHalfNaNInfinityOfFlippedSign,
    RevenantMPSGraphHalfNaNZero,
    RevenantMPSGraphHalfNaNCanonical,
    RevenantMPSGraphHalfNaNSaturates,
    RevenantMPSGraphHalfNaNSaturatesAtOne,
    RevenantMPSGraphHalfNaNSigmoid
};

static RevenantMPSGraphHalfNaN RevenantMPSGraphHalfNaNOf(RevenantMPSGraphOperationKind kind)
{
    switch (kind) {
    case RevenantMPSGraphOperationKindAbs:
    case RevenantMPSGraphOperationKindIdentity:
    case RevenantMPSGraphOperationKindAdd:
    case RevenantMPSGraphOperationKindSubtract:
    case RevenantMPSGraphOperationKindSquare:
    case RevenantMPSGraphOperationKindReciprocal:
    case RevenantMPSGraphOperationKindSqrt:
    case RevenantMPSGraphOperationKindRsqrt:
    case RevenantMPSGraphOperationKindLog:
    case RevenantMPSGraphOperationKindSign:
    case RevenantMPSGraphOperationKindCeil:
    case RevenantMPSGraphOperationKindFloor:
    case RevenantMPSGraphOperationKindRound:
    case RevenantMPSGraphOperationKindSelect:
    case RevenantMPSGraphOperationKindReLUGradient:
        return RevenantMPSGraphHalfNaNInfinityOfSign;
    case RevenantMPSGraphOperationKindNegate:
        return RevenantMPSGraphHalfNaNInfinityOfFlippedSign;
    case RevenantMPSGraphOperationKindSin:
    case RevenantMPSGraphOperationKindCos:
    case RevenantMPSGraphOperationKindLogBase2:
        return RevenantMPSGraphHalfNaNZero;
    case RevenantMPSGraphOperationKindAsin:
    case RevenantMPSGraphOperationKindAcos:
    case RevenantMPSGraphOperationKindAsinh:
    case RevenantMPSGraphOperationKindAcosh:
    case RevenantMPSGraphOperationKindAtanh:
        return RevenantMPSGraphHalfNaNCanonical;
    case RevenantMPSGraphOperationKindErf:
    case RevenantMPSGraphOperationKindTanh:
        return RevenantMPSGraphHalfNaNSaturates;
    case RevenantMPSGraphOperationKindPower:
        return RevenantMPSGraphHalfNaNSaturatesAtOne;
    case RevenantMPSGraphOperationKindSigmoid:
        return RevenantMPSGraphHalfNaNSigmoid;
    case RevenantMPSGraphOperationKindReLU:
        return RevenantMPSGraphHalfNaNInfinityOfSign;
    default:
        return RevenantMPSGraphHalfNaNNone;
    }
}

static int RevenantMPSGraphHalfRule(RevenantMPSGraphOperationKind kind)
{
    return RevenantMPSGraphHalfNaNOf(kind) != RevenantMPSGraphHalfNaNNone;
}

static double RevenantMPSGraphApply(RevenantMPSGraphOperationKind kind, double a, double b, double c,
                                  MPSDataType operandType, MPSDataType resultType, int latch)
{
    if (latch && (isnan(a) || isnan(b) || isnan(c)))
        return RevenantMPSGraphOwnNaN(NAN);
    int stored = RevenantMPSGraphReadsOperandAsStored(kind);
    if (!stored) {
        a = RevenantMPSGraphAsZero(a, operandType);
        b = RevenantMPSGraphAsZero(b, operandType);
        c = RevenantMPSGraphAsZero(c, operandType);
    }
    int integral = operandType != MPSDataTypeFloat32 && operandType != MPSDataTypeFloat16;
    double result;
    switch (kind) {
    case RevenantMPSGraphOperationKindAbs:
        result = integral ? a : fabs(a);
        break;
    case RevenantMPSGraphOperationKindIdentity:
        result = a;
        break;
    case RevenantMPSGraphOperationKindAdd:
        result = a + b;
        break;
    case RevenantMPSGraphOperationKindSubtract:
        result = a - b;
        break;
    case RevenantMPSGraphOperationKindMultiply:
        result = a * b;
        break;
    case RevenantMPSGraphOperationKindDivide:
        result = a / b;
        break;
    case RevenantMPSGraphOperationKindNegate:
        result = -a;
        break;
    case RevenantMPSGraphOperationKindSquare:
        result = a * a;
        break;
    case RevenantMPSGraphOperationKindReciprocal:
        result = 1.0 / a;
        break;
    case RevenantMPSGraphOperationKindRsqrt:
        result = 1.0 / sqrt(a);
        break;
    case RevenantMPSGraphOperationKindSqrt:
        result = sqrt(a);
        break;
    case RevenantMPSGraphOperationKindExp:
        result = exp(a);
        break;
    case RevenantMPSGraphOperationKindLog:
        result = log(a);
        break;
    case RevenantMPSGraphOperationKindSign:
        result = a > 0.0 ? 1.0 : (a < 0.0 ? -1.0 : 0.0);
        break;
    case RevenantMPSGraphOperationKindMinimum:
        result = fmin(a, b);
        break;
    case RevenantMPSGraphOperationKindMaximum:
        result = fmax(a, b);
        break;
    case RevenantMPSGraphOperationKindClamp:
        result = a < b ? a : b;
        break;
    case RevenantMPSGraphOperationKindExpBase2:
        result = exp2(a);
        break;
    case RevenantMPSGraphOperationKindExpBase10:
        result = pow(10.0, a);
        break;
    case RevenantMPSGraphOperationKindLogBase2:
        result = log2(a);
        break;
    case RevenantMPSGraphOperationKindLogBase10:
        result = log10(a);
        break;
    case RevenantMPSGraphOperationKindSin:
        result = sin(a);
        break;
    case RevenantMPSGraphOperationKindCos:
        result = cos(a);
        break;
    case RevenantMPSGraphOperationKindTan:
        result = tan(a);
        break;
    case RevenantMPSGraphOperationKindSinh:
        result = sinh(a);
        break;
    case RevenantMPSGraphOperationKindCosh:
        result = cosh(a);
        break;
    case RevenantMPSGraphOperationKindTanh:
        result = tanh(a);
        break;
    case RevenantMPSGraphOperationKindAsin:
        result = asin(a);
        break;
    case RevenantMPSGraphOperationKindAcos:
        result = acos(a);
        break;
    case RevenantMPSGraphOperationKindAtan:
        result = atan(a);
        break;
    case RevenantMPSGraphOperationKindAsinh:
        result = asinh(a);
        break;
    case RevenantMPSGraphOperationKindAcosh:
        result = acosh(a);
        break;
    case RevenantMPSGraphOperationKindAtanh:
        result = atanh(a);
        break;
    case RevenantMPSGraphOperationKindErf:
        result = erf(a);
        break;
    case RevenantMPSGraphOperationKindSignBit:
        result = signbit(a) ? 1.0 : 0.0;
        break;
    case RevenantMPSGraphOperationKindFloor:
        result = integral ? a : floor(a);
        break;
    case RevenantMPSGraphOperationKindCeil:
        result = integral ? a : ceil(a);
        break;
    case RevenantMPSGraphOperationKindRound:
        result = integral ? a : round(a);
        if (result == 0.0)
            result = 0.0;
        break;
    case RevenantMPSGraphOperationKindRint:
        result = integral ? a : rint(a);
        break;
    case RevenantMPSGraphOperationKindIsNaN:
        result = integral ? 0.0 : (isnan(a) ? 1.0 : 0.0);
        break;
    case RevenantMPSGraphOperationKindIsFinite:
        result = integral ? 1.0 : (isfinite(a) ? 1.0 : 0.0);
        break;
    case RevenantMPSGraphOperationKindIsInfinite:
        result = integral ? 0.0 : (isinf(a) ? 1.0 : 0.0);
        break;
    case RevenantMPSGraphOperationKindLogicalNot:
        result = a == 0.0 ? 1.0 : 0.0;
        break;
    case RevenantMPSGraphOperationKindEqual:
        result = a == b ? 1.0 : 0.0;
        break;
    case RevenantMPSGraphOperationKindNotEqual:
        result = a != b ? 1.0 : 0.0;
        break;
    case RevenantMPSGraphOperationKindLessThan:
        result = a < b ? 1.0 : 0.0;
        break;
    case RevenantMPSGraphOperationKindLessThanOrEqualTo:
        result = a <= b ? 1.0 : 0.0;
        break;
    case RevenantMPSGraphOperationKindGreaterThan:
        result = a > b ? 1.0 : 0.0;
        break;
    case RevenantMPSGraphOperationKindGreaterThanOrEqualTo:
        result = a >= b ? 1.0 : 0.0;
        break;
    case RevenantMPSGraphOperationKindLogicalAnd:
        result = (a != 0.0 && b != 0.0) ? 1.0 : 0.0;
        break;
    case RevenantMPSGraphOperationKindLogicalOr:
        result = (a != 0.0 || b != 0.0) ? 1.0 : 0.0;
        break;
    case RevenantMPSGraphOperationKindLogicalNand:
        result = !(a != 0.0 && b != 0.0) ? 1.0 : 0.0;
        break;
    case RevenantMPSGraphOperationKindLogicalNor:
        result = !(a != 0.0 || b != 0.0) ? 1.0 : 0.0;
        break;
    case RevenantMPSGraphOperationKindLogicalXor:
        result = (a != 0.0) != (b != 0.0) ? 1.0 : 0.0;
        break;
    case RevenantMPSGraphOperationKindLogicalXnor:
        result = (a != 0.0) == (b != 0.0) ? 1.0 : 0.0;
        break;
    case RevenantMPSGraphOperationKindModulo:
        result = fmod(a, b);
        break;
    case RevenantMPSGraphOperationKindFloorModulo:
        result = fmod(fmod(a, b) + b, b);
        break;
    case RevenantMPSGraphOperationKindPower:
        result = pow(a, b);
        break;
    case RevenantMPSGraphOperationKindAtan2:
        result = atan2(a, b);
        break;
    case RevenantMPSGraphOperationKindDivisionNoNaN:
        result = b == 0.0 ? 0.0 : a / b;
        break;
    case RevenantMPSGraphOperationKindSelect:
        result = a != 0.0 ? b : c;
        break;
    case RevenantMPSGraphOperationKindClamp3:
        result = fmin(fmax(a, b), c);
        break;
    case RevenantMPSGraphOperationKindReLU:
        result = a > 0.0 ? a : 0.0;
        break;
    case RevenantMPSGraphOperationKindReLUGradient:
        result = isnan(b) ? NAN : (b > 0.0 ? a : a * 0.0);
        break;
    case RevenantMPSGraphOperationKindSigmoid:
        result = 1.0 / (1.0 + exp(-a));
        break;
    case RevenantMPSGraphOperationKindSigmoidGradient: {
        double s = 1.0 / (1.0 + exp(-b));
        result = a * s * (1.0 - s);
        break;
    }
    default:
        result = a;
        break;
    }
    if (resultType == MPSDataTypeFloat16 && RevenantMPSGraphHalfRule(kind)) {
        if (isnan(a) || isnan(b) || isnan(c)) {
            double sign = isnan(a) ? a : (isnan(b) ? b : c);
            switch (RevenantMPSGraphHalfNaNOf(kind)) {
            case RevenantMPSGraphHalfNaNInfinityOfSign:
                result = copysign(INFINITY, sign);
                break;
            case RevenantMPSGraphHalfNaNInfinityOfFlippedSign:
                result = copysign(INFINITY, -sign);
                break;
            case RevenantMPSGraphHalfNaNZero:
                result = 0.0;
                break;
            case RevenantMPSGraphHalfNaNCanonical:
                result = NAN;
                break;
            case RevenantMPSGraphHalfNaNSaturates:
                result = copysign(1.0, sign);
                break;
            case RevenantMPSGraphHalfNaNSaturatesAtOne:
                result = 1.0;
                break;
            case RevenantMPSGraphHalfNaNSigmoid:
                result = signbit(sign) ? 0.0 : 1.0;
                break;
            default:
                result = (kind == RevenantMPSGraphOperationKindReciprocal) ? 0.0 : INFINITY;
                break;
            }
            if (kind == RevenantMPSGraphOperationKindSqrt)
                result = signbit(sign) ? 0.0 : INFINITY;
            else if (kind == RevenantMPSGraphOperationKindSign)
                result = copysign(1.0, sign);
            if (kind == RevenantMPSGraphOperationKindSquare || kind == RevenantMPSGraphOperationKindAbs)
                result = INFINITY;
        } else if (isinf(a) && (kind == RevenantMPSGraphOperationKindSin || kind == RevenantMPSGraphOperationKindCos)) {
            result = 0.0;
        } else {
            switch (kind) {
            case RevenantMPSGraphOperationKindSqrt:
                if (a < 0.0) {
                    result = 0.0;
                }
                break;
            case RevenantMPSGraphOperationKindRsqrt:
                result = a < 0.0 ? 0.0 : (a == 0.0 ? INFINITY : result);
                break;
            case RevenantMPSGraphOperationKindReciprocal:
                result = a == 0.0 ? INFINITY : result;
                break;
            case RevenantMPSGraphOperationKindLog:
                result = a == 0.0 ? -45440.0 : (isinf(a) ? 0.0 : (a > 0.0 ? log(a) : 0.0));
                break;
            case RevenantMPSGraphOperationKindSign:
                result = a != 0.0 ? copysign(1.0, a) : 0.0;
                break;
            default:
                break;
            }
        }
    }
    if (resultType == MPSDataTypeFloat16 && result == 0.0 && !latch)
        result = 0.0;
    if (resultType == MPSDataTypeBool)
        return result != 0.0 ? 1.0 : 0.0;
    if ((kind == RevenantMPSGraphOperationKindAtan || kind == RevenantMPSGraphOperationKindTanh) &&
        result == 0.0)
        result = 0.0;
    if (RevenantMPSGraphCopiesTheOperand(kind))
        return stored ? result : RevenantMPSGraphAsZero(result, resultType);
    double narrowed = stored ? result : RevenantMPSGraphAsZero(result, resultType);
    if (RevenantMPSGraphKeepsTheNaNItWasGiven(kind) && (isnan(a) || isnan(b)))
        return narrowed;
    return RevenantMPSGraphOwnNaN(narrowed);
}

typedef struct {
    const char *combination;
    double seed;
    int isExtreme;
    int isLesser;
    int isTruth;
    int isOr;
    int multiplies;
    int divides;
} RevenantMPSGraphFold;

static const RevenantMPSGraphFold RevenantMPSGraphFolds[] = {
    {"sum", 0.0, 0, 0, 0, 0, 0, 0},
    {"product", 1.0, 0, 0, 0, 0, 1, 0},
    {"maximum", -INFINITY, 1, 0, 0, 0, 0, 0},
    {"minimum", INFINITY, 1, 1, 0, 0, 0, 0},
    {"and", 1.0, 0, 0, 1, 0, 0, 0},
    {"or", 0.0, 0, 0, 1, 1, 0, 0},
    {"mean", 0.0, 0, 0, 0, 0, 0, 1},
    {"variance", 0.0, 0, 0, 0, 0, 0, 1},
};

static const RevenantMPSGraphFold *RevenantMPSGraphFoldNamed(const char *combination)
{
    if (combination == NULL)
        return NULL;
    for (unsigned i = 0; i < sizeof(RevenantMPSGraphFolds) / sizeof(RevenantMPSGraphFolds[0]); i++)
        if (strcmp(RevenantMPSGraphFolds[i].combination, combination) == 0)
            return &RevenantMPSGraphFolds[i];
    return NULL;
}

static NSUInteger RevenantMPSGraphReductionIndex(NSArray<NSNumber *> *shape, const unsigned char *dropped,
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

static long RevenantMPSGraphCoordinate(NSArray<NSNumber *> *shape, NSUInteger axis, NSUInteger element)
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

static double RevenantMPSGraphFoldStep(const RevenantMPSGraphFold *fold, double held, double value, int propagates,
                                     int tiesToValue)
{
    if (fold->isExtreme) {
        if (isnan(value))
            return propagates ? RevenantMPSGraphOwnNaN(NAN) : held;
        if (propagates && isnan(held))
            return held;
        if (fold->isLesser)
            return tiesToValue ? (value <= held ? value : held) : (value < held ? value : held);
        return tiesToValue ? (value >= held ? value : held) : (value > held ? value : held);
    }
    if (fold->isTruth) {
        int truth = value != 0.0;
        int was = held != 0.0;
        return (fold->isOr ? (truth || was) : (truth && was)) ? 1.0 : 0.0;
    }
    return RevenantMPSGraphOwnNaN(fold->multiplies ? held * value : held + value);
}

static void RevenantMPSGraphReduce(MPSGraphOperation *operation, MPSGraphTensorData *source,
                                  MPSGraphTensorData *meanGiven, MPSGraphTensorData *result)
{
    NSDictionary *parameters = operation.revenant_mps_parameters;
    NSArray<NSNumber *> *shape = source.shape;
    NSArray<NSNumber *> *axes = parameters[@"axes"];
    NSUInteger sourceCount = [source revenant_mps_elementCount];
    NSUInteger resultCount = [result revenant_mps_elementCount];
    NSUInteger rank = shape.count;
    MPSDataType type = source.dataType;
    MPSDataType resultType = result.dataType;
    size_t resultSize = MPSSizeofMPSDataType(resultType);
    void *in = [source revenant_mps_bytes];
    void *out = [result revenant_mps_bytes];
    const RevenantMPSGraphFold *fold = RevenantMPSGraphFoldNamed([parameters[@"combination"] UTF8String]);
    if (fold == NULL || !axes || sourceCount == 0 || resultCount == 0)
        return;

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
    {
        unsigned long long running = 1;
        for (NSUInteger axis = rank; axis-- > 0;) {
            if (!dropped[axis]) {
                stride[axis] = running;
                running *= (unsigned long long)shape[axis].unsignedIntegerValue;
            }
        }
    }

    int propagates = [parameters[@"propagateNaN"] boolValue];
    int isIndex = [parameters[@"index"] boolValue];

    if (isIndex) {
        double *held = calloc(resultCount, sizeof(double));
        long *found = calloc(resultCount, sizeof(long));
        NSUInteger reducedAxis = (NSUInteger)axes.firstObject.integerValue;
        for (NSUInteger i = 0; i < resultCount; i++)
            found[i] = -1;
        for (NSUInteger i = 0; i < sourceCount; i++) {
            NSUInteger index = RevenantMPSGraphReductionIndex(shape, dropped, stride, i);
            if (index >= resultCount)
                continue;
            double value = RevenantMPSLoad(in, type, i);
            if (isnan(value))
                continue;
            if (found[index] < 0 || (fold->isLesser ? value < held[index] : value > held[index])) {
                found[index] = RevenantMPSGraphCoordinate(shape, reducedAxis, i);
                held[index] = value;
            }
        }
        for (NSUInteger i = 0; i < resultCount; i++)
            RevenantMPSStoreRounded(out, resultType, i, (double)found[i], 1);
        free(found);
        free(held);
        free(stride);
        free(dropped);
        return;
    }

    memset(out, 0, resultCount * resultSize);
    if (fold->multiplies || fold->isExtreme || fold->isTruth)
        for (NSUInteger i = 0; i < resultCount; i++)
            RevenantMPSStoreRounded(out, resultType, i, fold->seed, 1);
    for (NSUInteger i = 0; i < sourceCount; i++) {
        NSUInteger index = RevenantMPSGraphReductionIndex(shape, dropped, stride, i);
        if (index >= resultCount)
            continue;
        double value = RevenantMPSLoad(in, type, i);
        double held = RevenantMPSLoad(out, resultType, index);
        RevenantMPSStoreRounded(out, resultType, index, RevenantMPSGraphFoldStep(fold, held, value, propagates, 0), 1);
    }
    if (fold->divides) {
        int isVariance = strcmp(fold->combination, "variance") == 0;
        unsigned char *mean = meanGiven ? (unsigned char *)[meanGiven revenant_mps_bytes]
                                        : malloc(resultCount * resultSize);
        if (!meanGiven) {
            for (NSUInteger i = 0; i < resultCount; i++)
                RevenantMPSStoreRounded(mean, resultType, i, RevenantMPSLoad(out, resultType, i) / count, 1);
        }
        MPSDataType meanType = meanGiven ? meanGiven.dataType : resultType;
        if (isVariance) {
            memset(out, 0, resultCount * resultSize);
            for (NSUInteger i = 0; i < sourceCount; i++) {
                NSUInteger index = RevenantMPSGraphReductionIndex(shape, dropped, stride, i);
                if (index >= resultCount)
                    continue;
                double deviation = RevenantMPSLoad(in, type, i) - RevenantMPSLoad(mean, meanType, index);
                RevenantMPSStoreRounded(out, resultType, index,
                                      RevenantMPSLoad(out, resultType, index) + deviation * deviation, 1);
            }
            for (NSUInteger i = 0; i < resultCount; i++)
                RevenantMPSStoreRounded(out, resultType, i, RevenantMPSLoad(out, resultType, i) / count, 1);
        }
        if (!isVariance)
            for (NSUInteger i = 0; i < resultCount; i++)
                RevenantMPSStoreRounded(out, resultType, i, RevenantMPSLoad(mean, meanType, i), 1);
        if (!meanGiven)
            free(mean);
    }
    free(stride);
    free(dropped);
}

static double RevenantMPSGraphScanSeed(const RevenantMPSGraphFold *fold, MPSDataType type)
{
    if (!fold->isExtreme)
        return fold->seed;
    double magnitude = 0.0;
    switch (type) {
    case MPSDataTypeFloat32:
        magnitude = (double)FLT_MAX;
        break;
    case MPSDataTypeFloat16:
        magnitude = 65504.0;
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
        magnitude = 1.0;
        break;
    }
    return fold->isLesser ? magnitude : -magnitude;
}

static void RevenantMPSGraphScan(MPSGraphOperation *operation, MPSGraphTensorData *source,
                               MPSGraphTensorData *axisData, MPSGraphTensorData *result)
{
    NSDictionary *parameters = operation.revenant_mps_parameters;
    const RevenantMPSGraphFold *fold = RevenantMPSGraphFoldNamed([parameters[@"scanCombination"] UTF8String]);
    NSArray<NSNumber *> *shape = source.shape;
    NSUInteger rank = shape.count;
    NSUInteger count = rank ? [source revenant_mps_elementCount] : 0;
    if (fold == NULL || count == 0)
        return;
    MPSDataType type = source.dataType;
    MPSDataType resultType = result.dataType;
    void *in = [source revenant_mps_bytes];
    void *out = [result revenant_mps_bytes];

    NSInteger axis;
    if (parameters[@"scanAxisTensor"]) {
        if (axisData == nil || ![axisData isKindOfClass:[MPSGraphTensorData class]]) {
            RevenantMPSGraphRefuse(@"MPSGraph: the cumulative operation named %@ was fed no value for its "
                                 @"axis, so nothing was written to its output", [operation name]);
            return;
        }
        NSInteger fed = (NSInteger)RevenantMPSLoad([axisData revenant_mps_bytes], axisData.dataType, 0);
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
    double seed = RevenantMPSGraphScanSeed(fold, type);
    for (NSUInteger base = 0; base < count; base++) {
        if (RevenantMPSGraphCoordinate(shape, (NSUInteger)axis, base) != 0)
            continue;
        double accumulator = seed;
        for (unsigned long long step = 0; step < extent; step++) {
            unsigned long long at = reverse ? extent - 1 - step : step;
            NSUInteger here = base + (NSUInteger)(at * laneStride);
            double value = RevenantMPSLoad(in, type, here);
            if (!exclusive)
                accumulator = RevenantMPSGraphFoldStep(fold, accumulator, value, 0, 1);
            RevenantMPSStoreRounded(out, resultType, here, accumulator, 1);
            accumulator = RevenantMPSLoad(out, resultType, here);
            if (exclusive)
                accumulator = RevenantMPSGraphFoldStep(fold, accumulator, value, 0, 1);
        }
    }
    free(stride);
}

static NSMutableArray<NSNumber *> *RevenantMPSGraphGatherIntegers(MPSGraphTensorData *parameter)
{
    if (parameter == nil)
        return nil;
    NSUInteger count = RevenantMPSGraphElementCount(parameter.shape);
    NSMutableArray<NSNumber *> *values = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger i = 0; i < count; i++)
        [values addObject:@((NSInteger)RevenantMPSLoad([parameter revenant_mps_bytes], parameter.dataType, i))];
    return values;
}

static NSDictionary *RevenantMPSGraphGatherPlan(NSString *name, NSArray<NSNumber *> *sourceShape,
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
        RevenantMPSGraphRefuse(@"MPSGraph: the operation named %@ asked for a gather this interpreter does not "
                             @"know, so nothing was written to its output", name);
        return nil;
    }
    if (strcmp(gather, "squeeze") == 0 || strcmp(gather, "expand") == 0) {
        int expanding = strcmp(gather, "expand") == 0;
        NSArray<NSNumber *> *declared = [parameters[@"gatherOperand"] isEqual:@"axes"] ? fedOne
            : (expanding ? parameters[@"gatherAdd"] : parameters[@"gatherDrop"]);
        NSMutableIndexSet *named = [NSMutableIndexSet indexSet];
        for (NSNumber *axis in declared) {
            NSInteger where = axis.integerValue;
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
        NSArray<NSNumber *> *starts = parameters[@"sliceStarts"];
        NSArray<NSNumber *> *ends = parameters[@"sliceEnds"];
        NSArray<NSNumber *> *strides = parameters[@"sliceStrides"];
        NSUInteger startMask = [parameters[@"sliceStartMask"] unsignedIntegerValue];
        NSUInteger endMask = [parameters[@"sliceEndMask"] unsignedIntegerValue];
        NSUInteger squeezeMask = [parameters[@"sliceSqueezeMask"] unsignedIntegerValue];
        BOOL sizes = [parameters[@"sliceSizes"] boolValue];
        NSArray<NSNumber *> *regionShape = sourceShape;
        NSUInteger fedFrom = [parameters[@"sliceFedFrom"] unsignedIntegerValue];
        if (fedFrom != 0) {
            NSUInteger wanted = 3 - (sizes ? 1 : 0);
            if (fed.count < wanted)
                return nil;
            starts = fed[0];
            ends = fed[1];
            strides = wanted > 2 ? fed[2] : nil;
            if (sizes)
                strides = nil;
        }
        if (strcmp(gather, "sliceGradient") == 0) {
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
            NSInteger length = [parameters[@"sliceLength"] integerValue];
            NSInteger end = ends[k].integerValue;
            if (maskEnd)
                end = step > 0 ? extentOfSource : -1;
            else if (end < 0)
                end += extentOfSource;
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
            return @{@"shape": regionShape, @"counts": counts, @"offsets": offsets, @"strides": steps,
                     @"scatter": @YES, @"update": @(strcmp(gather, "sliceUpdate") == 0)};
        }

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
        return @{@"shape": shape, @"mappedShape": mapped, @"sourceAxes": sourceAxes,
                 @"sourceCounts": sourceCounts, @"reversed": reversed, @"offsets": offsets, @"strides": steps};
    } else if (strcmp(gather, "scatter") == 0) {
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
        return @{@"shape": resultShape, @"offsets": offsets, @"strides": strides,
                 @"divisors": divisors ?: @[], @"scatter": @YES,
                 @"update": parameters[@"scatterUpdate"] ?: @NO};
    } else if (strcmp(gather, "tile") == 0) {
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
        return @{@"shape": shape, @"sourceAxes": sourceAxes, @"sourceCounts": sourceCounts, @"reversed": reversed,
                 @"offsets": left, @"strides": oneEach,
                 @"padMode": parameters[@"padMode"] ?: @0,
                 @"padConstant": parameters[@"padConstant"] ?: @0};
    } else if (strcmp(gather, "reshape") == 0) {
        NSArray<NSNumber *> *written = [parameters[@"gatherOperand"] isEqual:@"shape"] ? fedOne
                                                                                     : parameters[@"gatherShape"];
        if (written == nil)
            return nil;
        NSUInteger elementCount = RevenantMPSGraphElementCount(sourceShape);
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
        RevenantMPSGraphRefuse(@"MPSGraph: the operation named %@ asked for a gather this interpreter does not "
                             @"know, so nothing was written to its output", name);
        return nil;
    }
    return @{@"shape": shape, @"sourceAxes": sourceAxes, @"sourceCounts": sourceCounts,
             @"reversed": reversed, @"flat": @NO};
}

static void RevenantMPSGraphGather(MPSGraphOperation *operation, MPSGraphTensorData *source,
                                  MPSGraphTensorData *result, NSDictionary *plan)
{
    NSArray<NSNumber *> *sourceShape = source.shape;
    NSArray<NSNumber *> *resultShape = result.shape;
    NSArray<NSNumber *> *sourceAxes = plan[@"sourceAxes"];
    NSArray<NSNumber *> *sourceCounts = plan[@"sourceCounts"];
    NSArray<NSNumber *> *reversed = plan[@"reversed"];
    NSArray<NSNumber *> *offsets = plan[@"offsets"];
    NSArray<NSNumber *> *strides = plan[@"strides"];
    BOOL repeated = [plan[@"repeat"] boolValue];
    NSUInteger sourceRank = sourceShape.count;
    NSUInteger resultRank = resultShape.count;
    NSUInteger count = RevenantMPSGraphElementCount(resultShape);
    NSUInteger sourceCount = RevenantMPSGraphElementCount(sourceShape);
    if (count == 0)
        return;
    MPSDataType type = source.dataType;
    void *in = [source revenant_mps_bytes];
    void *out = [result revenant_mps_bytes];

    if ([plan[@"flat"] boolValue]) {
        for (NSUInteger element = 0; element < count && element < sourceCount; element++)
            RevenantMPSStoreRounded(out, result.dataType, element,
                                  RevenantMPSLoad(in, type, element), 1);
        return;
    }

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
                unsigned long long available = 1;
                for (NSUInteger c = 0; c < covered && first + c < sourceRank; c++)
                    available *= (unsigned long long)sourceShape[first + c].unsignedIntegerValue;
                if (repeated) {
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
                if (offsets != nil)
                    component = (unsigned long long)((NSInteger)component * [strides[k] integerValue] +
                                                     [offsets[k] integerValue]);
                sourceIndex += component * sourceStride[axis];
            }
        }
        if (!unsourced && sourceIndex < (unsigned long long)sourceCount)
            RevenantMPSStoreRounded(out, result.dataType, element,
                                  RevenantMPSLoad(in, type, (NSUInteger)sourceIndex), 1);
    }
    free(sourceStride);
}

static NSDictionary *RevenantMPSGraphConcatPlan(NSString *name, NSArray<NSArray<NSNumber *> *> *shapes,
                                              NSInteger axis, BOOL interleave, BOOL stacked)
{
    NSUInteger operands = shapes.count;
    if (operands == 0) {
        return @{};
    }
    NSArray<NSNumber *> *first = shapes.firstObject;
    NSUInteger rank = first.count;
    for (NSArray<NSNumber *> *shapeOfOperand in shapes) {
        if (shapeOfOperand.count != rank) {
            [NSException raise:NSInvalidArgumentException
                        format:@"MPSGraph: %@ was asked to %@ a rank-%lu tensor beside a rank-%lu one, and "
                               @"every operand has to have the same rank", name,
                               stacked ? @"stack" : @"concatenate", (unsigned long)rank,
                               (unsigned long)shapeOfOperand.count];
        }
    }
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
            for (NSArray<NSNumber *> *shapeOfOperand in shapes)
                total += stacked ? 1 : shapeOfOperand[(NSUInteger)where].longLongValue;
            [shape addObject:@(stacked ? (long long)operands : total)];
            continue;
        }
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

    NSMutableArray<NSNumber *> *starts = [NSMutableArray arrayWithCapacity:operands];
    long long at = 0;
    for (NSArray<NSNumber *> *shapeOfOperand in shapes) {
        [starts addObject:@(at)];
        at += stacked ? 1 : shapeOfOperand[(NSUInteger)where].longLongValue;
    }

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

static NSArray<NSNumber *> *RevenantMPSGraphSplitSizes(NSString *name, NSArray<NSNumber *> *written,
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

static NSDictionary *RevenantMPSGraphBlockShufflePlan(NSString *name, NSArray<NSNumber *> *operandShape,
                                                    NSArray<NSNumber *> *spatial, NSInteger batch,
                                                    NSArray<NSNumber *> *block, BOOL toBatch, BOOL shuffle)
{
    NSUInteger rank = operandShape.count;
    NSUInteger count = spatial.count;

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
    long long product = 1;
    for (NSUInteger i = 0; i < count; i++)
        product *= block[i].longLongValue;
    long long batchExtent = operandShape[(NSUInteger)where].longLongValue;
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

    long long *piece = calloc(keys.count, sizeof(long long));
    for (NSUInteger i = 0; i < count; i++) {
        long long extent = operandShape[spatialAxes[i].unsignedIntegerValue].longLongValue;
        piece[[indexOf[[NSString stringWithFormat:@"hi%lu", (unsigned long)i]] unsignedIntegerValue]] =
            toBatch ? extent / block[i].longLongValue : extent;
        piece[[indexOf[[NSString stringWithFormat:@"ki%lu", (unsigned long)i]] unsignedIntegerValue]] =
            block[i].longLongValue;
    }
    piece[[indexOf[batchKey] unsignedIntegerValue]] = toBatch ? batchExtent : batchExtent / product;
    for (NSUInteger axis = 0; axis < rank; axis++)
        if ([spatialAxes indexOfObject:@(axis)] == NSNotFound && axis != (NSUInteger)where)
            piece[[indexOf[[NSString stringWithFormat:@"ax%lu", (unsigned long)axis]] unsignedIntegerValue]] =
                operandShape[axis].longLongValue;
    NSMutableArray<NSNumber *> *splitShape = [NSMutableArray array];
    NSMutableArray<NSNumber *> *permutation = [NSMutableArray array];
    NSMutableArray<NSNumber *> *resultShape = [NSMutableArray array];
    if (toBatch) {
        for (NSUInteger j = 0; j < keys.count; j++)
            [splitShape addObject:@(piece[j])];
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
        NSMutableArray<NSNumber *> *sizes = [NSMutableArray arrayWithCapacity:count + 1];
        for (NSUInteger j = 0; j < count + 1; j++)
            [sizes addObject:@(piece[woven[j].unsignedIntegerValue])];
        NSUInteger destination = shuffle ? 0 : count;
        NSMutableArray<NSNumber *> *blockAt = [NSMutableArray arrayWithCapacity:count];
        for (NSUInteger i = 0; i < count; i++)
            [blockAt addObject:@(shuffle ? i + 1 : i)];
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
                [permutation addObject:@(base + [blockAt[which] unsignedIntegerValue])];
            }
        }
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

static void RevenantMPSGraphConcat(NSString *name, NSArray<MPSGraphTensorData *> *sources,
                                 MPSGraphTensorData *result, NSDictionary *plan)
{
    NSArray<NSNumber *> *resultShape = result.shape;
    NSInteger axis = [plan[@"concatAxis"] integerValue];
    NSArray<NSNumber *> *starts = plan[@"concatStarts"];
    BOOL interleave = [plan[@"concatInterleave"] boolValue];
    BOOL stacked = [plan[@"concatStacked"] boolValue];
    NSUInteger operands = starts.count;
    NSUInteger rank = resultShape.count;
    NSUInteger count = RevenantMPSGraphElementCount(resultShape);
    if (count == 0)
        return;
    MPSDataType type = result.dataType;
    void *out = [result revenant_mps_bytes];

NSUInteger across = rank ? (NSUInteger)resultShape[(NSUInteger)axis].unsignedIntegerValue : 1;
    unsigned long long axisStride = 1;
    for (NSUInteger a = (NSUInteger)axis + 1; a < rank; a++)
        axisStride *= (unsigned long long)resultShape[a].unsignedIntegerValue;
    for (NSUInteger element = 0; element < count; element++) {
        unsigned long long coordinate = axisStride ? (element / axisStride) % across : 0;
        NSUInteger which = 0;
        if (interleave) {
            which = (NSUInteger)(coordinate % operands);
        } else {
            for (NSUInteger i = operands; i-- > 0;) {
                if (coordinate >= (unsigned long long)[starts[i] longLongValue]) { which = i; break; }
            }
        }
        long long own = 0;
        if (!stacked)
            own = interleave ? (long long)(coordinate / operands)
                             : (long long)(coordinate - [starts[which] longLongValue]);
        MPSGraphTensorData *source = sources[which];
        NSArray<NSNumber *> *sourceShape = source.shape;
        unsigned long long sourceIndex = (unsigned long long)(own < 0 ? 0 : own);
        unsigned long long stride = 1;
        for (NSUInteger a = (NSUInteger)axis + 1; a < sourceShape.count; a++)
            stride *= (unsigned long long)sourceShape[a].unsignedIntegerValue;
        sourceIndex *= stride;
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
        NSUInteger sourceCount = RevenantMPSGraphElementCount(sourceShape);
        if (sourceIndex >= sourceCount) {
            RevenantMPSGraphRefuse(@"MPSGraph: the operation named %@ wanted element %lu of its result at "
                                 "index %llu of a %lu-element operand, which its own plan cannot ask for",
                                 name, (unsigned long)element, sourceIndex, (unsigned long)sourceCount);
            RevenantMPSStoreRounded(out, type, element, 0.0, 1);
            continue;
        }
        RevenantMPSStoreRounded(out, type, element,
                              RevenantMPSLoad([source revenant_mps_bytes], source.dataType, (NSUInteger)sourceIndex), 1);
    }
}

static void RevenantMPSGraphPad(MPSGraphTensorData *source, MPSGraphTensorData *result, NSDictionary *plan)
{
    NSArray<NSNumber *> *sourceShape = source.shape;
    NSArray<NSNumber *> *resultShape = result.shape;
    NSArray<NSNumber *> *left = plan[@"offsets"];
    NSInteger mode = [plan[@"padMode"] integerValue];
    double constant = [plan[@"padConstant"] doubleValue];
    NSUInteger rank = resultShape.count;
    NSUInteger count = RevenantMPSGraphElementCount(resultShape);
    if (count == 0)
        return;
    MPSDataType type = source.dataType;
    void *in = [source revenant_mps_bytes];
    void *out = [result revenant_mps_bytes];
    unsigned long long *resultStride = calloc(rank ? rank : 1, sizeof(unsigned long long));
    unsigned long long *sourceStride = calloc(rank ? rank : 1, sizeof(unsigned long long));
    for (NSUInteger i = rank; i-- > 0;) {
        resultStride[i] = (i + 1 < rank ? resultStride[i + 1] * (unsigned long long)resultShape[i + 1].unsignedIntegerValue : 1);
        sourceStride[i] = (i + 1 < rank ? sourceStride[i + 1] * (unsigned long long)sourceShape[i + 1].unsignedIntegerValue : 1);
    }
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
                    ofSource = ofSource < 0 ? 0 : extentOfSource - 1;
                else if (mode == 1)
                    ofSource = ofSource < 0 ? -ofSource : 2 * extentOfSource - 2 - ofSource;
                else if (mode == 2)
                    ofSource = ofSource < 0 ? -ofSource - 1 : 2 * extentOfSource - 1 - ofSource;
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
            value = RevenantMPSLoad(in, type, (NSUInteger)index);
        else if (mode == 0)
            value = constant;
        RevenantMPSStoreRounded(out, result.dataType, element, value, 1);
    }
    free(resultStride);
    free(sourceStride);
}

static void RevenantMPSGraphScatter(MPSGraphTensorData *source, MPSGraphTensorData *result, NSDictionary *plan)
{
    NSArray<NSNumber *> *sourceShape = source.shape;
    NSArray<NSNumber *> *resultShape = result.shape;
    NSArray<NSNumber *> *offsets = plan[@"offsets"];
    NSArray<NSNumber *> *strides = plan[@"strides"];
    NSArray<NSNumber *> *divisors = plan[@"divisors"];
    NSUInteger rank = resultShape.count;
    BOOL summed = divisors.count == rank;
    NSUInteger count = RevenantMPSGraphElementCount(sourceShape);
    if (count == 0)
        return;
    MPSDataType type = source.dataType;
    void *in = [source revenant_mps_bytes];
    void *out = [result revenant_mps_bytes];
    size_t width = MPSSizeofMPSDataType(result.dataType);

    unsigned long long *resultStride = calloc(rank ? rank : 1, sizeof(unsigned long long));
    for (NSUInteger i = rank; i-- > 0;)
        resultStride[i] = (i + 1 < rank
                           ? resultStride[i + 1] * (unsigned long long)resultShape[i + 1].unsignedIntegerValue
                           : 1);
    if (![plan[@"update"] boolValue])
        memset(out, 0, RevenantMPSGraphElementCount(resultShape) * width);
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
            if (place < 0 || (NSUInteger)place >= (NSUInteger)resultShape[k].unsignedIntegerValue) {
                outside = YES;
                break;
            }
            index += (unsigned long long)place * resultStride[k];
        }
        if (outside || index >= RevenantMPSGraphElementCount(resultShape))
            continue;
        double value = RevenantMPSLoad(in, type, element);
        if (summed)
            value += RevenantMPSLoad(out, result.dataType, (NSUInteger)index);
        RevenantMPSStoreRounded(out, result.dataType, (NSUInteger)index, value, 1);
    }
    free(resultStride);
}

static NSUInteger RevenantMPSGraphNonZeroCount(NSString *name, MPSGraphTensorData *source)
{
    void *in = [source revenant_mps_bytes];
    if (in == NULL) {
        RevenantMPSGraphRefuse(@"MPSGraph: the non-zero operation named %@ has nowhere to read its operand "
                             @"from, so its indices were not written", name);
        return 0;
    }
    NSUInteger total = RevenantMPSGraphElementCount(source.shape);
    MPSDataType type = source.dataType;
    NSUInteger count = 0;
    for (NSUInteger element = 0; element < total; element++)
        if (RevenantMPSGraphAsZero(RevenantMPSLoad(in, type, element), type) != 0.0)
            count++;
    return count;
}

static void RevenantMPSGraphNonZero(NSString *name, MPSGraphTensorData *source, MPSGraphTensorData *result,
                                 NSUInteger count)
{
    NSArray<NSNumber *> *shape = source.shape;
    NSUInteger rank = shape.count;
    NSUInteger total = RevenantMPSGraphElementCount(shape);
    void *in = [source revenant_mps_bytes];
    void *out = [result revenant_mps_bytes];
    if (in == NULL || (out == NULL && count != 0)) {
        RevenantMPSGraphRefuse(@"MPSGraph: the non-zero operation named %@ has nowhere to read its operand from "
                             @"or to write its indices to, so its indices were not written", name);
        return;
    }
    MPSDataType type = source.dataType;
    NSUInteger written = 0;
    for (NSUInteger element = 0; element < total; element++) {
        if (RevenantMPSGraphAsZero(RevenantMPSLoad(in, type, element), type) == 0.0)
            continue;
        unsigned long long at = element;
        for (NSUInteger axis = rank; axis-- > 0;) {
            NSUInteger extent = (NSUInteger)shape[axis].unsignedIntegerValue;
            RevenantMPSStore(out, MPSDataTypeInt32, written * rank + axis,
                           (double)(extent ? at % extent : 0));
            if (extent)
                at /= extent;
        }
        written++;
    }
}

@implementation MPSGraph (RevenantMPSGraphInterpreter)

- (NSArray<NSNumber *> *)revenant_mps_gatherShapeOfTensor:(MPSGraphTensor *)tensor
                                             parameters:(NSDictionary *)parameters
                                                    named:(NSString *)name
{
    NSDictionary *plan = RevenantMPSGraphGatherPlan(name, tensor.shape, parameters, nil);
    return plan[@"shape"];
}

- (NSArray<NSNumber *> *)revenant_mps_splitSizes:(NSArray<NSNumber *> *)written
                                    numSplits:(NSUInteger)numSplits
                                         axis:(NSInteger)axis
                                  ofShape:(NSArray<NSNumber *> *)operandShape
                                       named:(NSString *)name
{
    return RevenantMPSGraphSplitSizes(name, written, numSplits, axis, operandShape);
}

- (NSDictionary *)revenant_mps_blockShufflePlan:(NSString *)name
                                       ofShape:(NSArray<NSNumber *> *)operandShape
                                       spatial:(NSArray<NSNumber *> *)spatial
                                         batch:(NSInteger)batch
                                         block:(NSArray<NSNumber *> *)block
                                       toBatch:(BOOL)toBatch
                                       shuffle:(BOOL)shuffle
{
    return RevenantMPSGraphBlockShufflePlan(name, operandShape, spatial, batch, block, toBatch, shuffle);
}

- (NSArray<NSNumber *> *)revenant_mps_concatShapeOfTensors:(NSArray<MPSGraphTensor *> *)tensors
                                                    axis:(NSInteger)axis
                                              interleave:(BOOL)interleave
                                                stacked:(BOOL)stacked
                                                   named:(NSString *)name
{
    NSMutableArray<NSArray<NSNumber *> *> *shapes = [NSMutableArray arrayWithCapacity:tensors.count];
    for (MPSGraphTensor *tensor in tensors)
        [shapes addObject:tensor.shape];
    return RevenantMPSGraphConcatPlan(name, shapes, axis, interleave, stacked)[@"shape"];
}

- (void)revenant_mps_runBlockShuffleChain:(NSDictionary *)chain
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
        NSDictionary *walk = RevenantMPSGraphGatherPlan([operation name], carrying.shape,
                                                      @{@"gather": transforms[step], keys[step]: carried[step]},
                                                      nil);
        if (walk == nil) {
            RevenantMPSGraphRefuse(@"MPSGraph: the block-moving operation named %@ wanted a step of its chain "
                                 @"the gather does not know, so nothing was written to its output",
                                 [operation name]);
            return;
        }
        MPSGraphTensorData *next = [[MPSGraphTensorData alloc] initWithDevice:source.device
                                                                 elementCount:RevenantMPSGraphElementCount(walk[@"shape"])
                                                                        shape:walk[@"shape"]
                                                                     dataType:dataType];
        [next revenant_mps_bytes];
        RevenantMPSGraphGather(operation, carrying, next, walk);
        carrying = next;
    }
    [output revenant_mps_setShape:carrying.shape];
    values[output] = carrying;
}

- (void)revenant_mps_runOperation:(MPSGraphOperation *)operation values:(NSMutableDictionary *)values
{
    RevenantMPSGraphOperationKind kind = [operation revenant_mps_kind];
    if (kind == RevenantMPSGraphOperationKindPlaceholder)
        return;
    MPSGraphTensor *output = operation.outputTensors.firstObject;
    if (!output)
        return;
    NSArray<MPSGraphTensor *> *inputs = operation.inputTensors;
    NSUInteger count = [output revenant_mps_elementCount];
    MPSDataType dataType = output.dataType;
    MPSGraphTensorData *first = values[inputs.firstObject];
    id<MTLDevice> device = [first isKindOfClass:[MPSGraphTensorData class]] ? first.device.metalDevice
                                                                        : self.revenant_mps_device.metalDevice;

    if (operation.revenant_mps_parameters[@"splitAxis"]) {
        NSDictionary *parameters = operation.revenant_mps_parameters;
        NSInteger axis = [parameters[@"splitAxis"] integerValue];
        MPSGraphTensorData *source = values[inputs.firstObject];
        if (![source isKindOfClass:[MPSGraphTensorData class]]) {
            RevenantMPSGraphRefuse(@"MPSGraph: the split named %@ has no value for its operand, so none of its "
                                 @"results was written", [operation name]);
            return;
        }
        NSArray<NSNumber *> *sizes = RevenantMPSGraphSplitSizes([operation name], parameters[@"splitSizes"],
                                                              [parameters[@"splitNumSplits"] unsignedIntegerValue],
                                                              axis, source.shape);
        NSArray<MPSGraphTensor *> *outputs = operation.outputTensors;
        if (outputs.count != sizes.count) {
            RevenantMPSGraphRefuse(@"MPSGraph: the split named %@ has %lu results and %lu regions, so none of "
                                 @"them was written", [operation name], (unsigned long)outputs.count,
                                 (unsigned long)sizes.count);
            return;
        }
        long long at = 0;
        for (NSUInteger i = 0; i < outputs.count; i++) {
            MPSGraphTensor *output = outputs[i];
            NSMutableArray<NSNumber *> *starts = [NSMutableArray arrayWithCapacity:source.shape.count];
            NSMutableArray<NSNumber *> *ends = [source.shape mutableCopy];
            NSMutableArray<NSNumber *> *strides = [NSMutableArray arrayWithCapacity:source.shape.count];
            for (NSUInteger k = 0; k < source.shape.count; k++) {
                [starts addObject:@0];
                [strides addObject:@1];
            }
            starts[(NSUInteger)axis] = @(at);
            ends[(NSUInteger)axis] = @(at + sizes[i].longLongValue);
            NSDictionary *region = RevenantMPSGraphGatherPlan([operation name], source.shape,
                                                             @{@"gather": @"slice",
                                                               @"sliceStarts": starts,
                                                               @"sliceEnds": ends,
                                                               @"sliceStrides": strides,
                                                               @"sliceStartMask": @0,
                                                               @"sliceEndMask": @0,
                                                               @"sliceSqueezeMask": @0}, nil);
            if (region == nil) {
                RevenantMPSGraphRefuse(@"MPSGraph: the split named %@ wanted a region its own plan cannot ask "
                                     @"for, so none of its results was written", [operation name]);
                return;
            }
            MPSGraphTensorData *result = [[MPSGraphTensorData alloc] initWithDevice:source.device
                                                                     elementCount:[output revenant_mps_elementCount]
                                                                            shape:output.shape
                                                                         dataType:output.dataType];
            [result revenant_mps_bytes];
            RevenantMPSGraphGather(operation, source, result, region);
            values[output] = result;
            at += sizes[i].longLongValue;
        }
        return;
    }
    if (operation.revenant_mps_parameters[@"coordinateAxis"]) {
        MPSGraphTensor *output = operation.outputTensors.firstObject;
        NSArray<NSNumber *> *shape = operation.revenant_mps_parameters[@"coordinateShape"];
        NSInteger axis = [operation.revenant_mps_parameters[@"coordinateAxis"] integerValue];
        NSUInteger rank = shape.count;
        NSUInteger count = [output revenant_mps_elementCount];
        if (rank == 0 || axis < 0 || (NSUInteger)axis >= rank || count == 0)
            return;
        [output revenant_mps_setShape:shape];
        MPSGraphTensorData *result = [[MPSGraphTensorData alloc] initWithDevice:[MPSGraphDevice deviceWithMTLDevice:device]
                                                                  elementCount:count
                                                                         shape:shape
                                                                      dataType:MPSDataTypeInt32];
        int32_t *out = [result revenant_mps_bytes];
        if (out == NULL) {
            RevenantMPSGraphRefuse(@"MPSGraph: the coordinate named %@ has nowhere to write its %lu elements, so "
                                 @"nothing was written to its output", [operation name],
                                 (unsigned long)count);
            return;
        }
        unsigned long long stride = 1;
        for (NSUInteger k = (NSUInteger)axis + 1; k < rank; k++)
            stride *= (unsigned long long)shape[k].unsignedIntegerValue;
        unsigned long long extent = (unsigned long long)shape[(NSUInteger)axis].unsignedLongLongValue;
        for (NSUInteger element = 0; element < count; element++)
            out[element] = (int32_t)(stride ? (element / stride) % (extent ? extent : 1) : 0);
        values[output] = result;
        return;
    }
    if (operation.revenant_mps_parameters[@"concatAxis"]) {
        NSMutableArray<MPSGraphTensorData *> *sources = [NSMutableArray arrayWithCapacity:inputs.count];
        NSMutableArray<NSArray<NSNumber *> *> *shapes = [NSMutableArray arrayWithCapacity:inputs.count];
        for (MPSGraphTensor *input in inputs) {
            MPSGraphTensorData *value = values[input];
            if (![value isKindOfClass:[MPSGraphTensorData class]]) {
                RevenantMPSGraphRefuse(@"MPSGraph: the operation named %@ has no value for one of its operands, "
                                     @"so nothing was written to its output", [operation name]);
                return;
            }
            [sources addObject:value];
            [shapes addObject:value.shape];
        }
        NSDictionary *plan = RevenantMPSGraphConcatPlan([operation name], shapes,
                                                      [operation.revenant_mps_parameters[@"concatAxis"] integerValue],
                                                      [operation.revenant_mps_parameters[@"concatInterleave"] boolValue],
                                                      [operation.revenant_mps_parameters[@"concatStacked"] boolValue]);
        if (plan[@"shape"] == nil) {
            RevenantMPSGraphRefuse(@"MPSGraph: the operation named %@ was given no tensors, so its result "
                                 "carries no shape and nothing was written to it", [operation name]);
            return;
        }
        [output revenant_mps_setShape:plan[@"shape"]];
        MPSGraphTensorData *concatenated = [[MPSGraphTensorData alloc] initWithDevice:sources.firstObject.device
                                                                          elementCount:RevenantMPSGraphElementCount(plan[@"shape"])
                                                                                 shape:plan[@"shape"]
                                                                              dataType:dataType];
        [concatenated revenant_mps_bytes];
        RevenantMPSGraphConcat([operation name], sources, concatenated, plan);
        values[output] = concatenated;
        return;
    }
    if (operation.revenant_mps_parameters[@"blockShuffle"]) {
        MPSGraphTensorData *source = values[inputs.firstObject];
        if (![source isKindOfClass:[MPSGraphTensorData class]]) {
            RevenantMPSGraphRefuse(@"MPSGraph: the block-moving operation named %@ has no value for its operand, "
                                 @"so nothing was written to its output", [operation name]);
            return;
        }
        NSMutableArray<NSNumber *> *axes = [NSMutableArray arrayWithCapacity:3];
        if ([operation.revenant_mps_parameters[@"blockShuffleGeneral"] boolValue]) {
            NSArray<NSNumber *> *spatial = RevenantMPSGraphGatherIntegers(values[inputs[1]]);
            NSArray<NSNumber *> *where = RevenantMPSGraphGatherIntegers(values[inputs[2]]);
            NSArray<NSNumber *> *sizes = RevenantMPSGraphGatherIntegers(values[inputs[3]]);
            NSArray<NSArray<NSNumber *> *> *fed = @[spatial ?: @[], where ?: @[], sizes ?: @[]];
            for (NSUInteger i = 0; i < 3; i++) {
                if (fed[i].count != 0)
                    continue;
                RevenantMPSGraphRefuse(@"MPSGraph: the block-moving operation named %@ was fed nothing at all for "
                                     @"its parameter %lu, and every one of the three is a list of numbers the "
                                     @"plan reads, so nothing was written to its output",
                                     [operation name], (unsigned long)i + 1);
                return;
            }
            if (where.count != 1) {
                RevenantMPSGraphRefuse(@"MPSGraph: the block-moving operation named %@ was fed %lu numbers as its "
                                     @"batch axis, and the batch axis is one of them: measured, the release "
                                     @"takes it as a 0D tensor or one of shape [1]",
                                     [operation name], (unsigned long)where.count);
                return;
            }
            NSDictionary *general = [self revenant_mps_blockShufflePlan:[operation name]
                                                              ofShape:source.shape
                                                              spatial:spatial
                                                                batch:where.firstObject.integerValue
                                                                block:sizes
                                                              toBatch:[operation.revenant_mps_parameters[@"blockShuffleToBatch"] boolValue]
                                                              shuffle:[operation.revenant_mps_parameters[@"blockShuffleShuffle"] boolValue]];
            [self revenant_mps_runBlockShuffleChain:general into:output from:source operation:operation
                                            values:values];
            return;
        }
        for (NSUInteger i = 1; i < 4 && i < inputs.count; i++) {
            NSArray<NSNumber *> *read = RevenantMPSGraphGatherIntegers(values[inputs[i]]);
            if (read.count != 1) {
                RevenantMPSGraphRefuse(@"MPSGraph: the block-moving operation named %@ was fed %lu numbers for "
                                     @"its axis of input %lu, and an axis is one of them, so nothing was "
                                     @"written to its output",
                                     [operation name], (unsigned long)read.count, (unsigned long)i);
                return;
            }
            [axes addObject:read.firstObject];
        }
        if (axes.count != 3) {
            RevenantMPSGraphRefuse(@"MPSGraph: the block-moving operation named %@ carries %lu axes and the "
                                 @"family's fed form has three, so nothing was written to its output",
                                 [operation name], (unsigned long)axes.count);
            return;
        }
        NSUInteger oneBlock = [operation.revenant_mps_parameters[@"blockShuffleBlock"] unsignedIntegerValue];
        NSArray<NSNumber *> *block = @[@(oneBlock), @(oneBlock)];
        NSDictionary *chain = [self revenant_mps_blockShufflePlan:[operation name]
                                                       ofShape:source.shape
                                                       spatial:@[axes[1], axes[0]]
                                                         batch:axes[2].integerValue
                                                         block:block
                                                       toBatch:[operation.revenant_mps_parameters[@"blockShuffleToBatch"] boolValue]
                                                       shuffle:[operation.revenant_mps_parameters[@"blockShuffleShuffle"] boolValue]];
        [self revenant_mps_runBlockShuffleChain:chain into:output from:source operation:operation values:values];
        return;
    }
    if (operation.revenant_mps_parameters[@"gather"]) {
        MPSGraphTensorData *source = values[inputs.firstObject];
        if (![source isKindOfClass:[MPSGraphTensorData class]]) {
            RevenantMPSGraphRefuse(@"MPSGraph: the gather named %@ has no value for its first input, so "
                                 @"nothing was written to its output", [operation name]);
            return;
        }
        NSMutableArray<NSArray<NSNumber *> *> *fed = [NSMutableArray array];
        NSString *gather = operation.revenant_mps_parameters[@"gather"];
        BOOL sliceFamily = [gather hasPrefix:@"slice"];
        if (sliceFamily) {
            NSUInteger from = [operation.revenant_mps_parameters[@"sliceFedFrom"] unsignedIntegerValue];
            if (from != 0)
                for (NSUInteger i = from; i < inputs.count; i++)
                    [fed addObject:RevenantMPSGraphGatherIntegers(values[inputs[i]]) ?: @[]];
            if ([gather isEqualToString:@"sliceGradient"] && inputs.count > 1)
                [fed addObject:RevenantMPSGraphGatherIntegers(values[inputs[1]]) ?: @[]];
        } else if (inputs.count > 1) {
            [fed addObject:RevenantMPSGraphGatherIntegers(values[inputs[1]])];
        }
        NSDictionary *plan = RevenantMPSGraphGatherPlan([operation name], source.shape,
                                                      operation.revenant_mps_parameters, fed);
        if (plan == nil)
            return;
        [output revenant_mps_setShape:plan[@"shape"]];
        NSUInteger gathered_ = RevenantMPSGraphElementCount(plan[@"shape"]);
        MPSGraphTensorData *gathered = [[MPSGraphTensorData alloc] initWithDevice:source.device
                                                                     elementCount:gathered_
                                                                            shape:plan[@"shape"]
                                                                         dataType:dataType];
        [gathered revenant_mps_bytes];
        if ([plan[@"scatter"] boolValue]) {
            MPSGraphTensorData *scattered = [plan[@"update"] boolValue] && inputs.count > 1 ? values[inputs[1]]
                                                                                          : source;
            if (![scattered isKindOfClass:[MPSGraphTensorData class]]) {
                RevenantMPSGraphRefuse(@"MPSGraph: the slice operation named %@ has no value for the tensor it "
                                     @"writes, so nothing was written to its output", [operation name]);
                return;
            }
            if ([plan[@"update"] boolValue]) {
                NSUInteger available = RevenantMPSGraphElementCount(source.shape);
                NSUInteger room = RevenantMPSGraphElementCount(gathered.shape);
                void *out = [gathered revenant_mps_bytes];
                void *in = [source revenant_mps_bytes];
                for (NSUInteger i = 0; i < available && i < room; i++)
                    RevenantMPSStoreRounded(out, dataType, i, RevenantMPSLoad(in, source.dataType, i), 1);
            }
            RevenantMPSGraphScatter(scattered, gathered, plan);
        } else {
            NSArray<NSNumber *> *mapped = plan[@"mappedShape"];
            if (mapped != nil) {
                NSUInteger walked = RevenantMPSGraphElementCount(mapped);
                MPSGraphTensorData *full = [[MPSGraphTensorData alloc] initWithDevice:source.device
                                                                          elementCount:walked
                                                                                 shape:mapped
                                                                              dataType:dataType];
                [full revenant_mps_bytes];
                RevenantMPSGraphGather(operation, source, full, plan);
                memcpy([gathered revenant_mps_bytes], [full revenant_mps_bytes],
                       MIN(walked, gathered_) * MPSSizeofMPSDataType(dataType));
            } else if ([gather isEqualToString:@"pad"]) {
                RevenantMPSGraphPad(source, gathered, plan);
            } else {
                RevenantMPSGraphGather(operation, source, gathered, plan);
            }
        }
        values[output] = gathered;
        return;
    }
    if (kind == RevenantMPSGraphOperationKindNonZero) {
        MPSGraphTensorData *source = values[inputs.firstObject];
        if (![source isKindOfClass:[MPSGraphTensorData class]]) {
            RevenantMPSGraphRefuse(@"MPSGraph: the non-zero operation named %@ has no value for its operand, so "
                                 @"its indices were not written", [operation name]);
            return;
        }
        NSUInteger rank = source.shape.count;
        NSUInteger count = RevenantMPSGraphNonZeroCount([operation name], source);
        NSArray<NSNumber *> *answer = @[@(count), @(rank)];
        [output revenant_mps_setShape:answer];
        MPSGraphTensorData *indices = [[MPSGraphTensorData alloc] initWithDevice:source.device
                                                                    elementCount:count * rank
                                                                           shape:answer
                                                                        dataType:MPSDataTypeInt32];
        [indices revenant_mps_bytes];
        RevenantMPSGraphNonZero([operation name], source, indices, count);
        values[output] = indices;
        return;
    }
    if (operation.revenant_mps_parameters[@"scanCombination"]) {
        MPSGraphTensorData *source = values[inputs.firstObject];
        if (![source isKindOfClass:[MPSGraphTensorData class]]) {
            RevenantMPSGraphRefuse(@"MPSGraph: a cumulative operation named %@ has no value for its first "
                                 @"input, so nothing was written to its output", [operation name]);
            return;
        }
        MPSGraphTensorData *axisData = inputs.count > 1 ? values[inputs[1]] : nil;
        MPSGraphTensorData *scanned = [[MPSGraphTensorData alloc] initWithDevice:source.device
                                                                     elementCount:count
                                                                            shape:output.shape
                                                                         dataType:dataType];
        [scanned revenant_mps_bytes];
        RevenantMPSGraphScan(operation, source, axisData, scanned);
        values[output] = scanned;
        return;
    }
    if (operation.revenant_mps_parameters[@"combination"]) {
        MPSGraphTensorData *source = values[inputs.firstObject];
        MPSGraphTensor *meanTensor = operation.revenant_mps_parameters[@"mean"];
        if (![source isKindOfClass:[MPSGraphTensorData class]]) {
            RevenantMPSGraphRefuse(@"MPSGraph: a reduction named %@ has no value for its first input, so "
                                 @"nothing was written to its output", [operation name]);
            return;
        }
        MPSGraphTensorData *result = [[MPSGraphTensorData alloc] initWithDevice:source.device
                                                                    elementCount:count
                                                                           shape:output.shape
                                                                        dataType:dataType];
        [result revenant_mps_bytes];
        MPSGraphTensorData *mean = [meanTensor isKindOfClass:[MPSGraphTensor class]] ? values[meanTensor]
                                                                                     : nil;
        RevenantMPSGraphReduce(operation, source, [mean isKindOfClass:[MPSGraphTensorData class]] ? mean : nil,
                            result);
        values[output] = result;
        return;
    }

    if (kind == RevenantMPSGraphOperationKindConstant) {
        NSData *values_ = [operation revenant_mps_parameters][@"values"];
        if (!values_)
            return;
        MPSGraphTensorData *data = [[MPSGraphTensorData alloc] initWithDevice:[MPSGraphDevice deviceWithMTLDevice:device]
                                                                  elementCount:count
                                                                         shape:output.shape
                                                                      dataType:dataType];
        memcpy([data revenant_mps_bytes], values_.bytes, MIN(values_.length, count * MPSSizeofMPSDataType(dataType)));
        values[output] = data;
        return;
    }

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
        RevenantMPSGraphRefuse(@"MPSGraph: an operation named %@ has no value for its first input, so nothing was written to its output", [operation name]);
        return;
    }
    MPSGraphTensorData *result = [[MPSGraphTensorData alloc] initWithDevice:left.device
                                                             elementCount:count
                                                                    shape:output.shape
                                                                 dataType:dataType];
    [result revenant_mps_bytes];
    void *out = [result revenant_mps_bytes];
    MPSDataType operandType = left.dataType;
    int latch = [operation.revenant_mps_parameters[@"latchNaN"] boolValue];
    if (right) {
        if (third) {
            for (NSUInteger i = 0; i < count; i++)
                RevenantMPSStoreRounded(out, dataType, i,
                           RevenantMPSGraphApply(kind, RevenantMPSLoad([left revenant_mps_bytes], operandType, i),
                                               RevenantMPSLoad([right revenant_mps_bytes], right.dataType, i),
                                               RevenantMPSLoad([third revenant_mps_bytes], third.dataType, i),
                                               operandType, dataType, latch), 1);
        } else {
            for (NSUInteger i = 0; i < count; i++)
                RevenantMPSStoreRounded(out, dataType, i,
                           RevenantMPSGraphApply(kind, RevenantMPSLoad([left revenant_mps_bytes], operandType, i),
                                               RevenantMPSLoad([right revenant_mps_bytes], right.dataType, i), 0.0,
                                               operandType, dataType, latch), 1);
        }
    } else {
        for (NSUInteger i = 0; i < count; i++)
            RevenantMPSStoreRounded(out, dataType, i,
                       RevenantMPSGraphApply(kind, RevenantMPSLoad([left revenant_mps_bytes], operandType, i), 0.0, 0.0,
                                           operandType, dataType, latch), 1);
    }
    values[output] = result;
}

@end
