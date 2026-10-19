#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>

#include <math.h>
#include <string.h>

static inline BOOL CharonMPSDataTypeIsElement(MPSDataType type)
{
    switch (type) {
    case MPSDataTypeFloat32:
    case MPSDataTypeFloat16:
    case MPSDataTypeInt8:
    case MPSDataTypeInt16:
    case MPSDataTypeInt32:
    case MPSDataTypeUInt8:
    case MPSDataTypeUInt16:
    case MPSDataTypeUInt32:
        return YES;
    default:
        return NO;
    }
}

static inline BOOL CharonMPSDataTypeIsFloat(MPSDataType type)
{
    return type == MPSDataTypeFloat32 || type == MPSDataTypeFloat16;
}

static inline float CharonMPSHalfToFloat(uint16_t half)
{
    uint32_t sign = ((uint32_t)half & 0x8000u) << 16;
    uint32_t exponent = ((uint32_t)half >> 10) & 0x1Fu;
    uint32_t mantissa = (uint32_t)half & 0x3FFu;
    uint32_t bits;
    float value;
    if (exponent == 0) {
        if (mantissa == 0) {
            bits = sign;
        } else {
            uint32_t top = 0, rest = mantissa;
            while (rest > 1) {
                rest >>= 1;
                top++;
            }
            bits = sign | ((uint32_t)(top - 24 + 127) << 23) | ((mantissa - (1u << top)) << (23 - top));
        }
    } else if (exponent == 0x1F) {
        bits = sign | 0x7F800000u | (mantissa << 13);
    } else {
        bits = sign | ((exponent + 127 - 15) << 23) | (mantissa << 13);
    }
    memcpy(&value, &bits, sizeof(value));
    return value;
}

static inline uint16_t CharonMPSFloatToHalfRounded(float value, int awayFromZero)
{
    uint32_t bits, sign, mantissa, half, rest, halfway;
    int32_t biased, exponent;
    memcpy(&bits, &value, sizeof(bits));
    sign = (bits >> 16) & 0x8000u;
    biased = (int32_t)((bits >> 23) & 0xFFu);
    mantissa = bits & 0x7FFFFFu;
    if (biased == 0xFF) {
        return (uint16_t)(sign | 0x7C00u | (mantissa ? 0x200u : 0u));
    }
    exponent = biased - 127 + 15;
    if (exponent >= 0x1F) {
        return (uint16_t)(sign | 0x7C00u);
    }
    if (exponent <= 0) {
        if (exponent < -10) {
            return (uint16_t)sign;
        }
        mantissa |= 0x800000u;
        half = mantissa >> (14 - exponent);
        rest = mantissa & ((1u << (14 - exponent)) - 1u);
        halfway = 1u << (13 - exponent);
        if (rest > halfway || (rest == halfway && (awayFromZero || (half & 1))))
            half++;
        return (uint16_t)(sign | half);
    }
    half = ((uint32_t)exponent << 10) | (mantissa >> 13);
    rest = mantissa & 0x1FFFu;
    if (rest > 0x1000u || (rest == 0x1000u && (awayFromZero || (half & 1))))
        half++;
    return (uint16_t)(sign | half);
}

static inline uint16_t CharonMPSFloatToHalf(float value)
{
    return CharonMPSFloatToHalfRounded(value, 0);
}

static inline double CharonMPSLoad(const void *bytes, MPSDataType type, size_t index)
{
    switch (type) {
    case MPSDataTypeFloat32: {
        float value;
        memcpy(&value, (const char *)bytes + index * 4, 4);
        return (double)value;
    }
    case MPSDataTypeFloat16:
        return (double)CharonMPSHalfToFloat(((const uint16_t *)bytes)[index]);
    case MPSDataTypeInt8:
        return (double)((const int8_t *)bytes)[index];
    case MPSDataTypeInt16:
        return (double)((const int16_t *)bytes)[index];
    case MPSDataTypeInt32:
        return (double)((const int32_t *)bytes)[index];
    case MPSDataTypeUInt8:
        return (double)((const uint8_t *)bytes)[index];
    case MPSDataTypeUInt16:
        return (double)((const uint16_t *)bytes)[index];
    case MPSDataTypeUInt32:
        return (double)((const uint32_t *)bytes)[index];
    case MPSDataTypeBool:
        return (double)((const uint8_t *)bytes)[index];
    default:
        return 0.0;
    }
}

static inline void CharonMPSStoreRounded(void *bytes, MPSDataType type, size_t index, double value,
                                         int awayFromZero)
{
#if defined(CHARON_PLANT)
#if CHARON_PLANT == 1
    value = value + 1.0;
#elif CHARON_PLANT == 2
    if (index == 0)
        value = value + 1.0;
#endif
#endif
    switch (type) {
    case MPSDataTypeFloat32: {
        float narrowed = (float)value;
        memcpy((char *)bytes + index * 4, &narrowed, 4);
        break;
    }
    case MPSDataTypeFloat16:
        ((uint16_t *)bytes)[index] = CharonMPSFloatToHalfRounded((float)value, awayFromZero);
        break;
    case MPSDataTypeInt8:
        ((int8_t *)bytes)[index] = (int8_t)value;
        break;
    case MPSDataTypeInt16:
        ((int16_t *)bytes)[index] = (int16_t)value;
        break;
    case MPSDataTypeInt32:
        ((int32_t *)bytes)[index] = (int32_t)value;
        break;
    case MPSDataTypeUInt8:
        ((uint8_t *)bytes)[index] = (uint8_t)value;
        break;
    case MPSDataTypeUInt16:
        ((uint16_t *)bytes)[index] = (uint16_t)value;
        break;
    case MPSDataTypeUInt32:
        ((uint32_t *)bytes)[index] = (uint32_t)value;
        break;
    case MPSDataTypeBool:
        ((uint8_t *)bytes)[index] = value != 0.0 ? 1 : 0;
        break;
    default:
        break;
    }
}

static inline void CharonMPSStore(void *bytes, MPSDataType type, size_t index, double value)
{
    CharonMPSStoreRounded(bytes, type, index, value, 0);
}

typedef struct {
    void *bytes;
    MPSDataType dataType;
    size_t elementSize;
    size_t rowBytes;
    size_t matrixBytes;
    NSUInteger rows;
    NSUInteger columns;
    NSUInteger matrices;
} CharonMPSMatrixView;

static inline CharonMPSMatrixView CharonMPSMatrixViewOf(MPSMatrix *matrix)
{
    CharonMPSMatrixView view;
    view.bytes = (char *)[matrix.data contents] + matrix.offset;
    view.dataType = matrix.dataType;
    view.elementSize = MPSSizeofMPSDataType(matrix.dataType);
    view.rowBytes = matrix.rowBytes;
    view.matrixBytes = matrix.matrixBytes;
    view.rows = matrix.rows;
    view.columns = matrix.columns;
    view.matrices = matrix.matrices;
    return view;
}

static inline void *CharonMPSMatrixElement(const CharonMPSMatrixView *view, NSUInteger matrix, NSUInteger row, NSUInteger column)
{
    return (char *)view->bytes + matrix * view->matrixBytes + row * view->rowBytes + column * view->elementSize;
}

static inline BOOL CharonMPSMatrixHolds(const CharonMPSMatrixView *view, NSUInteger matrix, NSUInteger originRow, NSUInteger originColumn, NSUInteger rows, NSUInteger columns)
{
    if (matrix >= view->matrices)
        return NO;
    if (originRow > view->rows || rows > view->rows - originRow)
        return NO;
    if (originColumn > view->columns || columns > view->columns - originColumn)
        return NO;
    return YES;
}

typedef struct {
    void *bytes;
    MPSDataType dataType;
    size_t elementSize;
    size_t vectorBytes;
    NSUInteger length;
    NSUInteger vectors;
} CharonMPSVectorView;

static inline CharonMPSVectorView CharonMPSVectorViewOf(MPSVector *vector)
{
    CharonMPSVectorView view;
    view.bytes = (char *)[vector.data contents] + vector.offset;
    view.dataType = vector.dataType;
    view.elementSize = MPSSizeofMPSDataType(vector.dataType);
    view.vectorBytes = vector.vectorBytes;
    view.length = vector.length;
    view.vectors = vector.vectors;
    return view;
}

static inline void *CharonMPSVectorElement(const CharonMPSVectorView *view, NSUInteger index, NSUInteger component)
{
    return (char *)view->bytes + index * view->vectorBytes + component * view->elementSize;
}

static inline BOOL CharonMPSVectorHolds(const CharonMPSVectorView *view, NSUInteger index, NSUInteger length)
{
    return index < view->vectors && length <= view->length;
}

static inline double CharonMPSInverseNormal(double p)
{
    static const double a[6] = {-3.969683028665376e+01, 2.209460984245205e+02, -2.759285104469687e+02,
                                 1.383577518672690e+02, -3.066479806614716e+01, 2.506628277459239e+00};
    static const double b[5] = {-5.447609879822406e+01, 1.615858368580409e+02, -1.556989798598866e+02,
                                 6.680131188771972e+01, -1.328068155288572e+01};
    static const double c[6] = {-7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e+00,
                                 -2.549732539343734e+00, 4.374664141464968e+00, 2.938163982698783e+00};
    static const double d[4] = {7.784695709041462e-03, 3.224671290700398e-01, 2.445134137142996e+00,
                                 3.754408661907416e+00};
    const double boundary = 0.02425;
    if (p <= 0.0)
        return -INFINITY;
    if (p >= 1.0)
        return INFINITY;
    if (p < boundary) {
        double q = sqrt(-2.0 * log(p));
        return (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) /
               ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1.0);
    }
    if (p <= 1.0 - boundary) {
        double q = p - 0.5, r = q * q;
        return (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * q /
               (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1.0);
    }
    double q = sqrt(-2.0 * log(1.0 - p));
    return -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) /
            ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1.0);
}

static inline void CharonMPSBatch(NSUInteger batchStart, NSUInteger batchSize, NSUInteger available, NSUInteger *start, NSUInteger *count)
{
    NSUInteger first = batchStart < available ? batchStart : available;
    NSUInteger last = available;
    if (batchSize && first + batchSize < last)
        last = first + batchSize;
    *start = first;
    *count = last - first;
}

#define CharonMPSRefuse(...) NSLog(__VA_ARGS__)

@interface MPSPredicate (CharonMPS)
- (BOOL)charon_mps_permitsExecution;
@end

@interface MPSStateResourceList (CharonMPS)
- (NSArray<NSNumber *> *)charon_mps_bufferSizes;
- (NSArray<MTLTextureDescriptor *> *)charon_mps_textureDescriptors;
@end

@interface MPSState (CharonMPS)
- (void)charon_mps_appendBuffer:(size_t)size;
- (void)charon_mps_appendTexture:(MTLTextureDescriptor *)descriptor;
- (void)charon_mps_appendResource:(id<MTLResource>)resource;
@end

@interface MPSTemporaryMatrix (CharonMPS)
- (instancetype)charon_mps_withReadCount:(NSUInteger)readCount;
@end

@interface MPSTemporaryVector (CharonMPS)
- (instancetype)charon_mps_withReadCount:(NSUInteger)readCount;
@end

static inline BOOL CharonMPSCommandBufferPermits(id<MTLCommandBuffer> commandBuffer)
{
    if ([commandBuffer isKindOfClass:[MPSCommandBuffer class]])
        return [[(MPSCommandBuffer *)commandBuffer predicate] charon_mps_permitsExecution];
    return YES;
}

typedef struct {
    MPSCNNNeuronType type;
    float a, b, c;
    const float *prelu;
    NSUInteger channels;
} CharonMPSNeuron;

static inline double CharonMPSNeuronA(const CharonMPSNeuron *neuron, NSUInteger channel)
{
    return neuron->prelu ? (double)neuron->prelu[channel] : (double)neuron->a;
}

@interface MPSMatrixNeuron (CharonMPS)
- (CharonMPSNeuron)charon_mps_neuron;
@end

@interface MPSMatrixNeuronGradient (CharonMPS)
- (CharonMPSNeuron)charon_mps_neuron;
@end

@interface MPSMatrixFullyConnected (CharonMPS)
- (CharonMPSNeuron)charon_mps_neuron;
@end

@interface MPSMatrixBatchNormalization (CharonMPS)
- (CharonMPSNeuron)charon_mps_neuron;
@end

@interface MPSMatrixBatchNormalizationGradient (CharonMPS)
- (CharonMPSNeuron)charon_mps_neuron;
@end

@interface MPSMatrixSum (CharonMPS)
- (CharonMPSNeuron)charon_mps_neuron;
@end

@interface MPSMatrixRandom (CharonMPS)
- (id)initWithDevice:(id<MTLDevice>)device charonRandom:(BOOL)philox;
- (id)charon_mps_configureWithDataType:(MPSDataType)dataType
                                  seed:(uint32_t)seed
                            distribution:(MPSMatrixRandomDistributionDescriptor *)distribution;
- (uint32_t)charon_mps_wordAtIndex:(NSUInteger)index;
- (void)charon_mps_batchOver:(NSUInteger)available first:(NSUInteger *)first count:(NSUInteger *)count;
@end

@interface MPSNNOptimizer (CharonMPS)
- (instancetype)charon_initWithDevice:(id<MTLDevice>)device;
@end

@interface MPSMatrixSoftMax (CharonMPS)
- (void)charon_mps_setLogarithmic:(BOOL)logarithmic;
@end

@interface MPSMatrixCopyDescriptor (CharonMPS)
- (id)charon_mps_withCount:(NSUInteger)count;
- (NSUInteger)charon_mps_count;
- (MPSMatrix *)charon_mps_sourceAtIndex:(NSUInteger)index;
- (MPSMatrix *)charon_mps_destinationAtIndex:(NSUInteger)index;
- (MPSMatrixCopyOffsets)charon_mps_offsetsAtIndex:(NSUInteger)index;
@end

static inline void CharonMPSConsumeReadCount(id object)
{
    if ([object isKindOfClass:[MPSTemporaryMatrix class]] || [object isKindOfClass:[MPSTemporaryVector class]]) {
        NSUInteger count = [(MPSTemporaryVector *)object readCount];
        if (count)
            [(MPSTemporaryVector *)object setReadCount:count - 1];
        return;
    }
    if ([object isKindOfClass:[MPSTemporaryImage class]]) {
        NSUInteger count = [(MPSTemporaryImage *)object readCount];
        if (count)
            [(MPSTemporaryImage *)object setReadCount:count - 1];
    }
}

static inline size_t CharonMPSRowBytesForColumns(NSUInteger columns, MPSDataType dataType)
{
    size_t elementSize = MPSSizeofMPSDataType(dataType);
    size_t alignment = CharonMPSDataTypeIsFloat(dataType) ? 16 : 4 * elementSize;
    if (columns == 0)
        return 0;
    if (columns == 1)
        return elementSize;
    return (columns * elementSize + alignment - 1) / alignment * alignment;
}

static inline double CharonMPSApplyNeuron(MPSCNNNeuronType type, double x, double a, double b, double c, double aPerChannel)
{
    switch (type) {
    case MPSCNNNeuronTypeNone:
    case MPSCNNNeuronTypeCount:
        return x;
    case MPSCNNNeuronTypeReLU:
        return x >= 0.0 ? x : a * x;
    case MPSCNNNeuronTypeLinear:
        return a * x + b;
    case MPSCNNNeuronTypeSigmoid:
        return 1.0 / (1.0 + exp(-x));
    case MPSCNNNeuronTypeHardSigmoid: {
        double v = x * a + b;
        return v < 0.0 ? 0.0 : (v > 1.0 ? 1.0 : v);
    }
    case MPSCNNNeuronTypeTanH:
        return a * tanh(b * x);
    case MPSCNNNeuronTypeAbsolute:
        return fabs(x);
    case MPSCNNNeuronTypeSoftPlus:
        return a * log1p(exp(b * x));
    case MPSCNNNeuronTypeSoftSign: {
        double m = fabs(x);
        return m == INFINITY ? (x < 0.0 ? -1.0 : 1.0) : x / (1.0 + m);
    }
    case MPSCNNNeuronTypeELU:
        return x >= 0.0 ? x : a * (exp(x) - 1.0);
    case MPSCNNNeuronTypePReLU:
        return x >= 0.0 ? x : aPerChannel * x;
    case MPSCNNNeuronTypeReLUN: {
        double v = x >= 0.0 ? x : a * x;
        return v > b ? b : v;
    }
    case MPSCNNNeuronTypePower:
        return pow(a * x + b, c);
    case MPSCNNNeuronTypeExponential:
        return pow(c, a * x + b);
    case MPSCNNNeuronTypeLogarithm:
        return log(a * x + b) / log(c);
    case MPSCNNNeuronTypeGeLU:
        return (1.0 + erf(x * sqrt(0.5))) * 0.5 * x;
    default:
        return x;
    }
}

static inline double CharonMPSApplyNeuronGradient(MPSCNNNeuronType type, double x, double y, double a, double b, double c, double aPerChannel)
{
    switch (type) {
    case MPSCNNNeuronTypeNone:
    case MPSCNNNeuronTypeCount:
        return 1.0;
    case MPSCNNNeuronTypeReLU:
        return x >= 0.0 ? 1.0 : a;
    case MPSCNNNeuronTypeLinear:
        return a;
    case MPSCNNNeuronTypeSigmoid: {
        double e = exp(-fabs(x));
        double s = 1.0 / (1.0 + e);
        return s * (1.0 - s);
    }
    case MPSCNNNeuronTypeHardSigmoid:
        return (x * a + b) >= 0.0 && (x * a + b) <= 1.0 ? a : 0.0;
    case MPSCNNNeuronTypeTanH: {
        double t = tanh(b * x);
        return a * b * (1.0 - t * t);
    }
    case MPSCNNNeuronTypeAbsolute:
        return x > 0.0 ? 1.0 : (x < 0.0 ? -1.0 : 0.0);
    case MPSCNNNeuronTypeSoftPlus: {
        double t = b * x;
        double s = t >= 0.0 ? 1.0 / (1.0 + exp(-t)) : exp(t) / (1.0 + exp(t));
        return a * b * s;
    }
    case MPSCNNNeuronTypeSoftSign: {
        double m = fabs(x);
        if (m == INFINITY)
            return 0.0;
        return 1.0 / ((1.0 + m) * (1.0 + m));
    }
    case MPSCNNNeuronTypeELU:
        return x >= 0.0 ? 1.0 : a * exp(x);
    case MPSCNNNeuronTypePReLU:
        return x >= 0.0 ? 1.0 : aPerChannel;
    case MPSCNNNeuronTypeReLUN:
        return (x >= 0.0 ? x : a * x) >= b ? 0.0 : (x >= 0.0 ? 1.0 : a);
    case MPSCNNNeuronTypePower: {
        double t = a * x + b;
        return t == 0.0 ? 0.0 : c * pow(t, c - 1.0) * a;
    }
    case MPSCNNNeuronTypeExponential: {
        double t = pow(c, a * x + b);
        return t * a * log(c);
    }
    case MPSCNNNeuronTypeLogarithm: {
        double t = a * x + b;
        return a / (t * log(c));
    }
    case MPSCNNNeuronTypeGeLU: {
        double u = x * 0.70710678118654752440;
        return 0.5 * (1.0 + erf(u)) + x * exp(-0.5 * x * x) * 0.39894228040143267794;
    }
    default:
        return 1.0;
    }
}
